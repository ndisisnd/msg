#!/usr/bin/env bash
# script-eng-review-check.sh — the mechanical proof that `eng --review` ran.
#
# Every whole-change review writes one evidence artifact into the PRD's reports
# folder: `review-prd-<N>-<K>.json`, where `<K>` is the packet/agent key the
# orchestrator assigned (the same key the exec-table decomposition uses). This
# script answers one question for an orchestrator or gate — "was every packet in
# this wave reviewed?" — from the filesystem, never from a returned summary.
#
# Usage:
#   script-eng-review-check.sh --reports-dir <dir> --expect <k1,k2,…>
#   script-eng-review-check.sh --reports-dir <dir> --expect-from-builds
#
#   --expect             comma-separated packet keys the caller expects covered.
#   --expect-from-builds derive the expected keys from the build run reports
#                        already in <dir> (`report-prd-<N>-<K>.json|.md`, fix
#                        plans excluded) — for a caller (pre-merge) that did not
#                        run the wave and has no packet list of its own.
#
# A key is covered by either of two artifacts:
#   per-packet   `review-prd-<N>-<k>.json`  — one reviewer, one packet.
#   batched wave `review-prd-<N>-<W>.json` carrying `"packets": [… "<k>" …]`
#                — one reviewer over a whole wave of mechanical packets, which
#                is what the orchestrator spawns instead of a reviewer per leaf
#                (eng/refs/review/protocol.md § Batched wave reviews). The
#                member keys are satisfied by that one artifact; its severity
#                counts are added ONCE, not once per key it covers.
# A per-packet artifact always wins over a batched one for the same key.
#
# Output (stdout), in the expected-key order given:
#   MISSING <k>        no artifact for that key, or one that does not parse /
#                      lacks `verdict` or `findings` — an unreadable artifact is
#                      counted missing, never counted as covered.
#   SELF-REVIEWED <k>  the artifact's `reviewed_by` equals its `built_by` — or,
#                      on a batched artifact, matches any builder in the
#                      `built_by` list — so the reviewer was a builder, which
#                      the review protocol forbids.
#   reviewed <n>/<m> — <b> blocker, <h> high, <x> medium     (always last)
#
# Exit codes:
#   0  every expected key covered by a valid, independently-reviewed artifact
#   1  one or more MISSING / SELF-REVIEWED keys (the coverage line still prints)
#   2  usage or environment error
#   3  --expect-from-builds found no build reports, so no expectation could be
#      derived — an unknown, reported as such, never reported as covered.

set -uo pipefail

usage() {
  echo "usage: script-eng-review-check.sh --reports-dir <dir> (--expect <k1,k2,…> | --expect-from-builds)" >&2
  exit 2
}

reports_dir=""
expect_raw=""
from_builds=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reports-dir) reports_dir="${2-}"; shift 2 || usage ;;
    --expect) expect_raw="${2-}"; shift 2 || usage ;;
    --expect-from-builds) from_builds=1; shift ;;
    -h|--help) echo "usage: script-eng-review-check.sh --reports-dir <dir> (--expect <k1,k2,…> | --expect-from-builds)"; exit 0 ;;
    *) echo "script-eng-review-check: unknown argument: $1" >&2; usage ;;
  esac
done

[[ -n "$reports_dir" ]] || usage
[[ -n "$expect_raw" || "$from_builds" -eq 1 ]] || usage
[[ -n "$expect_raw" && "$from_builds" -eq 1 ]] && {
  echo "script-eng-review-check: pass --expect or --expect-from-builds, not both" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || {
  echo "script-eng-review-check: python3 not available" >&2; exit 2; }

# A missing reports dir is not an environment error — it is the strongest form of
# "nothing was reviewed", and the caller must see it as missing coverage.
[[ -d "$reports_dir" ]] || reports_dir_absent=1

# Reads one artifact. Prints "<blocker> <high> <medium>\t<reviewed_by>\t<built_by>"
# and exits 0 only when the file parses as an object carrying a non-empty string
# `verdict` and a list `findings`.
read_artifact() {
  python3 - "$1" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as fh:
        doc = json.load(fh)
except Exception:
    sys.exit(1)
if not isinstance(doc, dict):
    sys.exit(1)
if not isinstance(doc.get("verdict"), str) or not doc["verdict"].strip():
    sys.exit(1)
findings = doc.get("findings")
if not isinstance(findings, list):
    sys.exit(1)
counts = {"blocker": 0, "high": 0, "medium": 0}
for item in findings:
    if isinstance(item, dict) and item.get("severity") in counts:
        counts[item["severity"]] += 1
reviewed_by = doc.get("reviewed_by") or ""
# `built_by` is one builder on a per-packet artifact and the list of covered
# builders on a batched wave artifact; both flatten to a comma-joined string so
# the caller's membership test is the same either way.
built_by = doc.get("built_by") or ""
if isinstance(built_by, list):
    built_by = ",".join(str(b).strip() for b in built_by if str(b).strip())
print("%d %d %d\t%s\t%s" % (counts["blocker"], counts["high"], counts["medium"],
                            str(reviewed_by).strip(), str(built_by).strip()))
PY
}

# Prints the path of a batched wave artifact in <reports_dir> whose `packets`
# array names $1, or nothing. First match in sorted order wins, so the answer is
# stable across runs.
find_wave_artifact() {
  python3 - "$reports_dir" "$1" <<'PY'
import glob, json, os, sys
d, key = sys.argv[1], sys.argv[2]
for path in sorted(glob.glob(os.path.join(d, "review-prd-*.json"))):
    try:
        with open(path) as fh:
            doc = json.load(fh)
    except Exception:
        continue
    if not isinstance(doc, dict):
        continue
    packets = doc.get("packets")
    if isinstance(packets, list) and key in [str(p).strip() for p in packets]:
        print(path)
        break
PY
}

# Derives the expected packet keys from the build run reports already on disk.
derive_keys_from_builds() {
  local f base
  for f in "$reports_dir"/report-prd-*.json "$reports_dir"/report-prd-*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    base="${base%.json}"; base="${base%.md}"
    case "$base" in *-fix-plan) continue ;; esac
    printf '%s\n' "$base" | sed -E 's/^report-prd-[0-9]+(\.[0-9]+)*-//'
  done | sort -u
}

keys=()
if [[ "$from_builds" -eq 1 ]]; then
  if [[ "${reports_dir_absent:-0}" -eq 1 ]]; then
    echo "script-eng-review-check: no build reports under '$reports_dir' — expected coverage is unknown" >&2
    exit 3
  fi
  while IFS= read -r k; do
    [[ -n "$k" ]] && keys+=("$k")
  done < <(derive_keys_from_builds)
  if [[ "${#keys[@]}" -eq 0 ]]; then
    echo "script-eng-review-check: no build reports under '$reports_dir' — expected coverage is unknown" >&2
    exit 3
  fi
else
  while IFS= read -r k; do
    k="$(printf '%s' "$k" | tr -d '[:space:]')"
    [[ -n "$k" ]] && keys+=("$k")
  done < <(printf '%s\n' "$expect_raw" | tr ',' '\n')
  [[ "${#keys[@]}" -gt 0 ]] || { echo "script-eng-review-check: --expect listed no keys" >&2; exit 2; }
fi

covered=0
blocker=0
high=0
medium=0
gaps=0

counted=""   # artifact paths whose severities are already in the totals

for key in "${keys[@]}"; do
  artifact=""
  if [[ "${reports_dir_absent:-0}" -ne 1 ]]; then
    for candidate in "$reports_dir"/review-prd-*-"$key".json; do
      [[ -f "$candidate" ]] || continue
      artifact="$candidate"
      break
    done
    # No artifact of this key's own: a batched wave review may still cover it.
    if [[ -z "$artifact" ]]; then
      artifact="$(find_wave_artifact "$key" 2>/dev/null)"
    fi
  fi

  if [[ -z "$artifact" ]]; then
    echo "MISSING $key"
    gaps=1
    continue
  fi

  if ! parsed="$(read_artifact "$artifact" 2>/dev/null)"; then
    echo "MISSING $key"
    echo "script-eng-review-check: '$artifact' does not parse or lacks verdict/findings — counted missing" >&2
    gaps=1
    continue
  fi

  counts="${parsed%%$'\t'*}"
  rest="${parsed#*$'\t'}"
  reviewed_by="${rest%%$'\t'*}"
  built_by="${rest#*$'\t'}"

  # Severities are a property of the artifact, not of the key: a wave artifact
  # covering three packets contributes its findings once.
  case ",$counted," in
    *",$artifact,"*) ;;
    *)
      read -r b h m <<<"$counts"
      blocker=$((blocker + b))
      high=$((high + h))
      medium=$((medium + m))
      counted="$counted,$artifact"
      ;;
  esac
  covered=$((covered + 1))

  # `built_by` is a comma-joined list on a batched artifact, so membership —
  # not equality — is the test: reviewing a wave you helped build is still
  # self-review.
  if [[ -n "$reviewed_by" && ",$built_by," == *",$reviewed_by,"* ]]; then
    echo "SELF-REVIEWED $key"
    gaps=1
  fi
done

echo "reviewed $covered/${#keys[@]} — $blocker blocker, $high high, $medium medium"
exit "$gaps"

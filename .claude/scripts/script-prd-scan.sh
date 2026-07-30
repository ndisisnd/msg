#!/usr/bin/env bash
# script-prd-scan.sh — deterministic, lane-aware PRD inventory
#
# Emits one JSON object per line (JSONL) for every PRD under features/, including
# nested sub-PRDs. Fields: id, feature, module, platform, status, product_tuned,
# eng_tuned, reviewed, complete, completion (override or derived bucket),
# depends_on[], affects[], parent, created, path, full, missing[].
#
#   full     — true iff the PRD is roadmap-ready: pipeline stamps complete AND a
#              real acceptance-criteria table AND a real execution table. Both
#              tables are located by section TITLE (the same match cert-mech /
#              prd-shape use), never by section number — a renumbered PRD is
#              still a full PRD.
#   missing  — JSON array of the tokens that failed the fullness check, empty when
#              full. Tokens:
#                "stamps"
#                "acceptance-criteria"           no features section at all
#                "acceptance-criteria-unparsed"  section present, zero F-ID rows
#                "exec-table"                    no execution-table section at all
#                "exec-table-unparsed"           section present, zero F-ID rows
#              The `-unparsed` pair distinguishes "the PRD never wrote this table"
#              from "the table is there but nothing in it parsed as a row".
#
# Usage:
#   script-prd-scan.sh                    scan features/ from the project root
#   script-prd-scan.sh --exclude <id>     omit one PRD's own line (id = prd-<n>-<slug>)
#   script-prd-scan.sh --git              refine each `completion` bucket via
#                                              the git/gh ladder (see below)
#
# --exclude drops only the exact PRD id given (a top-level PRD or a sub-PRD); the
# excluded PRD's own nested sub-PRDs, and every other PRD, are still emitted.
#
# --git: without it, `completion` is the cheap frontmatter-derived fallback
# (product / eng / review / retired) — byte-identical to a bare scan. With it,
# `completion` is refined by a most-authoritative-first ladder that DELIBERATELY
# MIRRORS infer_completion() in .claude/skills/msg/refs/gui/server.py (the GUI
# board's H1 ladder). This is a mirror, not shared code — if server.py's ladder
# changes, update this one too. The mirrored vocabulary/semantics:
#     frontmatter `completion:` override        -> that bucket (any lane)
#     staging->prod release PR merged (this id) -> shipped
#     feature->staging PR for feat/<id> merged  -> staged
#     feature->staging PR for feat/<id> open    -> gated
#     branch feat/prd-<n>-* exists              -> building
#     status: eng                               -> planned
#     else                                      -> product
# (`retired` status is preserved ahead of the ladder so the roadmap keeps it in
# Phase 0.) gh rungs fire only when gh is installed, authenticated and a remote
# exists; otherwise the ladder silently degrades to the branch/status rungs with
# ONE stderr note total (never per-PRD, never blocks, exit stays 0). git itself
# absent -> refinement is skipped entirely and today's frontmatter bucket stands.
#
# Shell + awk. Under --git the release branch names come from script-policy-read.py
# (the one policy reader) when python3 and the reader are both available; the
# shell-only grep fallback survives for python-less environments and now says so
# on stderr when it misses over an existing policy file. Run from the project root.
# Unparseable frontmatter is skipped with a note on stderr (exit stays 0).

set -euo pipefail

shopt -s nullglob

# --- flag parse ---------------------------------------------------------------
# No flag → behaviour is byte-identical to a bare scan (apart from the always-on
# full/missing keys). Known flags: --exclude, --git; anything else is a usage
# error on stderr with exit 1.
EXCLUDE=""
GIT_MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --exclude)
      EXCLUDE="${2:-}"
      shift 2 || shift
      ;;
    --exclude=*)
      EXCLUDE="${1#--exclude=}"
      shift
      ;;
    --git)
      GIT_MODE=1
      shift
      ;;
    *)
      echo "usage: script-prd-scan.sh [--exclude <prd-id>] [--git]" >&2
      exit 1
      ;;
  esac
done

# --- git/gh readiness (computed once, never per-PRD) --------------------------
# Mirrors server.py's gh_ready() + release_branches(). Best-effort: any gap
# degrades the ladder, emits at most one stderr note, and never changes exit 0.
GIT_OK=0
GH_OK=0
PROD_BRANCH="main"
STAGING_BRANCH="staging"
GH_TIMEOUT=""
if [[ -n "$GIT_MODE" ]]; then
  if command -v timeout >/dev/null 2>&1; then GH_TIMEOUT="timeout 6"
  elif command -v gtimeout >/dev/null 2>&1; then GH_TIMEOUT="gtimeout 6"; fi

  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    GIT_OK=1
  fi

  # A17 — Release branch names from devkit/policy.json (mirror of
  # release_branches()), with server.py's main/staging fallbacks. Resolved through
  # script-policy-read.py, the ONE reader of policy.json: an ad-hoc grep that
  # missed (nested key, reformatted JSON, a comment) silently handed back `main`
  # and `staging`, and on a `master` repo every PRD's --git rung under-reported.
  # Two-path resolution (repo copy, then the global install), exactly as
  # script-branch-protection.sh does it.
  POLICY_FILE_PATH="${POLICY_FILE:-devkit/policy.json}"
  policy_reader=""
  for cand in ".claude/scripts/script-policy-read.py" "$HOME/.claude/scripts/script-policy-read.py"; do
    [[ -f "$cand" ]] && { policy_reader="$cand"; break; }
  done
  if [[ -n "$policy_reader" ]] && command -v python3 >/dev/null 2>&1; then
    policy_out="$(python3 "$policy_reader" --file "$POLICY_FILE_PATH" 2>/dev/null || true)"
    pb="$(printf '%s\n' "$policy_out" | sed -n 's/^PROD_BRANCH=//p' | head -1)"
    sb="$(printf '%s\n' "$policy_out" | sed -n 's/^STG_BRANCH=//p' | head -1)"
    # NB: plain `if`, not `[[ … ]] && …` — under `set -e` a trailing AND-list
    # whose test fails would abort the whole scan.
    if [[ -n "${pb:-}" ]]; then PROD_BRANCH="$pb"; fi
    # STG_BRANCH is empty under `direct` flow; server.py's release_branches()
    # keeps the "staging" fallback in that case, so this mirror does too.
    if [[ -n "${sb:-}" ]]; then STAGING_BRANCH="$sb"; fi
  elif [[ -f "$POLICY_FILE_PATH" ]]; then
    # Fallback for a python-less environment. Loud on a miss: a policy file that
    # exists but yields no branch names is drift, not a default. The `|| true` is
    # load-bearing — under `set -euo pipefail` a grep that matches nothing used to
    # abort the ENTIRE scan (exit 1, zero PRDs emitted), which is how the old
    # block behaved on any policy.json the grep could not read.
    pb="$(grep -o '"prod_branch"[[:space:]]*:[[:space:]]*"[^"]*"' "$POLICY_FILE_PATH" 2>/dev/null | sed -n '1s/.*"\([^"]*\)"[[:space:]]*$/\1/p' || true)"
    sb="$(grep -o '"staging_branch"[[:space:]]*:[[:space:]]*"[^"]*"' "$POLICY_FILE_PATH" 2>/dev/null | sed -n '1s/.*"\([^"]*\)"[[:space:]]*$/\1/p' || true)"
    if [[ -z "${pb:-}" && -z "${sb:-}" ]]; then
      echo "script-prd-scan: script-policy-read.py unavailable and no prod_branch/staging_branch grepped out of $POLICY_FILE_PATH — falling back to $PROD_BRANCH/$STAGING_BRANCH, which may be wrong for this repo" >&2
    fi
    if [[ -n "${pb:-}" ]]; then PROD_BRANCH="$pb"; fi
    if [[ -n "${sb:-}" ]]; then STAGING_BRANCH="$sb"; fi
  fi

  if [[ "$GIT_OK" == "1" ]]; then
    if command -v gh >/dev/null 2>&1 \
       && git remote 2>/dev/null | grep -q . \
       && $GH_TIMEOUT gh auth status >/dev/null 2>&1; then
      GH_OK=1
    else
      echo "script-prd-scan: gh unavailable/unauthenticated — completion refined from git branches only" >&2
    fi
  else
    echo "script-prd-scan: git unavailable — completion left frontmatter-derived" >&2
  fi
fi

# Run a gh JSON query; succeed only if it returns a non-empty, non-"[]" result.
gh_json_nonempty() {
  local out
  out="$($GH_TIMEOUT "$@" 2>/dev/null)" || return 1
  [[ -n "$out" && "$out" != "[]" ]]
}

emit_prd() {
  local file="$1" parent="$2"

  # --git rung facts (booleans passed into awk, which owns the override/status
  # rungs since it has already parsed the frontmatter).
  local gitmode=0 g_shipped=0 g_staged=0 g_gated=0 g_building=0
  if [[ -n "$GIT_MODE" && "$GIT_OK" == "1" ]]; then
    gitmode=1
    local pdir pbase pnum branch prd_id
    pdir="$(dirname "$file")"
    pbase="$(basename "$pdir")"
    prd_id="$pbase"
    pnum="${pbase#prd-}"
    pnum="${pnum%%[!0-9]*}"          # leading integer; sub-PRDs share the parent branch
    branch=""
    if [[ -n "$pnum" ]]; then
      branch="$(git branch --list "feat/prd-${pnum}-*" 2>/dev/null | sed -n '1{s/^[* ]*//;p;}')"
      [[ -n "$branch" ]] && g_building=1
      if [[ "$GH_OK" == "1" ]]; then
        if gh_json_nonempty gh pr list --base "$PROD_BRANCH" --state merged --search "$prd_id" --json number --limit 1; then g_shipped=1; fi
        if [[ -n "$branch" ]]; then
          if gh_json_nonempty gh pr list --head "$branch" --base "$STAGING_BRANCH" --state merged --json number --limit 1; then g_staged=1; fi
          if gh_json_nonempty gh pr list --head "$branch" --base "$STAGING_BRANCH" --state open --json number --limit 1; then g_gated=1; fi
        fi
      fi
    fi
  fi

  awk -v file="$file" -v parent="$parent" \
      -v gitmode="$gitmode" -v g_shipped="$g_shipped" -v g_staged="$g_staged" \
      -v g_gated="$g_gated" -v g_building="$g_building" '
    function json_escape(s) {
      gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); gsub(/\t/, " ", s)
      return s
    }
    # Convert a YAML inline list "[a, b]" (or bare "a") into a JSON array string.
    function json_list(v,   inner, n, parts, i, out) {
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v == "" || v == "[]") return "[]"
      inner = v
      gsub(/^\[/, "", inner); gsub(/\]$/, "", inner)
      gsub(/^[ \t]+|[ \t]+$/, "", inner)
      if (inner == "") return "[]"
      n = split(inner, parts, ",")
      out = "["
      for (i = 1; i <= n; i++) {
        gsub(/^[ \t]+|[ \t]+$/, "", parts[i])
        gsub(/^["'\''"]|["'\''"]$/, "", parts[i])
        out = out (i > 1 ? "," : "") "\"" json_escape(parts[i]) "\""
      }
      return out "]"
    }
    # A16 — section title normaliser, mirroring script-prd-shape.py norm() and
    # script-cert-mech.py norm_title(): drop the "## ", drop a leading "N. ",
    # lowercase. The section NUMBER is never load-bearing.
    function norm_title(s) {
      sub(/^##[ \t]*/, "", s)
      sub(/^[0-9]+[.][ \t]*/, "", s)
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      return tolower(s)
    }
    BEGIN { infm = 0; seen = 0; insec = ""
            has_f3 = 0; has_f6 = 0; saw_f3_sec = 0; saw_f6_sec = 0 }
    {
      if (NR == 1 && $0 ~ /^---[ \t]*$/) { infm = 1; next }
      if (infm && $0 ~ /^---[ \t]*$/)    { infm = 0; next }   # end frontmatter, read body
      if (infm) {
        line = $0
        # split on the first colon
        idx = index(line, ":")
        if (idx == 0) next
        key = substr(line, 1, idx - 1)
        val = substr(line, idx + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", key)
        gsub(/^[ \t]+|[ \t]+$/, "", val)
        gsub(/[ \t]+#.*$/, "", val)     # strip trailing comments
        fm[key] = val
        seen = 1
        next
      }
      # --- body scan: acceptance-criteria + execution-table completeness ---
      # Track the current H2 section BY TITLE. A real feature/exec row is a table
      # row whose first data cell is an F-ID (F1, F2, …) — this excludes header
      # rows (| ID |, | F-ID |), separators (|----|), and the template placeholders.
      if ($0 ~ /^##[ \t]/) {
        h = norm_title($0)
        # The exec table is tested FIRST: "feature execution table" also starts
        # with "feature" and would otherwise be read as the acceptance table.
        # Legacy unnumbered `## Execution Table` (pre-v5 PRDs) is the same home.
        if (h ~ /^(feature )?execution table/) { insec = "f6"; saw_f6_sec = 1 }
        else if (h ~ /^feature/ || h ~ /acceptance cri/) { insec = "f3"; saw_f3_sec = 1 }
        else insec = ""
        next
      }
      # Acceptance rows read `| F1 | …`; exec rows read `| F1: <name> — <concern> |`.
      # Markdown decoration around the id (`| **F1** |`, `| `F1` |`, `| _F1_ |`)
      # is stripped — a bolded id is still an id, and the old strict regex read a
      # decorated table as an empty one.
      if (insec != "" && $0 ~ /^[|][ \t]*[*_`]*F[0-9]+([.][0-9]+)?[*_`]*[ \t]*[|:]/) {
        if (insec == "f3") has_f3 = 1; else has_f6 = 1
      }
    }
    END {
      if (!seen) { print "script-prd-scan: no frontmatter in " file > "/dev/stderr"; exit 0 }

      status       = ("status"        in fm) ? fm["status"]        : "product"
      reviewed     = ("reviewed"      in fm) ? fm["reviewed"]      : "no"
      completion   = ("completion"    in fm) ? fm["completion"]    : ""
      ptuned       = ("product-tuned" in fm) ? fm["product-tuned"] : "no"
      etuned       = ("eng-tuned"     in fm) ? fm["eng-tuned"]     : "no"

      # Frontmatter-derived "planning pipeline finished" signal: a full PRD has been
      # through product spec + both tunes + eng planning. (status: retired can never
      # satisfy status == "eng", so retired PRDs are complete == false by construction.)
      complete = (status == "eng" && ptuned == "yes" && etuned == "yes") ? "true" : "false"

      # Derive a bucket when no explicit completion override is present.
      # Branch/PR signals are added only under --git below; this is the cheap fallback.
      bucket = completion
      if (bucket == "") {
        if (status == "retired")      bucket = "retired"
        else if (reviewed == "yes")   bucket = "review"
        else if (status == "eng")     bucket = "eng"
        else                          bucket = "product"
      }

      # --git: refine the bucket via the ladder mirrored from server.py. Rung 1
      # (frontmatter override) and the trailing status rungs live here in awk; the
      # git/gh rungs were computed in shell and handed in as g_* booleans.
      if (gitmode == 1) {
        if (completion != "")          bucket = completion    # override wins outright
        else if (status == "retired")  bucket = "retired"     # preserved for roadmap Phase 0
        else if (g_shipped == 1)       bucket = "shipped"
        else if (g_staged == 1)        bucket = "staged"
        else if (g_gated == 1)         bucket = "gated"
        else if (g_building == 1)      bucket = "building"
        else if (status == "eng")      bucket = "planned"
        else                           bucket = "product"
      }

      # --- fullness: pipeline stamps + real acceptance rows + real exec rows ---
      # A16: "the section is missing" and "the section is there but nothing in it
      # parsed" are different defects and now carry different tokens.
      missing = ""
      if (complete != "true") missing = missing (missing == "" ? "" : ",") "\"stamps\""
      if (!has_f3)            missing = missing (missing == "" ? "" : ",") (saw_f3_sec ? "\"acceptance-criteria-unparsed\"" : "\"acceptance-criteria\"")
      if (!has_f6)            missing = missing (missing == "" ? "" : ",") (saw_f6_sec ? "\"exec-table-unparsed\"" : "\"exec-table\"")
      full = (missing == "") ? "true" : "false"

      printf "{"
      printf "\"id\":\"%s\",",         json_escape(("name" in fm) ? fm["name"] : "")
      printf "\"feature\":\"%s\",",    json_escape(("feature" in fm) ? fm["feature"] : "")
      printf "\"module\":\"%s\",",     json_escape(("module" in fm) ? fm["module"] : "")
      printf "\"platform\":\"%s\",",   json_escape(("platform" in fm) ? fm["platform"] : "")
      printf "\"status\":\"%s\",",     json_escape(status)
      printf "\"product_tuned\":\"%s\",", json_escape(ptuned)
      printf "\"eng_tuned\":\"%s\",",  json_escape(etuned)
      printf "\"reviewed\":\"%s\",",   json_escape(reviewed)
      printf "\"complete\":%s,",       complete
      printf "\"completion\":\"%s\",", json_escape(bucket)
      printf "\"depends_on\":%s,",     json_list(("depends_on" in fm) ? fm["depends_on"] : "[]")
      printf "\"affects\":%s,",        json_list(("affects" in fm) ? fm["affects"] : "[]")
      printf "\"parent\":\"%s\",",     json_escape(parent)
      printf "\"created\":\"%s\",",    json_escape(("created" in fm) ? fm["created"] : "")
      printf "\"path\":\"%s\",",       json_escape(file)
      printf "\"full\":%s,",           full
      printf "\"missing\":[%s]",       missing
      printf "}\n"
    }
  ' "$file"
}

[[ -d features ]] || { exit 0; }

# Top-level PRDs, lane-agnostic: a PRD folder lives in exactly one of the three
# lifecycle lanes (planned/wip/done) or at the legacy flat path. Union all four
# and dedupe by PRD id (basename) so a given prd-<n>-<slug> is emitted once —
# lanes are scanned before flat, so the canonical "first hit wins" precedence
# holds if a stale flat copy ever coexists with a lane copy.
#   features/[<lane>/]prd-<n>-<slug>/prd-<n>-<slug>.md
seen_prd=" "   # space-delimited id set (bash 3.2 has no associative arrays)
for dir in features/planned/prd-*/ \
           features/wip/prd-*/ \
           features/done/prd-*/ \
           features/prd-*/; do
  [[ -d "$dir" ]] || continue
  base="${dir%/}"; base="${base##*/}"          # prd-<n>-<slug>
  case "$seen_prd" in *" $base "*) continue ;; esac  # already emitted from an earlier lane
  seen_prd="$seen_prd$base "
  top="$dir$base.md"
  # --exclude drops only the exact id; the excluded PRD's own subs still emit below.
  if [[ -f "$top" && "$base" != "$EXCLUDE" ]]; then
    emit_prd "$top" ""
  fi

  # Nested sub-PRDs travel inside the parent folder (any lane):
  #   features/[<lane>/]prd-<n>-<slug>/prd-<n>.<m>-<subslug>/prd-<n>.<m>-<subslug>.md
  for sub in "$dir"prd-*.*-*/; do
    [[ -d "$sub" ]] || continue
    sbase="${sub%/}"; sbase="${sbase##*/}"      # prd-<n>.<m>-<subslug>
    subfile="$sub$sbase.md"
    if [[ -f "$subfile" && "$sbase" != "$EXCLUDE" ]]; then
      emit_prd "$subfile" "$base"
    fi
  done
done

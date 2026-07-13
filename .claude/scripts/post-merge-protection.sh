#!/usr/bin/env bash
# post-merge-protection.sh — branch-protection bootstrap + verify (C3 / D11).
#
# The machine-enforced half of the v2 safety floor: nothing merges to `staging`
# or `main` without a passing pre-merge CI check, and nothing merges to `main`
# without a human GitHub approval. This script sets and checks that protection
# via `gh api`; post-merge Step 1 runs `--verify` and refuses when unprotected,
# and `/msg --init` offers `--bootstrap` when a GitHub remote exists.
#
# Modes:
#   post-merge-protection.sh --bootstrap                 set protection on staging + main
#   post-merge-protection.sh --bootstrap --contexts "ci/pre-merge,build"
#                                                        ...and require the named status
#                                                        checks to pass before merging
#   post-merge-protection.sh --verify                    check protection on staging + main
#   post-merge-protection.sh --verify main               check one branch only
#
# Protection baseline (per current GitHub REST — branch protection API):
#   staging → required_status_checks{strict:true, contexts:[]}, enforce_admins,
#             restrictions:null, allow_force_pushes:false
#   main    → the same PLUS required_pull_request_reviews with
#             required_approving_review_count:1 (the human-review half of D11)
#
# Machine output (one line per branch):
#   PROTECTED <branch>                     protection matches (verify)
#   UNPROTECTED <branch> <missing,...>     protection absent/incomplete (verify)
#   BOOTSTRAPPED <branch>                  protection applied (bootstrap)
#   BOOTSTRAP_FAILED <branch> <detail>     PUT failed (bootstrap)
#
# Exit codes:
#   0  verify: every checked branch PROTECTED · bootstrap: every branch applied
#   1  verify: at least one branch UNPROTECTED · bootstrap: at least one failed
#   2  environment: NO_GH (gh missing) / NO_REMOTE (no git remote) / usage error

set -uo pipefail

MODE=""
ONLY_BRANCH=""
CONTEXTS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) MODE="bootstrap"; shift ;;
    --verify)    MODE="verify"; shift ;;
    --contexts)  CONTEXTS="${2:-}"; shift 2 ;;
    --*)         echo "post-merge-protection: unknown flag '$1'" >&2; exit 2 ;;
    *)           ONLY_BRANCH="$1"; shift ;;
  esac
done

[[ -z "$MODE" ]] && { echo "post-merge-protection: pass --bootstrap or --verify" >&2; exit 2; }

# ── Environment preconditions (graceful degradation) ──────────────────────────
command -v gh >/dev/null 2>&1 || { echo "NO_GH"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "NO_GH"; exit 2; }
remotes=$(git remote 2>/dev/null)
[[ -z "$remotes" ]] && { echo "NO_REMOTE"; exit 2; }

if [[ -n "$ONLY_BRANCH" ]]; then
  BRANCHES=("$ONLY_BRANCH")
else
  BRANCHES=(staging main)
fi

# JSON payload for a branch. main gets the required-review clause; staging does not.
# --contexts "a,b" names the status checks that must pass before merging (a red
# named check then hard-blocks the PR); default [] enforces only up-to-date-ness.
payload_for() {
  local b="$1" reviews="null" ctx="[]"
  [[ "$b" == "main" ]] && reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":false,"require_code_owner_reviews":false}'
  if [[ -n "$CONTEXTS" ]]; then
    ctx=$(printf '%s' "$CONTEXTS" | tr ',' '\n' | sed 's/^ *//;s/ *$//;/^$/d' | sed 's/.*/"&"/' | paste -sd, - )
    ctx="[${ctx}]"
  fi
  cat <<JSON
{
  "required_status_checks": { "strict": true, "contexts": ${ctx} },
  "enforce_admins": true,
  "required_pull_request_reviews": ${reviews},
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
}

rc=0

if [[ "$MODE" == "bootstrap" ]]; then
  for b in "${BRANCHES[@]}"; do
    if err=$(payload_for "$b" | gh api -X PUT \
        -H "Accept: application/vnd.github+json" \
        "repos/{owner}/{repo}/branches/${b}/protection" \
        --input - 2>&1 >/dev/null); then
      echo "BOOTSTRAPPED $b"
    else
      # Trim to a single line so the machine output stays parseable.
      detail=$(printf '%s' "$err" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-160)
      echo "BOOTSTRAP_FAILED $b ${detail:-put-failed}"
      rc=1
    fi
  done
  exit "$rc"
fi

# ── verify ────────────────────────────────────────────────────────────────────
for b in "${BRANCHES[@]}"; do
  # `@tsv` of the three properties we care about; a 404 (unprotected) fails the call.
  if ! tsv=$(gh api -H "Accept: application/vnd.github+json" \
        "repos/{owner}/{repo}/branches/${b}/protection" \
        -q '[(.required_status_checks != null and .required_status_checks.strict == true),
             (.allow_force_pushes.enabled == false),
             (.required_pull_request_reviews.required_approving_review_count // 0)] | @tsv' \
        2>/dev/null); then
    echo "UNPROTECTED $b no-protection"
    rc=1
    continue
  fi

  IFS=$'\t' read -r has_checks no_force review_count <<<"$tsv"
  missing=""
  [[ "$has_checks" == "true" ]] || missing+="status-checks,"
  [[ "$no_force" == "true" ]] || missing+="force-pushes,"
  if [[ "$b" == "main" ]]; then
    [[ "${review_count:-0}" -ge 1 ]] 2>/dev/null || missing+="required-reviews,"
  fi

  if [[ -z "$missing" ]]; then
    echo "PROTECTED $b"
  else
    echo "UNPROTECTED $b ${missing%,}"
    rc=1
  fi
done

exit "$rc"

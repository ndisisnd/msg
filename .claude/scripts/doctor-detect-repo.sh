#!/usr/bin/env bash
# doctor-detect-repo.sh — repo topology + branch-protection-availability probe.
# Consumed by /pre-merge --doctor and /post-merge --doctor to seed devkit/policy.json's
# `repo` block and `policies.release_flow` (see shared/refs/policy-schema.md and
# update/improve-doctor.md's "post-merge --doctor" section, items 1 + 2).
#
# What the script DOES:
#   - Detects git remote host (github / other / none) from `git remote get-url origin`
#   - Queries GitHub repo visibility via `gh repo view --json visibility,isPrivate`
#     (only when gh is on $PATH and a remote exists)
#   - Probes the branch-protection API on the prod branch and sniffs a 403
#     upgrade-required response — the GitHub Free private-repo limitation — to set
#     branch_protection_available
#   - Detects release-flow topology: local/remote staging-branch existence, the
#     prod/default branch, and a suggested_mode (staged when staging exists, else direct)
#
# What the script does NOT do (left to `--doctor` SKILL.md):
#   - Writing devkit/policy.json — this script only detects and reports
#   - The Free-plan-403 confirm interview (AC-DR5) — SKILL.md gates that decision
#   - Per-branch PROTECTED/UNPROTECTED verification — reuse
#     post-merge-protection.sh --verify for that; this script only answers
#     "is the protection API usable at all on this plan/repo"
#   - Creating the staging branch — that's /msg --init-staging's job
#
# Usage:    doctor-detect-repo.sh [project-root]    (default: .)
# Output:   single JSON object to stdout
# Exit:     0 always (detection is non-fatal); errors → stderr

set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (brew install jq)" >&2
  exit 1
fi

# ---------- helpers ----------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------- environment preconditions ----------
in_git_repo=false
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git_repo=true

remote_url=""
if [[ "$in_git_repo" == true ]]; then
  remote_url=$(git remote get-url origin 2>/dev/null || true)
fi
has_remote=false
[[ -n "$remote_url" ]] && has_remote=true

has_gh=false
has_cmd gh && has_gh=true

# ---------- host ----------
host="none"
if [[ "$has_remote" == true ]]; then
  if [[ "$remote_url" == *github.com* ]]; then
    host="github"
  else
    host="other"
  fi
fi

# ---------- prod_branch (used by release_flow AND the protection probe) ----------
prod_branch=""
if [[ "$has_remote" == true ]]; then
  sym=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)
  [[ -n "$sym" ]] && prod_branch="${sym#refs/remotes/origin/}"
fi

# ---------- visibility + branch_protection_available + detected_via ----------
visibility="unknown"
branch_protection_available="null"   # tri-state: true | false | null (jq literal)
detected_via="no gh"

if [[ "$has_gh" == false ]]; then
  detected_via="no gh"
elif [[ "$has_remote" == false ]]; then
  detected_via="no remote"
else
  vis_json=$(gh repo view --json visibility,isPrivate,defaultBranchRef 2>/dev/null || true)
  if [[ -z "$vis_json" ]]; then
    detected_via="gh api → repo view failed (auth/network)"
  else
    v=$(jq -r '.visibility // empty' <<<"$vis_json" | tr '[:upper:]' '[:lower:]')
    [[ -n "$v" ]] && visibility="$v"

    # fall back to gh's default branch when no local origin/HEAD symref exists
    if [[ -z "$prod_branch" ]]; then
      db=$(jq -r '.defaultBranchRef.name // empty' <<<"$vis_json")
      [[ -n "$db" ]] && prod_branch="$db"
    fi
    probe_branch="${prod_branch:-main}"

    # Probe the branch-protection API and sniff a 403 upgrade-required response.
    probe_err=$(gh api -H "Accept: application/vnd.github+json" \
        "repos/{owner}/{repo}/branches/${probe_branch}/protection" 2>&1 >/dev/null)
    probe_status=$?
    if [[ $probe_status -eq 0 ]]; then
      branch_protection_available=true
      detected_via="gh api → 200 (protection readable on ${probe_branch})"
    elif grep -qi '403' <<<"$probe_err" && grep -qi 'upgrade' <<<"$probe_err"; then
      branch_protection_available=false
      detected_via="gh api → 403 upgrade-required"
    elif grep -qi '404' <<<"$probe_err"; then
      # 404 means no protection is SET on that branch, not that the API is
      # unavailable — the API itself is usable on this plan.
      branch_protection_available=true
      detected_via="gh api → 404 (no protection set, API available)"
    else
      branch_protection_available="null"
      detected_via="gh api → probe inconclusive"
    fi
  fi
fi

[[ -z "$prod_branch" ]] && prod_branch="main"

# ---------- release_flow: staging-branch existence (local + remote) ----------
staging_local=false
[[ "$in_git_repo" == true ]] && git show-ref --verify --quiet refs/heads/staging && staging_local=true

staging_remote=false
if [[ "$has_remote" == true ]]; then
  git ls-remote --exit-code --heads origin staging >/dev/null 2>&1 && staging_remote=true
fi

staging_branch_exists=false
if [[ "$staging_local" == true || "$staging_remote" == true ]]; then
  staging_branch_exists=true
fi

suggested_mode="direct"
[[ "$staging_branch_exists" == true ]] && suggested_mode="staged"

release_flow=$(jq -nc \
  --argjson staging_branch_exists "$staging_branch_exists" \
  --arg prod_branch "$prod_branch" \
  --arg suggested_mode "$suggested_mode" \
  '{staging_branch_exists: $staging_branch_exists, prod_branch: $prod_branch, suggested_mode: $suggested_mode}')

# ---------- emit ----------
jq -n \
  --arg host "$host" \
  --arg visibility "$visibility" \
  --argjson branch_protection_available "$branch_protection_available" \
  --arg detected_via "$detected_via" \
  --argjson release_flow "$release_flow" \
  '{
    host: $host,
    visibility: $visibility,
    branch_protection_available: $branch_protection_available,
    detected_via: $detected_via,
    release_flow: $release_flow
  }'

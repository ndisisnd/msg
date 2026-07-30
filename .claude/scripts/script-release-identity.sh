#!/usr/bin/env bash
# script-release-identity.sh — READ-ONLY release identity resolver for
# post-merge --production: current tag, next version, build, monotonicity,
# version regression, provenance.
#
# The version source of truth is the newest `v*` tag reachable on prod —
# never a VERSION file, never a bump commit. This script only READS: it never
# tags, never pushes, never fetches. `--production` Step 5's own fetch is what
# makes a post-merge run's numbers tag-time truth; run this after it for the
# authoritative pass, before it for the Step-3 confirm preview.
#
# Contract: .claude/skills/post-merge/refs/release-identity.md
#
# Usage:
#   script-release-identity.sh [--prod <branch>] [--remote <name>]
#                              [--bump major|minor|patch] [--version <x.y.z>]
#                              [--probe-sha <sha>] [--repo <dir>]
#
#   --prod       production branch (default: main)
#   --remote     remote whose tracking ref is read (default: origin; falls back
#                to the local branch when no remote-tracking ref exists)
#   --bump       semver level (default: minor — post-merge ships features)
#   --version    exact next version; must be STRICTLY GREATER than the current
#                tag's version, else VERSION_REGRESSION=true
#   --probe-sha  a platform `version_probe`'s reported commit, for provenance
#   --repo       repo dir (default: $PWD)
#
# Checks, all deterministic:
#   1. Tag parse       — v<major>.<minor>.<patch>[+<build>], newest first
#   2. Version bump    — default minor; major/patch/explicit honoured
#   3. Build recompute — commit count on prod (monotonic by construction)
#   4. Monotonicity    — BUILD > the current tag's build (legacy tags with no
#                        `+<build>` fall back to `rev-list --count <tag>`)
#   5. Version regress — an explicit --version not strictly greater
#   6. Provenance      — --probe-sha inside CURRENT_TAG..prod (or equal to prod)
#
# Output (stdout, KEY=VALUE lines, always the full key set):
#   VERDICT=ok|version_regression|nonmonotonic_build|provenance_fail
#   PROD_REF=<ref read>            e.g. origin/main
#   PROD_SHA=<sha>
#   CURRENT_TAG=<v…|>              empty ⇒ no release yet
#   CURRENT_VERSION=<x.y.z>        0.0.0 when there is no tag
#   CURRENT_BUILD=<n>
#   NEXT_VERSION=<x.y.z>
#   BUMP=major|minor|patch|explicit
#   BUILD=<n>                      commit count on prod, right now
#   NEXT_TAG=v<x.y.z>+<build>      what Step 9 would cut
#   VERSION_REGRESSION=true|false
#   NONMONOTONIC_BUILD=true|false
#   PROVENANCE=verified|asserted_unverified|fail
#   PROBE_SHA=<sha|>
#
# NONMONOTONIC_BUILD is `submission`-only policy: `deploy` platforms carry no
# store build contract, so the caller ignores that key for them. This script
# reports the fact; which platforms it gates is the caller's read.
#
# Exit codes:
#   0  VERDICT=ok
#   3  VERDICT=version_regression   (refuse — resolved early, before the lock)
#   4  VERDICT=nonmonotonic_build   (refuse before a submission's submit)
#   5  VERDICT=provenance_fail      (fail the ship — the merge already stands)
#   2  usage error / not a git repo / unresolvable prod ref
#
# Precedence when several trip: version_regression > nonmonotonic_build >
# provenance_fail — earliest gate wins, and every key is still emitted.

set -uo pipefail

SELF="$(basename "$0")"

usage() {
  echo "usage: $SELF [--prod <branch>] [--remote <name>] [--bump major|minor|patch] [--version <x.y.z>] [--probe-sha <sha>] [--repo <dir>]" >&2
  exit 2
}
die() { echo "$SELF: $1" >&2; exit 2; }

REPO="$PWD"; PROD="main"; REMOTE="origin"; BUMP="minor"; EXPLICIT=""; PROBE_SHA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prod)        [[ $# -ge 2 ]] || usage; PROD="$2"; shift 2 ;;
    --prod=*)      PROD="${1#--prod=}"; shift ;;
    --remote)      [[ $# -ge 2 ]] || usage; REMOTE="$2"; shift 2 ;;
    --remote=*)    REMOTE="${1#--remote=}"; shift ;;
    --bump)        [[ $# -ge 2 ]] || usage; BUMP="$2"; shift 2 ;;
    --bump=*)      BUMP="${1#--bump=}"; shift ;;
    --version)     [[ $# -ge 2 ]] || usage; EXPLICIT="$2"; shift 2 ;;
    --version=*)   EXPLICIT="${1#--version=}"; shift ;;
    --probe-sha)   [[ $# -ge 2 ]] || usage; PROBE_SHA="$2"; shift 2 ;;
    --probe-sha=*) PROBE_SHA="${1#--probe-sha=}"; shift ;;
    --repo)        [[ $# -ge 2 ]] || usage; REPO="$2"; shift 2 ;;
    --repo=*)      REPO="${1#--repo=}"; shift ;;
    -h|--help)     sed -n '2,70p' "$0"; exit 0 ;;
    *) usage ;;
  esac
done

case "$BUMP" in major|minor|patch) ;; *) die "bad --bump: $BUMP" ;; esac
[[ -d "$REPO" ]] || die "not a directory: $REPO"
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository: $REPO"
g() { git -C "$REPO" "$@"; }

PROD_REF="$REMOTE/$PROD"
PROD_SHA="$(g rev-parse --verify --quiet "$PROD_REF^{commit}" 2>/dev/null || true)"
if [[ -z "$PROD_SHA" ]]; then
  PROD_REF="$PROD"
  PROD_SHA="$(g rev-parse --verify --quiet "$PROD^{commit}" 2>/dev/null || true)"
fi
[[ -n "$PROD_SHA" ]] || die "cannot resolve prod ref: $REMOTE/$PROD or $PROD"

# 1 · Current tag — newest v* reachable on prod. A tag on an unmerged branch is
#     not a release, hence --merged.
CURRENT_TAG="$(g tag --list 'v*' --merged "$PROD_REF" --sort=-v:refname 2>/dev/null | head -1)"

parse_ver() {                      # v2.2.0+417 -> 2.2.0
  local t="${1#v}"; printf '%s' "${t%%+*}"
}

if [[ -n "$CURRENT_TAG" ]]; then
  CURRENT_VERSION="$(parse_ver "$CURRENT_TAG")"
  case "$CURRENT_TAG" in
    *+*) CURRENT_BUILD="${CURRENT_TAG##*+}" ;;
    *)   CURRENT_BUILD="$(g rev-list --count "$CURRENT_TAG" 2>/dev/null || echo 0)" ;;   # legacy tag, no +<build>
  esac
else
  CURRENT_VERSION="0.0.0"; CURRENT_BUILD=0
fi
[[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]] || CURRENT_BUILD=0

IFS='.' read -r CMAJ CMIN CPAT <<<"$CURRENT_VERSION"
CMAJ=${CMAJ:-0}; CMIN=${CMIN:-0}; CPAT=${CPAT:-0}

# 2 · Next version.
VERSION_REGRESSION=false
if [[ -n "$EXPLICIT" ]]; then
  [[ "$EXPLICIT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "bad --version (want x.y.z): $EXPLICIT"
  NEXT_VERSION="$EXPLICIT"; BUMP="explicit"
  IFS='.' read -r NMAJ NMIN NPAT <<<"$NEXT_VERSION"
  if (( NMAJ < CMAJ )) \
     || (( NMAJ == CMAJ && NMIN < CMIN )) \
     || (( NMAJ == CMAJ && NMIN == CMIN && NPAT <= CPAT )); then
    VERSION_REGRESSION=true
  fi
else
  case "$BUMP" in
    major) NEXT_VERSION="$((CMAJ + 1)).0.0" ;;
    minor) NEXT_VERSION="${CMAJ}.$((CMIN + 1)).0" ;;
    patch) NEXT_VERSION="${CMAJ}.${CMIN}.$((CPAT + 1))" ;;
  esac
fi

# 3 · Build — commit count on prod as it stands right now.
BUILD="$(g rev-list --count "$PROD_SHA" 2>/dev/null || echo 0)"
NEXT_TAG="v${NEXT_VERSION}+${BUILD}"

# 4 · Monotonicity.
NONMONOTONIC_BUILD=false
(( BUILD > CURRENT_BUILD )) || NONMONOTONIC_BUILD=true

# 6 · Provenance.
if [[ -z "$PROBE_SHA" ]]; then
  PROVENANCE=asserted_unverified
else
  PSHA="$(g rev-parse --verify --quiet "$PROBE_SHA^{commit}" 2>/dev/null || true)"
  if [[ -z "$PSHA" ]]; then
    PROVENANCE=fail
  elif ! g merge-base --is-ancestor "$PSHA" "$PROD_SHA" 2>/dev/null; then
    PROVENANCE=fail                                    # not even on prod
  elif [[ -n "$CURRENT_TAG" ]] && g merge-base --is-ancestor "$PSHA" "$CURRENT_TAG" 2>/dev/null; then
    PROVENANCE=fail                                    # already shipped in a prior release
  else
    PROVENANCE=verified
  fi
fi

VERDICT=ok; RC=0
if [[ "$VERSION_REGRESSION" == true ]]; then VERDICT=version_regression; RC=3
elif [[ "$NONMONOTONIC_BUILD" == true ]]; then VERDICT=nonmonotonic_build; RC=4
elif [[ "$PROVENANCE" == fail ]]; then VERDICT=provenance_fail; RC=5
fi

cat <<EOF
VERDICT=$VERDICT
PROD_REF=$PROD_REF
PROD_SHA=$PROD_SHA
CURRENT_TAG=$CURRENT_TAG
CURRENT_VERSION=$CURRENT_VERSION
CURRENT_BUILD=$CURRENT_BUILD
NEXT_VERSION=$NEXT_VERSION
BUMP=$BUMP
BUILD=$BUILD
NEXT_TAG=$NEXT_TAG
VERSION_REGRESSION=$VERSION_REGRESSION
NONMONOTONIC_BUILD=$NONMONOTONIC_BUILD
PROVENANCE=$PROVENANCE
PROBE_SHA=$PROBE_SHA
EOF
exit $RC

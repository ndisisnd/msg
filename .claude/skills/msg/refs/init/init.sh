#!/usr/bin/env bash
# Deterministic template writer for /msg --init.
#
# Usage: init.sh <target_dir>
#
# Required env vars (set by the skill after the interview steps):
#   PROJECT_NAME         Q1 name
#   PROJECT_DESCRIPTION  Q1 one-line description
#   PLATFORM             Q2 answer ("Web (frontend)", "Backend API", "CLI", "Mobile (iOS/Android)")
#   LANGUAGE             Q2b answer (e.g. "TypeScript", "Swift (iOS)", "Kotlin (Android)")
#   CONVENTIONS          house conventions (cto derives them; eng falls back to the default below)
#   ARCH_OVERVIEW        A1 — system components and how they interact
#   ARCH_EXTERNAL        A2 — external services and APIs
#   ARCH_DATA_STORES     A3 — databases, caches, queues
#   ARCH_AUTH            A4 — authentication approach
#   ARCH_DEPLOYMENT      A5 — deployment pipeline
#   DS_LIBRARY           D2 — component library
#   DS_TOKENS            D3 — design token locations
#   DS_CONVENTIONS       D4 — component naming / folder conventions
#
# Optional env var:
#   INTERACTIVE_LANES    Set "true" by /msg --update's classification step —
#                         ambiguous flat PRDs are left in place and reported via
#                         UNRESOLVED instead of being defaulted to "planned".
#
# Writes only files absent from <target_dir>. Exits non-zero if any write fails.
# Prints a manifest to stdout.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS="$SCRIPT_DIR/templates"
TARGET="${1:-.}"

# Fallbacks for missing env vars
PROJECT_NAME="${PROJECT_NAME:-$(basename "$TARGET")}"
PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION:-Project bootstrapped with /msg --init.}"
PLATFORM="${PLATFORM:-Not specified — fill in later.}"
LANGUAGE="${LANGUAGE:-Not specified — fill in later.}"
CONVENTIONS="${CONVENTIONS:-None recorded yet. Add house conventions as they emerge.}"
ARCH_OVERVIEW="${ARCH_OVERVIEW:-[USER: describe the major components of the system and how they interact]}"
ARCH_EXTERNAL="${ARCH_EXTERNAL:-[USER: list external services, APIs, and their dependencies]}"
ARCH_DATA_STORES="${ARCH_DATA_STORES:-[USER: list databases, caches, queues, blob stores, and what each holds]}"
ARCH_AUTH="${ARCH_AUTH:-[USER: authentication model]}"
ARCH_DEPLOYMENT="${ARCH_DEPLOYMENT:-[USER: CI/CD pipeline and environments]}"
DS_LIBRARY="${DS_LIBRARY:-[USER: note any external component library in use and the version pinned]}"
DS_TOKENS="${DS_TOKENS:-[USER: list colour, spacing, typography tokens and where they live]}"
DS_CONVENTIONS="${DS_CONVENTIONS:-[USER: naming conventions, folder structure rules, theming approach, and any constraints on adding new components]}"

CREATED=(); SKIPPED=(); FAILED=(); MOVED=(); UNRESOLVED=()

# When true (set by /msg --update's interactive PRD-classification step), rung 3
# of migrate_lane_for stops silently defaulting ambiguous PRDs to "planned" and
# instead reports them via UNRESOLVED for the caller to ask the user about.
INTERACTIVE_LANES="${INTERACTIVE_LANES:-false}"

# ── Helpers ───────────────────────────────────────────────────────────────────

apply_subs() {
  sed \
    -e "s|{{project_name}}|${PROJECT_NAME}|g" \
    -e "s|{{project_description}}|${PROJECT_DESCRIPTION}|g" \
    -e "s|{{platform}}|${PLATFORM}|g" \
    -e "s|{{language}}|${LANGUAGE}|g" \
    -e "s|{{conventions}}|${CONVENTIONS}|g" \
    -e "s|{{arch_overview}}|${ARCH_OVERVIEW}|g" \
    -e "s|{{arch_external}}|${ARCH_EXTERNAL}|g" \
    -e "s|{{arch_data_stores}}|${ARCH_DATA_STORES}|g" \
    -e "s|{{arch_auth}}|${ARCH_AUTH}|g" \
    -e "s|{{arch_deployment}}|${ARCH_DEPLOYMENT}|g" \
    -e "s|{{ds_library}}|${DS_LIBRARY}|g" \
    -e "s|{{ds_tokens}}|${DS_TOKENS}|g" \
    -e "s|{{ds_conventions}}|${DS_CONVENTIONS}|g"
}

# Extract content inside the ```...``` block that follows "## Template body"
extract_body() {
  awk '
    /^## Template body/ { in_section=1; next }
    in_section && /^```/ && !in_block { in_block=1; next }
    in_section && in_block && /^```/ { exit }
    in_section && in_block { print }
  ' "$1"
}

# Strip YAML frontmatter (--- ... ---); print everything after the second ---
strip_frontmatter() {
  awk 'BEGIN{n=0} /^---/{n++; next} n>=2{print}' "$1"
}

# Write content string to TARGET/<filename>; track in manifest arrays.
# Using a content variable (not stdin) so array writes happen in the main shell.
# Pass a subdirectory as $3 (e.g. "devkit") to write into TARGET/<subdir>/<filename>.
write_file() {
  local filename="$1"
  local content="$2"
  local subdir="${3:-}"
  local dest
  if [[ -n "$subdir" ]]; then
    dest="$TARGET/$subdir/$filename"
    filename="$subdir/$filename"
  else
    dest="$TARGET/$filename"
  fi

  if [[ -e "$dest" ]]; then
    SKIPPED+=("$filename")
    return 0
  fi

  # printf '%s\n' re-adds the single trailing newline stripped by $()
  if printf '%s\n' "$content" | sed 's/[[:space:]]*$//' > "$dest"; then
    local lines; lines=$(wc -l < "$dest" | tr -d ' ')
    CREATED+=("$filename|$lines")
  else
    FAILED+=("$filename")
  fi
}

# ── devkit/ directory ─────────────────────────────────────────────────────────

if [[ -d "$TARGET/devkit" ]]; then
  SKIPPED+=("devkit/")
elif mkdir -p "$TARGET/devkit"; then
  CREATED+=("devkit/|—")
else
  FAILED+=("devkit/")
fi

# ── Root-level templates (fenced ## Template body blocks) ─────────────────────
# README.md and CLAUDE.md stay at project root; .gitignore and CHANGELOG.md too.
# INTAKE.md is the root backlog ledger (D13 — repo root, not devkit); the block
# has no placeholders, so apply_subs is a harmless no-op.

for pair in \
  "README.md:template-README.md" \
  "CLAUDE.md:template-CLAUDE.md" \
  "INTAKE.md:TEMPLATE-INTAKE.md"
do
  f="${pair%%:*}"; t="${pair##*:}"
  content=$(extract_body "$REFS/$t" | apply_subs)
  write_file "$f" "$content"
done

# ── devkit/ templates (fenced ## Template body blocks) ────────────────────────

for pair in \
  "ARCHITECTURE.md:template-ARCHITECTURE.md" \
  "DESIGN-SYSTEM.md:template-DESIGN-SYSTEM.md"
do
  f="${pair%%:*}"; t="${pair##*:}"
  content=$(extract_body "$REFS/$t" | apply_subs)
  write_file "$f" "$content" "devkit"
done

# ── devkit/ flat templates (strip frontmatter; no placeholders) ───────────────

for pair in \
  "AHA.md:template-AHA.md" \
  "GLOSSARY.md:template-GLOSSARY.md" \
  "OPEN-QUESTIONS.md:template-OPEN-QUESTIONS.md"
do
  f="${pair%%:*}"; t="${pair##*:}"
  content=$(strip_frontmatter "$REFS/$t")
  write_file "$f" "$content" "devkit"
done

# ── devkit/PLATFORMS.md (B3 — pre-merge tolerance profiles) ────────────────────
# Assembled from the template's ## Doc body preamble + one ### <platform> default
# row per shipping platform selected at the --init interview (PLATFORMS env var).

if [[ -e "$TARGET/devkit/PLATFORMS.md" ]]; then
  SKIPPED+=("devkit/PLATFORMS.md")
else
  pf="$REFS/template-PLATFORMS.md"

  preamble=$(awk '
    /^## Doc body/ { in_section=1; next }
    in_section && /^```/ && !in_block { in_block=1; next }
    in_section && in_block && /^```/ { exit }
    in_section && in_block { print }
  ' "$pf")

  # Shipping platforms: interview answer (space/comma separated, any case);
  # default to all four baked-in profiles so the scaffold is complete and prunable.
  plats="${PLATFORMS:-web ios android macos}"
  plats=$(printf '%s' "$plats" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')

  rows=""
  for p in $plats; do
    row=$(awk -v hdr="### $p" '
      $0 == hdr { found=1; next }
      found && /^\|/ { print; exit }
      found && /^### / { exit }
    ' "$pf")
    [[ -n "$row" ]] && rows+="$row"$'\n'
  done

  {
    printf '%s\n' "$preamble"
    printf '%s' "$rows"
  } | sed 's/[[:space:]]*$//' > "$TARGET/devkit/PLATFORMS.md"

  lines=$(wc -l < "$TARGET/devkit/PLATFORMS.md" | tr -d ' ')
  CREATED+=("devkit/PLATFORMS.md|$lines")
fi

# ── Root-level flat templates ─────────────────────────────────────────────────

for pair in \
  "CHANGELOG.md:template-CHANGELOG.md"
do
  f="${pair%%:*}"; t="${pair##*:}"
  content=$(strip_frontmatter "$REFS/$t")
  write_file "$f" "$content"
done

# ── .gitignore ────────────────────────────────────────────────────────────────

if [[ -e "$TARGET/.gitignore" ]]; then
  SKIPPED+=(".gitignore")
else
  gf="$REFS/template-gitignore.md"

  universal=$(awk '
    /^## Universal section/ { in_section=1; next }
    in_section && /^```/ && !in_block { in_block=1; next }
    in_section && in_block && /^```/ { exit }
    in_section && in_block { print }
  ' "$gf")

  # Language-specific sections take priority; fall back to platform.
  # Lowercase LANGUAGE for case-insensitive matching of free-text input.
  lang_lc=$(printf '%s' "$LANGUAGE" | tr '[:upper:]' '[:lower:]')
  case "$lang_lc" in
    flutter*|dart*) stack_pat="^### Dart / Flutter" ;;
    *)
      case "$PLATFORM" in
        "Web (frontend)"*)  stack_pat="^### Web" ;;
        "Mobile"*)          stack_pat="^### Mobile" ;;
        "Backend API"*)     stack_pat="^### Backend API" ;;
        "CLI"*)             stack_pat="^### CLI" ;;
        *)                  stack_pat="" ;;
      esac
      ;;
  esac

  stack_content=""
  if [[ -n "$stack_pat" ]]; then
    stack_content=$(awk -v pat="$stack_pat" '
      $0 ~ pat { in_section=1; next }
      in_section && /^```/ && !in_block { in_block=1; next }
      in_section && in_block && /^```/ { exit }
      in_section && in_block { print }
    ' "$gf")
  fi

  {
    printf '%s\n' "$universal"
    if [[ -n "$stack_content" ]]; then
      printf '\n# Stack: %s\n%s\n' "$PLATFORM" "$stack_content"
    fi
  } | sed 's/[[:space:]]*$//' > "$TARGET/.gitignore"

  lines=$(wc -l < "$TARGET/.gitignore" | tr -d ' ')
  CREATED+=(".gitignore|$lines")
fi

# ── features/ lifecycle lanes ─────────────────────────────────────────────────
# Three lanes mirror the pipeline stage — planned (drafted), wip (in build),
# done (shipped). Each carries a tracked .gitkeep so the empty lane commits.
# Idempotent: a lane that already exists is skipped, never emptied or recreated.

for lane in planned wip done; do
  lane_dir="$TARGET/features/$lane"
  if [[ -d "$lane_dir" ]]; then
    SKIPPED+=("features/$lane/")
  elif mkdir -p "$lane_dir" && : > "$lane_dir/.gitkeep"; then
    CREATED+=("features/$lane/|—")
  else
    FAILED+=("features/$lane/")
  fi
done

# ── .claude/msg/ execution-mode preference ────────────────────────────────────
# The persisted team/solo planning execution mode consumed by plan-em (Step 0).
# Seeded here so /msg --init owns first-run creation and /msg --update tops it up
# on repos bootstrapped before it existed. Deterministic — no interview input;
# default is "team" (the pipeline default), flipped anytime via plan-em --solo/--team.
# Schema + consumers: .claude/skills/shared/refs/exec-mode-pref.md.

if [[ -e "$TARGET/.claude/msg/pref.json" ]]; then
  SKIPPED+=(".claude/msg/pref.json")
elif mkdir -p "$TARGET/.claude/msg" && printf '%s\n' '{"exec_mode": "team"}' > "$TARGET/.claude/msg/pref.json"; then
  CREATED+=(".claude/msg/pref.json|1")
else
  FAILED+=(".claude/msg/pref.json")
fi

# ── features/ flat-PRD migration (change 6) ───────────────────────────────────
# One-time sort of any pre-lane flat PRD dirs — features/prd-<n>-<slug>/ sitting
# directly under features/, not already inside a lane — into a lane by the GUI
# completion ladder:
#   merged staging->prod release PR (or a shipped tag) that names the PRD → done/
#   a live unshipped feat/prd-<n>-* branch (local or remote)             → wip/
#   otherwise                                                            → planned/
# git mv when the dir is tracked (history-preserving rename); plain mv otherwise.
# Idempotent: a PRD already inside a lane is never matched, and a brand-new repo
# with an empty features/ matches nothing and migrates nothing.

migrate_lane_for() {
  # $1 = flat PRD dir basename (prd-<n>-<slug>); echoes planned|wip|done.
  local base="$1" num prd_id prod_branch out
  num=$(printf '%s' "$base" | sed -E 's/^prd-([0-9]+).*/\1/')
  prd_id="$base"

  # Rung 1 — shipped: a merged staging->prod PR that names this PRD, or a git tag
  # that references it.
  if command -v gh >/dev/null 2>&1 && git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
    prod_branch=$(git -C "$TARGET" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
    [[ -z "$prod_branch" ]] && prod_branch=main
    out=$(gh pr list --base "$prod_branch" --state merged --search "$prd_id" --json number --limit 1 2>/dev/null)
    if [[ -n "$out" && "$out" != "[]" ]]; then
      printf 'done\n'; return
    fi
  fi
  if git -C "$TARGET" tag --list "*prd-${num}-*" 2>/dev/null | grep -q .; then
    printf 'done\n'; return
  fi

  # Rung 2 — wip: a live feat/prd-<n>-* branch (local or remote) exists.
  if git -C "$TARGET" branch -a --list "feat/prd-${num}-*" "*/feat/prd-${num}-*" 2>/dev/null | grep -q .; then
    printf 'wip\n'; return
  fi

  # Rung 3 — ambiguous (drafted-but-unbuilt, no evidence either way). Under
  # /msg --update's interactive mode, defer to the user instead of guessing.
  if [[ "$INTERACTIVE_LANES" == "true" ]]; then
    printf 'ask\n'; return
  fi
  printf 'planned\n'
}

if [[ -d "$TARGET/features" ]]; then
  for prd_dir in "$TARGET"/features/prd-*/; do
    [[ -d "$prd_dir" ]] || continue          # no flat PRDs → glob stays literal
    base=$(basename "$prd_dir")
    [[ "$base" == prd-* ]] || continue
    lane=$(migrate_lane_for "$base")
    if [[ "$lane" == "ask" ]]; then
      UNRESOLVED+=("$base")
      continue
    fi
    dest="$TARGET/features/$lane/$base"
    if [[ -e "$dest" ]]; then
      SKIPPED+=("features/$lane/$base/")   # already sorted — leave it alone
      continue
    fi
    if [[ -n "$(git -C "$TARGET" ls-files "features/$base" 2>/dev/null)" ]]; then
      if git -C "$TARGET" mv "features/$base" "features/$lane/$base" >/dev/null 2>&1; then
        MOVED+=("features/$base → features/$lane/$base")
      else
        FAILED+=("features/$base → features/$lane/")
      fi
    elif mv "$prd_dir" "$dest" 2>/dev/null; then
      MOVED+=("features/$base → features/$lane/$base")
    else
      FAILED+=("features/$base → features/$lane/")
    fi
  done
fi

# ── Manifest ──────────────────────────────────────────────────────────────────

printf '\nmsg --init complete — %d created, %d skipped, %d migrated, %d failed.\n\n' \
  "${#CREATED[@]}" "${#SKIPPED[@]}" "${#MOVED[@]}" "${#FAILED[@]}"

echo "UNRESOLVED=${UNRESOLVED[*]:-none}"

printf '%-36s %-22s %s\n' "File" "Status" "Lines"
printf '%-36s %-22s %s\n' "----" "------" "-----"

for entry in "${CREATED[@]}"; do
  printf '%-36s %-22s %s\n' "${entry%%|*}" "created" "${entry##*|}"
done
for name in "${SKIPPED[@]}"; do
  printf '%-36s %-22s %s\n' "$name" "skipped (exists)" "—"
done
for name in "${MOVED[@]}"; do
  printf '%-36s %-22s %s\n' "$name" "migrated (git mv)" "—"
done
for name in "${FAILED[@]}"; do
  printf '%-36s %-22s %s\n' "$name" "FAILED" "—" >&2
done

[[ ${#FAILED[@]} -eq 0 ]]

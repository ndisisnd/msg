#!/usr/bin/env bash
# Deterministic template writer for msg-init.
#
# Usage: init.sh <target_dir>
#
# Required env vars (set by the skill after the Step 2 interview):
#   PROJECT_NAME         Q1 name
#   PROJECT_DESCRIPTION  Q1 one-line description
#   PLATFORM             Q2 answer ("Web (frontend)", "Backend API", "CLI", "Mobile (iOS/Android)")
#   LANGUAGE             Q2b answer (e.g. "TypeScript", "Swift (iOS)", "Kotlin (Android)")
#   TEAM_TYPE            Q3 answer
#   CONVENTIONS          Q4 answer
#
# Writes only files absent from <target_dir>. Exits non-zero if any write fails.
# Prints a manifest to stdout.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS="$SCRIPT_DIR/refs"
TARGET="${1:-.}"

# Fallbacks for missing env vars
PROJECT_NAME="${PROJECT_NAME:-$(basename "$TARGET")}"
PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION:-Project bootstrapped with msg-init.}"
PLATFORM="${PLATFORM:-Not specified — fill in later.}"
LANGUAGE="${LANGUAGE:-Not specified — fill in later.}"
TEAM_TYPE="${TEAM_TYPE:-Solo}"
CONVENTIONS="${CONVENTIONS:-None recorded yet. Add house conventions as they emerge.}"

CREATED=(); SKIPPED=(); FAILED=()

# ── Helpers ───────────────────────────────────────────────────────────────────

apply_subs() {
  sed \
    -e "s|{{project_name}}|${PROJECT_NAME}|g" \
    -e "s|{{project_description}}|${PROJECT_DESCRIPTION}|g" \
    -e "s|{{platform}}|${PLATFORM}|g" \
    -e "s|{{language}}|${LANGUAGE}|g" \
    -e "s|{{team_type}}|${TEAM_TYPE}|g" \
    -e "s|{{conventions}}|${CONVENTIONS}|g"
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
write_file() {
  local filename="$1"
  local content="$2"
  local dest="$TARGET/$filename"

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

# ── Templates with fenced ## Template body blocks ────────────────────────────

for pair in \
  "README.md:template-README.md" \
  "CLAUDE.md:template-CLAUDE.md" \
  "ARCHITECTURE.md:template-ARCHITECTURE.md" \
  "DESIGN-SYSTEM.md:template-DESIGN-SYSTEM.md"
do
  f="${pair%%:*}"; t="${pair##*:}"
  content=$(extract_body "$REFS/$t" | apply_subs)
  write_file "$f" "$content"
done

# ── Flat templates (strip frontmatter; no placeholders) ───────────────────────

for pair in \
  "AHA.md:template-AHA.md" \
  "GLOSSARY.md:template-GLOSSARY.md"
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
    [[ -n "$stack_content" ]] && printf '\n# Stack: %s\n%s\n' "$PLATFORM" "$stack_content"
  } | sed 's/[[:space:]]*$//' > "$TARGET/.gitignore"

  lines=$(wc -l < "$TARGET/.gitignore" | tr -d ' ')
  CREATED+=(".gitignore|$lines")
fi

# ── features/ directory ───────────────────────────────────────────────────────

if [[ -d "$TARGET/features" ]]; then
  SKIPPED+=("features/")
elif mkdir -p "$TARGET/features"; then
  CREATED+=("features/|—")
else
  FAILED+=("features/")
fi

# ── Manifest ──────────────────────────────────────────────────────────────────

printf '\nmsg-init complete — %d created, %d skipped, %d failed.\n\n' \
  "${#CREATED[@]}" "${#SKIPPED[@]}" "${#FAILED[@]}"

printf '%-20s %-22s %s\n' "File" "Status" "Lines"
printf '%-20s %-22s %s\n' "----" "------" "-----"

for entry in "${CREATED[@]}"; do
  printf '%-20s %-22s %s\n' "${entry%%|*}" "created" "${entry##*|}"
done
for name in "${SKIPPED[@]}"; do
  printf '%-20s %-22s %s\n' "$name" "skipped (exists)" "—"
done
for name in "${FAILED[@]}"; do
  printf '%-20s %-22s %s\n' "$name" "FAILED" "—" >&2
done

[[ ${#FAILED[@]} -eq 0 ]]

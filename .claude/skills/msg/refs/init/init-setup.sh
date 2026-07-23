#!/usr/bin/env bash
# Scans target directory for /msg --init foundational files and stack hints.
#
# Usage: init-setup.sh <target_dir>
#
# Outputs key=value lines to stdout; always exits 0.
#   ALL_COMPLETE=true|false
#   PRESENT=<space-separated filenames, or "none">
#   MISSING=<space-separated filenames, or "none">
#   STACK_HINTS=<space-separated filenames, or "none">
#   STACK_DEFAULT=<Q2 platform string, or "Not specified">
#   LANG_DEFAULT=<Q2b language/framework string, or "Not specified">
#   INITIALISED=true|false   devkit/ exists → this repo was bootstrapped before
#   ROW_GAPS=<space-separated file:row tokens, or "none">

TARGET="${1:-.}"

# Every file /msg --init is responsible for. This list gates ALL_COMPLETE, so a
# file missing from it can never be noticed on an already-bootstrapped repo — the
# protocol stops at "nothing to initialise" before init.sh gets a chance to write
# it. Anything init.sh (or the skill) creates MUST be listed here.
TARGETS=(devkit/AHA.md devkit/GLOSSARY.md devkit/ARCHITECTURE.md devkit/DESIGN-SYSTEM.md devkit/OPEN-QUESTIONS.md devkit/PLATFORMS.md devkit/policy.json README.md .gitignore CLAUDE.md CHANGELOG.md INTAKE.md features/planned/ features/wip/ features/done/)
STACK_FILES=(package.json tsconfig.json Cargo.toml go.mod pyproject.toml Gemfile pom.xml build.gradle Podfile pubspec.yaml)

PRESENT=(); MISSING=(); STACK_DETECTED=()

for t in "${TARGETS[@]}"; do
  [[ -e "$TARGET/$t" ]] && PRESENT+=("$t") || MISSING+=("$t")
done

for s in "${STACK_FILES[@]}"; do
  [[ -e "$TARGET/$s" ]] && STACK_DETECTED+=("$s")
done

stack_default="Not specified"
for s in "${STACK_DETECTED[@]}"; do
  case "$s" in
    package.json|tsconfig.json) stack_default="Web (frontend)";      break ;;
    pubspec.yaml|Podfile)       stack_default="Mobile (iOS/Android)"; break ;;
    Cargo.toml)                 stack_default="CLI";                  break ;;
    go.mod|pyproject.toml|Gemfile|pom.xml|build.gradle)
                                stack_default="Backend API";          break ;;
  esac
done

# The same stack files are a language list in disguise — recover the signal
# stack_default throws away by collapsing each file to a platform. Feeds Q2b,
# which eng mode asks ONLY when this comes back "Not specified" (the empty-repo
# bootstrap case, where there is nothing to detect from).
# package.json is deliberately unmapped — it names no language on its own; a
# TypeScript repo is identified by tsconfig.json, which follows it in STACK_FILES.
lang_default="Not specified"
for s in "${STACK_DETECTED[@]}"; do
  case "$s" in
    pubspec.yaml)         lang_default="Dart / Flutter" ;;
    Cargo.toml)           lang_default="Rust"           ;;
    go.mod)               lang_default="Go"             ;;
    tsconfig.json)        lang_default="TypeScript"     ;;
    pyproject.toml)       lang_default="Python"         ;;
    Gemfile)              lang_default="Ruby"           ;;
    pom.xml|build.gradle) lang_default="Java / Kotlin"  ;;
  esac
  [[ "$lang_default" != "Not specified" ]] && break
done

all_complete=false
[[ ${#MISSING[@]} -eq 0 ]] && all_complete=true

# devkit/ is created only by /msg --init, so its presence means this repo was
# bootstrapped by an earlier version — the top-up case, not a fresh bootstrap.
initialised=false
[[ -d "$TARGET/devkit" ]] && initialised=true

# Row gaps: a file that EXISTS but predates a template row added since it was
# written. Additive only — each token names a row to add, never one to change.
# Extend by adding a check here; the token is <file>:<row-key>.
ROW_GAPS=()
if [[ -e "$TARGET/CLAUDE.md" ]] && ! grep -q '^- \*\*Language\*\*:' "$TARGET/CLAUDE.md" 2>/dev/null; then
  ROW_GAPS+=("CLAUDE.md:language")
fi

echo "ALL_COMPLETE=$all_complete"
echo "PRESENT=${PRESENT[*]:-none}"
echo "MISSING=${MISSING[*]:-none}"
echo "STACK_HINTS=${STACK_DETECTED[*]:-none}"
echo "STACK_DEFAULT=$stack_default"
echo "LANG_DEFAULT=$lang_default"
echo "INITIALISED=$initialised"
echo "ROW_GAPS=${ROW_GAPS[*]:-none}"

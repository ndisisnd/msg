#!/usr/bin/env bash
# eng-comment-scan.sh — A4 plain-English-comment scan (deterministic, zero-LLM).
#
# For each added/modified source file in a diff, flags added symbol-declaration
# lines (function / def / class / export / public-API declarations across common
# languages) that have NO comment line immediately above them in the new file.
# A heuristic grep, not a parser: false-negative-tolerant, low-false-positive.
#
# Usage:
#   eng-comment-scan.sh --staged            scan the staged diff
#   eng-comment-scan.sh <git-diff-range>    scan a range, e.g. HEAD~1..HEAD or main...HEAD
#
# Machine output:
#   UNCOMMENTED <file>:<line> <symbol>      one line per flagged declaration
#   COMMENT_SCAN <n> uncommented symbol(s) in <f> file(s)   summary (flags present)
#   COMMENT_SCAN clean                                      summary (no flags)
#
# Exit: 0 = clean, 1 = flags present, 2 = usage/environment error.

set -uo pipefail

command -v git >/dev/null 2>&1 || { echo "eng-comment-scan: git not available" >&2; exit 2; }

if [[ "${1:-}" == "--staged" ]]; then
  DIFF=(git diff --cached)
elif [[ -n "${1:-}" ]]; then
  DIFF=(git diff "$1")
else
  echo "usage: eng-comment-scan.sh (--staged | <git-diff-range>)" >&2
  exit 2
fi

"${DIFF[@]}" --no-color --no-ext-diff -U3 | awk '
function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function is_blank(s){ return s ~ /^[ \t]*$/ }
function is_comment(s,   t){ t=s; sub(/^[ \t]+/, "", t); return (t ~ /^(\/\/|#|\/\*|\*|<!--|--|;)/) }
function is_symbol(s,   t){
  t=s; sub(/^[ \t]+/, "", t)
  if (t ~ /^(export[ \t]+)?default[ \t]/) return 1
  if (t ~ /(^|[ \t])(function|def|fn|func|class|struct|interface|trait|impl|enum|protocol|extension|mixin|module|object)([ \t(<:]|$)/) return 1
  if (t ~ /(^|[ \t])(const|let|var)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*[ \t]*[:=].*=>/) return 1
  if (t ~ /(^|[ \t])type[ \t]+[A-Za-z_$][A-Za-z0-9_$]*[ \t]*=/) return 1
  return 0
}
# New file header — decide whether this file is in scope.
/^\+\+\+ / {
  f=$0; sub(/^\+\+\+ b\//, "", f); sub(/^\+\+\+ /, "", f)
  scan = (f ~ /\.(js|jsx|ts|tsx|mjs|cjs|py|go|rs|swift|kt|kts|dart|rb|java)$/) \
      && (f !~ /(^|\/)(node_modules|vendor|dist|build|generated|__generated__|fixtures|__fixtures__|testdata)\//) \
      && (f !~ /(\.min\.|\.generated\.|\.g\.dart$|\.freezed\.dart$|\.pb\.go$)/)
  prev1=""; prev2=""; nl=0
  next
}
/^--- / { next }
/^@@ / {
  m=$0; sub(/^.*\+/, "", m); split(m, a, /[, ]/); nl=a[1]+0; prev1=""; prev2=""
  next
}
!scan { next }
/^-/ { next }                 # removed line: no effect on the new file
{
  pfx=substr($0,1,1); content=substr($0,2)
  if (pfx=="+") {
    if (is_comment(content) || is_blank(content)) { prev2=prev1; prev1=content; nl++; next }
    if (is_symbol(content)) {
      ok = is_comment(prev1) || (is_blank(prev1) && is_comment(prev2))
      if (!ok) { print "UNCOMMENTED " f ":" nl " " trim(content); count++; flagged[f]=1 }
    }
    prev2=prev1; prev1=content; nl++
    next
  }
  if (pfx==" ") { prev2=prev1; prev1=content; nl++; next }
}
END {
  nf=0; for (x in flagged) nf++
  if (count>0) { print "COMMENT_SCAN " count " uncommented symbol(s) in " nf " file(s)"; exit 1 }
  print "COMMENT_SCAN clean"; exit 0
}
'
exit ${PIPESTATUS[1]}

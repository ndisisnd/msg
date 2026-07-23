#!/usr/bin/env bash
# plan-pm-roadmap-scan.sh — deterministic PRD inventory for plan-pm --roadmap
#
# Emits one JSON object per line (JSONL) for every PRD under features/, including
# nested sub-PRDs. Fields: id, feature, module, platform, status, product_tuned,
# eng_tuned, reviewed, completion (override or derived bucket), depends_on[],
# affects[], parent, created, path.
#
# Usage:
#   plan-pm-roadmap-scan.sh            scan features/ from the project root
#
# Pure shell + awk; no Python dependency. Run from the project root.
# Unparseable frontmatter is skipped with a note on stderr (exit stays 0).

set -euo pipefail

shopt -s nullglob

emit_prd() {
  local file="$1" parent="$2"
  awk -v file="$file" -v parent="$parent" '
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
    BEGIN { infm = 0; seen = 0 }
    {
      if (NR == 1 && $0 ~ /^---[ \t]*$/) { infm = 1; next }
      if (infm && $0 ~ /^---[ \t]*$/) { infm = 0; done = 1; exit }
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
      }
    }
    END {
      if (!seen) { print "plan-pm-roadmap-scan: no frontmatter in " file > "/dev/stderr"; exit 0 }

      status       = ("status"        in fm) ? fm["status"]        : "product"
      reviewed     = ("reviewed"      in fm) ? fm["reviewed"]      : "no"
      completion   = ("completion"    in fm) ? fm["completion"]    : ""
      ptuned       = ("product-tuned" in fm) ? fm["product-tuned"] : "no"
      etuned       = ("eng-tuned"     in fm) ? fm["eng-tuned"]     : "no"

      # Frontmatter-derived "planning pipeline finished" signal: a full PRD has been
      # through product spec + both tunes + eng planning. Section-level completeness
      # (§6 acceptance criteria, §7 exec rows) is confirmed by the reading protocol.
      complete = (status == "eng" && ptuned == "yes" && etuned == "yes") ? "true" : "false"

      # Derive a bucket when no explicit completion override is present.
      # Branch/PR signals are computed by the GUI server; this is the cheap fallback.
      bucket = completion
      if (bucket == "") {
        if (status == "retired")      bucket = "retired"
        else if (reviewed == "yes")   bucket = "review"
        else if (status == "eng")     bucket = "eng"
        else                          bucket = "product"
      }

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
      printf "\"path\":\"%s\"",        json_escape(file)
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
  [[ -f "$top" ]] && emit_prd "$top" ""

  # Nested sub-PRDs travel inside the parent folder (any lane):
  #   features/[<lane>/]prd-<n>-<slug>/prd-<n>.<m>-<subslug>/prd-<n>.<m>-<subslug>.md
  for sub in "$dir"prd-*.*-*/; do
    [[ -d "$sub" ]] || continue
    sbase="${sub%/}"; sbase="${sbase##*/}"      # prd-<n>.<m>-<subslug>
    subfile="$sub$sbase.md"
    [[ -f "$subfile" ]] && emit_prd "$subfile" "$base"
  done
done

#!/usr/bin/env python3
"""
plan-em-exec-skeleton.py — deterministic exec-table skeleton renderer (no LLM).

Given a msg PRD and an assignment spec on stdin, resolves each F-ID against the
PRD's §3 Features & acceptance criteria table and renders the complete execution
table skeleton markdown for the PRD's §6 Feature execution table (Step 3). The
LLM still decides the (feature, concern, agent) tuples and hands them in as the
spec; this script only renders them, so anchor typos and row-text drift are
impossible. See template-exec-table.md and template-prd.md §3/§6 for the shapes
consumed/produced.

Usage:
  echo '[{"fid":"F1","concern":"API contract","agent":"backend-eng"}]' \\
    | plan-em-exec-skeleton.py [--write] <prd.md>

  --write   write the table into the PRD's reserved "## N. Feature execution
            table" section in place (the exec table's ONE home), replacing the
            "_To be populated by plan-em …_" placeholder and any blank skeleton
            table already there. Without it the table only goes to stdout.

Stdin: a JSON array of {"fid","concern","agent"} objects, in row order.
Stdout: the skeleton table — header + separator + one row per spec entry:
  | Feature | Execution steps | Files | Todos | Agent |
  Feature cell = "<fid>: <name> — <concern>"; Execution steps + Files blank;
  Todos = "[F<n>](#todos-f<n>)" (lowercase anchor); Agent = the spec agent.
  With --write, stdout carries "WROTE <prd> section=<heading> rows=<n>" instead.

Exit codes:
  0 = table rendered (or written).
  1 = a spec fid is absent from §3, or --write found no reserved
      "Feature execution table" section (named on stderr; nothing written).
  2 = malformed JSON on stdin / usage / unreadable or unwritable PRD.
"""
import sys, re, json

HEADER = "| Feature | Execution steps | Files | Todos | Agent |"
SEP    = "|---------|----------------|-------|-------|-------|"


def die(msg, code):
    sys.stderr.write("plan-em-exec-skeleton: %s\n" % msg)
    sys.exit(code)


def read_lines(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read().splitlines()
    except OSError as e:
        die("cannot read PRD: %s" % e, 2)


def parse_features(lines):
    """Return {ID_UPPER: (canonical_ID, feature_name)} from the PRD §3 table."""
    # Locate the §3 "Features & acceptance criteria" heading (number-agnostic).
    start = None
    hdr = re.compile(r"^##\s+.*features\s*&\s*acceptance", re.I)
    for i, ln in enumerate(lines):
        if hdr.match(ln):
            start = i + 1
            break
    if start is None:
        return {}

    # Gather until the next level-2 heading.
    block = []
    for ln in lines[start:]:
        if re.match(r"^##\s+", ln):
            break
        block.append(ln)

    # Parse the first markdown table in the block.
    headers, rows = None, []
    for ln in block:
        s = ln.strip()
        if not s.startswith("|"):
            if headers is not None:
                break          # table ended
            continue
        if re.match(r"^[\s:|-]+$", s.replace("|", "")):
            continue           # separator row
        cells = [c.strip() for c in s.strip("|").split("|")]
        if headers is None:
            headers = [c.lower() for c in cells]
        else:
            rows.append(cells)
    if headers is None:
        return {}

    def col(*names):
        for idx, h in enumerate(headers):
            if h in names:
                return idx
        return None

    id_col, feat_col = col("id", "f-id"), col("feature")
    if id_col is None or feat_col is None:
        return {}

    out = {}
    for cells in rows:
        if len(cells) <= max(id_col, feat_col):
            continue
        fid = cells[id_col].strip()
        name = cells[feat_col].strip()
        if fid:
            out[fid.upper()] = (fid, name)
    return out


# Heading of the exec table's ONE home. Number-agnostic, and tolerant of the
# legacy unnumbered "## Execution Table" so a pre-v5 PRD can still be rewritten.
EXEC_HDR = re.compile(r"^##\s+(?:\d+\.\s*)?(?:Feature execution table|Execution Table)\s*$",
                      re.I)
PLACEHOLDER = re.compile(r"^_To be populated by plan-em\b.*_$", re.I)


def write_section(prd, lines, rows):
    """Replace the reserved exec-table section's body with the rendered table."""
    start = None
    for i, ln in enumerate(lines):
        if EXEC_HDR.match(ln):
            start = i
            break
    if start is None:
        die("no '## N. Feature execution table' section in %s — the exec table has one "
            "home and it is missing; restore it from template-prd.md" % prd, 1)

    end = len(lines)
    for j in range(start + 1, len(lines)):
        if re.match(r"^##\s+", lines[j]):
            end = j
            break

    kept = []
    for ln in lines[start + 1:end]:
        s = ln.strip()
        if not s:
            continue
        if PLACEHOLDER.match(s) or s.startswith("|") or s.startswith("```"):
            continue          # old placeholder / blank skeleton / fence
        kept.append(ln.rstrip())

    body = kept + ([""] if kept else []) + [HEADER, SEP] + rows
    new = lines[:start + 1] + [""] + body + [""] + lines[end:]
    try:
        with open(prd, "w", encoding="utf-8") as fh:
            fh.write("\n".join(new).rstrip("\n") + "\n")
    except OSError as e:
        die("cannot write PRD: %s" % e, 2)
    sys.stdout.write("WROTE %s section=%s rows=%d\n"
                     % (prd, lines[start].lstrip("# ").strip(), len(rows)))


def main():
    argv = sys.argv[1:]
    write = False
    if "--write" in argv:
        write = True
        argv = [a for a in argv if a != "--write"]
    if len(argv) != 1:
        die("usage: plan-em-exec-skeleton.py [--write] <prd.md>", 2)
    prd = argv[0]

    try:
        spec = json.loads(sys.stdin.read())
    except json.JSONDecodeError as e:
        die("malformed JSON on stdin: %s" % e, 2)
    if not isinstance(spec, list):
        die("spec must be a JSON array", 2)

    lines = read_lines(prd)
    feats = parse_features(lines)

    rows = []
    for entry in spec:
        if not isinstance(entry, dict):
            die("each spec entry must be a JSON object", 2)
        fid = str(entry.get("fid", "")).strip()
        concern = str(entry.get("concern", "")).strip()
        agent = str(entry.get("agent", "")).strip()
        if not fid:
            die("spec entry missing 'fid'", 2)
        rec = feats.get(fid.upper())
        if rec is None:
            die("fid '%s' not present in §3 Features & acceptance criteria table" % fid, 1)
        canon, name = rec
        anchor = canon.lower()
        rows.append("| %s: %s — %s | | | [%s](#todos-%s) | %s |"
                    % (canon, name, concern, canon, anchor, agent))

    if write:
        write_section(prd, lines, rows)
    else:
        sys.stdout.write("\n".join([HEADER, SEP] + rows) + "\n")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
plan-em-exec-skeleton.py — deterministic exec-table skeleton renderer (no LLM).

Given a msg PRD and an assignment spec on stdin, resolves each F-ID against the
PRD's §6 Features & acceptance criteria table and renders the complete Execution
Table skeleton markdown that plan-em appends to the PRD (Step 3). The LLM still
decides the (feature, concern, agent) tuples and hands them in as the spec; this
script only renders them, so anchor typos and row-text drift are impossible. See
template-exec-table.md and template-prd.md §6 for the shapes consumed/produced.

Usage:
  echo '[{"fid":"F1","concern":"API contract","agent":"backend-eng"}]' \\
    | plan-em-exec-skeleton.py <prd.md>

Stdin: a JSON array of {"fid","concern","agent"} objects, in row order.
Stdout: the skeleton table — header + separator + one row per spec entry:
  | Feature | Execution steps | Files | Todos | Agent |
  Feature cell = "<fid>: <name> — <concern>"; Execution steps + Files blank;
  Todos = "[F<n>](#todos-f<n>)" (lowercase anchor); Agent = the spec agent.

Exit codes:
  0 = table rendered.
  1 = a spec fid is absent from §6 (named on stderr; no output emitted).
  2 = malformed JSON on stdin / usage / unreadable PRD.
"""
import sys, re, json

HEADER = "| Feature | Execution steps | Files | Todos | Agent |"
SEP    = "|---------|----------------|-------|-------|-------|"


def die(msg, code):
    sys.stderr.write("plan-em-exec-skeleton: %s\n" % msg)
    sys.exit(code)


def parse_features(path):
    """Return {ID_UPPER: (canonical_ID, feature_name)} from the PRD §6 table."""
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError as e:
        die("cannot read PRD: %s" % e, 2)

    # Locate the §6 "Features & acceptance criteria" heading (number-agnostic).
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


def main():
    if len(sys.argv) != 2:
        die("usage: plan-em-exec-skeleton.py <prd.md>", 2)
    prd = sys.argv[1]

    try:
        spec = json.loads(sys.stdin.read())
    except json.JSONDecodeError as e:
        die("malformed JSON on stdin: %s" % e, 2)
    if not isinstance(spec, list):
        die("spec must be a JSON array", 2)

    feats = parse_features(prd)

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
            die("fid '%s' not present in §6 Features & acceptance criteria table" % fid, 1)
        canon, name = rec
        anchor = canon.lower()
        rows.append("| %s: %s — %s | | | [%s](#todos-%s) | %s |"
                    % (canon, name, concern, canon, anchor, agent))

    sys.stdout.write("\n".join([HEADER, SEP] + rows) + "\n")


if __name__ == "__main__":
    main()

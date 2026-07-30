#!/usr/bin/env python3
"""
script-ledger.py — the writer for a PRD's §7 "Plan tune findings" ledger.

Owns everything about the ledger that is decidable: locating (or creating) the
section, deduping this run's findings against prior rows, assigning the monotonic
`#`, and emitting the Clean marker row when a run finds nothing. The model decides
*what* the findings are and hands them over as JSON; it never counts rows, never
picks a row number, and never hand-writes the table.

The column set is a contract shared with `/msg --gui` and `plan-pm`'s
`template-prd.md`. This script never changes it: an existing table whose header is
missing a canonical column is a hard error, not something to patch around.

Usage:
  script-ledger.py <prd.md> --auditor P|E [--findings <file.json>|-] [--date YYYY-MM-DD] [--dry-run]

  --auditor    P (product tune) or E (eng tune). Written into every new row.
  --findings   JSON array of this run's findings. Default: stdin.
  --date       defaults to today.
  --dry-run    report what would change and write nothing.

Findings JSON — an array of objects:
  [{"severity": "Critical|Major|Minor",
    "what":     "terse: section + which check fired",
    "fix":      "terse concrete action",
    "why":      "terse: the consumer that breaks"}]
  An empty array is the no-findings path and produces the Clean marker row.

Dedup rule (mechanical half): an incoming finding whose `what` normalizes to the
same text as an existing row's "What is wrong" is the SAME issue carried forward —
that row is updated in place (Status -> Still open, Date -> today) and no new row
is added. Everything else is new and gets a fresh monotonic `#`. Judging whether a
prior finding was really fixed stays with the model: it simply omits the finding.

New rows are sorted Critical, Major, Minor before numbering, so `#` ascends with
severity within a run while staying monotonic across runs.

Output (KEY=VALUE lines on stdout):
  LEDGER_SECTION=created|filled|appended
  LEDGER_ROW=<#> <added|carried> <severity>      one per finding
  LEDGER_ADDED=<n>
  LEDGER_CARRIED=<n>
  LEDGER_CLEAN=yes|no
  LEDGER_NEXT=<the next free # after this run>

Exit codes:
  0  ledger written (or --dry-run plan emitted)
  2  usage error, unreadable PRD, malformed findings JSON, or an existing table
     whose header is missing a canonical column

Writes via a temp file + mv, so a crash can never truncate the PRD.
"""
import argparse
import datetime
import json
import os
import re
import sys
import tempfile
from pathlib import Path

SELF = "script-ledger"

COLUMNS = ["#", "Date", "Auditor", "Severity", "What is wrong",
           "Suggested fix", "Why it matters", "Status"]
SEV_ORDER = {"critical": 0, "major": 1, "minor": 2}
SECTION_TITLE = "Plan tune findings"


def die(msg):
    print(f"{SELF}: {msg}", file=sys.stderr)
    sys.exit(2)


def cell(text):
    """Table-safe cell: one line, pipes escaped."""
    s = " ".join(str(text or "").split())
    return s.replace("|", "\\|")


def norm(text):
    """Dedup key for a 'What is wrong' cell."""
    s = str(text or "").replace("\\|", "|").lower()
    s = re.sub(r"[`*_]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s.rstrip(".;,")


def split_row(line):
    """Split a markdown table row on unescaped pipes."""
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|") and not s.endswith("\\|"):
        s = s[:-1]
    out, buf, i = [], "", 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s) and s[i + 1] == "|":
            buf += "\\|"
            i += 2
            continue
        if s[i] == "|":
            out.append(buf.strip())
            buf = ""
            i += 1
            continue
        buf += s[i]
        i += 1
    out.append(buf.strip())
    return out


def is_separator(line):
    return re.match(r"^\|[\s:|-]+\|?\s*$", line.strip()) is not None


def heading_title(line):
    """'## 7. Plan tune findings' -> 'plan tune findings'; None if not an H2."""
    m = re.match(r"^##\s+(.*?)\s*$", line)
    if not m:
        return None
    return re.sub(r"^\d+(\.\d+)?\.\s*", "", m.group(1)).strip().lower()


def find_section(lines, name):
    """Return (heading_idx, end_idx) for the H2 whose title starts with `name`."""
    for i, ln in enumerate(lines):
        t = heading_title(ln)
        if t is not None and t.startswith(name):
            end = len(lines)
            for j in range(i + 1, len(lines)):
                m = re.match(r"^(#{1,2})\s", lines[j])
                if m:
                    end = j
                    break
            return i, end
    return None, None


def render(values):
    return "| " + " | ".join(values) + " |"


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-ledger.py")
    ap.add_argument("prd")
    ap.add_argument("--auditor", required=True, choices=["P", "E"])
    ap.add_argument("--findings", default="-")
    ap.add_argument("--date", default="")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    date = args.date or datetime.date.today().isoformat()
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", date):
        die(f"--date must be YYYY-MM-DD, got: {date}")

    prd = Path(args.prd)
    if not prd.is_file():
        die(f"no such PRD file: {args.prd}")
    try:
        text = prd.read_text(encoding="utf-8")
    except OSError as exc:
        die(f"cannot read {args.prd}: {exc}")
    lines = text.split("\n")

    raw = sys.stdin.read() if args.findings == "-" else Path(args.findings).read_text(encoding="utf-8")
    if not raw.strip():
        die("no findings JSON on stdin (send [] for the no-findings path)")
    try:
        findings = json.loads(raw)
    except json.JSONDecodeError as exc:
        die(f"findings JSON is malformed: {exc}")
    if not isinstance(findings, list):
        die("findings JSON must be an array")
    for n, f in enumerate(findings, start=1):
        if not isinstance(f, dict):
            die(f"finding {n} is not an object")
        sev = str(f.get("severity", "")).strip().lower()
        if sev not in SEV_ORDER:
            die(f"finding {n}: severity must be Critical|Major|Minor, got: {f.get('severity')!r}")
        if not str(f.get("what", "")).strip():
            die(f"finding {n}: 'what' is required and must be non-empty")

    # ── Locate the section and read any existing table ────────────────────────
    hidx, hend = find_section(lines, SECTION_TITLE.lower())
    header_cells, existing_rows, tbl_start, tbl_end = None, [], None, None
    if hidx is not None:
        for j in range(hidx + 1, hend):
            s = lines[j].strip()
            if s.startswith("|"):
                if tbl_start is None:
                    tbl_start = j
                tbl_end = j
            elif tbl_start is not None and s:
                break
        if tbl_start is not None:
            for j in range(tbl_start, tbl_end + 1):
                if is_separator(lines[j]):
                    continue
                cells = split_row(lines[j])
                if header_cells is None:
                    header_cells = cells
                else:
                    existing_rows.append((j, cells))

    if header_cells is not None:
        lowered = [c.strip().lower() for c in header_cells]
        colmap = {}
        for want in COLUMNS:
            if want.lower() not in lowered:
                die(f"§7 table header is missing the '{want}' column — the schema is a "
                    f"GUI + template contract; fix the table rather than writing into it")
            colmap[want] = lowered.index(want.lower())
    else:
        colmap = {c: i for i, c in enumerate(COLUMNS)}

    def get(cells, col):
        i = colmap[col]
        return cells[i] if i < len(cells) else ""

    # ── Dedup + numbering ─────────────────────────────────────────────────────
    by_what = {}
    highest = 0
    for j, cells in existing_rows:
        by_what.setdefault(norm(get(cells, "What is wrong")), (j, cells))
        m = re.match(r"^\d+$", get(cells, "#").strip())
        if m:
            highest = max(highest, int(get(cells, "#").strip()))

    carried, fresh = [], []
    for f in findings:
        hit = by_what.get(norm(f.get("what")))
        (carried if hit else fresh).append((f, hit))

    fresh.sort(key=lambda p: SEV_ORDER[str(p[0]["severity"]).strip().lower()])

    edits = {}   # line index -> replacement line (carried-forward updates)
    for f, (j, cells) in carried:
        row = list(cells) + [""] * (len(COLUMNS) - len(cells))
        row[colmap["Status"]] = "Still open"
        row[colmap["Date"]] = date
        edits[j] = render(row)

    new_lines_rows, num = [], highest
    report = []
    for f, _ in carried:
        j, cells = by_what[norm(f.get("what"))]
        report.append((get(cells, "#") or "?", "carried", str(f["severity"]).strip().title()))

    for f, _ in fresh:
        num += 1
        row = [""] * len(COLUMNS)
        row[colmap["#"]] = str(num)
        row[colmap["Date"]] = date
        row[colmap["Auditor"]] = args.auditor
        row[colmap["Severity"]] = str(f["severity"]).strip().title()
        row[colmap["What is wrong"]] = cell(f.get("what"))
        row[colmap["Suggested fix"]] = cell(f.get("fix")) or "—"
        row[colmap["Why it matters"]] = cell(f.get("why")) or "—"
        row[colmap["Status"]] = cell(f.get("status")) or "Open"
        new_lines_rows.append(render(row))
        report.append((str(num), "added", row[colmap["Severity"]]))

    clean = not findings
    if clean:
        num += 1
        row = [""] * len(COLUMNS)
        row[colmap["#"]] = str(num)
        row[colmap["Date"]] = date
        row[colmap["Auditor"]] = args.auditor
        row[colmap["Severity"]] = "—"
        row[colmap["What is wrong"]] = "No findings; all applicable checks certified"
        row[colmap["Suggested fix"]] = "—"
        row[colmap["Why it matters"]] = "—"
        row[colmap["Status"]] = "Clean"
        new_lines_rows.append(render(row))
        report.append((str(num), "added", "Clean"))

    # ── Apply ─────────────────────────────────────────────────────────────────
    out = list(lines)
    for j, repl in edits.items():
        out[j] = repl

    header_line = render([c for c in header_cells] if header_cells else COLUMNS)
    sep_line = "|" + "|".join("---" for _ in COLUMNS) + "|"

    if header_cells is not None:
        mode = "appended"
        out[tbl_end + 1:tbl_end + 1] = new_lines_rows
    elif hidx is not None:
        mode = "filled"
        body = [header_line, sep_line] + new_lines_rows
        # Replace the section body (placeholder prose and all) with the table.
        out[hidx + 1:hend] = [""] + body + [""]
    else:
        mode = "created"
        block = ["", f"## {SECTION_TITLE}", "", header_line, sep_line] + new_lines_rows + [""]
        # Canonical home is the reserved section between the exec table and Todos;
        # on a legacy PRD that lacks it, insert before Todos, else append.
        tidx, _ = find_section(out, "todos")
        if tidx is not None:
            out[tidx:tidx] = block
        else:
            while out and out[-1].strip() == "":
                out.pop()
            out.extend(block)

    print(f"LEDGER_SECTION={mode}")
    for num_s, what, sev in report:
        print(f"LEDGER_ROW={num_s} {what} {sev}")
    print(f"LEDGER_ADDED={len(new_lines_rows)}")
    print(f"LEDGER_CARRIED={len(carried)}")
    print(f"LEDGER_CLEAN={'yes' if clean else 'no'}")
    print(f"LEDGER_NEXT={num + 1}")

    if args.dry_run:
        return

    fd, tmp = tempfile.mkstemp(dir=str(prd.parent), prefix=".script-ledger.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write("\n".join(out))
        os.chmod(tmp, os.stat(prd).st_mode & 0o777)
        os.replace(tmp, prd)
    except OSError as exc:
        if os.path.exists(tmp):
            os.unlink(tmp)
        die(f"cannot write {args.prd}: {exc}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
script-ledger.py — the writer for a PRD's plan-review findings ledger.

Owns everything about the ledger that is decidable: locating (or creating) the
table, matching this run's findings against prior rows, honouring each
finding's status, clearing prior rows whose check ran clean, assigning the
monotonic `#`, and emitting the Clean marker row when a run finds nothing. The
model decides *what* the findings are and whether each one was fixed, and hands
them over as JSON once, after its fixes; it never counts rows, never picks a row
number, and never hand-writes the table.

WHERE THE LEDGER LIVES (two targets, auto-selected)

  The report beside the PRD:   <prd-dir>/reports/review-<prd-stem>.md
  An older PRD's own `## 7. Plan review findings` section, kept where it is with
  its eight-column (Auditor-bearing) table. Nothing is ever migrated.

Selection order: an existing report file wins; else an existing findings section
in the PRD; else a new report file is created (this script writes the scaffold).

Do not confuse the report with `reports/review-prd-<N>-<K>.json` — that is eng's
per-packet build-review evidence, a different file with a different shape.

The column set is a contract shared with `/msg --gui`. This script never changes
it: an existing table whose header is missing a canonical column is a hard
error, not something to patch around.

Usage:
  script-ledger.py <prd.md> [--auditor P|E] [--checks 1,2,3,6] [--findings <file.json>|-]
                   [--date YYYY-MM-DD] [--dry-run]

  --auditor    P (product check) or E (eng check). Written into every new row of
               an older in-PRD ledger, which has an Auditor column, and used to
               scope --checks clearing to the check that raised a row.
  --checks     the checks this run ran. A prior Open / Still open row of one of
               these checks that no finding of this run matches becomes Fixed.
               Omitted: no prior row is cleared.
  --findings   JSON array of this run's findings. Default: stdin.
  --date       defaults to today.
  --dry-run    report what would change and write nothing.

Findings JSON — an array of objects:
  [{"severity": "Critical|Major|Minor",
    "what":     "terse: what is wrong, where",
    "fix":      "terse concrete action",
    "why":      "terse: the consumer that breaks",
    "status":   "Open|Fixed",                 default Open
    "check":    1-7,                           optional; enables key matching
    "code":     "<slug>", "ref": "<locator>",  script findings (checks 4-6)
    "section":  "<PRD section title>"}]        judgment findings (checks 1, 2, 3, 7)
  An empty array is the no-findings path and produces the Clean marker row.

Matching a finding to a prior row:
  1. by key — same check and same key (`code ref` for a script finding, the
     section for a judgment finding). The key rides in the "What is wrong" cell
     as a trailing tag the script writes: `(check 4 eng · EXEC_FID_UNCOVERED F3)`.
  2. else by text — the "What is wrong" cell, tag removed, normalised.
  A matched row is updated in place (Status -> Still open, or Fixed when the
  finding says Fixed; Date -> today) and no new row is added. Everything else is
  new and gets a fresh monotonic `#`, sorted Critical, Major, Minor first.

Clearing (with --checks): a prior Open / Still open row that matched nothing,
whose check is in --checks, becomes Fixed (Date -> today). A row raised by the
other check type is left alone; a row with no known check type is cleared only
when its check is not check 2 (the one judgment check both types run).

Output (KEY=VALUE lines on stdout):
  LEDGER_TARGET=report|prd-section                which home was selected
  LEDGER_FILE=<path>                              the file actually written
  LEDGER_SECTION=created|filled|appended
  LEDGER_ROW=<#> <added|carried|cleared> <severity>
  LEDGER_ADDED=<n>
  LEDGER_CARRIED=<n>
  LEDGER_CLEARED=<n>
  LEDGER_CLEAN=yes|no
  LEDGER_NEXT=<the next free # after this run>
  LEDGER_OPEN_CRITICAL=<n> · LEDGER_OPEN_MAJOR=<n> · LEDGER_OPEN_MINOR=<n>
                                                  rows still Open / Still open
                                                  in the whole table after the run

Exit codes:
  0  ledger written (or --dry-run plan emitted)
  2  usage error, unreadable PRD, malformed findings JSON, an existing table
     whose header is missing a canonical column, an existing table with rows but
     no parsable `#` (LEDGER_NUMBERING_UNPARSABLE), or a drifted findings heading
     that would get a second section appended beside it (SECTION_TITLE_DRIFT)

Writes via a temp file + mv, so a crash can never truncate the target.
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

# The report — no Auditor column.
REPORT_COLUMNS = ["#", "Date", "Severity", "What is wrong",
                  "Suggested fix", "Why it matters", "Status"]
# The older in-PRD ledger — kept verbatim so an existing table is appended to, not reshaped.
COLUMNS = ["#", "Date", "Auditor", "Severity", "What is wrong",
           "Suggested fix", "Why it matters", "Status"]
SEV_ORDER = {"critical": 0, "major": 1, "minor": 2}
STATUSES = {"open": "Open", "fixed": "Fixed"}
OPEN_STATUSES = ("open", "still open")
SECTION_TITLE = "Plan review findings"
REPORT_SECTION_TITLE = "Findings"
# The certifier's former section heading in the oldest PRDs, kept verbatim.
LEGACY_SECTION_TITLES = ["plan tune findings"]
TUNES = {"P": "product", "E": "eng"}

# Trailing key tag the script writes: `(check 4 eng · CODE REF)`.
TAG_RE = re.compile(r"\s*\(check (\d)(?: (product|eng))?(?: · ([^()]*))?\)\s*$")
# A bare `(check N)` mention anywhere — how older rows named their check.
BARE_CHECK_RE = re.compile(r"\(check (\d)\)")


def report_path(prd):
    """<prd-dir>/reports/review-<prd-stem>.md — the report home for the ledger."""
    return prd.parent / "reports" / f"review-{prd.stem}.md"


def report_scaffold(stem, date):
    """A fresh report, table header excluded — the 'filled' path writes that."""
    return [
        "---",
        f"name: review-{stem}",
        f"prd: {stem}",
        f"created: {date}",
        f"last-run: {date}",
        "---",
        "",
        f"# Review findings — {stem}",
        "",
        "One growing table, appended across runs. Row numbers are monotonic and",
        "never reset; an open row's `Status` is recomputed on each run.",
        "",
        f"## {REPORT_SECTION_TITLE}",
        "",
    ]


def stamp_last_run(lines, date):
    """Rewrite `last-run:` inside the leading frontmatter block, in place."""
    if not lines or lines[0].strip() != "---":
        return lines
    out = list(lines)
    for i in range(1, len(out)):
        if out[i].strip() == "---":
            break
        if re.match(r"^last-run:", out[i]):
            out[i] = f"last-run: {date}"
            break
    return out


def die(msg):
    print(f"{SELF}: {msg}", file=sys.stderr)
    sys.exit(2)


def cell(text):
    """Table-safe cell: one line, pipes escaped."""
    s = " ".join(str(text or "").split())
    return s.replace("|", "\\|")


def norm(text):
    """Text-match key for a 'What is wrong' cell (its key tag removed)."""
    s = str(text or "").replace("\\|", "|")
    s = BARE_CHECK_RE.sub("", TAG_RE.sub("", s)).lower()
    s = re.sub(r"[`*_]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s.rstrip(".;,")


def norm_key(text):
    return re.sub(r"\s+", " ", str(text or "")).strip().lower()


def parse_tag(what):
    """(check:int|None, tune:str|None, key:str) from a 'What is wrong' cell."""
    s = str(what or "").replace("\\|", "|")
    m = TAG_RE.search(s)
    if m:
        return int(m.group(1)), m.group(2), norm_key(m.group(3))
    m = BARE_CHECK_RE.search(s)
    if m:
        return int(m.group(1)), None, ""
    return None, None, ""


def finding_key(f):
    if str(f.get("code", "")).strip():
        return " ".join(x for x in (str(f.get("code", "")).strip(),
                                    str(f.get("ref", "")).strip()) if x)
    return str(f.get("section", "")).strip()


def tagged_what(f, tune):
    """The cell text: the model's `what`, any tag it wrote removed, the key tag added."""
    base = TAG_RE.sub("", " ".join(str(f.get("what", "")).split()))
    base = BARE_CHECK_RE.sub("", base).strip()
    if f.get("check") is None:
        return " ".join(str(f.get("what", "")).split())
    key = " ".join(finding_key(f).split())
    tag = f"(check {f['check']} {tune}" + (f" · {key})" if key else ")")
    return f"{base} {tag}"


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
    """'## 7. Plan review findings' -> 'plan review findings'; None if not an H2."""
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


def parse_checks(raw):
    if not raw:
        return set()
    out = set()
    for part in raw.split(","):
        part = part.strip()
        if not re.match(r"^[1-7]$", part):
            die(f"--checks takes check numbers 1-7, comma-separated; got: {raw}")
        out.add(int(part))
    return out


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-ledger.py")
    ap.add_argument("prd")
    ap.add_argument("--auditor", default="P", choices=["P", "E"])
    ap.add_argument("--checks", default="")
    ap.add_argument("--findings", default="-")
    ap.add_argument("--date", default="")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    date = args.date or datetime.date.today().isoformat()
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", date):
        die(f"--date must be YYYY-MM-DD, got: {date}")
    ran_checks = parse_checks(args.checks)
    run_tune = TUNES[args.auditor]

    prd = Path(args.prd)
    if not prd.is_file():
        die(f"no such PRD file: {args.prd}")
    try:
        prd_lines = prd.read_text(encoding="utf-8").split("\n")
    except OSError as exc:
        die(f"cannot read {args.prd}: {exc}")

    # ── Select the ledger's home ──────────────────────────────────────────────
    rpath = report_path(prd)
    prd_has_section = find_section(prd_lines, SECTION_TITLE.lower())[0] is not None
    if not prd_has_section:
        prd_has_section = any(find_section(prd_lines, t)[0] is not None
                              for t in LEGACY_SECTION_TITLES)

    # A PRD whose findings heading drifted must not quietly get a report created
    # beside it: the orphaned section's rows would never be matched against.
    if not rpath.is_file() and not prd_has_section:
        for ln in prd_lines:
            t = heading_title(ln)
            if t is not None and "findings" in t:
                print(f"SECTION_TITLE_DRIFT={ln.strip()}")
                die(f"a findings section already exists as {ln.strip()!r} but its title "
                    f"does not match '{SECTION_TITLE}' (or a known legacy title) — "
                    f"refusing to start a separate report beside it; restore the "
                    f"canonical heading, or delete the section to move to a report")

    created_report = False
    if rpath.is_file():
        target, kind = rpath, "report"
        try:
            lines = rpath.read_text(encoding="utf-8").split("\n")
        except OSError as exc:
            die(f"cannot read {rpath}: {exc}")
    elif prd_has_section:
        target, kind, lines = prd, "prd-section", prd_lines
    else:
        target, kind = rpath, "report"
        lines = report_scaffold(prd.stem, date)
        created_report = True

    if kind == "report":
        columns, section_title, legacy_titles = REPORT_COLUMNS, REPORT_SECTION_TITLE, []
    else:
        columns, section_title, legacy_titles = COLUMNS, SECTION_TITLE, LEGACY_SECTION_TITLES

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
        st = str(f.get("status", "") or "open").strip().lower()
        if st not in STATUSES:
            die(f"finding {n}: status must be Open|Fixed, got: {f.get('status')!r}")
        f["status"] = STATUSES[st]
        if f.get("check") is not None:
            if not re.match(r"^[1-7]$", str(f["check"]).strip()):
                die(f"finding {n}: check must be 1-7, got: {f.get('check')!r}")
            f["check"] = int(str(f["check"]).strip())

    # ── Locate the section and read any existing table ────────────────────────
    hidx, hend = find_section(lines, section_title.lower())
    for legacy in legacy_titles:
        if hidx is not None:
            break
        hidx, hend = find_section(lines, legacy)
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
        for want in columns:
            if want.lower() not in lowered:
                die(f"findings table header is missing the '{want}' column — the schema "
                    f"is a GUI contract; fix the table rather than writing into it")
            colmap[want] = lowered.index(want.lower())
    else:
        colmap = {c: i for i, c in enumerate(columns)}

    def get(cells, col):
        i = colmap[col]
        return cells[i] if i < len(cells) else ""

    # ── Numbering ─────────────────────────────────────────────────────────────
    highest = 0
    parsed_any = False
    first_bad = None
    for j, cells in existing_rows:
        raw_num = get(cells, "#").strip()
        if re.match(r"^\d+$", raw_num):
            parsed_any = True
            highest = max(highest, int(raw_num))
        elif first_bad is None:
            first_bad = raw_num
    # Rows exist but not one `#` parsed: refuse to renumber from 1 on top of them.
    if existing_rows and not parsed_any:
        print(f"LEDGER_NUMBERING_UNPARSABLE={first_bad}")
        die(f"findings ledger has {len(existing_rows)} row(s) but no parsable '#' "
            f"(first offending cell: {first_bad!r}) — refusing to renumber from 1 "
            f"on top of them; fix the '#' column")

    # ── Match this run's findings to prior rows ───────────────────────────────
    prior = []   # [j, cells, check, tune, key, text]
    for j, cells in existing_rows:
        check, tune, key = parse_tag(get(cells, "What is wrong"))
        if tune is None and "Auditor" in colmap:
            tune = TUNES.get(get(cells, "Auditor").strip().upper())
        prior.append([j, cells, check, tune, key, norm(get(cells, "What is wrong"))])
    taken = set()

    def match(f):
        if f.get("check") is not None:
            key = norm_key(" ".join(finding_key(f).split()))
            if key:
                for p in prior:
                    if p[0] not in taken and p[2] == f["check"] and p[4] == key:
                        return p
        text = norm(f.get("what"))
        for p in prior:
            if p[0] not in taken and p[5] == text:
                return p
        return None

    carried, fresh = [], []
    for f in findings:
        p = match(f)
        if p is not None:
            taken.add(p[0])
            carried.append((f, p))
        else:
            fresh.append(f)

    fresh.sort(key=lambda f: SEV_ORDER[str(f["severity"]).strip().lower()])

    edits = {}   # line index -> replacement cells
    report = []
    for f, p in carried:
        j, cells = p[0], p[1]
        row = list(cells) + [""] * (len(columns) - len(cells))
        row[colmap["Status"]] = "Fixed" if f["status"] == "Fixed" else "Still open"
        row[colmap["Date"]] = date
        if f.get("check") is not None:
            row[colmap["What is wrong"]] = cell(tagged_what(f, run_tune))
        edits[j] = row
        report.append((get(cells, "#") or "?", "carried", str(f["severity"]).strip().title()))

    cleared = 0
    if ran_checks:
        for p in prior:
            j, cells, check, tune = p[0], p[1], p[2], p[3]
            if j in taken or check not in ran_checks:
                continue
            if get(cells, "Status").strip().lower() not in OPEN_STATUSES:
                continue
            if tune is not None and tune != run_tune:
                continue
            if tune is None and check == 2:
                continue
            row = list(cells) + [""] * (len(columns) - len(cells))
            row[colmap["Status"]] = "Fixed"
            row[colmap["Date"]] = date
            edits[j] = row
            cleared += 1
            report.append((get(cells, "#") or "?", "cleared", get(cells, "Severity").strip().title()))

    new_rows, num = [], highest
    for f in fresh:
        num += 1
        row = [""] * len(columns)
        row[colmap["#"]] = str(num)
        row[colmap["Date"]] = date
        if "Auditor" in colmap:
            row[colmap["Auditor"]] = args.auditor
        row[colmap["Severity"]] = str(f["severity"]).strip().title()
        row[colmap["What is wrong"]] = cell(tagged_what(f, run_tune))
        row[colmap["Suggested fix"]] = cell(f.get("fix")) or "—"
        row[colmap["Why it matters"]] = cell(f.get("why")) or "—"
        row[colmap["Status"]] = f["status"]
        new_rows.append(row)
        report.append((str(num), "added", row[colmap["Severity"]]))

    clean = not findings
    if clean:
        num += 1
        row = [""] * len(columns)
        row[colmap["#"]] = str(num)
        row[colmap["Date"]] = date
        if "Auditor" in colmap:
            row[colmap["Auditor"]] = args.auditor
        row[colmap["Severity"]] = "—"
        row[colmap["What is wrong"]] = "No findings; all applicable checks certified"
        row[colmap["Suggested fix"]] = "—"
        row[colmap["Why it matters"]] = "—"
        row[colmap["Status"]] = "Clean"
        new_rows.append(row)
        report.append((str(num), "added", "Clean"))

    # ── Open counts over the whole table after this run ───────────────────────
    open_counts = {"critical": 0, "major": 0, "minor": 0}
    final_rows = [edits.get(j, cells) for j, cells in existing_rows] + new_rows
    for row in final_rows:
        sev = get(row, "Severity").strip().lower()
        if sev in open_counts and get(row, "Status").strip().lower() in OPEN_STATUSES:
            open_counts[sev] += 1

    # ── Apply ─────────────────────────────────────────────────────────────────
    out = list(lines)
    for j, row in edits.items():
        out[j] = render(row)
    new_lines_rows = [render(r) for r in new_rows]

    header_line = render([c for c in header_cells] if header_cells else columns)
    sep_line = "|" + "|".join("---" for _ in columns) + "|"

    # Target selection guarantees the section exists in whichever home was chosen.
    if header_cells is not None:
        mode = "appended"
        out[tbl_end + 1:tbl_end + 1] = new_lines_rows
    else:
        mode = "created" if created_report else "filled"
        body = [header_line, sep_line] + new_lines_rows
        # Replace the section body (placeholder prose and all) with the table.
        out[hidx + 1:hend] = [""] + body + [""]

    if kind == "report":
        out = stamp_last_run(out, date)

    print(f"LEDGER_TARGET={kind}")
    print(f"LEDGER_FILE={target}")
    print(f"LEDGER_SECTION={mode}")
    for num_s, what, sev in report:
        print(f"LEDGER_ROW={num_s} {what} {sev}")
    print(f"LEDGER_ADDED={len(new_lines_rows)}")
    print(f"LEDGER_CARRIED={len(carried)}")
    print(f"LEDGER_CLEARED={cleared}")
    print(f"LEDGER_CLEAN={'yes' if clean else 'no'}")
    print(f"LEDGER_NEXT={num + 1}")
    print(f"LEDGER_OPEN_CRITICAL={open_counts['critical']}")
    print(f"LEDGER_OPEN_MAJOR={open_counts['major']}")
    print(f"LEDGER_OPEN_MINOR={open_counts['minor']}")

    if args.dry_run:
        return

    try:
        target.parent.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        die(f"cannot create {target.parent}: {exc}")

    fd, tmp = tempfile.mkstemp(dir=str(target.parent), prefix=".script-ledger.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write("\n".join(out))
        # A brand-new report has no mode of its own to preserve; inherit the PRD's.
        os.chmod(tmp, os.stat(target if target.exists() else prd).st_mode & 0o777)
        os.replace(tmp, target)
    except OSError as exc:
        if os.path.exists(tmp):
            os.unlink(tmp)
        die(f"cannot write {target}: {exc}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
script-ledger.py — the writer for a PRD's plan-review findings ledger.

Owns everything about the ledger that is decidable: locating (or creating) the
table, deduping this run's findings against prior rows, assigning the monotonic
`#`, and emitting the Clean marker row when a run finds nothing. The model decides
*what* the findings are and hands them over as JSON; it never counts rows, never
picks a row number, and never hand-writes the table.

WHERE THE LEDGER LIVES (two targets, auto-selected)

  v5.4 and later — an external report beside the PRD:
      <prd-dir>/reports/review-prd-<n>-<slug>.md
  A findings table is append-only and grows without bound; a PRD is a contract
  every downstream stage re-reads. Keeping the two in one file made every reader
  pay for the audit history, so the ledger moved out. The PRD's `reviewed:`
  frontmatter stamp remains the gate signal — this file is the evidence trail.

  v5 and earlier — the PRD's own `## 7. Plan review findings` section.
  A PRD that already carries that section keeps its ledger there, with its
  eight-column (Auditor-bearing) table intact. Nothing is ever migrated: the
  target is whichever home the PRD already has.

Selection order: an existing report file wins; else an existing findings section
in the PRD; else a new report file is created from the v5.4 scaffold.

Do not confuse the report with `reports/review-prd-<N>-<K>.json` — that is eng's
per-packet build-review evidence (v5.3), a different file with a different shape.
This one is markdown and its suffix is the PRD slug.

The column set is a contract shared with `/msg --gui` and
`plan-review/refs/template-review-report.md`. This script never changes it: an
existing table whose header is missing a canonical column is a hard error, not
something to patch around.

Usage:
  script-ledger.py <prd.md> [--auditor P|E] [--findings <file.json>|-] [--date YYYY-MM-DD] [--dry-run]

  --auditor    P (product tune) or E (eng tune). Written into every new row of a
               legacy in-PRD ledger, which has an Auditor column. Accepted and
               ignored for the v5.4 report, whose one mode has one auditor.
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
  LEDGER_TARGET=report|prd-section                which home was selected
  LEDGER_FILE=<path>                              the file actually written
  LEDGER_SECTION=created|filled|appended
  LEDGER_ROW=<#> <added|carried> <severity>      one per finding
  LEDGER_ADDED=<n>
  LEDGER_CARRIED=<n>
  LEDGER_CLEAN=yes|no
  LEDGER_NEXT=<the next free # after this run>

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

# v5.4 external report — one mode, one auditor, so no Auditor column.
REPORT_COLUMNS = ["#", "Date", "Severity", "What is wrong",
                  "Suggested fix", "Why it matters", "Status"]
# v5 in-PRD ledger — kept verbatim so an existing table is appended to, not reshaped.
COLUMNS = ["#", "Date", "Auditor", "Severity", "What is wrong",
           "Suggested fix", "Why it matters", "Status"]
SEV_ORDER = {"critical": 0, "major": 1, "minor": 2}
SECTION_TITLE = "Plan review findings"
REPORT_SECTION_TITLE = "Findings"
# Pre-v5 PRDs carry the certifier's former section heading, kept here verbatim.
# Appends find it and leave the heading exactly as written — nothing is rewritten.
LEGACY_SECTION_TITLES = ["plan tune findings"]


def report_path(prd):
    """<prd-dir>/reports/review-<prd-stem>.md — the v5.4 home for the ledger."""
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


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-ledger.py")
    ap.add_argument("prd")
    ap.add_argument("--auditor", default="P", choices=["P", "E"])
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
        prd_lines = prd.read_text(encoding="utf-8").split("\n")
    except OSError as exc:
        die(f"cannot read {args.prd}: {exc}")

    # ── Select the ledger's home ──────────────────────────────────────────────
    # An existing report wins; else a findings section already in the PRD (a
    # pre-v5.4 file keeps its ledger where it is); else a new report.
    rpath = report_path(prd)
    prd_has_section = find_section(prd_lines, SECTION_TITLE.lower())[0] is not None
    if not prd_has_section:
        prd_has_section = any(find_section(prd_lines, t)[0] is not None
                              for t in LEGACY_SECTION_TITLES)

    # A11 — a PRD whose findings heading drifted ("Review findings" instead of
    # "Plan review findings") must not quietly get a report created beside it:
    # the orphaned section's rows would never be deduped against, and a consumer
    # reading the PRD would see a stale table that no run updates. Refuse, exactly
    # as this refused to append a second section before the ledger moved out.
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
                    f"is a GUI + template contract; fix the table rather than writing "
                    f"into it")
            colmap[want] = lowered.index(want.lower())
    else:
        colmap = {c: i for i, c in enumerate(columns)}

    def get(cells, col):
        i = colmap[col]
        return cells[i] if i < len(cells) else ""

    # ── Dedup + numbering ─────────────────────────────────────────────────────
    by_what = {}
    highest = 0
    parsed_any = False
    first_bad = None
    for j, cells in existing_rows:
        by_what.setdefault(norm(get(cells, "What is wrong")), (j, cells))
        raw_num = get(cells, "#").strip()
        m = re.match(r"^\d+$", raw_num)
        if m:
            parsed_any = True
            highest = max(highest, int(raw_num))
        elif first_bad is None:
            first_bad = raw_num
    # A10 — rows exist but not one `#` parsed: `highest` would stay 0 and this run
    # would renumber from 1 alongside the rows already there. Mixed tables (some
    # rows parse) keep today's max-of-parsed behaviour.
    if existing_rows and not parsed_any:
        print(f"LEDGER_NUMBERING_UNPARSABLE={first_bad}")
        die(f"findings ledger has {len(existing_rows)} row(s) but no parsable '#' "
            f"(first offending cell: {first_bad!r}) — refusing to renumber from 1 "
            f"on top of them; fix the '#' column")

    carried, fresh = [], []
    for f in findings:
        hit = by_what.get(norm(f.get("what")))
        (carried if hit else fresh).append((f, hit))

    fresh.sort(key=lambda p: SEV_ORDER[str(p[0]["severity"]).strip().lower()])

    edits = {}   # line index -> replacement line (carried-forward updates)
    for f, (j, cells) in carried:
        row = list(cells) + [""] * (len(columns) - len(cells))
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
        row = [""] * len(columns)
        row[colmap["#"]] = str(num)
        row[colmap["Date"]] = date
        if "Auditor" in colmap:
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
        new_lines_rows.append(render(row))
        report.append((str(num), "added", "Clean"))

    # ── Apply ─────────────────────────────────────────────────────────────────
    out = list(lines)
    for j, repl in edits.items():
        out[j] = repl

    header_line = render([c for c in header_cells] if header_cells else columns)
    sep_line = "|" + "|".join("---" for _ in columns) + "|"

    # Only two arms remain. Target selection guarantees the section exists in
    # whichever home was chosen — the report scaffold always carries `## Findings`,
    # and prd-section mode is only entered when the PRD already has the heading —
    # so there is never a section to invent here. (Before the ledger moved out, a
    # third arm created the section inside the PRD and announced a Todos-anchor or
    # EOF placement; that is now unreachable, and `LEDGER_PLACEMENT` with it.)
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
    print(f"LEDGER_CLEAN={'yes' if clean else 'no'}")
    print(f"LEDGER_NEXT={num + 1}")

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

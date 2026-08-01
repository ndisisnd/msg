#!/usr/bin/env python3
"""
script-prd-update.py — deterministic PRD migrator, v5 shape → v5.4 (no LLM).

The read path never rewrites a PRD: every reader normalises the old shape in
memory and no writer emits it. `plan-pm --update` is the one deliberate,
user-invoked exception, and this script is its mechanical half (L1). It does
only the edits a machine can make without judgement — frontmatter keys, the
findings-section move, section renumbering. Everything that needs reading
comprehension (§5 bullets → the 4-column table, §1 bullet pruning) is L2 and
lives in `plan-pm/refs/protocol-update.md`.

Usage:
  script-prd-update.py <prd.md> [--dry-run] [--intake <INTAKE.md>] [--date YYYY-MM-DD]

  --dry-run  report the edits, write nothing (same stdout, same exit code).
  --intake   ledger to slug-match a missing `intake:` against. Default: the
             first INTAKE.md found walking up from the PRD.
  --date     date stamped into a newly created findings report. Default: the
             PRD's own `created` value — never today, so output is reproducible.

What it migrates:
  frontmatter  `depends_on` → `deps` · drop `module` / `platform` / `affects` ·
               `product-tuned` + `eng-tuned` → one `reviewed` (yes iff both
               were yes, or `reviewed: yes` was already stamped) · status map
               product→backlog, eng→specced, done→complete · a missing `intake`
               is slug-matched against the ledger, else left as a
               `[USER: intake row #]` placeholder — never invented.
  body         inline `## N. Plan review findings` → `<prd-dir>/reports/
               review-prd-<n>-<slug>.md` · `## 8. Todos` → `## 7. Todos` ·
               a legacy `## Execution Table` heading folds into §6.

What it never touches: §1–§5 prose, the §3/§4 tables, F-IDs, §6/§7 content and
the `## Engineering — <Agent>` / `## Todos — <Agent>` blocks beside them.

Skips (exit 2, nothing written):
  · `status: retired` — the v5.4 enum has no equivalent and a retired PRD is
    not worth migrating.
  · a findings report already exists at the target path — the inline section
    and the report would both be evidence; merging them is the user's call.

Output (stdout, one record per line, machine-readable):
  CHANGE code=<slug> ref=<locator> detail=<free text to EOL>
  WARN   code=<slug> ref=<locator> detail=<free text to EOL>
  SUMMARY shape=<v5|v5.4> changes=<n> warnings=<n> result=<...> mode=<...>

Change codes:
  deps-renamed · key-dropped · reviewed-fused · status-mapped · intake-resolved
  intake-placeholder · findings-extracted · findings-dropped · todos-renumbered
  exec-heading-folded · exec-heading-renumbered
Warn codes:
  retired-skipped · report-exists · intake-unresolved

Exit codes:
  0  already converged — no edit needed (rerunning is a byte-level no-op)
  1  the PRD was migrated (or would be, under --dry-run)
  2  usage error, unreadable PRD, no frontmatter, or the file was skipped

Deterministic: identical input produces byte-identical output.
"""
import argparse
import re
import sys
from pathlib import Path

SELF = "script-prd-update"

# ── the v5 → v5.4 mapping, in one place ──────────────────────────────────────

DROPPED_KEYS = ("module", "platform", "affects")
TUNE_KEYS = ("product-tuned", "eng-tuned")
STATUS_MAP = {"product": "backlog", "eng": "specced", "done": "complete"}
V5_MARKERS = ("module", "platform", "affects", "depends_on",
              "product-tuned", "eng-tuned")

INTAKE_PLACEHOLDER = "[USER: intake row #]"

FINDINGS_TITLES = ("plan review findings", "plan tune findings")
FINDINGS_PLACEHOLDER = "_Populated by plan-review (/plan-review) — audit findings table._"
EXEC_PLACEHOLDER = "_To be populated by plan-em — engineering breakdown of the §3 features._"

KEY_LINE = re.compile(r"^([A-Za-z0-9_-]+):\s*(.*)$")
H2 = re.compile(r"^##\s+(.*?)\s*$")
NUMBERED = re.compile(r"^(\d+)\.\s*(.+)$")
NAME = re.compile(r"^prd-(\d+(?:\.\d+)?)-([a-z0-9-]+)$")

RECORDS = []


def change(code, ref, detail):
    RECORDS.append(("CHANGE", code, ref, " ".join(str(detail).split())))


def warn(code, ref, detail):
    RECORDS.append(("WARN", code, ref, " ".join(str(detail).split())))


def die(msg):
    print(f"{SELF}: {msg}", file=sys.stderr)
    sys.exit(2)


def emit(shape, result, mode):
    changes = sum(1 for r in RECORDS if r[0] == "CHANGE")
    warnings = sum(1 for r in RECORDS if r[0] == "WARN")
    for kind, code, ref, detail in RECORDS:
        print(f"{kind} code={code} ref={ref} detail={detail}")
    print(f"SUMMARY shape={shape} changes={changes} warnings={warnings} "
          f"result={result} mode={mode}")


# ── parsing ───────────────────────────────────────────────────────────────────

def split_frontmatter(lines):
    """Return (dict, fm_line_slice_end) — end is the index of the closing '---'."""
    if not lines or lines[0].strip() != "---":
        return None, 0
    fm = {}
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return fm, i
        m = KEY_LINE.match(lines[i])
        if m:
            fm[m.group(1)] = m.group(2).strip()
    return None, 0


def norm(title):
    m = NUMBERED.match(title)
    return (m.group(2) if m else title).strip().lower()


def parse_blocks(lines, body_start):
    """[[heading_or_None, [body lines]], …] — the body, losslessly re-renderable."""
    blocks = [[None, []]]
    for ln in lines[body_start:]:
        if H2.match(ln):
            blocks.append([ln, []])
        else:
            blocks[-1][1].append(ln)
    return blocks


def render(fm_lines, blocks):
    out = ["---"] + fm_lines + ["---"]
    for heading, body in blocks:
        if heading is not None:
            out.append(heading)
        out.extend(body)
    return out


def find_block(blocks, want):
    for i, (heading, _) in enumerate(blocks):
        if heading is not None and norm(H2.match(heading).group(1)) == want:
            return i
    return None


def meaningful(body):
    """Body lines with the blanks and the reserved placeholder taken out."""
    return [l for l in body
            if l.strip() and l.strip() not in (FINDINGS_PLACEHOLDER, EXEC_PLACEHOLDER)]


def trim(body):
    lines = list(body)
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


# ── the intake ledger lookup ─────────────────────────────────────────────────

def slugify(text):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def find_intake_row(ledger, prd_name, slug):
    """Row `#` for this PRD: exact `prd` cell first, then a unique idea-slug match."""
    try:
        rows = ledger.read_text(encoding="utf-8").split("\n")
    except OSError:
        return None
    header, parsed = None, []
    for ln in rows:
        s = ln.strip()
        if not s.startswith("|"):
            continue
        bare = s.strip("|")
        if re.match(r"^[\s:|-]+$", bare):
            continue
        cells = [c.strip() for c in bare.split("|")]
        if header is None:
            header = [c.lower() for c in cells]
        else:
            parsed.append(cells)
    if not header or "#" not in header:
        return None

    def cell(cells, name):
        if name not in header:
            return ""
        i = header.index(name)
        return cells[i].strip() if i < len(cells) else ""

    for cells in parsed:
        if cell(cells, "prd") == prd_name:
            return cell(cells, "#").lstrip("#")
    hits = [cell(cells, "#").lstrip("#") for cells in parsed
            if slug and slug in slugify(cell(cells, "idea"))]
    return hits[0] if len(hits) == 1 else None


def locate_ledger(prd_path):
    for parent in [prd_path.parent] + list(prd_path.parents):
        candidate = parent / "INTAKE.md"
        if candidate.is_file():
            return candidate
    return None


# ── frontmatter migration ────────────────────────────────────────────────────

def migrate_frontmatter(fm_lines, fm, prd_path, intake_arg):
    """Return the rewritten frontmatter lines."""
    already = fm.get("reviewed") == "yes"
    both_tuned = all(fm.get(k) == "yes" for k in TUNE_KEYS if k in fm)
    fused = "yes" if already or (any(k in fm for k in TUNE_KEYS) and both_tuned) else "no"

    out, reviewed_written = [], False
    for line in fm_lines:
        m = KEY_LINE.match(line)
        if not m:
            out.append(line)
            continue
        key, value = m.group(1), m.group(2).strip()
        if key == "depends_on":
            out.append(f"deps: {value}")
            change("deps-renamed", "frontmatter",
                   f"`depends_on: {value}` → `deps: {value}` — one dependency key")
        elif key in DROPPED_KEYS:
            change("key-dropped", "frontmatter",
                   f"`{key}: {value}` removed — v5.4 has no {key} field")
        elif key in TUNE_KEYS:
            change("key-dropped", "frontmatter",
                   f"`{key}: {value}` removed — folded into the single `reviewed` stamp")
            if "reviewed" not in fm and not reviewed_written:
                out.append(f"reviewed: {fused}")
                reviewed_written = True
                change("reviewed-fused", "frontmatter",
                       f"`reviewed: {fused}` written — yes only when both tune "
                       f"stamps were yes")
        elif key == "reviewed":
            out.append(f"reviewed: {fused}")
            if fused != value:
                change("reviewed-fused", "frontmatter",
                       f"`reviewed: {value}` → `reviewed: {fused}` — fused with the "
                       f"tune stamps")
        elif key == "status":
            mapped = STATUS_MAP.get(value, value)
            out.append(f"status: {mapped}")
            if mapped != value:
                change("status-mapped", "frontmatter",
                       f"`status: {value}` → `status: {mapped}` — v5.4 lifecycle enum")
        else:
            out.append(line)

    if "intake" not in fm:
        name = fm.get("name", "")
        m = NAME.match(name)
        slug = m.group(2) if m else ""
        ledger = Path(intake_arg) if intake_arg else locate_ledger(prd_path)
        row = find_intake_row(ledger, name, slug) if ledger and ledger.is_file() else None
        if row:
            out.append(f"intake: #{row}")
            change("intake-resolved", "frontmatter",
                   f"`intake: #{row}` recovered by matching `{name}` against {ledger}")
        else:
            out.append(f"intake: {INTAKE_PLACEHOLDER}")
            change("intake-placeholder", "frontmatter",
                   f"`intake: {INTAKE_PLACEHOLDER}` inserted — no ledger row matched; "
                   f"the row number is never invented")
            warn("intake-unresolved", "frontmatter",
                 "the PRD carries an unresolved [USER: …] placeholder — raise it as an "
                 "Open §5 row and have the user supply the intake row number")
    return out


# ── body migration ───────────────────────────────────────────────────────────

def report_body(prd_name, date, extracted):
    return "\n".join([
        "---",
        f"name: review-{prd_name}",
        f"prd: {prd_name}",
        f"created: {date}",
        f"last-run: {date}",
        "---",
        "",
        f"# Review findings — {prd_name}",
        "",
        "Migrated out of the PRD's inline plan-review-findings section by",
        "`script-prd-update.py`. One growing table, appended across runs; row",
        "numbers are monotonic and never reset.",
        "",
    ] + extracted + [""])


def migrate_body(blocks, prd_path, prd_name, date, dry_run):
    """Mutate `blocks` in place. Returns (ok, report_path_or_None, report_text)."""
    report_path, report_text = None, None

    # inline findings → reports/review-prd-<n>-<slug>.md
    idx = None
    for i, (heading, _) in enumerate(blocks):
        if heading is not None and norm(H2.match(heading).group(1)) in FINDINGS_TITLES:
            idx = i
            break
    if idx is not None:
        title = H2.match(blocks[idx][0]).group(1)
        content = trim(meaningful(blocks[idx][1]))
        if not content:
            change("findings-dropped", f"'## {title}'",
                   "section held only the reserved placeholder — removed, nothing to keep")
        else:
            report_path = prd_path.parent / "reports" / f"review-{prd_name}.md"
            if report_path.exists():
                warn("report-exists", str(report_path),
                     "a findings report is already on disk — merging it with the inline "
                     "section is a human call; nothing was written")
                return False, None, None
            report_text = report_body(prd_name, date, content)
            change("findings-extracted", str(report_path),
                   f"{len(content)} lines moved out of '## {title}' — findings live in "
                   f"the report, never in the PRD")
        del blocks[idx]

        todos = find_block(blocks, "todos")
        if todos is not None:
            m = NUMBERED.match(H2.match(blocks[todos][0]).group(1))
            if m and m.group(1) != "7":
                blocks[todos][0] = "## 7. Todos"
                change("todos-renumbered", f"'## {m.group(1)}. Todos'",
                       "renumbered to '## 7. Todos' — seven sections after the "
                       "findings move")

    # legacy `## Execution Table` → §6
    legacy = find_block(blocks, "execution table")
    if legacy is not None:
        exec6 = find_block(blocks, "feature execution table")
        if exec6 is None:
            blocks[legacy][0] = "## 6. Feature execution table"
            change("exec-heading-renumbered", "'## Execution Table'",
                   "renamed to '## 6. Feature execution table' — §6 is the one home "
                   "for the execution table")
        else:
            moved = trim(meaningful(blocks[legacy][1]))
            if moved:
                kept = trim(meaningful(blocks[exec6][1]))
                blocks[exec6][1] = [""] + (kept + [""] if kept else []) + moved + [""]
            change("exec-heading-folded", "'## Execution Table'",
                   f"{len(moved)} lines folded into §6 and the legacy heading removed")
            del blocks[legacy]

    return True, report_path, report_text


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-prd-update.py")
    ap.add_argument("prd")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--intake", default=None)
    ap.add_argument("--date", default=None)
    args = ap.parse_args()

    prd = Path(args.prd)
    if not prd.is_file():
        die(f"no such PRD file: {args.prd}")
    if args.date and not re.match(r"^\d{4}-\d{2}-\d{2}$", args.date):
        die(f"--date must be YYYY-MM-DD, got '{args.date}'")
    try:
        original = prd.read_text(encoding="utf-8")
    except OSError as exc:
        die(f"cannot read {args.prd}: {exc}")

    lines = original.split("\n")
    fm, fm_end = split_frontmatter(lines)
    if fm is None:
        die(f"no YAML frontmatter in {args.prd}")

    shape = "v5" if any(k in fm for k in V5_MARKERS) else "v5.4"
    mode = "dry-run" if args.dry_run else "write"

    if fm.get("status") == "retired":
        warn("retired-skipped", "frontmatter",
             "`status: retired` has no v5.4 lifecycle equivalent — a retired PRD is "
             "left exactly as it is")
        emit(shape, "skipped", mode)
        sys.exit(2)

    prd_name = fm.get("name", prd.stem)
    date = args.date or fm.get("created")
    if not date or not re.match(r"^\d{4}-\d{2}-\d{2}$", date):
        die(f"cannot resolve a report date for {args.prd}: frontmatter `created` is "
            f"missing or malformed and no --date was given")

    fm_lines = migrate_frontmatter(lines[1:fm_end], fm, prd, args.intake)
    blocks = parse_blocks(lines, fm_end + 1)
    ok, report_path, report_text = migrate_body(blocks, prd, prd_name, date, args.dry_run)
    if not ok:
        emit(shape, "skipped", mode)
        sys.exit(2)

    updated = "\n".join(render(fm_lines, blocks))
    if updated == original and report_text is None:
        emit(shape, "no-op", mode)
        sys.exit(0)

    if not args.dry_run:
        if report_text is not None:
            report_path.parent.mkdir(parents=True, exist_ok=True)
            report_path.write_text(report_text, encoding="utf-8")
        prd.write_text(updated, encoding="utf-8")

    emit(shape, "migrated", mode)
    sys.exit(1)


if __name__ == "__main__":
    main()

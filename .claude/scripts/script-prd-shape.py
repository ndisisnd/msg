#!/usr/bin/env python3
"""
script-prd-shape.py — mechanical PRD shape validator (no LLM).

Checks that a drafted PRD actually follows `plan-pm/refs/template-prd.md`. The
template is the consistency mechanism; this script is what stops consistency
from depending on the model having read it carefully. Run at the end of
plan-pm's Step 3 (Part 5), where the fix is cheap.

Usage:
  script-prd-shape.py <prd.md> [--checks 1,2,3,4,5]

  --checks   comma-separated subset of 1..5. Default: all five.

The five checks:
  1 sections   every canonical `## N. Title` present, correctly numbered, in
               canonical order, none missing, none extra-numbered.
  2 ftable     §3 carries the four canonical columns; every row has a non-empty
               acceptance criterion; no `supports` / `handles` / `TBD` weasel
               tokens in the criterion cell.
  3 fids       F-IDs are F1..Fn — sequential, no gaps, no duplicates.
  4 reserved   the reserved sections carry their byte-exact placeholders, OR are
               genuinely populated by their owning skill. Never paraphrased.
  5 frontmatter every required key present with a legal value.

Two shapes, auto-detected from the frontmatter (never from the body):
  v5.4  seven sections (findings moved to reports/review-prd-<n>-<slug>.md),
        `deps`, one `reviewed` stamp, `status: backlog|specced|wip|complete`,
        `intake`. This is what every writer emits.
  v5    eight sections (§7 Plan review findings), `depends_on`, `affects`,
        `module`, `platform`, `product-tuned` + `eng-tuned`,
        `status: product|eng|done|retired`. Read-only tolerance for PRDs
        already on disk — nothing is ever rewritten into the new shape.

Output (stdout, one record per line, machine-readable):
  FAIL  check=<1-5> code=<slug> ref=<locator> detail=<free text to EOL>
  SUMMARY shape=<v5.4|v5> checks=<list> failures=<n>

Failure codes:
  check 1  missing-section · section-out-of-order · unknown-section · bad-number
  check 2  missing-features-table · bad-columns · empty-acceptance · weasel-token
  check 3  bad-fid · fid-gap · fid-duplicate
  check 4  placeholder-drift
  check 5  missing-key · bad-value

Exit codes:
  0  shape is conformant
  1  one or more FAIL lines emitted
  2  usage error, unreadable PRD, or no YAML frontmatter

Deterministic: identical input produces byte-identical output.
"""
import argparse
import re
import sys
from pathlib import Path

SELF = "script-prd-shape"

# ── Two shapes, one validator ────────────────────────────────────────────────
# v5.4 slimmed the PRD: seven sections (the findings ledger moved out to
# `reports/review-prd-<n>-<slug>.md`), `depends_on` renamed to `deps`, the two
# tune stamps fused into one `reviewed`, and `module`/`platform`/`affects`
# dropped. Writers emit v5.4 only. This reader keeps validating v5-shape PRDs
# already on disk exactly as it already tolerates the pre-v5 `## Execution
# Table` heading — nothing on disk is ever rewritten to the new shape.

CANONICAL_V54 = [
    (1, "Product objective"),
    (2, "Out-of-scope"),
    (3, "Features & acceptance criteria"),
    (4, "Error cases"),
    (5, "Open questions"),
    (6, "Feature execution table"),
    (7, "Todos"),
]

CANONICAL_V5 = [
    (1, "Product objective"),
    (2, "Out-of-scope"),
    (3, "Features & acceptance criteria"),
    (4, "Error cases"),
    (5, "Open questions"),
    (6, "Feature execution table"),
    (7, "Plan review findings"),
    (8, "Todos"),
]

# Section titles that older PRDs still carry, mapped to their canonical title.
# §7 carried the certifier's former name until v5; the read tolerates that old
# heading so pre-v5 PRDs keep validating (nothing on disk is ever rewritten).
LEGACY_TITLES = {"plan tune findings": "plan review findings"}

EXEC_PLACEHOLDER = "_To be populated by plan-em — engineering breakdown of the §3 features._"
FINDINGS_PLACEHOLDER = "_Populated by plan-review (/plan-review) — audit findings table._"
TODOS_PLACEHOLDER = "_Populated by eng --plan — implementation tickets, grouped by feature._"

RESERVED_V54 = {6: EXEC_PLACEHOLDER, 7: TODOS_PLACEHOLDER}
RESERVED_V5 = {6: EXEC_PLACEHOLDER, 7: FINDINGS_PLACEHOLDER, 8: TODOS_PLACEHOLDER}

OWNER_V54 = {6: "plan-em", 7: "eng --plan"}
OWNER_V5 = {6: "plan-em", 7: "plan-review", 8: "eng --plan"}

FEATURE_COLUMNS = ["id", "feature", "acceptance criterion", "dependencies"]

WEASEL = ("supports", "handles", "tbd", "gracefully", "as needed", "etc.")

REQUIRED_V54 = {
    "name":     re.compile(r"^prd-\d+(\.\d+)?-[a-z0-9-]+$"),
    "feature":  re.compile(r"^\S.*$"),
    "summary":  re.compile(r"^\S.*$"),
    "status":   re.compile(r"^(backlog|specced|wip|complete)$"),
    "reviewed": re.compile(r"^(yes|no)$"),
    "created":  re.compile(r"^\d{4}-\d{2}-\d{2}$"),
    "intake":   re.compile(r"^#?\d+$"),
}
LIST_V54 = ("deps",)

REQUIRED_V5 = {
    "name":          re.compile(r"^prd-\d+(\.\d+)?-[a-z0-9-]+$"),
    "feature":       re.compile(r"^\S.*$"),
    "summary":       re.compile(r"^\S.*$"),
    "module":        re.compile(r"^\S.*$"),
    "platform":      re.compile(r"^\S.*$"),
    "status":        re.compile(r"^(product|eng|done|retired)$"),
    "product-tuned": re.compile(r"^(yes|no)$"),
    "eng-tuned":     re.compile(r"^(yes|no)$"),
    "reviewed":      re.compile(r"^(yes|no)$"),
    "created":       re.compile(r"^\d{4}-\d{2}-\d{2}$"),
}
LIST_V5 = ("affects", "depends_on")

# A frontmatter carrying ANY key that v5.4 dropped or renamed is a v5-shape PRD.
# Detection is frontmatter-only and never looks at the body, so the section
# expectations and the key expectations can never disagree about which shape
# this file is.
V5_MARKERS = ("module", "platform", "affects", "depends_on",
              "product-tuned", "eng-tuned")


class Shape:
    """The one bundle of per-shape expectations every check reads."""

    def __init__(self, legacy):
        self.legacy = legacy
        self.canonical = CANONICAL_V5 if legacy else CANONICAL_V54
        self.reserved = RESERVED_V5 if legacy else RESERVED_V54
        self.owners = OWNER_V5 if legacy else OWNER_V54
        self.required = REQUIRED_V5 if legacy else REQUIRED_V54
        self.lists = LIST_V5 if legacy else LIST_V54
        self.name = "v5" if legacy else "v5.4"
        self.last = self.canonical[-1][0]


def detect_shape(fm):
    return Shape(any(k in fm for k in V5_MARKERS))


FAILURES = []


def fail(check, code, ref, detail):
    FAILURES.append((check, code, ref, " ".join(str(detail).split())))


def die(msg):
    print(f"{SELF}: {msg}", file=sys.stderr)
    sys.exit(2)


# ── parsing ───────────────────────────────────────────────────────────────────

def split_frontmatter(lines):
    """Return (dict, body_start_index) or (None, 0) when absent/unterminated."""
    if not lines or lines[0].strip() != "---":
        return None, 0
    fm = {}
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return fm, i + 1
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", lines[i])
        if m:
            fm[m.group(1)] = m.group(2).strip()
    return None, 0


H2 = re.compile(r"^##\s+(.*?)\s*$")
NUMBERED = re.compile(r"^(\d+)\.\s*(.+)$")


def h2_sections(lines, start):
    """Yield (raw_title, line_no_1indexed, body_lines) for every H2 in the body."""
    idx = [i for i in range(start, len(lines)) if H2.match(lines[i])]
    out = []
    for k, i in enumerate(idx):
        end = idx[k + 1] if k + 1 < len(idx) else len(lines)
        out.append((H2.match(lines[i]).group(1), i + 1, lines[i + 1:end]))
    return out


def md_table(block):
    """(headers_lower, rows) for the first markdown table in `block`."""
    headers, rows = None, []
    for ln in block:
        s = ln.strip()
        if not s.startswith("|"):
            if headers is not None:
                break
            continue
        bare = s.strip("|")
        if re.match(r"^[\s:|-]+$", bare):
            continue
        cells = [c.strip() for c in bare.split("|")]
        if headers is None:
            headers = [c.lower() for c in cells]
        else:
            rows.append(cells)
    return headers, rows


def norm(title):
    """'3. Features & acceptance criteria' -> 'features & acceptance criteria'."""
    m = NUMBERED.match(title)
    return (m.group(2) if m else title).strip().lower()


def canon(title):
    """norm() plus legacy-title folding, so an old heading reads as its new self."""
    k = norm(title)
    return LEGACY_TITLES.get(k, k)


# ── check 1 — sections present, numbered, ordered ─────────────────────────────

def check1(secs, shape):
    want = {t.lower(): n for n, t in shape.canonical}
    titles = dict(shape.canonical)
    count = len(shape.canonical)
    seen = {}
    for title, lineno, _ in secs:
        key = canon(title)
        if key not in want:
            m = NUMBERED.match(title)
            if m:
                fail(1, "unknown-section", f"line {lineno}",
                     f"'## {title}' is not one of the {count} canonical "
                     f"{shape.name} sections")
            continue                       # unnumbered extras (doc title) are fine
        n = want[key]
        if key in seen:
            fail(1, "unknown-section", f"line {lineno}",
                 f"section '{title}' appears twice — each section has exactly one home")
            continue
        seen[key] = (n, lineno, title)
        m = NUMBERED.match(title)
        if not m:
            fail(1, "bad-number", f"line {lineno}",
                 f"'## {title}' must be emitted as '## {n}. {titles[n]}'")
        elif int(m.group(1)) != n:
            fail(1, "bad-number", f"line {lineno}",
                 f"'## {title}' is numbered {m.group(1)} but is section {n}")

    for n, t in shape.canonical:
        if t.lower() not in seen:
            fail(1, "missing-section", f"§{n}",
                 f"required section '## {n}. {t}' is absent")

    order = [(seen[t.lower()][0], seen[t.lower()][1], t)
             for _, t in shape.canonical if t.lower() in seen]
    order_by_line = sorted(order, key=lambda r: r[1])
    if [r[0] for r in order_by_line] != sorted(r[0] for r in order_by_line):
        got = " → ".join(f"§{r[0]}" for r in order_by_line)
        fail(1, "section-out-of-order", "body",
             f"sections must appear in canonical order §1…§{shape.last}; found {got}")


# ── check 2 — the §3 features table ───────────────────────────────────────────

def check2(secs):
    block = section_body(secs, "features & acceptance criteria")
    if block is None:
        fail(2, "missing-features-table", "§3", "no '## 3. Features & acceptance criteria' section")
        return
    headers, rows = md_table(strip_examples(block))
    if headers is None:
        fail(2, "missing-features-table", "§3", "section carries no markdown table")
        return
    if headers[:4] != FEATURE_COLUMNS:
        fail(2, "bad-columns", "§3",
             f"columns must be {' | '.join(FEATURE_COLUMNS)}; found {' | '.join(headers)}")
        return
    if not rows:
        fail(2, "empty-acceptance", "§3", "features table has no rows")
        return
    for cells in rows:
        fid = cells[0].strip() if cells else ""
        crit = cells[2].strip() if len(cells) > 2 else ""
        if not crit:
            fail(2, "empty-acceptance", fid or "?",
                 "row has an empty acceptance-criterion cell")
            continue
        low = crit.lower()
        for w in WEASEL:
            if re.search(r"\b" + re.escape(w) + r"", low):
                fail(2, "weasel-token", fid or "?",
                     f"acceptance criterion uses the vague token '{w}' — name the "
                     f"observable user-goal outcome instead")
                break


# ── check 3 — F-ID sequence ───────────────────────────────────────────────────

def check3(secs):
    block = section_body(secs, "features & acceptance criteria")
    if block is None:
        return
    _, rows = md_table(strip_examples(block))
    ids = [(c[0].strip() if c else "") for c in rows]
    nums, seen = [], set()
    for raw in ids:
        m = re.match(r"^F(\d+)$", raw)
        if not m:
            fail(3, "bad-fid", raw or "?", f"'{raw}' is not a well-formed F-ID (F1, F2, …)")
            continue
        n = int(m.group(1))
        if raw in seen:
            fail(3, "fid-duplicate", raw, f"{raw} appears more than once")
            continue
        seen.add(raw)
        nums.append(n)
    if nums and nums != list(range(1, len(nums) + 1)):
        fail(3, "fid-gap", "§3",
             "F-IDs must run F1..Fn with no gaps and in order; found "
             + ", ".join("F%d" % n for n in nums))


# ── check 4 — reserved placeholders byte-exact ────────────────────────────────

def check4(secs, shape):
    titles = dict(shape.canonical)
    for n, text in shape.reserved.items():
        block = section_body(secs, titles[n].lower())
        if block is None:
            continue                       # already a check-1 failure
        body = [l.rstrip() for l in block if l.strip() and not l.strip().startswith("```")]
        if not body:
            fail(4, "placeholder-drift", f"§{n}",
                 f"section is empty — it must carry the exact reserved placeholder "
                 f"'{text}' until {shape.owners[n]} fills it")
            continue
        if any(l.strip() == text for l in body):
            continue                       # byte-exact placeholder present
        _, rows = md_table(body)
        if rows or any(l.strip().startswith("###") for l in body):
            continue                       # genuinely populated by its owner
                                           # (a header-only skeleton is NOT populated)
        fail(4, "placeholder-drift", f"§{n}",
             f"section is neither populated nor carrying the byte-exact placeholder "
             f"'{text}' — do not paraphrase or pre-fill it")


# ── check 5 — frontmatter ─────────────────────────────────────────────────────

def check5(fm, shape):
    for key, pattern in shape.required.items():
        if key not in fm:
            fail(5, "missing-key", key, "required frontmatter key is absent")
        elif not pattern.match(fm[key]):
            fail(5, "bad-value", key,
                 f"value '{fm[key]}' does not match the legal form {pattern.pattern}")
    for key in shape.lists:
        if key not in fm:
            fail(5, "missing-key", key, "required frontmatter key is absent")
        elif not re.match(r"^\[.*\]$", fm[key]):
            fail(5, "bad-value", key,
                 f"value '{fm[key]}' must be a YAML flow list, e.g. [] or [prd-2-slug]")


# ── helpers ───────────────────────────────────────────────────────────────────

def section_body(secs, want_lower):
    for title, _, block in secs:
        if canon(title) == want_lower:
            return block
    return None


def strip_examples(block):
    """Drop everything from the '**Worked example:**' marker onward."""
    for i, ln in enumerate(block):
        if ln.strip().lower().startswith("**worked example"):
            return block[:i]
    return block


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-prd-shape.py")
    ap.add_argument("prd")
    ap.add_argument("--checks", default="1,2,3,4,5")
    args = ap.parse_args()

    wanted = {c.strip() for c in args.checks.split(",") if c.strip()}
    unknown = wanted - {"1", "2", "3", "4", "5"}
    if unknown:
        die(f"unknown check(s): {','.join(sorted(unknown))} (this script owns 1..5)")
    if not wanted:
        die("--checks resolved to an empty set")

    prd = Path(args.prd)
    if not prd.is_file():
        die(f"no such PRD file: {args.prd}")
    try:
        lines = prd.read_text(encoding="utf-8").split("\n")
    except OSError as exc:
        die(f"cannot read {args.prd}: {exc}")

    fm, body_start = split_frontmatter(lines)
    if fm is None:
        die(f"no YAML frontmatter in {args.prd}")

    secs = h2_sections(lines, body_start)
    shape = detect_shape(fm)

    if "1" in wanted:
        check1(secs, shape)
    if "2" in wanted:
        check2(secs)
    if "3" in wanted:
        check3(secs)
    if "4" in wanted:
        check4(secs, shape)
    if "5" in wanted:
        check5(fm, shape)

    for check, code, ref, detail in sorted(FAILURES, key=lambda f: (f[0], f[1], f[2])):
        print(f"FAIL check={check} code={code} ref={ref} detail={detail}")
    print(f"SUMMARY shape={shape.name} checks={','.join(sorted(wanted))} failures={len(FAILURES)}")
    sys.exit(1 if FAILURES else 0)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
script-eng-fix-grade.py — the ONE simple/complex fix-complexity grader.

Scripts the rubric in `eng/refs/build/fix-build-orchestrated.md` § Complexity
rubric. Both readers of that rubric — `eng --plan report=` (which tags each fix
ticket ahead of time) and the orchestrated fix-build (which grades as a
fallback when no plan tag exists) — call this script, so the two passes cannot
drift. There are zero prose copies of the predicate.

ESCALATION IS THE MODEL'S ONLY POWER OVER THIS GRADE. A calling agent MAY
override `simple` → `complex` when the issue looks scarier than its fields
suggest (that is where the old rubric's one judgment clause went). It may
NEVER downgrade `complex` → `simple`. An over-powered subagent is safe; an
under-powered one on a security or migration fix is not.

Usage:
  script-eng-fix-grade.py <report.json> [--issue <id>] [--tsv]
  script-eng-fix-grade.py -            # projected tickets or findings on stdin

  <report.json>  a `/pre-merge` issues file (`report-prd-<N>-<K>.json`), or `-`
                 for JSON on stdin. Stdin accepts either the same issues-file
                 shape, the `{"tickets": [...]}` document emitted by
                 `script-project-findings.py`, or a bare JSON array of
                 finding/ticket objects — so a grouped fix ticket carrying more
                 than one file can be graded as well as a raw finding.
  --issue <id>   grade only this id.
  --tsv          emit `<id>\\t<complexity>\\t<tier>\\t<model>` and nothing else.

Signals read per issue (all from the finding / projected ticket):
  nfiles          len(files), or 1 when `file` is set and 0 when it is null
  category        the finding category enum
  suggestion      present / absent
  regression_of   set / null
  file            null (a suite-level finding) or a path
  repro           present / absent, and its length

The predicate (deterministic, evaluated in this order):
  1. Any COMPLEX signal fires → complex.
       multi-file (nfiles > 1) · category ∈ {security, migration, schema,
       architecture, performance, perf, integration, e2e, contract} · no
       suggestion · regression_of set · file is null (suite-level)
  2. Else category ∈ {mechanical, lint, format, typecheck, dead-code,
     duplication, readability, naming, coverage} → simple.
  3. Else a localized single-assertion `unit` failure with a small repro
     (category == "unit", repro present and ≤ 120 chars) → simple.
  4. Else → complex (mixed or ambiguous signals grade complex by rule).

Tier → model (the one mapping): fast tier = sonnet · deep tier = opus. A
model-family change is this line of this script, nowhere else.

Output (stdout, one record per issue, then a summary):
  GRADE id=<id> complexity=<simple|complex> tier=<fast|deep> model=<name> reason=<slugs>
  SUMMARY issues=<n> simple=<n> complex=<n>

Reason slugs: multi-file · complex-category · no-suggestion · regression ·
suite-level · simple-category · localized-unit · ambiguous

Exit codes:
  0  every issue graded
  1  the file parsed but its content is invalid (no issues, unknown --issue id)
  2  usage error, file not found, or unparseable JSON

Deterministic: identical input produces byte-identical output.
"""
import argparse
import json
import sys
from pathlib import Path

SELF = "script-eng-fix-grade"

COMPLEX_CATEGORIES = {"security", "migration", "schema", "migration/schema",
                      "architecture", "performance", "perf", "integration",
                      "e2e", "contract"}

SIMPLE_CATEGORIES = {"mechanical", "lint", "format", "formatting", "typecheck",
                     "dead-code", "duplication", "readability", "naming",
                     "coverage"}

# A `unit` failure only grades simple when its repro is small enough to be a
# localized single-assertion re-run rather than a whole-suite invocation.
SMALL_REPRO_CHARS = 120

TIER = {"simple": ("fast", "sonnet"), "complex": ("deep", "opus")}


def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)


def nfiles_of(obj):
    files = obj.get("files")
    if isinstance(files, list):
        return len(files)
    return 1 if obj.get("file") else 0


def grade(obj):
    """→ (complexity, [reason slugs]). See the module docstring's predicate."""
    category = (obj.get("category") or "").strip().lower()
    suggestion = obj.get("suggestion")
    regression = obj.get("regression_of")
    repro = obj.get("repro")
    nfiles = nfiles_of(obj)
    suite_level = nfiles == 0

    reasons = []
    if nfiles > 1:
        reasons.append("multi-file")
    if category in COMPLEX_CATEGORIES:
        reasons.append("complex-category")
    if not suggestion:
        reasons.append("no-suggestion")
    if regression:
        reasons.append("regression")
    if suite_level:
        reasons.append("suite-level")
    if reasons:
        return "complex", reasons

    if category in SIMPLE_CATEGORIES:
        return "simple", ["simple-category"]
    if category == "unit" and repro and len(repro) <= SMALL_REPRO_CHARS:
        return "simple", ["localized-unit"]
    return "complex", ["ambiguous"]


def load(locator, text):
    try:
        doc = json.loads(text)
    except (ValueError, TypeError) as exc:
        die(f"{SELF}: {locator} is not parseable JSON ({exc})")
    if isinstance(doc, list):
        items = doc
    elif isinstance(doc, dict):
        items = doc.get("tickets") or doc.get("issues") or []
    else:
        die(f"{SELF}: {locator} top level is {type(doc).__name__}, "
            f"expected an object or array")
    if not items:
        die(f"{SELF}: {locator} carries no issues[]/tickets[] to grade", 1)
    for i, obj in enumerate(items):
        if not isinstance(obj, dict):
            die(f"{SELF}: {locator} entry {i} is {type(obj).__name__}, "
                f"expected an object", 1)
    return items


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-eng-fix-grade.py")
    ap.add_argument("report")
    ap.add_argument("--issue", default=None)
    ap.add_argument("--tsv", action="store_true")
    args = ap.parse_args()

    if args.report == "-":
        locator, text = "<stdin>", sys.stdin.read()
    else:
        path = Path(args.report)
        if not path.is_file():
            die(f"{SELF}: no such report file: {args.report}")
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            die(f"{SELF}: cannot read {args.report}: {exc}")
        locator = args.report

    items = load(locator, text)

    if args.issue is not None:
        items = [o for o in items if o.get("id") == args.issue]
        if not items:
            die(f"{SELF}: {locator} has no issue with id {args.issue}", 1)

    counts = {"simple": 0, "complex": 0}
    for obj in items:
        complexity, reasons = grade(obj)
        counts[complexity] += 1
        tier, model = TIER[complexity]
        ident = obj.get("id") or "?"
        if args.tsv:
            print(f"{ident}\t{complexity}\t{tier}\t{model}")
        else:
            print(f"GRADE id={ident} complexity={complexity} tier={tier} "
                  f"model={model} reason={','.join(reasons)}")

    if not args.tsv:
        print(f"SUMMARY issues={len(items)} simple={counts['simple']} "
              f"complex={counts['complex']}")
    sys.exit(0)


if __name__ == "__main__":
    main()

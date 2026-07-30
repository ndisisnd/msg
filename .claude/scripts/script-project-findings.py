#!/usr/bin/env python3
"""
script-project-findings.py — the ONE finding → issue-ticket projection.

Reads a `/pre-merge` issues file (`report-prd-<N>-<K>.json`, canonical findings
per `shared/refs/finding-schema.md`) and emits the projected **issue-tickets**
as JSON. It is the single implementation of the projection that
`eng/refs/build/fix-build.md` § Finding → issue-ticket projection specifies;
`eng --build report=`, `eng --plan report=` and the `--gui` board all consume
this script instead of re-deriving the mapping. Two copies of a
drift-prevention contract are worse than none, so there is exactly one here.

It doubles as the **issues-file validator**: the `Hard failure: report … not
found / unparseable / no findings / malformed` checks that used to be prose
instructions are this script's exit codes.

READ-ONLY BY CONSTRUCTION. The script opens the issues file for reading and
never writes it — the file stays canonical findings on disk and the projection
stays a read-time view. The single sanctioned write to an issues file lives in
`script-eng-close-loop.py` (`followUp.status`, nothing else).

Usage:
  script-project-findings.py <report.json> [--issue <id>] [--validate-only]
                             [--compact]

  <report.json>     path to the issues file, or `-` to read JSON from stdin
                    (stdin locator is reported as `<stdin>`).
  --issue <id>      project only the finding with this `id` (the orchestrated
                    fix-build injects one ticket per subagent). Unknown id is
                    a validation failure.
  --validate-only   run the validator and emit no tickets (exit code is the
                    whole answer).
  --compact         emit single-line JSON instead of indent=2.

Output (stdout, on success only — nothing else is ever printed to stdout, so
the document is safely pipeable):

  {"file": "<path>", "count": <n>, "tickets": [ <issue-ticket>, … ]}

Field mapping — the projection's one definition (documentation, not a second
implementation; the code below IS the contract):

  kind          literal "issue"
  id            finding `id` verbatim (`unit-002`) — its non-F<n>-T<k> shape
                itself signals an issue and keeps dedup/depends-on handles stable
  title         finding `message`
  objective     `suggestion` when present, else "Restore correct behavior — <message>"
  type          "test" when `category` is a test bucket (unit, e2e, functional,
                qa, a11y, api, mobile, coverage, load, perf, integration,
                contract), else "code"
  files         [{"path": <file>, "action": "edit"}], or [] when `file` is null.
                `action` is always "edit" — `file` is where the SYMPTOM was
                observed, not a command to edit that path; the build's codebase
                scan still resolves the real target
  dependsOn     [] — findings carry no dependency graph
  doneWhen      "<repro> passes and the covering test file is green", or
                "the finding no longer reproduces" when `repro` is null

Preserved diagnostic fields (copied verbatim, never dropped — the fix flow and
the GUI side panel need them):

  severity · category · source · rule · repro · evidence.snippet · suggestion
  · flaky (from `evidence.flaky`) · regression_of

`source` is the one field normalized on read: retired wire values are mapped to
their current name via LEGACY_SOURCE (e.g. `pair-review` → `eng:review`) so an
already-committed report stays readable after a producer is renamed. Nothing is
ever rejected for carrying an old value, and the file on disk is not rewritten.

Key casing is camelCase (`dependsOn`, `doneWhen`) because the projected ticket
is consumed by the `--gui` board's JSON contract. The prose ticket schema
(`eng/refs/plan/template-todo.md`) renders the same fields hyphenated in
markdown; same contract, two renderings.

Validation (required finding fields, per shared/refs/finding-schema.md):
  id · source · severity · category · rule · message
A finding missing any of them cannot be projected or complexity-graded.

Errors (stderr; the message text is what the calling skill emits verbatim):
  Hard failure: report <path> not found or unparseable
  Hard failure: report <path> has no findings to plan
  Hard failure: report <path> finding <id|index> is malformed: <detail>
  Hard failure: report <path> has no finding with id <id>

Exit codes:
  0  projection emitted (or validation passed under --validate-only)
  1  the file parsed but its content is invalid (empty issues[], malformed
     finding, unknown --issue id)
  2  usage error, file not found, or unparseable JSON

Deterministic: identical input produces byte-identical output.
"""
import argparse
import json
import sys
from pathlib import Path

SELF = "script-project-findings"

# Categories whose findings are test failures; everything else is code work.
CATEGORY_TEST = {"unit", "e2e", "functional", "qa", "a11y", "api", "mobile",
                 "coverage", "load", "perf", "integration", "contract"}

# The finding fields the projection and the complexity grader read structurally.
REQUIRED = ("id", "source", "severity", "category", "rule", "message")

# ---------------------------------------------------------------- legacy wire values
# THE legacy-wire-value map. Committed reports on disk keep whatever `source`
# was canonical the day they were written, so a producer rename must never make
# an old report unreadable: retired values are mapped on read, never rejected.
# This is the single implementation for every reader on this path — the
# `/msg --gui` board imports this module rather than re-deriving the mapping.
# Adding a rename is one line here; see `shared/refs/finding-schema.md`
# § Legacy wire values, which lists the same table in prose. Dedup/regression
# keys never match on `source`, so mapping a value cannot change how findings
# group.
LEGACY_SOURCE = {
    "pair-review": "eng:review",   # v5: per-ticket pair review → one eng --review
    "post-merge": "merge",         # v5: the ship gate was renamed post-merge → merge
}


def normalize_source(value):
    """Map a retired `source` wire value onto its current name; pass others through."""
    if not isinstance(value, str):
        return value
    # A deduped finding carries a comma-separated list of merged sources.
    return ",".join(LEGACY_SOURCE.get(p.strip(), p.strip()) for p in value.split(","))


def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)


def project_finding(f):
    """Canonical finding → issue-ticket. The one definition; see module docstring."""
    msg = f.get("message") or f.get("title") or f.get("id") or "finding"
    suggestion = f.get("suggestion")
    repro = f.get("repro")
    ev = f.get("evidence") or {}
    return {
        "kind": "issue",
        "id": f.get("id"),
        "title": msg,
        "objective": (suggestion if suggestion else "Restore correct behavior — %s" % msg),
        "type": "test" if (f.get("category") in CATEGORY_TEST) else "code",
        "files": ([{"path": f["file"], "action": "edit"}] if f.get("file") else []),
        "dependsOn": [],
        "doneWhen": ("%s passes and the covering test file is green" % repro) if repro
                    else "the finding no longer reproduces",
        "severity": f.get("severity"),
        "category": f.get("category"),
        "source": normalize_source(f.get("source")),
        "rule": f.get("rule"),
        "repro": repro,
        "evidence": {"snippet": ev.get("snippet")},
        "suggestion": suggestion,
        "flaky": bool(ev.get("flaky")),
        "regression_of": f.get("regression_of"),
    }


def load_issues(locator, text):
    """Parse + validate; return the findings list. Exits on any hard failure."""
    try:
        doc = json.loads(text)
    except (ValueError, TypeError) as exc:
        die(f"Hard failure: report {locator} not found or unparseable ({exc})")
    if not isinstance(doc, dict):
        die(f"Hard failure: report {locator} not found or unparseable "
            f"(top level is {type(doc).__name__}, expected a JSON object)")
    issues = doc.get("issues")
    if not issues or not isinstance(issues, list):
        die(f"Hard failure: report {locator} has no findings to plan", 1)
    for i, f in enumerate(issues):
        if not isinstance(f, dict):
            die(f"Hard failure: report {locator} finding {i} is malformed: "
                f"expected an object, got {type(f).__name__}", 1)
        missing = [k for k in REQUIRED if f.get(k) in (None, "")]
        if missing:
            ref = f.get("id") or i
            die(f"Hard failure: report {locator} finding {ref} is malformed: "
                f"missing required field(s) {', '.join(missing)}", 1)
    return issues


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-project-findings.py")
    ap.add_argument("report")
    ap.add_argument("--issue", default=None)
    ap.add_argument("--validate-only", action="store_true")
    ap.add_argument("--compact", action="store_true")
    args = ap.parse_args()

    if args.report == "-":
        locator, text = "<stdin>", sys.stdin.read()
    else:
        path = Path(args.report)
        if not path.is_file():
            die(f"Hard failure: report {args.report} not found or unparseable "
                f"(no such file)")
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            die(f"Hard failure: report {args.report} not found or unparseable ({exc})")
        locator = args.report

    issues = load_issues(locator, text)

    if args.issue is not None:
        issues = [f for f in issues if f.get("id") == args.issue]
        if not issues:
            die(f"Hard failure: report {locator} has no finding with id {args.issue}", 1)

    if args.validate_only:
        sys.exit(0)

    out = {"file": locator, "count": len(issues),
           "tickets": [project_finding(f) for f in issues]}
    if args.compact:
        print(json.dumps(out, separators=(",", ":"), ensure_ascii=False))
    else:
        print(json.dumps(out, indent=2, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    main()

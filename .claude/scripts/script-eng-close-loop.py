#!/usr/bin/env python3
"""
script-eng-close-loop.py — the ONE sanctioned write to an issues file.

`eng --build report=<path>` closes the fix loop by recording that the findings
were acted on: it sets `followUp.status` to `resolved` or `partially_resolved`.
That is the *only* mutation build mode may make to
`report-prd-<N>-<K>.json` — `issues[]` and every other field must stay
canonical, because `/pre-merge`'s dedup and regression keys (`id`, `rule`,
`regression_of`) and the `--gui` board read them back.

Until now that promise was prose and the edit was done by hand. This script
makes the promise physically true: it rewrites exactly the status string and
nothing else, and PROVES it before the file is replaced.

How "touches nothing else" is guaranteed, in order:
  1. The status value is replaced as a **text splice** on the original bytes —
     the file is never re-serialized, so indentation, key order, trailing
     newline and unicode escaping are untouched by construction.
  2. The bytes before the spliced span and the bytes after it are asserted
     byte-identical to the original. Any drift aborts before any write.
  3. Both documents are re-parsed and compared with the status field masked
     out; any semantic difference aborts before any write.
  4. Only then is the new text written to a temp file in the same directory
     and moved into place with os.replace (atomic on POSIX) — a crash mid-run
     leaves the original intact rather than a truncated issues file.

Usage:
  script-eng-close-loop.py <report.json> resolved|partially_resolved [--dry-run]

  <report.json>   the issues file whose loop is being closed.
  --dry-run       run every check and print the verdict; write nothing.

Choosing the value (eng/refs/build/fix-build.md § Closing the loop):
  resolved             every issue verified green
  partially_resolved   one or more issues escalated (3-cycle debug bound hit)
                       or left unreproduced (flaky)

Output (stdout):
  CLOSED file=<path> status=<new> previous=<old> changed=<yes|no>
  VERIFIED outside-span=byte-identical document=equal-except-followUp.status
  DRY_RUN  (printed instead of CLOSED when --dry-run is passed)

Failure messages (stderr) are what the calling skill emits verbatim:
  Hard failure: report <path> not found or unparseable
  Hard failure: report <path> has no followUp object to close
  Hard failure: report <path> followUp has no status field to update
  Hard failure: report <path> close-loop verification failed: <detail>

Exit codes:
  0  status written (or verified under --dry-run)
  1  the file parsed but cannot be closed (no followUp / no status), or a
     verification assertion failed — nothing was written
  2  usage error, file not found, or unparseable JSON

Deterministic: identical input produces byte-identical output, and running it
twice with the same status is a no-op rewrite of the same bytes.
"""
import argparse
import copy
import json
import os
import re
import sys
import tempfile
from pathlib import Path

SELF = "script-eng-close-loop"

LEGAL = ("resolved", "partially_resolved")


def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)


def object_span(text, start):
    """Byte span of the JSON object whose opening brace is at/after `start`.
    Brace-counting that respects strings and escapes."""
    i = text.index("{", start)
    depth, j, in_str, esc = 0, i, False, False
    while j < len(text):
        ch = text[j]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i, j + 1
        j += 1
    raise ValueError("unterminated object")


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-eng-close-loop.py")
    ap.add_argument("report")
    ap.add_argument("status", choices=LEGAL)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    path = Path(args.report)
    if not path.is_file():
        die(f"Hard failure: report {args.report} not found or unparseable (no such file)")
    try:
        original = path.read_text(encoding="utf-8")
    except OSError as exc:
        die(f"Hard failure: report {args.report} not found or unparseable ({exc})")
    try:
        doc = json.loads(original)
    except ValueError as exc:
        die(f"Hard failure: report {args.report} not found or unparseable ({exc})")
    if not isinstance(doc, dict):
        die(f"Hard failure: report {args.report} not found or unparseable "
            f"(top level is {type(doc).__name__}, expected a JSON object)")

    follow = doc.get("followUp")
    if not isinstance(follow, dict):
        die(f"Hard failure: report {args.report} has no followUp object to close", 1)
    if "status" not in follow:
        die(f"Hard failure: report {args.report} followUp has no status field to update", 1)
    previous = follow.get("status")

    # ── 1. locate the status string INSIDE the followUp object and splice it ──
    key = re.search(r'"followUp"\s*:', original)
    if not key:
        die(f"Hard failure: report {args.report} has no followUp object to close", 1)
    try:
        obj_start, obj_end = object_span(original, key.end())
    except ValueError as exc:
        die(f"Hard failure: report {args.report} not found or unparseable ({exc})")
    block = original[obj_start:obj_end]
    hit = re.search(r'("status"\s*:\s*")((?:[^"\\]|\\.)*)(")', block)
    if not hit:
        die(f"Hard failure: report {args.report} followUp has no status field to update", 1)

    span_start = obj_start + hit.start(2)
    span_end = obj_start + hit.end(2)
    updated = original[:span_start] + args.status + original[span_end:]
    new_span_end = span_start + len(args.status)

    # ── 2. everything outside the spliced span is byte-identical ─────────────
    if updated[:span_start] != original[:span_start] or \
       updated[new_span_end:] != original[span_end:]:
        die(f"Hard failure: report {args.report} close-loop verification failed: "
            f"bytes outside the followUp.status span changed", 1)

    # ── 3. both documents are equal once the status field is masked out ──────
    try:
        redoc = json.loads(updated)
    except ValueError as exc:
        die(f"Hard failure: report {args.report} close-loop verification failed: "
            f"result is not parseable JSON ({exc})", 1)
    if redoc.get("followUp", {}).get("status") != args.status:
        die(f"Hard failure: report {args.report} close-loop verification failed: "
            f"the spliced status did not land in followUp.status", 1)
    a, b = copy.deepcopy(doc), copy.deepcopy(redoc)
    a["followUp"]["status"] = b["followUp"]["status"] = "\0masked"
    if a != b:
        die(f"Hard failure: report {args.report} close-loop verification failed: "
            f"a field other than followUp.status changed", 1)

    changed = "no" if previous == args.status else "yes"
    if args.dry_run:
        print(f"DRY_RUN file={args.report} status={args.status} "
              f"previous={previous} changed={changed}")
        print("VERIFIED outside-span=byte-identical "
              "document=equal-except-followUp.status")
        sys.exit(0)

    # ── 4. atomic replace ────────────────────────────────────────────────────
    directory = str(path.parent) or "."
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".close-loop-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as fh:
            fh.write(updated)
        os.replace(tmp, str(path))
    except OSError as exc:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        die(f"{SELF}: cannot write {args.report}: {exc}")

    print(f"CLOSED file={args.report} status={args.status} "
          f"previous={previous} changed={changed}")
    print("VERIFIED outside-span=byte-identical "
          "document=equal-except-followUp.status")
    sys.exit(0)


if __name__ == "__main__":
    main()

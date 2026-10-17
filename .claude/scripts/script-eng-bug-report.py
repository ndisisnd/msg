#!/usr/bin/env python3
"""
script-eng-bug-report.py — write a bug the user found by hand as a new report.

`/eng --bug "<what is wrong>"` files the bug in the same format pre-merge
writes, so the normal fix flow (`eng --build report=<json>`) and the `--gui`
Reports tab read it unchanged:

  report-prd-<N>-<K>.json   the issues file: issues[] + context + summary
                            + followUp (shared/refs/report-schema.md)
  report-prd-<N>-<K>.md     the run report, with the fixed section contract

`<K>` is the next free number in the PRD's reports/ folder. Every call writes
a NEW pair; an existing report is never edited (the write refuses to replace
a file that already exists).

Choosing the PRD (in order):
  --prd <prd.md | prd folder>  the PRD the user named
  --no-prd                     the no-PRD fallback: features/reports/report-<K>.*
  neither                      from the branch: feat/prd-<N>-<slug> → the folder
                               features/**/prd-<N>-*/ (lanes and sub-PRDs included)

Usage:
  script-eng-bug-report.py --description "<what is wrong>"
      [--prd <path> | --no-prd] [--branch <name>] [--file <path>]
      [--repro <command>] [--severity blocker|high|medium|low]
      [--category <category>] [--date <ISO-8601 UTC>] [--root <dir>]

Output (stdout, KEY=VALUE lines):
  REPORT_JSON=<path>   the issues file — pass it to eng --build report=
  REPORT_MD=<path>
  K=<k>

Exit codes:
  0  both files written
  1  the PRD could not be chosen; one line explains it:
       PRD_UNRESOLVED branch=<b>      the branch names no PRD, or no folder matches
       PRD_AMBIGUOUS <path> <path>…   more than one PRD folder matches
     The caller asks the user once (a PRD, or "No PRD") and calls again.
  2  usage error, an unknown PRD path, or a write failure
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

SEVERITIES = ("blocker", "high", "medium", "low")


def die(msg, code=2):
    print(msg, file=sys.stderr)
    sys.exit(code)


def current_branch(root):
    """The checked-out branch name, or 'none' outside a git repo."""
    try:
        out = subprocess.run(["git", "-C", root, "rev-parse", "--abbrev-ref", "HEAD"],
                             capture_output=True, text=True, check=True).stdout.strip()
        return out or "none"
    except (OSError, subprocess.CalledProcessError):
        return "none"


def prd_dirs_for(root, num):
    """Every PRD folder under features/ whose name is prd-<num>-<slug>."""
    hits = set()
    for pat in ("features/prd-%s-*" % num, "features/*/prd-%s-*" % num,
                "features/*/*/prd-%s-*" % num):
        for d in glob.glob(os.path.join(root, pat)):
            if os.path.isdir(d) and os.path.basename(d) != "reports":
                hits.add(os.path.relpath(d, root))
    return sorted(hits)


def prd_file_in(root, rel_dir):
    """The PRD .md inside a PRD folder (same stem as the folder), or None."""
    name = os.path.basename(rel_dir) + ".md"
    path = os.path.join(rel_dir, name)
    return path if os.path.isfile(os.path.join(root, path)) else None


def next_k(dirpath, stem_prefix):
    """max(existing K) + 1 over <stem_prefix><K>.md / .json in dirpath."""
    rx = re.compile(re.escape(stem_prefix) + r"(\d+)\.(md|json)$")
    ks = [int(m.group(1)) for f in (os.listdir(dirpath) if os.path.isdir(dirpath) else [])
          for m in [rx.match(f)] if m]
    return (max(ks) if ks else 0) + 1


def slug(text):
    """A stable rule id from the description: lower-case words joined by '-'."""
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return ("user-report-" + s[:48]).rstrip("-")


def write_new(path, text):
    """Write a file that must not exist yet — reports are append-only."""
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    except FileExistsError:
        die("script-eng-bug-report: %s already exists — reports are never edited" % path)
    except OSError as exc:
        die("script-eng-bug-report: cannot write %s: %s" % (path, exc))
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(text)


def main():
    ap = argparse.ArgumentParser(prog="script-eng-bug-report.py")
    ap.add_argument("--description", required=True)
    grp = ap.add_mutually_exclusive_group()
    grp.add_argument("--prd")
    grp.add_argument("--no-prd", action="store_true")
    ap.add_argument("--branch")
    ap.add_argument("--file")
    ap.add_argument("--repro")
    ap.add_argument("--severity", default="high", choices=SEVERITIES)
    ap.add_argument("--category", default="functional")
    ap.add_argument("--date")
    ap.add_argument("--root", default=".")
    args = ap.parse_args()

    desc = " ".join(args.description.split())
    if not desc:
        die("script-eng-bug-report: --description is empty")
    root = args.root
    branch = args.branch or current_branch(root)
    generated = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # ── choose the PRD ──────────────────────────────────────────────────────
    prd_dir = prd_path = num = None
    if args.prd:
        p = args.prd.rstrip("/")
        cand = p if os.path.isdir(os.path.join(root, p)) else os.path.dirname(p)
        if not re.match(r"prd-\d+(?:\.\d+)?-", os.path.basename(cand)) \
                or not os.path.isdir(os.path.join(root, cand)):
            die("script-eng-bug-report: --prd %s is not a PRD file or folder" % args.prd)
        prd_dir = cand
    elif not args.no_prd:
        m = re.match(r"^feat/prd-(\d+(?:\.\d+)?)-", branch)
        if not m:
            print("PRD_UNRESOLVED branch=%s" % branch)
            sys.exit(1)
        hits = prd_dirs_for(root, m.group(1))
        if not hits:
            print("PRD_UNRESOLVED branch=%s" % branch)
            sys.exit(1)
        if len(hits) > 1:
            print("PRD_AMBIGUOUS " + " ".join(hits))
            sys.exit(1)
        prd_dir = hits[0]
    if prd_dir:
        num = re.match(r"prd-(\d+(?:\.\d+)?)-", os.path.basename(prd_dir)).group(1)
        prd_path = prd_file_in(root, prd_dir) or prd_dir
        reports = os.path.join(prd_dir, "reports")
        prefix = "report-prd-%s-" % num
    else:
        reports = os.path.join("features", "reports")
        prefix = "report-"

    os.makedirs(os.path.join(root, reports), exist_ok=True)
    k = next_k(os.path.join(root, reports), prefix)
    stem = os.path.join(reports, "%s%d" % (prefix, k))
    json_rel, md_rel = stem + ".json", stem + ".md"
    run_label = ("%s-%d" % (num, k)) if num else str(k)

    # ── the issues file ─────────────────────────────────────────────────────
    finding = {
        "id": "bug-001",
        "source": "eng:bug",
        "severity": args.severity,
        "category": args.category,
        "rule": slug(desc),
        "message": desc if len(desc) <= 80 else desc[:77].rstrip() + "...",
        "file": args.file,
        "line": None,
        "evidence": {"tool": "user-report", "file": args.file, "line": None,
                     "snippet": desc},
        "suggestion": None,
        "repro": args.repro,
        "regression_of": None,
    }
    summary = {s: (1 if s == args.severity else 0) for s in SEVERITIES}
    doc = {
        "run_id": "bug-%s" % run_label,
        "gate": "eng:bug",
        "verdict": "fail",
        "context": {"base": None, "branch": branch, "prd": prd_path or "none",
                    "files_changed": [args.file] if args.file else [], "diff_stat": {}},
        "summary": summary,
        "issues": [finding],
        "followUp": {"status": "open",
                     "suggested_command": "eng --build report=%s" % json_rel},
    }

    # ── the run report (shared/refs/report-schema.md section contract) ──────
    sev_line = " · ".join("%s %d" % (s, summary[s]) for s in SEVERITIES)
    md = """---
skill: eng
prd: {prd}
branch: {branch}
verdict: fail
features: []
files_changed: 0
lines_added: 0
lines_removed: 0
tests_passed: 0
tests_failed: 0
generated: {generated}
---

# Report {label} — eng — Bug found by hand: {title}

## Summary
A bug was reported by hand: {desc} It is filed for the normal fix flow.

## Issue summary
**Total:** 1 issue(s)

| Category | Count |
|----------|-------|
| {category} | 1 |

**By severity:** {sev_line}

## Work done
None. This report files the bug; the fix build writes its own report.

## Code changes
None.

## Test results
None. No tests ran.

## What to expect
The bug is open. Run `eng --build report={json_rel}` to fix it.

## How to verify
1. {verify}

## Links
- Issues file: `{json_rel}`
- PRD: {prd}
""".format(prd=prd_path or "none", branch=branch, generated=generated, label=run_label,
           title=finding["message"], desc=desc if desc.endswith(".") else desc + ".",
           category=args.category, sev_line=sev_line, json_rel=json_rel,
           verify=("Run `%s` — it should pass once the bug is fixed." % args.repro)
           if args.repro else "Repeat what you did when you saw the bug — it should no longer happen.")

    write_new(os.path.join(root, json_rel), json.dumps(doc, indent=2) + "\n")
    write_new(os.path.join(root, md_rel), md)
    print("REPORT_JSON=" + json_rel)
    print("REPORT_MD=" + md_rel)
    print("K=%d" % k)
    sys.exit(0)


if __name__ == "__main__":
    main()

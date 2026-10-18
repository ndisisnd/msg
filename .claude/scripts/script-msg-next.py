#!/usr/bin/env python3
"""
script-msg-next.py — the next step for each piece of work in progress.

Bare `/msg` prints "Next: <command> — <why>" per PRD in progress. Which step comes
next is a lookup over files and git, never judgment, so this script owns it and the
model only renders the lines.

Contract: .claude/skills/msg/refs/protocol-default.md

Reads (all read-only):
  devkit/                          absent ⇒ the one line is `/msg --init`
  devkit/policy.json               the release flow, via script-policy-read.py
  features/<lane>/prd-*/           via script-prd-scan.sh (top-level PRDs only)
  PRD frontmatter                  `reviewed`, `staging-signoff`
  PRD body                         a `## Todos —` heading ⇒ planned
  <prd-dir>/reports/report-*.md    an eng report with a passing verdict ⇒ built
  .pre-merge/last-check.json       pre-merge's last check per branch (commit + verdict)
  git                              the branch tip, and whether it is in staging
  INTAKE.md                        `backlog` rows with an empty `prd` cell

The step ladder for one PRD (first match wins; branch = feat/<prd-id>):
  staged flow, tip in staging (not prod), signed off  /merge      ready for production
  staged flow, tip in staging (not prod), no sign-off /merge      waiting for sign-off
  pre-merge passed on the branch tip                  /merge      ready to merge / ship
  pre-merge record, commit is not the tip             /pre-merge  new commits since the pass
  pre-merge record, verdict not a pass                /pre-merge  last check did not pass
  built (passing eng report), no record               /pre-merge  built, not checked
  planned (`## Todos —`), lane wip                    /eng --build  tickets not built
  planned, lane planned                               /plan-em <path>  build not started
  not planned                                         /plan-em <path>  (reviewed or not)
Lane `done` and status `retired` are skipped.

Order: closest to shipping first, then PRD number. After the PRDs, one line for the
intake rows with no PRD (`/plan-pm #<n>`, the oldest row). Nothing in progress and no
such row ⇒ one `/intake` line.

Usage:
  script-msg-next.py [--repo <dir>] [--max 4] [--last-check <path>]

Output (key=value lines):
  SETUP=yes|no
  FLOW=staged|direct
  NEXT=<command>|<why>|<prd-id or ->      one per line, at most --max
  COUNT=<n>                               NEXT lines printed
  MORE=<n>                                steps not printed (over --max)

Exit: 0 always after a scan · 1 usage.
"""

import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PASS = ("pass", "pass_with_warnings")


def run(cmd, cwd):
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    except OSError:
        return 127, ""
    return p.returncode, p.stdout


def git(repo, *args):
    return run(["git", "-C", repo] + list(args), repo)


def script(repo, name):
    for base in (os.path.join(repo, ".claude", "scripts"), HERE,
                 os.path.join(os.path.expanduser("~"), ".claude", "scripts")):
        p = os.path.join(base, name)
        if os.path.isfile(p):
            return p
    return None


def flow(repo):
    s = script(repo, "script-policy-read.py")
    kv = {}
    if s:
        _, out = run([sys.executable, s, "--file",
                      os.path.join(repo, "devkit", "policy.json")], repo)
        for line in out.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                kv[k] = v
    return (kv.get("FLOW") or "direct", kv.get("STG_BRANCH") or "staging",
            kv.get("PROD_BRANCH") or "main")


def frontmatter(path):
    fm = {}
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return fm, ""
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if m:
        for line in m.group(1).splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                fm[k.strip()] = v.split("#", 1)[0].strip()
    return fm, text


def built(prd_dir):
    rdir = os.path.join(prd_dir, "reports")
    if not os.path.isdir(rdir):
        return False
    for name in os.listdir(rdir):
        if name.startswith("report-") and name.endswith(".md"):
            fm, _ = frontmatter(os.path.join(rdir, name))
            if fm.get("skill") == "eng" and fm.get("verdict") in PASS:
                return True
    return False


def last_checks(repo, path):
    try:
        with open(os.path.join(repo, path), encoding="utf-8") as f:
            data = json.load(f)
        b = data.get("branches", {})
        return b if isinstance(b, dict) else {}
    except (OSError, ValueError, AttributeError):
        return {}


def tip(repo, branch):
    code, out = git(repo, "rev-parse", "--verify", "-q", "refs/heads/" + branch)
    return out.strip() if code == 0 else ""


def contains(repo, ref_name, sha):
    for ref in ("refs/remotes/origin/" + ref_name, "refs/heads/" + ref_name):
        if git(repo, "rev-parse", "--verify", "-q", ref)[0] == 0:
            return git(repo, "merge-base", "--is-ancestor", sha, ref)[0] == 0
    return False


def in_staging(repo, sha, stg, prod):
    """The tip is in staging and not yet in prod (a branch with no own commits is not)."""
    return bool(sha) and contains(repo, stg, sha) and not contains(repo, prod, sha)


def step(repo, prd, fl, stg, prod, checks):
    """(rank, command, why) for one PRD; rank 0 is closest to shipping."""
    path = prd["path"]
    fm, text = frontmatter(os.path.join(repo, path))
    lane = path.split("/")[1] if path.count("/") >= 2 else ""
    branch = "feat/" + prd["id"]
    head = tip(repo, branch)
    rec = checks.get(branch) or {}
    if head and fl == "staged" and in_staging(repo, head, stg, prod):
        if fm.get("staging-signoff"):
            return 0, "/merge", "signed off on staging — ready for production"
        return 1, "/merge", "on staging — test it, then give the sign-off"
    if head and rec.get("verdict") in PASS and rec.get("head") == head:
        why = "pre-merge passed — ready to ship" if fl == "direct" \
            else "pre-merge passed — ready to merge into staging"
        return 2, "/merge", why
    if rec.get("head") and rec.get("verdict") in PASS:
        return 3, "/pre-merge", "new commits since the last pre-merge pass"
    if rec.get("head"):
        return 3, "/pre-merge", "the last pre-merge check did not pass"
    if built(os.path.dirname(os.path.join(repo, path))):
        return 4, "/pre-merge", "built — not checked by pre-merge yet"
    if re.search(r"^## Todos —", text, re.M):
        if lane == "wip":
            return 5, "/eng --build", "planned — tickets not built yet"
        return 6, "/plan-em " + path, "planned — build not started"
    if fm.get("reviewed") == "yes":
        return 7, "/plan-em " + path, "reviewed — not planned yet"
    return 7, "/plan-em " + path, "drafted — plan-em reviews and plans it"


def intake_rows(repo):
    rows = []
    try:
        with open(os.path.join(repo, "INTAKE.md"), encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return rows
    cols = None
    for line in lines:
        if not line.startswith("|"):
            cols = None
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells and cells[0] == "#":
            cols = cells
            continue
        if not cols or set(line) <= set("|-: "):
            continue
        r = dict(zip(cols, cells))
        if r.get("status") == "backlog" and not r.get("prd") and r.get("#", "").isdigit():
            rows.append(r)
    return rows


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--repo", default=os.getcwd())
    ap.add_argument("--max", type=int, default=4)
    ap.add_argument("--last-check", default=".pre-merge/last-check.json")
    try:
        a = ap.parse_args()
    except SystemExit:
        sys.exit(1)
    repo = os.path.abspath(a.repo)
    out = []
    if not os.path.isdir(os.path.join(repo, "devkit")):
        print("SETUP=no")
        print("FLOW=direct")
        print("NEXT=/msg --init|this project is not set up yet|-")
        print("COUNT=1")
        print("MORE=0")
        return 0
    fl, stg, prod = flow(repo)
    checks = last_checks(repo, a.last_check)
    scan = script(repo, "script-prd-scan.sh")
    prds = []
    if scan and os.path.isdir(os.path.join(repo, "features")):
        _, raw = run(["bash", scan], repo)
        for line in raw.splitlines():
            try:
                prds.append(json.loads(line))
            except ValueError:
                pass
    steps = []
    for p in prds:
        lane = p["path"].split("/")[1] if p["path"].count("/") >= 2 else ""
        if p.get("parent") or lane == "done" or p.get("status") == "retired":
            continue
        n = re.match(r"prd-(\d+)", p["id"])
        rank, cmd, why = step(repo, p, fl, stg, prod, checks)
        steps.append((rank, int(n.group(1)) if n else 0, cmd, why, p["id"]))
    steps.sort()
    for _, _, cmd, why, pid in steps:
        out.append((cmd, why, pid))
    rows = intake_rows(repo)
    if rows:
        r = rows[0]
        why = "intake row #%s has no PRD yet" % r["#"]
        if len(rows) > 1:
            why += " (%d rows waiting)" % len(rows)
        out.append(("/plan-pm #" + r["#"], why, "-"))
    if not out:
        out.append(("/intake", "nothing in progress — capture the next idea", "-"))
    print("SETUP=yes")
    print("FLOW=" + fl)
    for cmd, why, pid in out[:a.max]:
        print("NEXT=%s|%s|%s" % (cmd, why, pid))
    print("COUNT=%d" % min(len(out), a.max))
    print("MORE=%d" % max(0, len(out) - a.max))
    return 0


if __name__ == "__main__":
    sys.exit(main())

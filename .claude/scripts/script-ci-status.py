#!/usr/bin/env python3
"""
script-ci-status.py — the check-state set + policy → ONE CI verdict.

Three merge call sites spelled the identical logic in prose: `--staging`'s
"locate the PR + verify green CI" step, `--production`'s Step 1 staging-green
precondition, and `--production`'s Step 5 release-PR check (which explicitly
says "the same check `--staging` runs, including its empty-check-set branch").
Three copies of a five-way branch is three chances to drift — and the branch
that drifts silently is the *empty set*, where "no red" must never be read as
"green". This script is the one implementation.

It also carries the fixed-result **PR resolution rider**: given a base branch
and a head branch (or a PRD path to derive `feat/prd-<n>-<slug>` from), it
locates the open PR and reports it, so the model never hand-rolls that
`gh pr list` invocation either.

Contract:
  .claude/skills/merge/refs/staging.md    § Step 2
  .claude/skills/merge/refs/production.md § Step 1, Step 5
  .claude/skills/shared/refs/policy-schema.md            §2b github_actions
  .claude/skills/shared/refs/policy-schema-merge.md §3 steps.ci

The model keeps every judgment half: what to say in the refusal, whether the
failing check names a test (that is `script-ts-miss.py`'s input), and whether a
`vacuous-ci` note is worth acting on.

Usage
  # PR mode — resolve the PR, then grade its checks
  script-ci-status.py --base staging --head feat/prd-4-search [--policy <p>]
  script-ci-status.py --base staging --prd features/wip/prd-4-search/prd.md
  script-ci-status.py --pr 128 [--policy <p>]

  # Branch mode — the commit status of a branch (production Step 1)
  script-ci-status.py --branch staging [--policy <p>]

  # Fixture / offline mode — no gh call at all
  script-ci-status.py --input <checks.json> [--policy <p>]

  --policy   devkit/policy.json (default: devkit/policy.json). Resolved through
             script-policy-read.py when that script is present — one reader, no
             second parse path — falling back to a direct read of the two keys
             this script needs (`github_actions.enabled`, `steps.ci.status`).
  --ga / --steps-ci   override the resolved policy values (testing / callers
             that already read the policy).
  --input    a JSON file holding EITHER a gh `statusCheckRollup` array, a
             `{"statusCheckRollup": [...]}` object, a bare
             `[{"name": …, "state": …}, …]` list, or a gh combined-status
             object `{"state": …, "statuses": [...]}`. This is the fixture
             mode: it is how all five verdicts are proven without a network.
  --repo     repo dir for the gh calls (default: $PWD)

Output (stdout, KEY=VALUE lines, always the full key set):
  VERDICT=green|red|pending|empty-inactive|empty-vacuous
  REASON=ok|failing_checks|pending_checks|policy_disabled|step_opted_out|
         step_na|no_ci_record|vacuous_ci|no_pr|gh_error
  SOURCE=pr|branch|input
  CHECK_COUNT=<n>
  FAILING_CHECKS=<name,…>      non-empty ⇒ VERDICT=red
  PENDING_CHECKS=<name,…>      non-empty ⇒ VERDICT=pending
  PASSING_CHECKS=<name,…>
  GA=true|false                the resolved github_actions.enabled
  GA_REASON=<text>             surfaced verbatim in the one report line
  STEPS_CI=ready|opted_out|n/a|missing|deferred|absent
  PR_NUMBER=<n>                PR-resolution rider — empty outside PR mode
  PR_URL=<url>
  HEAD_BRANCH=<name>           resolved head (from --head, or derived from --prd)
  NOTE=<one line>              exactly what the caller puts in the run report
  ERROR=<short reason>         set on REASON=gh_error / no_pr

Verdict rules (the whole branch, in one place)
  * ANY check FAILURE/ERROR/CANCELLED/TIMED_OUT/ACTION_REQUIRED → red.
  * else ANY check PENDING/IN_PROGRESS/QUEUED/REQUESTED/WAITING/EXPECTED
    → pending. (Red outranks pending: a run with one failure and one
    still-queued check is red, not pending.)
  * else (all SUCCESS/NEUTRAL/SKIPPED) → green.
  * EMPTY set (zero checks reported) is never green. It resolves against
    policy, `github_actions` outranking `steps.ci` (§2b precedence):
      ga=false                       → empty-inactive (policy_disabled)
      ga=true, steps.ci=ready        → empty-vacuous  (vacuous_ci)
      ga=true, steps.ci=opted_out    → empty-inactive (step_opted_out)
      ga=true, steps.ci=n/a          → empty-inactive (step_na)
      ga=true, ci missing/deferred/absent → empty-inactive (no_ci_record)
    Only `empty-vacuous` carries a `low` note; every `empty-inactive` flavour
    proceeds, silently or with the one policy line the NOTE key spells.

Exit codes
  0  green
  3  red            → the caller refuses `red_ci`
  4  pending        → the caller refuses `pending_ci`
  5  empty-inactive → proceed (NOTE may be a single report line)
  6  empty-vacuous  → proceed + one `low` vacuous-ci note
  7  no open PR     → the caller refuses `no_pr`
  8  gh/infra error → the caller decides (never a silent green)
  2  usage error

Deterministic: identical check set + identical policy ⇒ identical output.
"""
import argparse
import json
import os
import re
import subprocess
import sys

SELF = "script-ci-status"

RED = {"FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED",
       "STARTUP_FAILURE", "STALE"}
PENDING = {"PENDING", "IN_PROGRESS", "QUEUED", "REQUESTED", "WAITING",
           "EXPECTED"}
GREEN = {"SUCCESS", "NEUTRAL", "SKIPPED"}


def die(msg):
    sys.stderr.write("%s: %s\n" % (SELF, msg))
    sys.exit(2)


def run(cmd, cwd):
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    except OSError as exc:
        return 127, "", str(exc)
    return p.returncode, p.stdout, p.stderr


def script_path(name):
    """Repo copy first, global install second — the house resolution form."""
    local = os.path.join(".claude", "scripts", name)
    if os.path.exists(local):
        return local
    home = os.path.join(os.path.expanduser("~"), ".claude", "scripts", name)
    return home if os.path.exists(home) else None


def read_policy(path, repo):
    """github_actions.enabled + steps.ci.status, via the one reader."""
    reader = script_path("script-policy-read.py")
    if reader:
        rc, out, _ = run([sys.executable, reader, "--file", path], repo)
        if rc == 0:
            kv = dict(l.split("=", 1) for l in out.splitlines() if "=" in l)
            return (kv.get("GITHUB_ACTIONS", "true") == "true",
                    kv.get("GITHUB_ACTIONS_REASON", ""),
                    kv.get("STEPS_CI", "absent"))
    # Fall back to a direct read of exactly the two keys needed. Fail-safe:
    # an unreadable policy resolves to the built-in defaults, never an abort.
    try:
        with open(os.path.join(repo, path), "r", encoding="utf-8") as fh:
            doc = json.loads(fh.read())
        if doc.get("version") != 1:
            raise ValueError("version")
    except Exception:
        return True, "", "absent"
    ga_obj = (doc.get("policies") or {}).get("github_actions") or {}
    ga = ga_obj.get("enabled", True)
    ci = ((doc.get("steps") or {}).get("ci") or {}).get("status", "absent")
    return (ga if isinstance(ga, bool) else True), ga_obj.get("reason", ""), ci


def normalise(payload):
    """Every accepted input shape → [(name, STATE), …]."""
    if isinstance(payload, dict):
        if "statusCheckRollup" in payload:
            payload = payload.get("statusCheckRollup") or []
        elif "statuses" in payload:              # gh combined-status object
            return [(s.get("context") or s.get("name") or "?",
                     str(s.get("state", "")).upper())
                    for s in (payload.get("statuses") or [])]
        elif "check_runs" in payload:            # gh check-runs object
            payload = payload.get("check_runs") or []
        else:
            payload = [payload]
    checks = []
    for c in payload or []:
        if not isinstance(c, dict):
            continue
        name = (c.get("name") or c.get("context") or c.get("workflowName")
                or "?")
        state = (c.get("state") or c.get("conclusion") or c.get("status")
                 or c.get("bucket") or "")
        checks.append((name, str(state).upper()))
    return checks


def grade(checks):
    fail = [n for n, s in checks if s in RED]
    pend = [n for n, s in checks if s in PENDING]
    pas = [n for n, s in checks if s in GREEN]
    unknown = [n for n, s in checks if s not in RED | PENDING | GREEN]
    # An unrecognised state is treated as PENDING — degrade toward waiting,
    # never toward a green that was never proven.
    pend += unknown
    return fail, pend, pas


def branch_from_prd(prd_path):
    """`features/**/prd-<n>-<slug>/…` → `feat/prd-<n>-<slug>` (fixed result)."""
    m = re.search(r"(prd-\d+-[A-Za-z0-9._-]+)", prd_path or "")
    return "feat/%s" % m.group(1) if m else ""


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-ci-status.py")
    ap.add_argument("--pr")
    ap.add_argument("--base")
    ap.add_argument("--head")
    ap.add_argument("--prd")
    ap.add_argument("--branch")
    ap.add_argument("--input")
    ap.add_argument("--policy", default="devkit/policy.json")
    ap.add_argument("--ga", choices=["true", "false"])
    ap.add_argument("--steps-ci", dest="steps_ci")
    ap.add_argument("--repo", default=os.getcwd())
    args = ap.parse_args()

    modes = [bool(args.input), bool(args.branch),
             bool(args.pr or args.base or args.head or args.prd)]
    if sum(1 for m in modes if m) != 1:
        die("give exactly one of --input | --branch | (--pr / --base+--head)")

    ga, ga_reason, steps_ci = read_policy(args.policy, args.repo)
    if args.ga:
        ga = args.ga == "true"
    if args.steps_ci:
        steps_ci = args.steps_ci

    source = "input"
    pr_number = pr_url = head = ""
    error = ""
    checks = []

    if args.input:
        try:
            with open(args.input, "r", encoding="utf-8") as fh:
                checks = normalise(json.loads(fh.read()))
        except (OSError, ValueError) as exc:
            die("cannot read --input %s: %s" % (args.input, exc))

    elif args.branch:
        source = "branch"
        rc, out, err = run(
            ["gh", "api", "repos/{owner}/{repo}/commits/%s/status"
             % args.branch], args.repo)
        if rc != 0:
            error = re.sub(r"\s+", " ", (err or out))[:160]
        else:
            try:
                checks = normalise(json.loads(out))
            except ValueError as exc:
                error = "unparseable gh output: %s" % exc

    else:
        source = "pr"
        if args.pr:
            pr_number = str(args.pr)
            rc, out, err = run(
                ["gh", "pr", "view", pr_number, "--json",
                 "number,url,headRefName,statusCheckRollup"], args.repo)
        else:
            head = args.head or branch_from_prd(args.prd)
            if not head:
                die("--head or a --prd path that names prd-<n>-<slug>")
            cmd = ["gh", "pr", "list", "--head", head, "--state", "open",
                   "--json", "number,url,headRefName,statusCheckRollup",
                   "--limit", "1"]
            if args.base:
                cmd[2:2] = ["--base", args.base]
            rc, out, err = run(cmd, args.repo)
        if rc != 0:
            error = re.sub(r"\s+", " ", (err or out))[:160]
        else:
            try:
                data = json.loads(out or "[]")
            except ValueError as exc:
                data, error = None, "unparseable gh output: %s" % exc
            if isinstance(data, list):
                data = data[0] if data else None
            if data is None and not error:
                emit("", "no_pr", source, [], [], [], [], ga, ga_reason,
                     steps_ci, "", "", head,
                     "No open PR for head `%s`%s — pre-merge has not opened "
                     "one, or it already merged."
                     % (head, " into `%s`" % args.base if args.base else ""),
                     "", 7)
            if data:
                pr_number = str(data.get("number", "") or "")
                pr_url = data.get("url", "") or ""
                head = data.get("headRefName", "") or head
                checks = normalise(data.get("statusCheckRollup") or [])

    if error:
        emit("", "gh_error", source, [], [], [], checks, ga, ga_reason,
             steps_ci, pr_number, pr_url, head,
             "CI state could not be read (`gh` error) — this is NOT a green "
             "verdict; resolve the tooling error before merging.", error, 8)

    fail, pend, pas = grade(checks)
    count = len(checks)

    if count == 0:
        if ga is False:
            note = ("GitHub Actions disabled by policy (%s) — change with "
                    "`/msg --update`" % (ga_reason or "no reason recorded"))
            emit("empty-inactive", "policy_disabled", source, fail, pend, pas,
                 checks, ga, ga_reason, steps_ci, pr_number, pr_url, head,
                 note, "", 5)
        if steps_ci == "ready":
            emit("empty-vacuous", "vacuous_ci", source, fail, pend, pas,
                 checks, ga, ga_reason, steps_ci, pr_number, pr_url, head,
                 "`steps.ci` expected a pipeline but the PR reported zero "
                 "checks — likely a broken or missing .github/workflows/ "
                 "pipeline; run `/pre-merge --init`.", "", 6)
        reason = {"opted_out": "step_opted_out",
                  "n/a": "step_na"}.get(steps_ci, "no_ci_record")
        emit("empty-inactive", reason, source, fail, pend, pas, checks, ga,
             ga_reason, steps_ci, pr_number, pr_url, head, "", "", 5)

    if fail:
        emit("red", "failing_checks", source, fail, pend, pas, checks, ga,
             ga_reason, steps_ci, pr_number, pr_url, head,
             "Failing checks: %s" % ", ".join(fail), "", 3)
    if pend:
        emit("pending", "pending_checks", source, fail, pend, pas, checks, ga,
             ga_reason, steps_ci, pr_number, pr_url, head,
             "Pending checks: %s" % ", ".join(pend), "", 4)
    emit("green", "ok", source, fail, pend, pas, checks, ga, ga_reason,
         steps_ci, pr_number, pr_url, head, "", "", 0)


def emit(verdict, reason, source, fail, pend, pas, checks, ga, ga_reason,
         steps_ci, pr_number, pr_url, head, note, error, code):
    print("\n".join([
        "VERDICT=%s" % verdict,
        "REASON=%s" % reason,
        "SOURCE=%s" % source,
        "CHECK_COUNT=%d" % len(checks),
        "FAILING_CHECKS=%s" % ",".join(fail),
        "PENDING_CHECKS=%s" % ",".join(pend),
        "PASSING_CHECKS=%s" % ",".join(pas),
        "GA=%s" % ("true" if ga else "false"),
        "GA_REASON=%s" % re.sub(r"\s+", " ", ga_reason or "").strip(),
        "STEPS_CI=%s" % steps_ci,
        "PR_NUMBER=%s" % pr_number,
        "PR_URL=%s" % pr_url,
        "HEAD_BRANCH=%s" % head,
        "NOTE=%s" % re.sub(r"\s+", " ", note or "").strip(),
        "ERROR=%s" % re.sub(r"\s+", " ", error or "").strip(),
    ]))
    sys.exit(code)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
script-ts-miss.py — test-selection-miss attribution, the CI-BACKSTOP HALF ONLY.

When `policies.test_selection` is on, pre-merge traded full-suite coverage for
speed on the promise that the full suite still runs at a declared backstop.
post-merge is where that promise is checked. The check has two halves, and the
v5 ruling ("mechanise only what always produces fixed results") splits them:

  * The **CI-backstop half is fixed** and lives here — read the committed
    `test_selection` block off the pre-merge universal report, match each
    failing CI check to its owning component, decide whether that component
    ran minified (so the selected set could NOT have caught the break) or ran
    full (an ordinary regression), and count misses across a 30-day window of
    reports already on disk.
  * The **human-outcome half stays with the model** — mapping a "Not yet"
    answer's *named behaviour* to a known test is judgment about English, not
    a lookup. This script does not attempt it, has no flag for it, and the
    call site says so.

Contract:
  .claude/skills/post-merge/refs/staging.md § Test-selection-miss detection
  .claude/skills/pre-merge/refs/output-schema.md § test_selection
  .claude/skills/shared/refs/policy-schema-pre-merge.md §policies.test_selection

Polarity, stated once because it is the easy thing to invert:
  a `fallback_reason` PRESENT means that component ran the FULL suite (the rule
  fell back) ⇒ NOT a miss. ABSENT means it genuinely ran minified ⇒ a failing
  test it did not select IS a miss.

Usage:
  script-ts-miss.py --report <pre-merge report .json>
                    --failing-check <name> [--failing-check <name>]...
                    [--reports-glob <glob>] [--window-days 30]
                    [--now YYYY-MM-DD] [--repo <dir>] [--json]

  --report        the committed universal report carrying the `test_selection`
                  block (the verdict JSON itself is stdout and does not survive
                  the run — the PRD's reports/report-prd-<N>-<K>.json is the
                  durable source).
  --failing-check repeatable — the failing check names straight off
                  `script-ci-status.py`'s FAILING_CHECKS.
  --reports-glob  where the 30-day window looks for prior reports
                  (default: features/**/reports/report-*.json).
  --now           window anchor, for reproducible runs (default: today).

Output (stdout, KEY=VALUE lines, always the full key set):
  REPORT=<path>
  SELECTION_RAN=true|false      false ⇒ the block is absent (a full or
                                selection-off run) — nothing here applies
  MODE=minified|full|
  TIER=S|M|L|
  CHECKS=<n>                    failing checks supplied
  MISS_COUNT=<n>                misses attributable in THIS run
  MISS=<check>|<component>|<selected>/<total>|<exclusion>
  NONMISS=<check>|<component>|<why>
  WINDOW_DAYS=<n>
  WINDOW_MISS_COUNT=<n>         prior `test-selection-miss` findings on disk in
                                the window, PLUS this run's misses
  WINDOW_REPORTS=<n>            reports scanned inside the window
  ESCALATE=true|false           WINDOW_MISS_COUNT >= 2 (the rolling-window rule)
  RECOMMENDATION=<one line>     emitted only when ESCALATE=true
  FORCE_FULL_CANDIDATES=<component,…>   the escapees' components, named as
                                force_full_paths candidates
  HUMAN_HALF=model              a standing marker: the "Not yet" mapping is NOT
                                computed here

`<why>` on a NONMISS is one of: `ran-full-fallback` (a `fallback_reason` is
present) · `ran-full-complete` (`selected == total`) · `no-per-check-entry`
(the check names no selection-capable component — mechanical, security,
migration and every platform component are never selection-capable).

`<exclusion>` is the deterministic read of the block: `tier` when the resolved
tier's own contract excluded the component (the `integration`-at-tier-M cell),
else `not-affected`. The finer per-test reason (`not-tagged` vs `not-affected`)
is not in the block's schema — the model reads it off the finding context.

Exit codes:
  0  no miss attributable (or nothing failing was supplied)
  3  at least one miss — the caller records a `high` `test-selection-miss`
     finding per MISS line, ADDITIVE to the red_ci refusal already in play
  4  SELECTION_RAN=false — the block is absent; nothing to attribute
  2  usage error / unreadable report

Never manufactures a refusal and never turns a green run red: it only explains
a failure that already exists.
"""
import argparse
import datetime
import glob
import json
import os
import re
import sys

SELF = "script-ts-miss"
CAPABLE = ("unit", "integration", "regression")


def die(msg):
    sys.stderr.write("%s: %s\n" % (SELF, msg))
    sys.exit(2)


def load(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.loads(fh.read())
    except (OSError, ValueError) as exc:
        die("cannot read %s: %s" % (path, exc))


def find_block(doc):
    """The block lives at the top level; tolerate a `context` nesting."""
    if not isinstance(doc, dict):
        return None
    for node in (doc, doc.get("context") or {}, doc.get("summary") or {}):
        if isinstance(node, dict) and isinstance(node.get("test_selection"),
                                                 dict):
            return node["test_selection"]
    return None


def component_of(check, per_check):
    """Failing check name → owning selection-capable component.

    Fixed rule: a component id appearing as a word in the check name owns it.
    `unit (42/731)`, `unit-tests`, `CI / integration` all resolve; a check
    naming no capable component resolves to None (not a miss — it is not
    selection-capable at all).
    """
    low = check.lower()
    hits = [c for c in per_check
            if re.search(r"(?<![a-z0-9])%s(?![a-z0-9])" % re.escape(c), low)]
    if hits:
        # Longest id wins, so `integration` beats a stray `unit` substring.
        return sorted(hits, key=len, reverse=True)[0]
    return None


def report_date(path, doc):
    for key in ("generated_at", "generated", "date", "timestamp", "ran_at"):
        v = doc.get(key) if isinstance(doc, dict) else None
        if isinstance(v, str):
            m = re.match(r"(\d{4})-(\d{2})-(\d{2})", v)
            if m:
                return datetime.date(*(int(g) for g in m.groups()))
    ctx = doc.get("context") if isinstance(doc, dict) else None
    if isinstance(ctx, dict):
        for key in ("generated_at", "date", "timestamp"):
            v = ctx.get(key)
            if isinstance(v, str):
                m = re.match(r"(\d{4})-(\d{2})-(\d{2})", v)
                if m:
                    return datetime.date(*(int(g) for g in m.groups()))
    try:
        return datetime.date.fromtimestamp(os.path.getmtime(path))
    except OSError:
        return None


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-ts-miss.py")
    ap.add_argument("--report", required=True)
    ap.add_argument("--failing-check", action="append", default=[],
                    dest="checks")
    ap.add_argument("--reports-glob",
                    default="features/**/reports/report-*.json")
    ap.add_argument("--window-days", type=int, default=30)
    ap.add_argument("--now")
    ap.add_argument("--repo", default=os.getcwd())
    ap.add_argument("--json", action="store_true", dest="as_json")
    args = ap.parse_args()

    doc = load(args.report)
    block = find_block(doc)

    if args.now:
        m = re.match(r"^(\d{4})-(\d{2})-(\d{2})$", args.now)
        if not m:
            die("--now must be YYYY-MM-DD")
        today = datetime.date(*(int(g) for g in m.groups()))
    else:
        today = datetime.date.today()
    cutoff = today - datetime.timedelta(days=args.window_days)

    # ── rolling window: prior misses already recorded on disk ───────────────
    window_misses, window_reports = 0, 0
    pattern = os.path.join(args.repo, args.reports_glob)
    for path in sorted(glob.glob(pattern, recursive=True)):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                other = json.loads(fh.read())
        except (OSError, ValueError):
            continue
        if os.path.abspath(path) == os.path.abspath(args.report):
            continue
        d = report_date(path, other)
        if d is None or d < cutoff:
            continue
        window_reports += 1
        issues = other.get("issues") or other.get("findings") or []
        if isinstance(issues, list):
            window_misses += sum(
                1 for f in issues
                if isinstance(f, dict) and f.get("rule") == "test-selection-miss")

    out = ["REPORT=%s" % args.report]

    if block is None:
        out += ["SELECTION_RAN=false", "MODE=", "TIER=",
                "CHECKS=%d" % len(args.checks), "MISS_COUNT=0",
                "WINDOW_DAYS=%d" % args.window_days,
                "WINDOW_MISS_COUNT=%d" % window_misses,
                "WINDOW_REPORTS=%d" % window_reports,
                "ESCALATE=false", "FORCE_FULL_CANDIDATES=",
                "HUMAN_HALF=model"]
        print("\n".join(out))
        return 4

    per_check = block.get("per_check") or {}
    tier = block.get("tier", "") or ""
    mode = block.get("mode", "") or ""

    misses, nonmisses = [], []
    for check in args.checks:
        comp = component_of(check, per_check)
        if comp is None:
            nonmisses.append((check, "-", "no-per-check-entry"))
            continue
        entry = per_check.get(comp) or {}
        selected = entry.get("selected")
        total = entry.get("total")
        if entry.get("fallback_reason"):
            nonmisses.append((check, comp, "ran-full-fallback"))
            continue
        if selected is not None and total is not None and selected >= total:
            nonmisses.append((check, comp, "ran-full-complete"))
            continue
        exclusion = "tier" if (comp == "integration" and tier == "M") \
            else "not-affected"
        misses.append((check, comp, "%s/%s" % (selected, total), exclusion))

    total_window = window_misses + len(misses)
    escalate = total_window >= 2

    out += [
        "SELECTION_RAN=true",
        "MODE=%s" % mode,
        "TIER=%s" % tier,
        "CHECKS=%d" % len(args.checks),
        "MISS_COUNT=%d" % len(misses),
    ]
    for m in misses:
        out.append("MISS=%s" % "|".join(m))
    for n in nonmisses:
        out.append("NONMISS=%s" % "|".join(n))
    out += [
        "WINDOW_DAYS=%d" % args.window_days,
        "WINDOW_MISS_COUNT=%d" % total_window,
        "WINDOW_REPORTS=%d" % window_reports,
        "ESCALATE=%s" % ("true" if escalate else "false"),
    ]
    if escalate:
        out.append(
            "RECOMMENDATION=%d test-selection misses in the last %d days — run "
            "`/pre-merge --update-criticality` to tag the escapee critical, or "
            "`/msg --update` to disable policies.test_selection outright; add "
            "the escapee's test file to policies.test_selection.force_full_paths"
            % (total_window, args.window_days))
    out.append("FORCE_FULL_CANDIDATES=%s"
               % ",".join(sorted({m[1] for m in misses})))
    out.append("HUMAN_HALF=model")
    print("\n".join(out))

    if args.as_json:
        print(json.dumps({
            "report": args.report, "tier": tier, "mode": mode,
            "misses": [{"check": c, "component": k, "counts": n,
                        "exclusion": e} for c, k, n, e in misses],
            "nonmisses": [{"check": c, "component": k, "why": w}
                          for c, k, w in nonmisses],
            "window": {"days": args.window_days, "misses": total_window,
                       "reports": window_reports, "escalate": escalate},
            "human_half": "model",
        }, indent=2))

    return 3 if misses else 0


if __name__ == "__main__":
    sys.exit(main())

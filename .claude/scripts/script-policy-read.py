#!/usr/bin/env python3
"""
script-policy-read.py — the one READER for `devkit/policy.json`.

Read-side twin of `script-policy-set.py`. Every `?? default` resolution the
post-merge protocol used to spell in prose — `release_flow`, `branch_protection`
(+ per-branch overrides), `github_actions`, `staging_readiness`, `steps.<key>`,
`staging_ready`, `test_selection` — is resolved here, once, in one call. Five
separate prose resolutions per run meant five chances to drop a `??` default;
this script is the single implementation of the read contract.

It reads the SPLIT schema world: the shared core
(`shared/refs/policy-schema.md` §0 `init`, §1 `release_flow`, §2b
`github_actions`) plus post-merge's half
(`shared/refs/policy-schema-post-merge.md` §2 `branch_protection`,
§3 `steps.<key>`, §5 `staging_ready`, `staging_readiness`) and the one
pre-merge key post-merge's test-selection backstop needs
(`shared/refs/policy-schema-pre-merge.md` §`policies.test_selection`).

Schema authority stays those three files; this script implements the read
contract, it does not replace it.

FAIL-SAFE, ALWAYS. A missing, malformed, or wrong-`version` file NEVER aborts:
the full key set is emitted with built-in defaults and `POLICY_STATE` says why.
Exit 0 in every non-usage case, so a caller can never accidentally refuse on a
policy read.

Usage:
  script-policy-read.py [--file <policy.json>] [--branch <name>]... [--json]

  --file    path to devkit/policy.json (default: devkit/policy.json)
  --branch  repeatable — resolve `branch_protection` for this branch and emit
            PROTECTION_MODE_<UPPER>=<mode>. The prod/staging branches resolved
            from release_flow are ALWAYS resolved, with or without this flag.
  --json    additionally dump the resolved map as JSON after the key block

Output (stdout, KEY=VALUE lines, always the full key set):
  POLICY_FILE=<path>
  POLICY_STATE=ok|absent|malformed|bad_version
  INIT=true|false                     §0 — `init ?? false`
  FLOW=staged|direct                  §1
  PROD_BRANCH=<name>                  §1 — `prod_branch ?? "main"`
  STG_BRANCH=<name>                   §1 — `staging_branch ?? "staging"`; empty under direct
  GITHUB_ACTIONS=true|false           §2b — absent ⇒ TRUE (enabled)
  GITHUB_ACTIONS_REASON=<text>
  BRANCH_PROTECTION_MODE=enforced|optional|skip     §2 — absent ⇒ enforced
  BRANCH_PROTECTION_REASON=<text>
  BRANCH_PROTECTION_OVERRIDES=<b=mode,…>
  PROTECTION_MODE_<BRANCH>=<mode>     one per resolved branch (overrides[b] ?? mode)
  STAGING_READINESS_MODE=enforced|optional|skip     absent ⇒ enforced
  STAGING_READINESS_REASON=<text>
  STAGING_READY_RECORD=present|absent §5 — absent ⇒ warn+proceed regardless of mode
  STAGING_READY_UNREADY=<p,…>         platforms carrying gaps[]
  STAGING_READY_RESOLVED_AT=<date>
  STEPS_CI=ready|opted_out|n/a|missing|deferred|absent               §3
  STEPS_CI_CHOSEN=<path|paths>
  STEPS_DEPLOY_STAGING=…  STEPS_DEPLOY_PRODUCTION=…  STEPS_SMOKE=…   §3
  TEST_SELECTION=true|false           §2c — absent ⇒ FALSE (disabled)
  TEST_SELECTION_BACKSTOP=ci|post-merge|both|<empty>
  TEST_SELECTION_FORCE_FULL=<glob,…>
  WARN=<text>                         zero or more, one per validation finding

Validation (shared/refs/policy-schema.md § Validation rules), all non-fatal:
  1. parse failure / version != 1  → whole file treated as absent (POLICY_STATE)
  2. bad enum                      → that field falls to its default + WARN
  3. missing justification         → honored + `unjustified-policy` WARN
  4. unknown steps key             → ignored + WARN
  5. contradictory flow            → release_flow discarded + WARN
  6. `init` missing on a present file → false

Exit codes:
  0  resolved (including absent / malformed — defaults emitted)
  2  usage error

Deterministic: identical file bytes ⇒ byte-identical output.
"""
import argparse
import json
import os
import re
import sys

SELF = "script-policy-read"

PROT_MODES = ("enforced", "optional", "skip")
STEP_STATES = ("ready", "opted_out", "n/a", "missing", "deferred")
STEP_KEYS = ("ci", "deploy_staging", "deploy_production", "smoke")
BACKSTOPS = ("ci", "post-merge", "both")

WARNS = []


def warn(text):
    WARNS.append(text)


def enum_or_default(value, allowed, default, label):
    """Validation rule 2 — a bad enum falls to its default, loudly."""
    if value is None:
        return default
    if value in allowed:
        return value
    warn("bad-enum: %s=%r is not one of %s — using %r"
         % (label, value, "|".join(allowed), default))
    return default


def as_obj(node, key):
    v = node.get(key)
    return v if isinstance(v, dict) else {}


def flat(value):
    """One KEY=VALUE line can hold no newline — flatten defensively."""
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (list, tuple)):
        return ",".join(flat(v) for v in value)
    return re.sub(r"\s+", " ", str(value)).strip()


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-policy-read.py")
    ap.add_argument("--file", default="devkit/policy.json")
    ap.add_argument("--branch", action="append", default=[], dest="branches")
    ap.add_argument("--json", action="store_true", dest="as_json")
    args = ap.parse_args()

    path = args.file
    state = "ok"
    doc = {}

    if not os.path.exists(path):
        state = "absent"
    else:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                doc = json.loads(fh.read())
            if not isinstance(doc, dict):
                raise ValueError("not a JSON object")
        except (ValueError, OSError) as exc:
            warn("unparseable-policy: %s (%s) — built-in defaults in force"
                 % (path, exc))
            state, doc = "malformed", {}
        else:
            if doc.get("version") != 1:
                warn("bad-version: version=%r (want 1) — whole file treated as "
                     "absent" % doc.get("version"))
                state, doc = "bad_version", {}

    pol = as_obj(doc, "policies")

    # ── §0 init ───────────────────────────────────────────────────────────
    init = bool(doc.get("init", False))

    # ── §1 release_flow ───────────────────────────────────────────────────
    rf = as_obj(pol, "release_flow")
    flow = enum_or_default(rf.get("mode"), ("staged", "direct"), "staged",
                           "policies.release_flow.mode")
    prod = rf.get("prod_branch") or "main"
    stg_raw = rf.get("staging_branch", "__absent__")
    # Rule 5 — staged with a null/absent staging_branch is contradictory.
    if flow == "staged" and rf and (stg_raw is None or stg_raw == ""):
        warn("contradictory-flow: release_flow.mode=staged with no "
             "staging_branch — release_flow discarded, defaults in force")
        flow, prod, stg = "staged", "main", "staging"
    elif flow == "direct":
        stg = ""
    else:
        stg = "staging" if stg_raw == "__absent__" else stg_raw

    # ── §2b github_actions ────────────────────────────────────────────────
    ga_obj = as_obj(pol, "github_actions")
    ga = ga_obj.get("enabled", True)
    if not isinstance(ga, bool):
        warn("bad-enum: policies.github_actions.enabled=%r is not a bool — "
             "using true" % ga)
        ga = True
    ga_reason = ga_obj.get("reason", "")
    if ga is False and not ga_reason:
        warn("unjustified-policy: github_actions.enabled=false with no reason "
             "— honored")

    # ── §2 branch_protection ──────────────────────────────────────────────
    bp = as_obj(pol, "branch_protection")
    bp_mode = enum_or_default(bp.get("mode"), PROT_MODES, "enforced",
                              "policies.branch_protection.mode")
    bp_reason = bp.get("reason", "")
    if bp_mode != "enforced" and not bp_reason:
        warn("unjustified-policy: branch_protection.mode=%s with no reason — "
             "honored" % bp_mode)
    overrides = {}
    for b, m in sorted(as_obj(bp, "overrides").items()):
        overrides[b] = enum_or_default(
            m, PROT_MODES, bp_mode,
            "policies.branch_protection.overrides.%s" % b)

    # ── staging_readiness ─────────────────────────────────────────────────
    sr = as_obj(pol, "staging_readiness")
    sr_mode = enum_or_default(sr.get("mode"), PROT_MODES, "enforced",
                              "policies.staging_readiness.mode")
    sr_reason = sr.get("reason", "")
    if sr_mode != "enforced" and not sr_reason:
        warn("unjustified-policy: staging_readiness.mode=%s with no reason — "
             "honored" % sr_mode)

    # ── §5 staging_ready (a resolved fact, not policy) ────────────────────
    ready = doc.get("staging_ready")
    if isinstance(ready, dict):
        ready_state = "present"
        ready_at = ready.get("resolved_at", "")
        unready = [p for p, v in sorted(as_obj(ready, "platforms").items())
                   if isinstance(v, dict)
                   and (v.get("gaps") or v.get("ready") is False)]
    else:
        ready_state, ready_at, unready = "absent", "", []

    # ── §3 steps.<key> ────────────────────────────────────────────────────
    steps = as_obj(doc, "steps")
    for k in steps:
        if k not in STEP_KEYS:
            warn("unknown-key: steps.%s ignored (live keys: %s)"
                 % (k, ", ".join(STEP_KEYS)))
    resolved_steps = {}
    for k in STEP_KEYS:
        entry = steps.get(k)
        if not isinstance(entry, dict):
            resolved_steps[k] = ("absent", "")
            continue
        st = entry.get("status")
        if st is None:
            st = "absent"
        elif st not in STEP_STATES:
            warn("bad-enum: steps.%s.status=%r — using 'absent' (built-in "
                 "fall-back)" % (k, st))
            st = "absent"
        if st in ("opted_out", "n/a", "deferred") and not entry.get("reason"):
            warn("unjustified-policy: steps.%s.status=%s with no reason — "
                 "honored" % (k, st))
        resolved_steps[k] = (st, flat(entry.get("chosen", "")))

    # ── §2c test_selection (pre-merge's key; post-merge reads it for the
    #     backstop-attribution guard only) ─────────────────────────────────
    ts = as_obj(pol, "test_selection")
    ts_on = ts.get("enabled", False)
    if not isinstance(ts_on, bool):
        warn("bad-enum: policies.test_selection.enabled=%r is not a bool — "
             "using false" % ts_on)
        ts_on = False
    ts_backstop = ""
    if ts_on:
        ts_backstop = enum_or_default(ts.get("full_run_backstop"), BACKSTOPS,
                                      "", "policies.test_selection."
                                          "full_run_backstop")
        if not ts_backstop:
            warn("unjustified-policy: test_selection.enabled=true with no "
                 "full_run_backstop — the backstop promise is unverifiable")
        if not ts.get("reason"):
            warn("unjustified-policy: test_selection.enabled=true with no "
                 "reason — honored")

    # ── emit ──────────────────────────────────────────────────────────────
    branches = []
    for b in [prod] + ([stg] if stg else []) + list(args.branches):
        if b and b not in branches:
            branches.append(b)

    out = [
        "POLICY_FILE=%s" % path,
        "POLICY_STATE=%s" % state,
        "INIT=%s" % flat(init),
        "FLOW=%s" % flow,
        "PROD_BRANCH=%s" % prod,
        "STG_BRANCH=%s" % stg,
        "GITHUB_ACTIONS=%s" % flat(ga),
        "GITHUB_ACTIONS_REASON=%s" % flat(ga_reason),
        "BRANCH_PROTECTION_MODE=%s" % bp_mode,
        "BRANCH_PROTECTION_REASON=%s" % flat(bp_reason),
        "BRANCH_PROTECTION_OVERRIDES=%s"
        % ",".join("%s=%s" % (b, m) for b, m in overrides.items()),
    ]
    for b in branches:
        key = re.sub(r"[^A-Za-z0-9]+", "_", b).upper()
        out.append("PROTECTION_MODE_%s=%s" % (key, overrides.get(b, bp_mode)))
    out += [
        "STAGING_READINESS_MODE=%s" % sr_mode,
        "STAGING_READINESS_REASON=%s" % flat(sr_reason),
        "STAGING_READY_RECORD=%s" % ready_state,
        "STAGING_READY_UNREADY=%s" % ",".join(unready),
        "STAGING_READY_RESOLVED_AT=%s" % flat(ready_at),
        "STEPS_CI=%s" % resolved_steps["ci"][0],
        "STEPS_CI_CHOSEN=%s" % resolved_steps["ci"][1],
        "STEPS_DEPLOY_STAGING=%s" % resolved_steps["deploy_staging"][0],
        "STEPS_DEPLOY_PRODUCTION=%s" % resolved_steps["deploy_production"][0],
        "STEPS_SMOKE=%s" % resolved_steps["smoke"][0],
        "TEST_SELECTION=%s" % flat(ts_on),
        "TEST_SELECTION_BACKSTOP=%s" % ts_backstop,
        "TEST_SELECTION_FORCE_FULL=%s" % flat(ts.get("force_full_paths", [])),
    ]
    out += ["WARN=%s" % flat(w) for w in WARNS]
    print("\n".join(out))

    if args.as_json:
        print(json.dumps({
            "policy_file": path, "policy_state": state, "init": init,
            "flow": flow, "prod_branch": prod, "staging_branch": stg,
            "github_actions": ga, "branch_protection": {
                "mode": bp_mode, "overrides": overrides,
                "resolved": {b: overrides.get(b, bp_mode) for b in branches}},
            "staging_readiness": sr_mode,
            "staging_ready": {"record": ready_state, "unready": unready},
            "steps": {k: v[0] for k, v in resolved_steps.items()},
            "test_selection": {"enabled": ts_on, "backstop": ts_backstop},
            "warnings": WARNS,
        }, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())

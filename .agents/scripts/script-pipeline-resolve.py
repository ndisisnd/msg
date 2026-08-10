#!/usr/bin/env python3
"""
script-pipeline-resolve.py — resolve the pre-merge run's pipeline plan.

Pruning, the C12 coverage-gap correlation, and the Kahn topo-sort into waves are
100% decidable from `devkit/policy.json` + `component-catalog.md` + the run's
flags + the diff surface. They used to be executed by the model from ~200 lines
of prose on every run, which is fail-silent: a wrong wave order or a dropped
component is invisible in the output. This script prints the plan instead, and
the executor quotes it verbatim.

The catalog is the source of every component **constant** (`nn`, `group`, `kind`,
`cost`, `depends_on`, `active_when`, `platforms`, `mandatory`, default
`criticality`, `needs_env`); `policy.json`'s `components[]` carries only the
per-project deltas (`present`, `run`, `run_minified`, `tooling`, `status`, plus
explicit user overrides). This script performs that join — it never reads a
catalog constant out of the manifest.

Two modes:

  resolve   (default) — print the plan JSON
  --check-complete    — compare a plan against a finished run dir and report
                        every component that ran without writing a result report

Usage:
  script-pipeline-resolve.py --policy <policy.json> --catalog <component-catalog.md>
                             [--platforms-file <PLATFORMS.md> | --platforms web,ios]
                             [--diff <resolve-diff.json>] [--prd <path>]
                             [--changed-only] [--flaky N]

  script-pipeline-resolve.py --check-complete --plan <plan.json> --run-dir <dir>

  --policy          devkit/policy.json (required in resolve mode)
  --catalog         shared/refs/component-catalog.md (required in resolve mode)
  --platforms-file  devkit/PLATFORMS.md — target platforms for the C12 check
  --platforms       comma list, overrides --platforms-file
  --diff            script-resolve-diff.sh output; absent ⇒ surface gates fail OPEN
  --prd             enables the prd-group components
  --changed-only    prune platform components whose surface the diff misses
  --flaky           retry count; recorded, never changes membership

Output (resolve, stdout): one JSON object

  { "waves": [ { "wave": 1, "components": [ { … } ] } ],
    "run": [ "<id>", … ],              the flat expected-report list
    "pruned": [ { "id", "reason" } ],
    "gap_findings": [ <canonical finding> ],
    "flags": { … },
    "counts": { "catalog", "manifest", "run", "pruned" } }

Output (--check-complete, stdout):

  MISSING=<id>            one line per component with no result report
  EXTRA=<id>              one line per report with no planned component
  STATUS=complete|incomplete
  PLANNED=<n>  REPORTED=<n>

Exit codes:
  0  resolved (or --check-complete found everything)
  1  usage error
  2  policy.json absent / unparseable / no components[]  (the no_manifest case)
  3  catalog unparseable, or the manifest names an id with no catalog row
  4  dependency cycle — refuse rather than loop (AC-PF3)
  5  --check-complete found a missing report
  6  a MANDATORY component is absent from the manifest (A20) — one
     `MANDATORY_ABSENT=<id>` line per component on stdout, then refuse. A
     mandatory component that was never written into `components[]` used to
     resolve as a `pruned[]` row and the run proceeded without it; the safety
     floor is not a prunable step, so this is a refusal — run /pre-merge --init.
  7  --platforms-file exists but could not be read (A19). An ABSENT file keeps
     its old behaviour (no targets, no coverage-gap findings); an unreadable
     one is a tooling failure, not "this repo ships nothing".

Deterministic: same policy + catalog + flags + diff ⇒ byte-identical plan.
"""
import argparse
import json
import os
import re
import sys

SELF = "script-pipeline-resolve"

# Applicability legend (component-catalog.md § Legend) → concrete platforms.
APPLICABILITY = {
    "all": {"web", "ios", "macos", "android", "backend"},
    "ui": {"web", "ios", "macos", "android"},
    "web": {"web"},
    "srv": {"backend", "web"},
    "mob": {"ios", "android"},
    "db": {"backend", "web", "ios", "android"},
}

# Diff-surface map — the same globs as pre-merge/refs/_common.md § --changed-only.
SURFACE_PATTERNS = {
    "ui-surface": [
        r"\.(tsx|jsx|vue|svelte|css|scss)$", r"/components?/", r"/pages?/",
        r"/views?/", r"/screens?/", r"^lib/.*\.dart$",
    ],
    "api-surface": [
        r"/routes?/", r"/controllers?/", r"/handlers?/", r"/api/", r"/server/",
        r"/services?/", r"\.proto$", r"openapi", r"swagger",
    ],
    "migrations": [r"/migrations?/", r"/migrate/", r"\.sql$"],
    "mobile-surface": [
        r"^ios/", r"^android/", r"\.swift$", r"\.kt$", r"\.dart$",
        r"\.xcodeproj", r"\.xcworkspace",
    ],
}

# Fields the manifest is allowed to carry. Anything else is catalog metadata a
# stale manifest copied; it is ignored with a warn rather than honored.
MANIFEST_FIELDS = {
    "id", "present", "run", "run_minified", "tooling", "status",
    "criticality", "needs_env", "reason",
    "hot_tables", "consumers", "traffic_mix", "matrix",
}

TAIL = "__tail__"


def fail(code, slug, detail):
    sys.stderr.write("%s: ERROR=%s detail=%s\n" % (SELF, slug, detail))
    sys.exit(code)


def warn(slug, detail):
    sys.stderr.write("%s: WARN=%s detail=%s\n" % (SELF, slug, detail))


def deaccent(cell):
    """Strip markdown emphasis, links and the catalog's footnote superscripts."""
    cell = cell.replace("**", "").replace("~~", "").replace("`", "")
    cell = re.sub(r"\([^)]*\)", "", cell)          # "(only-on-green, late wave)"
    cell = "".join(ch for ch in cell if ord(ch) < 128)
    return cell.strip()


def split_row(line):
    parts = line.strip().strip("|").split("|")
    return [p.strip() for p in parts]


def parse_catalog(path):
    """Parse the catalog's component table into {id: constants}.

    The table is the one whose header row starts with `nn | id | group`.
    """
    try:
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        fail(3, "catalog-unreadable", "%s: %s" % (path, exc))

    header_at = None
    for i, line in enumerate(lines):
        if not line.startswith("|"):
            continue
        cells = [deaccent(c).lower() for c in split_row(line)]
        if cells[:3] == ["nn", "id", "group"]:
            header_at = i
            break
    if header_at is None:
        fail(3, "catalog-no-table", "no `nn | id | group` header row in %s" % path)

    cols = [deaccent(c).lower() for c in split_row(lines[header_at])]
    idx = {name: n for n, name in enumerate(cols)}
    for needed in ("nn", "id", "group", "kind", "criticality", "cost",
                   "depends_on", "active_when", "platforms", "env", "mandatory"):
        if needed not in idx:
            fail(3, "catalog-column-missing", "%s column absent" % needed)

    catalog = {}
    for line in lines[header_at + 2:]:
        if not line.startswith("|"):
            break
        raw = split_row(line)
        if len(raw) < len(cols):
            continue
        cid = deaccent(raw[idx["id"]])
        if not cid or cid == "-":
            continue
        env_raw = raw[idx["env"]]
        dep_cell = raw[idx["depends_on"]].lower()
        only_on_green = "only-on-green" in dep_cell
        dep_raw = deaccent(raw[idx["depends_on"]]).lower()
        if "tail" in dep_raw:
            depends_on = TAIL
        elif dep_raw in ("", "-", "sync"):
            depends_on = []
        else:
            depends_on = [d.strip() for d in dep_raw.split(",") if d.strip()
                          and d.strip() != "sync"]

        catalog[cid] = {
            "id": cid,
            "nn": deaccent(raw[idx["nn"]]),
            "group": deaccent(raw[idx["group"]]),
            "kind": deaccent(raw[idx["kind"]]),
            "criticality": deaccent(raw[idx["criticality"]]) or "advisory",
            "cost": deaccent(raw[idx["cost"]]) or "moderate",
            "depends_on": depends_on,
            "active_when": normalise_active_when(raw[idx["active_when"]]),
            "platforms": deaccent(raw[idx["platforms"]]).lower() or "all",
            "needs_env": "✔" in env_raw,
            "needs_env_conditional": "cond" in deaccent(env_raw).lower(),
            "mandatory": "✔" in raw[idx["mandatory"]],
            # Only-on-green tier (catalog § Only-on-green tier): never scheduled
            # before every correctness component has completed.
            "only_on_green": only_on_green,
        }
    if not catalog:
        fail(3, "catalog-empty", "no component rows parsed from %s" % path)
    return catalog


def normalise_active_when(cell):
    text = deaccent(cell).lower()
    if not text or text == "always":
        return "always"
    for token in ("ui-surface", "api-surface",
                  "mobile-surface", "perf-config", "migrations"):
        if token in text:
            return token
    if "or" in text and "surface" in text:
        return "union"          # smoke: UI or api/migration/deploy surface
    if text == "prd":
        return "prd"
    return text


def surfaces_in_diff(files):
    hit = set()
    for path in files:
        low = path.lower()
        for surface, patterns in SURFACE_PATTERNS.items():
            if any(re.search(p, low) for p in patterns):
                hit.add(surface)
    return hit


KNOWN_PLATFORMS = {"web", "ios", "macos", "android", "backend", "server"}


def read_platforms_file(path):
    """Target platforms = the first column of PLATFORMS.md's pipe table.

    A19 — two silences closed:

    * An **unreadable but existing** file used to return `[]`, which reads as
      "this repo targets nothing" and skips the whole C12 coverage-gap check.
      That is a tooling failure, so it is now a hard refusal (exit 7). A file
      that is simply ABSENT still returns `[]` — that is the documented
      "no PLATFORMS.md yet" case, not a failure.
    * The known-platform set is hardcoded while template-PLATFORMS.md invites
      custom rows ("add your own row for anything else"). An unrecognised name
      is still not scheduled — the APPLICABILITY map has no entry for it — but
      it is now named on stderr instead of being dropped in silence.

    The unknown-platform warn fires only for rows of a table whose header's
    first cell is `platform`, so divider rows, the header itself, `[USER: …]`
    placeholders, `—`/blank cells and the *other* tables a doc may carry (the
    template's Column-contract and tolerance-profile tables) never warn.
    """
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        fail(7, "platforms-unreadable",
             "%s exists but cannot be read (%s) — refusing to resolve a plan "
             "whose platform coverage-gap check silently saw no targets" %
             (path, exc))
    found = []
    in_platform_table = False
    for n, line in enumerate(lines, start=1):
        if not line.startswith("|"):
            in_platform_table = False          # a markdown table ends here
            continue
        first = deaccent(split_row(line)[0]).lower().strip("`").strip()
        if first == "platform":                # the header row of THE table
            in_platform_table = True
            continue
        if first in KNOWN_PLATFORMS:
            if first not in found:
                found.append("backend" if first == "server" else first)
            continue
        if not in_platform_table:
            continue
        if not first or first.startswith("[user") or \
                re.fullmatch(r":?-{1,}:?", first):
            continue                           # divider / placeholder / `—`
        warn("unknown-platform",
             "%s line %d: `%s` is not one of %s — no component's applicability "
             "covers it, so none of its checks are scheduled and it raises no "
             "coverage gap" %
             (path, n, first, ",".join(sorted(KNOWN_PLATFORMS))))
    return found


def kahn(nodes, edges):
    """Kahn levels. `edges[n]` = the set n depends on. Returns {id: level>=1}."""
    level = {}
    remaining = dict((n, set(e) & set(nodes)) for n, e in edges.items())
    current = 1
    while remaining:
        ready = [n for n, deps in remaining.items()
                 if not (deps - set(level.keys()))]
        if not ready:
            fail(4, "dependency-cycle",
                 "unresolvable: %s" % ",".join(sorted(remaining)))
        for n in ready:
            level[n] = current
            del remaining[n]
        current += 1
    return level


TIER_RANK = {"critical": 0, "blocking": 1, "advisory": 2, "config-driven": 3}
COST_RANK = {"cheap": 0, "moderate": 1, "expensive": 2}


def resolve(args):
    # ── manifest ──────────────────────────────────────────────────────────
    if not os.path.exists(args.policy):
        fail(2, "no_manifest", "%s absent — run /pre-merge --init" % args.policy)
    try:
        with open(args.policy, "r", encoding="utf-8") as fh:
            policy = json.load(fh)
    except ValueError as exc:
        fail(2, "no_manifest", "%s unparseable: %s" % (args.policy, exc))
    if not isinstance(policy, dict) or policy.get("version") != 1:
        fail(2, "no_manifest", "%s: version != 1" % args.policy)
    entries = policy.get("components")
    if not isinstance(entries, list) or not entries:
        fail(2, "no_manifest",
             "%s has no components[] — run /pre-merge --init" % args.policy)

    catalog = parse_catalog(args.catalog)

    manifest = {}
    for entry in entries:
        if not isinstance(entry, dict) or not entry.get("id"):
            warn("bad-entry", "components[] entry without an id — ignored")
            continue
        cid = entry["id"]
        if cid not in catalog:
            warn("unknown-component", "%s has no catalog row — ignored" % cid)
            continue
        stale = set(entry) - MANIFEST_FIELDS
        if stale:
            warn("catalog-metadata-in-manifest",
                 "%s carries %s — resolved from the catalog, manifest copy ignored"
                 % (cid, ",".join(sorted(stale))))
        manifest[cid] = entry

    # ── diff surfaces (fail open when unresolved) ─────────────────────────
    diff_files, diff_ok = [], False
    if args.diff:
        try:
            with open(args.diff, "r", encoding="utf-8") as fh:
                d = json.load(fh)
            if not d.get("error"):
                diff_files = d.get("files_changed") or []
                diff_ok = True
        except (OSError, ValueError):
            diff_ok = False
    surfaces = surfaces_in_diff(diff_files) if diff_ok else set()

    # ── prune ─────────────────────────────────────────────────────────────
    run, pruned = [], []
    mandatory_absent = []

    def drop(cid, reason):
        pruned.append({"id": cid, "reason": reason})

    for cid, meta in catalog.items():
        entry = manifest.get(cid)
        # 1 · presence
        if entry is None:
            # A20: a MANDATORY component missing from the manifest used to be
            # just a `pruned[]` row — the plan still resolved and the run went
            # green without a safety-floor step that is not prunable by
            # contract. Collect them all (so one refusal names every gap) and
            # refuse below.
            if meta["mandatory"]:
                mandatory_absent.append(cid)
            continue
        if not entry.get("present") and not meta["mandatory"]:
            continue                              # absent ⇒ no step, no note
        status = entry.get("status")
        if status in ("opted_out", "n/a") and not meta["mandatory"]:
            drop(cid, "status: %s" % status)
            continue
        # 2 · active_when
        aw = meta["active_when"]
        if aw == "prd" and not args.prd:
            drop(cid, "active_when: prd (no --prd)")
            continue
        if aw in SURFACE_PATTERNS and diff_ok and aw not in surfaces:
            drop(cid, "active_when: %s not in the diff" % aw)
            continue
        elif aw == "union" and diff_ok and not (
                surfaces & {"ui-surface", "api-surface", "migrations"}):
            drop(cid, "active_when: no UI/api/migration surface in the diff")
            continue
        # 3 · flag pruning
        if args.changed_only and meta["group"] == "platform" and diff_ok:
            gate = {"e2e": "ui-surface", "a11y": "ui-surface",
                    "perf": "ui-surface", "mobile": "mobile-surface",
                    "api": "api-surface", "load": "api-surface"}.get(cid)
            if gate and gate not in surfaces:
                drop(cid, "--changed-only: %s untouched" % gate)
                continue
        run.append(cid)

    if mandatory_absent:
        for cid in sorted(mandatory_absent):
            print("MANDATORY_ABSENT=%s" % cid)
        fail(6, "mandatory-absent",
             "%s mandatory in the catalog but absent from %s's components[] — "
             "the safety floor is not a prunable step; run /pre-merge --init "
             "(or --update) to write the missing row(s)" %
             (",".join(sorted(mandatory_absent)), args.policy))

    # ── C12 coverage-gap correlation ──────────────────────────────────────
    targets = ([p.strip().lower() for p in args.platforms.split(",") if p.strip()]
               if args.platforms
               else read_platforms_file(args.platforms_file)
               if args.platforms_file else [])
    gaps = []
    for target in targets:
        for cid, meta in sorted(catalog.items()):
            applies = APPLICABILITY.get(meta["platforms"], set())
            if target not in applies:
                continue
            entry = manifest.get(cid)
            detected = entry is not None and entry.get("status") != "no_tooling"
            if detected:
                continue
            if entry is not None and entry.get("status") in ("opted_out", "n/a"):
                continue                    # a decision, not a gap
            gaps.append({
                "severity": "high",
                "category": cid,
                "rule": "platform-coverage-gap",
                "source": "pre-merge:executor",
                "file": None, "line": None,
                "message": ("`%s` is a target but `%s` has no coverage — add a "
                            "`%s` runner for `%s`, or drop `%s` from the repo's "
                            "targets." % (target, cid, target, cid, target)),
            })

    # ── order (Kahn levels + the C23 env floor) ───────────────────────────
    runset = set(run)
    edges = {}
    for cid in run:
        dep = catalog[cid]["depends_on"]
        edges[cid] = (runset - {cid}) if dep is TAIL else set(dep) & runset

    # Only-on-green components wait for every correctness component (catalog
    # § Only-on-green tier) — an execution policy layered over depends_on.
    green_tier = {c for c in run if catalog[c]["only_on_green"]}
    # Everything downstream of the tier — and the tail-pinned components — is
    # outside "correctness" too, or the added edges would close a cycle.
    excluded = set(green_tier) | {c for c in run
                                  if catalog[c]["depends_on"] is TAIL}
    grew = True
    while grew:
        grew = False
        for cid in run:
            if cid in excluded:
                continue
            if edges[cid] & excluded:
                excluded.add(cid)
                grew = True
    correctness = runset - excluded
    for cid in green_tier:
        edges[cid] = edges[cid] | correctness

    base_level = kahn(run, edges)
    # C23 env floor: the sandbox is provisioned only after the static wave-1
    # correctness components are green, so no env component precedes them.
    static_wave1 = {c for c in run
                    if base_level[c] == 1 and not needs_env(catalog, manifest, c)}
    for cid in run:
        if needs_env(catalog, manifest, cid):
            edges[cid] = edges[cid] | (static_wave1 - {cid})
    level = kahn(run, edges)

    waves = {}
    for cid in run:
        waves.setdefault(level[cid], []).append(cid)

    def sort_key(cid):
        crit = criticality(catalog, manifest, cid)
        return (TIER_RANK.get(crit, 9),
                COST_RANK.get(catalog[cid]["cost"], 9), cid)

    wave_list = []
    for n in sorted(waves):
        members = sorted(waves[n], key=sort_key)
        wave_list.append({
            "wave": n,
            "env_wave": any(needs_env(catalog, manifest, c) for c in members),
            "components": [component_view(catalog, manifest, c) for c in members],
        })

    ordered_run = [c for w in wave_list for c in
                   [x["id"] for x in w["components"]]]

    return {
        "waves": wave_list,
        "run": ordered_run,
        "pruned": sorted(pruned, key=lambda p: p["id"]),
        "gap_findings": gaps,
        "flags": {
            "prd": args.prd, "changed_only": args.changed_only,
            "flaky": args.flaky, "diff_resolved": diff_ok,
            "surfaces": sorted(surfaces),
        },
        "counts": {
            "catalog": len(catalog), "manifest": len(manifest),
            "run": len(ordered_run), "pruned": len(pruned),
        },
    }


def needs_env(catalog, manifest, cid):
    entry = manifest.get(cid) or {}
    if "needs_env" in entry:
        return bool(entry["needs_env"])
    return catalog[cid]["needs_env"]


def criticality(catalog, manifest, cid):
    entry = manifest.get(cid) or {}
    return entry.get("criticality") or catalog[cid]["criticality"]


def component_view(catalog, manifest, cid):
    meta = catalog[cid]
    entry = manifest.get(cid) or {}
    return {
        "id": cid,
        "nn": meta["nn"],
        "group": meta["group"],
        "kind": meta["kind"],
        "cost": meta["cost"],
        "mandatory": meta["mandatory"],
        "criticality": criticality(catalog, manifest, cid),
        "needs_env": needs_env(catalog, manifest, cid),
        "run": entry.get("run"),
        "run_minified": entry.get("run_minified"),
        "status": entry.get("status"),
        "ref": "%s/protocol-%s.md" % (meta["group"], cid),
    }


def check_complete(args):
    try:
        with open(args.plan, "r", encoding="utf-8") as fh:
            plan = json.load(fh)
    except (OSError, ValueError) as exc:
        fail(1, "bad-plan", "%s: %s" % (args.plan, exc))
    planned = list(plan.get("run") or [])
    if not os.path.isdir(args.run_dir):
        fail(1, "bad-run-dir", "%s is not a directory" % args.run_dir)
    reported = sorted(f[:-5] for f in os.listdir(args.run_dir)
                      if f.endswith(".json"))

    missing = [c for c in planned if c not in reported]
    extra = [r for r in reported if r not in planned]
    for c in missing:
        print("MISSING=%s" % c)
    for r in extra:
        print("EXTRA=%s" % r)
    print("PLANNED=%d" % len(planned))
    print("REPORTED=%d" % len([r for r in reported if r in planned]))
    print("STATUS=%s" % ("incomplete" if missing else "complete"))
    return 5 if missing else 0


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-pipeline-resolve.py")
    ap.add_argument("--policy")
    ap.add_argument("--catalog")
    ap.add_argument("--platforms-file")
    ap.add_argument("--platforms")
    ap.add_argument("--diff")
    ap.add_argument("--prd")
    ap.add_argument("--changed-only", action="store_true")
    ap.add_argument("--flaky", type=int, default=0)
    ap.add_argument("--check-complete", action="store_true")
    ap.add_argument("--plan")
    ap.add_argument("--run-dir")
    args = ap.parse_args()

    if args.check_complete:
        if not (args.plan and args.run_dir):
            fail(1, "bad-usage", "--check-complete needs --plan and --run-dir")
        return check_complete(args)

    if not (args.policy and args.catalog):
        fail(1, "bad-usage", "--policy and --catalog are required")
    print(json.dumps(resolve(args), indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

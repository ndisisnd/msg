#!/usr/bin/env python3
"""
script-platforms-parse.py — the ONE parser for `devkit/PLATFORMS.md`.

Three merge refs described the identical table parse in prose —
`refs/deploy.md` (deploy commands + `release_model` inference),
`refs/verify-deploy.md` (the v2 smoke declaration) and the two protocols'
rollback/provenance reads. A model parsing a 17-column pipe table three times
per run is a known drift source: a shifted column silently deploys the wrong
command. This script parses it once and emits `key=value`.

Columns are matched **by header name**, never by position, so adding or
reordering a column cannot mis-map a cell.

Cell markers (template-PLATFORMS.md § Column contract) — a cell that is blank,
`—`, or a `[USER: …]` placeholder all mean **not configured**. They are
normalised to the empty string here, and the caller's "ask or skip with a note"
rule is the same for all three. Merge never invents a command.

`release_model` — declared wins, inference is the fallback and is ALWAYS warned
(AC-RM1). **macOS is never inferred from identity**: a directly-downloaded,
Sparkle-updated `.app` is `deploy` and a Mac App Store build is `submission`,
and the row is the only thing that knows which. A macOS row therefore DECLARES
its model; when one omits it, this script still falls back to `deploy` (so the
run proceeds) and raises the macOS-specific warn naming the declaration as the
fix.

Contract:
  .claude/skills/merge/refs/deploy.md         § Resolve
  .claude/skills/merge/refs/verify-deploy.md  § Resolve
  .claude/skills/shared/refs/policy-schema-merge.md §4 release_model
  .claude/skills/msg/refs/init/templates/template-PLATFORMS.md § Column contract

Usage:
  script-platforms-parse.py [--file <PLATFORMS.md>] [--platform <p>]... [--json]

  --file      default: devkit/PLATFORMS.md
  --platform  repeatable — emit only these rows (unknown name → loud error)
  --json      additionally dump the resolved map as JSON after the key block

Output (stdout, KEY=VALUE lines):
  PLATFORMS_FILE=<path>
  PLATFORM_COUNT=<n>
  PLATFORMS=<p,…>                      table order, preserved
  <p>.release_model=deploy|submission
  <p>.release_model_source=declared|inferred
  <p>.rollback_possible=yes|limited|no
  <p>.rollback_lever_key=rollback_cmd|rollout_halt_cmd
  <p>.rollback_lever=<cmd>             the lever for THIS platform's model ("" ⇒ gap)
  <p>.tolerance=strict|standard|lenient
  <p>.staging_deploy_cmd=<cmd>
  <p>.production_deploy_cmd=<cmd>
  <p>.staging_config=<path>
  <p>.smoke_cmd=<cmd>
  <p>.smoke_watch_window=<d/i>
  <p>.smoke_poll=<t/i>
  <p>.smoke_mode=one_shot|poll|watch|poll+watch|none
  <p>.notarize_status_cmd=<cmd>        macOS `deploy` only; "" elsewhere
  <p>.signing_smoke_cmd=<cmd>
  <p>.appcast_url=<url>
  <p>.version_probe=<cmd>
  <p>.required_buckets=<b,…>
  WARN=<text>                          zero or more
  ERROR=<text>                         only on a malformed table (exit 3)

`smoke_mode` is derived, not authored: no `smoke_cmd` ⇒ `none` (verification is
skipped with a note); `cmd` alone ⇒ `one_shot`; `+poll` ⇒ `poll`;
`+watch_window` ⇒ `watch`; both ⇒ `poll+watch`. It is the exact value
`script-smoke-run.sh` runs and the run report records.

Exit codes:
  0  parsed
  3  malformed table — a row whose cell count does not match the header, a
     table with no `platform` column, or a duplicate platform row. LOUD: the
     ERROR line names the row and nothing else is emitted. A silently
     mis-parsed deploy command is worse than a stopped run.
  4  file absent — PLATFORM_COUNT=0 + one WARN. NOT an error: the caller warns
     ("No devkit/PLATFORMS.md — run /msg --init") and treats every command as
     empty; the merge/sign-off flow still has value (refs/deploy.md step 2).
  2  usage error / unknown --platform

Deterministic: identical file bytes ⇒ byte-identical output.
"""
import argparse
import json
import os
import re
import sys

SELF = "script-platforms-parse"

PLACEHOLDER = re.compile(r"^\[USER:.*\]$", re.S)

# header name → emitted key. Header matching is case-insensitive and
# whitespace/backtick-insensitive.
COLUMNS = {
    "platform": "platform",
    "rollback_possible": "rollback_possible",
    "release_model": "release_model",
    "tolerance": "tolerance",
    "staging_deploy_cmd": "staging_deploy_cmd",
    "staging_config": "staging_config",
    "production_deploy_cmd": "production_deploy_cmd",
    "smoke_cmd": "smoke_cmd",
    "smoke_watch_window": "smoke_watch_window",
    "smoke_poll": "smoke_poll",
    "notarize_status_cmd": "notarize_status_cmd",
    "signing_smoke_cmd": "signing_smoke_cmd",
    "appcast_url": "appcast_url",
    "rollback_cmd": "rollback_cmd",
    "rollout_halt_cmd": "rollout_halt_cmd",
    "version_probe": "version_probe",
    "required_buckets": "required_buckets",
}

EMIT_ORDER = ["release_model", "release_model_source", "rollback_possible",
              "rollback_lever_key", "rollback_lever", "tolerance",
              "staging_deploy_cmd", "production_deploy_cmd", "staging_config",
              "smoke_cmd", "smoke_watch_window", "smoke_poll", "smoke_mode",
              "notarize_status_cmd", "signing_smoke_cmd", "appcast_url",
              "version_probe", "required_buckets"]

WARNS = []


def die(msg):
    sys.stderr.write("%s: %s\n" % (SELF, msg))
    sys.exit(2)


def bail(msg):
    """Malformed table — loud, and nothing half-parsed is emitted."""
    print("ERROR=%s" % re.sub(r"\s+", " ", msg).strip())
    sys.stderr.write("%s: %s\n" % (SELF, msg))
    sys.exit(3)


def split_row(line):
    """Split a markdown pipe row, honouring `\\|` escaped inside a cell."""
    body = line.strip()
    body = body[1:] if body.startswith("|") else body
    body = body[:-1] if body.endswith("|") else body
    cells, cur, i = [], "", 0
    while i < len(body):
        ch = body[i]
        if ch == "\\" and i + 1 < len(body) and body[i + 1] == "|":
            cur += "|"
            i += 2
            continue
        if ch == "|":
            cells.append(cur.strip())
            cur = ""
            i += 1
            continue
        cur += ch
        i += 1
    cells.append(cur.strip())
    return cells


def norm_header(cell):
    return re.sub(r"[^a-z0-9_]+", "", cell.strip().strip("`").lower())


def is_divider(cells):
    return bool(cells) and all(re.fullmatch(r":?-{1,}:?", c or "")
                               for c in cells if c != "")


def clean(cell):
    """Blank · `—` · `[USER: …]` all mean not configured."""
    v = (cell or "").strip()
    if v in ("", "-", "—", "–", "n/a", "N/A"):
        return ""
    if PLACEHOLDER.match(v):
        return ""
    return v


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-platforms-parse.py")
    ap.add_argument("--file", default="devkit/PLATFORMS.md")
    ap.add_argument("--platform", action="append", default=[], dest="want")
    ap.add_argument("--json", action="store_true", dest="as_json")
    args = ap.parse_args()

    path = args.file
    if not os.path.exists(path):
        print("PLATFORMS_FILE=%s" % path)
        print("PLATFORM_COUNT=0")
        print("PLATFORMS=")
        print("WARN=No %s — run `/msg --init`; every deploy/smoke command is "
              "treated as not configured" % path)
        return 4

    try:
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        die("cannot read %s: %s" % (path, exc))

    # Find the LAST header row naming a `platform` column and take the rows
    # under it. A template file carries per-platform example blocks after the
    # active table; each of those rows is a data row of the same table.
    header = None
    header_at = -1
    for n, line in enumerate(lines):
        if "|" not in line:
            continue
        cells = [norm_header(c) for c in split_row(line)]
        if "platform" in cells and any(c in COLUMNS for c in cells if c):
            header, header_at = cells, n
    if header is None:
        bail("%s has no pipe table with a `platform` column" % path)

    unknown_cols = [c for c in header if c and c not in COLUMNS]
    for c in unknown_cols:
        WARNS.append("unknown column `%s` in the header — ignored" % c)

    ncols = len(header)
    idx = {name: i for i, name in enumerate(header) if name in COLUMNS}

    rows = []
    seen = set()
    for n in range(header_at + 1, len(lines)):
        line = lines[n]
        if "|" not in line:
            continue
        if line.lstrip().startswith(("#", ">")):
            continue
        cells = split_row(line)
        if is_divider(cells):
            continue
        if len(cells) != ncols:
            bail("%s line %d: row has %d cells, the header has %d — refusing "
                 "to guess a column mapping (row: %s)"
                 % (path, n + 1, len(cells), ncols, line.strip()[:120]))
        name = clean(cells[idx["platform"]]).strip("`").lower()
        if not name:
            continue
        if name in seen:
            bail("%s line %d: duplicate row for platform `%s` — one row per "
                 "platform" % (path, n + 1, name))
        seen.add(name)
        row = {k: clean(cells[i]) for k, i in idx.items()}
        row["platform"] = name
        rows.append(row)

    if args.want:
        known = {r["platform"] for r in rows}
        for w in args.want:
            if w.lower() not in known:
                die("no row for platform %r in %s (rows: %s)"
                    % (w, path, ", ".join(sorted(known)) or "none"))
        rows = [r for r in rows if r["platform"] in
                {w.lower() for w in args.want}]

    resolved = []
    for row in rows:
        p = row["platform"]
        out = {"platform": p}

        # release_model — declared wins; inference is always warned.
        declared = (row.get("release_model") or "").lower()
        if declared in ("deploy", "submission"):
            out["release_model"] = declared
            out["release_model_source"] = "declared"
        else:
            if declared:
                WARNS.append("%s: release_model=%r is not deploy|submission — "
                             "falling back to inference" % (p, declared))
            if p in ("ios", "android"):
                inferred = "submission"
            else:
                inferred = "deploy"
            out["release_model"] = inferred
            out["release_model_source"] = "inferred"
            if p == "macos":
                WARNS.append(
                    "macos: release_model is NOT declared. macOS is the one "
                    "platform whose identity does not settle the model — a "
                    "direct-download Sparkle app is `deploy`, a Mac App Store "
                    "build is `submission`. Falling back to `deploy`; if this "
                    "app ships through the Mac App Store the row MUST declare "
                    "`release_model: submission`.")
            else:
                WARNS.append("%s: release_model missing — inferred `%s` from "
                             "the platform identity (declare it in "
                             "PLATFORMS.md to silence this)" % (p, inferred))

        for k in ("rollback_possible", "tolerance", "staging_deploy_cmd",
                  "staging_config", "production_deploy_cmd", "smoke_cmd",
                  "smoke_watch_window", "smoke_poll", "version_probe",
                  "required_buckets"):
            out[k] = row.get(k, "")

        # The rollback lever is model-keyed — one lever per platform.
        if out["release_model"] == "deploy":
            out["rollback_lever_key"] = "rollback_cmd"
            out["rollback_lever"] = row.get("rollback_cmd", "")
        else:
            out["rollback_lever_key"] = "rollout_halt_cmd"
            out["rollback_lever"] = row.get("rollout_halt_cmd", "")

        # macOS `deploy` checks are config-gated AND model-gated: a Mac App
        # Store macOS row is notarized/signed by Apple internally and has no
        # appcast, so the columns are not surfaced even if filled in.
        mac_deploy = (p == "macos" and out["release_model"] == "deploy")
        for k in ("notarize_status_cmd", "signing_smoke_cmd", "appcast_url"):
            v = row.get(k, "")
            if v and not mac_deploy:
                WARNS.append("%s: `%s` is a macOS `deploy` column — ignored on "
                             "this row" % (p, k))
            out[k] = v if mac_deploy else ""

        if not out["smoke_cmd"]:
            out["smoke_mode"] = "none"
        elif out["smoke_poll"] and out["smoke_watch_window"]:
            out["smoke_mode"] = "poll+watch"
        elif out["smoke_poll"]:
            out["smoke_mode"] = "poll"
        elif out["smoke_watch_window"]:
            out["smoke_mode"] = "watch"
        else:
            out["smoke_mode"] = "one_shot"

        resolved.append(out)

    print("PLATFORMS_FILE=%s" % path)
    print("PLATFORM_COUNT=%d" % len(resolved))
    print("PLATFORMS=%s" % ",".join(r["platform"] for r in resolved))
    for r in resolved:
        for k in EMIT_ORDER:
            print("%s.%s=%s" % (r["platform"], k,
                                re.sub(r"\s+", " ", r.get(k, "")).strip()))
    for w in WARNS:
        print("WARN=%s" % re.sub(r"\s+", " ", w).strip())

    if args.as_json:
        print(json.dumps({"file": path, "platforms": resolved,
                          "warnings": WARNS}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())

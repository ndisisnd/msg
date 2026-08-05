#!/usr/bin/env python3
"""script-em-state.py — plan-em run-state checkpoint file (v5.6.5).

One JSON file per run, written at wave boundaries so a fresh session can
resume an interrupted run instead of restarting it. Resumability only:
observability stays with heartbeat.log and agent-watch.

Verbs (exactly one):
  --init  --file <path> --mode <plan|build|fused> [--size <tier>]
  --set   --file <path> --key <dotted.key> --value <str>
  --get   --file <path> [--key <dotted.key>]
  --close --file <path> --outcome <ok|failed|abandoned>
  --archive --file <path>          # move aside to <path>.prev (start fresh)

Contract (mirrors shared/refs/session-cache.md rule 4): a missing or corrupt
state file is never a hard failure for the run. --get prints NO_STATE /
CORRUPT and exits 0 so the consumer falls through to a fresh run; --set on a
missing/corrupt file exits 2 with one line (caller appends `|| true` and may
log a DOCTOR row). All writes are atomic (temp file + rename, same dir).
"""

import argparse
import json
import os
import sys
import tempfile
from datetime import datetime, timezone

SCHEMA = 1


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def atomic_write(path: str, obj: dict) -> None:
    d = os.path.dirname(os.path.abspath(path)) or "."
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".em-state.", dir=d)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(obj, f, indent=2, sort_keys=True)
            f.write("\n")
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def load(path: str):
    """Return (state, verdict) where verdict is OK | NO_STATE | CORRUPT."""
    if not os.path.exists(path):
        return None, "NO_STATE"
    try:
        with open(path) as f:
            state = json.load(f)
        if not isinstance(state, dict) or "status" not in state:
            return None, "CORRUPT"
        return state, "OK"
    except (json.JSONDecodeError, OSError, UnicodeDecodeError):
        return None, "CORRUPT"


def set_dotted(obj: dict, key: str, value: str) -> None:
    parts = key.split(".")
    for p in parts[:-1]:
        nxt = obj.get(p)
        if not isinstance(nxt, dict):
            nxt = {}
            obj[p] = nxt
        obj = nxt
    obj[parts[-1]] = value


def get_dotted(obj, key: str):
    for p in key.split("."):
        if not isinstance(obj, dict) or p not in obj:
            return None
        obj = obj[p]
    return obj


def main() -> int:
    ap = argparse.ArgumentParser(add_help=True)
    verb = ap.add_mutually_exclusive_group(required=True)
    verb.add_argument("--init", action="store_true")
    verb.add_argument("--set", action="store_true")
    verb.add_argument("--get", action="store_true")
    verb.add_argument("--close", action="store_true")
    verb.add_argument("--archive", action="store_true")
    ap.add_argument("--file", required=True)
    ap.add_argument("--mode", choices=["plan", "build", "fused"])
    ap.add_argument("--size")
    ap.add_argument("--key")
    ap.add_argument("--value")
    ap.add_argument("--outcome", choices=["ok", "failed", "abandoned"])
    a = ap.parse_args()

    if a.init:
        if not a.mode:
            print("Hard failure: --init requires --mode.")
            return 1
        state, verdict = load(a.file)
        if verdict == "OK" and state.get("status") == "open":
            # An open run already exists — never clobber it silently.
            print(f"OPEN_EXISTS {a.file}")
            return 3
        st = {
            "schema": SCHEMA,
            "status": "open",
            "mode": a.mode,
            "created_at": now(),
            "updated_at": now(),
            "waves": {},
        }
        if a.size:
            st["size"] = a.size
        atomic_write(a.file, st)
        print("INIT_OK")
        return 0

    if a.set:
        if not a.key or a.value is None:
            print("Hard failure: --set requires --key and --value.")
            return 1
        state, verdict = load(a.file)
        if verdict != "OK":
            print(f"STATE_{verdict}")
            return 2
        set_dotted(state, a.key, a.value)
        state["updated_at"] = now()
        atomic_write(a.file, state)
        print("SET_OK")
        return 0

    if a.get:
        state, verdict = load(a.file)
        if verdict != "OK":
            print(verdict)
            return 0
        if a.key:
            val = get_dotted(state, a.key)
            print("" if val is None else (json.dumps(val) if isinstance(val, (dict, list)) else val))
        else:
            print(json.dumps(state, indent=2, sort_keys=True))
        return 0

    if a.close:
        if not a.outcome:
            print("Hard failure: --close requires --outcome.")
            return 1
        state, verdict = load(a.file)
        if verdict != "OK":
            print(f"STATE_{verdict}")
            return 2
        state["status"] = "closed"
        state["outcome"] = a.outcome
        state["closed_at"] = now()
        state["updated_at"] = now()
        atomic_write(a.file, state)
        print("CLOSE_OK")
        return 0

    if a.archive:
        if not os.path.exists(a.file):
            print("NO_STATE")
            return 0
        os.replace(a.file, a.file + ".prev")
        print("ARCHIVED")
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())

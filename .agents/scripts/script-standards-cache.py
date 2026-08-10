#!/usr/bin/env python3
"""script-standards-cache.py — persistent cache for compiled /cook standards
payloads (v5.6.5).

Extends the session-cache convention (shared/refs/session-cache.md): artifacts
live under .claude/msg/cache/, keyed by the canonical flag set, with a
source_hash covering every cook file the flags could load. The freshness check
here is script-based (LLM-free); regeneration is a /cook invocation by the
caller — the documented exception in session-cache.md.

Verbs:
  --check --flags "<flag set>" [--cache-dir D] [--cook-root R]
      HIT <payload-path>   exit 0   (fresh — read the payload, skip /cook)
      MISS <key>           exit 1   (call /cook, then --store)
  --store --flags "<flag set>" --payload <file> [--cache-dir D] [--cook-root R]
      STORE_OK <payload-path>  exit 0
      STORE_FAIL <reason>      exit 1  (best-effort; caller continues)

Hash set for a flag list like `--global --macos --macos:hig-conventions`:
cook's SKILL.md + refs/*.md (flag→file resolution logic) plus the whole
standards/<domain>/ tree for every domain named ("global" counts as a domain).
Hashing whole domain trees over-invalidates slightly but can never serve a
stale composition. Any doubt (missing cook, unreadable meta) is a MISS, never
a traceback.
"""

import argparse
import hashlib
import json
import os
import sys
import tempfile
from datetime import datetime, timezone

DEFAULT_CACHE_DIR = ".claude/msg/cache"


def find_cook_root(override: str | None) -> str | None:
    candidates = [override] if override else [
        ".claude/skills/cook",
        os.path.expanduser("~/.claude/skills/cook"),
    ]
    for c in candidates:
        if c and os.path.isdir(c):
            return c
    return None


def canonical_flags(raw: str) -> list[str]:
    return sorted(set(raw.split()))


def flag_domains(flags: list[str]) -> list[str]:
    domains = set()
    for f in flags:
        tok = f.lstrip("-")
        domains.add(tok.split(":", 1)[0])
    return sorted(domains)


def iter_hash_files(cook_root: str, domains: list[str]):
    skill = os.path.join(cook_root, "SKILL.md")
    if os.path.isfile(skill):
        yield skill
    refs = os.path.join(cook_root, "refs")
    if os.path.isdir(refs):
        for name in sorted(os.listdir(refs)):
            p = os.path.join(refs, name)
            if os.path.isfile(p) and name.endswith(".md"):
                yield p
    for dom in domains:
        droot = os.path.join(cook_root, "standards", dom)
        if not os.path.isdir(droot):
            continue
        for dirpath, dirnames, filenames in os.walk(droot):
            dirnames.sort()
            for name in sorted(filenames):
                yield os.path.join(dirpath, name)


def source_hash(cook_root: str, flags: list[str]) -> str:
    h = hashlib.sha256()
    h.update(("\x00".join(flags) + "\x01").encode())
    for path in iter_hash_files(cook_root, flag_domains(flags)):
        rel = os.path.relpath(path, cook_root)
        h.update(rel.encode() + b"\x00")
        try:
            with open(path, "rb") as f:
                h.update(f.read())
        except OSError:
            h.update(b"<unreadable>")
        h.update(b"\x00")
    return h.hexdigest()


def cache_paths(cache_dir: str, flags: list[str]):
    key = hashlib.sha256(" ".join(flags).encode()).hexdigest()[:12]
    base = os.path.join(cache_dir, f"standards-{key}")
    return key, base + ".payload.md", base + ".meta.json"


def main() -> int:
    ap = argparse.ArgumentParser()
    verb = ap.add_mutually_exclusive_group(required=True)
    verb.add_argument("--check", action="store_true")
    verb.add_argument("--store", action="store_true")
    ap.add_argument("--flags", required=True)
    ap.add_argument("--payload")
    ap.add_argument("--cache-dir", default=DEFAULT_CACHE_DIR)
    ap.add_argument("--cook-root")
    a = ap.parse_args()

    flags = canonical_flags(a.flags)
    if not flags:
        print("MISS empty-flags" if a.check else "STORE_FAIL empty-flags")
        return 1
    key, payload_path, meta_path = cache_paths(a.cache_dir, flags)
    cook_root = find_cook_root(a.cook_root)

    if a.check:
        if cook_root is None:
            print("MISS cook-not-found")
            return 1
        if not (os.path.isfile(payload_path) and os.path.isfile(meta_path)):
            print(f"MISS {key}")
            return 1
        try:
            with open(meta_path) as f:
                meta = json.load(f)
        except (json.JSONDecodeError, OSError, UnicodeDecodeError):
            print(f"MISS {key}")
            return 1
        if meta.get("flags") != flags or meta.get("source_hash") != source_hash(cook_root, flags):
            print(f"MISS {key}")
            return 1
        print(f"HIT {payload_path}")
        return 0

    # --store
    if not a.payload:
        print("STORE_FAIL payload-required")
        return 1
    if cook_root is None:
        print("STORE_FAIL cook-not-found")
        return 1
    try:
        with open(a.payload, "rb") as f:
            payload = f.read()
    except OSError as e:
        print(f"STORE_FAIL unreadable-payload:{e.strerror}")
        return 1
    if not payload.strip():
        print("STORE_FAIL empty-payload")
        return 1
    try:
        os.makedirs(a.cache_dir, exist_ok=True)
        for target, data in (
            (payload_path, payload),
            (meta_path, (json.dumps({
                "flags": flags,
                "source_hash": source_hash(cook_root, flags),
                "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            }, indent=2, sort_keys=True) + "\n").encode()),
        ):
            fd, tmp = tempfile.mkstemp(prefix=".standards.", dir=a.cache_dir)
            with os.fdopen(fd, "wb") as f:
                f.write(data)
            os.replace(tmp, target)
    except OSError as e:
        print(f"STORE_FAIL write:{e.strerror}")
        return 1
    print(f"STORE_OK {payload_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

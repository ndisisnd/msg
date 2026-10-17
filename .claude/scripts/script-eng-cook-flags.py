#!/usr/bin/env python3
"""
script-eng-cook-flags.py — the /cook flag set for a build, from its stack.

A standalone `eng --build` (and plan-em's standards step) calls `/cook` with
explicit flags, never prose, so the call is cacheable and always loads the P0
floor. This script owns the mechanical part of that selection; the model owns
only the judgment of which refs the PRD/devkit PROVABLY excludes.

Rules it applies:
  1. `--global` always, bare and unscoped (the P0 floor + every concern ref).
  2. Each stack token maps to its cook domain(s) via STACK_DOMAINS.
  3. A domain's refs are enumerated from `<cook>/standards/<domain>/refs/*.md`
     — never a hard-coded list, because cook's shelves change.
  4. Keep every ref by default. Drop a ref only when it is named in --exclude
     (`<domain>:<ref>`) — a provable exclusion the caller decided.
  5. The bare `--<domain>` flag is always emitted (the domain SKILL.md floor).
     With no exclusion in a domain the bare flag alone already loads every ref,
     so no sub-ref flags are added. With an exclusion, one `--<domain>:<ref>`
     per kept ref follows the bare flag.
  6. A domain with no `standards/<domain>/` folder, or an unknown stack token,
     is reported as a GAP; the caller names it in the build summary.

Usage:
  script-eng-cook-flags.py --stack <tok[,tok…]> [--exclude <domain:ref[,…]>]
                           [--cook-root <dir>]

  Stack tokens: flutter dart react nextjs nodejs typescript supabase postgres
  graphql swift macos css.

Output (stdout):
  FLAGS=<the flag set, space-separated>
  GAP=<token-or-domain>         one line per uncovered stack (may be none)

Exit codes:
  0  flags printed (GAP lines included when present)
  2  usage error, or no cook install found
"""
import argparse
import os
import sys

STACK_DOMAINS = {
    "flutter": ["flutter", "dart"],
    "dart": ["dart"],
    "react": ["react"],
    "nextjs": ["nextjs"],
    "nodejs": ["nodejs"],
    "typescript": ["typescript"],
    "supabase": ["supabase", "database"],
    "postgres": ["database"],
    "graphql": ["graphql"],
    "swift": ["swift"],
    "macos": ["macos"],
    "css": ["css"],
}


def find_cook_root(override):
    """Return the first cook install that exists, or None."""
    candidates = [override] if override else [
        ".claude/skills/cook",
        os.path.expanduser("~/.claude/skills/cook"),
    ]
    for c in candidates:
        if c and os.path.isdir(os.path.join(c, "standards")):
            return c
    return None


def split_list(raw):
    """Split a comma/space separated argument into clean tokens."""
    return [t.strip() for t in (raw or "").replace(",", " ").split() if t.strip()]


def main():
    ap = argparse.ArgumentParser(prog="script-eng-cook-flags.py")
    ap.add_argument("--stack", required=True)
    ap.add_argument("--exclude", default="")
    ap.add_argument("--cook-root", default=None)
    args = ap.parse_args()

    root = find_cook_root(args.cook_root)
    if not root:
        print("script-eng-cook-flags: no cook install found (standards/ missing)",
              file=sys.stderr)
        sys.exit(2)

    excluded = set(split_list(args.exclude))
    domains, gaps = [], []
    for tok in split_list(args.stack):
        mapped = STACK_DOMAINS.get(tok.lower())
        if not mapped:
            gaps.append(tok)
            continue
        for d in mapped:
            if d not in domains:
                domains.append(d)

    flags = ["--global"]
    for d in domains:
        droot = os.path.join(root, "standards", d)
        if not os.path.isdir(droot):
            gaps.append(d)
            continue
        refs_dir = os.path.join(droot, "refs")
        refs = sorted(f[:-3] for f in os.listdir(refs_dir)
                      if f.endswith(".md")) if os.path.isdir(refs_dir) else []
        kept = [r for r in refs if f"{d}:{r}" not in excluded]
        flags.append(f"--{d}")
        if len(kept) < len(refs):
            flags.extend(f"--{d}:{r}" for r in kept)

    print("FLAGS=" + " ".join(flags))
    for g in gaps:
        print("GAP=" + g)
    sys.exit(0)


if __name__ == "__main__":
    main()

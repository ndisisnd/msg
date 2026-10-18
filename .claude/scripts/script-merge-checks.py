#!/usr/bin/env python3
"""
script-merge-checks.py — the mechanical halves of merge's PR step and setup.

merge opens the PR, so before it pushes it must know three facts that are pure
lookups, never judgment: did pre-merge pass on this commit, how big and how
risky is anything committed since, and how long may CI take. This script
answers each one; the model only acts on the keys.

Contract:
  .claude/skills/merge/refs/open-pr.md               § Pass check, § CI wait
  .claude/skills/merge/refs/protocol-init.md         § Risky paths, § CI limit
  .claude/skills/shared/refs/policy-schema-merge.md  § policies.merge
  .claude/skills/shared/refs/component-catalog.md    § Risky libraries

Subcommands
  pass      --branch <b> [--head <sha>] [--last-check <file>] [--policy <p>]
            [--catalog <md>] [--max-lines 20] [--repo <dir>]
      Reads pre-merge's stored last check (.pre-merge/last-check.json, written
      by script-premerge-last-check.sh) and grades the branch tip against it.
        PASS_STATE=current     the pass is on the tip            exit 0
        PASS_STATE=small       new commits, small + not risky    exit 4
                               (merge runs the quick check)
        PASS_STATE=not_small   new commits, too big or risky     exit 3
        PASS_STATE=none        no record, or the verdict is not  exit 3
                               pass / pass_with_warnings
        PASS_STATE=history_changed  the checked commit is not    exit 3
                               an ancestor of the tip
      Small = this branch's own commits since the pass (first parent, no
      merges) change <= --max-lines added+removed lines, lock and generated
      files not counted, and touch no risky path. A lock file is never counted
      and is always risky. A risky-library hit in a changed file outside the
      list is risky too; its folder is reported in NEW_RISKY_PATHS.
  libs      (--all | --files <f>...) [--policy <p>] [--catalog <md>] [--repo]
      Runs the risky-library search over tracked files (--all) or the named
      files. Prints FOUND_PATHS (every folder hit) and NEW_RISKY_PATHS (hits
      the policy list does not already cover), plus RISKY_PATHS_JSON (the
      policy list with the new paths appended — never a path removed).
  seed      --scope <universal|web|python|go|apple|android>... [--catalog <md>]
      Prints RISKY_PATHS_JSON: the force_full_paths rows for the scopes plus
      the fixed globs. Setup appends the `libs --all` hits.
  ci-limit  [--input <runs.json>] [--runs 20] [--repo <dir>]
      Measures recent GitHub Actions run times (`gh run list`, or a fixture
      list of {createdAt, updatedAt, status}) and prints CI_LIMIT_MINUTES =
      max(30, slowest completed run x 1.5, rounded up to 5). No runs ⇒ 30.

Output: KEY=VALUE lines on stdout. Exit 2 on a usage error.
Deterministic: the same repo state + inputs ⇒ the same output.
"""
import argparse
import fnmatch
import json
import math
import os
import re
import subprocess
import sys
from datetime import datetime

SELF = "script-merge-checks"
PASSING = {"pass", "pass_with_warnings"}

LOCK_FILES = {
    "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb",
    "bun.lock", "npm-shrinkwrap.json", "poetry.lock", "Pipfile.lock",
    "uv.lock", "Cargo.lock", "go.sum", "Gemfile.lock", "composer.lock",
    "Podfile.lock", "Package.resolved", "gradle.lockfile", "pubspec.lock",
    "mix.lock",
}
GENERATED_GLOBS = [
    "*.min.js", "*.min.css", "*.map", "*.pb.go", "*_pb2.py", "*.g.dart",
    "*.generated.*", "**/__generated__/**", "**/generated/**",
    "dist/**", "build/**", "**/dist/**", "**/build/**",
]
SKIP_SEARCH = ["node_modules/", "vendor/", "dist/", "build/", ".git/"]
IMPORT_LINE = re.compile(
    r"^\s*(import\b|from\b|use\b|#import\b|@import\b|implementation\b|"
    r"api\b|.*\brequire\s*\(|.*\bimport\s*\()")


def die(msg):
    sys.stderr.write("%s: %s\n" % (SELF, msg))
    sys.exit(2)


def git(repo, *args):
    p = subprocess.run(["git", "-C", repo] + list(args),
                       capture_output=True, text=True)
    return p.returncode, p.stdout


def resolve(repo, rel):
    """Repo copy first, global install second (sanctioned-writes.md form)."""
    local = os.path.join(repo, rel)
    if os.path.exists(local):
        return local
    home = os.path.join(os.path.expanduser("~"), rel)
    return home if os.path.exists(home) else None


# ── glob matching (gitignore-like: a slash-less glob matches any basename) ──
def glob_re(pat):
    out, i = "", 0
    while i < len(pat):
        if pat.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pat.startswith("**", i):
            out += ".*"
            i += 2
        elif pat[i] == "*":
            out += "[^/]*"
            i += 1
        elif pat[i] == "?":
            out += "[^/]"
            i += 1
        else:
            out += re.escape(pat[i])
            i += 1
    return re.compile("^" + out + "$")


def matches(path, pat):
    pat = pat.strip()
    if not pat:
        return False
    if "/" not in pat.rstrip("/"):
        return fnmatch.fnmatchcase(os.path.basename(path), pat)
    return bool(glob_re(pat).match(path))


def is_lock(path):
    return os.path.basename(path) in LOCK_FILES


def is_generated(path):
    return any(matches(path, g) for g in GENERATED_GLOBS)


# ── catalog parsing ─────────────────────────────────────────────────────────
def section_rows(text, heading_prefix):
    rows, inside = [], False
    for line in text.splitlines():
        if line.startswith("### "):
            inside = line.startswith(heading_prefix)
            continue
        if line.startswith("## "):
            inside = False
        if inside and line.startswith("|") and not re.match(r"^\|[-\s|]+\|$",
                                                            line):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            rows.append(cells)
    return rows[1:] if rows else []   # drop the header row


def tokens(cell):
    return [t.strip().strip("`") for t in cell.split("·")
            if t.strip().strip("`") and t.strip() != "—"]


def load_catalog(repo, path):
    path = path or resolve(repo, ".claude/skills/shared/refs/component-catalog.md")
    if not path or not os.path.exists(path):
        die("component catalog not found (pass --catalog)")
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    fixed, imports, calls = [], [], []
    for cells in section_rows(text, "### Risky libraries"):
        if len(cells) < 3:
            continue
        if cells[0].lower() == "fixed":
            fixed += tokens(cells[1])
        else:
            imports += tokens(cells[1])
            calls += tokens(cells[2])
    scopes = {}
    for cells in section_rows(text, "### `force_full_paths` defaults"):
        if len(cells) >= 2:
            key = re.sub(r"[^a-z]", " ", cells[0].lower()).split()
            if key:
                scopes[key[0]] = tokens(cells[1])
    return fixed, imports, calls, scopes


def load_policy_risky(repo, policy):
    try:
        with open(os.path.join(repo, policy), encoding="utf-8") as fh:
            doc = json.load(fh)
        lst = ((doc.get("policies") or {}).get("merge") or {}).get(
            "risky_paths")
        if isinstance(lst, list) and all(isinstance(x, str) for x in lst):
            return lst, "present"
    except (OSError, ValueError, AttributeError):
        pass
    return None, "absent"


def seed_list(fixed, scopes, wanted):
    out = []
    for s in ["universal"] + list(wanted):
        for g in scopes.get(s, []):
            if g not in out:
                out.append(g)
    for g in fixed:
        if g not in out:
            out.append(g)
    return out


# ── library search ──────────────────────────────────────────────────────────
def lib_hits(repo, files, imports, calls):
    found = []
    for f in files:
        if (is_lock(f) or f.endswith(".md")
                or any(("/" + f).find("/" + s) >= 0 for s in SKIP_SEARCH)):
            continue
        full = os.path.join(repo, f)
        try:
            if os.path.getsize(full) > 1_000_000:
                continue
            with open(full, encoding="utf-8", errors="ignore") as fh:
                text = fh.read()
        except OSError:
            continue
        hit = False
        for line in text.splitlines():
            if any(c in line for c in calls):
                hit = True
            elif IMPORT_LINE.match(line) and any(t in line for t in imports):
                hit = True
            if hit:
                break
        if hit:
            d = os.path.dirname(f)
            g = (d + "/**") if d else f
            if g not in found:
                found.append(g)
    return found


def covered(path_glob, risky):
    probe = path_glob[:-3] + "/x" if path_glob.endswith("/**") else path_glob
    return any(matches(probe, r) for r in risky)


# ── subcommands ─────────────────────────────────────────────────────────────
def emit(pairs, code):
    print("\n".join("%s=%s" % kv for kv in pairs))
    sys.exit(code)


def cmd_pass(a):
    repo = a.repo
    lc = os.path.join(repo, a.last_check)
    rec = None
    try:
        with open(lc, encoding="utf-8") as fh:
            rec = (json.load(fh).get("branches") or {}).get(a.branch)
    except (OSError, ValueError, AttributeError):
        rec = None
    rc, head = git(repo, "rev-parse", a.head or "HEAD")
    head = head.strip()
    if rc != 0 or not head:
        die("cannot resolve the branch tip")
    base = [("BRANCH", a.branch), ("HEAD", head)]
    if not isinstance(rec, dict) or not rec.get("head") \
            or not rec.get("verdict"):
        emit(base + [("PASS_STATE", "none"), ("CHECKED", ""), ("VERDICT", ""),
                     ("REASON", "no pre-merge record for this branch")], 3)
    checked, verdict = rec["head"], rec["verdict"]
    base += [("CHECKED", checked), ("VERDICT", verdict),
             ("REPORT", rec.get("report") or "")]
    if verdict not in PASSING:
        emit(base + [("PASS_STATE", "none"),
                     ("REASON", "last pre-merge verdict is %s" % verdict)], 3)
    rc, full = git(repo, "rev-parse", "--verify", "--quiet",
                   checked + "^{commit}")
    if rc != 0:
        emit(base + [("PASS_STATE", "history_changed"),
                     ("REASON", "checked commit no longer exists")], 3)
    if full.strip() == head:
        emit(base + [("PASS_STATE", "current"), ("REASON", "pass is on the tip")],
             0)
    rc, _ = git(repo, "merge-base", "--is-ancestor", checked, head)
    if rc != 0:
        emit(base + [("PASS_STATE", "history_changed"),
                     ("REASON", "checked commit is not an ancestor of the tip")],
             3)

    rng = "%s..%s" % (checked, head)
    _, log = git(repo, "log", "--first-parent", "--no-merges",
                 "--format=@@%h %s", "--numstat", rng)
    commits, lines, files = [], 0, []
    for line in log.splitlines():
        if line.startswith("@@"):
            commits.append(line[2:])
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        add, rem, path = parts
        if "=>" in path:   # rename: count the new path
            path = re.sub(r"\{[^}]*=> ([^}]*)\}", r"\1", path)
            path = path.split(" => ")[-1]
        if path not in files:
            files.append(path)
        if is_lock(path) or is_generated(path):
            continue
        lines += (int(add) if add.isdigit() else 0) + \
                 (int(rem) if rem.isdigit() else 0)

    fixed, imports, calls, scopes = load_catalog(repo, a.catalog)
    risky, state = load_policy_risky(repo, a.policy)
    if risky is None:
        risky = seed_list(fixed, scopes, [])
    risky_hits = [f for f in files
                  if is_lock(f) or any(matches(f, r) for r in risky)]
    present = [f for f in files if os.path.exists(os.path.join(repo, f))]
    new_paths = [g for g in lib_hits(repo, present, imports, calls)
                 if not covered(g, risky)]
    for g in new_paths:
        for f in files:
            if matches(f, g) and f not in risky_hits:
                risky_hits.append(f)
    small = lines <= a.max_lines and not risky_hits
    out = base + [
        ("PASS_STATE", "small" if small else "not_small"),
        ("NEW_COMMITS", len(commits)),
        ("CHANGED_LINES", lines),
        ("MAX_LINES", a.max_lines),
        ("CHANGED_FILES", ",".join(files)),
        ("RISKY_FILES", ",".join(risky_hits)),
        ("RISKY_SOURCE", "policy" if state == "present" else "catalog-seed"),
        ("NEW_RISKY_PATHS", ",".join(new_paths)),
        ("RISKY_PATHS_JSON", json.dumps(risky + new_paths)),
        ("TEST_FILES", ",".join(name_matched_tests(repo, files))),
        ("REASON", "small change since the pass" if small else
         ("risky files changed" if risky_hits else
          "%d changed lines > %d" % (lines, a.max_lines))),
    ]
    for c in commits:
        out.append(("COMMIT", c))
    emit(out, 4 if small else 3)


def name_matched_tests(repo, files):
    """`home.ts` → `home.test.ts` / `home.spec.ts` / `test_home.py` / …"""
    rc, out = git(repo, "ls-files")
    tracked = out.splitlines() if rc == 0 else []
    found = []
    for f in files:
        stem, ext = os.path.splitext(os.path.basename(f))
        if re.search(r"(\.test|\.spec|_test|Tests?)$", stem) \
                or stem.startswith("test_"):
            cands = {os.path.basename(f)}
        else:
            cands = {"%s.test%s" % (stem, ext), "%s.spec%s" % (stem, ext),
                     "%s_test%s" % (stem, ext), "test_%s%s" % (stem, ext),
                     "%sTests%s" % (stem, ext), "%sTest%s" % (stem, ext)}
        for t in tracked:
            if os.path.basename(t) in cands and t not in found:
                found.append(t)
    return found


def cmd_libs(a):
    repo = a.repo
    fixed, imports, calls, scopes = load_catalog(repo, a.catalog)
    risky, _ = load_policy_risky(repo, a.policy)
    if risky is None:
        risky = seed_list(fixed, scopes, [])
    if a.all:
        rc, out = git(repo, "ls-files")
        files = out.splitlines() if rc == 0 else []
    else:
        files = a.files or []
    found = lib_hits(repo, files, imports, calls)
    new = [g for g in found if not covered(g, risky)]
    emit([("FOUND_PATHS", ",".join(found)),
          ("NEW_RISKY_PATHS", ",".join(new)),
          ("RISKY_PATHS_JSON", json.dumps(risky + new))], 0)


def cmd_seed(a):
    fixed, _, _, scopes = load_catalog(a.repo, a.catalog)
    unknown = [s for s in a.scope if s not in scopes]
    if unknown:
        die("unknown scope(s): %s (known: %s)"
            % (",".join(unknown), ",".join(sorted(scopes))))
    emit([("SCOPES", ",".join(["universal"] + [s for s in a.scope
                                                if s != "universal"])),
          ("RISKY_PATHS_JSON", json.dumps(seed_list(fixed, scopes, a.scope)))],
         0)


def parse_ts(s):
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")
    except (TypeError, ValueError):
        return None


def cmd_ci_limit(a):
    runs, source = [], "gh"
    if a.input:
        source = "input"
        try:
            with open(a.input, encoding="utf-8") as fh:
                runs = json.load(fh)
        except (OSError, ValueError) as exc:
            die("cannot read --input: %s" % exc)
    else:
        p = subprocess.run(
            ["gh", "run", "list", "--limit", str(a.runs), "--json",
             "createdAt,updatedAt,status"], cwd=a.repo,
            capture_output=True, text=True)
        if p.returncode == 0:
            try:
                runs = json.loads(p.stdout or "[]")
            except ValueError:
                runs = []
        else:
            source = "gh_error"
    mins = []
    for r in runs if isinstance(runs, list) else []:
        if not isinstance(r, dict) or r.get("status") not in (None,
                                                               "completed"):
            continue
        t0, t1 = parse_ts(r.get("createdAt")), parse_ts(r.get("updatedAt"))
        if t0 and t1 and t1 >= t0:
            mins.append((t1 - t0).total_seconds() / 60.0)
    slowest = max(mins) if mins else 0.0
    limit = max(30, int(math.ceil(slowest * 1.5 / 5.0)) * 5)
    emit([("SOURCE", source), ("RUNS_MEASURED", len(mins)),
          ("SLOWEST_MINUTES", int(math.ceil(slowest))),
          ("CI_LIMIT_MINUTES", limit)], 0)


def main():
    ap = argparse.ArgumentParser(prog="script-merge-checks.py")
    sub = ap.add_subparsers(dest="cmd")
    p = sub.add_parser("pass")
    p.add_argument("--branch", required=True)
    p.add_argument("--head")
    p.add_argument("--last-check", default=".pre-merge/last-check.json")
    p.add_argument("--max-lines", type=int, default=20)
    l = sub.add_parser("libs")
    l.add_argument("--all", action="store_true")
    l.add_argument("--files", nargs="*")
    s = sub.add_parser("seed")
    s.add_argument("--scope", action="extend", nargs="+", default=[])
    c = sub.add_parser("ci-limit")
    c.add_argument("--input")
    c.add_argument("--runs", type=int, default=20)
    for x in (p, l, s, c):
        x.add_argument("--repo", default=os.getcwd())
        x.add_argument("--policy", default="devkit/policy.json")
        x.add_argument("--catalog")
    a = ap.parse_args()
    if a.cmd is None:
        ap.print_usage(sys.stderr)
        sys.exit(2)
    if a.cmd == "libs" and not a.all and not a.files:
        die("libs needs --all or --files")
    {"pass": cmd_pass, "libs": cmd_libs, "seed": cmd_seed,
     "ci-limit": cmd_ci_limit}[a.cmd](a)


if __name__ == "__main__":
    main()

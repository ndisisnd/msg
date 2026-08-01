#!/usr/bin/env python3
"""
script-cert-mech.py — the mechanical half of the PRD certification.

Owns every certification check whose verdict is decidable from the PRD text
alone: check 4 (exec-table coverage / hygiene / collisions), check 5 (ticket
graph validity) and check 6 (frontmatter graph + platform bucket coverage).
Checks 1, 2, 3 and 7 are judgment calls and are not implemented here.

Usage:
  script-cert-mech.py <prd.md> [--checks 4,5,6]
                               [--platforms <PLATFORMS.md>]
                               [--features-root <dir>]

  --checks         comma-separated subset of 4,5,6. Default: 4,5,6.
                   Product tune passes `--checks 6`; eng tune passes `--checks 4,5,6`.
  --platforms      path to devkit/PLATFORMS.md. Default: devkit/PLATFORMS.md.
                   Absent → the bucket-coverage facet is skipped, never an error.
  --features-root  root the frontmatter graph is resolved against. Default: features.

Output (stdout, one record per line, machine-readable):
  FINDING check=<4|5|6> sev=<critical|major> code=<slug> ref=<locator> detail=<free text to EOL>
  SKIP    check=<n> facet=<slug> reason=<slug>
  SUMMARY checks=<list> findings=<n> critical=<n> major=<n>

SKIP reasons for check 4's collision facet: `no-collision-script` (neither the
repo copy nor the global install of script-em-exec-collision.py exists) and
`no-files-column` (the exec table has no Files column, so "zero collisions"
would be vacuous — the sub-script exits 3 and this is what the caller renders).

On stderr only, never stdout: `RESOLVED_VIA=global <path>` when the collision
sub-script is taken from `~/.claude/scripts/` because the repo has no copy. The
repo-copy case — the normal one — stays silent.

Finding codes:
  check 4  uncovered-fid (critical) · file-collision (critical) · empty-files (major)
           features-id-column-unresolved (critical — features table has rows but
           no id column, so F-ID coverage is unverifiable)
           files-column-unresolved (major — the exec table has no Files column at
           all, so the collision facet is skipped, not passed)
  check 5  unknown-ticket-id (critical) · ticket-cycle (critical) · missing-done-when (major)
  check 6  frontmatter-cycle (critical) · missing-edge-target (major) · missing-bucket-coverage (major)

Exit codes:
  0  ran clean — no findings
  1  ran — one or more FINDING lines emitted
  2  usage error, unreadable PRD, or no YAML frontmatter

Deterministic: identical inputs produce byte-identical output. Collisions are
delegated to script-em-exec-collision.py so there is one collision implementation.
"""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

SELF = "script-cert-mech"

FINDINGS = []


def emit(check, sev, code, ref, detail):
    FINDINGS.append((check, sev, code, ref, " ".join(str(detail).split())))


def die(msg):
    print(f"{SELF}: {msg}", file=sys.stderr)
    sys.exit(2)


# ── PRD parsing ───────────────────────────────────────────────────────────────

def split_frontmatter(lines):
    """Return (frontmatter_dict, body_start_index). Scalars and lists only."""
    if not lines or lines[0].strip() != "---":
        return None, 0
    fm, key = {}, None
    for i in range(1, len(lines)):
        raw = lines[i]
        if raw.strip() == "---":
            return fm, i + 1
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", raw)
        if m:
            key, val = m.group(1), m.group(2).strip()
            if val.startswith("[") and val.endswith("]"):
                fm[key] = [t.strip().strip("'\"") for t in val[1:-1].split(",") if t.strip()]
            elif val == "":
                fm[key] = []
            else:
                fm[key] = val.strip("'\"")
            continue
        m = re.match(r"^\s+-\s*(.+?)\s*$", raw)
        if m and key is not None:
            cur = fm.get(key)
            if not isinstance(cur, list):
                cur = [] if cur in ("", None) else [cur]
            cur.append(m.group(1).strip("'\""))
            fm[key] = cur
    return None, 0


def sections(lines, start, level):
    """Yield (title, start_idx, end_idx, block_lines) for `level` headings."""
    mark = "#" * level + " "
    idxs = [i for i in range(start, len(lines)) if lines[i].startswith(mark)]
    for n, i in enumerate(idxs):
        end = len(lines)
        for j in range(i + 1, len(lines)):
            m = re.match(r"^(#{1,6})\s", lines[j])
            if m and len(m.group(1)) <= level:
                end = j
                break
        yield lines[i][len(mark):].strip(), i, end, lines[i + 1:end]


def norm_title(title):
    return re.sub(r"^\d+(\.\d+)?\.\s*", "", title.lower()).strip()


def md_table(block):
    """Return (headers, rows) for the first markdown table in `block`."""
    headers, rows = None, []
    for ln in block:
        s = ln.strip()
        if not s.startswith("|"):
            if headers is not None:
                break
            continue
        bare = s.strip("|")
        if re.match(r"^[\s:|-]+$", bare):
            continue
        cells = [c.strip() for c in bare.split("|")]
        if headers is None:
            headers = [c.lower() for c in cells]
        else:
            rows.append(cells)
    return headers, rows


def col(headers, rows, *names):
    """Values of the first column whose header matches one of `names`."""
    if not headers:
        return []
    for i, h in enumerate(headers):
        if h in names:
            return [(r[i].strip() if i < len(r) else "") for r in rows]
    return []


def cycle_in(graph):
    """Return the first cycle found as a node list, or None. Deterministic."""
    WHITE, GREY, BLACK = 0, 1, 2
    state = {n: WHITE for n in graph}
    stack = []

    def visit(n):
        state[n] = GREY
        stack.append(n)
        for m in sorted(graph.get(n, [])):
            if m not in state:
                continue
            if state[m] == GREY:
                return stack[stack.index(m):] + [m]
            if state[m] == WHITE:
                found = visit(m)
                if found:
                    return found
        stack.pop()
        state[n] = BLACK
        return None

    for n in sorted(graph):
        if state[n] == WHITE:
            found = visit(n)
            if found:
                return found
    return None


# ── check 4 — exec-table / eng-section integrity ──────────────────────────────

def check4(lines, body_start, prd_path):
    feature_ids, exec_block, scope_text = [], None, []
    for title, s, e, block in sections(lines, body_start, 2):
        low = norm_title(title)
        # The exec table's ONE home (new: `## 6. Feature execution table`; legacy
        # `## Execution Table` still read). MUST be tested before the features
        # branch — "feature execution table" also starts with "feature".
        if low.startswith(("execution table", "feature execution table")):
            exec_block = block
        elif low.startswith("feature") or "acceptance cri" in low:
            headers, rows = md_table(block)
            ids = col(headers, rows, "id", "feature id")
            # A7: a features table with rows but no resolvable id column yields
            # zero F-IDs, so the uncovered-fid loop below iterates over nothing
            # and check 4 passes vacuously. Name the drift instead.
            if rows and not ids:
                emit(4, "critical", "features-id-column-unresolved", title.strip(),
                     f"features table has {len(rows)} row(s) but no 'id'/'feature id' "
                     f"column — headers seen: {', '.join(headers or []) or '(none)'}; "
                     "F-ID coverage cannot be checked")
            feature_ids += [v.upper() for v in ids if v]
        elif low.startswith("engineering"):
            for st, ss, se, sb in sections(lines, s, 3):
                if "scope mapping" in st.lower():
                    scope_text.append("\n".join(sb))

    scope_ids = set()
    for txt in scope_text:
        scope_ids |= {m.upper() for m in re.findall(r"\bF\d+(?:\.\d+)?\b", txt)}

    if not scope_text:
        emit(4, "critical", "uncovered-fid", "engineering",
             "no '### Scope mapping' subsection under any '## Engineering —' section; "
             "every F-ID is uncovered")
    else:
        for fid in feature_ids:
            if fid and fid not in scope_ids:
                emit(4, "critical", "uncovered-fid", fid,
                     f"{fid} from the features table appears in no engineering scope map")

    if exec_block is None:
        emit(4, "critical", "uncovered-fid", "execution-table",
             "no '## N. Feature execution table' section (legacy '## Execution Table' "
             "also accepted) — eng --build has no rows to read")
        return

    collide = Path(__file__).resolve().parent / "script-em-exec-collision.py"
    if not collide.is_file():
        # A23: falling back to the GLOBAL install is now stated. The repo copy
        # is the one under review; a stale ~/.claude copy silently grading a
        # repo's PRD is exactly the seam this names.
        alt = Path(os.path.expanduser("~/.claude/scripts/script-em-exec-collision.py"))
        if alt.is_file():
            collide = alt
            print(f"{SELF}: RESOLVED_VIA=global {alt}", file=sys.stderr)
        else:
            collide = None
    if collide is None:
        print(f"{SELF}: script-em-exec-collision.py not found — collision facet skipped",
              file=sys.stderr)
        print("SKIP check=4 facet=collisions reason=no-collision-script")
        return

    proc = subprocess.run([sys.executable, str(collide), "-"],
                          input="\n".join(exec_block), capture_output=True, text=True)
    # A21: rc 3 = the exec table carries no Files column, so the collision
    # question was never answered. Render the skip rather than dropping the
    # sub-script's stderr warning on the floor.
    if proc.returncode == 3:
        print(f"{SELF}: {proc.stderr.strip()}", file=sys.stderr)
        print("SKIP check=4 facet=collisions reason=no-files-column")
        # The SKIP says the facet did not run; the finding says why that is the
        # PRD's problem to fix. Without it a Files-less table would grade
        # QUIETER than before (it used to raise one `empty-files` major per
        # row), which would be a new silence inside the fix for an old one.
        headers, _rows = md_table(exec_block)
        emit(4, "major", "files-column-unresolved", "execution-table",
             "the execution table has no 'Files' column — headers seen: "
             f"{', '.join(headers or []) or '(none)'}; parallel-safety cannot "
             "be checked and eng --build has no file scope per row")
        return
    if proc.returncode not in (0, 1):
        die(f"script-em-exec-collision.py failed on {prd_path} (rc={proc.returncode}): "
            f"{proc.stderr.strip()}")
    for ln in proc.stdout.splitlines():
        if ln.startswith("COLLISION "):
            parts = ln.split()
            emit(4, "critical", "file-collision", f"{parts[1]}+{parts[2]}",
                 "execution-table rows share files: " + " ".join(parts[3:]))
        elif ln.startswith("MISSING_FILES "):
            parts = ln.split(None, 2)
            emit(4, "major", "empty-files", parts[1],
                 f"execution-table row has an empty Files column ({parts[2] if len(parts) > 2 else '?'})")


# ── check 5 — ticket graph validity ───────────────────────────────────────────

TICKET_RE = re.compile(r"^\s*-\s*\*\*(F\d+(?:\.\d+)?-T\d+)\b")
FIELD_RE = re.compile(r"^\s*-\s*\*\*([a-z-]+):\*\*\s*(.*)$", re.IGNORECASE)


def check5(lines, body_start):
    tickets, order, current = {}, [], None
    seen_todos = False
    for title, s, e, block in sections(lines, body_start, 2):
        if not norm_title(title).startswith("todos"):
            continue
        seen_todos = True
        for ln in block:
            m = TICKET_RE.match(ln)
            if m:
                current = m.group(1).upper()
                if current not in tickets:
                    tickets[current] = {"depends-on": "", "done-when": ""}
                    order.append(current)
                continue
            f = FIELD_RE.match(ln)
            if f and current:
                key = f.group(1).lower()
                if key in ("depends-on", "done-when"):
                    tickets[current][key] = f.group(2).strip()

    if not seen_todos:
        print("SKIP check=5 facet=all reason=no-todos-section")
        return
    if not tickets:
        print("SKIP check=5 facet=all reason=no-tickets")
        return

    graph = {}
    for tid in order:
        deps = []
        raw = tickets[tid]["depends-on"]
        if raw and raw.strip().lower() not in ("none", "—", "-", "n/a"):
            for dep in re.findall(r"F\d+(?:\.\d+)?-T\d+", raw.upper()):
                deps.append(dep)
                if dep not in tickets:
                    emit(5, "critical", "unknown-ticket-id", tid,
                         f"depends-on names {dep}, which is not a ticket in this PRD")
        graph[tid] = [d for d in deps if d in tickets]
        dw = tickets[tid]["done-when"]
        if not dw or dw.strip().lower() in ("none", "—", "-", "tbd", "n/a"):
            emit(5, "major", "missing-done-when", tid, "ticket has no done-when clause")

    cyc = cycle_in(graph)
    if cyc:
        emit(5, "critical", "ticket-cycle", cyc[0],
             "depends-on cycle: " + " -> ".join(cyc))


# ── check 6 — frontmatter graph + bucket coverage ─────────────────────────────

def prd_id(path):
    p = Path(path)
    parent = p.parent.name
    return parent if parent.startswith("prd-") else p.stem


def check6(fm, lines, prd_path, features_root, platforms_path):
    self_id = prd_id(prd_path)
    root = Path(features_root)

    known, graphs = {}, {}
    if root.is_dir():
        for cand in sorted(root.glob("**/prd-*/prd-*.md")):
            cid = prd_id(cand)
            if cid in known:
                continue
            known[cid] = cand
            try:
                cfm, _ = split_frontmatter(cand.read_text(encoding="utf-8").split("\n"))
            except OSError:
                cfm = None
            # v5.4 name first, v5 name as the read-tolerance fallback.
            deps = (cfm or {}).get("deps") or (cfm or {}).get("depends_on") or []
            if isinstance(deps, str):
                deps = [deps]
            graphs[cid] = [d for d in deps if d]
    else:
        print(f"SKIP check=6 facet=edge-targets reason=no-features-root")

    def edges(key):
        v = fm.get(key) or []
        return [v] if isinstance(v, str) and v else (v if isinstance(v, list) else [])

    # v5.4 dropped `affects` and renamed `depends_on` -> `deps`, so the edge set
    # is whichever of those keys the PRD actually carries. A v5-shape PRD still
    # gets both of its edge kinds checked; a v5.4 PRD has one.
    edge_keys = [k for k in ("deps", "depends_on", "affects") if k in fm]
    dep_keys = [k for k in ("deps", "depends_on") if k in fm]

    if known:
        for key in edge_keys:
            for target in edges(key):
                if target not in known:
                    emit(6, "major", "missing-edge-target", f"{key}:{target}",
                         f"frontmatter {key} names {target}, which resolves to no PRD "
                         f"under {features_root}/")

        graphs.setdefault(self_id, [])
        graphs[self_id] = [d for k in dep_keys for d in edges(k)]
        reachable = {k: [d for d in v if d in graphs] for k, v in graphs.items()}
        cyc = cycle_in(reachable)
        if cyc and self_id in cyc:
            emit(6, "critical", "frontmatter-cycle", self_id,
                 "deps cycle: " + " -> ".join(cyc))
    elif root.is_dir():
        # A6: the features root exists but the prd-*/prd-*.md glob matched
        # nothing — the edge-target and cycle facets are skipped just as they are
        # when the root is missing, so say so rather than pass silently.
        print("SKIP check=6 facet=edge-targets reason=no-prds-matched-glob")

    # Bucket coverage — the buckets pre-merge will require for each shipping platform.
    pf = Path(platforms_path)
    if not pf.is_file():
        print("SKIP check=6 facet=buckets reason=no-platforms-file")
        return

    headers, rows = md_table(pf.read_text(encoding="utf-8").split("\n"))
    plats = col(headers, rows, "platform")
    buckets = col(headers, rows, "required_buckets")
    if not plats or not buckets:
        print("SKIP check=6 facet=buckets reason=no-required-buckets-column")
        return
    table = {p.strip().strip("`").lower(): b for p, b in zip(plats, buckets)}

    declared = fm.get("platform") or []
    if isinstance(declared, str):
        declared = [t.strip() for t in re.split(r"[,/]", declared) if t.strip()]
    if not declared:
        print("SKIP check=6 facet=buckets reason=no-platform-in-frontmatter")
        return

    body = "\n".join(lines).lower()
    for plat in declared:
        row = table.get(plat.strip().strip("`").lower())
        if row is None:
            emit(6, "major", "missing-bucket-coverage", plat,
                 f"platform {plat} has no row in {platforms_path} — pre-merge cannot "
                 f"resolve its bucket set")
            continue
        want = [b.strip().strip("`") for b in re.split(r"[,\s]+", row) if b.strip()
                and b.strip() not in ("—", "-")]
        missing = [b for b in want
                   if not re.search(r"\b" + re.escape(b.lower()) + r"\b", body)]
        if missing:
            emit(6, "major", "missing-bucket-coverage", plat,
                 f"PRD never names the buckets {platforms_path} requires for {plat}: "
                 + ", ".join(missing))


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-cert-mech.py")
    ap.add_argument("prd")
    ap.add_argument("--checks", default="4,5,6")
    ap.add_argument("--platforms", default="devkit/PLATFORMS.md")
    ap.add_argument("--features-root", default="features")
    args = ap.parse_args()

    wanted = {c.strip() for c in args.checks.split(",") if c.strip()}
    unknown = wanted - {"4", "5", "6"}
    if unknown:
        die(f"unknown check(s): {','.join(sorted(unknown))} (this script owns 4, 5, 6)")
    if not wanted:
        die("--checks resolved to an empty set")

    prd = Path(args.prd)
    if not prd.is_file():
        die(f"no such PRD file: {args.prd}")
    try:
        lines = prd.read_text(encoding="utf-8").split("\n")
    except OSError as exc:
        die(f"cannot read {args.prd}: {exc}")

    fm, body_start = split_frontmatter(lines)
    if fm is None:
        die(f"no YAML frontmatter in {args.prd}")

    if "4" in wanted:
        check4(lines, body_start, args.prd)
    if "5" in wanted:
        check5(lines, body_start)
    if "6" in wanted:
        check6(fm, lines, args.prd, args.features_root, args.platforms)

    order = {"critical": 0, "major": 1}
    for check, sev, code, ref, detail in sorted(
            FINDINGS, key=lambda f: (order[f[1]], f[0], f[2], f[3])):
        print(f"FINDING check={check} sev={sev} code={code} ref={ref} detail={detail}")

    crit = sum(1 for f in FINDINGS if f[1] == "critical")
    major = len(FINDINGS) - crit
    print(f"SUMMARY checks={','.join(sorted(wanted))} findings={len(FINDINGS)} "
          f"critical={crit} major={major}")
    sys.exit(1 if FINDINGS else 0)


if __name__ == "__main__":
    main()

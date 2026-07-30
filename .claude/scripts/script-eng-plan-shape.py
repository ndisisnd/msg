#!/usr/bin/env python3
"""
script-eng-plan-shape.py — mechanical validator for an `eng --plan` pass.

`eng --plan` writes three coupled things in one pass: the `## Engineering —
<Agent>` section, the `## Todos — <Agent>` tickets that are the build spec, and
the exec-table cells that index them. Every contract between those three is
**fail-silent** if broken — a dangling ticket pointer, a cyclic `depends-on`,
or a guessed file path all produce a plausible-looking plan that only explodes
during the build wave, an expensive distance away.

This script is the assertion. Run it at the end of `eng --plan`
(`eng/refs/plan/protocol.md` § Closing check), where the fix costs one edit.
Sibling of `script-prd-shape.py` (PRD template shape) and
`script-cert-mech.py` (certification); this one owns the plan pass's own
paperwork.

Usage:
  script-eng-plan-shape.py <prd.md> [--agent <name>] [--checks 1,2,3,4,5,6,7]
                                    [--repo-root <dir>]

  --agent      validate only this agent's `## Engineering — <name>` /
               `## Todos — <name>` pair (the normal call — one agent per plan
               invocation). Omitted: every `## Todos — <name>` block found.
  --checks     comma-separated subset of 1..7. Default: all seven.
  --repo-root  root that check 7 resolves ticket file paths against.
               Default: the current working directory.

The seven checks:
  1 headings   both contract headings present byte-exact — `## Engineering —
               <Agent>` and `## Todos — <Agent>` (plan-em and eng --build
               detect readiness by grepping these literals).
  2 tickets    every ticket carries the schema in `eng/refs/plan/template-todo.md`
               — id `F<n>-T<k>`, a title, then objective / type / files /
               depends-on / done-when in that order; a legal `type`; every
               `files` path tagged `(add|edit|remove)`; a non-empty `done-when`.
  3 fids       `### F<n>` todo blocks ↔ the exec-table F-IDs this agent owns,
               aligned both ways.
  4 deps       every `depends-on` id resolves to a ticket in this PRD, and the
               dependency graph is acyclic.
  5 sentinel   a feature with no tickets carries the byte-exact
               `_No discrete work for this feature._` line, and never both.
  6 pointers   every owned exec row's Execution-steps cell is a `→ <ids>`
               pointer whose ids all resolve; every ticket is pointed at by
               some row.
  7 files      files-vs-reality: `(edit)`/`(remove)` paths must exist in the
               repo, `(add)` paths must not — this is what mechanically catches
               a guessed or stale identifier, the exact failure the
               exact-identifier rule exists to prevent.

Output (stdout, one record per line, machine-readable):
  FAIL  check=<1-7> code=<slug> ref=<locator> detail=<free text to EOL>
  SKIP  check=<n> facet=<slug> reason=<slug>
  SUMMARY checks=<list> agents=<list> failures=<n>

Failure codes:
  check 1  missing-engineering-heading · missing-todos-heading
  check 2  bad-ticket-id · missing-title · missing-field · field-out-of-order ·
           bad-type · untagged-file-path · bad-file-action · empty-done-when
  check 3  uncovered-feature · unmapped-feature
  check 4  unknown-dependency · dependency-cycle
  check 5  missing-sentinel · sentinel-with-tickets
  check 6  missing-exec-table · empty-pointer · unresolved-pointer · unpointed-ticket
  check 7  missing-path · existing-add-path

Exit codes:
  0  the plan's shape is conformant
  1  one or more FAIL lines emitted
  2  usage error, unreadable PRD, or no `## Todos — <Agent>` block to validate

Deterministic: identical input produces byte-identical output.
"""
import argparse
import re
import sys
from pathlib import Path

SELF = "script-eng-plan-shape"

FIELD_ORDER = ["objective", "type", "files", "depends-on", "done-when"]
LEGAL_TYPES = {"code", "test", "config", "migration", "doc"}
LEGAL_ACTIONS = {"add", "edit", "remove"}
SENTINEL = "_No discrete work for this feature._"

H2 = re.compile(r"^##\s+(.*?)\s*$")
H3 = re.compile(r"^###\s+(.*?)\s*$")
TICKET_RE = re.compile(r"^\s*-\s+\*\*(?P<id>[^\s—]+)\s*—\s*(?P<title>.*?)\*\*\s*(?P<rest>.*)$")
FIELD_RE = re.compile(r"^\s+-\s+\*\*(?P<key>[a-zA-Z-]+):\*\*\s*(?P<val>.*)$")
TICKET_ID_RE = re.compile(r"^F(\d+)(?:\.\d+)?-T(\d+)$")
FID_RE = re.compile(r"^F\d+(?:\.\d+)?$")
# One `path` token, with its (action) tag when the author remembered one.
PATH_TOKEN_RE = re.compile(r"`([^`]+)`(?:\s*\(([^)]*)\))?")

FAILURES = []


def fail(check, code, ref, detail):
    FAILURES.append((check, code, ref, " ".join(str(detail).split())))


def die(msg):
    print(f"{SELF}: {msg}", file=sys.stderr)
    sys.exit(2)


# ── parsing ───────────────────────────────────────────────────────────────────

def h2_blocks(lines):
    """[(raw_title, line_no_1indexed, body_lines)] for every H2 in the file."""
    idx = [i for i in range(len(lines)) if H2.match(lines[i])]
    out = []
    for k, i in enumerate(idx):
        end = idx[k + 1] if k + 1 < len(idx) else len(lines)
        out.append((H2.match(lines[i]).group(1), i + 1, lines[i + 1:end]))
    return out


def md_table(block):
    """(headers_lower, rows_with_lineoffset) for the first markdown table."""
    headers, rows = None, []
    for off, ln in enumerate(block):
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
            rows.append((cells, off))
    return headers, rows


def col_index(headers, *names):
    for n in names:
        for i, h in enumerate(headers or []):
            if h.startswith(n):
                return i
    return None


def parse_todos_block(body, lineno0):
    """One `## Todos — <Agent>` body → {fid: {"tickets": [...], "lines": [...],
    "line": n}}. Each ticket is a dict of parsed fields + provenance."""
    features, current = {}, None
    ticket = None
    for off, ln in enumerate(body):
        line_no = lineno0 + off + 1
        h3 = H3.match(ln)
        if h3:
            fid = h3.group(1).strip().upper()
            current = fid
            features.setdefault(fid, {"tickets": [], "line": line_no,
                                      "sentinel": False})
            ticket = None
            continue
        if current is None:
            continue
        # The sentinel is written as its own line or as a lone bullet; the
        # sentinel TEXT is what must be byte-exact, not the bullet marker.
        if ln.strip().lstrip("-").strip() == SENTINEL:
            features[current]["sentinel"] = True
            continue
        m = TICKET_RE.match(ln)
        if m and not FIELD_RE.match(ln):
            ticket = {"id": m.group("id").strip(),
                      "title": m.group("title").strip(),
                      "line": line_no, "fields": {}, "order": []}
            features[current]["tickets"].append(ticket)
            continue
        f = FIELD_RE.match(ln)
        if f and ticket is not None:
            key = f.group("key").lower()
            if key not in ticket["fields"]:
                ticket["order"].append(key)
            ticket["fields"][key] = f.group("val").strip()
    return features


# ── check 1 — the two contract headings ───────────────────────────────────────

def check1(blocks, agent):
    eng = [t for t, _, _ in blocks if t.startswith(f"Engineering — {agent}")]
    todos = [t for t, _, _ in blocks if t.startswith(f"Todos — {agent}")]
    if not eng:
        fail(1, "missing-engineering-heading", agent,
             f"no byte-exact '## Engineering — {agent}' heading — plan-em detects "
             f"the section by this literal")
    if not todos:
        fail(1, "missing-todos-heading", agent,
             f"no byte-exact '## Todos — {agent}' heading — eng --build locates "
             f"its spec by this literal")


# ── check 2 — ticket schema ───────────────────────────────────────────────────

def check2(features, agent):
    for fid in sorted(features):
        for t in features[fid]["tickets"]:
            ref = f"{agent}/{t['id']}"
            if not TICKET_ID_RE.match(t["id"]):
                fail(2, "bad-ticket-id", ref,
                     f"line {t['line']}: '{t['id']}' is not a well-formed F<n>-T<k> id")
            if not t["title"]:
                fail(2, "missing-title", ref, f"line {t['line']}: ticket has no title")
            present = [k for k in t["order"] if k in FIELD_ORDER]
            for key in FIELD_ORDER:
                if key not in t["fields"]:
                    fail(2, "missing-field", ref,
                         f"line {t['line']}: required field '{key}' is absent")
            if present and present != [k for k in FIELD_ORDER if k in present]:
                fail(2, "field-out-of-order", ref,
                     f"line {t['line']}: fields must appear in the order "
                     f"{' → '.join(FIELD_ORDER)}; found {' → '.join(present)}")
            typ = t["fields"].get("type", "").strip().lower()
            if typ and typ not in LEGAL_TYPES:
                fail(2, "bad-type", ref,
                     f"line {t['line']}: type '{typ}' is not one of "
                     f"{'|'.join(sorted(LEGAL_TYPES))}")
            raw_files = t["fields"].get("files", "")
            if raw_files and raw_files.strip().lower() not in ("none", "—", "-"):
                for path, action in PATH_TOKEN_RE.findall(raw_files):
                    if not action:
                        fail(2, "untagged-file-path", ref,
                             f"line {t['line']}: path `{path}` carries no "
                             f"(add|edit|remove) action tag")
                    elif action.strip().lower() not in LEGAL_ACTIONS:
                        fail(2, "bad-file-action", ref,
                             f"line {t['line']}: path `{path}` is tagged "
                             f"'({action})'; legal actions are add|edit|remove")
            dw = t["fields"].get("done-when", "")
            if not dw or dw.strip().lower() in ("none", "—", "-", "tbd", "n/a"):
                fail(2, "empty-done-when", ref,
                     f"line {t['line']}: done-when is empty or a placeholder — a "
                     f"build agent has nothing to verify against")


# ── check 3 — `### F<n>` blocks ↔ owned exec-table F-IDs ──────────────────────

def check3(features, owned_fids, agent):
    todo_fids = set(features)
    for fid in sorted(owned_fids):
        if fid not in todo_fids:
            fail(3, "uncovered-feature", f"{agent}/{fid}",
                 f"exec-table row(s) owned by {agent} carry {fid} but there is no "
                 f"'### {fid}' block under '## Todos — {agent}'")
    for fid in sorted(todo_fids):
        if fid not in owned_fids:
            fail(3, "unmapped-feature", f"{agent}/{fid}",
                 f"'### {fid}' exists under '## Todos — {agent}' but no exec-table "
                 f"row owned by {agent} carries {fid}")


# ── check 4 — dependency graph resolves and is acyclic ────────────────────────

def check4(features, all_ticket_ids, agent):
    graph, home = {}, {}
    for fid in sorted(features):
        for t in features[fid]["tickets"]:
            tid = t["id"].upper()
            home[tid] = t
            deps = []
            raw = t["fields"].get("depends-on", "")
            if raw and raw.strip().lower() not in ("none", "—", "-", "n/a", ""):
                for dep in re.findall(r"F\d+(?:\.\d+)?-T\d+", raw.upper()):
                    if dep not in all_ticket_ids:
                        fail(4, "unknown-dependency", f"{agent}/{t['id']}",
                             f"line {t['line']}: depends-on names {dep}, which is "
                             f"not a ticket in this PRD's ## Todos")
                    else:
                        deps.append(dep)
            graph[tid] = deps

    colour, stack, cycles = {}, [], []

    def visit(n):
        colour[n] = 1
        stack.append(n)
        for m in graph.get(n, []):
            if m not in graph:
                continue
            if colour.get(m) == 1:
                cycles.append(stack[stack.index(m):] + [m])
            elif colour.get(m, 0) == 0:
                visit(m)
        stack.pop()
        colour[n] = 2

    for n in sorted(graph):
        if colour.get(n, 0) == 0:
            visit(n)
    for cyc in cycles:
        fail(4, "dependency-cycle", f"{agent}/{cyc[0]}",
             "depends-on cycle: " + " -> ".join(cyc))


# ── check 5 — the empty-feature sentinel ──────────────────────────────────────

def check5(features, agent):
    for fid in sorted(features):
        f = features[fid]
        if not f["tickets"] and not f["sentinel"]:
            fail(5, "missing-sentinel", f"{agent}/{fid}",
                 f"line {f['line']}: '### {fid}' has no tickets and no byte-exact "
                 f"'{SENTINEL}' line — the #todos-{fid.lower()} anchor must stay "
                 f"resolvable")
        if f["tickets"] and f["sentinel"]:
            fail(5, "sentinel-with-tickets", f"{agent}/{fid}",
                 f"line {f['line']}: '### {fid}' carries both tickets and the "
                 f"empty-feature sentinel")


# ── check 6 — exec-table pointer cells ────────────────────────────────────────

def check6(exec_rows, features, all_ticket_ids, agent, saw_table):
    if not saw_table:
        fail(6, "missing-exec-table", "execution-table",
             "no '## N. Feature execution table' section (legacy '## Execution "
             "Table' also read) — the plan has no row to point from")
        return
    pointed = set()
    for fid, steps, owner, ref in exec_rows:
        if owner != agent:
            continue
        cell = steps.strip()
        if not cell or cell in ("—", "-"):
            fail(6, "empty-pointer", ref,
                 "Execution steps cell is empty — the row has no build spec")
            continue
        ids = re.findall(r"F\d+(?:\.\d+)?-T\d+", cell.upper())
        if not ids:
            fail(6, "empty-pointer", ref,
                 f"Execution steps cell '{cell}' carries no F<n>-T<k> ticket "
                 f"pointer (expected '→ F2-T1, F2-T2')")
            continue
        for tid in ids:
            if tid not in all_ticket_ids:
                fail(6, "unresolved-pointer", ref,
                     f"Execution steps points at {tid}, which resolves to no ticket "
                     f"under '## Todos'")
            else:
                pointed.add(tid)

    for fid in sorted(features):
        for t in features[fid]["tickets"]:
            if t["id"].upper() not in pointed:
                fail(6, "unpointed-ticket", f"{agent}/{t['id']}",
                     f"line {t['line']}: no exec-table row points at this ticket — "
                     f"it is invisible to a row-scoped build")


# ── check 7 — files vs reality ────────────────────────────────────────────────

def check7(features, repo_root, agent):
    for fid in sorted(features):
        for t in features[fid]["tickets"]:
            raw = t["fields"].get("files", "")
            for path, action in PATH_TOKEN_RE.findall(raw):
                act = action.strip().lower()
                if act not in LEGAL_ACTIONS:
                    continue                        # already a check-2 failure
                p = (repo_root / path.strip()).resolve()
                exists = p.exists()
                if act in ("edit", "remove") and not exists:
                    fail(7, "missing-path", f"{agent}/{t['id']}",
                         f"line {t['line']}: `{path}` is tagged ({act}) but does not "
                         f"exist under {repo_root} — a guessed or stale path")
                if act == "add" and exists:
                    fail(7, "existing-add-path", f"{agent}/{t['id']}",
                         f"line {t['line']}: `{path}` is tagged (add) but already "
                         f"exists under {repo_root} — it is an edit, not an add")


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-eng-plan-shape.py")
    ap.add_argument("prd")
    ap.add_argument("--agent", default=None)
    ap.add_argument("--checks", default="1,2,3,4,5,6,7")
    ap.add_argument("--repo-root", default=".")
    args = ap.parse_args()

    wanted = {c.strip() for c in args.checks.split(",") if c.strip()}
    unknown = wanted - {"1", "2", "3", "4", "5", "6", "7"}
    if unknown:
        die(f"unknown check(s): {','.join(sorted(unknown))} (this script owns 1..7)")
    if not wanted:
        die("--checks resolved to an empty set")

    prd = Path(args.prd)
    if not prd.is_file():
        die(f"no such PRD file: {args.prd}")
    try:
        lines = prd.read_text(encoding="utf-8").split("\n")
    except OSError as exc:
        die(f"cannot read {args.prd}: {exc}")

    repo_root = Path(args.repo_root).resolve()
    if "7" in wanted and not repo_root.is_dir():
        die(f"--repo-root is not a directory: {args.repo_root}")

    blocks = h2_blocks(lines)

    # Exec table — the one home, new numbered heading or the legacy title.
    exec_rows, saw_table = [], False
    for title, lineno, body in blocks:
        low = re.sub(r"^\d+\.\s*", "", title).strip().lower()
        if not low.startswith(("execution table", "feature execution table")):
            continue
        saw_table = True
        headers, rows = md_table(body)
        fi = col_index(headers, "feature")
        si = col_index(headers, "execution steps", "execution")
        ai = col_index(headers, "agent")
        if fi is None or si is None or ai is None:
            continue
        for cells, off in rows:
            if len(cells) <= max(fi, si, ai):
                continue
            feat = cells[fi]
            m = re.match(r"^\**\s*(F\d+(?:\.\d+)?)\b", feat.strip())
            fid = m.group(1).upper() if m else ""
            exec_rows.append((fid, cells[si], cells[ai].strip(),
                              f"row {lineno + off + 1}:{fid or feat[:24]}"))

    # Todo blocks, keyed by agent.
    per_agent = {}
    for title, lineno, body in blocks:
        m = re.match(r"^Todos\s+—\s+(.+?)\s*$", title)
        if m:
            per_agent[m.group(1)] = parse_todos_block(body, lineno)

    agents = [args.agent] if args.agent else sorted(per_agent)
    if not agents:
        die(f"no '## Todos — <Agent>' block in {args.prd} — nothing to validate")

    # Every ticket id in the PRD (dependencies and pointers cross agents).
    all_ticket_ids = set()
    for feats in per_agent.values():
        for fid in feats:
            for t in feats[fid]["tickets"]:
                all_ticket_ids.add(t["id"].upper())

    for agent in agents:
        features = per_agent.get(agent)
        if features is None:
            if "1" in wanted:
                check1(blocks, agent)
            else:
                die(f"no '## Todos — {agent}' block in {args.prd}")
            continue
        owned = {fid for fid, _, owner, _ in exec_rows if owner == agent and fid}
        if "1" in wanted:
            check1(blocks, agent)
        if "2" in wanted:
            check2(features, agent)
        if "3" in wanted:
            check3(features, owned, agent)
        if "4" in wanted:
            check4(features, all_ticket_ids, agent)
        if "5" in wanted:
            check5(features, agent)
        if "6" in wanted:
            check6(exec_rows, features, all_ticket_ids, agent, saw_table)
        if "7" in wanted:
            check7(features, repo_root, agent)

    for check, code, ref, detail in sorted(FAILURES, key=lambda f: (f[0], f[1], f[2])):
        print(f"FAIL check={check} code={code} ref={ref} detail={detail}")
    print(f"SUMMARY checks={','.join(sorted(wanted))} "
          f"agents={','.join(agents)} failures={len(FAILURES)}")
    sys.exit(1 if FAILURES else 0)


if __name__ == "__main__":
    main()

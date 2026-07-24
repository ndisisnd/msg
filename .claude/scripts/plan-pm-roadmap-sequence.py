#!/usr/bin/env python3
"""
plan-pm-roadmap-sequence.py — deterministic roadmap phase assignment (no LLM).

Mechanises Step 4 of plan-pm's roadmap protocol (refs/protocol-roadmap.md): it
turns the scanner's JSONL working set into a stable, byte-identical phase layout
so the LLM narrates phase names, goals, rationales and the tune log instead of
building the dependency DAG, topo-sorting it, and applying stability/intake bias
probabilistically in-context.

Usage:
  plan-pm-roadmap-sequence.py [--intake <INTAKE.md>] [--roadmap <roadmap.md>] < scan.jsonl

Input:
  plan-pm-roadmap-scan.sh JSONL on stdin — the POST-GATE working set. The protocol
  has already resolved incomplete PRDs (Step 2 completeness gate); this script
  sequences exactly what it is given. Duplicate ids: first line wins.

Model (mechanised verbatim from protocol-roadmap Step 4):
  - Phase 0 (not sequenced): every PRD whose `completion` bucket is `shipped`, plus
    every `retired` PRD (bucket `retired` or `status: retired`, listed for
    provenance). Emitted as `PHASE 0 <id> <shipped|retired>`.
  - Hard edges = `depends_on`: a PRD lands in a phase STRICTLY after all of its hard
    deps that are themselves in the sequenced set. Deps that resolve to a Phase-0 or
    an absent PRD are already-satisfied and impose no constraint (floor stays >= 1).
    Hard edges ALWAYS win a conflict.
  - Soft edges = `affects` (A affects B ⇒ prefer A before B) and intake `blocked-by`
    (blocker before blocked). Soft edges never change a phase number — they only
    order PRDs WITHIN a phase and break intra-phase ties.

Intake S: bands (only when --intake is given):
  Each INTAKE.md row's grade cell carries an `S:` band; it is mapped onto the PRD
  named in the row's `prd` cell (resolved by id, id-prefix, or prd-number). The band
  becomes a per-PRD `bias offset` added on top of the hard-dep earliest phase:
      S:now                       -> offset 0   (keep at earliest phase deps allow)
      S:next                      -> offset +1  (one phase later than earliest)
      S:later                     -> offset +2  (two phases later than earliest)
      S:blocked-by-#n             -> offset 0, plus a SOFT edge blocker->this
      S:blocked-by-prd-<n>        -> offset 0, plus a SOFT edge blocker->this
      (no row / no band)          -> offset 0
  EXACT DETERMINISTIC RULE for placement of a PRD X:
      floor(X)    = 1 + max(floor(d) for hard dep d in the sequenced set)   [deps to
                    Phase-0/absent PRDs count as 0; longest-path layering]
      desired(X)  = floor(X) + offset(X)          when X is new / no existing roadmap
                  = existing_phase(X)             when X survives an existing roadmap
      assigned(X) = max( desired(X), 1 + max(assigned(d) for hard dep d) )
  Because the bias is only ever ADDED to the earliest phase and hard edges re-impose
  `strictly after every dep` on the assigned (already-biased) phases, the S: band can
  only push a PRD later, never before a hard dep — hard edges always win. `blocked-by`
  is soft only (a hard edge only if the same id is also in `depends_on`, which the
  DAG already carries).

Stability (only when --roadmap is given):
  The existing roadmap's `## Phase <k> — <name>` headings and `- prd-<id> — …` bullets
  are parsed. Every surviving PRD (present in both roadmap and scan) is PINNED to its
  current phase (`desired = existing_phase`) and tagged `kept` — UNLESS a hard dep now
  forces it later (assigned > existing_phase), in which case it is tagged `moved-dep`
  (trigger b). A PRD in the scan but absent from the roadmap drops into the earliest
  phase its hard deps allow and is tagged `new`. A PRD in the roadmap but absent from
  the scan is emitted as a `PRUNED <id>` line (trigger a — a reshaped/split/merged PRD
  manifests here as pruned old ids alongside new child ids; trigger c, consolidation,
  is LLM judgment, not this script's). With no --roadmap every sequenced PRD is `new`.

Cycles:
  A hard-dep cycle (SCC of size > 1, or a self-dependency) is surfaced as a
  `CYCLE <id> <id> …` line. Cycle members are placed in the earliest phase that
  satisfies their NON-cycle deps (intra-cycle hard edges are ignored for layering),
  never crashing; the exit code stays 0.

Determinism:
  Total order within a phase = soft-edge precedence (a stable Kahn sort), then
  `created`, then `id`. Same stdin + same flags => byte-identical stdout. No network,
  no git, stdlib only.

Output (stdout, machine lines, in this fixed order):
  PHASE 0 <id> <shipped|retired>          per Phase-0 PRD          (sorted created,id)
  PHASE <k> <id> <kept|new|moved-dep>     per sequenced PRD, phases contiguous from 1
  CYCLE <id> <id> …                       per detected cycle
  PRUNED <id>                             per vanished PRD
Trailing on STDERR:
  summary: <K> phases, <N> prds, <S> shipped, <C> cycles
    K = sequenced phase count (excludes Phase 0); N = total PRDs read;
    S = shipped count; C = cycle count.
"""
import sys, re, json, argparse


def sort_key(rec):
    """Total order for byte-identical reruns: (created, id)."""
    return (rec.get("created", "") or "", rec.get("id", "") or "")


def prd_num(pid):
    """Leading integer after the prd- prefix, or None."""
    m = re.match(r"^prd-(\d+)", pid or "")
    return m.group(1) if m else None


def extract_prd_token(cell):
    """Pull the first prd-<n>[-slug] token out of an arbitrary cell / link."""
    if not cell:
        return None
    m = re.search(r"prd-\d+(?:\.\d+)?(?:-[A-Za-z0-9._-]+)?", cell)
    return m.group(0) if m else None


class Resolver:
    """Map a loose dep/affects/prd token onto a real scan id."""

    def __init__(self, ids):
        self.ids = set(ids)
        self.by_num = {}
        for i in sorted(ids):
            n = prd_num(i)
            if n is not None:
                self.by_num.setdefault(n, []).append(i)

    def resolve(self, token):
        tok = extract_prd_token(token) if token else None
        if not tok:
            return None
        if tok in self.ids:
            return tok
        for i in sorted(self.ids):
            if i.startswith(tok + "-"):
                return i
        n = prd_num(tok)
        if n is not None and self.by_num.get(n):
            return sorted(self.by_num[n])[0]
        return None


# --- intake --------------------------------------------------------------------

BAND_RE = re.compile(
    r"S:\s*(now|next|later|blocked-by-#\d+|blocked-by-prd-\d+)", re.IGNORECASE
)
OFFSET = {"now": 0, "next": 1, "later": 2}


def parse_intake(path):
    """Return (row_num -> prd token, prd token -> raw band string) from INTAKE.md.

    Table shape: | # | date | type | idea | goal | grade | status | prd |.
    Only the # / grade / prd columns are consumed; a missing/short row is skipped.
    """
    rows_prd = {}          # intake row number -> prd token
    band_by_prd = {}       # prd token -> band string (e.g. "now", "blocked-by-#3")
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return rows_prd, band_by_prd
    for ln in lines:
        s = ln.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if len(cells) < 8:
            continue
        num = cells[0]
        if not re.match(r"^\d+$", num):     # header / separator / non-data row
            continue
        grade, prd_cell = cells[5], cells[7]
        prd_tok = extract_prd_token(prd_cell)
        if prd_tok:
            rows_prd[num] = prd_tok
        m = BAND_RE.search(grade)
        if m and prd_tok:
            band_by_prd[prd_tok] = m.group(1).lower()
    return rows_prd, band_by_prd


# --- roadmap -------------------------------------------------------------------

PHASE_HEAD_RE = re.compile(r"^##\s*Phase\s+(\d+)\b")
BULLET_RE = re.compile(r"^-\s+(prd-\S+)")


def parse_roadmap(path):
    """Return {id_token: phase_int} for every '- prd-… ' bullet under a phase heading."""
    placed = {}
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return placed
    cur = None
    for ln in lines:
        h = PHASE_HEAD_RE.match(ln.strip())
        if h:
            cur = int(h.group(1))
            continue
        b = BULLET_RE.match(ln.strip())
        if b and cur is not None:
            placed[b.group(1)] = cur
    return placed


# --- SCC (iterative Tarjan) ----------------------------------------------------

def strongly_connected(nodes, succ):
    """Tarjan SCC over `nodes` with successor map `succ`; deterministic node order."""
    index = {}
    low = {}
    on_stack = set()
    stack = []
    comps = []
    counter = [0]
    order = sorted(nodes)

    for root in order:
        if root in index:
            continue
        work = [(root, 0)]
        while work:
            v, pi = work[-1]
            if pi == 0:
                index[v] = low[v] = counter[0]
                counter[0] += 1
                stack.append(v)
                on_stack.add(v)
            succs = succ.get(v, [])
            if pi < len(succs):
                work[-1] = (v, pi + 1)
                w = succs[pi]
                if w not in index:
                    work.append((w, 0))
                elif w in on_stack:
                    low[v] = min(low[v], index[w])
            else:
                if low[v] == index[v]:
                    comp = []
                    while True:
                        w = stack.pop()
                        on_stack.discard(w)
                        comp.append(w)
                        if w == v:
                            break
                    comps.append(comp)
                work.pop()
                if work:
                    p = work[-1][0]
                    low[p] = min(low[p], low[v])
    return comps


# --- intra-phase ordering ------------------------------------------------------

def order_phase(members, soft_pred, key_of):
    """Stable Kahn sort of `members` honouring soft edges (soft_pred[m] = befores)."""
    mset = set(members)
    indeg = {m: 0 for m in members}
    succ = {m: [] for m in members}
    for m in members:
        for p in soft_pred.get(m, ()):  # p must come before m
            if p in mset:
                indeg[m] += 1
                succ[p].append(m)
    remaining = set(members)
    out = []
    while remaining:
        ready = sorted((m for m in remaining if indeg[m] == 0), key=key_of)
        if not ready:
            # soft cycle: force the smallest remaining to unblock, deterministically
            ready = [sorted(remaining, key=key_of)[0]]
        m = ready[0]
        out.append(m)
        remaining.discard(m)
        indeg[m] = -1
        for s in succ[m]:
            if indeg[s] > 0:
                indeg[s] -= 1
    return out


# --- main ----------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--intake")
    ap.add_argument("--roadmap")
    a = ap.parse_args()

    records = []
    seen = set()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            print(f"plan-pm-roadmap-sequence: skipping unparseable line", file=sys.stderr)
            continue
        pid = rec.get("id", "")
        if not pid or pid in seen:
            continue
        seen.add(pid)
        records.append(rec)

    by_id = {r["id"]: r for r in records}
    resolver = Resolver(by_id.keys())

    # --- Phase 0 partition ----------------------------------------------------
    phase0 = []   # (rec, tag)
    seq = []
    for r in records:
        comp = (r.get("completion") or "").lower()
        status = (r.get("status") or "").lower()
        if comp == "shipped":
            phase0.append((r, "shipped"))
        elif comp == "retired" or status == "retired":
            phase0.append((r, "retired"))
        else:
            seq.append(r)

    seq_ids = {r["id"] for r in seq}

    # --- hard-edge graph over the sequenced set -------------------------------
    hard = {}   # v -> list of seq-set dep ids (u before v), self kept for cycle
    for r in seq:
        deps = []
        for d in r.get("depends_on") or []:
            rid = resolver.resolve(d)
            if rid in seq_ids:
                deps.append(rid)
        hard[r["id"]] = sorted(set(deps))

    succ = {v: [] for v in seq_ids}   # u -> [v]  (u before v)
    for v, deps in hard.items():
        for u in deps:
            succ[u].append(v)
    for u in succ:
        succ[u].sort()

    # --- cycles ---------------------------------------------------------------
    comps = strongly_connected(seq_ids, succ)
    comp_of = {}
    cyclic = set()   # ids that belong to a cycle
    cycles = []      # list of member-id lists
    for comp in comps:
        cid = min(comp)
        for m in comp:
            comp_of[m] = cid
        self_loop = len(comp) == 1 and comp[0] in hard.get(comp[0], [])
        if len(comp) > 1 or self_loop:
            for m in comp:
                cyclic.add(m)
            cycles.append(sorted(comp, key=lambda i: sort_key(by_id[i])))

    def eff_deps(v):
        """Hard deps of v used for layering: drop self and intra-cycle edges."""
        out = []
        for u in hard.get(v, []):
            if u == v:
                continue
            if u in cyclic and v in cyclic and comp_of.get(u) == comp_of.get(v):
                continue
            out.append(u)
        return out

    # --- deterministic topo order over the layering DAG -----------------------
    eff = {v: eff_deps(v) for v in seq_ids}
    indeg = {v: 0 for v in seq_ids}
    esucc = {v: [] for v in seq_ids}
    for v, deps in eff.items():
        for u in deps:
            indeg[v] += 1
            esucc[u].append(v)
    topo = []
    remaining = set(seq_ids)
    while remaining:
        ready = sorted((v for v in remaining if indeg[v] == 0),
                       key=lambda i: sort_key(by_id[i]))
        if not ready:   # residual (should not happen post cycle-break) — force one
            ready = [sorted(remaining, key=lambda i: sort_key(by_id[i]))[0]]
        v = ready[0]
        topo.append(v)
        remaining.discard(v)
        indeg[v] = -1
        for s in sorted(esucc[v]):
            if indeg[s] > 0:
                indeg[s] -= 1

    # --- floor (pure hard-dep earliest) ---------------------------------------
    floor = {}
    for v in topo:
        floor[v] = 1 + max((floor[u] for u in eff[v]), default=0)

    # --- intake bias + blocked-by soft edges ----------------------------------
    offset = {v: 0 for v in seq_ids}
    soft_pred = {v: set() for v in seq_ids}
    # affects soft edges: A affects B => A before B
    for r in seq:
        for aff in r.get("affects") or []:
            b = resolver.resolve(aff)
            if b in seq_ids and b != r["id"]:
                soft_pred[b].add(r["id"])
    if a.intake:
        rows_prd, band_by_prd = parse_intake(a.intake)
        # band tokens are keyed by the intake prd token; map onto seq ids
        for prd_tok, band in band_by_prd.items():
            target = resolver.resolve(prd_tok)
            if target not in seq_ids:
                continue
            if band in OFFSET:
                offset[target] = OFFSET[band]
            elif band.startswith("blocked-by-#"):
                row = band[len("blocked-by-#"):]
                blocker = resolver.resolve(rows_prd.get(row))
                if blocker in seq_ids and blocker != target:
                    soft_pred[target].add(blocker)
            elif band.startswith("blocked-by-prd-"):
                blocker = resolver.resolve("prd-" + band[len("blocked-by-prd-"):])
                if blocker in seq_ids and blocker != target:
                    soft_pred[target].add(blocker)

    # --- existing-roadmap stability -------------------------------------------
    existing = {}
    roadmap_ids = set()
    if a.roadmap:
        placed = parse_roadmap(a.roadmap)
        roadmap_ids = set(placed.keys())
        for tok, ph in placed.items():
            rid = resolver.resolve(tok)
            if rid in seq_ids and ph >= 1:
                existing[rid] = ph

    # --- assign phases (topo order; hard edges always win) --------------------
    assigned = {}
    tag = {}
    for v in topo:
        if a.roadmap and v in existing:
            desired = existing[v]
        else:
            desired = floor[v] + offset[v]
        hardmin = 1 + max((assigned[u] for u in eff[v]), default=0)
        assigned[v] = max(desired, hardmin)
        if a.roadmap:
            if v in existing:
                tag[v] = "moved-dep" if assigned[v] > existing[v] else "kept"
            else:
                tag[v] = "new"
        else:
            tag[v] = "new"

    # --- compress to contiguous phase numbers from 1 --------------------------
    used = sorted(set(assigned.values()))
    remap = {old: new for new, old in enumerate(used, start=1)}
    for v in assigned:
        assigned[v] = remap[assigned[v]]

    # --- emit -----------------------------------------------------------------
    out = []
    for r, t in sorted(phase0, key=lambda rt: sort_key(rt[0])):
        out.append(f"PHASE 0 {r['id']} {t}")

    K = len(used)
    for k in range(1, K + 1):
        members = [v for v in seq_ids if assigned[v] == k]
        for v in order_phase(members, soft_pred, lambda i: sort_key(by_id[i])):
            out.append(f"PHASE {k} {v} {tag[v]}")

    for cyc in sorted(cycles, key=lambda c: sort_key(by_id[c[0]])):
        out.append("CYCLE " + " ".join(cyc))

    pruned = sorted(t for t in roadmap_ids if resolver.resolve(t) not in by_id)
    for p in pruned:
        out.append(f"PRUNED {p}")

    sys.stdout.write("\n".join(out))
    if out:
        sys.stdout.write("\n")

    shipped = sum(1 for _, t in phase0 if t == "shipped")
    print(f"summary: {K} phases, {len(records)} prds, {shipped} shipped, "
          f"{len(cycles)} cycles", file=sys.stderr)


if __name__ == "__main__":
    main()

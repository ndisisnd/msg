#!/usr/bin/env python3
"""
script-em-exec-collision.sh — mechanical collision / parallel-safety check for an
Execution Table.

Reads an exec-table markdown (from a file arg or stdin), extracts each row's
**Files** set, and computes pairwise intersections. Two rows are unsafe to run
in parallel iff their Files sets overlap.

With `--waves` it goes one step further: it turns that overlap relation into a
wave decomposition — packets (rows that must run serially) and waves (packets
that may run concurrently) — so callers consume the schedule instead of
re-deriving the graph by hand.

Usage:
  script-em-exec-collision.sh [--waves] <exec-table.md>
  cat exec-table.md | script-em-exec-collision.sh [--waves]
  script-em-exec-collision.sh <exec-table.md> --waves   # flag before or after the path

Output (stdout, machine-readable lines are prefixed):
  COLLISION row<N> row<M> <shared paths...>   one per colliding pair
  MISSING_FILES row<N> <feature>              one per owned row with empty Files
  plus a human-readable summary.

With --waves, after the lines above, emits the wave decomposition:
  PACKET <p> agent=<agent> rows=<n,...>   rows partitioned first by the Agent
                                          column (packets never mix agents), then
                                          into connected components over shared-file
                                          edges within each agent group; row ids are
                                          1-based ascending; packets numbered in
                                          first-row order.
  UNPACKETED rows=<ids>                   rows with empty Files, excluded from
                                          packets (MISSING_FILES already reports
                                          them per-row); single line, emitted only
                                          when such rows exist.
  WAVE <w> packets=<p,...>                greedy first-fit layering in packet-id
                                          order: a packet joins the earliest wave
                                          where it is file-disjoint from every packet
                                          already in that wave — checked across
                                          agents, so cross-agent file sharing splits
                                          into different waves.

Exit code:
  Without --waves (the existing contract, preserved for existing callers):
    1  if any collision was found
    0  if no collisions (EMPTY Files cells degrade gracefully — reported per row
       as MISSING_FILES, never a crash)
  With --waves:
    0  ALWAYS — a collision is a serialization constraint expressed by the packets
       (colliding rows share a packet and run serially), not an error. Callers that
       rely on the exit-1-on-collision signal must NOT pass --waves.
    2  genuine parse error (no markdown table found), same as the no-flag mode.
  Both modes:
    3  the table has NO Files column at all (A21). Distinct from 0 because every
       row's Files set would be empty and the run would report zero collisions —
       "not checked" must not read as "safe to parallelise". Nothing is emitted
       on stdout; stderr carries `ERROR=no-files-column` and the headers seen.

Deterministic: identical input → byte-identical output. A missing Agent column
puts every row in one empty-string agent group (no crash).

Row ids are 1-based over the data rows of the first markdown table found.
"""
import sys, re


def norm(cell):
    """A Files cell -> ordered de-duped list of repo-relative paths."""
    cell = cell.replace("<br>", " ").replace("<br/>", " ").replace("<br />", " ")
    cell = cell.replace("`", " ")
    parts = [p.strip() for p in re.split(r"[,\s]+", cell) if p.strip()]
    seen, out = set(), []
    for p in parts:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


def parse_table(text):
    """Return (headers[list], rows[list[list_cells]]) for the first md table."""
    headers, rows = None, []
    for ln in text.splitlines():
        s = ln.strip()
        if not s.startswith("|"):
            if headers is not None:
                break  # table ended
            continue
        bare = s.strip("|")
        if re.match(r"^[\s:|-]+$", bare):  # separator row
            continue
        cells = [c.strip() for c in bare.split("|")]
        if headers is None:
            headers = cells
        else:
            rows.append(cells)
    return headers, rows


def col_index(headers, *names):
    for i, h in enumerate(headers or []):
        if h.strip().lower() in names:
            return i
    return -1


def components(ids, filesmap):
    """Connected components over shared-file edges among `ids` (ascending).
    Returns each component as a sorted row-id list; components ordered by their
    smallest row id. Deterministic (union-find, min-root)."""
    parent = {i: i for i in ids}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    for i in range(len(ids)):
        for j in range(i + 1, len(ids)):
            a, b = ids[i], ids[j]
            if filesmap[a] & filesmap[b]:
                union(a, b)

    groups = {}
    for i in ids:
        groups.setdefault(find(i), []).append(i)
    comps = [sorted(v) for v in groups.values()]
    comps.sort(key=lambda c: c[0])
    return comps


def emit_waves(rowfiles, rowagent):
    """Emit PACKET / UNPACKETED / WAVE lines for the --waves mode."""
    filesmap = {n: set(files) for (n, feat, files) in rowfiles}

    # Rows with Files, grouped by Agent (packets never mix agents), preserving
    # first-appearance order of the agents.
    agent_order, agent_rows = [], {}
    for (n, feat, files) in rowfiles:
        if not files:
            continue
        ag = rowagent.get(n, "")
        if ag not in agent_rows:
            agent_rows[ag] = []
            agent_order.append(ag)
        agent_rows[ag].append(n)

    # Build packets: (agent, [rows], fileset) — connected components per agent.
    packets = []
    for ag in agent_order:
        for comp in components(agent_rows[ag], filesmap):
            fs = set()
            for r in comp:
                fs |= filesmap[r]
            packets.append((ag, comp, fs))
    # Number packets in first-row order (global, so interleaved agents order right).
    packets.sort(key=lambda p: p[1][0])

    for pid, (ag, comp, fs) in enumerate(packets, start=1):
        print(f"PACKET {pid} agent={ag} rows={','.join(str(r) for r in comp)}")

    # Rows with empty Files are excluded from packets (MISSING_FILES reports them).
    unpacketed = sorted(n for (n, feat, files) in rowfiles if not files)
    if unpacketed:
        print(f"UNPACKETED rows={','.join(str(r) for r in unpacketed)}")

    # Waves: greedy first-fit in packet-id order — a packet joins the earliest
    # wave file-disjoint from every packet already there (checked across agents).
    waves = []  # each: [ [packet ids], accumulated fileset ]
    for pid, (ag, comp, fs) in enumerate(packets, start=1):
        placed = False
        for w in waves:
            if not (w[1] & fs):
                w[0].append(pid)
                w[1] |= fs
                placed = True
                break
        if not placed:
            waves.append([[pid], set(fs)])

    for wid, w in enumerate(waves, start=1):
        print(f"WAVE {wid} packets={','.join(str(p) for p in w[0])}")


def main():
    # Flag position is flexible (before or after the path); stdin `-` still works.
    waves = False
    path = None
    for a in sys.argv[1:]:
        if a == "--waves":
            waves = True
        elif path is None:
            path = a
        # extra positional args are ignored (first path wins)

    if path is not None and path not in ("-", "/dev/stdin"):
        with open(path, encoding="utf-8") as f:
            text = f.read()
    else:
        text = sys.stdin.read()

    headers, rows = parse_table(text)
    if headers is None:
        print("error: no markdown table found", file=sys.stderr)
        sys.exit(2)

    fi = col_index(headers, "files", "file")
    feati = col_index(headers, "feature")
    ai = col_index(headers, "agent")

    # A21: a table with no Files column cannot answer the question this script
    # exists to answer — every row's Files set is empty, so zero collisions are
    # found and the old exit 0 read exactly like "safe to run in parallel". The
    # stderr WARNING was invisible to `script-cert-mech.py`, which captures the
    # streams separately and only inspected stdout. Distinct exit 3 instead:
    # callers can now tell "no collisions" from "not checked".
    if fi == -1:
        print("ERROR=no-files-column", file=sys.stderr)
        print("%s: the table has no `Files` column (headers seen: %s) — every "
              "row's Files set would be empty, so a zero-collision result "
              "would be meaningless; populate the Files column before the "
              "build wave" % ("script-em-exec-collision",
                              ", ".join(headers) or "(none)"), file=sys.stderr)
        sys.exit(3)

    def cell(row, idx):
        return row[idx] if 0 <= idx < len(row) else ""

    rowfiles = []  # (rowno, feature, set(files))
    rowagent = {}  # rowno -> Agent-column value ("" if no Agent column)
    for n, r in enumerate(rows, start=1):
        feat = cell(r, feati) or f"row{n}"
        files = norm(cell(r, fi)) if fi != -1 else []
        rowfiles.append((n, feat, files))
        rowagent[n] = cell(r, ai)

    # lint: rows with no Files
    missing = [(n, feat) for (n, feat, files) in rowfiles if not files]
    for n, feat in missing:
        print(f"MISSING_FILES row{n} {feat}")

    # pairwise intersections
    collisions = 0
    for a in range(len(rowfiles)):
        na, fa, sa = rowfiles[a]
        if not sa:
            continue
        for b in range(a + 1, len(rowfiles)):
            nb, fb, sb = rowfiles[b]
            if not sb:
                continue
            shared = [p for p in sa if p in set(sb)]
            if shared:
                collisions += 1
                print(f"COLLISION row{na} row{nb} " + " ".join(shared))
                print(f"  collision: row{na} ({fa}) <-> row{nb} ({fb}) "
                      f"share: {', '.join(shared)}", file=sys.stderr)

    total = len(rowfiles)
    print(f"summary: {total} rows, {len(missing)} with empty Files, "
          f"{collisions} colliding pair(s)", file=sys.stderr)

    if waves:
        # A collision is a serialization constraint carried by the packets, not
        # an error — always exit 0 (parse errors already exited 2 above).
        emit_waves(rowfiles, rowagent)
        sys.exit(0)

    sys.exit(1 if collisions else 0)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
plan-em-exec-collision.sh — mechanical collision / parallel-safety check for an
Execution Table.

Reads an exec-table markdown (from a file arg or stdin), extracts each row's
**Files** set, and computes pairwise intersections. Two rows are unsafe to run
in parallel iff their Files sets overlap.

Usage:
  plan-em-exec-collision.sh <exec-table.md>
  cat exec-table.md | plan-em-exec-collision.sh

Output (stdout, machine-readable lines are prefixed):
  COLLISION row<N> row<M> <shared paths...>   one per colliding pair
  MISSING_FILES row<N> <feature>              one per owned row with empty Files
  plus a human-readable summary.

Exit code:
  1  if any collision was found
  0  if no collisions (missing/empty Files degrades gracefully — reported, never a crash)

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


def main():
    if len(sys.argv) > 1 and sys.argv[1] not in ("-", "/dev/stdin"):
        with open(sys.argv[1], encoding="utf-8") as f:
            text = f.read()
    else:
        text = sys.stdin.read()

    headers, rows = parse_table(text)
    if headers is None:
        print("error: no markdown table found", file=sys.stderr)
        sys.exit(2)

    fi = col_index(headers, "files", "file")
    feati = col_index(headers, "feature")

    if fi == -1:
        print("WARNING: no Files column — treating every row's Files as empty "
              "(legacy table, degrading gracefully)", file=sys.stderr)

    def cell(row, idx):
        return row[idx] if 0 <= idx < len(row) else ""

    rowfiles = []  # (rowno, feature, set(files))
    for n, r in enumerate(rows, start=1):
        feat = cell(r, feati) or f"row{n}"
        files = norm(cell(r, fi)) if fi != -1 else []
        rowfiles.append((n, feat, files))

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
    sys.exit(1 if collisions else 0)


if __name__ == "__main__":
    main()

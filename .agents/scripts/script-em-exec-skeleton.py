#!/usr/bin/env python3
"""
script-em-exec-skeleton.py — deterministic exec-table skeleton renderer (no LLM).

Given a msg PRD and an assignment spec on stdin, resolves each F-ID against the
PRD's §3 Features & acceptance criteria table and renders the complete execution
table skeleton markdown for the PRD's §6 Feature execution table (Step 3). The
LLM still decides the (feature, concern, agent) tuples and hands them in as the
spec; this script only renders them, so anchor typos and row-text drift are
impossible. See template-exec-table.md and template-prd.md §3/§6 for the shapes
consumed/produced.

Two modes.

RENDER (default) — build the skeleton from an assignment spec:
  echo '[{"fid":"F1","concern":"API contract","agent":"backend-eng"}]' \\
    | script-em-exec-skeleton.py [--write] [--force] <prd.md>

  --write   write the table into the PRD's reserved "## N. Feature execution
            table" section in place (the exec table's ONE home), replacing the
            "_To be populated by plan-em …_" placeholder and any blank skeleton
            table already there. Without it the table only goes to stdout.

  --force   allow --write to overwrite an exec table that already holds work.
            Without it, --write refuses (exit 1, REFUSING_OVERWRITE=<n>) when the
            section's table has any populated "Files" cell (or, on a legacy
            table, "Execution steps"), or holds a table whose header resolves
            neither column (then the key is REFUSING_OVERWRITE=unresolved-columns).
            A genuinely blank skeleton (or the placeholder) is replaced as before.

  Stdin: a JSON array of {"fid","concern","agent"} objects, in row order.
  Stdout: the skeleton table — header + separator + one row per spec entry:
    | Feature — concern | Files | Agent |
    Feature cell = "<fid>: <name> — <concern>"; Files blank (see --fill-files);
    Agent = the spec agent.
    With --write, stdout carries "WROTE <prd> section=<heading> rows=<n>".

FILL-FILES (v5.4) — derive every row's Files cell from the tickets:
  script-em-exec-skeleton.py --fill-files [--agent <name>] <prd.md>

  The Files column is no longer typed by a planner agent. This mode reads the
  PRD's `## Todos — <Agent>` blocks, and for each exec-table row unions the
  `files` paths of every ticket under that row's F-ID in that row's agent's
  block, then writes the result into the row's Files cell in place. Rows sharing
  an (F-ID, agent) pair therefore share a Files set — deliberately: the collision
  graph is a file-disjointness question, and a per-concern split of one feature's
  files would claim a disjointness the build does not actually have.

  --agent   fill only rows whose Agent cell matches; other rows are left byte-
            identical. Omitted: every row.

  Stdout, one record per line:
    FILLED <prd> rows=<n> paths=<m>          on success
    EMPTY_FILES row=<n> fid=<F> agent=<a>    row resolved to an empty ticket
                                             file set (the empty-feature
                                             sentinel) — informational, the cell
                                             is left blank, exit stays 0
    MISSING_TICKETS row=<n> fid=<F> agent=<a>  no `### F<n>` block under
                                             `## Todos — <a>` — hard failure
    NO_FILES_COLUMN                          the table has no Files column

Exit codes:
  0 = table rendered / written / filled.
  1 = a spec fid is absent from §3; --write found no reserved "Feature execution
      table" section; --write would overwrite a populated exec table without
      --force; or --fill-files hit a missing ticket block or no Files column
      (named on stderr; nothing written in every case).
  2 = malformed JSON on stdin / usage / unreadable or unwritable PRD.

Every write goes through a temp file + os.replace, so a crash can never truncate
the PRD (same discipline as script-eng-close-loop.py / script-ledger.py).
"""
import sys, re, json, os, tempfile

HEADER = "| Feature — concern | Files | Agent |"
SEP    = "|-------------------|-------|-------|"


def die(msg, code):
    sys.stderr.write("script-em-exec-skeleton: %s\n" % msg)
    sys.exit(code)


def read_lines(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read().splitlines()
    except OSError as e:
        die("cannot read PRD: %s" % e, 2)


def parse_features(lines):
    """Return {ID_UPPER: (canonical_ID, feature_name)} from the PRD §3 table."""
    # Locate the §3 "Features & acceptance criteria" heading (number-agnostic).
    start = None
    hdr = re.compile(r"^##\s+.*features\s*&\s*acceptance", re.I)
    for i, ln in enumerate(lines):
        if hdr.match(ln):
            start = i + 1
            break
    if start is None:
        return {}

    # Gather until the next level-2 heading.
    block = []
    for ln in lines[start:]:
        if re.match(r"^##\s+", ln):
            break
        block.append(ln)

    # Parse the first markdown table in the block.
    headers, rows = None, []
    for ln in block:
        s = ln.strip()
        if not s.startswith("|"):
            if headers is not None:
                break          # table ended
            continue
        if re.match(r"^[\s:|-]+$", s.replace("|", "")):
            continue           # separator row
        cells = [c.strip() for c in s.strip("|").split("|")]
        if headers is None:
            headers = [c.lower() for c in cells]
        else:
            rows.append(cells)
    if headers is None:
        return {}

    def col(*names):
        for idx, h in enumerate(headers):
            if h in names:
                return idx
        return None

    id_col, feat_col = col("id", "f-id"), col("feature")
    if id_col is None or feat_col is None:
        return {}

    out = {}
    for cells in rows:
        if len(cells) <= max(id_col, feat_col):
            continue
        fid = cells[id_col].strip()
        name = cells[feat_col].strip()
        if fid:
            out[fid.upper()] = (fid, name)
    return out


# Heading of the exec table's ONE home. Number-agnostic, and tolerant of the
# legacy unnumbered "## Execution Table" so a pre-v5 PRD can still be rewritten.
EXEC_HDR = re.compile(r"^##\s+(?:\d+\.\s*)?(?:Feature execution table|Execution Table)\s*$",
                      re.I)
PLACEHOLDER = re.compile(r"^_To be populated by plan-em\b.*_$", re.I)


def scan_existing_table(body):
    """Inspect the table already sitting in the exec-table section.

    Returns (has_table, resolved, populated):
      has_table  a markdown table was found in the section body
      resolved   its header resolved AT LEAST ONE of Execution steps / Files
                 (a pre-v5 table carries Feature/Execution steps/Agent only)
      populated  number of data rows with a non-blank cell in a resolved column

    A blank skeleton (header + separator, no rows) and the bare placeholder both
    come back populated=0 — those are the only shapes --write may replace.
    """
    headers, cols, populated, has_table = None, [], 0, False
    for ln in body:
        s = ln.strip()
        if not s.startswith("|"):
            continue
        if re.match(r"^[\s:|-]+$", s.replace("|", "")):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if headers is None:
            has_table = True
            headers = [c.lower() for c in cells]
            # Containing-match, so "Execution steps (phase)" still resolves.
            for want in ("execution", "file"):
                for idx, h in enumerate(headers):
                    if want in h:
                        cols.append(idx)
                        break
            continue
        if any(i < len(cells) and cells[i] for i in cols):
            populated += 1
    return has_table, bool(cols), populated


def write_section(prd, lines, rows, force=False):
    """Replace the reserved exec-table section's body with the rendered table."""
    start = None
    for i, ln in enumerate(lines):
        if EXEC_HDR.match(ln):
            start = i
            break
    if start is None:
        die("no '## N. Feature execution table' section in %s — the exec table has one "
            "home and it is missing; restore it from template-prd.md" % prd, 1)

    end = len(lines)
    for j in range(start + 1, len(lines)):
        if re.match(r"^##\s+", lines[j]):
            end = j
            break

    # Refuse to wipe an exec table that already holds work. The keep-filter below
    # drops every `|` line, so without this guard a second --write pass silently
    # destroys populated Execution-steps/Files cells (A8).
    if not force:
        has_table, resolved, populated = scan_existing_table(lines[start + 1:end])
        if has_table and not resolved:
            sys.stdout.write("REFUSING_OVERWRITE=unresolved-columns\n")
            die("the '%s' section in %s holds a table whose header resolves neither "
                "'Execution steps' nor 'Files' — refusing to overwrite an unreadable "
                "table; fix the header or re-run with --force"
                % (lines[start].lstrip("# ").strip(), prd), 1)
        if populated:
            sys.stdout.write("REFUSING_OVERWRITE=%d\n" % populated)
            die("the '%s' section in %s already has %d row(s) with populated "
                "Execution steps/Files — refusing to overwrite engineering work; "
                "re-run with --force to replace it anyway"
                % (lines[start].lstrip("# ").strip(), prd, populated), 1)

    kept = []
    for ln in lines[start + 1:end]:
        s = ln.strip()
        if not s:
            continue
        if PLACEHOLDER.match(s) or s.startswith("|") or s.startswith("```"):
            continue          # old placeholder / blank skeleton / fence
        kept.append(ln.rstrip())

    body = kept + ([""] if kept else []) + [HEADER, SEP] + rows
    new = lines[:start + 1] + [""] + body + [""] + lines[end:]
    atomic_write(prd, new)          # A8b — never leave a truncated PRD
    sys.stdout.write("WROTE %s section=%s rows=%d\n"
                     % (prd, lines[start].lstrip("# ").strip(), len(rows)))


# ── --fill-files (v5.4): the Files column is derived, never typed ─────────────

# `src/api/goals.ts` (edit)  ->  src/api/goals.ts
TICKET_PATH_RE = re.compile(r"`([^`]+)`")
FID_HEAD_RE = re.compile(r"^\**\s*(F\d+(?:\.\d+)?)\b")


def parse_todos(lines):
    """{agent: {FID: [paths in ticket order, de-duped]}} from every
    `## Todos — <Agent>` block. A block present with no ticket `files` (the
    empty-feature sentinel) yields an empty list — which is a real answer,
    distinct from the F-ID being absent entirely."""
    out, agent, fid = {}, None, None
    for ln in lines:
        h2 = re.match(r"^##\s+Todos\s+—\s+(.+?)\s*$", ln)
        if h2:
            agent = h2.group(1).strip()
            out.setdefault(agent, {})
            fid = None
            continue
        if re.match(r"^##\s+", ln):
            agent, fid = None, None
            continue
        if agent is None:
            continue
        h3 = re.match(r"^###\s+(.+?)\s*$", ln)
        if h3:
            m = FID_HEAD_RE.match(h3.group(1))
            fid = m.group(1).upper() if m else None
            if fid:
                out[agent].setdefault(fid, [])
            continue
        if fid is None:
            continue
        f = re.match(r"^\s+-\s+\*\*files:\*\*\s*(.*)$", ln, re.I)
        if f:
            for path in TICKET_PATH_RE.findall(f.group(1)):
                p = path.strip()
                if p and p not in out[agent][fid]:
                    out[agent][fid].append(p)
    return out


def fill_files(prd, lines, only_agent=None):
    """Rewrite every exec-table row's Files cell as the union of its tickets'
    `files` paths. Planner agents no longer fill this cell by hand — the two
    could disagree, and the collision graph is only as true as this column."""
    start = None
    for i, ln in enumerate(lines):
        if EXEC_HDR.match(ln):
            start = i
            break
    if start is None:
        die("no '## N. Feature execution table' section in %s — nothing to fill" % prd, 1)
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if re.match(r"^##\s+", lines[j]):
            end = j
            break

    todos = parse_todos(lines)

    headers, hdr_line = None, None
    fi = ii = ai = None
    out = list(lines)
    filled, total_paths, missing, empties = 0, 0, [], []
    rowno = 0                      # 1-based over data rows, matching the collision
                                   # checker's row ids so the two can be cross-read

    for i in range(start + 1, end):
        s = lines[i].strip()
        if not s.startswith("|"):
            continue
        if re.match(r"^[\s:|-]+$", s.replace("|", "")):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if headers is None:
            headers, hdr_line = [c.lower() for c in cells], i
            for idx, h in enumerate(headers):
                if fi is None and h.startswith("feature"):
                    fi = idx
                if ii is None and "file" in h:
                    ii = idx
                if ai is None and h.startswith("agent"):
                    ai = idx
            if ii is None:
                sys.stdout.write("NO_FILES_COLUMN\n")
                die("the exec table in %s has no Files column (headers seen: %s) — "
                    "restore it from template-exec-table.md" % (prd, ", ".join(headers)), 1)
            if fi is None or ai is None:
                die("the exec table in %s resolves no Feature and/or Agent column "
                    "(headers seen: %s)" % (prd, ", ".join(headers)), 1)
            continue

        rowno += 1
        if len(cells) <= max(fi, ii, ai):
            continue                    # short row — plan-shape check 6 owns it
        agent = cells[ai]
        if only_agent is not None and agent != only_agent:
            continue
        m = FID_HEAD_RE.match(cells[fi])
        fid = m.group(1).upper() if m else ""
        paths = todos.get(agent, {}).get(fid)
        if paths is None:
            missing.append((rowno, fid or cells[fi][:24], agent))
            continue
        if not paths:
            empties.append((rowno, fid, agent))
        cells[ii] = ", ".join(paths)
        out[i] = "| " + " | ".join(cells) + " |"
        filled += 1
        total_paths += len(paths)

    for rowno, fid, agent in missing:
        sys.stdout.write("MISSING_TICKETS row=%d fid=%s agent=%s\n" % (rowno, fid, agent))
    if missing:
        die("%d exec-table row(s) name an F-ID with no '### F<n>' block under their "
            "agent's '## Todos — <Agent>' section — the plan pass is incomplete; "
            "nothing written" % len(missing), 1)
    for rowno, fid, agent in empties:
        sys.stdout.write("EMPTY_FILES row=%d fid=%s agent=%s\n" % (rowno, fid, agent))

    atomic_write(prd, out)
    sys.stdout.write("FILLED %s rows=%d paths=%d\n" % (prd, filled, total_paths))


def atomic_write(prd, newlines):
    """Temp file + os.replace: a crash mid-write can never leave a truncated PRD."""
    directory = os.path.dirname(os.path.abspath(prd)) or "."
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".exec-skeleton.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write("\n".join(newlines).rstrip("\n") + "\n")
        try:
            os.chmod(tmp, os.stat(prd).st_mode & 0o777)
        except OSError:
            pass
        os.replace(tmp, prd)
    except OSError as e:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        die("cannot write PRD: %s" % e, 2)


def main():
    argv = sys.argv[1:]
    write = "--write" in argv
    force = "--force" in argv
    fill = "--fill-files" in argv
    only_agent = None
    if "--agent" in argv:
        k = argv.index("--agent")
        if k + 1 >= len(argv):
            die("--agent needs a value", 2)
        only_agent = argv[k + 1]
        argv = argv[:k] + argv[k + 2:]
    argv = [a for a in argv if a not in ("--write", "--force", "--fill-files")]
    if len(argv) != 1:
        die("usage: script-em-exec-skeleton.py [--write] [--force] <prd.md>\n"
            "       script-em-exec-skeleton.py --fill-files [--agent <name>] <prd.md>", 2)
    prd = argv[0]

    if fill:
        if write or force:
            die("--fill-files is its own mode — do not combine it with --write/--force", 2)
        fill_files(prd, read_lines(prd), only_agent)
        return
    if only_agent is not None:
        die("--agent applies to --fill-files only", 2)

    try:
        spec = json.loads(sys.stdin.read())
    except json.JSONDecodeError as e:
        die("malformed JSON on stdin: %s" % e, 2)
    if not isinstance(spec, list):
        die("spec must be a JSON array", 2)

    lines = read_lines(prd)
    feats = parse_features(lines)

    rows = []
    for entry in spec:
        if not isinstance(entry, dict):
            die("each spec entry must be a JSON object", 2)
        fid = str(entry.get("fid", "")).strip()
        concern = str(entry.get("concern", "")).strip()
        agent = str(entry.get("agent", "")).strip()
        if not fid:
            die("spec entry missing 'fid'", 2)
        rec = feats.get(fid.upper())
        if rec is None:
            die("fid '%s' not present in §3 Features & acceptance criteria table" % fid, 1)
        canon, name = rec
        rows.append("| %s: %s — %s | | %s |" % (canon, name, concern, agent))

    if write:
        write_section(prd, lines, rows, force=force)
    else:
        sys.stdout.write("\n".join([HEADER, SEP] + rows) + "\n")


if __name__ == "__main__":
    main()

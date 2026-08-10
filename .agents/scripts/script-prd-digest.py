#!/usr/bin/env python3
"""
script-prd-digest.py — deterministic PRD -> compact digest (no LLM).

Splits a msg PRD on its standardized headings and emits a JSON digest that
downstream stages consume instead of re-parsing the full prose. Contractual
fields (F-IDs, acceptance criteria, integration contracts, glossary, exec rows)
are copied VERBATIM; narrative prose is dropped but every section keeps a
`prose_lines` pointer for on-demand access. See shared/refs/session-cache.md.

Usage:
  script-prd-digest.py <prd.md> [--out <path>] [--stdout] [--force]

Behaviour:
  - Default out: .claude/msg/cache/prd-<slug>.digest.json (repo root inferred).
  - Cache contract: if the out file exists and its source_hash matches the PRD,
    prints "hit <path>" and exits 0 without rewriting (unless --force).
  - Non-standard headings are recorded under `unparsed_sections` so a consumer
    can fall back to prose for them (never a hard failure).
Prints the digest path on success (or the JSON with --stdout).

Exit codes:
  0  digest written / printed
  1  --verify-rows found an unowned or unknown row
  2  usage error, missing PRD, or a loud parse refusal:
       FEATURE_ID_EMPTY=<row>      a §3 features row digested with an empty id
                                   (A14 — the id column did not resolve)
       FEATURE_NOT_RESOLVED=<fid>  --feature emptied a previously non-empty
                                   features / exec_table set (A15)
"""
import sys, os, re, json, hashlib, argparse

def sha256(text): return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()

def parse_frontmatter(lines):
    if not lines or lines[0].strip() != "---": return {}, 0
    fm, i = {}, 1
    while i < len(lines) and lines[i].strip() != "---":
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", lines[i])
        if m:
            k, v = m.group(1), m.group(2).strip()
            if v.startswith("[") and v.endswith("]"):
                inner = v[1:-1].strip()
                v = [x.strip() for x in inner.split(",")] if inner else []
            fm[k] = v
        i += 1
    return fm, (i + 1 if i < len(lines) else len(lines))

def md_table(block_lines):
    """Parse the first markdown table found in block_lines -> (headers, rows[list[dict]])."""
    rows, headers = [], None
    for ln in block_lines:
        s = ln.strip()
        if not s.startswith("|"):
            if headers is not None: break   # table ended
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if re.match(r"^[\s:|-]+$", s.replace("|", "")):   # separator row
            continue
        if headers is None:
            headers = cells
        else:
            rows.append(dict(zip(headers, cells + [""] * (len(headers) - len(cells)))))
    return headers, rows

def bullets(block_lines):
    return [ln.strip()[2:].strip() for ln in block_lines if ln.strip().startswith("- ")]

def raw(block_lines):
    return "\n".join(block_lines).strip()

def pick(row, *needles):
    """Fuzzy column access: first cell whose header word-matches any needle (case-insensitive)."""
    for k, v in row.items():
        kl = k.strip().lower()
        if any(kl == n or kl.startswith(n) or n in kl.split() for n in needles):
            return v.strip()
    return ""

def sections(lines, start, level):
    """Yield (title, start_line, end_line, block_lines) for headings of exactly `level` (#) from `start`."""
    hdr = re.compile(r"^#{%d}\s+(.*)$" % level)
    any_hdr = re.compile(r"^#{1,%d}\s+" % level)
    idx, out = [], []
    for i in range(start, len(lines)):
        m = hdr.match(lines[i])
        if m: idx.append((i, m.group(1).strip()))
    for k, (i, title) in enumerate(idx):
        # end = next heading of this level OR shallower
        end = len(lines)
        for j in range(i + 1, len(lines)):
            if any_hdr.match(lines[j]) and not lines[j].startswith("#" * (level + 1) + " "):
                # a heading of level<=level ends this section
                hashes = len(lines[j]) - len(lines[j].lstrip("#"))
                if hashes <= level:
                    end = j; break
        out.append((title, i + 1, end, lines[i + 1:end]))   # 1-indexed heading line
    return out

# A14 — §3 features rows whose `id` cell did not resolve, as
# (section title, row label, headers seen). Populated by build(), refused in main().
ID_GAPS = []


class FeatureNotResolved(Exception):
    """A15 — `--feature <fid>` filtered a non-empty set down to nothing."""
    def __init__(self, fid, emptied, seen_features, seen_rows):
        super().__init__(fid)
        self.fid = fid
        self.emptied = emptied
        self.seen_features = seen_features
        self.seen_rows = seen_rows


def build(prd_path):
    del ID_GAPS[:]
    with open(prd_path, encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    fm, body_start = parse_frontmatter(lines)
    d = {
        "prd": prd_path,
        "source_hash": sha256(text),
        # Both PRD shapes are emitted from one key list: the v5.4 keys
        # (deps/intake/reviewed) and the v5 keys it replaced (depends_on/affects/
        # module/platform/product-tuned/eng-tuned). Whichever the file does not
        # carry comes back None, so a consumer reads `deps or depends_on` and
        # gets the right array for either shape.
        "frontmatter": {k: fm.get(k) for k in
                        ("name","feature","status","reviewed","parent","deps",
                         "created","intake",
                         "module","platform","product-tuned","eng-tuned",
                         "depends_on","affects")},
        "summary": fm.get("summary"),
        "features": [], "out_of_scope": [], "key_interactions": [],
        "error_cases": [], "edge_cases": [], "glossary": {}, "open_questions": [],
        "exec_table": [], "engineering": {}, "engineering_agents": [],
        "audits_present": [],
        "todos": {}, "user_flows": None, "auth_model": None,
        "unparsed_sections": [],
    }
    KNOWN = set()
    for title, s, e, block in sections(lines, body_start, 2):
        lp = {"prose_lines": f"{s}-{e}"}
        # number-agnostic: strip a leading "N. " so features can live at any section number
        low = re.sub(r"^\d+\.\s*", "", title.lower()).strip()
        if low.startswith(("out-of-scope", "out of scope")):
            d["out_of_scope"] = bullets(block); KNOWN.add(title)
        elif low.startswith(("target platform", "platform")):
            KNOWN.add(title)  # platform already in frontmatter
        elif low.startswith("auth model"):
            d["auth_model"] = {"text": raw(block), **lp}; KNOWN.add(title)
        elif low.startswith(("execution table", "feature execution table")):
            # The exec table's ONE home (new: `## 6. Feature execution table`;
            # legacy `## Execution Table` still read). MUST be tested before the
            # features branch below — "feature execution table" also starts with
            # "feature" and would otherwise be parsed as the F-ID table.
            _, rows = md_table(block)
            d["exec_table"] = [{"feature": pick(r, "feature"),
                                "steps": pick(r, "execution steps", "steps", "execution"),
                                "files": pick(r, "files", "file"),
                                "agent": pick(r, "agent", "owner")} for r in rows]
            d["exec_table_prose_lines"] = f"{s}-{e}"; KNOWN.add(title)
        elif low.startswith("feature") or "acceptance cri" in low:
            headers, rows = md_table(block)
            for n, r in enumerate(rows, 1):
                # A14: `pick()` returns "" when the id column does not resolve, so
                # a header drift ("F-ID", "Ref", a dropped column) yields features
                # with empty ids — and `--feature F1` then hands eng --build an
                # empty-but-well-formed spec. Record the drift; main() refuses.
                fid = pick(r, "id", "feature id")
                if not fid:
                    label = pick(r, "feature", "name") or f"row-{n}"
                    ID_GAPS.append((title, label, headers or []))
                d["features"].append({
                    "id": fid,
                    "title": pick(r, "feature", "name"),
                    "acceptance": pick(r, "acceptance", "acceptance criterion", "acceptance criteria", "criterion"),
                    "dependencies": pick(r, "dependencies", "dependency", "depends"),
                    "prose_lines": f"{s}-{e}",
                }); KNOWN.add(title)
        elif low.startswith("user flow"):
            d["user_flows"] = lp; KNOWN.add(title)   # pointer only (narrative)
        elif low.startswith(("key user interaction", "key interaction")):
            d["key_interactions"] = bullets(block); KNOWN.add(title)
        elif low.startswith("error case"):
            _, rows = md_table(block)
            d["error_cases"] = [{"id": pick(r, "id"),
                                 "trigger": pick(r, "trigger"),
                                 "behavior": pick(r, "user-visible behavior", "behavior", "behaviour")} for r in rows]
            KNOWN.add(title)
        elif low.startswith("edge case"):
            _, rows = md_table(block)
            d["edge_cases"] = [{"id": pick(r, "id"),
                                "trigger": pick(r, "scenario", "condition", "trigger", "case"),
                                "behavior": pick(r, "expected behavior", "expected", "user-visible behavior", "behavior", "behaviour", "handling")} for r in rows]
            KNOWN.add(title)
        elif low.startswith("open question"):
            d["open_questions"] = bullets(block); KNOWN.add(title)
        elif low.startswith("glossary"):
            _, rows = md_table(block)
            for r in rows:
                t = pick(r, "term")
                if t: d["glossary"][t] = pick(r, "definition", "meaning")
            KNOWN.add(title)
        elif low.startswith("engineering"):
            agent = title.split("—",1)[1].strip() if "—" in title else title
            eng = {"prose_lines": f"{s}-{e}"}
            for st, ss, se, sb in sections(lines, s, 3):
                sl = st.lower()
                if "integration contract" in sl:
                    eng["integration_contracts_md"] = raw(sb)
                elif "migration" in sl:
                    eng["migration_breaking_md"] = raw(sb)
                elif "scope mapping" in sl:
                    _, rows = md_table(sb); eng["scope_mapping"] = rows
                elif sl.startswith("12.") or "findings" in sl:
                    eng["findings_md"] = raw(sb)
                elif sl.startswith("13.") or "open questions" in sl:
                    eng["open_questions_md"] = raw(sb)
            d["engineering"][agent] = eng
            d["engineering_agents"].append(agent); KNOWN.add(title)
        elif low.startswith("audit"):
            d["audits_present"].append({"heading": title, "prose_lines": f"{s}-{e}"}); KNOWN.add(title)
        elif low.startswith("todos"):
            agent = title.split("—",1)[1].strip() if "—" in title else "_all"
            ids = [t for t,_,_,_ in sections(lines, s, 3)]
            d["todos"][agent] = {"ids": ids, "prose_lines": f"{s}-{e}"}; KNOWN.add(title)
        elif title.startswith("PRD-") or low.startswith("prd-"):
            KNOWN.add(title)  # doc title
        else:
            d["unparsed_sections"].append({"heading": title, "lines": f"{s}-{e}"})
    return d, text

# Named slice bundles — each pipeline stage reads ONLY its slice, never the whole
# digest. Keeps per-stage token load to the minimum that stage actually needs.
SLICES = {
    # plan-review --product: does the PRD hold together as a product spec?
    "product": ["frontmatter","summary","out_of_scope","features","error_cases",
                "glossary","key_interactions"],
    # plan-em: what to build and for which platform (engineering_agents drives
    # Step 4 wave-mode detection — build once all roster agents have a section).
    "plan":    ["frontmatter","summary","features","exec_table","engineering_agents"],
    # plan-review --eng: eng-plan integrity (exec_table + todos feed checks 4/5).
    "eng-audit":["frontmatter","features","exec_table","engineering","todos","open_questions"],
    # eng --build: implement (optionally filtered to one feature via --feature).
    # `todos` carries each agent's ticket ids + the prose_lines range to read them
    # from — the tickets are the build spec, so the slice has to point at them.
    "build":   ["frontmatter","features","exec_table","engineering","todos"],
    # review / test eval bootstrap + manual-test-plan (C22): derive assertions +
    # the human-testable checklist. edge_cases[] feeds C22's checklist (C11 stays
    # on features + error_cases).
    "eval":    ["features","error_cases","edge_cases"],
    # plan-em Step 5 synthesis: summarize eng sections + cross-section findings.
    "synth":   ["frontmatter","features","exec_table","engineering","engineering_agents","open_questions"],
}

def slice_digest(d, name, feature=None):
    keys = SLICES[name]
    out = {"prd": d["prd"], "source_hash": d["source_hash"], "slice": name}
    for k in keys:
        if k in d: out[k] = d[k]
    if feature and "features" in out:
        fid = feature.upper()
        # A15: the filters below are deliberately strict — features match on an
        # exact id, exec rows on the canonical `F<k>: <name>` rendering. A PRD
        # written `F1 — name` (or an unresolved id column) used to filter down to
        # an empty-but-well-formed slice and eng --build would implement nothing.
        # Strictness stays; the silence goes.
        before_features = out["features"]
        before_exec = out.get("exec_table")
        out["features"] = [f for f in before_features
                           if (f.get("id") or "").upper() == fid]
        if "exec_table" in out:
            out["exec_table"] = [r for r in before_exec
                                 if (r.get("feature") or "").upper().startswith(fid + ":")]
        emptied = []
        if before_features and not out["features"]:
            emptied.append("features")
        if before_exec and not out.get("exec_table"):
            emptied.append("exec_table")
        if emptied:
            raise FeatureNotResolved(
                fid, emptied,
                [f.get("id") or "(empty)" for f in before_features],
                [(r.get("feature") or "(empty)") for r in (before_exec or [])])
    return out

def verify_rows(d, rows, agent):
    """Row-ownership check for eng --build Step 2. Returns a list of failure lines."""
    fails = []
    table = d.get("exec_table") or []
    for r in [x.strip() for x in rows.split(";") if x.strip()]:
        matches = [row for row in table if (row.get("feature") or "").strip() == r]
        if not matches:
            fails.append(f"Hard failure: row '{r}' matches no Feature cell in {d['prd']}")
            continue
        for row in matches:
            owner = (row.get("agent") or "").strip()
            if agent and owner != agent:
                fails.append(f"Hard failure: row '{r}' is owned by '{owner}', not '{agent}'")
    return fails

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("prd")
    ap.add_argument("--out")
    ap.add_argument("--stdout", action="store_true")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--slice", choices=sorted(SLICES), help="emit only this stage's slice to stdout")
    ap.add_argument("--feature", help="with --slice build: filter to one feature id (e.g. F1)")
    ap.add_argument("--verify-rows", dest="verify_rows",
                    help="semicolon-separated exec-table Feature identifiers to verify exist and are owned by --agent")
    ap.add_argument("--agent", help="with --verify-rows: the agent that must own every named row")
    a = ap.parse_args()
    prd = a.prd
    if not os.path.isfile(prd):
        print(f"error: no such PRD: {prd}", file=sys.stderr); sys.exit(2)

    d, text = build(prd)

    # A14 — refuse before anything is emitted or cached. An empty `id` means the
    # features table's id column did not resolve, and every downstream consumer
    # (--feature slices, F-ID coverage, eng --build) reads it as "no such feature"
    # rather than "the parse missed".
    if ID_GAPS:
        title, label, headers = ID_GAPS[0]
        print(f"FEATURE_ID_EMPTY={label}")
        print(f"script-prd-digest: {len(ID_GAPS)} row(s) in '{title}' of {prd} "
              f"digested with an empty 'id' (first: '{label}') — headers seen: "
              f"{', '.join(headers) or '(none)'}; refusing to emit a digest whose "
              "features cannot be addressed by F-ID", file=sys.stderr)
        sys.exit(2)

    if a.verify_rows is not None:
        fails = verify_rows(d, a.verify_rows, a.agent)
        for line in fails:
            print(line, file=sys.stderr)
        if fails:
            sys.exit(1)
        print("ROWS_OK"); return
    if a.slice:
        try:
            sliced = slice_digest(d, a.slice, a.feature)
        except FeatureNotResolved as exc:
            print(f"FEATURE_NOT_RESOLVED={exc.fid}")
            detail = []
            if "features" in exc.emptied:
                detail.append("features ids seen: "
                              + (", ".join(exc.seen_features) or "(none)"))
            if "exec_table" in exc.emptied:
                detail.append("exec-table Feature cells seen: "
                              + (", ".join(exc.seen_rows) or "(none)"))
            print(f"script-prd-digest: --feature {exc.fid} emptied "
                  f"{' and '.join(exc.emptied)} in {prd} — "
                  + "; ".join(detail)
                  + "; refusing to hand back an empty slice", file=sys.stderr)
            sys.exit(2)
        print(json.dumps(sliced, indent=2, ensure_ascii=False)); return
    if a.stdout:
        print(json.dumps(d, indent=2, ensure_ascii=False)); return

    out = a.out
    if not out:
        # infer repo root = nearest ancestor containing .claude/
        root = os.path.dirname(os.path.abspath(prd))
        while root != "/" and not os.path.isdir(os.path.join(root, ".claude")):
            root = os.path.dirname(root)
        slug = d["frontmatter"].get("name") or os.path.splitext(os.path.basename(prd))[0]
        out = os.path.join(root, ".claude/msg/cache", f"prd-{slug}.digest.json")

    if os.path.isfile(out) and not a.force:
        try:
            if json.load(open(out)).get("source_hash") == d["source_hash"]:
                print(f"hit {out}"); return
        except Exception:
            pass
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
    print(out)

if __name__ == "__main__":
    main()

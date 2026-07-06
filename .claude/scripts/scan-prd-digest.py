#!/usr/bin/env python3
"""
scan-prd-digest.py — deterministic PRD -> compact digest (no LLM).

Splits a msg PRD on its standardized headings and emits a JSON digest that
downstream stages consume instead of re-parsing the full prose. Contractual
fields (F-IDs, acceptance criteria, integration contracts, glossary, exec rows)
are copied VERBATIM; narrative prose is dropped but every section keeps a
`prose_lines` pointer for on-demand access. See shared/refs/session-cache.md.

Usage:
  scan-prd-digest.py <prd.md> [--out <path>] [--stdout] [--force]

Behaviour:
  - Default out: .claude/msg/cache/prd-<slug>.digest.json (repo root inferred).
  - Cache contract: if the out file exists and its source_hash matches the PRD,
    prints "hit <path>" and exits 0 without rewriting (unless --force).
  - Non-standard headings are recorded under `unparsed_sections` so a consumer
    can fall back to prose for them (never a hard failure).
Prints the digest path on success (or the JSON with --stdout).
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

def build(prd_path):
    with open(prd_path, encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    fm, body_start = parse_frontmatter(lines)
    d = {
        "prd": prd_path,
        "source_hash": sha256(text),
        "frontmatter": {k: fm.get(k) for k in
                        ("name","feature","module","platform","status",
                         "product-tuned","eng-tuned","reviewed","depends_on","affects","created")},
        "summary": fm.get("summary"),
        "features": [], "out_of_scope": [], "key_interactions": [],
        "error_cases": [], "glossary": {}, "open_questions": [],
        "exec_table": [], "engineering": {}, "audits_present": [],
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
        elif low.startswith("feature") or "acceptance cri" in low:
            _, rows = md_table(block)
            for r in rows:
                d["features"].append({
                    "id": pick(r, "id", "feature id"),
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
        elif low.startswith("open question"):
            d["open_questions"] = bullets(block); KNOWN.add(title)
        elif low.startswith("glossary"):
            _, rows = md_table(block)
            for r in rows:
                t = pick(r, "term")
                if t: d["glossary"][t] = pick(r, "definition", "meaning")
            KNOWN.add(title)
        elif low.startswith("execution table"):
            _, rows = md_table(block)
            d["exec_table"] = [{"feature": pick(r, "feature"),
                                "steps": pick(r, "execution steps", "steps", "execution"),
                                "agent": pick(r, "agent", "owner")} for r in rows]
            d["exec_table_prose_lines"] = f"{s}-{e}"; KNOWN.add(title)
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
            d["engineering"][agent] = eng; KNOWN.add(title)
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
    # plan-tune --product: does the PRD hold together as a product spec?
    "product": ["frontmatter","summary","out_of_scope","features","error_cases",
                "glossary","key_interactions"],
    # plan-em: what to build and for which platform.
    "plan":    ["frontmatter","summary","features","exec_table"],
    # plan-tune --eng: eng-plan integrity.
    "eng-audit":["frontmatter","features","engineering","open_questions"],
    # eng --build: implement (optionally filtered to one feature via --feature).
    "build":   ["frontmatter","features","exec_table","engineering"],
    # review / test eval bootstrap: derive assertions.
    "eval":    ["features","error_cases"],
    # plan-em Step 5 synthesis: summarize eng sections + cross-section findings.
    "synth":   ["frontmatter","features","exec_table","engineering","open_questions"],
}

def slice_digest(d, name, feature=None):
    keys = SLICES[name]
    out = {"prd": d["prd"], "source_hash": d["source_hash"], "slice": name}
    for k in keys:
        if k in d: out[k] = d[k]
    if feature and "features" in out:
        fid = feature.upper()
        out["features"] = [f for f in out["features"] if f["id"].upper() == fid]
        if "exec_table" in out:
            out["exec_table"] = [r for r in out["exec_table"] if r["feature"].upper().startswith(fid + ":")]
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("prd")
    ap.add_argument("--out")
    ap.add_argument("--stdout", action="store_true")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--slice", choices=sorted(SLICES), help="emit only this stage's slice to stdout")
    ap.add_argument("--feature", help="with --slice build: filter to one feature id (e.g. F1)")
    a = ap.parse_args()
    prd = a.prd
    if not os.path.isfile(prd):
        print(f"error: no such PRD: {prd}", file=sys.stderr); sys.exit(2)

    d, text = build(prd)
    if a.slice:
        print(json.dumps(slice_digest(d, a.slice, a.feature), indent=2, ensure_ascii=False)); return
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

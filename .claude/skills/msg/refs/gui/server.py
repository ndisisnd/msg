#!/usr/bin/env python3
"""msg --gui · interactive local server.

Serves the PRD board (refs/gui/index.html filled with live data) plus a small
JSON API that turns the board into a lightweight Linear/Jira-style tool:

  GET  /                      filled index.html (styles + fresh data + token)
  GET  /api/ping              liveness + existing job ids
  GET  /api/data              rebuilt data contract (see protocol-gui.md Step 3)
  GET  /api/roadmap           roadmap/roadmap.md parsed into phases (Roadmap tab)
  GET  /api/files             allowlisted project docs (README, CLAUDE.md, devkit/)
  GET  /api/file?path=…       one doc's content
  POST /api/prd/save          {path, body}        rewrite a PRD body (frontmatter kept)
  POST /api/prd/meta          {path, key, value}  set a frontmatter key (status, completion, …)
  POST /api/todo/toggle       {prd, id, done}     set a ticket's `done:` field in ## Todos
  POST /api/prompt            {prompt}            run a Claude prompt against the project
  GET  /api/jobs              prompt runs + tails of their output

Security posture: binds 127.0.0.1 only; every /api call requires the per-run
X-Msg-Token header (injected into the served HTML); Host header must be local;
all file paths are resolved and confined to the project root; reads are
extension-allowlisted; writes are restricted to features/prd-*/ markdown.

Stdlib only. Python 3.9+.
"""

import argparse
import glob
import json
import os
import re
import secrets
import subprocess
import threading
import time
import shlex
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

# --------------------------------------------------------------------------- config

ARGS = None
TOKEN = secrets.token_hex(16)
READ_EXTS = {".md", ".markdown", ".json", ".txt", ".yaml", ".yml", ".toml"}
DENY_PARTS = {".git", "node_modules", ".env", "__pycache__", ".venv", "venv"}
BUCKETS = ("product", "eng", "building", "review", "shipped")
META_KEYS = {"completion", "status", "module", "platform", "feature"}

JOBS = []          # [{id, prompt, status, output, started, finished, reported}]
JOBS_LOCK = threading.Lock()
OUTPUT_CAP = 64 * 1024


def root_path():
    return os.path.realpath(ARGS.root)


def confine(rel):
    """Resolve rel against the project root; refuse anything that escapes it."""
    if not rel or rel.startswith(("/", "~")) or ".." in rel.split("/"):
        return None
    full = os.path.realpath(os.path.join(root_path(), rel))
    if full != root_path() and not full.startswith(root_path() + os.sep):
        return None
    if any(part in DENY_PARTS for part in full[len(root_path()):].split(os.sep)):
        return None
    return full


# --------------------------------------------------------------------------- PRD parsing

FM_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n?", re.S)


def parse_frontmatter(text):
    m = FM_RE.match(text)
    if not m:
        return None, text
    fm = {}
    for line in m.group(1).splitlines():
        km = re.match(r"^([\w][\w.-]*)\s*:\s*(.*)$", line)
        if not km:
            continue
        key, val = km.group(1), km.group(2).strip()
        if val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            fm[key] = [v.strip().strip("'\"") for v in inner.split(",") if v.strip()]
        else:
            fm[key] = val.strip("'\"")
    return fm, text[m.end():]


def as_badge(v):
    if v is None:
        return None
    return str(v).strip().lower() in ("true", "yes", "✓", "x")


def parse_features(body):
    """F-ID rows from `## N. Features…` (any leading number, e.g. `## 6. Features &
    acceptance criteria`) or, failing that, `## Execution Table` (legacy) /
    `## N. Feature execution table` (new)."""
    feats, order = {}, []

    def scan(section_re):
        m = re.search(section_re, body, re.M)
        if not m:
            return False
        seg = body[m.end():]
        nxt = re.search(r"^## ", seg, re.M)
        if nxt:
            seg = seg[:nxt.start()]
        found = False
        for row in re.finditer(r"^\|(.+)\|\s*$", seg, re.M):
            cells = [c.strip() for c in row.group(1).split("|")]
            fid = None
            for c in cells:
                fm2 = re.match(r"^\**\s*(F\d+)\b", c)
                if fm2:
                    fid = fm2.group(1)
                    break
            if not fid or fid in feats:
                continue
            title = ""
            for c in cells:
                t = re.sub(r"^\**\s*F\d+\s*[—–:-]?\s*", "", c).strip(" *`")
                if t and not re.match(r"^F\d+$", t) and t != "---" and not re.match(r"^:?-+:?$", t):
                    title = t
                    break
            feats[fid] = {"id": fid, "title": title, "todos": []}
            order.append(fid)
            found = True
        return found

    if not scan(r"^##\s*\d+\.\s*Features.*$"):
        if not scan(r"^##\s*Execution Table.*$"):
            scan(r"^##\s*\d+\.\s*Feature execution table.*$")
    return feats, order


TICKET_RE = re.compile(r"^(\s*)-\s+\*\*([\w][\w.-]*)\s*[—–-]\s*(.+?)\*\*\s*$")
FIELD_RE = re.compile(r"^\s*-\s+\*\*([\w-]+):\*\*\s*(.*)$")


def parse_ticket_fields(field_lines):
    fields = {}
    for line in field_lines:
        if not FIELD_RE.match(line):
            continue
        # one physical line may carry several labels: `**type:** code · **priority:** P0`
        for key, val in re.findall(r"\*\*([\w-]+):\*\*\s*([^·]*)", line):
            fields[key.lower()] = val.strip()
    return fields


def parse_files_field(val):
    out = []
    for piece in re.finditer(r"`([^`]+)`(?:\s*\(([\w-]+)\))?", val or ""):
        out.append({"path": piece.group(1), "action": piece.group(2) or ""})
    return out


def parse_todos(body, feats, order):
    m = re.search(r"^##\s*(?:\d+\.\s*)?Todos\s*$", body, re.M)
    has = bool(m)
    if not has:
        return False
    seg = body[m.end():]
    cur_f = None
    lines = seg.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        hm = re.match(r"^###\s+(F\d+)\b", line)
        if hm:
            cur_f = hm.group(1)
            if cur_f not in feats:
                feats[cur_f] = {"id": cur_f, "title": "", "todos": []}
                order.append(cur_f)
            i += 1
            continue
        if re.match(r"^##\s", line):  # left the Todos umbrella? only stop at a non-Todos ## heading
            if not re.match(r"^##\s*(?:\d+\.\s*)?Todos\b", line):
                break
            i += 1
            continue
        tm = TICKET_RE.match(line)
        if tm and cur_f:
            indent = len(tm.group(1))
            tid, title = tm.group(2), tm.group(3).strip()
            j = i + 1
            block = []
            while j < len(lines):
                nxt = lines[j]
                if TICKET_RE.match(nxt) or re.match(r"^#{2,3}\s", nxt):
                    break
                if nxt.strip() and (len(nxt) - len(nxt.lstrip())) <= indent and re.match(r"^\s*-\s", nxt) \
                        and not FIELD_RE.match(nxt):
                    break
                block.append(nxt)
                j += 1
            f = parse_ticket_fields(block)
            files = parse_files_field(f.get("files", ""))
            depends = [d.strip() for d in re.split(r"[,\s]+", f.get("depends-on", "")) if d.strip()]
            depends = [d for d in depends if d.lower() != "none"]
            ticket = {
                "kind": "todo",
                "id": tid,
                "title": title,
                "objective": f.get("objective", ""),
                "type": f.get("type", ""),
                "priority": f.get("priority", ""),
                "files": files,
                "file": files[0]["path"] if files else None,
                "action": files[0]["action"] if files else None,
                "dependsOn": depends,
                "doneWhen": f.get("done-when", ""),
                "done": str(f.get("done", "")).strip().lower() == "true",
            }
            feats[cur_f]["todos"].append(ticket)
            i = j
            continue
        i += 1
    return True


def run_cmd(argv, timeout=3):
    try:
        r = subprocess.run(argv, cwd=root_path(), capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or "").strip()
    except Exception:
        return 1, ""


def infer_completion(fm, num, slug):
    """Frontmatter `completion:` override wins; otherwise observable git/gh signals;
    otherwise the frontmatter status fallback — same ladder as protocol-gui.md Step 2."""
    override = (fm.get("completion") or "").strip().lower()
    if override in BUCKETS:
        return override, "frontmatter completion override"
    branch = None
    code, out = run_cmd(["git", "branch", "--list", "feat/prd-%s-*" % num])
    if code == 0 and out:
        branch = out.splitlines()[0].lstrip("* ").strip()
    if branch:
        code, out = run_cmd(["gh", "pr", "list", "--head", branch, "--state", "merged",
                             "--json", "number", "--limit", "1"], timeout=4)
        if code == 0 and out and out != "[]":
            return "shipped", "PR for %s merged" % branch
        code, out = run_cmd(["gh", "pr", "list", "--head", branch, "--state", "open",
                             "--json", "number", "--limit", "1"], timeout=4)
        if code == 0 and out and out != "[]":
            return "review", "open PR for %s" % branch
        return "building", "branch %s exists" % branch
    status = (fm.get("status") or "").strip().lower()
    if status in ("eng", "engineering"):
        return "eng", "frontmatter status: %s" % status
    return "product", "frontmatter status: %s" % (status or "absent")


def parse_prd_dir(d):
    rel = os.path.relpath(d, root_path())
    mds = sorted(glob.glob(os.path.join(d, "prd-*.md")))
    if not mds:
        return None, {"path": rel + "/", "reason": "no prd-*.md file"}
    text = open(mds[0], encoding="utf-8", errors="replace").read()
    fm, body = parse_frontmatter(text)
    if fm is None:
        return None, {"path": os.path.relpath(mds[0], root_path()), "reason": "missing/unparseable frontmatter"}
    base = os.path.basename(d)
    nm = re.match(r"^prd-(\d+)-?(.*)$", base)
    num = int(nm.group(1)) if nm else 0
    slug = nm.group(2) if nm else base
    feats, order = parse_features(body)
    has_todos = parse_todos(body, feats, order)
    completion, source = infer_completion(fm, num, slug)
    badges = {
        "productTuned": as_badge(fm.get("product-tuned", fm.get("tuned"))),
        "engTuned": as_badge(fm.get("eng-tuned")),
        "reviewed": as_badge(fm.get("reviewed")),
    }
    return {
        "num": num,
        "id": base,
        "path": rel + "/",
        "file": os.path.relpath(mds[0], root_path()),
        "feature": fm.get("feature") or fm.get("name") or slug.replace("-", " ").title(),
        "summary": fm.get("summary"),
        "module": fm.get("module"),
        "platform": fm.get("platform"),
        "status": fm.get("status"),
        "created": fm.get("created"),
        "affects": fm.get("affects") or [],
        "depends_on": fm.get("depends_on") or [],
        "badges": badges,
        "completion": completion,
        "completionSource": source,
        "detail": body.strip(),
        "hasTodos": has_todos,
        "features": [feats[k] for k in order],
    }, None


# --------------------------------------------------------------------------- test issues

CATEGORY_TEST = {"unit", "e2e", "functional", "qa", "a11y", "api", "mobile",
                 "coverage", "load", "perf", "integration", "contract"}
SEV_PRIO = {"blocker": "P0", "high": "P1", "medium": "P2", "low": "P2"}


def project_finding(f):
    """Canonical finding → issue-ticket (template-todo.md 'Finding → issue-ticket projection')."""
    msg = f.get("message") or f.get("title") or f.get("id") or "finding"
    suggestion = f.get("suggestion")
    repro = f.get("repro")
    ev = f.get("evidence") or {}
    return {
        "kind": "issue",
        "id": f.get("id"),
        "title": msg,
        "objective": (suggestion if suggestion else "Restore correct behavior — %s" % msg),
        "type": "test" if (f.get("category") in CATEGORY_TEST) else "code",
        "priority": SEV_PRIO.get(f.get("severity"), "P2"),
        "files": ([{"path": f["file"], "action": "edit"}] if f.get("file") else []),
        "dependsOn": [],
        "doneWhen": ("%s passes and the covering test file is green" % repro) if repro
                    else "the finding no longer reproduces",
        "severity": f.get("severity"),
        "category": f.get("category"),
        "rule": f.get("rule"),
        "repro": repro,
        "evidence": {"snippet": ev.get("snippet")},
        "suggestion": suggestion,
        "flaky": bool(ev.get("flaky")),
        "regression_of": f.get("regression_of"),
    }


def collect_test_issues(skipped):
    out = []
    for path in sorted(glob.glob(os.path.join(root_path(), "msg-test", "test-*.json"))):
        rel = os.path.relpath(path, root_path())
        try:
            doc = json.load(open(path, encoding="utf-8"))
        except Exception as e:
            skipped.append({"path": rel, "reason": "unparseable JSON: %s" % e})
            continue
        nm = re.search(r"test-(\d+)\.json$", path)
        out.append({
            "file": rel,
            "runId": int(nm.group(1)) if nm else rel,
            "verdict": doc.get("verdict"),
            "context": doc.get("context") or {},
            "summary": doc.get("summary") or {},
            "followUp": doc.get("followUp") or {"status": "open"},
            "tickets": [project_finding(f) for f in (doc.get("issues") or [])],
        })
    return out


# --------------------------------------------------------------------------- roadmap

ROADMAP_REL = os.path.join("roadmap", "roadmap.md")
PHASE_RE = re.compile(r"^##\s+Phase\s+(\d+)\s*[—–-]\s*(.+?)\s*$", re.M)


def build_roadmap(prds):
    """Parse roadmap/roadmap.md into ordered phases, each with its PRD cards
    cross-referenced against the live PRD set so a card carries the same
    completion bucket the Board shows. Absent file → an empty, valid payload."""
    full = confine(ROADMAP_REL)
    if not full or not os.path.isfile(full):
        return {"exists": False, "phases": [], "tuneLog": ""}
    text = open(full, encoding="utf-8", errors="replace").read()
    _fm, body = parse_frontmatter(text)
    body = body if body else text
    by_id = {p["id"]: p for p in prds}

    # Split off the trailing `## Roadmap tune log` so it never leaks into the last phase.
    tm = re.search(r"^##\s+Roadmap tune log\s*$", body, re.M)
    tune_log = body[tm.end():].strip() if tm else ""
    phase_body = body[:tm.start()] if tm else body

    matches = list(PHASE_RE.finditer(phase_body))
    phases = []
    for i, m in enumerate(matches):
        name = m.group(2).strip()
        seg = phase_body[m.end(): matches[i + 1].start() if i + 1 < len(matches) else len(phase_body)]
        goal = ""
        gm = re.search(r"^\s*Goal:\s*(.+?)\s*$", seg, re.M)
        if gm:
            goal = gm.group(1).strip()
        cards = []
        # Separator between id and the rest is a *spaced* em/en-dash — never the
        # ASCII hyphens inside the id itself (prd-101-task-crud).
        for lm in re.finditer(r"^-\s+(prd-[\w.-]+?)\s+[—–]\s+(.+?)\s*$", seg, re.M):
            pid = lm.group(1)
            parts = [p.strip() for p in re.split(r"\s+[—–]\s+", lm.group(2))]
            feature = parts[0] if parts else ""
            file_bucket = parts[1] if len(parts) > 1 else ""
            rationale = parts[2] if len(parts) > 2 else ""
            live = by_id.get(pid)
            cards.append({
                "id": pid,
                "feature": (live or {}).get("feature") or feature,
                "completion": (live or {}).get("completion") or file_bucket or "product",
                "fileBucket": file_bucket,
                "rationale": rationale,
                "path": (live or {}).get("path"),
                "known": live is not None,
            })
        phases.append({"phase": int(m.group(1)), "name": name, "goal": goal, "prds": cards})

    return {"exists": True, "phases": phases, "tuneLog": tune_log}


# --------------------------------------------------------------------------- data + files

def read_h1(rel_or_abs):
    """First markdown H1 (`# …`) in a file, or None. Skips the atx trailer."""
    try:
        with open(rel_or_abs, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = re.match(r"^#\s+(.+?)\s*#*\s*$", line)
                if m:
                    return m.group(1).strip()
    except Exception:
        return None
    return None


def project_name():
    """Resolution ladder (protocol-gui.md Step 3): devkit → README/CLAUDE → repo
    folder → 'Your Project'. devkit ARCHITECTURE.md carries the interpolated name
    as `# <name> — Architecture`; strip the suffix."""
    root = root_path()
    arch = read_h1(os.path.join(root, "devkit", "ARCHITECTURE.md"))
    if arch:
        stripped = re.sub(r"\s*[—–-]\s*Architecture\s*$", "", arch).strip()
        return stripped or arch
    for name in ("README.md", "CLAUDE.md"):
        h1 = read_h1(os.path.join(root, name))
        if h1:
            return h1
    base = os.path.basename(root.rstrip(os.sep))
    return base or "Your Project"


def build_data():
    prds, skipped = [], []
    for d in sorted(glob.glob(os.path.join(root_path(), "features", "prd-*"))):
        if not os.path.isdir(d):
            continue
        candidates = [d] + sorted(g for g in glob.glob(os.path.join(d, "prd-*")) if os.path.isdir(g))
        for c in candidates:
            prd, skip = parse_prd_dir(c)
            if prd:
                prds.append(prd)
            elif skip and c == d:
                skipped.append(skip)
    test_issues = collect_test_issues(skipped)
    return {
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "project": project_name(),
        "prds": prds,
        "testIssues": test_issues,
        "roadmap": build_roadmap(prds),
        "skipped": skipped,
    }


def list_project_files():
    files = []
    for name in sorted(os.listdir(root_path())):
        if name.lower().endswith(".md") and os.path.isfile(os.path.join(root_path(), name)):
            files.append({"path": name, "group": "Project"})
    devkit = os.path.join(root_path(), "devkit")
    if os.path.isdir(devkit):
        for name in sorted(os.listdir(devkit)):
            if name.lower().endswith(".md"):
                files.append({"path": "devkit/" + name, "group": "Devkit"})
    # CLAUDE.md first if present — it's the "learn about this project" entry point
    files.sort(key=lambda f: (f["group"] != "Project", f["path"].lower() != "claude.md", f["path"].lower()))
    return files


# --------------------------------------------------------------------------- writes

def resolve_prd_md(rel):
    """Accept a PRD dir path (`features/prd-1-x/`) or the .md path itself."""
    full = confine(rel.rstrip("/"))
    if not full:
        return None
    relnorm = os.path.relpath(full, root_path())
    if not relnorm.startswith("features" + os.sep):
        return None
    if os.path.isdir(full):
        mds = sorted(glob.glob(os.path.join(full, "prd-*.md")))
        return mds[0] if mds else None
    return full if (full.endswith(".md") and os.path.isfile(full)) else None


def save_prd_body(rel, new_body):
    md = resolve_prd_md(rel)
    if not md:
        return "PRD not found or outside features/: %s" % rel
    text = open(md, encoding="utf-8").read()
    m = FM_RE.match(text)
    if not m:
        return "PRD has no frontmatter: %s" % rel
    open(md, "w", encoding="utf-8").write(text[:m.end()] + new_body.rstrip() + "\n")
    return None


def set_frontmatter_key(rel, key, value):
    if key not in META_KEYS:
        return "key not editable: %s" % key
    if key == "completion" and value not in BUCKETS:
        return "invalid completion bucket: %s" % value
    md = resolve_prd_md(rel)
    if not md:
        return "PRD not found or outside features/: %s" % rel
    text = open(md, encoding="utf-8").read()
    m = FM_RE.match(text)
    if not m:
        return "PRD has no frontmatter: %s" % rel
    fm_block = m.group(1)
    line = "%s: %s" % (key, value)
    if re.search(r"^%s\s*:" % re.escape(key), fm_block, re.M):
        fm_block = re.sub(r"^%s\s*:.*$" % re.escape(key), line, fm_block, count=1, flags=re.M)
    else:
        fm_block = fm_block + "\n" + line
    open(md, "w", encoding="utf-8").write("---\n" + fm_block + "\n---\n" + text[m.end():])
    return None


def toggle_todo(rel, ticket_id, done):
    md = resolve_prd_md(rel)
    if not md:
        return "PRD not found or outside features/: %s" % rel
    text = open(md, encoding="utf-8").read()
    um = re.search(r"^##\s*(?:\d+\.\s*)?Todos\s*$", text, re.M)
    if not um:
        return "PRD has no ## Todos section"
    lines = text.splitlines(keepends=True)
    # locate the ticket title line after ## Todos
    start_idx = text[:um.start()].count("\n")
    tline = None
    for i in range(start_idx, len(lines)):
        tm = TICKET_RE.match(lines[i].rstrip("\n"))
        if tm and tm.group(2) == ticket_id:
            tline = i
            break
    if tline is None:
        return "ticket %s not found under ## Todos" % ticket_id
    # block = field lines until the next ticket/heading
    end = tline + 1
    while end < len(lines):
        raw = lines[end].rstrip("\n")
        if TICKET_RE.match(raw) or re.match(r"^#{2,3}\s", raw):
            break
        end += 1
    indent = "  "
    for i in range(tline + 1, end):
        fm = FIELD_RE.match(lines[i].rstrip("\n"))
        if fm:
            indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
            break
    val = "true" if done else "false"
    for i in range(tline + 1, end):
        if re.match(r"^\s*-\s+\*\*done:\*\*", lines[i]):
            lines[i] = "%s- **done:** %s\n" % (indent, val)
            open(md, "w", encoding="utf-8").write("".join(lines))
            return None
    insert_at = end
    while insert_at > tline + 1 and lines[insert_at - 1].strip() == "":
        insert_at -= 1
    lines.insert(insert_at, "%s- **done:** %s\n" % (indent, val))
    open(md, "w", encoding="utf-8").write("".join(lines))
    return None


# --------------------------------------------------------------------------- prompt jobs

def start_job(prompt):
    job = {
        "id": secrets.token_hex(6),
        "prompt": prompt,
        "status": "running",
        "output": "",
        "started": time.time(),
        "finished": None,
        "reported": False,
    }
    with JOBS_LOCK:
        JOBS.append(job)

    def run():
        try:
            argv = [a if a != "{prompt}" else prompt for a in shlex.split(ARGS.runner)]
            if "{prompt}" not in ARGS.runner:
                argv.append(prompt)
            proc = subprocess.Popen(argv, cwd=root_path(), stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, errors="replace")
            for line in proc.stdout:
                with JOBS_LOCK:
                    job["output"] = (job["output"] + line)[-OUTPUT_CAP:]
            proc.wait()
            with JOBS_LOCK:
                job["status"] = "done" if proc.returncode == 0 else "error"
                if proc.returncode != 0:
                    job["output"] += "\n[exit code %d]" % proc.returncode
        except Exception as e:
            with JOBS_LOCK:
                job["status"] = "error"
                job["output"] += "\n[failed to run: %s]" % e
        finally:
            with JOBS_LOCK:
                job["finished"] = time.time()

    threading.Thread(target=run, daemon=True).start()
    return job["id"]


def jobs_snapshot():
    now = time.time()
    out = []
    with JOBS_LOCK:
        for j in reversed(JOBS):
            fin = j["finished"]
            item = {
                "id": j["id"],
                "prompt": j["prompt"][:400],
                "status": j["status"],
                "elapsed": (fin or now) - j["started"],
                "output": j["output"][-16384:],
            }
            if j["status"] != "running" and not j["reported"]:
                item["justFinished"] = True
                j["reported"] = True
            out.append(item)
    return out


# --------------------------------------------------------------------------- http

def fill_template():
    gui = os.path.realpath(ARGS.gui_dir)
    html = open(os.path.join(gui, "index.html"), encoding="utf-8").read()
    styles = open(os.path.join(gui, "styles.css"), encoding="utf-8").read()
    data = json.dumps(build_data()).replace("</", "<\\/")
    html = html.replace("__STYLES__", styles, 1)
    html = html.replace("__PRD_DATA__", data, 1)
    html = html.replace("__API_TOKEN__", TOKEN, 1)
    html = html.replace("__DEFAULT_VIEW__", getattr(ARGS, "view", "board") or "board", 1)
    return html


class Handler(BaseHTTPRequestHandler):
    server_version = "msg-gui/2.0"

    def log_message(self, fmt, *args):
        pass

    # -- helpers
    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        raw = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def _json(self, obj, code=200):
        self._send(code, json.dumps(obj))

    def _err(self, msg, code=400):
        self._json({"error": msg}, code)

    def _guard(self):
        host = (self.headers.get("Host") or "").split(":")[0]
        if host not in ("127.0.0.1", "localhost"):
            self._err("bad host", 403)
            return False
        if self.headers.get("X-Msg-Token") != TOKEN:
            self._err("bad or missing token", 403)
            return False
        return True

    def _body(self):
        try:
            n = int(self.headers.get("Content-Length") or 0)
            return json.loads(self.rfile.read(n).decode("utf-8")) if n else {}
        except Exception:
            return None

    # -- routes
    def do_GET(self):
        u = urlparse(self.path)
        if u.path in ("/", "/index.html"):
            try:
                self._send(200, fill_template(), "text/html; charset=utf-8")
            except Exception as e:
                self._send(500, "template error: %s" % e, "text/plain; charset=utf-8")
            return
        if not u.path.startswith("/api/"):
            self._send(404, "not found", "text/plain; charset=utf-8")
            return
        if not self._guard():
            return
        if u.path == "/api/ping":
            with JOBS_LOCK:
                ids = [j["id"] for j in JOBS]
            self._json({"ok": True, "root": root_path(), "jobs": ids})
        elif u.path == "/api/data":
            self._json(build_data())
        elif u.path == "/api/roadmap":
            self._json(build_roadmap(build_data()["prds"]))
        elif u.path == "/api/files":
            self._json({"files": list_project_files()})
        elif u.path == "/api/file":
            rel = (parse_qs(u.query).get("path") or [""])[0]
            full = confine(rel)
            if not full or not os.path.isfile(full):
                return self._err("file not found: %s" % rel, 404)
            if os.path.splitext(full)[1].lower() not in READ_EXTS:
                return self._err("file type not viewable", 403)
            if os.path.getsize(full) > 2 * 1024 * 1024:
                return self._err("file too large", 413)
            content = open(full, encoding="utf-8", errors="replace").read()
            self._json({"path": rel, "content": content})
        elif u.path == "/api/jobs":
            self._json({"jobs": jobs_snapshot()})
        else:
            self._err("unknown endpoint", 404)

    def do_POST(self):
        u = urlparse(self.path)
        if not u.path.startswith("/api/"):
            return self._err("unknown endpoint", 404)
        if not self._guard():
            return
        b = self._body()
        if b is None:
            return self._err("invalid JSON body")
        if u.path == "/api/prd/save":
            if not isinstance(b.get("body"), str):
                return self._err("missing body")
            e = save_prd_body(str(b.get("path") or ""), b["body"])
            return self._err(e) if e else self._json({"ok": True})
        if u.path == "/api/prd/meta":
            e = set_frontmatter_key(str(b.get("path") or ""), str(b.get("key") or ""),
                                    str(b.get("value") or ""))
            return self._err(e) if e else self._json({"ok": True})
        if u.path == "/api/todo/toggle":
            e = toggle_todo(str(b.get("prd") or ""), str(b.get("id") or ""), bool(b.get("done")))
            return self._err(e) if e else self._json({"ok": True})
        if u.path == "/api/prompt":
            prompt = str(b.get("prompt") or "").strip()
            if not prompt:
                return self._err("empty prompt")
            if len(prompt) > 20000:
                return self._err("prompt too long")
            return self._json({"ok": True, "id": start_job(prompt)})
        return self._err("unknown endpoint", 404)


def main():
    global ARGS
    ap = argparse.ArgumentParser(description="msg --gui interactive server")
    ap.add_argument("--root", default=".", help="project root (contains features/)")
    ap.add_argument("--gui-dir", default=os.path.dirname(os.path.abspath(__file__)),
                    help="dir containing index.html + styles.css")
    ap.add_argument("--port", type=int, default=0, help="port (0 = pick a free one)")
    ap.add_argument("--view", default="board", choices=("board", "roadmap"),
                    help="initial tab the served board opens on")
    ap.add_argument("--runner", default="claude -p {prompt} --permission-mode acceptEdits",
                    help="command template for /api/prompt; {prompt} is replaced argv-safely")
    ARGS = ap.parse_args()
    if not os.path.isdir(root_path()):
        raise SystemExit("root does not exist: %s" % ARGS.root)

    srv = ThreadingHTTPServer(("127.0.0.1", ARGS.port), Handler)
    print("msg-gui serving %s" % root_path())
    print("URL: http://127.0.0.1:%d/" % srv.server_address[1], flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()

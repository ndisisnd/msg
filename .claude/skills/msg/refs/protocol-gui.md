# Protocol — `--gui`

Build and serve a **local-only** GUI over `features/prd-*/`: a Kanban/Table board of PRDs
→ per-PRD detail page (rendered PRD body + a TODOs section with its own Kanban/Table
toggle and a side panel), a **Roadmap** view (phases-as-lanes over `roadmap/roadmap.md`,
shown when that file exists), a **Files** view over the project's docs (README, CLAUDE.md,
`devkit/`), and — in interactive mode — a **Prompts** console that runs Claude against the
project. The surface lives in `refs/gui/` (`index.html`, `styles.css`, `server.py`); this
protocol only launches or fills it.

Dispatched from `msg/SKILL.md` on `/msg --gui`, the bare word `/msg gui`, or a
natural-language board/kanban/visualise request. Skip the picker entirely — go straight to
serving; do not call `AskUserQuestion`.

---

## Two modes, one template

| Mode | How it runs | What works |
|------|-------------|------------|
| **Interactive (default)** | `refs/gui/server.py` serves the board and a JSON API | Everything below **plus** editing: PRD body editor, status changes (dropdown + drag-and-drop between columns), todo done-toggling (checkbox + drag between Open/Done), the Prompts console, live Files view, data refresh after every write |
| **Static (fallback)** | template + data-fill, served by any dumb file server | Read-only board: Kanban/Table, detail pages, rendered markdown preview, filter/sort, Test Issues. All editing UI stays hidden because no `/api/ping` answers |

The same `index.html` implements both: at boot it pings `api/ping`; a response flips it
into live mode, no response leaves it read-only. **Default to interactive mode**; fall back
to static only when `python3` is unavailable or the user asks for a read-only snapshot.

## Step 1 — Interactive mode (default)

1. Launch the server from the project root (run in background, note PID + URL):

   ```bash
   python3 .claude/skills/msg/refs/gui/server.py --root . --port 0
   ```

   `--port 0` picks a free port; the chosen URL is printed on stdout. Optional:
   `--runner '<cmd template>'` overrides how Prompts are executed (default
   `claude -p {prompt} --permission-mode acceptEdits`, run argv-safe with the project root
   as cwd — never through a shell).

2. Open the default browser at the printed `http://127.0.0.1:<port>/`. If the browser
   can't be opened, print the URL so the user can open it manually (error case 3).

3. Tear the server down when the user says they're done, or after a short idle timeout
   (criterion 9). Note the PID/URL so it can be stopped cleanly.

The server owns everything the agent used to do at generation time: it parses PRDs
(Step 3's contract), infers completion, fills the template **in memory** on every page
load, and re-parses on every `/api/data` call — so external edits (including ones made by
a Prompts run) appear on refresh. Nothing generated is ever written into the repo.

### Interactive surface — what the API allows

- **Edit a PRD body** — `POST /api/prd/save {path, body}` rewrites everything after the
  frontmatter of that PRD's `prd-*.md`. Frontmatter is preserved verbatim.
- **Change status** — `POST /api/prd/meta {path, key, value}`, editable keys:
  `completion | status | module | platform | feature`. Setting `completion` writes a
  frontmatter `completion:` override — see Step 2's inference ladder (the override is its
  top rung). Drag-and-drop between board columns and the detail-page dropdown both use this.
- **Toggle a todo** — `POST /api/todo/toggle {prd, id, done}` sets a `- **done:** true|false`
  field on that ticket's block under `## Todos` (additive: a field the todo schema tolerates
  and `--build` ignores). **Issue-tickets are never toggleable** — their done-state is
  `followUp.status`, owned by `eng --build`; the GUI only renders it.
- **Run a prompt** — `POST /api/prompt {prompt}` starts a background job via the runner
  template; `GET /api/jobs` returns status + output tails and the GUI polls while a run is
  live, then refreshes board data. Quick actions prefill skill invocations (`/plan-pm …`,
  `/eng --build …`); todo/issue side panels offer "Ask Claude about this" with context
  prefilled.
- **View project docs** — `GET /api/files` lists root `*.md` (README, CLAUDE.md, CHANGELOG…)
  and `devkit/*.md`, grouped; `GET /api/file?path=…` returns one file, rendered as markdown
  in the Files view.
- **View the roadmap** — `GET /api/roadmap` parses `roadmap/roadmap.md` (written by
  `plan-pm --roadmap`) into ordered phases, each cross-referenced against the live PRD set so
  a card shows the same completion pill the Board uses. The same payload is also folded into
  `/api/data` under `roadmap`, so both live and static modes render the tab. The Roadmap view
  is **read-only for v1** (no write endpoints — the roadmap is authored by `plan-pm`). The
  server accepts `--view <board|roadmap>` to choose the initial tab; `plan-pm --roadmap`
  launches with `--view roadmap`. The **Roadmap** nav tab appears only when a roadmap exists
  (or in interactive mode); each phase renders as a lane (reusing the Kanban column, header,
  and card/pill components) with `Phase 0 — Shipped` first and the tune log in a footer accordion.

### Security posture (unchanged spirit, wider surface)

- Binds **127.0.0.1 only** (criterion 6); the `Host` header must be local.
- Every `/api/*` call requires the per-run `X-Msg-Token` header. The token is generated at
  server start and injected only into the served HTML — cross-origin pages can't read it,
  and the custom header forces a CORS preflight the server never grants.
- All paths are resolved and confined to `--root`; reads are extension-allowlisted
  (`.md .json .txt .yaml .yml .toml`, ≤2 MB) and skip `.git`/`node_modules`/`.env*`;
  **writes are restricted to `features/prd-*/` markdown** — the server cannot write
  anywhere else, and never writes `msg-gate/gate-*.json` (the finding→ticket projection
  stays read-time; `followUp.status` is written solely by `eng --build`).

## Step 2 — Data model (what the server parses)

Same read model as before — now implemented in `server.py`, re-run per request:

1. **Frontmatter** per `features/prd-*/prd-*.md` (missing fields are normal → `null`;
   missing/unparseable frontmatter → `skipped[]`, keep going).
2. **F-ID feature rows** from `## N. Features…` (any leading number, e.g.
   `## 6. Features & acceptance criteria`), falling back to `## Execution Table` (legacy)
   or `## N. Feature execution table` (new).
3. **Todos** under `## Todos` / `## N. Todos` (e.g. `## 11. Todos`) → tickets per
   `.claude/skills/eng/refs/plan/template-todo.md` (`**<id> — <title>**` + labelled field
   bullets). A ticket's `done` is read from its `- **done:** true` field when present
   (written by the toggle endpoint); absent → `false`.
4. **Gate issues** from `msg-gate/gate-*.json` via the shared **finding → issue-ticket
   projection** in `eng/refs/build/protocol-build-gatejson.md` (read-time view, never
   re-serialized). Absent `msg-gate/` → `gateIssues: []`.
5. **Run reports** from `features/prd-*/reports/report-*.md` (one level of nested
   `prd-*` sub-dirs included) and `features/reports/report-*.md` (the no-PRD fallback),
   per `.claude/skills/shared/refs/report-schema.md` — frontmatter → typed fields, body
   → raw markdown `detail`, containing `prd-*` folder → `prdId`. Missing/unparseable
   frontmatter → `skipped[]`. No reports → `reports: []`.
6. **Completion inference (H1 ladder)**, most-authoritative first:

   | Signal | Bucket |
   |---|---|
   | frontmatter `completion:` override (written by the GUI) | that bucket, verbatim |
   | PR `staging → main` MERGED (references this PRD) | `shipped` (production) |
   | `staging-signoff:` stamp present in the frontmatter | `staged` (human-approved) |
   | PR `feature → staging` MERGED | `staged` |
   | PR `feature → staging` OPEN | `gated` (pre-merge passed) |
   | `feat/prd-<n>-*` branch exists | `building` (in build) |
   | frontmatter `status: eng`/`engineering` | `planned` |
   | anything else | `product` |

   The PR-state rungs come from `gh pr list --json` and need `gh` + a git remote; the
   `staging-signoff:` rung is read straight from frontmatter. When `gh`/a remote is
   unavailable (or slow), the PR rungs are skipped and the ladder falls through **silently
   down-ladder** to the stamp/branch/frontmatter rungs — never an error. Record the winning
   rung as a human string in `completionSource`. Board columns render the six v2 buckets
   `product · planned · building · gated · staged · shipped`; a card can now visibly sit in
   `gated`, `staged`, or `shipped`.

## Step 3 — Data contract

The JSON shape `index.html` expects (inline in static mode, from `/api/data` in live mode)
is unchanged from the previous protocol revision, with these notes:

- A top-level `project` string names the board (the `<h1>` title and the browser tab).
  The server resolves it via a ladder — `devkit/ARCHITECTURE.md` H1 (its interpolated
  `# <name> — Architecture`, suffix stripped) → `README.md` H1 → `CLAUDE.md` H1 → repo
  folder name → `"Your Project"`. Static producers should embed the same string; if
  absent the GUI falls back to `"PRD Board"`.
- `detail` is still the **raw PRD markdown body** as a plain string. The GUI renders it
  client-side through its own self-contained, injection-safe formatter (source is
  HTML-escaped before any markup transformation; no external libraries, no network) and
  now **splits it into one collapsible accordion per `##` section**. Section-name
  matching tolerates an optional leading section number, so both the legacy unnumbered
  headings and the new numbered template render: `## Todos` / `## 11. Todos`,
  `## Execution Table` / `## 7. Feature execution table`, and `## 3. Features` /
  `## 6. Features & acceptance criteria` (any `## N. Features…`). The Todos dump is
  omitted (todos render in their own section). The findings section — new
  `## N. Plan tune findings` (legacy `## Audit — <date>` still supported) — plus any
  nested `### 12. Findings` eng list is parsed into a dedicated **Plan-tune findings**
  table. In the new template that section is itself a **markdown table** with columns
  `# | Date | Auditor | Severity | What is wrong | Suggested fix | Why it matters | Status`
  (Auditor is `P` or `E`; Status is Open / Fixed / Still open / Clean; `Clean`/empty-
  severity rows are skipped). Legacy prose findings (`Finding N — Severity — Title`) are
  still parsed as a fallback. The rendered table shows columns **#, Date, Auditor,
  Severity, What is wrong, Suggested fix, Why it matters, Status** — cells missing from a
  legacy/eng finding (Date/Auditor/Status) render as `—`. Producers must keep passing raw
  markdown — never pre-rendered HTML.
- todos may carry `done: true` (from the toggle field); todo progress fractions are real
  when the field exists and `0/N` otherwise.
- an optional top-level `projectFiles: [{path, group, content}]` may be embedded in
  **static** mode to light up the read-only Files view; live mode ignores it and uses the
  API.

```json
{
  "generatedAt": "…", "project": "Your Project",
  "prds": [ { "num": 100, "id": "prd-100-…", "path": "features/prd-100-…/",
    "feature": "…", "summary": "<2–3 sentence gist from frontmatter `summary`; null if absent — detail page falls back to the feature-title list>",
    "module": "…", "platform": "…", "status": "eng", "created": "2026-07-02",
    "badges": { "productTuned": true, "engTuned": true, "reviewed": false },
    "completion": "building", "completionSource": "branch feat/prd-100-… exists",
    "detail": "<raw PRD markdown body>", "hasTodos": true,
    "features": [ { "id": "F1", "title": "…", "todos": [ { "kind": "todo", "id": "F1-T1", "title": "…",
      "objective": "…", "type": "code", "priority": "P0",
      "files": [ { "path": "src/x.ts", "action": "add" } ], "dependsOn": [], "doneWhen": "…",
      "done": false } ] } ] } ],
  "gateIssues": [ { "file": "msg-gate/gate-1.json", "runId": 1, "verdict": "fail",
    "context": { "prd": "…", "branch": "…", "base": "staging" },
    "summary": { "failed": 2, "flaky": 1, "warnings": 0 }, "followUp": { "status": "open" },
    "tickets": [ { "kind": "issue", "id": "unit-002", "source": "pre-merge:unit-int", "…": "projected per protocol-build-gatejson.md" } ] } ],
  "reports": [ { "file": "features/prd-101-task-crud/reports/report-1.md", "reportId": 1,
    "skill": "eng", "prd": "features/prd-101-task-crud/prd-101-task-crud.md",
    "prdId": "prd-101-task-crud", "branch": "feat/prd-101-task-crud", "verdict": "pass",
    "generated": "2026-07-08T14:00:00Z", "features": ["F1"],
    "stats": { "filesChanged": 3, "linesAdded": 120, "linesRemoved": 8,
      "testsPassed": 6, "testsFailed": 0 },
    "title": "Report 1 — eng — …", "detail": "<raw report markdown body>" } ],
  "skipped": [ { "path": "…", "reason": "…" } ]
}
```

## Step 4 — Static fallback (no server)

When interactive mode isn't possible or wanted:

1. Collect the Step 3 JSON yourself (read-only — same parsing rules as Step 2; never write
   or modify any PRD file). Write it to a fresh temp dir (`mktemp -d`) — never into the
   repo. Optionally include a top-level `projectFiles` (path/group/content) array to light
   up the read-only Files view.
2. Fill the template by running `refs/gui/fill-static.py` — **do not** Read/splice
   `index.html`/`styles.css` by hand. The script does the `__STYLES__` / `__PRD_DATA__` /
   `__API_TOKEN__` substitution (validates the JSON, escapes `</` so the inline data can't
   break out of its `<script>` tag, and leaves the token empty so the editing UI stays off):

   ```bash
   DIR=$(mktemp -d)
   #   …write the Step-3 data contract to "$DIR/data.json"…
   python3 .claude/skills/msg/refs/gui/fill-static.py \
     --data "$DIR/data.json" --out "$DIR/index.html"
   ```

   Defaults resolve the template and CSS from the sibling `refs/gui/` files. Pass
   `--default-view roadmap` to open on the Roadmap tab (omit it to leave the JS `board`
   fallback). `--data -` reads the JSON from stdin instead of a file.
3. Serve the temp dir GET-only: `python3 -m http.server <port> --bind 127.0.0.1 --directory "$DIR"`.
4. Open the browser / print the URL; tear down as in Step 1.

Templates must stay as files under `refs/gui/` — never inline the HTML/CSS in this
protocol (criterion 25). The design system in `styles.css` is hardcoded and identical
across every project (light + dark, responsive); it is **not** sourced from
`devkit/DESIGN-SYSTEM.md` (criterion 26).

### Error cases
- `python3` missing / ports busy → surface it, don't fail silently (error case 1).
- Malformed PRD frontmatter or unparseable `msg-gate/*.json` → `skipped[]`, flagged in the
  board header; the rest still render (error case 2).
- Browser won't open → print the `127.0.0.1` URL (error case 3).
- `claude` CLI missing → Prompts runs fail with a visible error in the run's output; the
  rest of the board is unaffected.

---

## Gate Issues surface + PRD cross-link (rendering)

- **A distinct surface, not a PRD column.** `gateIssues[]` render in their own grouping on
  the board — one card per `msg-gate/gate-<n>.json` (runId, verdict pill, summary counts,
  `followUp.status`).
- **Every ticket is tagged by `kind`.** Issue-tickets get a 🐞 tag, a `severity` pill, and
  `repro`/`evidence.snippet` in the side panel.
- **Per-issue gate-step badge.** Each issue-ticket shows the originating gate step parsed
  from the finding's `source` field (`pre-merge:mechanical` → `mechanical`,
  `pre-merge:bucket:e2e` → `bucket:e2e`); the raw `source` is surfaced as `Gate step` in
  the side panel.
- **Real done-state for issues.** `followUp.status` is written back by `eng --build`; the
  board renders it, never invents it, and never offers a toggle for it. The
  suggested-command deep-link is `eng --build gate-json=msg-gate/gate-<n>.json`.
- **PRD cross-link.** A `gateIssues[]` entry whose `context.prd` matches an enumerated PRD
  also surfaces its tickets on that PRD's detail page, tagged `kind: "issue"`.

## Reports tab (rendering)

- **Own tab, read-only.** `reports[]` render under a dedicated **Reports** nav tab
  (`#/reports`), grouped by `prdId` (unmapped reports group under "No PRD"), one card per
  `report-[n].md` with skill, verdict pill, diff/test stat pills, branch, and timestamp.
- **Detail page.** `#/reports/<file>` renders the report's raw markdown `detail` through
  the same injection-safe formatter as PRDs, with a `↗` cross-link to the mapped PRD when
  `prdId` matches an enumerated PRD.
- **Producers, not the GUI, write reports.** `eng --build`, `/pre-merge`, and
  `/post-merge` own `report-[n].md` (`.claude/skills/shared/refs/report-schema.md`); the
  board renders them and never writes, renumbers, or toggles them. Post-merge reports join
  the per-PRD grouping by their `skill: post-merge` frontmatter — staging reports carry the
  human test script in `## How to verify`; production reports render release-style, and when
  the body contains the literal token `IRREVERSIBLE` (a no-rollback platform like iOS) the
  Reports tab surfaces a prominent badge on the card and a callout banner on the detail page.

## What this protocol never does
- Never lets the GUI write outside `features/prd-*/` markdown: no repo-file writes from the
  Files view, no writes to `msg-gate/gate-*.json` (`followUp.status` belongs to
  `eng --build`), no generated output written into the repo.
- Never invents issue done-state, and never fabricates todo done-state — a todo is `done`
  only when its ticket block carries `- **done:** true` (the toggle's own field).
- Never binds to anything but `127.0.0.1`, and never serves without the per-run token
  guard in interactive mode.
- Never pre-renders `detail` to HTML in the data contract — rendering is the GUI's job,
  from raw markdown, through its escaping formatter.

# Protocol — `--gui`

Build and serve a **local-only, read-only** GUI over `features/prd-*/`: a Kanban/Table
board of PRDs → per-PRD detail page (collapsible PRD body + a TODOs section with its own
Kanban/Table toggle and a side panel). Nothing is ever editable and no PRD file is ever
written. Generation is **template + data-fill** — the HTML/CSS live in `refs/gui/`; this
protocol only collects data, fills the two placeholders, and serves the result.

Dispatched from `msg/SKILL.md` on `/msg --gui`, the bare word `/msg gui`, or a
natural-language board/kanban/visualise request. Skip the picker entirely — go straight to
rendering; do not call `AskUserQuestion`.

---

## Step 1 — Collect PRD data (read-only)

Enumerate every `features/prd-*/` directory (top-level and nested sub-PRD folders when they
exist). For each, locate its PRD markdown (`prd-*.md` in that folder) and parse:

1. **Frontmatter** (YAML between the leading `---` fences). Read whatever is present:
   `name`, `feature`, `module`, `status`, `platform`, `created`, `affects`, `depends_on`,
   and the badge fields `product-tuned` / `eng-tuned` / `reviewed`. **Missing fields are
   normal** — older PRDs use `tuned:` or omit badges. Never fail on absence; emit `null`.
   - If the frontmatter block is missing or unparseable → **skip that PRD**, add
     `{ path, reason }` to `skipped[]`, and keep going (error case 2).

2. **F-ID feature rows.** Prefer the `## 3. Features & acceptance criteria` table; if that
   heading is absent, fall back to the `## Execution Table` (present once a PRD passes
   `plan-em`). Extract each distinct `F<n>` and its title (the text before `—` / the first
   column). A PRD past `plan-em` lacking `## 3.` must fall back cleanly (edge case 4); a PRD
   with neither section yields an empty `features[]` (no error).

3. **Todos.** Only where a `## Todos` section exists: under each agent sub-heading, read each
   feature's `### F<n>` block and parse its **tickets** (JIRA/Linear-style, per
   `.claude/skills/eng/refs/todo/template-todo.md`). Each ticket's title line is `**<id> — <title>**`;
   its indented fields are `objective`, `type`, `priority`, `files`, `depends-on`, `done-when`.
   Map them to `{ id, title, objective, type, priority, files: [{ path, action }], dependsOn: [ids],
   doneWhen, done }`. `files` is a comma-separated list of `` `path` (action) `` — split into the
   `files[]` array; also keep the first path as `file` and its action as `action` for backward
   compatibility with older single-file todo blocks (a legacy `type · file · action · done-when`
   bullet parses as a one-ticket-per-item block with an empty `title`/`objective`). Attach each
   ticket to the matching `features[].id`. **No done-state field exists in the todo schema**
   (`done-when` is the acceptance *check*, not a stored status) — set every ticket's `done` to
   `false`. PRDs with no `## Todos` section get `hasTodos: false` and no tickets (edge case 3).

Never write or modify any PRD file (criterion 14).

## Step 1b — Collect persistent test issues (read-only)

After enumerating `features/prd-*/`, also glob `msg-test/test-*.json` at the **repo root** — the persistent issue tickets `/test` Step 6 writes on a non-clean run. **If `msg-test/` is absent, skip this step cleanly** (it only exists once a non-clean run has occurred): `testIssues[]` is simply empty and the board still renders (edge case 5).

For each `msg-test/test-<n>.json`:

1. Parse the file (canonical findings — the shape in `.claude/skills/test/refs/schema.md`). If a file is unparseable, add `{ path, reason }` to `skipped[]` and keep going — same posture as a malformed PRD.
2. **Project each finding in `issues[]` into an issue-ticket** per the shared mapping in `.claude/skills/eng/refs/todo/template-todo.md` (**Finding → issue-ticket projection**). Every projected ticket carries `kind: "issue"` plus the preserved diagnostic fields (`severity`, `category`, `rule`, `repro`, `evidence.snippet`, `suggestion`, `evidence.flaky`). This is a **read-time view** — never write the projection back to the file.
3. Emit one `testIssues[]` entry per file (shape in Step 3).

This projection is the *same* mapping `eng --build` applies — defined once in `template-todo.md` so the board and the fixer never drift.

## Step 2 — Infer completion status (criterion 19)

For each PRD derive a `completion` bucket from observable signals, most-authoritative last,
falling back to frontmatter when no later signal exists:

| Signal (checked in order) | Bucket | How |
|---|---|---|
| last `pre-merge` passed / merged | `shipped` | PR merged, or a passing `pre-merge` record for the branch |
| open PR for the branch | `review` | `gh pr list --head feat/prd-<n>-<slug>` non-empty |
| `feat/prd-<n>-<slug>` branch exists | `building` | `git branch --list` / `git rev-parse` |
| frontmatter `status: eng` (or `engineering`) | `eng` | fallback |
| frontmatter `status: product` (or anything else) | `product` | fallback |

Record a short human string in `completionSource` (e.g. `"branch feat/prd-100-… exists"`).
If `git`/`gh` are unavailable, silently use the frontmatter fallback — never block the board.

## Step 3 — Build the data contract

Assemble one JSON object. This is the exact shape `refs/gui/index.html` expects:

```json
{
  "generatedAt": "<ISO timestamp or date>",
  "prds": [
    {
      "num": 100,
      "id": "prd-100-calendar-scheduling",
      "path": "features/prd-100-calendar-scheduling/",
      "feature": "Calendar Scheduling",
      "module": "scheduling",
      "platform": "web",
      "status": "eng",
      "created": "2026-07-02",
      "affects": [], "depends_on": [],
      "badges": { "productTuned": true, "engTuned": true, "reviewed": false },
      "completion": "building",
      "completionSource": "branch feat/prd-100-calendar-scheduling exists",
      "detail": "<full PRD markdown body as a plain string>",
      "hasTodos": false,
      "features": [
        { "id": "F1", "title": "Booking page creation",
          "todos": [ { "id": "F1-T1", "title": "Booking page route",
                       "objective": "Let a host publish a bookable page",
                       "type": "code", "priority": "P0",
                       "files": [ { "path": "src/x.ts", "action": "add" } ],
                       "file": "src/x.ts", "action": "add",
                       "dependsOn": [], "doneWhen": "…", "done": false } ] }
      ]
    }
  ],
  "testIssues": [
    {
      "file": "msg-test/test-1.json",
      "runId": 1,
      "verdict": "fail",
      "context": { "prd": "features/prd-100-calendar-scheduling/prd-100-calendar-scheduling.md", "branch": "feat/prd-100-calendar-scheduling", "base": "main" },
      "summary": { "failed": 2, "flaky": 1, "warnings": 0 },
      "followUp": { "status": "open" },
      "tickets": [
        { "kind": "issue", "id": "unit-002", "title": "expected streak to persist across days",
          "objective": "Restore correct behavior — expected streak to persist across days",
          "type": "test", "priority": "P0",
          "files": [ { "path": "src/streak.ts", "action": "edit" } ],
          "dependsOn": [], "doneWhen": "`npm test -- streak` passes and the covering test file is green",
          "severity": "blocker", "category": "unit", "rule": "streak persists across days",
          "repro": "npm test -- streak", "evidence": { "snippet": "Expected 1 to be 2" },
          "suggestion": "reset streak only when a day is missed", "flaky": false }
      ]
    }
  ],
  "skipped": [ { "path": "features/prd-77/prd-77.md", "reason": "unparseable frontmatter" } ]
}
```

Notes:
- `badges` values are `true` / `false` / `null` (absent). The GUI renders `null` as an
  un-set pill, never a crash (edge case 2).
- `detail` is the raw PRD body (everything after the frontmatter). The GUI shows it in a
  collapsible block and escapes it — do not pre-render HTML.
- `completion` must be one of `product | eng | building | review | shipped`.
- `testIssues[]` — one entry per `msg-test/test-<n>.json` (Step 1b). `verdict` is
  `fail | pass_with_warnings`; `followUp.status` is `open | resolved | partially_resolved`
  (written back by `eng --build` — the board **renders** it, never invents it). Each `tickets[]`
  entry is a projected issue-ticket (`kind: "issue"`) carrying the same positional fields a todo
  has (`id`/`title`/`objective`/`type`/`priority`/`files`/`dependsOn`/`doneWhen`) **plus** the
  preserved diagnostic fields (`severity`, `category`, `rule`, `repro`, `evidence.snippet`,
  `suggestion`, `flaky`). Absent `msg-test/` → `testIssues: []` (edge case 5).

## Step 4 — Fill the templates

1. Read `refs/gui/index.html` and `refs/gui/styles.css`.
2. Replace `__STYLES__` (inside the `<style>` tag) with the full contents of `styles.css`.
3. Replace `__PRD_DATA__` (inside the `application/json` script) with the JSON from Step 3,
   **exactly once**, as valid JSON (it is read via `JSON.parse`, so it is inherently safe —
   no HTML escaping needed inside the JSON).
4. Write the single filled file to a fresh temp dir, e.g.
   `DIR=$(mktemp -d) && cp <filled> "$DIR/index.html"`. Do **not** write generated output
   into the repo (keeps the read-only guarantee and avoids accidental commits).

Templates must stay as files under `refs/gui/` — never inline the HTML/CSS as one big string
in this protocol (criterion 25). The design system in `styles.css` is hardcoded and identical
across every project; it is **not** sourced from `devkit/DESIGN-SYSTEM.md` (criterion 26).

## Step 5 — Serve, open, tear down

1. Serve GET-only, bound to loopback:
   `python3 -m http.server <port> --bind 127.0.0.1 --directory "$DIR"` (run in background).
   Pick a free port; if the chosen port is in use, try the next few and report the one used.
2. Open the default browser at `http://127.0.0.1:<port>/`. If the browser can't be opened,
   print the URL so the user can open it manually (error case 3).
3. The app is entirely static — there are no POST handlers or write endpoints; the only
   traffic is GETs for `index.html` (criterion 8).
4. Tear the server down when the user says they're done, or after a short idle timeout
   (criterion 9). Note the PID/URL so it can be stopped cleanly.

### Error cases
- `python3` missing or every candidate port busy → surface it to the user, don't fail
  silently (error case 1).
- Malformed PRD frontmatter → that PRD is in `skipped[]` and flagged in the board header;
  the rest still render (error case 2).
- Browser won't open → print the `127.0.0.1` URL (error case 3).

---

## Test Issues surface + PRD cross-link (rendering)

- **A distinct surface, not a PRD column.** Because a test issue may have no PRD (`context.prd: null`), `testIssues[]` render in their own **Test Issues** grouping on the board — one card per `msg-test/test-<n>.json` showing its `runId`, a `fail`/`pass_with_warnings` verdict pill, the `summary` counts, and the `followUp.status`.
- **Every ticket is tagged by `kind`.** Todos render as before; issue-tickets get a distinct **🐞 Bug / Test issue** tag, surface `severity` as a coloured pill (not just `priority`), and expose `repro` + `evidence.snippet` in the side panel.
- **Real done-state for issues.** Unlike a todo (no stored done-state → always **Open**), an issue-ticket's `followUp.status` is written back by `eng --build`, so a Test Issues card shows an honest Open/Resolved state and a real progress fraction — the GUI renders a field the file already carries, never inventing state.
- **PRD cross-link (criterion 31).** When a `testIssues[]` entry's `context.prd` matches an enumerated PRD's path, its `tickets[]` **also** surface on that PRD's detail page inside the TODOs section, tagged `kind: "issue"` so they read as bugs against the PRD rather than build work. A `context.prd` matching no enumerated PRD appears only in the Test Issues surface (edge case 6).

## What this protocol never does
- Never writes or edits a PRD (pure read model, criterion 14 / 24), and never writes back to a
  `msg-test/test-<n>.json` file — the finding→ticket projection is read-time only; `followUp.status`
  is written solely by `eng --build`, and the board merely renders it.
- Never invents or persists **todo** done-state — with no stored field, all todos show as **Open**
  and progress reads `0/N` only where todos exist (never `0/0`; edge cases 3, 5). **Issue** done-state
  is different: it is read from the file's `followUp.status`, not invented.
- Never binds to anything but `127.0.0.1` (criterion 6).

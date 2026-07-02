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
   feature's `### F<n>` block and parse its items (`type`, `file`, `action`, `done-when`).
   Attach each item to the matching `features[].id`. **No done-state field exists in the todo
   schema yet** (see the feature's P0 prerequisite) — set every item's `done` to `false`.
   PRDs with no `## Todos` section get `hasTodos: false` and no todo items (edge case 3).

Never write or modify any PRD file (criterion 14).

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
          "todos": [ { "type": "code", "file": "src/x.ts", "action": "add",
                       "doneWhen": "…", "done": false } ] }
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

## What this protocol never does
- Never writes or edits a PRD (pure read model, criterion 14 / 24).
- Never invents or persists todo done-state — with no stored field, all todos show as **Open**
  and progress reads `0/N` only where todos exist (never `0/0`; edge cases 3, 5).
- Never binds to anything but `127.0.0.1` (criterion 6).

---
name: Plan Protocol
description: End-to-end five-step autonomous protocol for plan-pm — resolve a graded intake row, scan prior PRDs, draft the full PRD solo, pause only for batched open questions + breaking/critical touches, stamp the intake lifecycle, terminate.
type: reference
---

# Plan Protocol

The five-step protocol plan-pm follows end-to-end. In `--sub` mode, substitute the nested sub-PRD path
(§ Sub-PRD mode, delta D3) everywhere the steps write the drafted PRD's own path
`features/planned/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md`.

**Autonomy contract (F3).** The interview is gone — it moved to `/intake`, which
delivers a graded, fleshed-out row (`idea`, `goal`, `type`, `grade`). plan-pm drafts
the **full PRD solo** — objective, scope boundaries, feature/acceptance table, error
cases — with **no per-section gates**. Do not re-interview the user and do not
gate section by section: the instinct to check in mid-draft is the one this contract
overrides. It pauses for **exactly two** things: batched open questions the draft
couldn't resolve (Step 4), and breaking/critical touches (Step 4 safety pause).
Nothing else.

## Step 1/5 — Resolve the intake row

**Every PRD is planned from an `INTAKE.md` row. There is no other entry path** — no
PRD is ever drafted against a row that does not exist, which is what lets `plan-review`
check 3 compare every PRD against its source intent. Two ways in:

1. **No args** → read `INTAKE.md` (repo root). List every **non-`completed`** row
   (`# · type · idea · grade · status`). If the ledger is missing or empty, emit
   `No backlog rows — capturing this idea through /intake first.` and take path 3
   below if the user supplied prose; otherwise stop and ask them for an idea.
   Otherwise `AskUserQuestion` (single-select, up to 4 rows per call; page if more) —
   "Which idea should I plan?" — and take the pick.
2. **Intake row reference** (`#n`) **or explicit idea text that matches a row** → resolve
   it against `INTAKE.md` and plan it directly, no picker.
3. **Direct prose with NO matching intake row** → **capture it, do not bounce it back.**
   Invoke `Skill("intake", "<the user's prose verbatim>")` — intake's capture mode
   interviews within its ≤2-question budget, grades the idea against its own rubric
   (`C:`/`T:`/`S:` bands) and appends the row. Then re-read `INTAKE.md`, take the newly
   appended row, and continue as path 2. `intake` stays the sole writer of new rows
   (D14); plan-pm never appends one itself. If capture returns no row (the user
   abandoned it), stop — there is nothing to plan.

The capture happens **here, before Step 2** — the prior-PRD scan reconciles against the
row's `S:blocked-by-#n` grade, which does not exist until the row does.

Hold the resolved row in context: `idea`, `goal`, `type`, `grade`, and its `#`
(for the Step 5 stamp). A `--sub` invocation seeds from the parent and captures its own
marked row instead (§ Sub-PRD mode, D2). Produce no file in this step.

## Step 2/5 — Scan prior PRDs for overlap + breaking surface

Enumerate prior PRDs with the deterministic lane-aware scanner (two-path resolution, as in
Step 3 Part 1) rather than a lane-blind glob — it emits one JSONL object per PRD across all
lanes (`planned/`, `wip/`, `done/`) and the legacy flat path, nested sub-PRDs included:

```bash
S=.claude/scripts/script-prd-scan.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-scan.sh"; bash "$S"
```

If it emits nothing, emit `No prior PRDs.` and proceed. Otherwise, for each prior PRD line:
1. Read its `deps` from the JSONL first for a fast signal (no file open). The scan emits
   `deps` for a PRD of either shape, so this one read covers the whole inventory.
2. **The overlap scan is `deps` + §3 Dependencies, and nothing else.** v5.4 removed the
   `module` and `affects` fields, so there is no domain-keyword shortcut: when a prior PRD
   is named in the new idea's dependency chain, or its own `deps` reach into the area the
   new idea touches, flag it and read its §3 features section in full. Older PRDs may still
   carry `module`/`affects` values — treat them as a hint, never as a required input.
3. Classify and hold for Step 3 frontmatter:
   - **Dependency** (`deps`): the new PRD requires a prior PRD's output. Record its ID.
4. **Breaking-surface flag:** if the new idea would **break a shipped PRD's contract**
   (redefine an F-ID's acceptance criterion another PRD depends on, or overlap a shipped
   feature), mark it — this arms the Step 4 safety pause.

The intake `grade` cell's `S:blocked-by-#n`/`prd-<n>` is a second dependency signal — reconcile it with the scan.

## Step 3/5 — Autonomous draft (pre-flight + populate)

**Part 1 — Pre-flight.** Resolve the next PRD number (ships in the global scripts dir; resolve there when the project has no vendored copy):

```bash
S=.claude/scripts/script-prd-number; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-number"; bash "$S" prd
```

Store as `n`. Detect the platform from `devkit/ARCHITECTURE.md` (do not ask):

```bash
bash -c '[[ -f devkit/ARCHITECTURE.md ]] || exit 0; for e in "Expo:\bExpo\b" "Flutter:\bFlutter\b" "React Native:\bReact Native\b" "iOS:\biOS\b" "Android:\bAndroid\b" "Desktop:\b(Electron|Tauri)\b" "Web:\b(web app|web application|web frontend|web client|browser|SPA|PWA)\b" "Backend:\b(REST API|GraphQL|microservice|server-side|backend|API server)\b"; do grep -qiE "${e#*:}" devkit/ARCHITECTURE.md && echo "${e%%:*}"; done'
```

The detected platform is **not** written to the PRD — v5.4 removed the `platform` field, and
every downstream stage that needs it re-runs this same grep against `devkit/ARCHITECTURE.md`.
Use it here only to shape §2 Out-of-scope (non-targeted platforms) and to steer the draft.
Empty output → note the undetectable platform as a §5 open question. Derive `feature_slug`:
kebab-case, ≤6 words, lowercase + hyphens, from the intake `idea`.

**Part 2 — Initialize template.** A freshly-drafted PRD always starts in the `planned/`
lane. Create `features/planned/` and `features/planned/prd-[n]-[feature_slug]/`
if absent. Write `features/planned/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md` from
`refs/template-prd.md` with frontmatter:
- `name`: `prd-[n]-[feature_slug]` · `feature`: short name from the `idea`
- `summary`: 2–3 sentence single-line plain-prose gist (core objective + headline features), reconciled in Part 3
- `deps`: seed with the prior-PRD IDs from Step 2 (`[]` if none); it is **reconciled against §3 at the end of Part 3** (§ Dependency mirroring) — §3 is the source of truth for cross-PRD edges
- `status: backlog` — the first rung of the lifecycle enum (`backlog` → `specced` → `wip` → `complete`). plan-pm only ever writes `backlog`; plan-em stamps `specced` and `wip`, and `merge --production` stamps `complete`
- `reviewed: no` · `created`: today `YYYY-MM-DD`
- **`intake: #<n>`** — the source intake row `#`. Always present; every PRD has an
  ancestor row (Step 1)

There is no `module`, `platform` or `affects` field, and no `product-tuned`/`eng-tuned`
pair — v5.4 removed all five. Never write them into a new PRD, even when a prior PRD in
the same repo still carries them.

**Part 3 — Populate every section solo.** Draft each section from the intake `idea` +
`goal` + prior-PRD context — autonomously, no interview, no per-section gate. Two scope
rules govern the whole draft:

- **One problem, one PRD.** A single PRD addresses one user problem. If the resolved row
  spans multiple problems, surfaces, or ship cycles, propose a split into separate PRDs
  rather than bundling them.
- **Only what was asked.** Every requirement traces to the intake row. If something seems
  missing, raise it as a §5 open question — never silently add it to the PRD.

Canonical order per `refs/template-prd.md`:

| Section | Autonomous source |
|---------|-------------------|
| 1. Product objective | **Three terse bullets** from the intake `goal` — who / what changes / success signal, one line each. A product spec, not an essay and not engineering: no feature list, no implementation, no paragraph |
| 2. Out-of-scope | Boundaries the draft draws around the idea; non-targeted platforms auto-added |
| 3. Features & acceptance criteria | Derive the feature set from the idea; assign sequential F-IDs; one observable user-goal acceptance criterion per feature; Dependencies column from Step 2. Free of engineering detail (no APIs, schemas, components, files) |
| 4. Error cases | Draft the concrete, triggerable error/edge cases **per §3 feature** (invalid input, network/permission failures, empty states, auth expiry, external-service failure, rate limits, race conditions, timezone/date boundaries). Format + rules in `refs/template-prd.md` §4. **No row quota** — write the failure modes the §3 features actually have; padding a short table to hit a count is worse than the short table. Genuinely unresolvable ones → Step 4 open questions |
| 5. Open questions | Overlap from Step 2 + relevant `devkit/AHA.md` entries + anything the draft couldn't resolve, as `\| # \| Question \| Answer \| Status \|` rows (`Status = Open`) |
| 6. Feature execution table | Leave the `_To be populated by plan-em …_` placeholder — plan-em owns it |
| 7. Todos | Leave the `_Populated by eng --plan …_` placeholder — `eng --plan` owns it |

There is no `Plan review findings` section any more. `plan-review` writes its ledger to
`<prd-dir>/reports/review-prd-[n]-[slug].md` and stamps `reviewed:` in the frontmatter —
never create a findings section in a new PRD.

New domain terms go straight into `devkit/GLOSSARY.md`, where the whole pipeline sees
them — the PRD carries no glossary of its own.

Carry every F-ID into §3 unchanged — plan-em keys §6 on them. Reconcile the frontmatter
`summary` against the finalized §1 + §3 (single-line, plain prose). Components and files
are engineering detail → §6 (plan-em), never the product sections.

**Part 4 — Dependency mirroring (mechanical, never skipped).** §3 is the source of truth
for cross-PRD edges: **every** `prd-<n>-<slug>` id in a §3 Dependencies cell must also appear
in frontmatter `deps`. Do not author the two independently — after §3 is finalized,
reconcile the frontmatter *from* §3 so the two cannot drift (`plan-review` check 6 is a backstop,
not the primary catch). Run the deterministic mirror — it extracts every `prd-<n>-<slug>` token
from the §3 Dependencies column (external services / data sources / intra-PRD F-IDs are **not**
mirrored), unions it with the seeded array, and rewrites `deps` in place (`[]` when empty). On a
PRD written before v5.4 it rewrites that file's `depends_on` line instead, so nothing is migrated:

```bash
PRD=features/planned/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md
S=.claude/scripts/script-prd-deps-mirror.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-deps-mirror.sh"; bash "$S" "$PRD"
```

It prints `ADDED <id>` for each newly-mirrored id and is idempotent. Sub-PRD ids
(`prd-2.1-slug`) count. No file / no frontmatter → exit 2.

**Part 5 — Shape check (mechanical, never skipped).** The template is only a contract if
something verifies it was followed. Run the shape validator on the drafted PRD — it is the
last action of Step 3 and it gates Step 4:

```bash
S=.claude/scripts/script-prd-shape.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-shape.py"; python3 "$S" "$PRD"
```

It prints one `FAIL check=<n> code=<slug> ref=<locator> detail=…` line per defect and a
`SUMMARY checks=5 failures=<n>` line, exiting `1` on any failure and `2` on a usage or
read error. **Exit 1 → fix the PRD and re-run until it exits 0** — never proceed to Step 4
on a failing shape, and never edit the checker to match the draft.

## Step 4/5 — Pauses (open questions + safety) — the ONLY pauses

**Open questions.** Batch everything the draft couldn't resolve into **one**
`AskUserQuestion` (≤4 questions per call, `multiSelect` where apt; each entry offers plausible
answers + "Skip"). Apply every answer **autonomously** — write it into the relevant section and
mark its §5 row `Addressed`. Skipped questions stay `Open`. No open questions → skip this pause
entirely.

**Breaking-change / critical-cut safety pause (never relaxed).** If Step 2 flagged a
breaking surface — the draft would **break a shipped PRD's contract**, or cut into
**DB / data / production-config** territory — pause via `AskUserQuestion` before finalizing:
name the exact contract/surface at risk and ask how to proceed (proceed with the break
documented / rescope to avoid it / stop). This is a safety-floor gate, distinct from the
open-questions batch; it fires even when there are no open questions.

## Step 5/5 — Stamp the intake lifecycle, then terminate

**AHA.md update (conditional).** Record a learning in `devkit/AHA.md` when this run
surfaced one (a CLAUDE.md rule invalidated a feature; prior-PRD overlap recorded; a safety
pause fired). Create `devkit/AHA.md` from
`.claude/skills/msg/refs/init/templates/template-AHA.md` if absent, then go through the
file's one writer — never hand-append. Each field is one terse clause (≤140 chars; the
writer rejects longer):

```bash
A=.claude/scripts/script-aha.sh; [ -f "$A" ] || A="$HOME/.claude/scripts/script-aha.sh"
bash "$A" devkit/AHA.md --tag "pm:<class>" --summary "<what happened>" --why "<root cause>" --note "<action or warning for future runs>"
```

`--tag` names the class (e.g. `pm:claude-md-conflict`, `pm:prd-overlap`, `pm:safety-pause`) —
same tag for the same class every time, so recurrences count. Write only on a real learning.

**Intake lifecycle stamp (F4).** Always stamp the source row — every PRD has one (Step 1).
Write it in `INTAKE.md` via the shared ledger writer — set its `status` cell to `in-progress`
and its `prd` cell to `prd-[n]-[feature_slug]`. `<row-#>` is the resolved row's `#` held from
Step 1. The writer edits only that row's two cells, preserving every other row verbatim:

```bash
S=.claude/scripts/script-intake-stamp.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-intake-stamp.sh"; bash "$S" INTAKE.md <row-#> --status in-progress --prd prd-[n]-[feature_slug]
```

Missing `INTAKE.md` → the writer exits 2; skip with a one-line note. Row not found → exit 1.

**Follow-up ask.** **One** final `AskUserQuestion` (single-select) — "Anything to follow up
on this PRD?":
- **No, done** — terminate.
- **Yes** — capture the follow-up (batched, ≤4), apply it autonomously, then terminate.

There is no separate completion line: the PRD path and the open-questions count are
mandatory rows of the closing message (SKILL.md § Step-by-step protocol), which is the
run's last output. Take the next step from the `closing-message.md` registry's plan-pm
row — `/plan-em` on green — and **recommend** it, never invoke it.

**Multi-PRD note.** There is no multi-PRD loop in v2 — compound asks are split into discrete
rows at `/intake` (hybrid-ask detection + the ≥8-split gate), so plan-pm always plans exactly one
row per run. To plan another backlog row, run `/plan-pm` again.

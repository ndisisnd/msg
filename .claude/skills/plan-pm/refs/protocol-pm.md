---
name: Plan Protocol
description: End-to-end five-step autonomous protocol for plan-pm — resolve a graded intake row, scan prior PRDs, draft the full PRD solo, pause only for batched open questions + breaking/critical touches, stamp the intake lifecycle, terminate.
type: reference
---

# Plan Protocol

The five-step protocol plan-pm follows end-to-end. Emit progress per § Progress
emission in SKILL.md. In `--sub` mode, substitute the nested sub-PRD path
(§ Sub-PRD mode, delta D3) everywhere the steps say
`features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md`.

**Autonomy contract (F3).** The interview is gone — it moved to `/intake`, which
delivers a graded, fleshed-out row (`idea`, `goal`, `type`, `grade`). plan-pm drafts
the **full PRD solo** — edge cases, feature/acceptance table, user flows, error
handling — with **no per-section gates**. It pauses for **exactly two** things:
batched open questions the draft couldn't resolve (Step 4), and breaking/critical
touches (Step 4 safety pause). Nothing else.

## Step 1/5 — Resolve the idea (entry paths)

Determine what to plan. Three entry paths:

1. **No args** → read `INTAKE.md` (repo root). List every **non-`completed`** row
   (`# · type · idea · grade · status`). If the ledger is missing or empty, emit
   `No backlog rows — run /intake to capture an idea first.` and offer to hand off to
   `/intake` (recommend, do not invoke). Otherwise `AskUserQuestion` (single-select, up
   to 4 rows per call; page if more) — "Which idea should I plan?" — and take the pick.
2. **Intake row reference** (`#n`) **or explicit idea text that matches a row** → resolve
   it against `INTAKE.md` and plan it directly, no picker.
3. **Direct prose with NO matching intake row** → offer **one bounce**: `AskUserQuestion`
   "Log this through `/intake` first so it's graded in the backlog?" — **Yes** hands off to
   `/intake` (recommend it, then resume on the new row); **No, plan it now** proceeds
   directly but **notes the ledger gap** (a PRD with no intake ancestor — plan-tune check 3
   will skip intent-fidelity with a note).

Hold the resolved row in context: `idea`, `goal`, `type`, `grade`, and its `#`
(for the Step 5 stamp). A `--sub` invocation pre-seeds from the parent instead
(§ Sub-PRD mode, D2). Produce no file in this step.

## Step 2/5 — Scan prior PRDs for overlap + breaking surface

List `features/prd-*/prd-*.md` via `Bash`. If none exist, emit `No prior PRDs.` and
proceed. Otherwise, for each prior PRD:
1. Read its YAML frontmatter (`module`, `affects`, `depends_on`) first for a fast signal.
2. If the new idea's domain matches a prior PRD's `module`, or the prior PRD's `affects`
   references the new area, flag it and read its features section in full.
3. Classify and hold for Step 3 frontmatter:
   - **Dependency** (`depends_on`): the new PRD requires a prior PRD's output. Record its ID.
   - **Affects** (`affects`): the new PRD modifies scope/contracts a prior PRD also touches. Record its ID.
4. **Breaking-surface flag:** if the new idea would **break a shipped PRD's contract**
   (redefine an F-ID's acceptance criterion another PRD depends on, or overlap a shipped
   feature), mark it — this arms the Step 4 safety pause.

The intake `grade` cell's `S:blocked-by-#n`/`prd-<n>` is a second dependency signal — reconcile it with the scan.

## Step 3/5 — Autonomous draft (pre-flight + populate)

**Part 1 — Pre-flight.** Resolve the next PRD number (ships in the global scripts dir; resolve there when the project has no vendored copy):

```bash
S=.claude/scripts/scan-n.prd; [ -f "$S" ] || S="$HOME/.claude/scripts/scan-n.prd"; bash "$S" prd
```

Store as `n`. Detect the platform from `devkit/ARCHITECTURE.md` (do not ask):

```bash
bash -c '[[ -f devkit/ARCHITECTURE.md ]] || exit 0; for e in "Expo:\bExpo\b" "Flutter:\bFlutter\b" "React Native:\bReact Native\b" "iOS:\biOS\b" "Android:\bAndroid\b" "Desktop:\b(Electron|Tauri)\b" "Web:\b(web app|web application|web frontend|web client|browser|SPA|PWA)\b" "Backend:\b(REST API|GraphQL|microservice|server-side|backend|API server)\b"; do grep -qiE "${e#*:}" devkit/ARCHITECTURE.md && echo "${e%%:*}"; done'
```

Empty output → `platform: TBD` and record it as an open question. Derive `feature_slug`:
kebab-case, ≤6 words, lowercase + hyphens, from the intake `idea`.

**Part 2 — Initialize template.** Create `features/` and `features/prd-[n]-[feature_slug]/`
if absent. Write `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md` from
`refs/template-prd.md` with frontmatter:
- `name`: `prd-[n]-[feature_slug]` · `feature`: short name from the `idea`
- `summary`: 2–3 sentence single-line plain-prose gist (core objective + headline features), reconciled in Part 3
- `module`: primary domain inferred from the idea · `platform`: detected above
- `affects` / `depends_on`: prior-PRD IDs from Step 2 (`[]` if none)
- `status: product` · `product-tuned: no` · `eng-tuned: no` · `reviewed: no` · `created`: today `YYYY-MM-DD`
- **`intake: #<n>`** — the source intake row `#` (omit only on the no-intake-ancestor path from Step 1.3)

**Part 3 — Populate every section solo.** Read `refs/principles.md` first and apply it
throughout. Draft each section from the intake `idea` + `goal` + prior-PRD context —
autonomously, no interview, no per-section gate. Canonical order per `refs/template-prd.md`:

| Section | Autonomous source |
|---------|-------------------|
| 1. Product objective | One paragraph from the intake `goal` — the user/business outcome that defines success. No feature list, no implementation |
| 2. Out-of-scope | Boundaries the draft draws around the idea; non-targeted platforms auto-added |
| 3. User flow | One ASCII user-visible flow per feature; dependencies (Step 2) as preconditions. No engineering detail |
| 4. Key user interactions | The core actions the feature must support, derived from the idea + goal |
| 5. Error cases | Draft the concrete, triggerable error/edge cases per feature (invalid input, network/permission failures, empty states, auth expiry, external-service failure, rate limits, race conditions, timezone/date boundaries). Format from `refs/template-error.md`. Genuinely unresolvable ones → Step 4 open questions |
| 6. Features & acceptance criteria | Derive the feature set from the idea; assign F-IDs (`refs/template-feature-table.md`); one observable user-goal acceptance criterion per feature; Dependencies column from Step 2. Free of engineering detail (no APIs, schemas, components, files) |
| 7. Feature execution table | Leave the `_To be populated by plan-em …_` placeholder — plan-em owns it |
| 8. Open questions | Overlap from Step 2 + relevant `devkit/AHA.md` entries + anything the draft couldn't resolve, as `\| # \| Question \| Answer \| Status \|` rows (`Status = Open`) |
| 9. Plan tune findings | Leave the `_Populated by plan-tune …_` placeholder — plan-tune owns it |
| 10. Glossary | GLOSSARY.md cross-reference; add new terms from this PRD |
| 11. Todos | Leave the `_Populated by /todo …_` placeholder |

Carry every F-ID into §6 unchanged — plan-em keys §7 on them. Reconcile the frontmatter
`summary` against the finalized §1 + §6 (single-line, plain prose). Components and files
are engineering detail → §7 (plan-em), never the User flow.

## Step 4/5 — Pauses (open questions + safety) — the ONLY pauses

**Open questions.** Batch everything the draft couldn't resolve into **one**
`AskUserQuestion` (≤4 questions per call, `multiSelect` where apt; each entry offers plausible
answers + "Skip"). Apply every answer **autonomously** — write it into the relevant section and
mark its §8 row `Addressed`. Skipped questions stay `Open`. No open questions → skip this pause
entirely.

**Breaking-change / critical-cut safety pause (never relaxed).** If Step 2 flagged a
breaking surface — the draft would **break a shipped PRD's contract**, or cut into
**DB / data / production-config** territory — pause via `AskUserQuestion` before finalizing:
name the exact contract/surface at risk and ask how to proceed (proceed with the break
documented / rescope to avoid it / stop). This is a safety-floor gate, distinct from the
open-questions batch; it fires even when there are no open questions.

## Step 5/5 — Stamp the intake lifecycle, then terminate

**AHA.md update (conditional).** Append a learning to `devkit/AHA.md` when this run
surfaced one (a CLAUDE.md rule invalidated a feature; prior-PRD overlap recorded; a safety
pause fired). Format:

```
### [YYYY-MM-DD] <Summary title>
**Why**: <Root cause>
**Note**: <Concrete action or warning for future runs>
```

Under `## Entries`, most recent first. Create `devkit/AHA.md` from
`.claude/skills/msg/refs/init/templates/template-AHA.md` if absent. Write only on a real learning.

**Intake lifecycle stamp (F4).** Unless this PRD had no intake ancestor (Step 1.3), stamp the
source row in `INTAKE.md` via `Bash` — set its `status` cell to `in-progress` and its `prd`
cell to `prd-[n]-[feature_slug]`. This is plan-pm's write to the ledger; edit only that row's
two cells, preserving every other row verbatim. Missing `INTAKE.md` → skip with a one-line note.

**Completion summary + follow-up ask.** Emit:

```
PRD generated for <feature>. There are <value> open questions.
```

Then **one** final `AskUserQuestion` (single-select) — "Anything to follow up on this PRD?":
- **No, done** — terminate.
- **Yes** — capture the follow-up (batched, ≤4), apply it autonomously, then terminate.

On termination, **recommend** (never invoke) `plan-tune --product` on this PRD as the next step:
`Next: run /plan-tune --product on features/prd-[n]-[feature_slug]/… to certify the contract.`

**Multi-PRD note.** There is no multi-PRD loop in v2 — compound asks are split into discrete
rows at `/intake` (hybrid-ask detection + the XL-split gate), so plan-pm always plans exactly one
row per run. To plan another backlog row, run `/plan-pm` again.

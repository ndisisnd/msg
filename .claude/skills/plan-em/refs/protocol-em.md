---
name: EM Protocol
description: End-to-end five-step execution protocol for plan-em — validate/pre-flight, PRD tune gate, roster, agents write, synthesise
type: reference
---

# EM Protocol

The five-step protocol plan-em runs end-to-end, after Step 0 (todo preference) resolves `$TODOS`. Emit progress per § Progress emission in SKILL.md (`Step X/5 — <title>`). Ref paths (`refs/principles.md`, `refs/template-exec-table.md`) resolve relative to the skill root.

## Step-by-step protocol

---

**Step 1/5 — Validate and pre-flight**

**1a. Validate PRD path.** Must exist and match `features/prd-*/prd-*.md` (top-level) **or** `features/prd-*/prd-*/prd-*.md` (nested sub-PRD, e.g. `features/prd-2-habit-tracking/prd-2.1-streak-freeze/prd-2.1-streak-freeze.md`).
- Store the matched PRD's own parent directory as `$PRD_DIR`; write **every** artifact relative to `$PRD_DIR`, never a reconstructed `features/prd-[n]/`.
- Derive `n` = first numeric segment of that parent dir name (`prd-3-habit-tracking` → `n=3`; `prd-2.1-streak-freeze` → `n=2`, the parent's number for a sub-PRD).
- On failure: refuse, emit the rule, produce no output.

**1b. Mandatory pre-flight scan (devkit + PRD).** Devkit files live in `devkit/` (created by `msg-init`); `CLAUDE.md` is at project root. Read all, in order:

| # | Source | Read for / action |
|---|--------|-------------------|
| 1 | `devkit/AHA.md` | Past learnings applicable to this PRD's domain/feature type. Note every directly-relevant entry. |
| 2 | `devkit/GLOSSARY.md` | Canonical term definitions. Flag PRD terms that deviate. |
| 3 | `devkit/ARCHITECTURE.md` | System constraints, existing layers, integration points. Note constraints affecting the PRD's features. |
| 4 | `CLAUDE.md` (root) | Tech-stack constraints, naming conventions, arch notes. Note conventions that constrain agent scope / eng choices this run. |
| 5 | `devkit/DESIGN-SYSTEM.md` | Component registry. Per component note: which PRD features impact it, which reuse it unchanged, which need new data ingestion. Feeds the pre-flight report; constrains frontend agent scope. |
| 6 | `devkit/OPEN-QUESTIONS.md` | Unresolved decisions overlapping this PRD's domain/features. Note each under a new **Open questions** section; if one directly blocks a feature, flag as a blocking gap. |
| 7 | Input PRD | **Via its digest slice, not full prose** (see below). |

**Item 7 — PRD digest slice.** Run the PRD-digest generator for plan-em's `plan` slice; consume the JSON it prints:

```bash
G=.claude/scripts/scan-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/scan-prd-digest.py"; python3 "$G" "<PRD path>" --slice plan
```

The `plan` slice returns `frontmatter` (incl. `platform`, `module`, `affects`, `depends_on`), `summary`, `features` (F-IDs + acceptance criteria verbatim), and `exec_table` — the inputs the roster and exec-table build consume (Steps 3–4). The generator re-parses the current PRD on every call → the slice is never stale and PRD prose stays canonical (see `.claude/skills/shared/refs/session-cache.md`). **Escape hatch:** if a pre-flight check needs prose the slice omits — User-flow narrative for a terminology/architecture-conflict finding, or a heading under the digest's `unparsed_sections` — read only that section's `prose_lines` range. Do **not** default to the whole PRD.

**Absent-file rule.**
- No `devkit/` → emit `devkit/ not found — run /msg-init to initialise the project first.` and **stop** (do not proceed to Step 2).
- `devkit/` exists but a file missing → emit `<filename> not found — run /msg-init to initialise the project first.` Proceed without it; do not create it.

**1c. Multi-PRD cross-reference.** Run `bash ls features/prd-*/prd-*.md`, excluding the input PRD's directory. For each prior PRD:
1. **Fast scan via frontmatter first** — read `module`, `affects`, `depends_on`. Flag immediately if: input's `module` matches another's `module`; input appears in another's `affects`; or input's `depends_on` names a prior PRD.
2. **Full read only when flagged** — read the flagged PRD's features section in full and classify:

   | Relationship | Definition |
   |--------------|------------|
   | **Dependency** | Input's `depends_on` lists this PRD; it must ship first or be in flight. Confirm current status. |
   | **Breaking change** | Input's features alter a contract/schema/module a prior PRD owns (may break a shipped feature). Name the specific contract at risk. |
   | **Overlap** | The two PRDs share user-facing scope with no clear ownership boundary. |
3. **No frontmatter** — fall back to reading every prior PRD's features section and compare against the input's features.

If any flagged PRD is found, present via one `AskUserQuestion` per relationship type, options per type:

| Type | Options |
|------|---------|
| Dependency | Confirm dependency satisfied / Merge dependency into this plan / Stop and ship the dependency first / Proceed at risk |
| Breaking change | Add backward-compat shim / Coordinate with owning PRD author / Proceed with explicit breakage noted / Stop and reconcile |
| Overlap | Reuse existing / Refactor existing / Proceed with parallel implementation / Stop and reconcile with PRD author |

**Frontmatter writeback** — after all resolutions, `Edit` the input PRD's YAML frontmatter:
- Add newly-confirmed dependency PRD IDs to `depends_on` (merge, no duplicates).
- Add newly-confirmed overlap/breaking-change PRD IDs to `affects` (merge, no duplicates).
- If `module` is blank/placeholder, infer from the PRD's feature domain and set it.
- Also update any prior PRD's `affects` to include the input PRD's ID when the input is confirmed to break/overlap that prior PRD's scope.

**1d. Write pre-flight report** to `$PRD_DIR/preflight.md` (create or overwrite), containing all findings in full:
- **Terminology deviations** — PRD terms not matching GLOSSARY.md
- **Architecture conflicts** — features contradicting/ignoring ARCHITECTURE.md
- **AHA.md warnings** — applicable past learnings
- **Design system impact** — components impacted, data-ingestion needs, new components required (from DESIGN-SYSTEM.md scan)
- **Multi-PRD findings** — dependencies, breaking changes, overlaps, each classified and actioned
- **PRD gaps** — sections too ambiguous/incomplete to map domains

Do not hold the full report in context. After writing, emit inline **only actionable findings** (those needing a decision before proceeding: blocking PRD gaps, architecture conflicts, multi-PRD questions). Suppress informational findings (AHA.md warnings, terminology notes, design-system observations) inline — they live in `preflight.md`, available on request.

---

**Step 2/5 — PRD tune gate**

Checks whether the **PM/product tune** (`plan-tune --product`) has run. Does **not** check eng tune — the eng tune (`plan-tune --eng`) audits engineering output and is prompted at Step 5 *after* agents write. Full sequence:

```
plan-tune --product  →  plan-em  →  [agents write]  →  plan-tune --eng
```

Read the PRD's `product-tuned:` frontmatter (from Step 1):
- `product-tuned: yes` → product tune already ran; skip the gate, proceed straight to agent identification.
- `product-tuned: no` or absent → note it in the question context and ask via `AskUserQuestion`:
  - **Run plan-tune --product first** — emit handoff: "Run `/plan-tune $PRD_DIR/prd-[n]-[slug].md --product` to tune the PRD before engineering planning." (Use resolved `$PRD_DIR` and `n`.) Then stop.
  - **Continue without tune** — proceed to agent identification.

Do not activate any agent until the user responds.

---

**Step 3/5 — Identify agents and get approval**

**3a — Compile coding standards (flags) to confirm agent types.** Before proposing any roster, derive platform identifiers from the PRD frontmatter `platform` field and the Features & acceptance criteria table. Then call `/cook` **once per implied platform via explicit flags** — never a prose summary — using the stack→flag derivation in `.claude/skills/eng/refs/build/protocol.md` (§ Coding-standards flags): `--global` (guarantees the P0 floor) plus the platform's domain flags (e.g. `--global --flutter --dart`).
- Read each result fully and **retain the compiled payload per stack** — this is the *compile-once, share-many* standards payload injected into build subagents at Step 4. Cook is called **at most once per distinct stack per run** (a repeated identical flag set is a cache hit).
- A platform whose flags `/cook` accepts is covered; its flag names the canonical agent identifier (`eng-<platform>`). Do not derive agent names from the PRD alone — `/cook`'s flag set is the authority on supported platforms.
- If `/cook` has no flag for an implied platform (rejects the flag with the valid-flag list): surface as a blocking gap — emit a warning, list the uncovered platform, and ask via `AskUserQuestion` before continuing.

**3b — Propose language-targeted roster and get approval.** Map every PRD feature to the covered platforms from 3a. One agent per language/platform stack in scope. Do **not** collapse platforms to reduce count: `eng-ios` and `eng-android` own different codebases, toolchains, and integration concerns — never merge. An under-staffed roster produces a worse plan.

Present as a table:

| Agent | Domain | Scope summary | PRD features covered |
|-------|--------|---------------|----------------------|

Then ask approval via `AskUserQuestion`:
- **Approve roster** — proceed with agent activation.
- **Revise roster** — user provides changes; re-run 3b with the revision (do **not** re-fetch `/cook`).

Do not activate any agent without explicit approval.

**Execution table skeleton.** Once the roster is approved, build the skeleton using `refs/template-exec-table.md` as guide:
- Enumerate features from the PRD's Features & acceptance criteria table — the F-IDs there (F1, F2, …) are the canonical feature list and the key for every exec-table row.
- For each F-ID, enumerate applicable execution concerns (API contract, schema migration, authentication, webhooks/hooks, client implementation, tests) and create one row per `(feature, concern)` pair. Feature cell = exact `<F-ID>: <name> — <concern>` text.
- Pre-populate Feature and Agent columns; leave Execution steps blank.

**Todos column (only when `$TODOS = true`).** Add a **Todos** column between Execution steps and Agent. Each cell is an anchor link to that feature's `### F<n>` subsection under `## Todos`: `[F<n>](#todos-f<n>)` (e.g. `[F1](#todos-f1)`). All rows sharing an F-ID point to the same anchor. Targets don't exist yet (written in the todo phase, Step 4) — this is a forward pointer. When `$TODOS = false`, **omit this column entirely**.

Append the skeleton to the PRD. `$TODOS = true`:

```markdown
## Execution Table

| Feature | Execution steps | Todos | Agent |
|---------|----------------|-------|-------|
| F1: Set daily goal — API contract | | [F1](#todos-f1) | backend-eng |
```

`$TODOS = false`:

```markdown
## Execution Table

| Feature | Execution steps | Agent |
|---------|----------------|-------|
```

**AHA.md update (conditional).** Before Step 4, capture a learning if any of: a PRD gap catchable in `plan-pm`; an architecture conflict that should inform future PRD templates; an overlap with a prior PRD that required a resolution decision. For each, append one entry under `## Entries` (most recent first) of `devkit/AHA.md`:

```
### [YYYY-MM-DD] <Summary title>
**Why**: <Root cause>
**Note**: <Concrete action or warning for future runs>
```

Write only when ≥1 qualifying learning exists — never an empty entry.

---

**Step 4/5 — Agents write**

**Mode detection.** Scan PRD headings for `## Engineering —` and `## Todos —` blocks. The approved roster count = expected count for "all agents." Resolve `$MODE` by `$TODOS`:

| `$TODOS` | Condition | `$MODE` |
|----------|-----------|---------|
| `false` (todo layer off) | no `## Engineering —` heading | `plan` |
| `false` | ≥1 `## Engineering —` heading present | `build` |
| `true` | no `## Engineering —` heading | `plan` |
| `true` | `## Engineering —` present but `## Todos —` absent for any agent (fewer `## Todos —` blocks than roster agents) | `todo` |
| `true` | `## Todos —` present for **all** agents | `build` |

Each mode dispatches its agents to the `eng` skill with the matching flag (`--plan` / `--todo` / `--build`). `--todo` agents run only after **all** `--plan` agents wrote their `## Engineering — <Agent>` sections, and before **any** `--build` agent — the detection above enforces this ordering.

**Subagent context injection (compile/read once, share many).** plan-em already read the full PRD + devkit (Step 1) and compiled per-stack standards payloads (Step 3a). It passes each `eng` subagent only what it needs, so siblings do **not** each re-read the whole PRD, re-read every devkit file, or re-invoke `/cook`. Every dispatch prompt below therefore also includes:
- **Scoped context** — this agent's exec-table rows, the PRD **feature sections** those rows map to, and a **devkit digest** (canonical GLOSSARY terms, ARCHITECTURE constraints, DESIGN-SYSTEM components relevant to the rows — distilled from the Step 1 pre-flight). Plus the **escape hatch**: *"The full PRD is at `<prd-path>`; read it (or a specific devkit file) on demand only if a scoped excerpt is insufficient to resolve a row."*
- **Standards payload** *(build mode only)* — the compiled `/cook` output for this agent's stack, retained from Step 3a. The build agent uses it and **does not call `/cook` itself**. (`--plan`/`--todo` agents pull no standards → no payload.)

Scope-enforcement and the branch contract in the numbered fields are unchanged — each agent acts only on its assigned rows and commits only to the resolved branch.

**Plan mode (`$MODE = plan`).** Activate each approved agent as a parallel subagent via the `Agent` tool, each running `eng` in `--plan` mode. Prompt fields:
1. "Read `.claude/skills/eng/SKILL.md` fully and follow its protocol."
2. Mode flag: `--plan`
3. `prd-path`: the PRD file path
4. `rows`: the semicolon-separated exec-table Feature identifiers assigned to this agent — each the exact `<ID>: <name> — <concern>` text of a Feature cell
5. `agent`: this agent's name from the approved roster — the exact **Agent** column value for these rows (e.g. `backend-eng`)
6. **Scoped context** (per § Subagent context injection): rows, the mapped PRD feature sections, devkit digest, PRD-path escape hatch. (`--plan` pulls no standards → no payload.)

Each agent writes its engineering section directly to the PRD. Emit a short progress note per completion.

**Bootstrap the development eval_set (plan mode only).** After all plan-mode agents wrote their sections — so the PRD now carries the full feature list, engineering sections, and exec table — invoke `/test --prd <prd-path>` **once** (via `Skill`, resolved PRD path from Step 1). This bootstraps an `eval_set` of functional assertions under `$PRD_DIR/`, before the build phase begins; downstream `eng --build` agents and `/review` consume it via `/test --eval-set <path>` rather than re-deriving it. Emit a one-line note with the assertion count (e.g. `Eval-set: 12 executable assertions bootstrapped.`). If `/test` reports zero executable assertions, note it and continue — a planner signal that the PRD lacks testable acceptance criteria, not a blocker.

**Todo mode (`$MODE = todo` — only when `$TODOS = true`).** Confirmed `## Engineering — <Agent>` sections now exist; break each F-ID's scope into an executable todo checklist before any build agent runs.

First, append the `## Todos` umbrella heading **once** (if absent), immediately after the last `## Engineering — <Agent>` section — this is the anchor namespace the exec-table Todos column points into; creating it here (not in parallel agents) avoids a write race. Then activate each approved agent as a parallel subagent, each running `eng` in `--todo` mode. Prompt fields:
1. "Read `.claude/skills/eng/SKILL.md` fully and follow its protocol."
2. Mode flag: `--todo`
3. `prd-path`: the PRD file path (engineering sections already appended)
4. `rows`: the semicolon-separated exec-table Feature identifiers assigned to this agent — each the exact `<ID>: <name> — <concern>` text of a Feature cell
5. `agent`: this agent's name from the approved roster — the exact **Agent** column value for these rows (e.g. `backend-eng`)
6. **Scoped context** (per § Subagent context injection): rows, its confirmed `## Engineering — <Agent>` section plus the mapped feature-table sections, devkit digest, PRD-path escape hatch. (`--todo` pulls no standards → no payload.)

Each agent appends its own `## Todos — <Agent>` block (one `### F<n>` block per owned feature) under the `## Todos` umbrella. Emit a short progress note per completion. When every agent has written its `## Todos —` block, the todo phase is complete and the next `plan-em` invocation detects `$MODE = build`.

**Build mode (`$MODE = build`).** First, resolve and create the feature branch **once**.

**Branch resolution (parent-aware).** Read the PRD frontmatter for a `parent:` field (present only on sub-PRDs — see `plan-pm` § Sub-PRD mode):

| Frontmatter | `$BRANCH` | Note |
|-------------|-----------|------|
| No `parent:` (top-level PRD) | `feat/prd-[n]-<short-name>` (from this PRD's own id/title) | as before |
| `parent: prd-<parent-n>-<parent-slug>` (sub-PRD) | `feat/prd-<parent-n>-<parent-slug>` (parsed from `parent`) | sub-PRD **never** gets its own branch — commits land on the parent's feature branch, so `/review` and `/test` see its changes in the parent's existing run directory |

**Idempotent create-or-checkout.** Check `git branch --list "$BRANCH"`:
- Does **not** exist (common for a top-level PRD's first build) → cut it from `main` and push it.
- **Already exists** (common for a sub-PRD, whose parent branch is present) → check it out; do **not** re-create or reset.

Build agents run in parallel and must not each try to create it (concurrent creation from `main` corrupts the tree) — they hard-fail if it is missing. Then activate each approved agent as a parallel subagent, each running `eng` in `--build` mode. Prompt fields:
1. "Read `.claude/skills/eng/SKILL.md` fully and follow its protocol."
2. Mode flag: `--build`
3. `prd-path`: the PRD file path (engineering sections already appended)
4. `rows`: the semicolon-separated exec-table Feature identifiers assigned to this agent — each the exact `<ID>: <name> — <concern>` text of a Feature cell
5. `branch`: `$BRANCH` (resolved/created above — the parent's branch for a sub-PRD)
6. `agent`: this agent's name from the approved roster — the exact **Agent** column value for these rows (e.g. `backend-eng`)
7. **Scoped context + standards payload** (per § Subagent context injection): rows, the mapped PRD feature sections, devkit digest, PRD-path escape hatch, **and** the compiled `/cook` **standards payload** for this agent's stack (retained from Step 3a). The build agent uses the injected payload and **does not call `/cook` itself**; cook is invoked at most once per distinct stack per run.

Emit a short progress note per completion.

**Plan-mode branch suggestion.** After all plan sections are appended, derive the short feature name from the PRD title (lowercase, hyphenated, ≤ 4 words) and emit the suggested working branch:

```
feat/prd-[n]-<short-name>
```

Engineers should cut this branch from `main` before starting work.

---

**Step 5/5 — Synthesise and next steps**

**Synthesise.** Read the engineering sections + feature coverage via the digest **synth** slice — `python3 .claude/scripts/scan-prd-digest.py <prd-path> --slice synth` (frontmatter + `features` + `exec_table` + every agent's `engineering` block + `open_questions` — everything this synthesis summarizes). **Escape hatch:** for a cross-section conflict that needs product prose (a user-flow or design-system detail), read only that section's `prose_lines` range; do **not** default to reading the whole PRD. Produce a synthesis report inline:
1. **Per-agent summary** — per engineering section: one paragraph on what was written, decided, and left open.
2. **Numbered findings list** — every gap/conflict/open question across all sections, each with:
   - Severity: **Critical** (blocks engineering kickoff) / **Major** (requires mid-flight PRD revision) / **Minor** (note for future cycles)
   - Location: PRD section and owning agent
   - Required action: what must happen before engineering work begins

   If Critical findings exist, present via `AskUserQuestion` and resolve before declaring the run complete.
3. **Suggested branch** — derive the short feature name from the PRD title (lowercase, hyphenated, ≤ 4 words). Emit per the convention in `.claude/skills/eng/refs/plan/template-eng-plan.md` §10:

   ```
   feat/prd-[n]-<short-name>
   ```

   Example: `feat/prd-3-habit-tracking`. Engineers cut this from `main` before starting work.

**Next steps.** After synthesis, ask via `AskUserQuestion` (single-select) "What would you like to do next?" — options depend on the phase just completed (`$MODE` from Step 4) and `$TODOS`.

**After the `plan` phase** (or after `todo`, whichever ran):

| Option | Action |
|--------|--------|
| **Run plan-tune (eng mode)** — run `plan-tune --eng` on this PRD | invoke `Skill("plan-tune", "<prd-path> --eng")` (resolved PRD path from Step 1). Do not terminate until plan-tune completes. |
| **Run todo breakdown** *(offer only when `$TODOS = true` and no `## Todos —` blocks exist yet)* — decompose confirmed engineering sections into per-feature todos before building | invoke `Skill("plan-em", "<prd-path>")`. Engineering sections present but no todos + `$TODOS = true` → plan-em detects `$MODE = todo` and activates the todo agents. |
| **Run eng --build** — begin the build phase using this PRD | invoke `Skill("plan-em", "<prd-path>")`. plan-em re-runs mode detection: `$TODOS = true` with no todos yet → runs the `todo` phase first (todos always precede build when enabled); once todos exist for all agents → `$MODE = build`. `$TODOS = false` → `$MODE = build` directly. |
| **Skip** — terminate plan-em with no further action | terminate immediately. |

Final state: the PRD contains all engineering sections (and, when `$TODOS = true` and the todo phase ran, a `## Todos` section with a `## Todos — <Agent>` block per agent), the synthesis is visible, no Critical findings are unresolved, and the suggested branch is emitted.

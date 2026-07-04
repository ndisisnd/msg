---
name: EM Protocol
description: End-to-end five-step execution protocol for plan-em — validate/pre-flight, PRD tune gate, roster, agents write, synthesise
type: reference
---

# EM Protocol

The five-step execution protocol plan-em follows end-to-end, after Step 0 (todo preference) resolves `$TODOS`. Emit progress per § Progress emission in SKILL.md (`Step X/5 — <title>`). Reference paths (`refs/principles.md`, `refs/template-exec-table.md`) resolve relative to the skill root.

## Step-by-step protocol

---

**Step 1/5 — Validate and pre-flight**

First, validate: verify the PRD path exists and matches `features/prd-*/prd-*.md` (top-level) **or** `features/prd-*/prd-*/prd-*.md` (a nested sub-PRD, e.g. `features/prd-2-habit-tracking/prd-2.1-streak-freeze/prd-2.1-streak-freeze.md`). Resolve and store the actual matched directory (the PRD file's own parent directory) as `$PRD_DIR` — write every artifact below relative to `$PRD_DIR`, never to a reconstructed `features/prd-[n]/`. Derive `n` as the first numeric segment of that parent directory name (`prd-3-habit-tracking` → `n=3`; `prd-2.1-streak-freeze` → `n=2`, i.e. the parent's number for a sub-PRD). If validation fails, refuse and emit the rule. Produce no output on failure.

Then, mandatory pre-flight scan (devkit + PRD). Devkit files live in `devkit/` (created by `msg-init`); `CLAUDE.md` is at project root. Read all of the following in order:

1. `devkit/AHA.md` — scan for past learnings applicable to this PRD's domain or feature type. Note every entry that is directly relevant.
2. `devkit/GLOSSARY.md` — load canonical term definitions. Flag any PRD terms that deviate from the glossary.
3. `devkit/ARCHITECTURE.md` — load system constraints, existing layers, and integration points. Note any constraints that affect the PRD's features.
4. `CLAUDE.md` — load tech stack constraints, naming conventions, and architecture notes. Note any conventions that constrain agent scope or engineering choices in this run.
5. `devkit/DESIGN-SYSTEM.md` — load the component registry. For each component: note which PRD features would impact it, which could reuse it without changes, and which require new data ingestion. Record findings per component — they feed into the pre-flight report and constrain the frontend agent scope.
6. `devkit/OPEN-QUESTIONS.md` — scan for unresolved decisions that overlap this PRD's domain or feature set. Note each relevant question; include it in the pre-flight report under a new **Open questions** section. If a question directly blocks a PRD feature, flag it as a blocking gap in the pre-flight report.
7. The PRD file in full.

**Absent-file rule:** If `devkit/` does not exist, emit `devkit/ not found — run /msg-init to initialise the project first.` and **stop**. Do not proceed to Step 2. If `devkit/` exists but an individual devkit file is missing, emit `<filename> not found — run /msg-init to initialise the project first.` Proceed without the file; do not create it.

**Multi-PRD cross-reference.** Run `bash ls features/prd-*/prd-*.md` excluding the input PRD's directory. For each prior PRD:
   - **Fast scan via frontmatter first**: read the `module`, `affects`, and `depends_on` fields in the YAML frontmatter. If the input PRD's `module` matches another PRD's `module`, or the input PRD appears in another PRD's `affects` list, or the input PRD's `depends_on` names a prior PRD — flag it immediately.
   - **Full read only when flagged**: for any PRD flagged by frontmatter, read its features section in full and classify the relationship as one of:
     - **Dependency** — the input PRD's `depends_on` lists this PRD; it must ship first or be in flight. Confirm its current status.
     - **Breaking change** — the input PRD's features alter a contract, schema, or module that a prior PRD also owns (may break an already-shipped feature). Name the specific contract at risk.
     - **Overlap** — the two PRDs share user-facing scope without a clear ownership boundary.
   - **No frontmatter**: fall back to reading the features section of every prior PRD and compare against the input PRD's features.

   If any flagged PRD is found, present via one `AskUserQuestion` per relationship type (dependency, breaking change, overlap), with options appropriate to the type:
   - **Dependency**: Confirm dependency is satisfied / Merge dependency into this plan / Stop and ship the dependency first / Proceed at risk
   - **Breaking change**: Add backward-compat shim / Coordinate with owning PRD author / Proceed with explicit breakage noted / Stop and reconcile
   - **Overlap**: Reuse existing / Refactor existing / Proceed with parallel implementation / Stop and reconcile with PRD author

   **Frontmatter writeback** — after all resolutions are complete, update the input PRD's YAML frontmatter via `Edit` to reflect confirmed relationships:
   - Add any newly confirmed dependency PRD IDs to `depends_on` (merge with existing list, no duplicates).
   - Add any newly confirmed overlap or breaking-change PRD IDs to `affects` (merge with existing list, no duplicates).
   - If `module` is blank or a placeholder, infer it from the PRD's feature domain and set it now.

   Also update the frontmatter of any prior PRD whose `affects` list should include the input PRD (i.e., if the input PRD is confirmed to break or overlap a prior PRD's scope, add the input PRD's ID to that prior PRD's `affects` field).

Write the pre-flight report to `$PRD_DIR/preflight.md` (create or overwrite). The file contains all findings in full:

- **Terminology deviations** — PRD terms not matching GLOSSARY.md
- **Architecture conflicts** — features that contradict or ignore ARCHITECTURE.md constraints
- **AHA.md warnings** — past learnings that apply to this PRD
- **Design system impact** — components impacted by the PRD's features, whether they need data-ingestion changes, and whether new components are required (from DESIGN-SYSTEM.md scan)
- **Multi-PRD findings** — dependencies, breaking changes, and overlaps with prior PRDs, each classified and actioned as above
- **PRD gaps** — sections ambiguous or incomplete enough to block domain mapping

Do not hold the full report in context. After writing, emit inline only the **actionable findings** — those that require a decision before proceeding (blocking PRD gaps, architecture conflicts, multi-PRD relationship questions). Suppress informational findings (AHA.md warnings, terminology notes, design system observations) from the inline summary; they live in `preflight.md` and are available on request.

---

**Step 2/5 — PRD tune gate**

This gate checks whether the **PM/product tune** (`plan-tune --product`) has been run on the PRD. It does **not** check for eng tune. The eng tune (`plan-tune --eng`) audits engineering output and is prompted at Step 5 *after* agents write. The full sequence is:

```
plan-tune --product  →  plan-em  →  [agents write]  →  plan-tune --eng
```

Check the PRD's `product-tuned:` frontmatter field (read in Step 1). If `product-tuned: no` or the field is absent, note it in the question context. (If `product-tuned: yes`, the product tune has already run — you may skip the gate and proceed straight to agent identification.)

Ask the user via `AskUserQuestion`:

- **Run plan-tune --product first** — emit the handoff message: "Run `/plan-tune $PRD_DIR/prd-[n]-[slug].md --product` to tune the PRD before engineering planning." (Use the resolved `$PRD_DIR` and `n` from Step 1.) Then stop.
- **Continue without tune** — proceed to agent identification.

Do not activate any agent until the user responds.

---

**Step 3/5 — Identify agents and get approval**

**3a — Fetch coding standards to confirm agent types**

Before proposing any roster, derive the platform identifiers from the PRD frontmatter `platform` field and the Features & acceptance criteria table. Then call `/cook` once per implied platform and read each result fully. The platforms `/cook` returns coverage for are the canonical agent identifiers — use them to name agents (`eng-<platform>`). Do not derive agent names from the PRD alone; `/cook` is the authority on what platforms are supported.

If `/cook` returns no coverage for a platform implied by the PRD, surface it as a blocking gap: emit a warning, list the uncovered platform, and ask the user via `AskUserQuestion` how to proceed before continuing.

**3b — Propose language-targeted roster and get approval**

Map every PRD feature to the covered platforms from 3a. The roster is driven by the languages and platforms the PRD targets — one agent per language/platform stack in scope. Do not collapse platforms to reduce agent count: `eng-ios` and `eng-android` own different codebases, toolchains, and integration concerns and must not be merged. An under-staffed roster produces a worse plan than a correctly-sized one.

Present the agent roster as a table:

| Agent | Domain | Scope summary | PRD features covered |
|-------|--------|---------------|----------------------|

Then ask for approval via `AskUserQuestion`:
- **Approve roster** — proceed with agent activation
- **Revise roster** — user provides changes; re-run Step 3b with the revision (do not re-fetch `/cook`)

Do not activate any agent without explicit approval.

**Execution table skeleton**

Once the roster is approved, build the execution table skeleton using `refs/template-exec-table.md` as the guide. Enumerate features from the PRD's Features & acceptance criteria table — the F-IDs there (F1, F2, …) are the canonical feature list and the keys for every exec-table row. For each F-ID, enumerate applicable execution concerns (API contract, schema migration, authentication, webhooks/hooks, client implementation, tests) and create one row per `(feature, concern)` pair, with the Feature cell as the exact `<F-ID>: <name> — <concern>` text. Pre-populate the Feature and Agent columns; leave Execution steps blank.

**Todos column (only when `$TODOS = true`).** If the todo layer is enabled, add a **Todos** column between Execution steps and Agent. Each row's Todos cell is an anchor link to that feature's `### F<n>` subsection under the `## Todos` section: `[F<n>](#todos-f<n>)` (e.g. `[F1](#todos-f1)`). All rows sharing an F-ID point to the same anchor. The target blocks don't exist yet — they're written in the todo phase (Step 4) — so this is a forward pointer. When `$TODOS = false`, **omit this column entirely**; the table is unchanged from before this feature.

Append the skeleton to the PRD. With `$TODOS = true`:

```markdown
## Execution Table

| Feature | Execution steps | Todos | Agent |
|---------|----------------|-------|-------|
| F1: Set daily goal — API contract | | [F1](#todos-f1) | backend-eng |
```

With `$TODOS = false`:

```markdown
## Execution Table

| Feature | Execution steps | Agent |
|---------|----------------|-------|
```

**AHA.md update (conditional)**

Before proceeding to Step 4, identify learnings from Steps 1–3 worth capturing. A learning qualifies if any of:
- A PRD gap was found that could have been caught in `plan-pm`
- An architecture conflict was found that should inform future PRD templates
- Overlap with a prior PRD required a resolution decision

For each qualifying learning, append one entry to `devkit/AHA.md`:

```
### [YYYY-MM-DD] <Summary title>
**Why**: <Root cause>
**Note**: <Concrete action or warning for future runs>
```

Entries go under `## Entries`, most recent first. Write only when there is at least one qualifying learning — do not create an empty entry.

---

**Step 4/5 — Agents write**

**Mode detection:** Scan the PRD's headings for `## Engineering —` and `## Todos —` blocks. The number of agents in the approved roster is the expected count for "all agents." Resolve `$MODE` by `$TODOS` (from Step 0):

- **`$TODOS = false`** (todo layer off — pre-feature behaviour): no `## Engineering —` heading → `$MODE = plan`; one or more `## Engineering —` headings present → `$MODE = build`. The todo state is skipped entirely.
- **`$TODOS = true`** (todo layer on — three states):
  - no `## Engineering —` heading exists → `$MODE = plan`;
  - `## Engineering —` present but a `## Todos —` heading is **absent for any agent** (fewer `## Todos —` blocks than roster agents) → `$MODE = todo`;
  - a `## Todos —` heading is present for **all** agents → `$MODE = build`.

Each mode dispatches its agents to the `eng` skill with the matching flag (`--plan` / `--todo` / `--build`), detailed in the mode blocks below. `--todo` agents run only after **all** `--plan` agents have written their `## Engineering — <Agent>` sections, and before **any** `--build` agent runs — the detection above enforces this ordering automatically.

**Plan mode (`$MODE = plan`):** Activate each approved agent as a parallel subagent via the `Agent` tool. Each agent runs the `eng` skill in `--plan` mode. For each agent, the prompt must include:

1. "Read `.claude/skills/eng/SKILL.md` fully and follow its protocol."
2. Mode flag: `--plan`
3. `prd-path`: the PRD file path
4. `rows`: the semicolon-separated exec-table Feature identifiers assigned to this agent — each the exact `<ID>: <name> — <concern>` text of a Feature cell
5. `agent`: this agent's name from the approved roster — the exact value in the exec-table **Agent** column for these rows (e.g. `backend-eng`)

Each agent writes its engineering section directly to the PRD file. Emit a short progress note as each agent completes.

**Bootstrap the development eval_set (plan mode only):** After all plan-mode agents have written their engineering sections — so the PRD now carries the full feature list, engineering sections, and execution table — invoke `/test --prd <prd-path>` **once** (via the `Skill` tool, with the resolved PRD path from Step 1). This reads the PRD and bootstraps an `eval_set` of functional assertions for the feature, written under `$PRD_DIR/`. Running it here, once, means the eval_set exists before the build phase begins; downstream `eng --build` agents and `/review` consume it via `/test --eval-set <path>` rather than each re-deriving it. Emit a one-line note with the assertion count (e.g. `Eval-set: 12 executable assertions bootstrapped.`). If `/test` reports zero executable assertions, note it and continue — this is a planner signal that the PRD lacks testable acceptance criteria, not a blocker.

**Todo mode (`$MODE = todo` — only reachable when `$TODOS = true`):** The confirmed `## Engineering — <Agent>` sections now exist; break each F-ID's scope into an executable todo checklist before any build agent runs.

First, append the `## Todos` umbrella heading to the PRD **once** (if absent), immediately after the last `## Engineering — <Agent>` section — this is the anchor namespace the execution table's Todos column points into, and creating it here (rather than in the parallel agents) avoids a write race. Then activate each approved agent as a parallel subagent via the `Agent` tool, each running the `eng` skill in `--todo` mode. For each agent, the prompt must include:

1. "Read `.claude/skills/eng/SKILL.md` fully and follow its protocol."
2. Mode flag: `--todo`
3. `prd-path`: the PRD file path (with engineering sections already appended)
4. `rows`: the semicolon-separated exec-table Feature identifiers assigned to this agent — each the exact `<ID>: <name> — <concern>` text of a Feature cell
5. `agent`: this agent's name from the approved roster — the exact value in the exec-table **Agent** column for these rows (e.g. `backend-eng`)

Each agent appends its own `## Todos — <Agent>` block (one `### F<n>` block per owned feature) under the `## Todos` umbrella. Emit a short progress note as each agent completes. When every agent has written its `## Todos —` block, the todo phase is complete and the next `plan-em` invocation will detect `$MODE = build`.

**Build mode (`$MODE = build`):** First, resolve and create the feature branch **once**.

**Branch resolution (parent-aware).** Read the PRD's frontmatter for a `parent:` field (present only on sub-PRDs — see `plan-pm`'s § Sub-PRD mode):
- **No `parent:`** (top-level PRD) → `$BRANCH = feat/prd-[n]-<short-name>`, derived from this PRD's own id/title as before.
- **`parent: prd-<parent-n>-<parent-slug>`** (sub-PRD) → `$BRANCH = feat/prd-<parent-n>-<parent-slug>`, parsed directly from the `parent` value. A sub-PRD **never** gets its own branch — its commits land on the parent's feature branch, so `/review` and `/test` see the sub-PRD's changes in the parent's existing run directory.

**Idempotent create-or-checkout.** Check `git branch --list "$BRANCH"`:
- If it **does not exist** (the common case for a top-level PRD's first build) → cut it from `main` and push it.
- If it **already exists** (the common case for a sub-PRD, whose parent branch is already present) → check it out; do **not** re-create or reset it.

Build agents run in parallel and must not each try to create it (concurrent creation from `main` corrupts the tree) — they hard-fail if it is missing. Then activate each approved agent as a parallel subagent via the `Agent` tool. Each agent runs the `eng` skill in `--build` mode. For each agent, the prompt must include:

1. "Read `.claude/skills/eng/SKILL.md` fully and follow its protocol."
2. Mode flag: `--build`
3. `prd-path`: the PRD file path (with engineering sections already appended)
4. `rows`: the semicolon-separated exec-table Feature identifiers assigned to this agent — each the exact `<ID>: <name> — <concern>` text of a Feature cell
5. `branch`: `$BRANCH` (the feature branch resolved and created/checked-out above — the parent's branch for a sub-PRD)
6. `agent`: this agent's name from the approved roster — the exact value in the exec-table **Agent** column for these rows (e.g. `backend-eng`)

Emit a short progress note as each agent completes.

**Plan-mode branch suggestion:** After all plan sections are appended, derive the short feature name from the PRD title (lowercase, hyphenated, ≤ 4 words) and emit the suggested working branch:

```
feat/prd-[n]-<short-name>
```

Engineers should cut this branch from `main` before starting work.

---

**Step 5/5 — Synthesise and next steps**

**Synthesise:**

Read the full updated PRD. Produce a synthesis report inline:

1. **Per-agent summary** — for each engineering section: one paragraph on what was written, what was decided, and what remains open.
2. **Numbered findings list** — every gap, conflict, or open question across all sections, each with:
   - Severity: **Critical** (blocks engineering kickoff) / **Major** (requires mid-flight PRD revision) / **Minor** (note for future cycles)
   - Location: PRD section and owning agent
   - Required action: what must happen before engineering work begins

If Critical findings exist, present them via `AskUserQuestion` and resolve before declaring the run complete.

3. **Suggested branch** — derive the short feature name from the PRD title (lowercase, hyphenated, ≤ 4 words). Emit the suggested branch name following the convention defined in `.claude/skills/eng/refs/plan/template-eng-plan.md` §10:

   ```
   feat/prd-[n]-<short-name>
   ```

   Example: `feat/prd-3-habit-tracking`. This is the branch engineers should cut from `main` before starting work.

After synthesis, ask via `AskUserQuestion` (single-select):

> What would you like to do next?

The options offered depend on the phase just completed (`$MODE` from Step 4) and `$TODOS` from Step 0.

**After the `plan` phase** (or after `todo`, whichever ran):

Options:
- **Run plan-tune (eng mode)** — run `plan-tune --eng` on this PRD
- **Run todo breakdown** *(offer only when `$TODOS = true` and no `## Todos —` blocks exist yet — i.e. the todo phase hasn't run)* — decompose the confirmed engineering sections into per-feature todos before building
- **Run eng --build** — begin the build phase using this PRD
- **Skip** — terminate plan-em with no further action

Based on the user's selection:
- **Run plan-tune (eng mode)** → invoke `Skill("plan-tune", "<prd-path> --eng")` where `<prd-path>` is the resolved PRD path from Step 1. Do not terminate until plan-tune completes.
- **Run todo breakdown** → invoke `Skill("plan-em", "<prd-path>")`. Since engineering sections are present but no todos exist yet and `$TODOS = true`, plan-em detects `$MODE = todo` in Step 4 and activates the todo agents.
- **Run eng --build** → invoke `Skill("plan-em", "<prd-path>")`. plan-em re-runs mode detection in Step 4: with `$TODOS = true` and no todos yet, it will run the `todo` phase first (todos always precede build when enabled); once todos exist for all agents it detects `$MODE = build` and activates build agents. With `$TODOS = false` it detects `$MODE = build` directly.
- **Skip** → terminate plan-em immediately with no further action.

Final state: the PRD contains all engineering sections (and, when `$TODOS = true` and the todo phase has run, a `## Todos` section with a `## Todos — <Agent>` block per agent), the synthesis is visible to the user, no Critical findings are unresolved, and the suggested branch is emitted.

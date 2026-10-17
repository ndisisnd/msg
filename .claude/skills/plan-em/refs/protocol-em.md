---
name: EM Protocol
description: End-to-end five-step execution protocol for plan-em — validate/pre-flight, certification precondition, roster, agents write (plan half, then "Start the build now?", then build half), digest
type: reference
---

# EM Protocol

The five-step protocol plan-em runs end-to-end. Ref paths (`refs/template-exec-table.md`) resolve relative to the skill root.

**Harness incidents.** Any script this protocol runs that exits non-zero on an outcome the step's own text does not document appends a `devkit/DOCTOR.md` row via the shared appender, per `../../shared/refs/doctor-logging.md`. Logging never changes control flow — the step's own rule (continue, stop, repair-once) still decides. The call sites below name their signature.

**Internals.** Stage timing, the run-state file, the team-lane heartbeat relay and prompt-cache field order live in `refs/internals.md`. Read a section there only at the call site that names it. Mark each stage boundary listed in `refs/internals.md` § Stage timing as the run crosses it.

## Step-by-step protocol

---

**Step 0 — Dispatch lane** (resolve before Step 1)

`$TEAM_MODE = team` on every run. The hidden `--solo` flag (maintainers and debugging only) sets `$TEAM_MODE = solo` for this run only: it is never saved, and a later run is `team` again. `--team` is accepted and changes nothing. Strip either flag from the argument string before Step 1a. Never name the lane to the user — no "Execution mode" line. `$TEAM_MODE` is read only at Step 4.

---

**Step 1/5 — Validate and pre-flight**

**1a. Validate PRD path.** Must exist and match a lane-lifecycle path — `features/{planned,wip,done}/prd-*/prd-*.md` (top-level) **or** `features/{planned,wip,done}/prd-*/prd-*/prd-*.md` (nested sub-PRD, e.g. `features/wip/prd-2-habit-tracking/prd-2.1-streak-freeze/prd-2.1-streak-freeze.md`) — **or** the legacy flat form `features/prd-*/prd-*.md` (top-level) / `features/prd-*/prd-*/prd-*.md` (nested sub-PRD).
- Store the matched PRD's own parent directory as `$PRD_DIR`; write **every** artifact relative to `$PRD_DIR`, never a reconstructed `features/prd-[n]/`.
- Derive `n` = first numeric segment of that parent dir name (`prd-3-habit-tracking` → `n=3`; `prd-2.1-streak-freeze` → `n=2`, the parent's number for a sub-PRD).
- On failure: refuse, emit the rule, produce no output.

**1a′. Run-state resume check.** Before any pre-flight work, read the run-state file and act on it per `refs/internals.md` § Run-state file. A stopped-after-plan state continues without a question; any other open state asks Resume / Start fresh / Abort.

**1b. Mandatory pre-flight scan (devkit + PRD).** Devkit files live in `devkit/` (created by `/msg --init`); `CLAUDE.md` is at project root. Read all, in order:

| # | Source | Read for / action |
|---|--------|-------------------|
| 1 | `devkit/AHA.md` | Past learnings applicable to this PRD's domain/feature type. Note every directly-relevant entry. |
| 2 | `devkit/GLOSSARY.md` | Canonical term definitions. Flag PRD terms that deviate. |
| 3 | `devkit/ARCHITECTURE.md` | System constraints, existing layers, integration points, and the project's stacks (Step 3b's usual roster). Note constraints affecting the PRD's features. |
| 4 | `CLAUDE.md` (root) | Tech-stack constraints, naming conventions, arch notes. Note conventions that constrain agent scope / eng choices this run. |
| 5 | `devkit/DESIGN-SYSTEM.md` | Component registry. Per component note: which PRD features impact it, which reuse it unchanged, which need new data ingestion. Feeds the pre-flight report; constrains frontend agent scope. |
| 6 | `devkit/OPEN-QUESTIONS.md` | Unresolved decisions overlapping this PRD's domain/features. Note each under a new **Open questions** section; if one directly blocks a feature, flag as a blocking gap. |
| 7 | Input PRD | **Via its digest slice, not full prose** (see below). |

**Item 7 — PRD digest slice.** Run the PRD-digest generator for plan-em's `plan` slice; consume the JSON it prints:

```bash
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"; python3 "$G" "<PRD path>" --slice plan
```

The `plan` slice returns `frontmatter` (incl. `deps` — plus `platform`/`module`/`affects`/`depends_on` on an older PRD, `null` otherwise), `summary`, `features` (F-IDs + acceptance criteria verbatim), `exec_table` and `engineering_agents`. The generator re-parses the PRD on every call, so the slice is never stale (`.claude/skills/shared/refs/session-cache.md`). **Escape hatch:** if a pre-flight check needs prose the slice omits — User-flow narrative for a terminology/architecture-conflict finding, or a heading under the digest's `unparsed_sections` — read only that section's `prose_lines` range. Do **not** default to the whole PRD.

**Absent-file rule.**
- No `devkit/` → emit `devkit/ not found — run /msg --init to initialise the project first.` and **stop** (do not proceed to Step 2).
- `devkit/` exists but a file missing → emit `<filename> not found — run /msg --init to initialise the project first.` Proceed without it; do not create it.

**1c. Multi-PRD cross-reference — consume the certified graph, ask only on conflict.** intake graded sequencing into the `S:` cell, and plan-review check 6 verified the frontmatter `deps` graph. plan-em does not re-ask what they answered.

1. **Fast scan via the lane-aware scanner** — run the PRD inventory with `--exclude` set to the input PRD's own id. It emits one JSONL object per prior PRD across all lanes and the legacy flat path:

   ```bash
   S=.claude/scripts/script-prd-scan.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-scan.sh"; bash "$S" --exclude prd-[n]-[slug]
   ```

   A non-zero exit → log one DOCTOR row (`tool-error:script-prd-scan`), then continue with an empty prior-PRD inventory.

   Read each prior PRD's `deps` from the JSONL (no file open) and cross-check against the input's certified `deps` and its codebase/feature scan. The `deps` array plus the §3 Dependencies column it mirrors are the whole cross-PRD graph.
2. **Ask only on a genuine conflict** — one `AskUserQuestion`, only when the certified graph contradicts the scan:
   - the certified `deps` names a PRD whose surface this PRD's features plainly do **not** touch (a spurious edge), or
   - the feature scan reveals an **undeclared** dependency on a prior PRD absent from `deps` (a missing edge).
   Options: **Trust the certified graph** / **Amend the graph** (add/remove the edge, then the writeback below) / **Stop and reconcile**.
3. **Expected on a clean run: zero relationship questions.**

**Frontmatter writeback (only when an edge was amended):** add or remove the reconciled ids in the input PRD's `deps` array (merge, no duplicates) and in the §3 Dependencies cell it mirrors. Use `script-prd-deps-mirror.sh`, not a hand `Edit`: it targets whichever array name the file carries.

**1d. Pre-flight findings — written only when there are findings.** Collect what 1b and 1c found across six categories:
- **Terminology deviations** — PRD terms not matching GLOSSARY.md
- **Architecture conflicts** — features contradicting/ignoring ARCHITECTURE.md
- **AHA.md warnings** — applicable past learnings
- **Design system impact** — components impacted, data-ingestion needs, new components required
- **Multi-PRD findings** — a deps-vs-scan conflict and how it was resolved
- **PRD gaps** — sections too ambiguous/incomplete to map domains

Then:

- **At least one finding → write `$PRD_DIR/preflight.md`** (create or overwrite) with every finding in full. Emit inline **only actionable findings** — those needing a decision before proceeding (blocking PRD gaps, architecture conflicts, multi-PRD questions). Informational findings stay in the file.
- **No findings → write no file.** Emit one line: `Pre-flight clean — devkit + PRD scanned, no findings.` A stale `preflight.md` from an earlier run is deleted on a clean run.

**1e. Resolve the size tier (`$SIZE`).** Size decides which check runs before the build. Resolve it once here; every later step uses the answer.

The digest `frontmatter` carries `intake: #<n>` — the row id in the root `INTAKE.md` ledger, whose grade cell reads `C:<band> S:<sequencing>`. The id is a whole number (`#7`) or, for a sub-PRD, dotted (`#7.1` — its own row, never the parent's). Read that one row through the ledger writer, never the whole ledger — `bash "$S" INTAKE.md - --list-rows --row <id>` with `S=.claude/scripts/script-intake-stamp.sh` (two-path resolution) — and take its `C:` band:

| `C:` band | `$SIZE` | Check before the build half |
|-----------|---------|-----------------------------|
| **≥ 8** | `large` | The plan-review eng certification. |
| **< 8**, or unresolvable | `medium` (**the default**) | The mechanical plan-shape check. |

Every size runs the same way: plan half → "Start the build now?" → build half. No `intake:` key, no matching row, an unparseable grade cell, or no `INTAKE.md` → `medium`. `eng --plan` tiers its section shape on the same grade cell (`eng/refs/plan/protocol.md` § Which shape); plan-em injects the resolved size into every leaf so the two never disagree. Emit one line — `Size: medium (intake #12, C:5).`

---

**Step 2/5 — Certification precondition (product side)**

Before any agent writes anything, the product-side certification must have passed. plan-em runs it inline rather than asking.

Run the certification gate checker on the input PRD (stamp + open-Critical scan of the findings ledger, two-path resolution). It reads the `reviewed:` stamp and `reports/review-prd-[n]-[slug].md`, or an older PRD's `product-tuned:` stamp and inline §7:

```bash
S=.claude/scripts/script-cert-status.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-cert-status.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md" --product
```

- `CERTIFIED` (exit 0) → proceed to Step 3.
- `UNCERTIFIED …` (exit 1 — `no-stamp` or `open-critical <id>`) → **run the plan-review product check inline**: `Skill("plan-review", "$PRD_DIR/prd-[n]-[slug].md --product")` (the flag is internal — never shown to the user). The certifier auto-fixes Critical+Major, stamps the PRD through `script-prd-stamp.sh --certify`, and returns its result block for the Step 5 digest. **Re-run the checker**:
  - `CERTIFIED` → proceed.
  - The certifier hit its **product-decision pause** → it already batched that question; once the user answers and the certifier finishes, re-check. A Critical still open → **stop** and surface it — plan-em never plans on an uncertified PRD — and log one DOCTOR row (`validator-fail:script-cert-status-product`). The first `UNCERTIFIED` is expected and never logged.

No `AskUserQuestion` in this step — the certifier's own product-decision pause is the only stop.

---

**Step 3/5 — Identify agents**

**Resume rules — Steps 1–3 re-run on every invocation.** A later `/plan-em` on the same PRD resumes at the build half, so this step must be idempotent:

- **Exec table already present** — the reserved `## 6. Feature execution table` section holds real rows rather than its `_To be populated by plan-em …_` placeholder. **Verify, do not render:** confirm (i) that section is the table's only home — no second `## Execution Table` heading — and (ii) every row's Feature cell keys on an F-ID that still exists in §3. Verified → skip the skeleton render; **never append a second table.** A verification failure is a hard stop — surface it and let the user reconcile.
- **Roster already set** — the digest's `engineering_agents` already lists every agent 3b would propose. The roster was settled by the plan half. **Confirm in one line and move on** — e.g. `Roster unchanged from the plan half: eng-backend, eng-ios.` Do not re-present the roster table, do not emit the intent summary again, and do not re-ask the roster question even when the roster is unusual.
- **3a runs either way.** The build half needs the compiled `/cook` payloads; the standards cache (3a) usually serves them.

**3a — Compile coding standards (flags) to confirm agent types.** Before proposing any roster, derive platform identifiers from the PRD frontmatter `platform` field and the Features & acceptance criteria table. Then call `/cook` **once per implied platform via explicit flags** — never a prose summary — built by the same script a manual eng build uses:

  ```bash
  F=.claude/scripts/script-eng-cook-flags.py; [ -f "$F" ] || F="$HOME/.claude/scripts/script-eng-cook-flags.py"
  python3 "$F" --stack "<the platform's stack tokens>" [--exclude "<domain:ref,…>"]
  ```

  The script emits `--global` whole, the bare `--<domain>` floor, and — only when a ref is excluded — one `--<domain>:<ref>` per kept ref, enumerated from cook's shelf. Your only judgment is `--exclude`: name a ref only when the PRD/devkit **provably** excludes its subject (e.g. `macos:distribution` when `CLAUDE.md` defers distribution; `macos:localization` with no i18n in scope). Signals: the exec-table **Files** column, the row **concerns**, the devkit. **Never under-load** — on any doubt, keep the ref. A `GAP=<stack>` line is an uncovered stack.
- **Cache check before every cook call.** Once the flag set for a stack is derived:

  ```bash
  C=.claude/scripts/script-standards-cache.py; [ -f "$C" ] || C="$HOME/.claude/scripts/script-standards-cache.py"
  python3 "$C" --check --flags "<the derived flag set>"
  ```

  `HIT <payload-path>` → read that file as the payload and **skip the `/cook` call**. `MISS` → call `/cook`, write the payload to a temp file, then `python3 "$C" --store --flags "<same flag set>" --payload <temp-file> || true`. The cache is keyed on cook's own source files (`../../shared/refs/session-cache.md` § Consumers).
- **Retain the compiled payload per stack** — it is injected into build leaves at Step 4. Cook is called **at most once per distinct stack per run**.
- A platform whose flags `/cook` accepts is covered; its flag names the canonical agent identifier (`eng-<platform>`). `/cook`'s flag set is the authority on supported platforms.
- If `/cook` has no flag for an implied platform (rejects the flag with the valid-flag list): the roster is unusual — list the uncovered platform and ask in 3b's one roster question before continuing.

**3b — Propose the roster; ask only when it is unusual.** Map every PRD feature to the covered platforms from 3a. One agent per language/platform stack in scope. Do **not** collapse platforms to reduce count: `eng-ios` and `eng-android` own different codebases, toolchains, and integration concerns — never merge.

**The usual roster** is the stacks named in `devkit/ARCHITECTURE.md` (read at 1b) plus the agents of earlier PRDs:

```bash
grep -rhE '^## Engineering — ' features --include='prd-*.md' --exclude="$(basename "<PRD path>")" 2>/dev/null | sed 's/^## Engineering — //' | sort -u
```

**Usual roster → one information line, no question.** Every roster agent appears in an earlier PRD **and** its stack is named in `devkit/ARCHITECTURE.md` → emit `Roster: eng-backend (F1, F2), eng-ios (F3).` and continue.

**Unusual roster → ask.** Ask when any of these holds:
- a roster agent appears in no earlier PRD (a new stack — this includes the project's first PRD);
- a roster agent's stack is not named in `devkit/ARCHITECTURE.md` (it differs from the project's usual roster);
- 3a found a stack `/cook` does not support (fold that warning into this one question).

Before the question, emit **2–3 lines of what the PRD is trying to do** (from the 1b digest's `summary`; if thin, the objective plus the feature count from `features`), then one line naming why the roster is unusual, then the table:

| Agent | Domain | Scope summary | PRD features covered |
|-------|--------|---------------|----------------------|

Then ask via `AskUserQuestion`:
- **Approve roster** — continue.
- **Revise roster** — the user gives the changes; re-run 3b with them (do **not** re-fetch `/cook`). A revised roster is approved by the revision itself.

**Execution table skeleton.** Once the roster is set, **decide** the exec-table rows and **render** them with the skeleton script (`refs/template-exec-table.md` is the guide for the table shape and the concern checklist):
- The F-IDs in §3 (F1, F2, …) are the canonical feature list and the key for every exec-table row.
- For each F-ID, decide the `(feature, concern, agent)` tuple for each applicable concern (API contract, schema migration, authentication, webhooks/hooks, client implementation, tests). **This judgment stays with the LLM.**
- Pipe the tuples as a JSON spec (one `{"fid","concern","agent"}` object per row, in row order) through the renderer. It resolves each `fid → <name>`, builds each `<F-ID>: <name> — <concern>` cell, sets Agent, and leaves **Files** blank — Files is derived from the tickets later, never typed:

```bash
S=.claude/scripts/script-em-exec-skeleton.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-exec-skeleton.py"
echo '[{"fid":"F1","concern":"API contract","agent":"eng-backend"}, …]' | python3 "$S" --write "$PRD_DIR/prd-[n]-[slug].md"
```

A spec `fid` absent from §3 is a hard error (exit 1) — fix the spec, never edit the PRD to match. `--write` replaces the placeholder of the reserved `## 6. Feature execution table` section. Never append a second `## Execution Table` heading. A missing reserved section is a hard error (exit 1) — restore it from `template-prd.md`. Either exit-1 path → log one DOCTOR row (`write-miss:script-em-exec-skeleton`), then handle it as stated.

**AHA.md update (conditional).** Before Step 4, capture a learning if any of: a PRD gap catchable in `plan-pm`; an architecture conflict that should inform future PRD templates; an overlap with a prior PRD that required a resolution decision. Use the file's one writer — never hand-append. Each field is one terse clause (≤140 chars):

```bash
A=.claude/scripts/script-aha.sh; [ -f "$A" ] || A="$HOME/.claude/scripts/script-aha.sh"
bash "$A" devkit/AHA.md --tag "em:<class>" --summary "<what happened>" --why "<root cause>" --note "<action or warning for future runs>"
```

`--tag` names the class (`em:prd-gap`, `em:arch-conflict`, `em:prd-overlap`) — same tag for the same class every time. Exit 3 (no `devkit/AHA.md`) → skip silently. Write only when ≥1 qualifying learning exists.

---

**Step 4/5 — Agents write**

Every run has the same shape: **plan half → "Start the build now?" → build half**. plan-em never starts the build without a Yes. Size decides only the check before the build half (Step 1e).

**Mode detection.** Run the digest `plan` slice (Step 1b command) and compare its `engineering_agents` against the roster from Step 3b:

| `engineering_agents` vs roster | `$MODE` | Run |
|-------------------------------|---------|-----|
| some roster agent missing (or the list is empty) | `plan` | § Plan half → § Ask → § Build half on Yes |
| **every** roster agent present | `build` | § Build half only — the resume path after a No, or after a run that died |

The PRD decides the mode, never the run-state file. Seed the run state now (`refs/internals.md` § Run-state file — init + roster).

**Dispatch lane.** Both halves share every precondition in both lanes. They differ only at the fan-out:

| `$TEAM_MODE` | Fan-out |
|--------------|---------|
| `team` (always, unless `--solo`) | one orchestrator spawn per half, per § Team lane |
| `solo` (hidden debug flag) | plan-em dispatches one leaf `eng` subagent per roster stack itself |

**Subagent context injection.** plan-em already read the PRD + devkit (Step 1) and compiled per-stack standards (Step 3a). Each `eng` leaf gets only what it needs:
- **Scoped context** — this agent's exec-table rows, the PRD **feature sections** those rows map to, and a **devkit digest** (canonical GLOSSARY terms, ARCHITECTURE constraints, DESIGN-SYSTEM components relevant to the rows, plus an **AHA slice**: at most 5 `devkit/AHA.md` entries matching this agent's rows/stack). Plus the **escape hatch**: *"The full PRD is at `<prd-path>`; read it (or a specific devkit file) on demand only if a scoped excerpt is insufficient to resolve a row."*
- **The size tier** *(plan leaves only)* — `intake grade C:<band> → write the <medium|large> shape`. The planner must not re-read `INTAKE.md` itself.
- **Standards payload** *(build leaves only)* — the compiled `/cook` output for this agent's stack. The build leaf does **not** call `/cook` itself.

Each agent acts only on its assigned rows and commits only to the resolved branch.

**House rules for the engineering plan (both lanes).** State them verbatim in the scoped context of every `--plan` leaf (and in the orchestrator's input), and apply them when writing the Step 5 findings:
- **One innovation token per plan, max.** If the plan introduces more than one unfamiliar technology, split it or pick one.
- **Extract on the third occurrence, not the second.** Duplication is cheaper than premature abstraction.

### Plan half (`$MODE = plan`)

1. **Todos umbrella.** Append the `## Todos` heading **once** (if absent) after the exec-table skeleton. plan-em writes it so parallel planners never race on it.
2. **Dispatch the planners.** `team` → § Team lane with `$MODE = plan`. `solo` → one parallel `Agent` subagent per roster agent, each running `eng --plan`. Field order follows `refs/internals.md` § Prompt-cache field order:
   - *Shared head:* "Read `.claude/skills/eng/SKILL.md` fully and follow its protocol." · mode flag `--plan` · `prd-path` · the two house rules · devkit digest.
   - *Per-agent tail:* `agent` (the exact **Agent** column value, e.g. `eng-backend`) · `rows` (semicolon-separated exact `<ID>: <name> — <concern>` Feature cells) · row-scoped context (mapped feature sections + AHA slice) · the escape hatch.

   Each agent writes its `## Engineering — <Agent>` section **and** its `## Todos — <Agent>` block (one `### F<n>` per owned feature, schema in `eng/refs/plan/template-todo.md`) in one pass. Emit a short progress note per completion.
3. **Stamp `status: specced`** once every agent has written both blocks:

   ```bash
   S=.claude/scripts/script-prd-stamp.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-stamp.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md" status specced
   ```

   An older PRD reads `status: eng`; leave it — every consumer reads the two as the same rung. Record `waves.plan.status done` in the run state.
4. **Files derivation.** The Files column is **derived from the tickets, never typed**:

   ```bash
   S=.claude/scripts/script-em-exec-skeleton.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-exec-skeleton.py"
   python3 "$S" --fill-files "$PRD_DIR/prd-[n]-[slug].md"
   ```

   `FILLED <prd> rows=<n> paths=<m>` → done. `EMPTY_FILES row=…` is informational (the feature carries the empty-work sentinel). **`MISSING_TICKETS row=<n> fid=<F> agent=<a>` (exit 1, nothing written) is a hard failure:** re-dispatch that agent's plan pass and log one DOCTOR row (`validator-fail:script-em-exec-skeleton`). Never hand-fill the cell. The derivation is idempotent — re-run it after any ticket edit, including one made by `plan-review`.
5. **Auto-review.** When the switch is on — the bare `--review` flag, or `policies.plan_em.review: true` in `devkit/policy.json` (absent = off; SKILL.md § Usage) — run the plan-review eng check now: `Skill("plan-review", "$PRD_DIR/prd-[n]-[slug].md --eng")`. Its result goes into the Step 5 digest. A Critical it leaves open stops the run here, as in the eng certification below. Switch off → run nothing; the closing message suggests `/plan-review`.

### Ask — "Start the build now?" (`$MODE = plan` only)

Print a short plan summary, then ask once. The summary is three lines:

```
Planned  F1 Set daily goal, F2 Track streak, F3 Daily reminder
Agents   eng-backend (5 tickets), eng-ios (3 tickets)
Check    <medium: plan-shape check runs before the build | large: eng certification runs before the build>
```

Then `AskUserQuestion` — "Start the build now?":
- **Start the build (Recommended)** — runs the check before the build, cuts `feat/<prd-id>`, and builds in this run. Recommended because the plan is complete and nothing else is needed from you.
- **Stop here** — ends the run with the plan written. Pick this to read or review the plan first (for example with `/plan-review`). A later `/plan-em <prd>` starts at the build half.

**Yes** → § Build half. **No** → record `waves.build.status not-started` in the run state, keep it open, and go to Step 5. Under an autonomy contract (a caller running hands-off), Yes is pre-approved.

### Build half (`$MODE = build`, or Yes)

1. **Check before the build — by `$SIZE`:**
   - **`large` → eng certification.** Run the gate checker (`reviewed:` stamp, or an older PRD's `eng-tuned:`):

     ```bash
     S=.claude/scripts/script-cert-status.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-cert-status.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md" --eng
     ```

     `CERTIFIED` → continue. `UNCERTIFIED …` → **run the plan-review eng check inline**: `Skill("plan-review", "$PRD_DIR/prd-[n]-[slug].md --eng")` (checks 2, 4, 5, 6, 7; the flag is internal). It auto-fixes Critical+Major, stamps through `script-prd-stamp.sh --certify`, and returns its result block. Re-run the checker; still `UNCERTIFIED` → **stop** (no build leaf dispatches on an uncertified eng plan) and log one DOCTOR row (`validator-fail:script-cert-status-eng`). The first `UNCERTIFIED` is never logged.
   - **`medium` → mechanical plan-shape check.** Once per planning agent:

     ```bash
     S=.claude/scripts/script-eng-plan-shape.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-eng-plan-shape.py"
     python3 "$S" "$PRD_DIR/prd-[n]-[slug].md" --agent "<agent>"
     ```

     Exit 0 → continue. Non-zero → **repair once**: re-dispatch that one agent's plan pass with the reported findings (a missing contract heading, a ticket violating the schema, a `### F<n>` block with no exec row, a cyclic `depends-on`, an `(edit)` path that does not exist), re-run `--fill-files`, and re-run the check once. Still failing → **stop before any build leaf** and log one DOCTOR row (`validator-fail:script-eng-plan-shape`).
2. **Branch resolution + lane move.** plan-em always cuts the branch, in both lanes. Run the resolver (READ-ONLY — it never mutates git or moves files), then execute what it emits:

   ```bash
   S=.claude/scripts/script-em-branch-resolve.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-branch-resolve.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md"
   ```

   Set `$BRANCH` from `BRANCH=`, then act on `ACTION=`:

   | `ACTION` | Meaning | What to run |
   |----------|---------|-------------|
   | `create` | branch absent | `git checkout -b $BRANCH main && git push -u origin $BRANCH` |
   | `checkout` | branch exists, not yet merged (e.g. a sub-PRD's parent branch) | `git checkout $BRANCH` — do **not** re-create or reset |
   | `fresh-cut` | branch exists but already merged to `main` | same as `create` with the emitted `$BRANCH` |

   Then run the emitted `LANE_MOVE=` verbatim **unless** it is `none` (the folder carries `reports/`, `preflight.md` and `test/` with it). Record the branch in the run state.

   Branch naming is `feat/<prd-id>` (the PRD folder basename). The resolver never reuses a branch already merged to `main`: a sub-PRD then uses its own id (`feat/prd-2.1-streak-freeze`), a top-level PRD gets the next free `-N` suffix. A sub-PRD otherwise rides the parent's branch and never moves lane.
3. **Stamp `status: wip`** once the branch exists (do not stamp a sub-PRD — the parent's stamp covers it):

   ```bash
   S=.claude/scripts/script-prd-stamp.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-stamp.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md" status wip
   ```

   An older PRD has no `wip` value — leave `status: eng`.
4. **Collision pre-check (solo lane; the orchestrator runs its own `--waves` check).** Isolate §6 and pipe it into the collision checker (the awk matches both the reserved `## N. Feature execution table` heading and a legacy `## Execution Table`):

   ```bash
   S=.claude/scripts/script-em-exec-collision.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-exec-collision.py"
   awk 'tolower($0) ~ /^## ([0-9]+\. )?(feature execution table|execution table)[[:space:]]*$/{f=1;next} f&&/^## /{exit} f' "$PRD_DIR/prd-[n]-[slug].md" | python3 "$S"
   ```

   Exit 1 (collisions) → keep each `COLLISION` pair on one agent (serial); not an incident. **Exit 3** (`ERROR=no-files-column`) → the table is malformed: restore the column from `refs/template-exec-table.md`, re-run the Files derivation, log the DOCTOR row, and never read exit 3 as "no collisions". A `MISSING_FILES` line on any in-scope row → stop, run the Files derivation, and log one DOCTOR row (`validator-fail:script-em-exec-collision`).
5. **Dispatch the build leaves.** Build leaves need the branch to exist and hard-fail without it. `team` → § Team lane with `$MODE = build`. `solo` → one parallel subagent per roster agent, each running `eng --build`. Field order per `refs/internals.md` § Prompt-cache field order:
   - *Shared head (per stack):* "Read `.claude/skills/eng/refs/build/protocol-packet.md` fully and follow it." (the orchestrated build leaf's fast path — it assumes the branch is checked out, the payload and scoped context are injected, and every gate except the db-touch pause is pre-approved) · mode flag `--build` · `prd-path` · `branch`: `$BRANCH` · devkit digest · the stack's standards payload.
   - *Per-agent tail:* `agent` (e.g. `eng-backend`) · `rows` · row-scoped context · **review-artifact identity**: `<K>` = this agent's name and `built_by` = the same name (the leaf's reviewer writes `<prd-dir>/reports/review-prd-<N>-<K>.json`, per `.claude/skills/eng/refs/review/protocol.md` § Artifact) · the escape hatch.

   Emit a short progress note per completion and record each returned agent in the run state. **On a resumed run**, dispatch only the agents the state does not mark `done`.
6. **Review coverage (solo lane).** Before Step 5, ask the script, not the agents:

   ```bash
   R=.claude/scripts/script-eng-review-check.sh; [ -f "$R" ] || R="$HOME/.claude/scripts/script-eng-review-check.sh"
   bash "$R" --reports-dir "$PRD_DIR/reports" --expect "<the dispatched agent names, comma-separated>"
   ```

   Exit 0 → keep its coverage line for the digest and record it in the run state. Exit 1 → **repair, don't rebuild**: spawn one `eng --review` over that agent's rows and diff (never the agent that wrote the code), injecting `built_by=<agent>` and `<K>=<agent>`, then re-check once. Still missing → name the uncovered agents in the digest and log one `tool-error:review-<agent>` DOCTOR row. Exit 2 or an absent script is a harness fault (`validator-fail:script-eng-review-check`), never coverage. The digest must state coverage; one that cannot is a hard failure. Review findings gate nothing — `pre-merge` is the safety floor.

**Status stamps land at their real triggers:** `specced` when the plan half's sections and tickets exist, `wip` when the branch is cut. A run that plans and builds writes both, in that order.

### Team lane

Run every precondition above exactly as written. Then, **instead of** fanning out the leaves, spawn **one orchestrator engineer agent per half**:

- Open the dispatcher heartbeat and watch first (`refs/internals.md` § Team-lane heartbeat relay — a fresh `TEAM_RUN_ID` per spawn).
- Spawn via the `Agent` tool with `model: opus`, `run_in_background: true`, and a prompt that (a) says *"Read `.claude/skills/plan-em/refs/protocol-team.md` fully and follow it"* and (b) injects its input contract: `$MODE` (`plan` or `build`), `prd-path`, the `roster`, the `exec_table` rows (with `Files` on the build half), `$BRANCH` **and** the per-stack `standards payloads` (build half only), the devkit digest, the house rules (plan half), `$SIZE` + intake `C:` band, `$TIMING_RUN_ID`, `$STATUS_RELAY`, and the escape hatch. **Never inject `$TEAM_RUN_ID`.**
- Register it as one watched leaf, hold the turn and poll, and close both states on every exit path (`refs/internals.md` § Team-lane heartbeat relay).
- The orchestrator decomposes the half into file-disjoint, model-tiered packets and fans out leaf `eng` subagents. It never runs a certification, resolves or cuts the branch, stamps the PRD status, or invokes `/cook`. Exactly one agent cuts the branch — plan-em — and leaves never touch branches.
- The plan-half orchestrator returns after the planners land. plan-em then stamps, derives Files, runs the auto-review, and asks. On Yes, plan-em runs the check before the build, cuts the branch, and spawns a **second** orchestrator for the build half.
- When an orchestrator returns, its consolidated summary is that half's output for Step 5.

---

**Step 5/5 — Digest and next step**

**Read the outcome** via the digest **synth** slice (two-path resolution):

```bash
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"; python3 "$G" <prd-path> --slice synth
```

It returns frontmatter + `features` + `exec_table` + every agent's `engineering` block + `open_questions`. **Escape hatch:** for a cross-section conflict that needs product prose, read only that section's `prose_lines` range.

**Findings.** Collect every gap, conflict or open question across the sections, the build summaries and any plan-review result block from this run (Step 2, auto-review, eng certification). Severity: **Critical** (blocks the work, needs a decision) / **Major** (needs a mid-flight PRD revision) / **Minor** (note for future cycles).

**Print the digest** directly above the closing message. One line each; omit a line that has nothing to say:

```
Built     F1 Set daily goal, F2 Track streak · eng-backend, eng-ios
Branch    feat/prd-3-habit-tracking
Review    2/2 agents reviewed
Findings  1 Critical · 2 Major · 1 Minor
```

- **Built** — the features and stacks. A run that stopped after the plan half prints **Planned** instead.
- **Branch** — the branch the build is on. A plan-only run prints `not cut yet — the build cuts feat/<prd-id>`.
- **Review** — the coverage line from the review check (agents in solo, packets in team). Omitted on a plan-only run.
- **Findings** — counts by severity, including plan-review's open items. Omitted when 0.

Below the digest, list each **Critical** finding (location: PRD section + owning agent; required action). Batch them into one `AskUserQuestion` (≤4 per call), apply the answers, then continue. A Critical the certifier should have caught (an uncertified-field contract break) means the eng check was skipped — re-run it rather than hand-patching here. Major and Minor findings stay in the PRD's engineering sections; the digest gives only their counts.

**Close the run state** per `refs/internals.md` § Run-state file — except after a **No** at the Ask, where the state stays open with the build not started.

**Next step.** plan-em recommends the next command and never invokes it. End with the closing message per `../../shared/refs/closing-message.md`, taking the step verbatim from the registry row for how the run ended: `plan-em — plan wave` after a **No** (run `/plan-em <prd>` again to build), `plan-em — build wave` after a build (run `/pre-merge`). Never compose the step.

Final state: the PRD holds every engineering section and a `## Todos — <Agent>` block per agent under one `## Todos` heading; after a build, the code is on `$BRANCH`; no Critical finding is unresolved.

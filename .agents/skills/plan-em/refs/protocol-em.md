---
name: EM Protocol
description: End-to-end five-step execution protocol for plan-em — validate/pre-flight, certification precondition, roster, agents write (fused plan+build wave on a medium PRD, two waves on a large one), synthesise
type: reference
---

# EM Protocol

The five-step protocol plan-em runs end-to-end. Ref paths (`refs/template-exec-table.md`) resolve relative to the skill root.

**Harness incidents.** Any script this protocol runs that exits non-zero on an outcome the step's own text does not document appends a `devkit/DOCTOR.md` row via the shared appender, per `../../shared/refs/doctor-logging.md`. Logging never changes control flow — the step's own rule (continue, stop, repair-once) still decides. The individual call sites below name their signature.

**Stage timing.** Every structural saving in v5.4 is an *estimate* until a real run says where its hour went, so this protocol marks each stage boundary it crosses. Fix one `$TIMING_RUN_ID` per run (`em-$(date +%s)` — reuse the heartbeat's `RUN_ID` when there is one) and append one line at each boundary below:

```bash
T=.claude/scripts/script-em-timing.sh; [ -f "$T" ] || T="$HOME/.claude/scripts/script-em-timing.sh"
bash "$T" --stage <stage> --reports-dir "$PRD_DIR/reports" --run-id "$TIMING_RUN_ID" --note "<optional>" || true
```

| Stage name | Fires when |
|------------|-----------|
| `pre-flight-done` | Step 1 finishes (1a–1e complete, size resolved) |
| `cert-done` | Step 2's certification returns `CERTIFIED` |
| `skeleton-done` | Step 3's exec-table skeleton is rendered (after the roster gate — this boundary therefore contains the human wait, which is exactly what makes it worth separating) |
| `plan-half-done` | every agent's `## Engineering —` + `## Todos —` blocks exist |
| `files-collision-done` | `--fill-files` and the collision decomposition have both returned |
| `branch-done` | the branch is created/checked out and the lane move (if any) has run |
| `build-wave-<n>-done` | build wave `<n>` has returned — one line per wave |
| `review-check-done` | the review-coverage check has returned (after any repair spawn) |
| `synthesis-done` | Step 5's synthesis is emitted — the run's last line |

**Best-effort, always.** The `|| true` is part of the contract: a timing append that fails changes nothing about what the run does next, and no step may branch on its exit code. The log is append-only at `$PRD_DIR/reports/timings-<date>.log`, so nothing a previous run wrote is ever rewritten. In `--team` mode the orchestrator marks the boundaries that happen inside its own spawn (`refs/protocol-team.md` § Stage timing) using the **same run id**, so one run reads as one timeline.

## Step-by-step protocol

---

**Step 0 — Resolve execution mode** (resolve before Step 1)

Resolve `$TEAM_MODE` from the **inline flag**, else the **persisted preference**, else the
default. The pref file (path resolution, schema, and the read snippet) is defined in
`.claude/skills/shared/refs/exec-mode-pref.md` — the shared source of truth `/msg --init`
seeds at bootstrap (`/msg --update` tops it up on older repos). Precedence:

1. **Inline flag wins.** `--solo` / `--team` in the invocation → set `$TEAM_MODE` to it,
   **persist** `{"exec_mode": "<target>"}` to the resolved pref path (§ Read + flag-override
   in the shared ref — create `.claude/msg/` if needed), and emit `Execution mode: <target>
   (persisted).`. Both flags at once → hard failure: `Pass at most one of --team / --solo.` Stop.
2. **Else read the pref file** (local `.claude/msg/pref.json`, then global `~/.claude/msg/pref.json`
   — local wins) → its `exec_mode` → `$TEAM_MODE`.
3. **Else default `team`** (**the pipeline default**). Do **not** create the pref file here —
   `/msg --init` (or `--update`) seeds it when absent.

Strip the recognised flag from the argument string **before** resolving the PRD path in
Step 1a, so path validation never sees it. `$TEAM_MODE` is consumed only at Step 4 (the
dispatch lane); every other step is identical in both modes. Cache it for the run — a
later `plan-em` invocation (e.g. the build wave after the plan wave) re-resolves it the
same way, so the persisted pref carries the choice across waves without re-passing a flag.

---

**Step 1/5 — Validate and pre-flight**

**1a. Validate PRD path.** Must exist and match a lane-lifecycle path — `features/{planned,wip,done}/prd-*/prd-*.md` (top-level) **or** `features/{planned,wip,done}/prd-*/prd-*/prd-*.md` (nested sub-PRD, e.g. `features/wip/prd-2-habit-tracking/prd-2.1-streak-freeze/prd-2.1-streak-freeze.md`) — **or** the legacy flat form `features/prd-*/prd-*.md` (top-level) / `features/prd-*/prd-*/prd-*.md` (nested sub-PRD).
- Store the matched PRD's own parent directory as `$PRD_DIR`; write **every** artifact relative to `$PRD_DIR`, never a reconstructed `features/prd-[n]/`.
- Derive `n` = first numeric segment of that parent dir name (`prd-3-habit-tracking` → `n=3`; `prd-2.1-streak-freeze` → `n=2`, the parent's number for a sub-PRD).
- On failure: refuse, emit the rule, produce no output.

**1a′. Run-state resume check (v5.6.5).** Before any pre-flight work, read the run-state file:

```bash
S=.claude/scripts/script-em-state.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-state.py"; python3 "$S" --get --file "$PRD_DIR/reports/em-state.json"
```

- `NO_STATE`, `CORRUPT`, or a state with `"status": "closed"` → fresh run; continue to 1b. (Corrupt is never a hard failure — session-cache rule 4 applies; log one DOCTOR row `validator-fail:script-em-state` only if the file existed and would not parse.)
- An **open** state → summarise it in one line from the JSON (e.g. `Open run found: mode build, plan wave done, 2 of 4 build agents returned.`) and ask via `AskUserQuestion`: **Resume** (default; skip work the state marks done — the existing Step 3 resume rules already govern the plan-wave artifacts, and § Step 4 skips build agents marked `done`) / **Start fresh** (`--archive` the file to `em-state.json.prev`, then continue as a fresh run) / **Abort**. *(Under an autonomy contract — orchestrator running hands-off — Resume is pre-approved; do not fire the gate.)*

The state file is **resumability only**: it never carries a verdict, never substitutes for the heartbeat or agent-watch (those stay observational), and every later write in this protocol rides a step that already exists — never add a step to create a checkpoint.

**1b. Mandatory pre-flight scan (devkit + PRD).** Devkit files live in `devkit/` (created by `/msg --init`); `CLAUDE.md` is at project root. Read all, in order:

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
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"; python3 "$G" "<PRD path>" --slice plan
```

The `plan` slice returns `frontmatter` (incl. `deps` — plus the v5 keys `platform`/`module`/`affects`/`depends_on` when the PRD predates v5.4, `null` otherwise), `summary`, `features` (F-IDs + acceptance criteria verbatim), and `exec_table` — the inputs the roster and exec-table build consume (Steps 3–4). The generator re-parses the current PRD on every call → the slice is never stale and PRD prose stays canonical (see `.claude/skills/shared/refs/session-cache.md`). **Escape hatch:** if a pre-flight check needs prose the slice omits — User-flow narrative for a terminology/architecture-conflict finding, or a heading under the digest's `unparsed_sections` — read only that section's `prose_lines` range. Do **not** default to the whole PRD.

**Absent-file rule.**
- No `devkit/` → emit `devkit/ not found — run /msg --init to initialise the project first.` and **stop** (do not proceed to Step 2).
- `devkit/` exists but a file missing → emit `<filename> not found — run /msg --init to initialise the project first.` Proceed without it; do not create it.

**1c. Multi-PRD cross-reference — consume the certified graph, ask only on conflict (I3/D19).**

By the time plan-em runs, the PRD's cross-PRD graph is **already established** by two upstream mechanisms plan-em consumes silently — it does **not** re-ask what they already answered:
- **intake** graded sequencing into the `S:` cell (`S:now/next/later/blocked-by-#n`), positioning this PRD against the rest of the backlog.
- **plan-review** verified the frontmatter graph in certification check 6 (`deps` correctness + acyclicity) — a precondition already enforced by Step 2 for the product wave (and Step 4 for the build wave).

So the v1 per-relationship `AskUserQuestion` gate (Dependency / Breaking change / Overlap, three questions) is **deleted**. Instead:

1. **Fast scan via the lane-aware scanner** — run the deterministic PRD inventory with `--exclude` set to the input PRD's own id (two-path resolution), which emits one JSONL object per prior PRD across all lanes (`planned/`, `wip/`, `done/`) and the legacy flat path, omitting the input PRD's own line:

   ```bash
   S=.claude/scripts/script-prd-scan.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-scan.sh"; bash "$S" --exclude prd-[n]-[slug]
   ```

   A non-zero exit from the scanner is not an expected outcome — log one DOCTOR row (`tool-error:script-prd-scan`) per § Harness incidents, then continue with an empty prior-PRD inventory rather than blocking the run.

   Read each prior PRD's `deps` from the JSONL (no file open) — the scanner emits that field for a PRD of either shape. Cross-check against the input's certified `deps` and its codebase/feature scan.

   **This is a deps-only conflict check.** v5.4 removed `module` and `affects`, so the dependency array plus the §3 Dependencies column it mirrors are the entire cross-PRD graph. There is no domain-match shortcut and no reverse "who does this break" edge to consult.
2. **Ask only on a genuine conflict** — one `AskUserQuestion` fires **only** when the certified graph contradicts what the codebase/feature scan implies, e.g.:
   - the certified `deps` names a PRD whose surface this PRD's features plainly do **not** touch (a spurious edge), or
   - the feature scan reveals an **undeclared** dependency on a prior PRD absent from `deps` (a missing edge the certifier didn't catch because it never touched an executable field).
   Options for a conflict: **Trust the certified graph** / **Amend the graph** (add/remove the edge — then apply the frontmatter writeback below) / **Stop and reconcile**.
3. **Expected on a clean run: zero relationship questions.** A PRD whose certified graph matches its scan proceeds silently.

**Frontmatter writeback (only when Step 2 above amended an edge):** add or remove the reconciled ids in the input PRD's `deps` array (merge, no duplicates) — and add the corresponding id to the §3 Dependencies cell it mirrors, so the two cannot drift. Prefer `script-prd-deps-mirror.sh` over a hand `Edit`: it targets whichever array name the file carries, so a PRD written before v5.4 keeps its `depends_on` line. On a clean run (no amendment) this is a no-op.

**1d. Pre-flight findings — written only when there are findings.** Collect what 1b and 1c turned up across six categories:
- **Terminology deviations** — PRD terms not matching GLOSSARY.md
- **Architecture conflicts** — features contradicting/ignoring ARCHITECTURE.md
- **AHA.md warnings** — applicable past learnings
- **Design system impact** — components impacted, data-ingestion needs, new components required (from DESIGN-SYSTEM.md scan)
- **Multi-PRD findings** — a deps-vs-scan conflict and how it was resolved (per 1c; a clean graph produces no finding)
- **PRD gaps** — sections too ambiguous/incomplete to map domains

Then branch on whether there is anything to say:

- **At least one finding → write `$PRD_DIR/preflight.md`** (create or overwrite) with every finding in full. Do not hold the full report in context. Emit inline **only actionable findings** — those needing a decision before proceeding (blocking PRD gaps, architecture conflicts, multi-PRD questions). Informational findings (AHA warnings, terminology notes, design-system observations) stay in the file, available on request.
- **No findings → write no file.** Emit one line instead: `Pre-flight clean — devkit + PRD scanned, no findings.` A file whose content is six empty headings is not evidence of a clean scan; it is a write, a read on every later visit, and a thing to keep in sync. The inline line carries the same information at a fraction of the cost, and the *absence* of `preflight.md` means exactly one thing — the scan found nothing.

**A stale `preflight.md` from an earlier run is deleted, not left.** If the file exists and this run is clean, remove it: a clean run that leaves last run's findings in place is worse than one that never wrote them, because the file now describes a PRD state that no longer holds.

**1e. Resolve the size tier (`$SIZE`) — the one input that shapes the whole run.** v5.4 sizes the ceremony to the PRD instead of paying the large-PRD cost every time, and **intake's complexity grade is the measure**. Resolve it once here; every later step consumes the answer and never re-derives it.

The Step 1b digest already returned `frontmatter`, which carries `intake: #<n>` — the row id in the root `INTAKE.md` ledger, whose grade cell reads `C:<band> T:<band> S:<sequencing>`. Read that row's `C:` band:

| `C:` band | `$SIZE` | What it buys |
|-----------|---------|--------------|
| **≥ 8** | `large` | The two-wave path, unchanged: plan wave → second `/plan-em` → build wave, with a certification before each. |
| **< 8**, or unresolvable | `medium` (**the default**) | The **fused** wave: one `/plan-em` invocation plans *and* builds, behind one certification. |

**Default to medium.** No `intake:` key, no matching row, an unparseable grade cell, or no `INTAKE.md` at all → `medium`. This is the same rule and the same grade cell that `eng --plan` tiers its section shape on (`eng/refs/plan/protocol.md` § Which shape); resolving it once here and **injecting it into every leaf's scoped context** is what keeps the two decisions from disagreeing. Emit the resolution in one line — `Size: medium (intake #12, C:5) — fused plan+build wave.` — so the human can see which path the run took before it takes it.

---

**Step 2/5 — Certification precondition (product wave)**

Certification is a **precondition, not a choice** (D18). Before any agent writes anything, the product-side certification must have passed — plan-em runs it inline rather than asking. Without this, checks 1/2/3/6 would be advisory and an unenforced gate decays into documentation.

**How many certifications a run pays depends on `$SIZE` (Step 1e):**

```
$SIZE = medium →  Step 2: certify product  →  FUSED wave (plan half → mechanical shape check → build half)
$SIZE = large  →  Step 2: certify product  →  plan wave  ┊  Step 4 (build mode): certify eng → build wave
```

A **medium** run pays **one** certification, here. The between-wave eng certification is not skipped work that reappears later — it is deleted for this size, and a **mechanical** plan-shape check stands in its place immediately before the build half dispatches (§ Fused mode below). The reasoning: the eng cert's value is catching a *human-authored* plan that drifted from the PRD across a session boundary; a fused run has no session boundary, and the ticket-schema failures that actually break a build wave are exactly what `script-eng-plan-shape.py` catches mechanically, in seconds, for free. A **large** run keeps both certifications — its plan half is genuinely a separate sitting.

Run the certification gate checker on the input PRD (certification stamp + open-Critical scan of the findings ledger, two-path resolution). On a v5.4 PRD the stamp it reads is the single `reviewed:` field and the ledger is `reports/review-prd-[n]-[slug].md`; on a PRD written before v5.4 it reads that file's `product-tuned:` stamp and its inline §7 section instead — the flag name is unchanged either way:

```bash
S=.claude/scripts/script-cert-status.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-cert-status.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md" --product
```

- `CERTIFIED` (exit 0) → certified; proceed straight to agent identification.
- `UNCERTIFIED …` (exit 1 — `no-stamp` or `open-critical <id>`) → **run `plan-review --product` inline**: `Skill("plan-review", "$PRD_DIR/prd-[n]-[slug].md --product")` (the input PRD path resolved in Step 1a). The certifier auto-fixes Critical+Major, stamps `reviewed: yes` (`product-tuned: yes` on a pre-v5.4 PRD), and terminates recommend-only. When it returns, **re-run the checker**:
  - `CERTIFIED` → proceed to agent identification.
  - The certifier hit its **product-decision pause** (a fix needing a human product choice) → it already batched that question; once the user answers and the certifier finishes, re-check. If a Critical remains genuinely unresolved after the certifier ran, **stop** and surface it — plan-em never plans on an uncertified PRD — and log one DOCTOR row (`validator-fail:script-cert-status-product`) per § Harness incidents. The *first* `UNCERTIFIED` is expected (it is what triggers the inline certify) and is never logged; only the repair-once loop's still-failing arm is.

No `AskUserQuestion` in this step — the certifier is autonomous and cheap; its own product-decision pause is the only stop.

---

**Step 3/5 — Identify agents and get approval**

**Resume rules — Steps 1–3 re-run on every invocation.** The build wave arrives as a *second* `/plan-em` on the same PRD, so this step must be idempotent. Check the PRD's current state before doing 3b's work and take the resume path wherever it applies:

- **Exec table already present** — the reserved `## 6. Feature execution table` section holds real rows rather than its `_To be populated by plan-em …_` placeholder. **Verify, do not render:** confirm (i) that section is the table's only home — no second `## Execution Table` heading was appended alongside it — and (ii) every row's Feature cell keys on an F-ID that still exists in the PRD's §3 Features & acceptance criteria table. Verified → skip the skeleton render entirely; **never append a second table.** A verification failure (a duplicate table, or a row keying on an F-ID §3 no longer carries) is a hard stop — surface it and let the user reconcile; do not re-render over it.
- **Roster already approved** — the digest's `engineering_agents` field (the same field Step 4 mode-detection reads) already lists every agent the roster in 3b would propose. This is the build-wave case: the gate is a **per-PRD approval, not a per-wave one**, and it already happened. **Confirm in one line and move on** — e.g. `Roster unchanged from the plan wave: backend-eng, eng-ios.` Do not re-present the roster table, do not emit the intent summary again, and do not re-fire the approval `AskUserQuestion`.
- **3a still runs either way — but consult the standards cache first (v5.6.5).** The build wave's dispatch (Step 4) needs the compiled `/cook` payloads; since v5.6.5 they persist across runs under `.claude/msg/cache/` (§ 3a cache check below), so "runs either way" usually means a cache hit, not a recompile. Only 3b's approval interview and the skeleton render are resumable.

**3a — Compile coding standards (flags) to confirm agent types.** Before proposing any roster, derive platform identifiers from the PRD frontmatter `platform` field and the Features & acceptance criteria table. Then call `/cook` **once per implied platform via explicit flags** — never a prose summary — using the stack→flag derivation in `.claude/skills/eng/refs/build/protocol.md` (§ Coding-standards flags): `--global` (mandatory, unscoped — guarantees the P0 floor) plus, for each platform, **diff-scoped domain sub-ref flags** rather than the bare domain flag.
- **Scope each domain, don't over-load.** A bare domain flag (`--macos`, `--react`) compiles the domain's `SKILL.md` **plus every** `refs/*.md` — the full shelf. Instead, mirror the eng derivation so the orchestrator-compiled payload is scoped too (both paths must agree — standalone `eng` and orchestrated runs): enumerate the domain's refs (`<cook>/standards/<domain>/refs/` or its `_INDEX.md` — never a hardcoded list), keep every ref by default, and **drop a ref only when the PRD/devkit provably excludes its subject** (e.g. `distribution.md` when `CLAUDE.md` defers distribution; `localization.md` with no i18n in scope; `sandbox-and-tcc.md` with no entitlements/sandbox). Signals: the exec-table **Files** column, the row **concerns**, and the devkit's provable exclusions. **Never under-load — missing a relevant standard is worse than loading an extra one:** on any uncertainty keep the ref, and if a whole domain can't be confidently scoped fall back to the **bare** domain flag (full shelf). Always keep the domain `SKILL.md` floor (emit the bare `--<domain>` flag to anchor it), then emit `--<domain>:<ref>` for each kept ref (e.g. `--global --macos --macos:architecture-and-state --macos:windows-and-scenes --macos:performance-accessibility --macos:hig-conventions`). This scoping applies to **domain** flags only; `--global` stays whole.
- **Cache check before every cook call (v5.6.5).** Once the flag set for a stack is derived, ask the persistent cache before invoking `/cook`:

  ```bash
  C=.claude/scripts/script-standards-cache.py; [ -f "$C" ] || C="$HOME/.claude/scripts/script-standards-cache.py"
  python3 "$C" --check --flags "<the derived flag set>"
  ```

  `HIT <payload-path>` → read that file as the compiled payload for this stack and **skip the `/cook` call**. `MISS` (any reason) → call `/cook` exactly as above, write the returned payload to a temp file, then `python3 "$C" --store --flags "<same flag set>" --payload <temp-file> || true` (best-effort; a failed store never blocks the run). The cache is hash-keyed on cook's own source files, so a standards edit invalidates it automatically — see `../../shared/refs/session-cache.md` § Consumers.
- Read each result fully (cache hit or fresh compile) and **retain the compiled payload per stack** — this is the *compile-once, share-many* standards payload injected into build subagents at Step 4. Cook is called **at most once per distinct stack per run**, and with a warm cache, zero times.
- A platform whose flags `/cook` accepts is covered; its flag names the canonical agent identifier (`eng-<platform>`). Do not derive agent names from the PRD alone — `/cook`'s flag set is the authority on supported platforms.
- If `/cook` has no flag for an implied platform (rejects the flag with the valid-flag list): surface as a blocking gap — emit a warning, list the uncovered platform, and ask via `AskUserQuestion` before continuing.

**3b — Propose language-targeted roster and get approval.** Map every PRD feature to the covered platforms from 3a. One agent per language/platform stack in scope. Do **not** collapse platforms to reduce count: `eng-ios` and `eng-android` own different codebases, toolchains, and integration concerns — never merge. An under-staffed roster produces a worse plan.

**Open the gate with the PRD's intent.** This is the run's single human gate, and an approver cannot judge staffing for a feature the message never restates. So **before** the roster table, emit **2–3 lines of what the PRD is trying to do** — the product intent, not the engineering shape. Source it from the Step 1b digest's `summary` field (already in hand — no new read, no new script); if `summary` is thin, distil the objective plus the feature count from the digest's `features`. Then the table, then the question.

Present as a table:

| Agent | Domain | Scope summary | PRD features covered |
|-------|--------|---------------|----------------------|

Then ask approval via `AskUserQuestion`:
- **Approve roster** — proceed with agent activation.
- **Revise roster** — user provides changes; re-run 3b with the revision (do **not** re-fetch `/cook`).

Do not activate any agent without explicit approval.

**Execution table skeleton.** Once the roster is approved, **decide** the exec-table rows but **render** them with the skeleton script — anchor typos and row-text drift are then impossible (`refs/template-exec-table.md` is the guide for the table shape and the concern checklist):
- Enumerate features from the PRD's Features & acceptance criteria table — the F-IDs there (F1, F2, …) are the canonical feature list and the key for every exec-table row.
- For each F-ID, enumerate applicable execution concerns (API contract, schema migration, authentication, webhooks/hooks, client implementation, tests — the checklist in `refs/template-exec-table.md`) and decide the `(feature, concern, agent)` tuple for each row. **This judgment stays with the LLM.**
- Emit those tuples as a JSON spec — one `{"fid","concern","agent"}` object per row, in row order — and pipe it through the renderer (two-path resolution). It reads §3 to resolve each `fid → <name>`, builds each `Feature — concern` cell as `<F-ID>: <name> — <concern>`, sets Agent, and leaves **Files** blank — the table is three columns as of v5.4 (`Feature — concern | Files | Agent`), and Files is filled later by derivation, never by an agent:

```bash
S=.claude/scripts/script-em-exec-skeleton.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-exec-skeleton.py"
echo '[{"fid":"F1","concern":"API contract","agent":"backend-eng"}, …]' | python3 "$S" --write "$PRD_DIR/prd-[n]-[slug].md"
```

A spec `fid` absent from §3 is a hard error (exit 1, named on stderr) — fix the spec, never edit the PRD to match. `--write` puts the rendered table in the PRD's **reserved `## 6. Feature execution table` section** — the exec table's one home — replacing its `_To be populated by plan-em …_` placeholder. Never append a second `## Execution Table` heading; that legacy name is read-tolerated by the parsers for pre-v5 PRDs and is written by nothing. A missing reserved section is a hard error (exit 1) — restore it from `template-prd.md`, do not invent a heading.

Either exit-1 path is an undocumented-failure exit: log one DOCTOR row (`write-miss:script-em-exec-skeleton`) per § Harness incidents, then handle it exactly as stated above.

**Files derivation (after the plan wave, before anything reads the table).** The Files column is **derived from the tickets, never typed** — planner agents write tickets and stop. Once the plan wave has returned and every `## Todos — <Agent>` block exists, run the derivation once over the PRD:

```bash
S=.claude/scripts/script-em-exec-skeleton.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-exec-skeleton.py"
python3 "$S" --fill-files "$PRD_DIR/prd-[n]-[slug].md"
```

`FILLED <prd> rows=<n> paths=<m>` means the collision graph is now derivable. `EMPTY_FILES row=…` is informational — that row's feature carries the empty-work sentinel, so a blank cell is correct. **`MISSING_TICKETS row=<n> fid=<F> agent=<a>` (exit 1, nothing written) is a hard failure:** an exec row names an F-ID that agent never wrote tickets for, so the plan wave is incomplete — re-dispatch that agent's plan pass and log one DOCTOR row (`validator-fail:script-em-exec-skeleton`) per § Harness incidents. Never hand-fill the cell to move past it; a typed cell that disagrees with the tickets makes every downstream collision result a lie.

The derivation is **idempotent and re-runnable** — re-run it after any ticket edit, including one made by `plan-review`.

**AHA.md update (conditional).** Before Step 4, capture a learning if any of: a PRD gap catchable in `plan-pm`; an architecture conflict that should inform future PRD templates; an overlap with a prior PRD that required a resolution decision. For each, go through the file's one writer — never hand-append. Each field is one terse clause (≤140 chars; the writer rejects longer):

```bash
A=.claude/scripts/script-aha.sh; [ -f "$A" ] || A="$HOME/.claude/scripts/script-aha.sh"
bash "$A" devkit/AHA.md --tag "em:<class>" --summary "<what happened>" --why "<root cause>" --note "<action or warning for future runs>"
```

`--tag` names the class (e.g. `em:prd-gap`, `em:arch-conflict`, `em:prd-overlap`) — same tag for the same class every time, so recurrences count. Exit 3 (no `devkit/AHA.md`) → skip silently. Write only when ≥1 qualifying learning exists — never an empty entry.

---

**Step 4/5 — Agents write**

**Execution lane (`$TEAM_MODE`, from Step 0).** This step has two dispatch lanes; they
share **every precondition** — mode detection, the plan-wave `## Todos` umbrella heading,
the build-wave eng-certification precondition, and build-wave branch resolution + lane
move all run identically. They diverge only at the **fan-out**:

| `$TEAM_MODE` | Fan-out |
|--------------|---------|
| `solo` | plan-em dispatches the leaf `eng` subagents directly — **one per roster stack**, whole-stack scope, inherited model — exactly as the Plan-mode / Build-mode sections below describe. |
| `team` (default) | plan-em runs the same preconditions, then hands the wave to **one orchestrator engineer agent on Opus** (per § Team lane below) instead of fanning out leaves itself. |

Run mode detection and the mode-specific preconditions first (they are lane-independent),
then take the fan-out for `$TEAM_MODE`.

**Mode detection.** Run the digest for the `plan` slice (the Step 1b invocation pattern) and read its `engineering_agents` field — the ordered list of `<Agent>` names the generator parsed from the PRD's `## Engineering — <Agent>` headings:

```bash
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"; python3 "$G" "<PRD path>" --slice plan
```

Compare `engineering_agents` against the **approved roster** (Step 3b), then cross it with `$SIZE` (Step 1e). Three modes:

| `$SIZE` | `engineering_agents` vs roster | `$MODE` | Meaning |
|---------|-------------------------------|---------|---------|
| `medium` | some roster agent missing (or the list is empty) | **`fused`** | Nothing planned yet → plan **and** build in this one invocation (§ Fused mode). |
| `medium` | **every** roster agent present | `build` | **The resume path.** A fused run was interrupted after its plan half landed; re-invoking `/plan-em` finds the sections written and proceeds with the build half only. |
| `large` | some roster agent missing (or the list is empty) | `plan` | The plan wave. The run ends after it; the build wave arrives as a second `/plan-em`. |
| `large` | **every** roster agent present | `build` | The build wave of the two-wave path. |

The `engineering_agents` comparison is therefore doing two jobs at once: it is the wave selector for a large PRD and the **resume detector** for a medium one. That is deliberate — an interrupted fused run leaves exactly the same on-disk evidence a completed plan wave does, so the same signal recovers it from the PRD itself. The v5.6.5 run-state file never overrides this: **mode selection is always PRD-evidence-driven**, and `em-state.json` only adds what the PRD cannot show — which build agents of an open wave already returned. If the state file and the PRD evidence disagree, the PRD wins and the stale state is archived (`--archive`).

**Run-state init (v5.6.5).** With `$MODE` now resolved, seed the state file for a fresh run (a resumed run already has one — `OPEN_EXISTS` on stdout is the expected no-op then, exit 3 is not an error here):

```bash
S=.claude/scripts/script-em-state.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-state.py"
python3 "$S" --init --file "$PRD_DIR/reports/em-state.json" --mode "$MODE" --size "$SIZE" || true
python3 "$S" --set --file "$PRD_DIR/reports/em-state.json" --key roster --value "<approved agent names, comma-separated>" || true
```

On a build dispatch, also record the resolved branch the same way (`--key branch --value "$BRANCH"`) once the resolver returns. All state writes are best-effort (`|| true`) — a failed write is one DOCTOR row, never a changed verdict.

Each mode dispatches its agents to the `eng` skill with the matching flag (`--plan` / `--build`; `fused` dispatches both, in order). The `plan` wave writes each agent's `## Engineering — <Agent>` section **and** its `## Todos — <Agent>` tickets in **one pass** — there is no separate todo wave.

**Subagent context injection (compile/read once, share many).** plan-em already read the full PRD + devkit (Step 1) and compiled per-stack standards payloads (Step 3a). It passes each `eng` subagent only what it needs, so siblings do **not** each re-read the whole PRD, re-read every devkit file, or re-invoke `/cook`. Every dispatch prompt below therefore also includes:
- **Scoped context** — this agent's exec-table rows, the PRD **feature sections** those rows map to, and a **devkit digest** (canonical GLOSSARY terms, ARCHITECTURE constraints, DESIGN-SYSTEM components relevant to the rows — distilled from the Step 1 pre-flight — plus an **AHA slice**: at most 5 `devkit/AHA.md` entries whose tag or content matches this agent's rows/stack, selected from the pre-flight's AHA warnings; never the whole ledger). Plus the **escape hatch**: *"The full PRD is at `<prd-path>`; read it (or a specific devkit file) on demand only if a scoped excerpt is insufficient to resolve a row."*
- **The resolved size tier** *(plan dispatches only)* — `$SIZE` and the `C:` band behind it, from Step 1e, stated as `intake grade C:<band> → write the <medium|large> shape`. The planner tiers its `## Engineering — <Agent>` section on exactly this (`eng/refs/plan/protocol.md` § Which shape) and **must not re-read `INTAKE.md` itself**: one resolution per run, injected, so a sibling planner cannot reach a different answer than the run it belongs to.
- **Standards payload** *(build mode only)* — the compiled `/cook` output for this agent's stack, retained from Step 3a. The build agent uses it and **does not call `/cook` itself**. (`--plan` agents pull no standards → no payload.)

Scope-enforcement and the branch contract in the numbered fields are unchanged — each agent acts only on its assigned rows and commits only to the resolved branch.

**House rules for the engineering plan (both lanes).** Two msg house rules constrain what the plan wave may propose — state them verbatim in the scoped context of every `--plan` dispatch (solo fan-out below, and the orchestrator's input contract in `refs/protocol-team.md`), and apply them yourself when reviewing the returned sections at Step 5:
- **One innovation token per plan, max.** If the plan introduces more than one unfamiliar technology, split it or pick one.
- **Extract on the third occurrence, not the second.** Duplication is cheaper than premature abstraction.

**Plan mode (`$MODE = plan`, and the plan half of `$MODE = fused`).** First, append the `## Todos` umbrella heading **once** (if absent) after the exec-table skeleton — since v5.4 it is the only index to the tickets, so every agent's block must hang off one shared heading. Creating it here (not in the parallel agents) avoids a write race on the shared heading. Then — **`$TEAM_MODE = solo` fan-out** (in `team` mode, skip this direct fan-out and hand the plan wave to the orchestrator per § Team lane) — activate each approved agent as a parallel subagent via the `Agent` tool, each running `eng` in `--plan` mode.

Prompt fields are ordered **stable head first, varying tail last (v5.6.5)** — every field identical across sibling leaves precedes every per-agent field, so Anthropic's prefix-match prompt cache can serve the shared bytes to each leaf after the first. Keep the shared fields **byte-identical** across siblings (verbatim, same order, same whitespace) — a paraphrase is a cache miss:

*Stable head (identical for every leaf in this wave):*
1. "Read `.claude/skills/eng/SKILL.md` fully and follow its protocol."
2. Mode flag: `--plan`
3. `prd-path`: the PRD file path
4. The two **house rules** verbatim
5. Devkit digest (the shared GLOSSARY/ARCHITECTURE/DESIGN-SYSTEM distillate — run-scoped, not row-scoped)

*Varying tail (per-agent):*
6. `agent`: this agent's name from the approved roster — the exact **Agent** column value for these rows (e.g. `backend-eng`)
7. `rows`: the semicolon-separated exec-table Feature identifiers assigned to this agent — each the exact `<ID>: <name> — <concern>` text of a Feature cell
8. **Row-scoped context** (per § Subagent context injection): the mapped PRD feature sections and the row-matched AHA slice — these vary per agent, which is why they live in the tail
9. The PRD-path escape hatch line

(`--plan` pulls no standards → no payload. Leaves parse fields by name, never by position — the ordering serves the cache only.)

Each agent writes its `## Engineering — <Agent>` section **and**, in the same pass, its `## Todos — <Agent>` block (one `### F<n>` per owned feature, under the `## Todos` umbrella — schema in `eng/refs/plan/template-todo.md`) directly to the PRD. Emit a short progress note per completion. When every agent has written both, the plan phase is complete — stamp the PRD's lifecycle field (the § PRD status lifecycle trigger "eng sections written to PRD"):

```bash
S=.claude/scripts/script-prd-stamp.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-stamp.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md" status specced
```

Record the wave boundary in the run state (rides the stamp step — no new step):

```bash
S=.claude/scripts/script-em-state.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-state.py"; python3 "$S" --set --file "$PRD_DIR/reports/em-state.json" --key waves.plan.status --value done || true
```

`specced` is the v5.4 lifecycle value for "execution table + todos written" — the rung that used to be called `eng`. On a PRD written before v5.4 the frontmatter still reads `status: eng`; leave it, every consumer normalises the two to the same rung.

Then, by `$MODE`:
- `plan` (large) — the run **ends** here. Emit the branch suggestion below and go to Step 5; the next `plan-em` invocation detects `$MODE = build`.
- `fused` (medium) — **do not return to the user.** Continue straight into § Fused mode below, which carries the run from the written tickets to the built code without a second invocation.

**Build mode (`$MODE = build`).**

**Eng certification precondition (D18) — `$SIZE = large` only.** The engineering sections exist now (the plan wave wrote them), so on a **large** PRD the eng-side certification is a precondition to the build wave, the same way the product cert (Step 2) gated the plan wave. On a **medium** PRD — whether this is the build half of a fused run or the resume path re-entering at `$MODE = build` — this certification does not run at all; the **mechanical plan-shape check** in § Fused mode stands in its place, and Step 2's single certification is the only one the run pays. Skipping it on a medium PRD is the v5.4 decision, not a shortcut taken here: run the shape check instead, never nothing. This closes the v1 hole where synth merely *recommended* the eng tune — the build wave can no longer start on an uncertified eng plan. Run the certification gate checker (certification stamp + open-Critical scan of the findings ledger — `reviewed:` on a v5.4 PRD, that file's `eng-tuned:` stamp on an older one, two-path resolution):

```bash
S=.claude/scripts/script-cert-status.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-cert-status.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md" --eng
```

- `CERTIFIED` (exit 0) → certified; proceed to branch resolution.
- `UNCERTIFIED …` (exit 1 — `no-stamp` or `open-critical <id>`) → **run `plan-review --eng` inline**: `Skill("plan-review", "$PRD_DIR/prd-[n]-[slug].md --eng")` (the input PRD path from Step 1a; the eng-side check set: 2, 4, 5, 6, 7). It auto-fixes Critical+Major, stamps `reviewed: yes` (`eng-tuned: yes` on a pre-v5.4 PRD), terminates recommend-only. **Re-run the checker** on return; if it still reports `UNCERTIFIED` after it ran, **stop** and surface it — no build agent dispatches on an uncertified eng plan — and log one DOCTOR row (`validator-fail:script-cert-status-eng`) per § Harness incidents (the first `UNCERTIFIED` is expected and never logged). No `AskUserQuestion` here (the certifier's own product-decision pause is the only stop).

Then, resolve and create the feature branch **once**.

**Branch resolution + lane move (run the resolver).** The parent-aware branch choice, the idempotent create-or-checkout ladder, and the `planned/ → wip/` lane move are one deterministic computation — run the resolver (two-path resolution; it is **READ-ONLY** — never mutates git, never moves files), then execute exactly what it emits:

```bash
S=.claude/scripts/script-em-branch-resolve.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-branch-resolve.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md"
```

It emits three `key=value` lines. Set `$BRANCH` from `BRANCH=`, then act on `ACTION=`:

| `ACTION` | Meaning | What to run |
|----------|---------|-------------|
| `create` | branch absent (common for a top-level PRD's first build) | `git checkout -b $BRANCH main && git push -u origin $BRANCH` |
| `checkout` | branch exists, not yet merged (common for a sub-PRD whose parent branch is still in flight) | `git checkout $BRANCH` — do **not** re-create or reset |
| `fresh-cut` | branch exists but already merged to `main` | same as `create` with the emitted `$BRANCH` |

Then run the emitted `LANE_MOVE=` verbatim **unless** it is `none` (it carries `reports/`, `preflight.md`, and `test/` for free — they live inside the folder; the move relocates only the folder).

**Stamp `status: wip` once the branch exists** — the lifecycle trigger is the branch cut, and it is stamped whether or not a lane move was emitted (a sub-PRD cuts no branch of its own and never moves lane, but the work is under way all the same, so the parent's stamp covers it — do not stamp a sub-PRD):

```bash
S=.claude/scripts/script-prd-stamp.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-stamp.sh"; bash "$S" "$PRD_DIR/prd-[n]-[slug].md" status wip
```

The lane and the status answer different questions and are both written here: the lane says the folder now lives in `wip/`, the status says the work reached the `wip` rung. On a PRD written before v5.4 the enum has no `wip` value — leave `status: eng` as it is rather than stamping a value that shape does not define.

Rationale the resolver bakes in (the decision ladder itself now lives in the script): a branch **already merged to `main`** is never reused — committing new work onto a shipped branch would merge it a second time, so the resolver returns a fresh, non-colliding name (a sub-PRD uses its **own** id, e.g. `feat/prd-2.1-streak-freeze`; a top-level whose own name collides with the shipped branch gets the next free `-N` suffix). Branch naming is `feat/<prd-id>` (the PRD folder basename), matching `plan-pm` § Sub-PRD branch inference and the roadmap completion ladder (`feat/prd-<n>-*`). A **sub-PRD** rides the parent's feature branch and never gets its own (so `/pre-merge` sees its changes in the parent's existing run directory) and never moves lane — it already lives inside the parent folder, which relaned when the parent's branch was cut. `LANE_MOVE` is emitted only on a fresh cut (`create`/`fresh-cut`) of a top-level PRD not already under `features/wip/`; a re-checkout is a no-op move.

**Collision pre-check (solo fan-out).** Before fanning out the build agents, pipe the PRD's exec-table section into the collision checker (two-path resolution) — the checker parses the first markdown table it sees, so isolate §6 rather than passing the whole PRD (§3's feature table precedes it). The awk matches **both** heading forms — the reserved `## N. Feature execution table` and the legacy `## Execution Table` of a pre-v5 PRD:

```bash
S=.claude/scripts/script-em-exec-collision.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-exec-collision.py"
awk 'tolower($0) ~ /^## ([0-9]+\. )?(feature execution table|execution table)[[:space:]]*$/{f=1;next} f&&/^## /{exit} f' "$PRD_DIR/prd-[n]-[slug].md" | python3 "$S"
```

The checker reads **both** table shapes — v5.4's 3-column `Feature — concern | Files | Agent` and the legacy 5-column table of an older PRD — so an existing PRD schedules exactly as it always did.

Exit 1 (collisions) → the `COLLISION`-named rows must **not** be dispatched to concurrent agents; keep each colliding pair on one agent (serial). **Exit 3** (`ERROR=no-files-column` on stderr) → the exec table has no `Files` column *at all*, so nothing was checked; both shapes carry Files, so the table is malformed — restore the column from `refs/template-exec-table.md`, re-run the Files derivation, log the DOCTOR row, and never read exit 3 as "no collisions". A `MISSING_FILES` line on any in-scope row is a **hard failure** — stop and **run the Files derivation** (`script-em-exec-skeleton.py --fill-files`, § Execution table skeleton above) before the build wave, and log one DOCTOR row (`validator-fail:script-em-exec-collision`) per § Harness incidents. If the derivation itself then reports `MISSING_TICKETS`, the plan wave — not the table — is what is incomplete. A collision-only exit 1 is a documented outcome and is **not** an incident — serialise and carry on without logging. (In `team` mode the orchestrator runs the same check per `refs/protocol-team.md`.)

Build agents run in parallel and must not each try to create it (concurrent creation from `main` corrupts the tree) — they hard-fail if it is missing. Then — **`$TEAM_MODE = solo` fan-out** (in `team` mode, skip this direct fan-out and hand the build wave to the orchestrator per § Team lane) — activate each approved agent as a parallel subagent, each running `eng` in `--build` mode.

Prompt fields are ordered **stable head first, varying tail last (v5.6.5)** — identical-across-siblings content precedes per-agent content so the prompt cache serves the shared bytes (the standards payload is the largest win) to every leaf after the first. Byte-identical means byte-identical: verbatim, same order, same whitespace. When stacks differ, spawn leaves of the same stack contiguously so they share the payload prefix:

*Stable head (identical for every leaf of this stack in this wave):*
1. "Read `.claude/skills/eng/refs/build/protocol-packet.md` fully and follow it." — the **orchestrated build leaf's fast path**: everything a leaf needs (tickets, TDD loop, full-suite gate, the Step-5 review artifact, commit gates, db-touch pause, output contract) and nothing it is forbidden to do. It assumes exactly what this lane guarantees — branch already checked out, standards payload injected, scoped context injected, gates pre-approved except the db-touch safety floor — so the leaf reads ~11KB instead of `SKILL.md` + `refs/build/protocol.md` (~48KB). A **standalone** `eng --build` run still reads `SKILL.md`.
2. Mode flag: `--build`
3. `prd-path`: the PRD file path (engineering sections already appended)
4. `branch`: `$BRANCH` (resolved/created above — the parent's branch for a sub-PRD)
5. Devkit digest (the shared GLOSSARY/ARCHITECTURE/DESIGN-SYSTEM distillate — run-scoped, not row-scoped)
6. The compiled `/cook` **standards payload** for this agent's stack (retained from Step 3a, cache-served when warm). The build agent uses the injected payload and **does not call `/cook` itself**; cook is invoked at most once per distinct stack per run, and with a warm cache, zero times.

*Varying tail (per-agent):*
7. `agent`: this agent's name from the approved roster — the exact **Agent** column value for these rows (e.g. `backend-eng`)
8. `rows`: the semicolon-separated exec-table Feature identifiers assigned to this agent — each the exact `<ID>: <name> — <concern>` text of a Feature cell
9. **Row-scoped context** (per § Subagent context injection): the mapped PRD feature sections and the row-matched AHA slice — per-agent by construction, so they live in the tail
10. **Review-artifact identity:** `<K>` = this agent's name (the solo lane runs one leaf per stack, so the agent name *is* the packet key) and `built_by` = the same name. The leaf passes both through to its Step 5a reviewer, which writes `<prd-dir>/reports/review-prd-<N>-<K>.json` (`.claude/skills/eng/refs/review/protocol.md` § Artifact). A leaf never invents the key.
11. The PRD-path escape hatch line

(Leaves parse fields by name, never by position — the ordering serves the cache only. Do **not** serialize spawns for cache reasons; parallel spawn stays.)

Emit a short progress note per completion, and record each returned agent in the run state (rides the progress note — no new step): `python3 "$S" --set --file "$PRD_DIR/reports/em-state.json" --key waves.build.agents.<agent> --value done || true` (same `script-em-state.py` two-path resolution as § Run-state init). **On a resumed run** (1a′ chose Resume), dispatch only the agents the state does **not** mark `done` — a returned leaf's work is already on the branch, and leaves are idempotent per their branch/ticket contract, so re-dispatching a done agent is waste, not safety.

**Review coverage before consolidating (solo fan-out).** The solo lane has exactly the exposure the team lane does — one leaf per stack, each of which is required to spawn a reviewer and any of which can skip it silently. So when the build agents return, and **before** Step 5 synthesis, ask the script, not the agents:

```bash
R=.claude/scripts/script-eng-review-check.sh; [ -f "$R" ] || R="$HOME/.claude/scripts/script-eng-review-check.sh"
bash "$R" --reports-dir "$PRD_DIR/reports" --expect "<the dispatched agent names, comma-separated>"
```

Exit 0 → quote its coverage line in the synthesis and record it: `python3 "$S" --set --file "$PRD_DIR/reports/em-state.json" --key waves.build.review_coverage --value "<n>/<n>" || true`. Exit 1 → **repair, don't rebuild**: spawn one `eng --review` over that agent's rows and diff (never the agent that wrote the code), injecting `built_by=<agent>` and `<K>=<agent>`, then re-check once. Still missing → surface the uncovered agents in the synthesis and log one `tool-error:review-<agent>` DOCTOR row per § Harness incidents. Exit 2 or an absent script is a harness fault (`validator-fail:script-eng-review-check`), never coverage. **The synthesis must state coverage** — `reviewed <n>/<n> agents` — and one that cannot state it is a hard failure, not a footnote. Review findings gate nothing: presence is reported, `pre-merge` remains the safety floor.

**Fused mode (`$MODE = fused` — the medium-PRD path).** One invocation carries the PRD from "certified product spec" to "code on a branch". It is **composed of the two halves above, not a third implementation** — every precondition, script and failure arm is the one already written; what changes is that nothing returns to the user in between, and one certification round-trip is replaced by one mechanical check. Run in this order:

1. **Plan half.** Exactly § Plan mode above: `## Todos` umbrella heading, dispatch the `--plan` leaves (solo fan-out, or the orchestrator in team mode), collect their sections and tickets, stamp `status: specced`.
2. **Files derivation.** Run `script-em-exec-skeleton.py --fill-files` per § Execution table skeleton. Its failure arms are unchanged and still hard: `MISSING_TICKETS` means the plan half is incomplete — re-dispatch that agent's plan pass, never hand-fill the cell.
3. **Mechanical plan-shape check — the stand-in for the eng certification.** Once per planning agent, over the PRD the plan half just wrote (two-path resolution):

   ```bash
   S=.claude/scripts/script-eng-plan-shape.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-eng-plan-shape.py"
   python3 "$S" "$PRD_DIR/prd-[n]-[slug].md" --agent "<agent>"
   ```

   **Green (exit 0) → dispatch the build half.** Non-zero → **repair once, then escalate**: the failures it reports (a missing contract heading, a ticket violating the schema, a `### F<n>` block with no exec row, a cyclic `depends-on`, a `(edit)` path that does not exist) are all fixable by the agent that wrote them, so re-dispatch that one agent's plan pass with the reported findings and re-run the check once. Still failing → **stop before the build half** and surface it, and log one DOCTOR row (`validator-fail:script-eng-plan-shape`) per § Harness incidents. A build half must never dispatch on a plan that failed its shape check — that is the whole reason this check is allowed to replace a certification.
4. **Branch resolution + lane move**, then **stamp `status: wip`** — § Branch resolution + lane move above, verbatim, including the sub-PRD carve-out.
5. **Collision decomposition** — the § Collision pre-check (solo) or the orchestrator's `--waves` decomposition (team), unchanged. It works mid-run because `Files` is ticket-derived (v5.4 P4), so the collision graph exists the moment step 2 lands — it never needed a completed prior wave, only completed tickets.
6. **Build half.** Exactly § Build mode's fan-out onward: dispatch the `--build` leaves with the packet doc, the standards payload and the review-artifact identity, then the **review-coverage check** — which is *not* relaxed for a fused run (v5.3's rule holds everywhere: coverage is verified after every wave, a `MISSING` key is repaired by re-spawning a reviewer once, and an uncovered packet is escalated, never accepted).
7. **Step 5**, once, over the whole fused run.

**Status stamps land at their real triggers, not at invocation boundaries:** `backlog → specced` when the plan half's sections and tickets exist (step 1), `→ wip` when the branch is cut (step 4). A fused run therefore writes both stamps in one invocation, in that order — the lifecycle is a property of the work, not of how many times the skill was called.

**If the run dies mid-fusion**, the next `/plan-em` on the same PRD re-runs Steps 1–3 (idempotent by their own resume rules), detects every roster agent present in `engineering_agents`, resolves `$MODE = build`, and completes the build half. No state file, no `--resume` flag.

**Plan-mode branch suggestion (`$MODE = plan` only).** After all plan sections are appended, emit the suggested working branch as `feat/<prd-id>` — the PRD folder basename (e.g. `feat/prd-3-habit-tracking`). A **fused** run does not emit a suggestion: it cut the branch itself at § Fused mode step 4, so it reports the branch it is on rather than one to create. This matches the sub-PRD branch inference and the roadmap completion ladder (`feat/prd-<n>-*`), and is the exact branch the build wave's resolver (`script-em-branch-resolve.sh`) will pick:

```
feat/<prd-id>
```

Engineers should cut this branch from `main` before starting work.

**§ Team lane (`$TEAM_MODE = team` — the default).** Run **all** the mode-specific
preconditions above exactly as written — mode detection; the plan-wave `## Todos` umbrella
heading; the build-wave eng-certification precondition (large only); build-wave branch
resolution, the `planned/ → wip/` lane move, and the create-or-checkout of `$BRANCH`. Then,
**instead of** plan-em fanning out the leaf subagents itself, spawn **one orchestrator
engineer agent** to own the fan-out:

- **Open the dispatcher heartbeat and watch first.** plan-em mints its **own** run id for
  this — `TEAM_RUN_ID=emteam-$(date +%s)` — and the orchestrator keeps its own
  `em-<epoch>` untouched. The two ids are disjoint and that is load-bearing
  (`../../shared/refs/status-heartbeat.md` § *Relaying across a subagent boundary*):
  sharing one would let whichever side ticks first drain the notes bank and reset the
  window, and let either side's `--end` delete the other's state.

  ```bash
  S=.claude/scripts/script-status-tick.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-status-tick.sh"
  W=.claude/scripts/script-agent-watch.sh; [ -f "$W" ] || W="$HOME/.claude/scripts/script-agent-watch.sh"
  TEAM_RUN_ID=emteam-$(date +%s)
  "$S" --start --phase plan-em-team --run-id "$TEAM_RUN_ID" --total 1 --label "team orchestrator — $MODE"
  "$S" --tick  --run-id "$TEAM_RUN_ID" --next "team wave — one orchestrator, <n> leaves"
  ```

- Spawn it via the `Agent` tool with `model: opus`, `run_in_background: true`, and a
  prompt that (a) tells it to *"Read `.claude/skills/plan-em/refs/protocol-team.md` fully
  and follow it"* and (b) injects the input contract that file defines: `$MODE`
  (`plan` / `build` / `fused` from mode detection), `prd-path`, the approved `roster`, the
  `exec_table` rows (with the `Files` column on the build wave), `$BRANCH` **and** the
  compiled per-stack `standards payloads` (build wave only), the devkit digest, the
  resolved `$SIZE` + intake `C:` band, `$TIMING_RUN_ID`, `$STATUS_RELAY` (below), and the
  PRD-path escape hatch. **Never inject `$TEAM_RUN_ID`** — the orchestrator must not see it.
- **Register the orchestrator as one watched leaf**, immediately after the spawn message,
  per `../../shared/refs/agent-watch.md`. `$STATUS_RELAY` is
  `<prd-dir>/reports/heartbeat.log` — plan-em dictates the path, the orchestrator appends
  its rendered `REPORT` blocks there, and the same file doubles as the liveness evidence:

  ```bash
  "$W" --register --run-id "$TEAM_RUN_ID" --leaf orchestrator \
       --evidence "<prd-dir>/reports/heartbeat.log" --evidence "<prd-dir>/reports/*" \
       --label "team orchestrator — $MODE"
  ```

- **Hold the turn and poll.** Wake on the harness's task notification for the backgrounded
  spawn where it delivers one, otherwise a Monitor or until-loop at the resolved interval —
  never a foreground `sleep`. On each wake, read the **newest** `REPORT` block appended to
  `$STATUS_RELAY` and fold it in as plan-em's own `--note`, then `--check` and `--tick`.
  Fold the block's **content** lines only — its `done:` / `now:` / `issues:` / `next:` — and
  drop its `⏱` header line: plan-em renders its own header, and passing the inner one
  through just prints the phase name twice inside a single report.

  ```bash
  "$W" --check --run-id "$TEAM_RUN_ID"
  "$S" --tick  --run-id "$TEAM_RUN_ID" --note "<newest block from $STATUS_RELAY>" --step "team wave — orchestrator running"
  ```

  Quote the tick's output verbatim; a `QUIET` produces no chat output at all. The
  escalation ladder is unchanged — `NOTICE` banks a note, `WARN` adds `--finding low`,
  `STALL` adds `--finding high` plus the one sanctioned visible line naming the
  orchestrator and its idle age. **The watch stays observational**: a stalled orchestrator
  is reported to the human, never killed. An empty or missing `$STATUS_RELAY` is not a
  fault — tick without a `--note` and let the watch speak to liveness.
- **Close both states on every exit path** — clean return, hard failure, spawn error,
  mid-run stop:

  ```bash
  "$W" --done  --run-id "$TEAM_RUN_ID" --leaf orchestrator
  "$S" --end   --run-id "$TEAM_RUN_ID" --outcome "<the consolidated summary's headline>"
  "$W" --close --run-id "$TEAM_RUN_ID"
  ```
- The orchestrator decomposes the wave into file-disjoint, model-tiered packets and fans
  out leaf `eng` subagents (`--plan` planners on Opus; `--build` packets on Opus or Sonnet
  per complexity), respecting the `Files`-disjoint collision rule and committing all build
  work to `$BRANCH`. plan-em does **not** re-run any certification, re-resolve the branch,
  or re-invoke `/cook` — the orchestrator consumes what plan-em already produced.
- **`$MODE = fused` — one orchestrator spawn covers both halves.** A medium PRD hands the
  orchestrator the whole fused wave (`refs/protocol-team.md` § Fused wave): it runs the
  stack planners, then the Files derivation, the plan-shape check, the branch cut and the
  status stamps, then the build packets — without returning to plan-em in between. This is
  the **one** documented exception to *"the orchestrator never resolves the branch"*, and
  it exists because the alternative costs what the fusion was meant to save: plan-em
  cannot interject mid-spawn — backgrounding lets it *watch* the orchestrator, not reach
  into it — so keeping the branch cut on plan-em's side would force a second orchestrator
  spawn for the build half. The invariant that actually
  protects the tree is unchanged — **leaves never touch branches; exactly one agent cuts
  it, once.** plan-em passes no `$BRANCH` for a fused wave and does not pre-move the lane.
- When the orchestrator returns its consolidated summary, proceed to Step 5 with it as the
  wave's output — Step 5 synthesis reads the written engineering sections / build result
  the same way regardless of lane.

The heartbeat now carries the run's progress, so there is no separate spawn/return note to
emit — the `--start` line announces the spawn, the poll-wake ticks carry the orchestrator's
own relayed blocks, and `--end` closes it.

---

**Step 5/5 — Synthesise and next steps**

**Synthesise.** Read the engineering sections + feature coverage via the digest **synth** slice — `python3 .claude/scripts/script-prd-digest.py <prd-path> --slice synth` (frontmatter + `features` + `exec_table` + every agent's `engineering` block + `open_questions` — everything this synthesis summarizes). **Escape hatch:** for a cross-section conflict that needs product prose (a user-flow or design-system detail), read only that section's `prose_lines` range; do **not** default to reading the whole PRD. Produce a synthesis report inline. **Its first element is sized to the wave** — the findings list and branch line below are identical either way:

1. **The summary — one combined, or one per agent, by `$MODE`:**
   - **`fused`** → **one combined summary**, ~5 lines for the whole run: what was planned and built, which stacks took part, the branch, and the review coverage line. **Do not write a paragraph per agent.** A fused run already returned a build summary per packet and a consolidated orchestrator report; a per-agent synthesis paragraph is a third telling of the same events, generated at the most expensive point in the run and read by no one.
   - **`plan` / `build`** (the large two-wave path) → today's shape, unchanged: one paragraph per engineering section on what was written, decided, and left open. A two-wave run has a genuine handover between sittings, and that paragraph is what the human reads before deciding to start the build wave.
2. **Numbered findings list** — every gap/conflict/open question across all sections, each with:
   - Severity: **Critical** (blocks engineering kickoff) / **Major** (requires mid-flight PRD revision) / **Minor** (note for future cycles)
   - Location: PRD section and owning agent
   - Required action: what must happen before engineering work begins

   Critical synth findings are **batched, not a blocking terminal gate** (I5) — collect them into one `AskUserQuestion` (≤4 per call, same pause shape as the certifier's product-decision pause and plan-pm's open-questions pause), apply the resolutions, then continue. A Critical that the certifier should have caught (an uncertified-field contract break) is a signal the eng precondition (Step 4) was skipped — re-run it rather than hand-patching here.
3. **Suggested branch** — emit `feat/<prd-id>`, the PRD folder basename (matching the sub-PRD branch inference and the roadmap completion ladder `feat/prd-<n>-*`, and the branch the build wave's resolver picks). Emit per the branch convention in `.claude/skills/eng/refs/build/protocol.md` § Branch contract:

   ```
   feat/<prd-id>
   ```

   Example: `feat/prd-3-habit-tracking`. Engineers cut this from `main` before starting work.

**Close the run state (v5.6.5).** Before the closing message, stamp the state file terminal so the next invocation starts clean:

```bash
S=.claude/scripts/script-em-state.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-state.py"; python3 "$S" --close --file "$PRD_DIR/reports/em-state.json" --outcome ok || true
```

(`--outcome failed` when the run ends on an unresolved hard failure; a run the user abandons mid-gate simply stays `open` and is what 1a′ recovers. A `plan`-mode run of the two-wave path closes here too — the build wave is a *new* invocation and seeds its own state at § Run-state init.)

**Next steps.** There is **no next-steps menu.** plan-em recommends the next command; it never invokes the next stage itself. The run ends with the closing message per `../../shared/refs/closing-message.md` — the last chat output, after the synthesis above — taking its next step verbatim from the registry's `plan-em` row **for the wave that just finished** — `plan-em — plan wave` when `$MODE = plan` (🟢 `Run /plan-em <prd> again to start the build wave`), `plan-em — fused wave` when `$MODE = fused` and `plan-em — build wave` when `$MODE = build` (both 🟢 `Run /pre-merge now`, because both end with code on a branch). Never compose the step.

The synthesis's batched-Critical `AskUserQuestion` above is untouched: that is a genuine decision point, not a do-next bounce.

Final state: the PRD contains all engineering sections plus a `## Todos` section with a `## Todos — <Agent>` block per agent (written in the same plan pass), the synthesis is visible, no Critical findings are unresolved, and the suggested branch is emitted.

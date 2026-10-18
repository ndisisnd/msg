---
name: executor
description: The preflight-driven pipeline executor (C1/C5) — reads devkit/policy.json components[], prunes by presence + flags, topo-sorts on depends_on into parallel waves, runs each component (the needs_env wave inside the C23 ephemeral test-sandbox, provisioned only-on-green), fails fast by criticality, and aggregates the per-check result reports into the verdict JSON + universal report. The pipeline is resolved per run from the manifest.
type: reference
---

# The pipeline executor

The gate is a **manifest-driven executor**, not a fixed step list. It reads the
`components[]` manifest from `devkit/policy.json` (`../../shared/refs/policy-schema-pre-merge.md` §`components[]`), computes the run
order at runtime, and runs the resolved pipeline.

**The manifest is deltas; the catalog is the constants.** Each entry carries only
`present` / `run` / `run_minified` / `tooling` / `status` plus explicit user
overrides. Everything else — `nn`, `group`, `kind`, `cost`, `depends_on`,
`active_when`, `platforms`, `mandatory`, the default `criticality`, `needs_env` —
is **resolved by `id` against `../../shared/refs/component-catalog.md` at run
time**, never read from the manifest. A catalog edit is therefore live for every
repo on its next run, with no reconcile step. `../../../scripts/script-pipeline-resolve.py`
performs the join; nothing here re-derives component metadata by hand.

The **spine is un-prunable** (Fork B): `SYNC` is the mandatory DAG root — every
component implicitly depends on it, so the tree is synced before anything runs —
and the verdict (pass → "Next: /merge", fail → the fix loop) is the terminal. Neither is a `components[]` entry;
both bracket the resolved pipeline.

## 0 · Load the manifest — first run sets it up

Load + validate `devkit/policy.json` once per run (`policy-schema.md` read-contract
§0/§1 + `policy-schema-pre-merge.md` §2c — merge's sections are never loaded).

| Manifest state | Behavior |
|---|---|
| `components[]` present, non-empty | **run** the resolved pipeline |
| no `devkit/` at all | setup runs by itself: `/msg --init` first (`../../shared/refs/setup-first.md`), then the row below |
| `policy.json` absent, or present with **no** `components[]` | **first-run setup**, in the main conversation: run `protocol-init.md` (batched questions, gaps only), save `devkit/policy.json`, commit the setup outputs as one `chore(pre-merge): setup` commit (`protocol-init.md` step 7), then **continue into the gate in the same run** |
| `policy.json` malformed, or `version` ≠ 1 | stop and name the parse error (resolver exit `8`, §1); setup never overwrites a file it cannot read |

There is no built-in-defaults path: the gate runs the pipeline the manifest declares,
and the first run writes that manifest. Run-vs-skip comes from component **presence**:
an absent component simply isn't in the pipeline. Setup asks the user, so it runs
**before** the gate subagent is spawned (`../../shared/refs/gate-dispatch.md` step 1);
only the user starts `/pre-merge`, so a user is present to answer.

**Manifest staleness nudge — the canonical statement (Fork E, read-only).** With a
valid manifest, recompute `source_signature` cheaply (`policy-schema-pre-merge.md` §`source_signature`) and, on mismatch, print one line —
*"pipeline may be stale — run `/pre-merge --update`"* — then **proceed on the current
manifest**. The gate **never** writes `policy.json` or mutates `components[]`;
only setup and `--update` do (the one gate-run write is the `criticality_review`
stamp, §3c.4). Every other mention of this nudge cites this section rather than
restating it.

## 0a · Resolve the base — once

Resolve the base branch **once**, at the start of the run, and pass it to every step
and script: `staging` when `origin/staging` (or a local `staging`) resolves, else
`main` — the sync rule (`sync.md` precondition 2). SYNC merges it, `script-resolve-diff.sh
<base>` diffs against it, the comment scan and the commit-cap audit range over it, and
the verdict records it. No step or script keeps a default of its own.

## 0b · Find the PRD — from the branch name

pre-merge finds the PRD itself; there is no PRD flag. In the main conversation, before
the spawn:

| Branch | PRD |
|---|---|
| `feat/prd-<N>-<slug>` and exactly one `features/**/prd-<N>-*/` directory matches | that PRD |
| the name does not match, or several PRDs match | ask **once** (`AskUserQuestion`) — the matching PRDs (or the open PRDs), each as one option, plus **No PRD** (skips the PRD checks — the quick-fix case) |

With no user present (a sub-agent run): no PRD matches ⇒ **No PRD**; several match ⇒
stop and report the matches, never guess. The one PRD found feeds every PRD consumer —
the `prd` group (`prd-consistency`, `manual-test-plan`), `regression`, and the review
coverage check (§5a.1) — and is passed to the scripts as their internal `--prd <path>`
argument. One run checks one PRD. **No PRD ⇒ the `prd` group is pruned.**

## 1 · Resolve the pipeline — one script call

Pruning, the C12 coverage-gap correlation (§1b), and the topo-sort into waves (§2)
are **100% decidable** from the manifest + the catalog + this run's flags + the
diff. They are therefore **resolved by script, not by judgment** — a wrong wave
order or a silently dropped component is invisible in the output, which is exactly
the fail-silent class `script-*` exists to close.

```bash
.claude/scripts/script-pipeline-resolve.py \
  --policy devkit/policy.json \
  --catalog .claude/skills/shared/refs/component-catalog.md \
  --platforms-file devkit/PLATFORMS.md \
  [--diff <resolve-diff output>] [--prd <the PRD found at §0b>] [--changed-only] [--flaky <N>]
```

It prints the run's **plan JSON**:

| Key | Holds |
|---|---|
| `waves[]` | the ordered Kahn levels, each component resolved (`criticality`, `cost`, `needs_env`, `run`, `ref`), tie-broken by criticality then cost |
| `run[]` | the flat ordered id list — **the expected-report set** (§5's completeness check) |
| `pruned[]` | every dropped component with its `reason`, verbatim |
| `gap_findings[]` | the §1b coverage-gap findings, already in canonical finding shape |
| `flags` / `counts` | what was passed, what resolved |

**Quote the plan verbatim.** The run report's `## How to verify`, the verdict JSON's
`pipeline` block (§5), and every wave the executor runs come from this output — the
executor never re-orders or re-prunes on its own. Exit `2` is the no-manifest
case (file absent, or no `components[]`) — run setup first (§0), never a refusal; exit `8`
is a `policy.json` that is unparseable or has `version` ≠ 1 — stop and name the parse
error (§0), never setup, because setup never overwrites a file it cannot read; exit `4` is a dependency cycle (refuse, never loop); exit `6` names a
**mandatory component absent from `components[]`** — one `MANDATORY_ABSENT=<id>` line
per gap, no plan. The safety floor is not prunable, so this is a refusal, not a
`pruned[]` row: run `/pre-merge --update` to write the missing row(s), then re-run. Exit `7` means `--platforms-file` exists but could not be read — a
tooling failure, distinct from the file being absent (absent = no targets, no
coverage-gap findings, and the run proceeds).

Write the plan to `.pre-merge/<ts>/plan.json` so §5's completeness check can read it,
with two run facts added at the top level: `base` (§0a) and `last_checked` — the
commit the previous run on this branch checked, read from
`script-premerge-last-check.sh --read --branch <branch>` (`null` when there is no
record). The commit-cap audit reads `last_checked` (`universal/protocol-mechanical.md`).

**Heartbeat starts here** (`../../shared/refs/status-heartbeat.md`). Once the plan
is written, call `--start --phase pre-merge --run-id premerge-<epoch> --total <len(run[])> --label "<resolved pipeline>"` —
`--total` is the plan's `run[]` count, `--label` the resolved pipeline already
quoted verbatim above. `<epoch>` is fixed once, at this call, and every later
`--tick`/`--end` in the run reuses `premerge-<epoch>` verbatim.

### What the script implements (reference — do not re-execute by hand)

1. **Presence.** Include a component iff `present:true` **or** `mandatory:true`.
   `security` + `migration` are always `mandatory` and can never be pruned (Fork D) — with no scanner detected, `security` still runs its
   `/cook` semantic pass; `migration` is `active_when` the diff touches migrations.
2. **`active_when` gate.** Drop a present component whose presence gate isn't met
   this run — the `prd` group needs the **PRD found at §0b** (passed as `--prd`);
   a manifest `active_when` override (written by `--update`) wins over the catalog
   trigger; `ui-surface`/`api-surface`/`migrations`/
   `mobile-surface`/`perf-config` need the matching surface in the diff; `smoke`'s
   union gate needs a UI **or** api/migration/deploy surface.
3. **Flag pruning** (record what each prunes for observability, §5):
   - `--changed-only` — drop a platform component whose surface the diff doesn't
     touch (`../_common.md` surface map). Fail-open: unresolved diff → keep it.
   - `--prd <path>` (internal — the executor passes the §0b PRD) — the `prd` group
     runs when a PRD was found; with no PRD it is pruned (a quick fix skips it).
   - `--flaky <N>` changes retry behavior, not membership.

An **absent** component produces **no** step and **no** "skipped/no_tooling" note
 — that noise lived in the old per-step consult and is gone. (A component
that ran but had nothing to do still writes a `skipped` result report — §4, that
is a *ran-and-skipped* trace, not an absent component.)

## 1b · Platform coverage-gap check (C12 — post-detection)

`script-pipeline-resolve.py` performs this check and emits its findings as the plan's
`gap_findings[]` — the prose below is the **specification** it implements, kept here
because the rule is a contract, not because the executor re-runs it.

After pruning, before ordering, the **coverage-gap check** runs. It turns the
catalog's documented platform gaps into **enforced findings** so a native
app can no longer silently green with zero UI/perf/a11y coverage.

`platforms[]` in the catalog is **applicability** — where a component's concern
*applies* — **not** runner coverage. A web-only *runner* against a broader
applicability is a coverage fact, not a narrowing. The check correlates three inputs
that already exist: catalog `platforms` + the repo's **target platforms** + component
**detection**.

**Target platforms** come from `devkit/PLATFORMS.md` (declared by `/msg --init`) —
the platforms the repo actually ships to (∈ web · iOS · macOS · Android · backend).

For **each target platform** `T`, for **each component** `C` where `T` falls in
`C.platforms` applicability (per the catalog legend — `all` / `UI` = all clients /
`web` / `srv` / `mob` / `DB`):

- **A runner/mode IS detected** for `(C, T)` → covered, no finding.
- **NO runner/mode detected** for `(C, T)` → emit a **`high`** finding (`rule: platform-coverage-gap`, `category: <C's category>`,
  `source: pre-merge:executor`), naming **platform + component + remediation**
: *"`<T>` is a target but `<C>` has no coverage — add a `<T>` runner
  for `<C>`, or drop `<T>` from the repo's targets."*

**Scoping rules (no false gaps):**

- A component whose **concern does not apply** to `T` fires **no** gap: `e2e`
  is `web`-only applicability — native UI-e2e is `mobile`'s domain — so an iOS target
  raises **no** `e2e` gap (it surfaces via `mobile` instead). Applicability is read
  straight from the catalog `platforms` column; the check never invents applicability.
- **No target platform** declared for a component ⇒ **no** gap for it — gaps
  are scoped to declared targets only. A backend-only repo raises no `a11y`/`mobile`
  gaps.
- This is **enforcement of the catalog's documented gaps**: mobile-a11y/perf,
  macOS-native, native UI-e2e (via `mobile`) all become `high` findings **when those
  platforms are targeted**, never silent.

Gap findings join the run's `findings[]` for aggregation (§5). They are `high` (blocking per the rubric), distinct from a *present-but-hollow* safety-floor finding (D28): the gap answers *"is anything covering this?"*; a floor finding answers *"is the
thing that runs actually checking anything?"* — both can fire on one component without
double-counting (absent → gap; hollow → floor). `severity-rubric.md` carries the
`platform-coverage-gap` rule.

## 2 · Order the pipeline (Fork B — runtime topo-sort)

Order is computed every run by `script-pipeline-resolve.py` (§1) — the manifest carries
**no** frozen `order` field. The rules it implements:

1. **Topological sort on `depends_on`** (the only hard edges):
   `coverage → {unit, integration}`,
   `manual-test-plan → {prd-consistency}` (C22), and `regression`'s tail-pin (`depends_on` every other universal/prd component). Everything else is
   independent (the catalog's `sync` marker means "needs the synced branch",
   **not** a dependency edge).
2. **Tie-break** components with no dependency path between them (same wave) by
   `criticality` (critical → blocking → advisory/config-driven) then `cost` (cheap → moderate → expensive). This is a **display/scheduling** order
   within a wave; it never overrides a hard edge.
3. **Reject a cycle.** The DAG is validated acyclic at setup; if a
   loaded manifest is somehow cyclic, refuse rather than loop.

The sort yields **waves** — each wave is the set of components whose dependencies
all completed in an earlier wave (Kahn levels). **C23 splits the schedule on
`needs_env`** (an execution-policy layer like only-on-green, not a `depends_on`
edge): `needs_env:false` components schedule normally; `needs_env:true` components
are deferred into the **env wave**, which runs inside the sandbox after the static
correctness waves are green (§3b). For a universal+prd web-app manifest (C5):

| Wave | Components (tie-break order shown) | Why |
|---|---|---|
| **1** *(static)* | `mechanical` (critical, short-circuits) · `security` (critical) · `unit` · `prd-consistency` *(prd; when a PRD resolves)* · `api` *(spec-diff — its static half)* | `needs_env:false`, need only `sync` — no effect edges among them |
| **2** *(env wave — in the C23 sandbox)* | `integration` · `e2e` · `a11y` · `perf` · `load` · `mobile` · `smoke` (whichever are present) | `needs_env:true` — sandbox provisioned only-on-green after Wave 1 (§3b) |
| **3** | `coverage` · `manual-test-plan` *(prd; when a PRD resolves)* | `coverage depends_on {unit, integration}`; `manual-test-plan depends_on {prd-consistency}` (reuses its grades) |
| **4+** | `regression` | the only-on-green tail — `regression` is tail-pinned (`depends_on` all other universal/prd), and its `needs_env` follows its suite composition |

**The table is illustrative, not normative** — the wave numbers a run actually gets
come from the plan JSON. A component whose dependencies clear early lands early: with
a PRD found, `manual-test-plan` joins the wave right after `prd-consistency` rather than
waiting for `coverage`, because it needs no sandbox and no other input.

**Smoke runs first in the env wave (C21).** `smoke` is cheap and `blocking`, and the
other env-wave components are expensive, so schedule it **first within the env wave**:
if the sandbox app is not alive on its golden paths, its `blocking` failure short-circuits
the rest of the wave (`e2e`, `a11y`, `perf`, `load`, `api`'s live-conformance half,
`migration`'s up→down→up round-trip) rather than burning minutes against a dead app.
Smoke's default-liveness floor means the check can never pass vacuously
(`platform/protocol-smoke.md`, C21).

## 3 · Run the waves + fail-fast

**Nesting — this section is unchanged when the gate runs in a subagent.** Gate runs
are dispatched into a subagent (`../../shared/refs/gate-dispatch.md`), so the
component subagents this section spawns are **nested** one level deeper. That was
verified against the harness at v5.6.1 and it works: a spawned agent can itself call
the `Agent` tool, so parallel waves, backgrounded dispatch and the inner watch all
run exactly as written below, whether the executor is running inline or inside the
gate subagent. Nothing here forks on execution location. The **only** requirement is
run-id disjointness: this section's `premerge-<epoch>` and the dispatcher's
`gate-<epoch>` are separate watch states and neither reads the other's.

Run waves **in order**. For every edge `A depends_on B`, B fully completes before
A starts — true under every flag combination. Within a wave:

- **Independent components run concurrently** as parallel `Agent` subagents,
  **dispatched backgrounded and watched** (`../../shared/refs/agent-watch.md`): the
  wave's subagents go out in one message with `run_in_background: true`, and the
  executor keeps the turn and polls until they return, rather than blocking for the
  length of the wave. `load` and `perf` run **isolated** (not overlapping each other or
  other components) so contention can't skew their numbers (`../_common.md`) —
  isolation is a scheduling rule and the watch does not touch it; an isolated
  component is simply a wave of one, dispatched and polled the same way.
- **Dependent components never run concurrently** — a dependent waits for its
  whole `depends_on` set.

**Heartbeat + watch across the wave** (`../../shared/refs/status-heartbeat.md`,
`../../shared/refs/agent-watch.md` — those own the loop, the thresholds and the
escalation ladder; this section only wires them up). Pre-announce the wave before
dispatching it; when it carries a known-long component (catalog `cost: expensive` —
`e2e`, `perf`, `load`, `regression`'s accumulated run), the `--next` names it and its
expected duration, so the silence is bounded rather than mysterious. Then register
each component as it is spawned:

```bash
W=.claude/scripts/script-agent-watch.sh; [ -f "$W" ] || W="$HOME/.claude/scripts/script-agent-watch.sh"
"$W" --register --run-id premerge-<epoch> --leaf <check id> \
     --evidence ".pre-merge/<ts>/<check>.json" --evidence ".pre-merge/<ts>/<check>.log" --label "<check>"
```

**Tick relay — write every `REPORT` block to the artifact dir.** Each rendered
`REPORT` the executor emits is also appended to `.pre-merge/<ts>/heartbeat.log` as it
is produced. When the gate runs inline this file is a harmless extra artifact; when
the gate runs in a subagent it is the **only** way its progress reaches a human,
because a leaf does not narrate and only the dispatcher's ticks are seen. The
dispatcher folds the newest block into its own `--note` on each poll wake
(`../../shared/refs/gate-dispatch.md` § *Register and watch*). Best-effort: a failed
append never fails, blocks, or re-verdicts the run.

The per-check **result report and its log** (§4) are the evidence globs — every
component writes both on every run, pass, fail or skip, so a component's liveness is
measured against the exact artifact it is producing. `--run-id` is the same
`premerge-<epoch>` fixed at §1; never mint a second one.

On each poll wake, in the contract's order: fold every component that returned since the
last wake in as a `--note` carrying its verdict (§4) and `--done` it in the watch state,
`--check`, then `--tick --step "wave <n> — <k>/<m> checks"`. §4's per-report note is
unchanged in content — it now rides the poll wake that first observes the report rather
than a checkpoint of its own. The wave boundary still ticks
(`--tick --run-id premerge-<epoch> --step "wave <n> done" --done <n components complete>`)
as the natural point where control returns between Kahn levels. A `NOTICE` banks a
note, a `WARN` adds `--finding low`, and a `STALL` adds `--finding high` plus the one
visible line naming the check, its idle age and the human's options. **The watch is
observational**: a stalled check is reported, never stopped, never failed, and never
graded — it produces no result report, no finding of its own beyond the heartbeat's,
and no change to the wave order or the verdict.

**Only-on-green tier.** `regression`'s test-authoring sub-step **and the C23 sandbox
provisioning (§3b)** run only after the correctness
components are green — never author or provision onto a red branch (catalog
"Only-on-green tier"). `regression`'s
*accumulated-suite run* always executes at the tail (it's the final
"doesn't-break-production" gate before /merge); only its *authoring* is gated on
green. `prd-consistency` is Wave 1, judges each acceptance criterion against the
diff's code paths + existing tests, and is **independent of regression** — it
never blocks on regression's fresh authoring.

**Fail-fast by `criticality`.** The rule and its table live in **one place** —
`../severity-rubric.md` § *Fail-fast by component `criticality`*. Read it there; do
not restate it. In one line: a failing `critical` component aborts the rest of the
pipeline, a failing `blocking` component fails the verdict and blocks its dependents
while independent branches finish, and `advisory`/`config-driven` never aborts. The
**critical class is `{mechanical, security, migration}`** — those three, and only
those three, abort a run. **A stalled component is not a failed one** — the watch above
reports idleness and nothing else, so fail-fast, criticality and the abort set read
exactly as they did before it existed.

A component marked `blocked` (its dependency failed) is not run; it writes a
`skipped` result report with `skip_reason: "blocked:<dep>"` (§4).

## 3b · The C23 test-sandbox lifecycle (provision → env wave → promote → teardown)

The `needs_env: true` components (catalog `env` column; manifest `needs_env`) run
inside **exactly one** ephemeral, isolated sandbox per gate run — own DB/state/ports,
concurrent-run safe. A `needs_env: false` component **never** triggers
provisioning and **never** enters the sandbox — the static waves run exactly as before.

**The mechanism is read from `devkit/ENV.md`, never invented and never written.** That
file is the project's committed env-setup contract (`../../shared/refs/env-contract.md`):
human prose around one fenced `env` block carrying the four verbs below. The executor
**reads** it (Fork E — gate runs never write it); setup scaffolds it and `--update`
reconciles it. Resolution, including the placeholder and absent-file cases, is the table
in `env-contract.md` § *Resolution*; every unresolved case lands on the loud degrade at
the bottom of this section. A
composite resolution (`stacks[]` — e.g. simulator + compose backend for a full-stack
mobile repo) is still **one logical sandbox**: every verb below runs across **all**
stacks together — provisioned together, torn down together, never partially.

1. **Provision — only-on-green.** Stand the sandbox up **only after** the
   static correctness waves pass. A run that fails `mechanical`/`unit` (or aborts on a
   `critical`) never provisions — zero env cost on a fail-fast. Run
   `ENV.md`'s `provision`, then its `seed` (migrate-from-zero + the
   committed seed fixture; `scale_factor` dataset for `perf`/`load` when declared).
   Tick once provisioning completes (`--tick --run-id premerge-<epoch> --note "sandbox provisioned"`).
2. **Run the env wave.** All present `needs_env:true` components execute inside the
   sandbox, concurrency rules unchanged (§3 — `load`/`perf` still run isolated), with
   `smoke` scheduled first so a dead app short-circuits the expensive ones (§2). Each
   writes its normal result report (§4); findings aggregate normally (§5). **No second
   environment is ever provisioned** — every env-needing component shares this one.
   Once the wave's results are promoted into the aggregate, tick (`--note "env wave complete"`).
3. **Teardown — always.** Run `ENV.md`'s `teardown` after **every** run,
   pass or fail. Tick once teardown completes (`--note "sandbox torn down"`).

**Fix-loop warm reuse (S-Q2).** Within one fix-loop, the stack stays warm between
iterations: run `ENV.md`'s `reset` (drop → remigrate → re-seed — seconds) instead of
a full re-provision (minutes).

**No provisioner ⇒ loud degrade (D28 pattern).** `devkit/ENV.md` absent, its
`env` block missing/unparseable, a consumed verb still a `[USER: …]` placeholder, or
`provisioner: "none"`:

- **Non-destructive** env-needing checks run against the **ambient** environment,
  each carrying a `high` finding (`rule: sandbox-unprovisioned`,
  `source: pre-merge:executor`): *"cannot run hermetically — no sandbox provisioner;
  declare one in `devkit/ENV.md`, or run `/pre-merge --update` to scaffold it"*. Never a
  silent pass. The finding names the **exact** unresolved line (missing file / missing
  fence / the placeholder verb) so the fix is one edit.
- **Destructive or server-bound** checks — the migration up→down→up round-trip
  (`platform/protocol-migration.md` § *Round-trip*) and the live API check
  (`platform/protocol-api.md` § *Live conformance*) — are **not run**, never run against
  shared state. Each reports *"not run: no sandbox"* in its result report and in the
  run report's `## Test results`. A check that did not run is never listed as run,
  never "passed", never omitted.
- A provisioner **without** a `seed_script` runs the sandbox but flags the same loud
  note for seed-dependent realism (`load`/`perf`/`integration` against an empty DB).

## 3c · Test selection (`policies.test_selection`)

How a **test** component's command is chosen — `run` (full) vs `run_minified` (affected ∪ critical). Selection is an execution-policy layer like only-on-green:
it changes **which tests a component runs**, never which components are in the
pipeline (that is §1's pruning) and never the wave order (§2).

**Resolution + precedence** (`../../shared/refs/policy-schema-pre-merge.md` §2c):

```
ts = policies.test_selection.enabled ?? false // opt-IN — absent means off
selection_on = --full ? false : (--minified ? true : ts)
```

**When `selection_on` is false, this entire section is inert**:
every component runs its `run` command exactly as before the key existed, and
**no** selection artifact is read at all — not `run_minified`, not `tiers`, not
`force_full_paths`, not `critical_markers`, not the `criticality_review` stamp,
not the in-code tags. Nothing is emitted: no `test_selection` verdict block, no
pipeline-line suffix, no critical-tagging pass (§3c.4). `--full` is the per-run kill switch;
`/msg --update` flipping `enabled:false` is the repo-wide one.

The scope is exactly the three **selection-capable** components (catalog legend
`ˢᵉˡ`): `unit`, `integration`, `regression`. Everything else runs whole. In
particular `mechanical`, `security`, and `migration` are **never** selected —
the mandatory floor is untouched (`../../shared/refs/safety-floor.md`: fewer checks never means
weaker ones, and these aren't fewer) — and neither are this PRD's **newly
authored** regression tests (below).

### The rule (5 steps, in order, per test component)

```
1. diff hits force_full_paths → full (note: "force-full: <path>")
2. run_minified == null → full (silent — the runner can't select)
3. affected set unresolvable → full (note: "fallback: <reason>") [fail open]
4. size tier == L → full (note: "tier: L (<trigger>)")
5. else → run_minified per the tier; record selected/total + tier
```

- Rule step 2 is **silent, not a gap** — a runner without selection support is a fact
  about the toolchain, not a finding (same treatment as an absent component).
- Rule step 3 is the **fail-open invariant**, the same rule `--changed-only`
  already uses: no graph, dirty state, runner refused the selector → run the full
  suite with a one-line note. Every resolution failure resolves toward **more**
  testing, never less.
- Rule step 5's selected set is **deterministic**: affected comes from
  runner-native selection or the code graph, the critical floor from declared
  tags. Same diff + same manifest + same tags ⇒ same selected set. The executor
  never asks an agent which tests to run.

### 3c.1 · The size-tier rubric

**Size is measured from the diff's blast radius, never from the PRD's prose.** A
"medium-looking" PRD touching two leaf components is small; a one-line PRD editing
a shared util is large. All three signals are computed **in the prelude**, from
`../scripts/script-resolve-diff.sh` + the code graph — no agent judgment, no per-run LLM call
:

| Signal | Definition | Source | Unavailable ⇒ |
|---|---|---|---|
| `modules` | distinct modules / targets / packages touched | diff paths → module boundaries (SPM/Gradle/package dirs) | — (always derivable from paths) |
| `ratio` | \|affected ∪ critical\| / \|suite\| | the resolved affected set + the declared critical floor | step 3 fires (fail open → full) |
| `fan_in_pct` | highest fan-in **percentile** among touched files | code graph (tokensave `rank`/`hotspots`), cached | **treat as exceeding the small bound** — degrade toward more testing |

Thresholds come from `policies.test_selection.tiers` + `max_affected_ratio` (defaults in `policy-schema-pre-merge.md`); a `force_full_paths` hit is a fourth,
short-circuiting signal (rule step 1) that lands directly in **L**.

**The tier is resolved by script, not by judgment.** Run
the tier script with the two-path pattern —

```bash
T=.claude/scripts/script-tier-resolve.sh; [ -f "$T" ] || T="$HOME/.claude/scripts/script-tier-resolve.sh"
bash "$T" <base> [--affected-ratio <r>] [--fan-in-pct <p>]
```


— it reads the thresholds + `force_full_paths` from `devkit/policy.json`, derives
`modules` from the diff itself, and prints `{tier, signals, trigger}`. Record that
`tier` and those `signals` verbatim (§3c.3); `trigger` is the human-readable
explanation of which bound decided it. The caller supplies `ratio` and `fan_in_pct`
because only the caller can resolve the affected set and the code graph — omit
either and the script degrades toward the larger tier on its own. It is
read-only and never writes `policy.json`.

| Tier | Bounds (defaults) | `unit` | `integration` | `regression` accumulated | `regression` new |
|---|---|---|---|---|---|
| **S** | `modules ≤ 2` **and** `ratio ≤ 0.10` **and** `fan_in < p90` | affected ∪ critical | affected ∪ critical | critical ∪ affected | full |
| **M** | above S, but `modules ≤ 6` **and** `ratio ≤ max_affected_ratio` | affected ∪ critical | **full** | critical ∪ affected **∪ 1-hop dependents** | full |
| **L** | any of: force-full hit · `modules > 6` · `ratio > max_affected_ratio` | full | full | full | full |

**Why M widens exactly there.** As breadth grows the residual risk shifts from
"this unit is wrong" — which unit selection still covers, since affected is
precise at file granularity — to **cross-module interaction**. So M pays for the
full `integration` suite while `unit` stays selected, and the regression net
widens by one dependency hop (tests of modules that directly depend on a touched
module), since accumulated regression tests are exactly the "a distant page broke"
detectors.

**Conflict resolution — the largest tier wins.** The tier is the **largest** tier
any signal lands in; conflicting signals always resolve toward **more** testing. `modules = 1` with `ratio = 0.7` is **L**, not S.

**Critical-only is never a tier.** The critical floor is a *supplement*
to the affected set, never a substitute — a mode that dropped `affected` would
guarantee misses on any untagged-but-relevant test. **Every** tier runs at least
`affected ∪ critical`; no flag, threshold, or degradation path produces a
critical-only run.

### 3c.2 · Per-component contracts

- **`unit` / `integration`** — straight application of the rule + tier table above.
- **`regression`** — two-part contract (this is what protects the D9 ratchet):
  1. **accumulated suite** (`tests/regression/prd-*/`) — selectable: critical-tagged
     ∪ affected, widened one dependency hop at tier **M**.
  2. **this PRD's newly authored tests** — **always run in full; never selected
     away**, at every tier, under every flag.
  The authoring eng subagent **tags at authoring time**: any regression test derived
  from a PRD acceptance criterion the PRD marks P0/critical gets the platform's
  critical marker in the same commit, so new tests are **born tagged**.
- **`coverage`** — not selection-capable, but selection-**aware**: when its `unit`/
  `integration` dependencies ran minified, coverage deltas are computed **only over
  the diff's files** (a suite-wide number from a partial run is meaningless) and its
  result report says so. Both dependencies full → unchanged behaviour.
- **`mechanical` / `security` / `migration`** — untouched; the mandatory floor never
  narrows.

### 3c.3 · Recording — a minified run is never mistaken for a full one

The chosen tier **and** the triggering signal values are recorded in three places, so a miss is attributable to a threshold — and the threshold is
tunable in policy rather than re-litigated per run:

| Surface | Form |
|---|---|
| **pipeline line** (§5 `pipeline`) | `unit: minified (42/731, tier S)` — a full-run component keeps its existing bare form |
| **run report `## Test results`** (§6) | `selected/total` per check, plus the tier and any `fallback_reason` |
| **verdict JSON** | the additive `test_selection` block — `{mode, tier, signals: {modules, ratio, fan_in_pct}, per_check: {<id>: {selected, total, fallback_reason?}}}` (`../refs/output-schema.md`; additive, shape unchanged) |

`pass` semantics are otherwise **unchanged**: selection changes how many tests ran,
never how a finding is graded (`../severity-rubric.md` is untouched by this
section). A run that fell back to full at steps 1–4 records the reason in the same
places, so "why did this take 40 minutes" is answerable from the artifacts.

### 3c.4 · Critical-test tagging — before selection, automatic

When `selection_on` is true, **before** the rule above picks any test, run the
critical-test tagging pass (`protocol-criticality.md`): find untagged tests, tag the
ones that must always run (with cited evidence), commit the tags on the branch as one
`test(criticality): …` commit, restamp `criticality_review`, and list the tags in the
run report. No question — a wrong "critical" tag only makes a test run more often.
No critical-marker vocabulary from setup ⇒ skip the pass and say so in the report.
This and the sync-merge commit are the gate's only file writes. Selection off ⇒ the
pass is skipped.

## 4 · Result reports (one per component, every run)

**Every** component that runs — pass, fail, or skip — writes a normalized
**result report** to `.pre-merge/<ts>/<check>.json` on **every** run, never
failure-only. `<ts>` is the run timestamp; the dir is a gitignored
runtime artifact. This is the `result` section of the one check-report schema (`../../shared/refs/check-report-schema.md`):

```json
{ "check": "unit", "group": "universal",
  "verdict": "pass|pass_with_warnings|fail|skipped",
  "runner": "vitest", "ran_at": "<ISO-8601>",
  "totals": { "passed": 24, "failed": 0, "skipped": 0, "flaky": 0 },
  "findings": [ /* canonical findings, source = "<check>", or [] */ ],
  "log_path": ".pre-merge/<ts>/unit.log",
  "skip_reason": null }
```

- Keep it **lean** — `findings[]` carries only the canonical finding shape (`../../shared/refs/finding-schema.md`); a clean pass writes `findings: []` and a
  positive `totals` (you can tell "ran + passed 24" from "skipped"). No
  prose, no duplicated finding bodies.
- `unit` emits the **same** shape as every other check — no exceptions.
- A **skipped** check still writes a report with `verdict: "skipped"` +
  `skip_reason` — e.g. `"no_tooling"`, `"env_unreachable"`,
  `"blocked:unit"`, `"surface_absent"`.
- **An errored check that covers changed surface carries a finding.** When a
  component errors out (crash / unreachable / auth — `../_common.md` § *Component-level
  error rule*) **and** the diff touches the surface it covers, its report carries one
  `medium` finding, `rule: component-errored`, alongside the `pass_with_warnings`
  verdict. An error on untouched surface stays a note. This is the difference between
  "the environment hiccuped on something we didn't change" and "nothing has verified
  the thing we are shipping".
- Mandatory-component reports are always written even when they degrade (`security` with no scanner → its `/cook` pass result).
- **Heartbeat note per report.** Each report is worth one
  `--note "<check> <verdict>"` on the heartbeat, with
  `--done <n components complete>`; when the report's `findings[]` graded this check
  `blocker` or `high`, add `--finding <severity>` once per such finding. The report
  write is already one-per-component, so it is the note's natural site and no step is
  added to create it — the tick that carries it is the §3 poll wake that first sees the
  report land (or, for a component the executor ran in the foreground, the write itself).

These per-check result reports are the executor's **single uniform aggregation
input** — the verdict and the universal report are both *derived* from them, never
authored separately.

## 5 · Aggregate → verdict JSON + universal report (C7)

### 5a · Completeness check — every planned component reported

Before aggregating, verify the run is whole. "Every component writes a report" was
an unenforced convention: a component that died mid-flight simply vanished from the
aggregate, producing a **smaller, quieter, greener** verdict than the run deserved.

```bash
.claude/scripts/script-pipeline-resolve.py --check-complete \
  --plan .pre-merge/<ts>/plan.json --run-dir .pre-merge/<ts>/
```

Exit `5` with `MISSING=<id>` lines means a planned component never wrote its result
report. That is a **`high` finding** (`rule: missing-result-report`,
`source: pre-merge:executor`) naming each component — *"`<id>` was in the plan but
wrote no result report; its outcome is unknown"* — never a silently smaller
aggregate. `EXTRA=<id>` (a report with no planned component) is one `low` note.

### 5a.1 · Review coverage (the backstop — reports, never blocks)

The gate is the last place an unreviewed branch can still reach a human quietly. So when the run has a resolved PRD path (the same one §5b passes as `--prd`), ask the script how much of what was built was also reviewed:

```bash
R=.claude/scripts/script-eng-review-check.sh; [ -f "$R" ] || R="$HOME/.claude/scripts/script-eng-review-check.sh"
bash "$R" --reports-dir "<prd-dir>/reports" --expect-from-builds
```

The gate did not run the wave and holds no packet list, so `--expect-from-builds` derives the expectation from the build run reports already in the folder — for every `report-prd-<N>-<K>` there should be a `review-prd-<N>-<K>`.

| Exit | Meaning | What the gate records |
|---|---|---|
| 0 | every built packet reviewed | the coverage line in the universal report; no finding |
| 1 | one or more `MISSING`/`SELF-REVIEWED` keys | **one `medium` finding**, `rule: review-coverage`, `source: pre-merge:executor`, naming each uncovered key — *"`<k>` was built on this branch but has no review artifact; whether it was reviewed is unknown"* |
| 3 | no build reports, so no expectation derivable | one `low` note — an unknown reported as unknown |
| 2 / script absent | harness fault | one `low` note plus a `validator-fail:script-eng-review-check` DOCTOR row; never recorded as coverage |

**`medium` is deliberate and so is non-blocking.** Missing review coverage never produces `fail` — a merge is gated by pre-merge's own green run, never by review (`../../eng/refs/review/protocol.md`). `medium` was chosen over `low` because it survives a skim of the report, which `low` does not; its only verdict effect is the ordinary `medium` → `pass_with_warnings` one, and a run that was already failing is unaffected. The value here is not enforcement — it is that an unreviewed branch can no longer reach a human silently.

The finding is authored here, exactly like §5a's `missing-result-report` finding, and flows into §5b's aggregation with the rest.

### 5b · Aggregate

The mechanical half runs as one script:

```bash
.claude/scripts/script-aggregate-verdict.sh --run-dir .pre-merge/<ts>/ \
  --plan .pre-merge/<ts>/plan.json --diff <resolve-diff output> [--prd <path>]
```

It owns everything decidable — collect (the result reports' `findings[]` **plus the
plan's already-resolved `gap_findings[]`**, so §1b's coverage gaps are never
re-derived), dedup by `(category, file, line, rule)`
keeping the highest severity and comma-joining the distinct `source` values (the
wire contract `/msg --gui` splits on — `../../shared/refs/finding-schema.md`), the two **path-pattern**
downgrades from `../severity-rubric.md` (§2 dev-only scope, §4 out-of-diff, with the
secret-scanner / build-failure / repo-level exemptions), the verdict derivation, the
per-severity summary, the `checks[]` roll-up, `skipped[]`, and the critical-abort
signal (`aborted` / `aborted_by`). It refuses malformed input rather than quietly
dropping a component. No `--diff` ⇒ the out-of-diff downgrade is skipped: a finding
is never weakened on a guess.

**Judgment stays with the model; the verdict stays with the script.** The model judges:

- **reachability** (`../severity-rubric.md` §3 — dead code, compile-time-false flags),
- **profile coverage floors** and any in-context re-grading,
- **regression marking** from `--prior-issues` on `(category, file, rule)` — this is
  what turns a repeated `component-errored` finding into a visible standing breakage
  rather than a fresh surprise each run.

Write those judgments to `.pre-merge/<ts>/regrades.json` — a JSON array, one entry per
judged finding: `{category, file, line, rule, severity?, regression?, reason}` (the
four key fields copied from the script's `issues[]`). Then run the script once more
with `--regrades .pre-merge/<ts>/regrades.json`. It applies the re-grades and the
regression marks and computes the **one** final verdict, the counts and `issues[]`.
**The model never computes a verdict by hand**, so the verdict, the counts and the
issues file cannot disagree. No judgments ⇒ the first run's output is final. An entry
that matches no issue comes back in `regrades_unmatched`; fix the key and re-run.
Verdict rule (the script's): `fail` (any **blocking** finding — blocker/high, except a
prd-consistency finding other than `acceptance-unmet`) · `pass_with_warnings` (any
other finding) · `pass` (zero) · `refused`/`skipped` (early-termination paths).

**Verdict JSON (stdout — the final emission, `../refs/output-schema.md`).** Two
optional fields ride along: `pipeline` — the resolved ordered wave list + what each
flag pruned — and, **only when test selection ran** (§3c), `test_selection`.

**Universal report (`report-prd-<N>-<K>.json` — the eng-ingestible issues file).**
Written on a non-clean verdict into the run report's paired `.json` (`../../shared/refs/report-schema.md` path rules). It **extends** the existing
issues-file shape (`issues[]` + `context` + `summary` + `followUp`) with a
`checks[]` block:

```json
{ "run_id": "...", "gate": "pre-merge", "verdict": "fail",
  "context": { "base": "...", "branch": "...", "prd": "...",
               "files_changed": [ ], "diff_stat": { } },
  "summary": { "blocker": 0, "high": 1, "medium": 2, "low": 0 },
  "checks": [ /* each result report's {check, group, verdict, totals, runner, log_path} */ ],
  "issues": [ /* flattened + deduped canonical findings — the FIX LIST */ ],
  "followUp": { "status": "open",
                "suggested_command": "eng --build report=<this path>" } }
```

- `checks[]` = the full run picture (what ran, pass/fail/skip, totals) — sourced
  directly from the per-check result reports.
- `issues[]` = the flattened + deduped `(category,file,line,rule)` fix list; each
  finding keeps `source` = producing check and is eng-fixable (`file`, `line`, `rule`, `severity`, `message`, `repro`, `suggestion`).
- **`followUp.status` is camelCase — preserve it verbatim**: `eng --build`
  writes it back, `/msg --gui` reads it. Never rename to `follow_up`/`status`
  casing.
- The verdict JSON and the universal report share the **canonical finding shape** —
  neither invents fields the other lacks.
- **On a minified run the universal report also carries the `test_selection` block**
  — the same object emitted in the verdict JSON (§3c.3), copied verbatim at the top
  level beside `checks[]`, and omitted entirely on a full or selection-off run. The verdict JSON is stdout and doesn't survive the run, so this
  committed copy is the **durable** record merge reads to attribute a backstop
  failure to a selected-away test (`../../merge/refs/staging.md` § *Test-selection-miss detection*; shape contract in `../../shared/refs/report-schema.md`).

## 6 · Terminal + run report

- **Terminal issue summary** on **every** report write, all verdicts, per
  `../../shared/refs/report-schema.md`. A clean run prints exactly
  `Issue summary — 0 issues`.
- **Run report `## Test results`** has one line per check for pass **AND** fail,
  derived from `checks[]`; `tests_passed`/`tests_failed` frontmatter is summed from
  the result reports' `totals`. `## How to verify` lists the resolved,
  ordered pipeline + what was pruned. On a minified run each
  selection-capable check's line also carries `selected/total`, the tier, and any
  `fallback_reason` (§3c.3); on a full or selection-off run the lines are
  unchanged.
- **Write the verdict to `.pre-merge/<ts>/verdict.json`** — the same JSON §5b emits to
  stdout, byte-for-byte, written to disk before it is printed. On **every** verdict
  including `refused` and `skipped`. This file is the dispatcher's transport: a gate
  run in a subagent has no stdout the main thread can trust, so the dispatcher `cat`s
  this file and re-emits it verbatim rather than paraphrasing the subagent's return
  text (`../../shared/refs/gate-dispatch.md` § *Relay, don't rewrite*). Unlike the run
  report this write is **not** best-effort — a missing `verdict.json` means the run
  failed its emission contract and the dispatcher reports it as such.
- **Heartbeat and watch end here.** After the terminal issue summary and run report are
  written, call `--end --run-id premerge-<epoch> --outcome "<verdict>"` on the tick
  script and `--close --run-id premerge-<epoch>` on the watch script — before the verdict
  JSON is emitted. **Both close on every exit path after §1's `--start`**, not just a
  completed run: a critical abort (§3), an unresolvable env degrade, a refusal reached
  mid-run. The verdict JSON (§5b) remains stdout's final machine emission,
  byte-identical whatever the heartbeat printed.
- **Record the last check — the commit and the verdict together.** On every run that
  reached a `pass`, `pass_with_warnings` or `fail` verdict, write the checked commit
  (`git rev-parse HEAD` after the sync and any regression or tag commits — the verdict
  JSON's `head`) and the verdict in one record:

  ```bash
  L=.claude/scripts/script-premerge-last-check.sh; [ -f "$L" ] || L="$HOME/.claude/scripts/script-premerge-last-check.sh"
  bash "$L" --write --branch <branch> --head <head> --verdict <verdict> \
       --report <run report path> --run-dir .pre-merge/<ts>/
  ```

  `.pre-merge/last-check.json` is the one durable store: the next run's commit-cap
  audit starts from its `head`, and `merge` reads it to check that pre-merge passed on
  the current branch tip — the commit or the verdict missing means no pass.

## 7 · Terminals + emission order

**Pass — `pass` / `pass_with_warnings`.** The run ends with the verdict, the report
path and **"Next: /merge"** as the closing message's last line. pre-merge **never
pushes and never opens a PR**: `/merge` checks the stored pass (§6), pushes the
branch, opens the PR and waits for CI. The branch stays local.

**Fix loop — `fail`.** No PR, no push. Write the **issues file** — the run report's
paired `.json` (same stem, folder, N and K), the **universal report** (C7) per §5b —
and end the gate run. The gate subagent does **not** plan or build fixes. The **main
conversation** runs the automatic fix rounds in `../../shared/refs/fix-loop.md`
§ *pre-merge — automatic, up to 2 rounds* (plan → build → gate again, no question,
up to 2 rounds, with its stop rules); do **not** re-spell that wording here. A round
that passes ends with "Next: /merge"; a loop that stops hands to the user with the
reason and the next command.

**Every run ends with, in order:** (1) the run report — best-effort, skipped on
`refused`/`skipped`; (2) the terminal `Issue summary` block — every verdict; (3) the
verdict JSON, stdout's final **machine** emission, also written to
`.pre-merge/<ts>/verdict.json` (§6); (4) the **closing message** per
`../../shared/refs/closing-message.md` as the last **chat** output — every verdict,
including `refused` / `skipped`.

## Contract stability (load-bearing)

`eng --build report=`, `../../shared/refs/fix-loop.md`, and `/msg --gui` read the
verdict JSON's top-level keys and the issues file's `issues[]` shape. Do not rename
or drop either; `pipeline`, `test_selection`, and `checks[]` are optional extras that
consumers may ignore.

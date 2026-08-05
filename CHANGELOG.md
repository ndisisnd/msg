# Changelog

## 2026-08-05

### [157] — README header: v5.6.5 release blurb, in GitHub alert syntax

- `README.md`: Changed — the header's `mkpub:release` card now uses GitHub's native `> [!NOTE]` alert syntax instead of a hand-styled `<div>`, so it renders as a tinted block on github.com itself rather than only in editor previews. Content updated to announce v5.6.5 (resumable orchestration runs via the run-state checkpoint, the persisted standards cache, and cache-aligned leaf dispatch), with the same install command as the update CTA.

### [156] — Release v5.6.5

- `RELEASES.md`: Added — v5.6.5 notes covering [155] (resumable orchestration runs via the run-state checkpoint, the persistent standards-payload cache, and cache-aligned leaf dispatch), with [154] folded into a documentation touch-up line.
- `package.json`: Unchanged — the version was already bumped to `5.6.5` alongside the feature in [155].

### [155] — v5.6.5: the memory-layer patch — resumable runs, persisted standards, cache-aligned dispatch

- `.claude/scripts/script-em-state.py`: Added — plan-em run-state checkpoint file (`<prd-dir>/reports/em-state.json`): atomic `--init`/`--set`/`--get`/`--close`/`--archive`, written at wave boundaries only; an open state lets a fresh session resume an interrupted run (skip completed waves and already-returned build agents) instead of restarting. Missing or corrupt state is never a hard failure; the file is resumability only — heartbeat and agent-watch keep observability, and mode selection stays PRD-evidence-driven with the state file never overriding it.
- `.claude/scripts/script-standards-cache.py`: Added — persistent cache for compiled `/cook` standards payloads under `.claude/msg/cache/` (`standards-<key>.payload.md` + meta), keyed by the canonical flag set with a source hash over cook's SKILL.md, refs, and every flagged domain's `standards/` tree; `--check` prints `HIT <path>`/`MISS <key>`, `--store` writes atomically. Any doubt is a MISS; a standards edit invalidates automatically.
- `.claude/skills/plan-em/refs/protocol-em.md`: Changed — Step 1a′ run-state resume check (Resume / Start fresh / Abort; Resume pre-approved under an autonomy contract); Step 3 resume bullet and Step 3a now consult the standards cache before every `/cook` call and store on a miss (the payloads are no longer per-run); Step 4 seeds the run state after mode detection and records the plan-wave boundary, each returned build agent, and review coverage; both fan-out prompt-field lists reordered **stable head first, varying tail last** (shared: protocol pointer, mode, prd-path, branch, house rules, devkit digest, standards payload; per-agent: agent, rows, feature sections + AHA slice, review identity, escape hatch) so Anthropic's prefix-match prompt cache serves the shared bytes to every sibling leaf after the first — leaves parse fields by name, so the order serves the cache only; Step 5 closes the state file before the closing message.
- `.claude/skills/plan-em/refs/protocol-team.md`: Changed — the leaf-dispatch input contract carries the same stable-head/varying-tail ordering rule (byte-identical shared fields, same-stack leaves spawned contiguously, spawning stays parallel).
- `.claude/skills/eng/SKILL.md`: Changed — Step 4's standalone lane consults the same standards cache before calling `/cook` and stores on a miss, so the standalone and orchestrated paths fill and read one cache.
- `.claude/skills/shared/refs/session-cache.md`: Changed — standards payloads added to § Consumers, with the sanctioned exception to rule 5 recorded (script-based freshness check; regeneration is a `/cook` invocation).
- `ARCHITECTURE.md`: Changed — the two new scripts added to the engineering scripts table.
- `evals/cases/`: Added — `em-state-lifecycle`, `em-state-open-exists`, `em-state-corrupt`, `standards-cache-roundtrip`, `standards-cache-stale` (suite: 125/125).
- `package.json`: Changed — version `5.6.4` → `5.6.5`.

### [154] — README header: v5.6.4 release blurb, and two stale counts

- `README.md`: Added — `mkpub:release` card in the header announcing `/emulate`, with the recommended installer as the update CTA (the same command `## How to update` gives, because re-running it upgrades an existing install rather than erroring). Changed — skills badge `8` → `9`, and "installs as eight slash commands" → "nine" in § *What it does*; the same claim further down the page was corrected in [152], and this second occurrence was missed.

### [153] — Release v5.6.4

- `RELEASES.md`: Added — v5.6.4 notes covering [152] (`/emulate` runs the app on a local simulator or emulator from the current branch, clearing the previous attempt's stale build processes first; optional `emulate_cmd` column; `/msg --update` offers both new settings to repos bootstrapped earlier).
- `package.json`: Unchanged — the version was already bumped to `5.6.4` alongside the feature in [152].

### [152] — `/emulate`: the local run lane — boot a simulator on this branch and open the window

- `.claude/skills/emulate/SKILL.md`: Added — new skill, and the first leaf outside the planning→build→gate→ship spine: it launches, it never ships. Router with the dispatch table (`--ios` / `--adr` / `--expo` / `--device` / `--dry-run`), the "two axes, not one" statement (`--ios`/`--adr` pin the **platform**, a product fact read from `devkit/PLATFORMS.md`; `--expo` pins the **runner**, a repo fact), and the two contracts the lane is built on: fail loudly where the answer is knowable and wrong to guess, ask only where the answer is genuinely the user's.
- `.claude/skills/emulate/refs/protocol.md`: Added — Steps 0–6 (parse invocation → resolve target → ask once → branch check → sweep → launch → report). The branch is **reported, never gated**: running the branch you are standing on is the point of the lane, so a banner naming branch, sha and dirty state replaces any block. Exactly one ask can be pending per run — an unresolved platform stops the preflight before devices are enumerated, because the device list is platform-specific — so the platform ask comes first on its own and the device ask lands on the re-run.
- `.claude/skills/emulate/refs/runners.md`: Added — the launch recipes (Expo iOS/Android, native iOS, native Android) with a named ready-signal each, the cold-boot rules, and the log path `.emulate/<platform>-<epoch>.log`. Three rules hold across all of them: background anything long-lived, wait on a signal and never on the clock, and raise the window (booting a simulator without `open -a Simulator` leaves it headless).
- `.claude/scripts/script-emulate-preflight.sh`: Added — the read-only resolver. Settles platform, runner, launch command, device and branch state in one call and prints `KEY=VALUE`; mutates nothing, signals nothing. Loud exits are coded so the cause is legible without reading prose: 2 = no emulatable platform or a bad flag, 3 = `PLATFORMS.md` missing or unparseable, 4 = toolchain absent, 5 = device problem. Every one prints `ERROR=<cause>` on stdout and a fix on stderr. Toolchains are looked up on `PATH` rather than behind a bypass env var, so tests inject stubs without drifting from real behaviour. Device defaults rank booted → toolchain-declared → newest, because an already-running device is both the likeliest intent and the fastest launch.
- `.claude/scripts/script-emulate-sweep.sh`: Added — the one destructive step, bounded three ways: an **allowlist** of build-tool shapes compiled in (never a user-supplied pattern, never a broad `killall`), **scope** limited to processes attributable to this repo (cwd or command line inside it, or holding the dev-server port about to be bound), and **announcement** of every candidate with pid and reason. TERM first, KILL only after a bounded grace. `--dry-run` prints the identical list and signals nothing. Never fails the run — a stubborn daemon is reported, not fatal.
- `.claude/scripts/script-platforms-parse.py`: Added — `emulate_cmd` column support, matched by header name like every other column, with `[USER: …]` / `—` / blank all collapsing to empty. A pre-v5.6.4 `PLATFORMS.md` with no such column parses clean and yields empty, which is what makes the column purely additive.
- `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md`: Added — the `emulate_cmd` column, ios/android only, with the contract stated in the column notes: a declared command wins over detection, and `$EMULATE_DEVICE_ID` / `$EMULATE_DEVICE_NAME` are exported for it to use.
- `.claude/skills/msg/refs/init/templates/template-gitignore.md`: Added — `.emulate/` to the universal msg-artifacts block. `/emulate`'s launch logs are machine-local build noise, and `/emulate` is barred from editing `.gitignore` itself, so the ignore line has to come from `--init`.
- `.claude/skills/msg/refs/init/init-setup.sh`: Added — two row-gap checks, `devkit/PLATFORMS.md:emulate_cmd` and `.gitignore:emulate`, so a repo bootstrapped before v5.6.4 is offered both by `/msg --update` instead of silently missing them.
- `.claude/skills/msg/refs/protocol-init.md`: Added — the matching Step 3b top-up rows (fixed content, no variable, no question — a blank `emulate_cmd` cell means `/emulate` detects the runner itself), plus the one narrow exception to the never-touch-an-existing-line rule that a *column* top-up requires: every existing cell keeps its content and its column, and the changed lines are shown in the preview like any other edit.
- `.claude/skills/msg/SKILL.md`: Added — `emulate` row in the canonical skills menu and a `--help` routing row (Reviewing + code/diff + working code).
- `.claude/skills/shared/refs/safety-floor.md`: Added — `/emulate`'s write powers, which are **nothing in the repo**: no commit, branch, PR, stamp or report, only its own launch logs under `.emulate/`. Added — the statement that killing a process is a write power too, and the three bounds that hold it.
- `.claude/skills/shared/refs/closing-message.md`: Added — `/emulate` row in the next-steps registry.
- `README.md` / `QUICKSTART.md` / `ARCHITECTURE.md` / `llms.txt`: Added — the skill, the two scripts, the `PLATFORMS.md` column, and the placement of `/emulate` as a leaf reachable from anywhere rather than a pipeline stage.
- `evals/cases/`: Added — 20 cases covering platform resolution (single / ambiguous / none / no file / flag-beats-file / unknown flag), toolchain absence, device selection (named, unknown, none, ask, single) and the three default rankings, `emulate_cmd` override vs placeholder, the parser's new column on both new and legacy files, and the sweep's scope and dry-run guarantees. The scope case starts two identically-shaped decoy processes — one inside the repo, one outside — and asserts only the in-repo one is a candidate. Changed — `a24-platforms-multiple-tables` golden gains the new `macos.emulate_cmd=` line.
- `package.json`: Changed — version bumped to `5.6.4`.

## 2026-08-03

### [151] — Release v5.6.3

- `RELEASES.md`: Added — v5.6.3 notes covering [150] (`/msg --version` reports the installed release, install-time version stamp).
- `package.json`: Changed — version bumped to `5.6.3`, which is what the installer stamps from here on.

### [150] — `/msg --version`: an installed copy can now name its own release

- `package.json`: Added — new file, and the single version field for the repo. No JS build exists here; it is present so `/kermit --release` (which bumps `package.json` when it finds one) advances the version as part of the release itself, leaving no manual step that could drift from the tag.
- `install.sh`: Added — reads the version out of the clone's `package.json` with `sed` (not `node` — the installer must not require a JS toolchain for one field), captures the short commit, and writes a one-line stamp to `~/.claude/skills/msg/VERSION`. Written *after* the skill copy, since copying `msg/` deletes the destination directory first. The version read is guarded with `|| true`: under `set -euo pipefail` a clone predating `package.json` would otherwise abort the whole install over a cosmetic stamp, and such a clone is labelled `msg (unversioned)` rather than `vunknown`. Changed — the clone line, the success line, and the next-steps list now name the version and point at `/msg --version`.
- `.claude/skills/msg/SKILL.md`: Added — `--version` dispatch row (plus the bare word `version` and the natural-language "did the reinstall land" phrasings), and the **Protocol: --version** section: one `cat` of the global stamp, emit the line verbatim, stop. Reads the global path even when a project ships its own `.claude/skills/msg/`, because the installed copy is what other repos load. Explicitly forbids inferring a version from a tag, changelog, or the repo's own `package.json` — those describe the source, not the install. An absent stamp is itself an answer (the copy predates v5.6.3) and returns the reinstall command. Changed — frontmatter description and `argument-hint`; `--version` joins the pure-emission modes exempt from the closing message.
- `README.md`: Added — `/msg --version` row in the mode table, and a `VERSION` check in the post-install verification block with the reason it matters (skills live in `~/.claude`, so a half-failed reinstall leaves every project looking unchanged).
- `ARCHITECTURE.md`: Added — install-layer paragraph covering the stamp, why `package.json` exists, and the write-after-copy ordering.

### [149] — Release v5.6.2

- `RELEASES.md`: Added — v5.6.2 notes covering [148] (`plan-em --team` orchestrator spawn goes backgrounded, progress relays through a file rather than a shared heartbeat run-id).

### [148] — `plan-em --team`: orchestrator spawn goes backgrounded, progress relays through a file

- `.claude/skills/shared/refs/status-heartbeat.md`: Added — § *Relaying across a subagent boundary*, the single statement of the two rules any nested-orchestrator dispatch obeys: run-ids stay disjoint, and the relay is a file in the run's artifact directory. Spells out why sharing a heartbeat run-id destroys progress rather than relaying it — a reporting `--tick` drains the notes bank and resets the report window, so whichever side ticks first takes everything, and `--end` deletes the state file outright.
- `.claude/skills/plan-em/refs/protocol-em.md`: Changed — § *Team lane* spawns the orchestrator with `run_in_background: true` (was `false`, which held the session's turn for the whole wave and made the ~5-minute heartbeat unreachable). Added — plan-em mints its own `emteam-<epoch>` for a dispatcher heartbeat and a single-leaf watch, registers the orchestrator against `<prd-dir>/reports/heartbeat.log`, polls on cadence folding the newest relayed `REPORT` block in as a `--note`, and closes both states on every exit path. The fused-mode rationale no longer rests on plan-em being blocked; the spawn/return progress note is retired in favour of the heartbeat.
- `.claude/skills/plan-em/refs/protocol-team.md`: Changed — input-contract preamble documents the backgrounded spawn. Added — `$STATUS_RELAY` contract row and the § *Wave dispatch* tick-relay paragraph: append every rendered `REPORT` block to the path plan-em injected, which is also the evidence glob its watch measures liveness against. The orchestrator's own `RUN_ID=em-<epoch>` mints are deliberately untouched.
- `.claude/skills/shared/refs/gate-dispatch.md`: Changed — § *Register and watch* points at the new heartbeat section as the canonical statement of both rules instead of implying they are gate-specific.
- `.claude/skills/plan-em/SKILL.md`: Added — `--team` lane note naming the thin-dispatcher shape and the disjoint run-ids.
- `ARCHITECTURE.md`: Added — § *Run visibility* records that v5.6.2 extends the v5.5 backgrounded-and-watched shape to `plan-em --team`, and why the relay is a file and never a shared run-id.

### [147] — Release v5.6.1

- `RELEASES.md`: Added — v5.6.1 notes covering [143]–[146] (gate runs in `pre-merge` and `merge` dispatch to a subagent, `merge` phase-split between mechanical steps and human-gate steps, verdict always written to disk, docs).

### [146] — v5.6.1 docs

- `README.md`: Added — FAQ entry explaining why a gate run reports itself as running in a subagent (leaner conversation, live progress, no output or approval change).
- `ARCHITECTURE.md`: Changed — the composition bullet now names gate self-delegation and nesting as a supported shape; § *Run visibility* gains the dispatcher paragraph (probe → spawn → `gate-<epoch>` watch → verdict-file relay, merge's phase split, interview modes inline).

### [145] — `merge` phase-split: mechanical phases in subagents, every human gate main-thread

- `.claude/skills/merge/SKILL.md`: Added — `Agent` to `allowed_tools`; § *Dispatch — the phase split* with the per-mode phase table, the structured gate-request hand-back, and the restatement that sanctioned writes execute inside the subagent while the dispatcher writes nothing. `--staging` phase 2 (the sign-off stamp) runs inline — one script call is cheaper than a spawn. `--init` stays inline.
- `.claude/skills/merge/refs/staging.md`: Added — phase markers at the existing boundaries: Steps 1–6 are subagent phase 1, the Step 6 STOP and Step 7's approval ask are main thread. No step re-ordered.
- `.claude/skills/merge/refs/production.md`: Added — phase markers: release identity through Step 2 is subagent phase 1, Step 3's double-confirmation and the `direct`-flow inline human-test approval are main thread, lock acquire through Step 10 is subagent phase 2, and the failed-ship rollback offer stays main thread. No step re-ordered.

### [144] — `pre-merge` dispatches its gate run to a subagent

- `.claude/skills/pre-merge/SKILL.md`: Added — § *Dispatch* now opens with the subagent-execution stanza (cheap refusal probe inline, backgrounded spawn, `gate-<epoch>` watch, relay); interview modes stay inline; new `verdict_file` output row; emission step 3 names the verdict file as the dispatcher's transport; `gate-dispatch.md` added to references.
- `.claude/skills/pre-merge/refs/executor.md`: Added — §3 nesting note recording the v5.6.1 spike outcome (nested `Agent` spawns work, so parallel waves run unchanged inside the gate subagent; only run-id disjointness is required); the tick-relay rule writing every `REPORT` block to `.pre-merge/<ts>/heartbeat.log` so the dispatcher can fold inner progress into its own notes; §6 now writes `verdict.json` to the artifact dir on every verdict, not best-effort.

### [143] — `shared/refs/gate-dispatch.md` — the gate dispatcher contract

- `.claude/skills/shared/refs/gate-dispatch.md`: Added — new cross-skill contract: pre-spawn refusal probe → one backgrounded `Agent` spawn → `script-agent-watch.sh` registration under a gate-scoped `gate-<epoch>` run-id disjoint from the inner `premerge-<epoch>` → byte-identical verdict relay read from the artifact file (never paraphrased from the subagent's return text) → `--end` + `--close` on every exit path. Carries the phase-split rule (every `AskUserQuestion` stays main-thread, same wording, same order) and the six invariants: dispatcher does no work, byte-identical output, no gate weakens, observational watch, disjoint run-ids, both states close.

## 2026-08-02

### [142] — Release v5.6.0

- `RELEASES.md`: Added — v5.6.0 notes covering [138]–[141] (AHA terse write contract, `script-aha.sh --list` sweep, the `/msg --aha` compaction mode, targeted AHA read slices, docs).

### [141] — v5.6 docs

- `README.md`: Added — `/msg --aha` mode-table row.
- `ARCHITECTURE.md`: Changed — `script-aha.sh` row now names the terse cap, `--count` and `--list`; `devkit/AHA.md` row now names the 2–3-line contract and the `--aha` compaction pass.
- `QUICKSTART.md`: Added — troubleshooting row for a long/noisy `devkit/AHA.md` → `/msg --aha`.

### [140] — every AHA writer terse, every AHA reader targeted

- `.claude/skills/plan-pm/refs/protocol-pm.md`, `.claude/skills/plan-em/refs/protocol-em.md`: Changed — the two remaining hand-append AHA paths now go through `script-aha.sh` (tags `pm:<class>` / `em:<class>`), so the terse cap and recurrence counting cover every writer.
- `.claude/skills/eng/refs/build/protocol.md`, `protocol-packet.md`: Added — one-line terse-cap note (writer rejects oversize; compress, never hand-append around it).
- `.claude/skills/msg/refs/init/templates/template-AHA.md`: Changed — states the 2–3-line one-clause-per-field contract and the tagged entry shape.
- `.claude/skills/plan-em/refs/protocol-em.md`: Added — the devkit digest injected into build/plan subagents now carries an AHA slice: ≤5 entries matched to the agent's rows/stack, never the whole ledger.
- `.claude/skills/eng/SKILL.md`: Changed — direct (non-orchestrated) runs scan `devkit/AHA.md` for row-relevant entries only.

### [139] — `/msg --aha` — sweep, triage, compact the learnings ledger

- `.claude/skills/msg/refs/protocol-aha.md`: Added — new harness mode: `script-aha.sh --list` sweep, per-entry triage (keep / merge / prune / promote with a workflow/memory/code route), inline triage table, one gate, then the rewrite of `devkit/AHA.md` in terse form. Hard boundary mirrors `--doctor`: promotions stay recommendations; the ledger is the mode's only write.
- `.claude/skills/msg/SKILL.md`: Added — `--aha` dispatch row, argument-hint, closing-message and harness-incident coverage.

### [138] — `script-aha.sh`: terse cap + `--list` sweep

- `.claude/scripts/script-aha.sh`: Added — 140-char single-line cap per field (`--summary`/`--why`/`--note`; exit 2 on violation, file untouched) and a `--list` read mode emitting `AHA_ENTRY=<date>|<tag>|<recurrence>|<summary>` per entry plus `AHA_ENTRIES=<n>`; legacy untagged entries report `-`/1.
- `evals/cases/aha-append-reject-oversize/`, `evals/cases/aha-list/`: Added — cap-refusal properties (oversize + multiline, ledger byte-identical) and a golden idempotent sweep over tagged, recurring, and legacy entries. Suite: 100/100.

## 2026-08-01

### [137] — Release v5.5.0

- `RELEASES.md`: Added — v5.5.0 notes covering [131]–[136] (subagent stall watchdog with the 5/10/15 ladder and no auto-stop, backgrounded-wave dispatch giving the heartbeat a real 5-minute cadence, the shared agent-watch contract, `plan-pm --update` PRD migration, converged sample PRDs, docs).

### [136] — v5.5 docs

- `README.md`: Added — `/plan-pm --update` skill-table row; run-visibility FAQ paragraph on the stall watchdog (mentioned at 5m, flagged at 10m, assumed stuck at 15m; nothing is ever killed automatically).
- `ARCHITECTURE.md`: Added — § Run visibility paragraph on backgrounded waves, the poll loop, the 5/10/15 ladder, and the no-auto-stop rule; pointers to `agent-watch.md` and `policies.agent_watch`.

### [135] — sample PRDs converged via `--update` (v5.5 Part A acceptance)

Ran the full `--update` pass (L1 + L2) on prd-100..103. L1 was a no-op (frontmatter already v5.4); the style pass converted §5 bullet lists to the four-column table in all four and relocated extra §1 constraint bullets to §5 as `Addressed` rows (platform bullets deleted — platform is detected at run time). All four now pass `script-prd-shape.py --checks 1,2,3,4,5,6` with 0 failures. §3/§4/§6/§7 and every `Engineering —`/`Todos —` block byte-untouched. Closes the v5.0.1 "prd-100..103 repair-or-accept" item. Note: `features/` is gitignored, so the converged samples exist on disk only and cannot be committed as evidence.

### [134] — `plan-pm --update`: the PRD template/style migrator (v5.5 Part A)

- `.claude/scripts/script-prd-update.py`: Added — deterministic L1 migrator, v5 → v5.4: `depends_on`→`deps`, drops `module`/`platform`/`affects`, fuses the two tuned stamps into `reviewed`, remaps the status enum (`retired` → skip + warn), recovers missing `intake:` from the INTAKE.md ledger (never invents), moves inline plan-review findings to `reports/`, renumbers `## 8. Todos` → `## 7.`. `--dry-run`; one CHANGE/WARN line per edit; exit 0 no-op · 1 migrated · 2 skipped/error; idempotent.
- `script-prd-shape.py`: Added — opt-in check 6 "style" (§5 four-column table, §1 exactly three labelled bullets). Not in the default set; every existing gate byte-identical.
- `plan-pm/refs/protocol-update.md`: Added — U1–U5: resolve targets (path | number | `--all`) → L1 → four L2 style edits → `--checks 1,2,3,4,5,6` gate → closing message. Invariants hard: §3/§4 verbatim, F-IDs frozen, downstream sections untouched, `reviewed: yes` survives structure-only migration. A lingering `[USER: intake row #]` placeholder is 🟡, not 🔴.
- `plan-pm/SKILL.md`: Added — `--update` usage, NL triggers, § Update mode (no INTAKE row — maintenance carve-out; read path unchanged), argument-hint, References.
- `shared/refs/closing-message.md`: Added — one registry row for `plan-pm --update`.
- Evals: 4 new `prd-update-*` cases (full v5→v5.4 migration, idempotency, style gate, `reviewed` preservation).

### [133] — subagent waves dispatch backgrounded and watched (v5.5 Part B, adopters)

- `plan-em/refs/protocol-team.md`: Added — § Wave dispatch (backgrounded + watched): every fan-out (plan wave, build wave, both fused halves) spawns leaves `run_in_background: true`, registers each with its evidence globs, and polls; the per-returning-leaf tick lives inside the loop; `--close` joins `--end` on every exit path including § Hard failures. The "orchestrator is blocked while its leaves run" shape is gone. Leaf contract, collision graph, model tiering, review coverage untouched.
- `pre-merge/refs/executor.md`: Changed — component waves same flip; evidence globs are each check's result report + log; §4's per-report note now rides the poll wake that first observes the report; a stalled component is explicitly not a failed one — fail-fast, criticality and the abort set unchanged; heartbeat and watch both close on every exit path. `load`/`perf` isolation unchanged (an isolated component is a wave of one).
- `eng/refs/build/protocol.md`: Added — one paragraph stating this protocol fans out no leaf wave and keeps plain checkpoint ticks; the step-5a reviewer is a single foreground spawn, never registered or polled.
- merge: audited, not edited — zero subagent fan-out across all 12 files; its long steps are foreground commands, so it keeps checkpoint ticks + pre-announce.

### [132] — the agent-watch contract and heartbeat amendments (v5.5 Part B, refs)

- `shared/refs/agent-watch.md`: Added — the cross-skill dispatch-and-watch contract: the five-step loop, the four-verb call surface, thresholds resolved once at first `--register` (`MSG_WATCH_THRESHOLD` → `policies.agent_watch` → 5/10/15), and the escalation ladder — NOTICE banks a note, WARN adds `--finding low`, STALL adds `--finding high` plus the one sanctioned visible line asking the human ("Stop the task, or let it ride?"). No auto-stop exists in any configuration.
- `shared/refs/status-heartbeat.md`: Changed — poll-loop wake added as a first-class checkpoint with the tightened guarantee (during a backgrounded wave, reports land within ~1 interval of due — effectively real 5-minute cadence); background-and-poll is the standard shape for leaf waves; the persisted-STALL line documented as the single sanctioned out-of-band exception to "only the orchestrator speaks".
- `shared/refs/policy-schema.md`: Added — `policies.agent_watch {enabled, notice_minutes, warn_minutes, stall_minutes}` in the `status_cadence` format, with the explicit statement that the four keys are the whole schema and there is deliberately no `action` key.

### [131] — `script-agent-watch.sh`: the subagent stall watchdog (v5.5 Part B, script)

The sole owner of "is a spawned leaf still producing evidence of work?" arithmetic. Four verbs (`--register` with repeatable `--evidence` globs, `--check` emitting one `OK`/`NOTICE`/`WARN`/`STALL` line per leaf plus `WATCH_SUMMARY=<ok>/<notice>/<warn>/<stall>`, `--done`, `--close`); liveness = freshest of evidence-glob mtimes → newest HEAD commit since register → register ts; thresholds frozen at first `--register` (env → policy → 5/10/15 defaults, ordering repaired to defaults with one stderr note); flat KEY=VALUE state under `.claude/msg/cache/watch/`; strictly observational — no kill, no signal, no `action` key; missing/corrupt state degrades to `WATCH_SUMMARY=0/0/0/0` + exit 0, exit 2 only for caller usage errors. Mirrors `script-status-tick.sh`'s discipline throughout. 7 new `agent-watch-*` eval cases (fake clock): the full tier ladder, no-mid-run threshold drift, fresh-evidence reset, `--done` removal, corrupt state, the disable switch, env scaling + ordering repair, usage guards. Suite green at 98/98.

### [130] — Release v5.4.0

- `RELEASES.md`: Added — v5.4.0 notes covering [118]–[128] (slim PRD schema, external findings ledger, tiered eng plans, 3-column exec table with derived Files, fused medium wave, packet fast-path, batched review, write slimming, timing instrumentation, GUI ledger read, Todos-umbrella validator fix).

### [129] — Release v5.3.0

- `RELEASES.md`: Added — v5.3.0 notes covering [112]–[117] (review evidence artifacts, coverage checks at every build-spawning orchestrator, pre-merge backstop). Numbered [129] deliberately: [118]–[128] are already taken by the v5.4 work on `feat/msg-v5.4.0`, which merges next.

### [128] — the PRD shape validator rejected the Todos shape the pipeline writes (v5.4 fix)

`script-prd-shape.py` check 4 failed `§7 Todos` as an empty reserved section on **every PRD the pipeline actually produces** after a plan wave. The section splitter cuts on H2 headings, and the umbrella `## 7. Todos` is immediately followed by each planner's `## Todos — <Agent>` block — also an H2 — so the umbrella's own body is empty by construction. That is the correct shape: plan-em appends the umbrella once so parallel planners do not race on a shared heading, and each planner adds its own sibling block. Found while regenerating the sample PRDs, where every fixture hit it.

A reserved section is now also satisfied by **populated named continuation sections** — an H2 whose title is the reserved title plus `— <name>`. The rule is deliberately narrow in one respect: a continuation heading with nothing under it does not count, so a titled-but-empty `## Todos — <Agent>` still fails placeholder-drift. Presence of a heading was never the thing being checked; presence of tickets is.

- `.claude/scripts/script-prd-shape.py` — new `continued_by()`; check 4 consults it before the empty/drift arms
- `evals/cases/prd-shape-v54-todos-umbrella`, `prd-shape-v54-todos-umbrella-empty` — **new**, both directions: the umbrella with populated agent blocks certifies clean; the umbrella with an empty agent block still fails

### [127] — the GUI reads findings from the external ledger (v5.4 leftover)

v5.4 moved `plan-review`'s findings out of the PRD and into a growing ledger beside it (entry [120]), which quietly broke the board: it parsed findings out of the PRD body, so a v5.4 PRD rendered no findings at all.

`server.py` now reads `<prd-dir>/reports/review-prd-<n>-<slug>.md` when it exists and ships its text with the PRD payload as `reviewFindings` (plus `reviewFindingsPath`). The client prefers that ledger and parses its table directly — the ledger's heading is a plain `## Findings` and its table has no Auditor column, so pointing the existing table parser at the file is simpler and more tolerant than teaching the heading matcher a new name.

**`reviewFindings` is `null` on a PRD written before v5.4, and that is the fallback signal**: those PRDs keep their findings in the body, the body parser still reads them, and nothing is migrated. A board showing both PRD generations therefore reads each one where it actually keeps its findings. The eng `### 12. Findings` list keeps feeding the same table from the body in both cases.

- `.claude/skills/msg/refs/gui/server.py` — loads the ledger beside the PRD, preferring the exactly-named file
- `.claude/skills/msg/refs/gui/index.html` — new `parseLedgerFindings`; the accordion prefers the ledger and falls back to the body
- `.claude/skills/msg/refs/protocol-gui.md` — documents the two homes and which wins

### [126] — plan-em runs leave a timeline (v5.4 P0)

Every saving in this release is a structural argument: fewer invocations, fewer certifications, fewer reviewer spawns, less prose. None of them is a measurement. `script-em-timing.sh` is the measurement — one appended line per stage boundary of a `plan-em` run, so a finished run leaves a readable answer to "where did the hour go?".

The log is `features/prd-<n>-<slug>/reports/timings-<date>.log`, tab-separated and append-only: `<iso> <epoch> <run-id> <stage> +<delta>s <note>`. The delta is measured against **that run id's own** previous line, so two runs sharing a log never report each other's gaps as their own, and reading the file top to bottom needs no arithmetic. Boundaries marked: pre-flight, certification, exec-table skeleton, plan half, files+collision, branch, each build wave, the review-coverage check, and synthesis. The skeleton boundary deliberately sits *after* the roster gate, so the human wait is isolated in its own segment rather than smeared across the run.

**It is best-effort by contract.** Every call site appends `|| true`, no step may branch on the exit code, and the script never reads a PRD or decides anything. A stage name is validated as a column value — lowercase, digits and hyphens — because a name with a space would produce a line that cannot be read back; that is a usage error and nothing is written. In team mode the orchestrator marks the boundaries inside its own spawn using the run id plan-em injected, so one run reads as one timeline instead of two.

- `.claude/scripts/script-em-timing.sh` — **new**
- `.claude/skills/plan-em/refs/protocol-em.md` — new § Stage timing with the boundary table; `$TIMING_RUN_ID` joins the orchestrator spawn's injected contract
- `.claude/skills/plan-em/refs/protocol-team.md` — new § Stage timing for the boundaries inside the orchestrator's spawn; `$TIMING_RUN_ID` in the input contract
- `.claude/skills/plan-em/SKILL.md`, `ARCHITECTURE.md` — the log and the script are listed as outputs
- `evals/cases/em-timing-first-line`, `em-timing-delta-per-run`, `em-timing-bad-stage` — **new**: the log and its parent are created with +0s; elapsed is per run id and existing lines are never rewritten; a malformed stage name is refused and writes nothing

### [125] — plan-em stops writing things nobody reads (v5.4 P8)

Three writes in a `plan-em` run were unconditional and mostly empty of information.

**`preflight.md` is now written only when the scan found something.** A clean pre-flight used to produce a file of six headings with nothing under them — a write, a read on every later visit, and one more artifact to keep in sync, all to say "nothing to report". A clean run now emits one line instead (`Pre-flight clean — devkit + PRD scanned, no findings.`), and the *absence* of the file means exactly that. A stale `preflight.md` from an earlier run is deleted on a clean run rather than left behind describing a PRD state that no longer holds.

**Step 5's synthesis is one combined summary on a fused run.** The per-agent paragraph made sense when the plan wave ended a sitting and a human read it before deciding to start the build wave — that is still what a large two-wave run gets, unchanged. A fused run has no such handover, and by the time it synthesises it has already returned a build summary per packet and a consolidated orchestrator report; a paragraph per agent is a third telling of the same events, generated at the most expensive point in the run. Fused runs emit ~5 lines: what was planned and built, which stacks took part, the branch, and review coverage.

**Step 1c is a deps-only conflict check**, and the text now says so plainly. `module` and `affects` left the frontmatter in v5.4 P1, so the `deps` array plus the §3 Dependencies column it mirrors are the entire cross-PRD graph — there is no domain-match shortcut and no reverse "who does this break" edge left to consult.

- `.claude/skills/plan-em/refs/protocol-em.md` — 1d branches on whether findings exist (and deletes a stale report on a clean run); Step 5's summary element is selected by `$MODE`
- `.claude/skills/plan-em/SKILL.md` — the Outputs table states the pre-flight report is conditional

### [124] — mechanical packets are reviewed per wave, not per leaf (v5.4 P7)

v5.3 made review coverage provable: every packet's reviewer writes an evidence artifact, and the orchestrator checks the filesystem for one after every wave. That is the right floor, but it was buying the same thing at very different prices — a reviewer spawn per leaf costs the same whether the leaf wrote an auth migration or wired four CRUD forms.

Review **granularity** now follows the packet's model tier, which is a judgment the orchestrator already made and recorded:

- **Sonnet / mechanical packets** — no per-leaf reviewer. The orchestrator spawns **one** `eng --review` over the wave's accumulated diff once the wave lands, and that review writes **one** artifact, `review-prd-<N>-W<w>.json`, carrying a `packets` list of every key it covered and a `built_by` list of those packets' agents.
- **Opus / load-bearing packets** — unchanged, a reviewer per packet, exactly as v5.3 wrote it.

**Coverage did not become weaker, only cheaper.** The orchestrator still passes *every* packet key in the wave to `script-eng-review-check.sh`, which now resolves a key against a wave artifact's `packets` list when no per-packet artifact exists. A key the wave artifact does not list still reads `MISSING`, still gets one reviewer re-spawned, and still escalates on a second miss. The self-review rule tightened rather than loosened: `reviewed_by` matching **any** builder in a batched `built_by` list is self-review, because a reviewer that built one packet of the wave it is reviewing is the exact conflict the rule exists to prevent. Severities from a wave artifact are counted once, not once per key it covers, so the aggregate finding counts stay honest.

Leaves are told which regime they are in via an injected `review=self|batched` field rather than inferring it — a leaf never decides its own review. A batched leaf skips its reviewer spawn and says so on its Review line, which stays a required element of the return.

**Commits batch with the review.** A mechanical packet may land as one commit when it reads as one coherent unit, instead of one per ticket; a load-bearing packet keeps per-ticket commits, where a reviewable history earns its cost. Both commit gates — the comment scan and the size/trailer cap — run on **every** commit regardless; batching commits never batches the gates.

- `.claude/scripts/script-eng-review-check.sh` — a key resolves to a per-packet artifact first, then to a batched wave artifact whose `packets` names it; `built_by` accepts a list and self-review becomes a membership test; severity counts deduped per artifact
- `.claude/skills/eng/refs/review/protocol.md` — new § Batched wave reviews; the artifact schema gains the optional `packets` field
- `.claude/skills/plan-em/refs/protocol-team.md` — § Build wave step 4 routes review by packet tier; § Subagent contract gains the `review=` field and the batched-wave reviewer row
- `.claude/skills/eng/refs/build/protocol-packet.md` — Step 5 branches on `review=`; Step 7 states the commit-granularity rule and that the gates do not batch
- `evals/cases/review-check-wave-batched`, `review-check-wave-unlisted`, `review-check-wave-self-reviewed` — **new**: the batch covers its listed keys and counts once; an unlisted key is still MISSING; a batched builder reviewing its own wave is still SELF-REVIEWED
- `ARCHITECTURE.md` — the review-evidence section states that granularity varies and coverage does not

### [123] — medium PRDs plan and build in one run (v5.4 P5)

A PRD used to cost two `/plan-em` invocations no matter how big it was: plan wave, stop, human re-invokes, build wave. Each invocation repaid the same fixed ceremony — pre-flight scan, cross-PRD check, roster gate — and a full certification round-trip sat between the two halves. For a small feature that overhead is most of the run.

`plan-em` now **sizes itself on the PRD**. Step 1e resolves the intake complexity grade once (`C:` band from the `INTAKE.md` row the PRD's `intake:` key names) into `$SIZE`, and everything downstream consumes that one answer:

- **Medium (`C:` < 8, and the default whenever the grade cannot be resolved)** — one `/plan-em` run does everything. Steps 1–3 are unchanged (pre-flight, one certification, roster gate, exec-table skeleton), then a single **fused** Step 4: the plan leaves write their engineering sections and tickets, `--fill-files` derives the Files column, a mechanical plan-shape check runs, the branch is cut and the lane moved, and the build leaves dispatch — without returning to the user in between. Status walks `backlog → specced` when the tickets land and `→ wip` when the branch is cut, both inside the one invocation, because the lifecycle tracks the work and not the call count.
- **Large (`C:` ≥ 8)** — the two-wave path, byte-for-byte as before, with a certification before each wave.

**One certification, not two — and the gap is filled mechanically.** A medium run pays only the product certification at Step 2. The between-wave eng certification is not deferred, it is deleted for that size, and `script-eng-plan-shape.py` runs in its place immediately before the build half dispatches. That trade is deliberate: the eng cert's real value is catching a plan that drifted across a session boundary, and a fused run has no session boundary — whereas the failures that actually break a build wave (a ticket violating the schema, a cyclic `depends-on`, a `(edit)` path that does not exist) are exactly what the shape check catches mechanically in seconds. A red check after one repair attempt **stops the run before any build packet is dispatched**; a medium run has nothing else standing there.

**Resume needs no new machinery.** The existing `engineering_agents` mode detection does double duty: it is the wave selector for a large PRD and the resume detector for a medium one. An interrupted fused run leaves exactly the on-disk evidence a completed plan wave leaves, so re-invoking `/plan-em` finds every roster agent present, resolves `$MODE = build`, and finishes the build half. No `--resume` flag, no run-state file.

**One orchestrator spawn covers both halves in team mode**, which is the one documented exception to "the orchestrator never resolves the branch". plan-em is blocked while its orchestrator runs, so keeping the branch cut on plan-em's side would have forced a second orchestrator spawn for the build half — the exact cost the fusion removes. The invariant that protects the shared tree is unchanged: leaves never touch branches, and exactly one agent cuts it, once.

Nothing about review coverage is relaxed for a fused run — v5.3's after-every-wave check, its single reviewer re-spawn and its escalation all apply to the build half unchanged.

- `.claude/skills/plan-em/refs/protocol-em.md` — new Step 1e size resolution; Step 2 states the per-size certification count; Step 4 mode detection becomes a 3-mode table (`plan` / `build` / `fused`) crossed with `$SIZE`; new § Fused mode composing the two halves by reference; the eng-cert precondition is scoped to large; the branch suggestion is scoped to `$MODE = plan`; `$SIZE` joins the injected scoped context for plan dispatches
- `.claude/skills/plan-em/refs/protocol-team.md` — new § Fused wave (planners → `--fill-files` → shape check → branch cut + stamps → build packets → one consolidation, one heartbeat across both halves); `$MODE` gains `fused` and `$SIZE` joins the input contract; hard failures scoped per mode
- `.claude/skills/plan-em/SKILL.md` — new § How many invocations a PRD costs
- `.claude/skills/shared/refs/closing-message.md` — third `plan-em` row for the fused wave
- `ARCHITECTURE.md`, `README.md` — the pipeline narrative describes size-proportional invocation counts

### [122] — orchestrated build leaves get a fast-path protocol (v5.4 P6)

Every leaf in a parallel build wave was reading `eng/SKILL.md` plus `refs/build/protocol.md` — about 48KB — to do a job that needs a fraction of it. Most of what it read described situations that cannot arise inside an orchestrated run: how to create a branch (the orchestrator already did), how to call `/cook` (the standards payload is injected), how to open a sub-branch PR (leaves commit direct), how to run a status heartbeat (the orchestrator ticks for it), and how to build from a `report=` issues file (a different entry point entirely). With N leaves per wave, that read is paid N times.

`eng/refs/build/protocol-packet.md` is the leaf's whole contract instead: what it may assume, tickets and their ordering, the red/green TDD loop, the full-suite gate and the note that a caller may suppress it, the Step-5 review artifact, the db-touch pause, the commit gates, scope enforcement, the AHA / OPEN-QUESTIONS writers, and the output contract. It opens by stating what the orchestrator guarantees — branch checked out, standards payload injected, scoped context injected, gates pre-approved — because a document that omits the branch-creation path has to say *why* it is safe to omit it.

The two things that stay non-negotiable are called out as such. The **db-touch pause** is the one gate the autonomy contract does not reach, and the **v5.3 review artifact** (`reports/review-prd-<N>-<K>.json`) plus the summary's Review line are required elements of the return, not optional — with the reminder that the orchestrator's coverage check reads the filesystem regardless of what a leaf claims.

**Only build leaves are rerouted.** Plan leaves have no branch, no standards payload and no commit gates, so `protocol-team.md` now names the protocol file per wave rather than once for both. Standalone human `eng --build` runs are untouched — the packet doc's assumptions are false outside an orchestrated run, so `SKILL.md` routes there only when a leaf was spawned.

- `.claude/skills/eng/refs/build/protocol-packet.md` — **new**, ~11KB replacing ~48KB per leaf
- `.claude/skills/plan-em/refs/protocol-team.md` — the leaf-spawn prompt's read target becomes a per-wave table (build → packet doc, plan → `SKILL.md`), with the standalone case stated explicitly
- `.claude/skills/plan-em/refs/protocol-em.md` — the solo lane's build fan-out points at the packet doc; its plan fan-out is unchanged
- `.claude/skills/eng/SKILL.md` — Step 0's `--build` row and the References entry note the orchestrated fast path

### [121] — the exec table drops to three columns and the Files column is derived (v5.4 P4)

The execution table went from five columns to three — `Feature — concern | Files | Agent` — and the one column that remains contentful is no longer written by an agent at all.

**Two columns were carrying nothing.** The **Todos** anchor (`[F1](#todos-f1)`) was human navigation; nothing mechanical ever read it. The **Execution steps** pointer (`→ F2-T1, F2-T2`) was a second index over the tickets, and a second index is only ever something to disagree with the first. Build agents now locate their tickets exactly one way: take the assigned rows' F-IDs, read `### F<n>` under `## Todos — <Agent>`. That deletes a whole failure class — `unresolved-pointer`, `unpointed-ticket`, and the build protocol's Step 0 pointer cross-check — without weakening the tickets-are-the-spec contract, which is untouched.

**Files is now mechanised.** `script-em-exec-skeleton.py --fill-files` reads the tickets and writes every Files cell as the union of that row's F-ID's ticket `files` for that row's agent. The collision graph therefore becomes derivable from the tickets at any moment, rather than being an assertion a planner agent typed and could get wrong. Rows sharing an (F-ID, agent) pair get the same set — deliberately, since two concerns of one feature built by one agent genuinely are not file-disjoint, and splitting the set would claim a safety the build does not have. An F-ID with no ticket block is a hard failure (`MISSING_TICKETS`, exit 1, nothing written); the empty-work sentinel is not (`EMPTY_FILES`, exit 0, cell left blank) — the distinction is exactly why that sentinel exists.

**Read-tolerance, verified.** Every reader resolves columns by name, so the legacy 5-column table keeps working: the same rows in either shape produce a **byte-identical** wave decomposition, and `script-eng-plan-shape.py` on the untouched `features/planned/` sample PRDs produces byte-identical output before and after this change. Check 6 keeps its full pointer validation for legacy tables and reports `SKIP … reason=no-pointer-column` for 3-column ones. The A22 drift guard was at risk here — a table whose `Execution steps` header had drifted would have read as "the new shape" — so a pointerless table only counts as v5.4 when Feature, **Files** and Agent all resolve; anything else is still drift and still fails.

- `.claude/scripts/script-em-exec-skeleton.py` — renders 3 columns; new `--fill-files [--agent <name>]` derivation mode with `FILLED` / `EMPTY_FILES` / `MISSING_TICKETS` / `NO_FILES_COLUMN` records; the atomic write is now shared by both write paths
- `.claude/scripts/script-em-exec-collision.py` — columns resolve exact-then-prefix, which is what lets `Feature — concern` resolve and keeps collisions named by feature rather than `row<N>`; the exit-3 and `MISSING_FILES` arms stay for legacy tables, with the message redirected to the derivation
- `.claude/scripts/script-eng-plan-shape.py` — check 6's pointer arm is legacy-only; `pointer_mode` tri-state distinguishes the new shape from header drift
- `.claude/skills/eng/refs/build/protocol-exec.md` — **deleted**, with every reference to it; the Files-fill instruction it carried is now a script
- `.claude/skills/eng/refs/build/protocol.md` — Step 0 cross-checks that the ticket blocks exist rather than that pointers resolve; Spec source and step 2 locate tickets by F-ID alone
- `.claude/skills/eng/refs/plan/protocol.md` · `template-todo.md` · `SKILL.md` — the plan pass writes two artifacts, not three, and touches no exec-table cell
- `.claude/skills/plan-em/refs/template-exec-table.md` — rewritten around the 3-column shape, the derivation call and its two failure lines
- `.claude/skills/plan-em/refs/protocol-em.md` · `protocol-team.md` — the derivation step after the plan wave; every "the plan wave must populate Files" hard-failure text now says "run the Files derivation"
- `.claude/skills/plan-pm/refs/template-prd.md` · `.claude/skills/plan-review/refs/certification.md` · `ARCHITECTURE.md` — the 3-column skeleton and the derived-not-typed reading of an empty cell
- `evals/cases/exec-skeleton-v54-3col` · `exec-files-derive` · `exec-files-derive-missing-tickets` · `exec-collision-v54-3col` · `exec-collision-legacy-5col` — new; the 3-column render, both derivation directions (including the PRD being left byte-identical on failure), and the two table shapes producing identical decompositions
- `evals/cases/a21-exec-collision-no-files-column` — golden refreshed for the redirected message

### [120] — the engineering plan is sized to the PRD: 12 sections become 4 (v5.4 P3)

An eng agent used to write the same twelve-section essay whether the PRD was a one-file tweak or a multi-stack rewrite. Most of it had no reader: build agents execute the `## Todos` tickets and never open plan prose, so Summary, PRD reference, Alternatives considered, Phases and dependencies, Developer experience, Migration and breaking changes and Risks and mitigations were written, paid for in Opus tokens, and consumed by nobody.

The default is now four sections — **Design decisions, Integration contracts, Scope mapping, Open questions** — chosen because each carries something a ticket structurally cannot: a rationale that outlives the diff, a cross-agent contract, the feature-to-agent map, and a question only a human can answer. The old Findings — PRD gaps section folds into Open questions; both resolve the same way, so they were one list split across two headings.

The full twelve-section shape survives for genuinely large work, **tiered on the intake grade**: a PRD whose `INTAKE.md` row grades `C:` ≥ 8 gets the long form, everything else gets the short one. That threshold is not new — it is the same band that already triggers intake's split gate. An unresolvable grade defaults to medium, deliberately: writing the long shape defensively would give back the entire saving.

Read-tolerance runs both ways. `script-eng-plan-shape.py` gains an eighth check that accepts either shape, including the legacy 13-section variant carrying "Branching and CI strategy" that the `features/planned/` sample PRDs still use — those parse untouched. A section with no `###` subheadings at all is skipped rather than failed, so prose-only engineering sections written before the shape was numbered do not start erroring.

- `.claude/skills/eng/refs/plan/template-eng-plan.md` — rewritten around the two shapes: the tier table and grade-resolution rule up front, then the medium four and the large twelve, each with its own quality-gate table
- `.claude/skills/eng/refs/plan/protocol.md` — the shape-selection rule at the output contract; every `§11 (Findings)` gap-reporting pointer now names **Open questions** (medium §4 / large §11), since a medium plan has no §11
- `.claude/scripts/script-eng-plan-shape.py` — **check 8**: the `## Engineering — <Agent>` section must be one of the two sanctioned shapes. Titles are prefix-matched after normalising ordinals, emphasis and dash style, so numbering drift and em-dash style cannot cause a false failure. Codes `missing-plan-section` / `unknown-plan-section`
- `.claude/skills/eng/SKILL.md` — the reference entries for the template and the validator
- `evals/cases/plan-shape-v54-medium` · `plan-shape-v54-large-legacy` · `plan-shape-v54-unknown-section` · `plan-shape-v54-shape-skip` — new; both accepted shapes, the fail-loud direction (missing core + invented section in one case), and the no-sections SKIP

### [119] — plan-review findings move to an external report (v5.4 P2)

The certification ledger left the PRD. Findings now accumulate in one growing table at `<prd-dir>/reports/review-prd-[n]-[slug].md`, created on the first run and appended to thereafter. The reasoning: a findings table is append-only and grows without bound, while the PRD is a contract every downstream stage re-reads on every run — keeping them in one file made every reader pay for the audit history. The `reviewed:` frontmatter stamp stays the gate signal; the report is the evidence trail behind it, and gates nothing on its own.

The report drops the `Auditor` column — one mode, one auditor, so it carried no information. **PRDs written before v5.4 keep their ledger exactly where it is**: `script-ledger.py` picks the home (existing report → existing in-PRD section → new report) and appends to whichever table it finds, eight-column Auditor table and all. Nothing is migrated.

Two things worth flagging. First, the A11 drift guard would have silently died: a PRD whose findings heading had drifted used to be refused, but under the new selection it would have quietly got a report created beside the orphaned section, whose rows no run would ever dedup against. The guard moved into target selection and still refuses. Second, that made the in-PRD section-creation arm unreachable, so it and its `LEDGER_PLACEMENT=eof-fallback` output are gone.

- `.claude/skills/plan-review/refs/template-review-report.md` — **new**: the report's location, frontmatter, column contract and status-recomputation rule, plus an explicit table distinguishing it from v5.3's `review-prd-<N>-<K>.json` eng build evidence. Different suffix shape, verified non-colliding against every existing glob
- `.claude/scripts/script-ledger.py` — picks the ledger's home; creates the report scaffold; `created` set once and `last-run` rewritten each run; `Auditor` written only when the target table has that column; `--auditor` now optional; emits `LEDGER_TARGET=` and `LEDGER_FILE=`
- `.claude/scripts/script-cert-status.sh` — follows the ledger to its new home and resolves Severity/Status by column *name*, which is what lets one scan read either table shape. The stamp read falls back to `reviewed:` when the PRD has no tune pair, so `--product`/`--eng` keep working unchanged at the call site
- `.claude/skills/plan-review/SKILL.md` — the report is now the one file this skill creates; stamps `reviewed: yes`; the discriminator for a legacy PRD is the *tune pair*, not `reviewed` (both shapes have `reviewed`, so keying on it would have left older PRDs uncertified)
- `.claude/skills/plan-review/refs/certification.md` — findings-table schema split into the v5.4 and legacy shapes
- `ARCHITECTURE.md` — `script-ledger.py` and `script-cert-status.sh` entries rewritten
- `evals/cases/ledger-report-append` · `ledger-legacy-section-kept` — new; the growing-table cycle (carry + append + `last-run`) and the read-tolerance direction (legacy PRD keeps §7, no report created)
- `evals/cases/a11-ledger-eof-fallback` → `a11-ledger-no-section-creates-report` — repurposed: the same input now creates the report and leaves the PRD byte-identical

### [118] — PRD template slim: seven sections, one review stamp (v5.4 P1)

The PRD shrank. Frontmatter dropped `module`, `platform` and `affects`, renamed `depends_on` to `deps`, and fused the `product-tuned`/`eng-tuned` pair into a single `reviewed` stamp. The lifecycle enum is now `backlog → specced → wip → complete`, where `status` is the lifecycle truth and the lane directory stays the location truth — the two answer different questions and neither derives from the other. §1 Product objective became three terse bullets (who / what changes / success signal) instead of a paragraph, §4 Error cases lost its ≥2-row quota, and the old §7 Plan review findings section is gone, which renumbers Todos to §7.

**Every parser keeps reading v5-shape PRDs**, exactly as they already tolerate the pre-v5 `## Execution Table` heading. Shape is detected from the frontmatter alone — any of the six dropped/renamed keys means v5 — so section expectations and key expectations can never disagree about which shape a file is. Nothing on disk is migrated: writers emit v5.4 only, and the sample PRDs under `features/planned/` are regenerated in a later packet.

- `.claude/skills/plan-pm/refs/template-prd.md` — rewritten to seven sections; new frontmatter block; the status/lane table; the platform-detection and overlap-scan fallbacks for the removed fields
- `.claude/scripts/script-prd-shape.py` — one validator, two shapes: `Shape` bundles the canonical sections, reserved placeholders, owners and frontmatter keys per shape, and `detect_shape()` picks from the frontmatter. `SUMMARY` now carries `shape=`
- `.claude/scripts/script-prd-scan.sh` — normalises both shapes once, then derives `complete`/`completion` from the normalised values, so a v5 PRD buckets byte-identically. Emits `deps` alongside `depends_on`; frontmatter scalars stay verbatim passthrough
- `.claude/scripts/script-prd-deps-mirror.sh` — writes back under whichever array name the file carries, so a v5 PRD keeps `depends_on` and is never migrated; a file with neither gets `deps`
- `.claude/scripts/script-prd-digest.py` — the frontmatter slice carries both shapes' keys; whichever the file lacks reads back `None`
- `.claude/scripts/script-cert-mech.py` — check 6 walks whichever edge keys the PRD actually has, so a v5 PRD still gets both its edge kinds checked and a v5.4 PRD gets one
- `.claude/scripts/script-prd-stamp.sh` — documents the new enum and the single `reviewed` stamp; keeps the v5 fields allowed so an older PRD can still be stamped where it sits
- `.claude/skills/msg/refs/gui/server.py` · `index.html` — `specced`/`wip` join the planned rung; `deps` alias; the board is told each PRD's shape so it stops rendering two permanently-blank tune pills on a v5.4 PRD
- `.claude/skills/plan-pm/refs/protocol-pm.md` · `protocol-sub.md` · `SKILL.md` — deps-only overlap scan, run-time platform detection, terse §1, no row quota, the new stamp table
- `.claude/skills/plan-em/refs/protocol-em.md` — Step 1c is a deps-only conflict check; stamps `specced` after the plan wave and `wip` at the branch cut
- `.claude/skills/merge/refs/production.md` · `SKILL.md` — the terminal stamp is `complete`, or `done` on a PRD that predates v5.4
- `.claude/skills/plan-review/refs/certification.md` — check 6 reads `deps`; notes that cert-mech covers both shapes
- `evals/cases/prd-shape-v54-clean` · `prd-shape-v5-tolerated` · `prd-shape-v54-stale-findings` · `deps-mirror-v54-deps-key` — new; the first cases to cover `script-prd-shape.py` at all, pinning both shapes and the "v5.4 PRD must not keep the findings section" direction
- `evals/cases/a16-prd-scan-title-anchored/expected/stdout` — regenerated for the additive `deps` key; every other field byte-identical

### [117] — The pre-merge backstop, plus docs and the incident learning (v5.3 P5)

- `.claude/skills/pre-merge/refs/executor.md`: Added — §5a.1, review coverage for the branch under grade. The gate did not run the wave and holds no packet list, so it uses `--expect-from-builds`: for every `report-prd-<N>-<K>` on disk there should be a `review-prd-<N>-<K>`. Missing coverage is **one `medium` finding** (`rule: review-coverage`), authored the same way §5a authors its `missing-result-report` finding
- **`medium` is deliberate and non-blocking.** Review coverage can never produce `fail` — a merge is gated by pre-merge's own green run, never by review. `medium` was chosen over `low` because it survives a skim of the report and `low` does not. The value is not enforcement; it is that an unreviewed branch can no longer reach a human silently
- `.claude/skills/shared/refs/finding-schema.md`: Added — the review artifact documented alongside the issues file it sits beside. The two answer different questions: the issues file is *what a failed run found*, the review artifact is *that a review happened at all*
- `ARCHITECTURE.md`: Added — a **Review evidence** section stating the mechanism and, more importantly, why review's authority is unchanged: presence is now provable, gating is not
- `README.md`: Added — "How do I know the review actually ran?" in the FAQ voice: because it leaves a file behind, and a missing one is repaired by re-reviewing rather than re-building
- `devkit/AHA.md`: Added — the incident and its lesson under `harness:prose-without-a-check`, so future protocol work does not try to re-solve a skipped rule by rewording the instruction. That file is gitignored working state, so the durable statement of the same lesson lives in ARCHITECTURE.md

### [116] — Every build-spawning orchestrator checks coverage (v5.3 P4)

- The gap was never specific to team mode. The audit rule is now uniform: **every site that spawns `eng --build` and consolidates the result runs the coverage check before consolidating.** A grep over `.claude/skills` finds exactly three such sites, and all three are wired
- `.claude/skills/plan-em/refs/protocol-em.md`: Added — the `--solo` lane runs the same check before Step 5 synthesis, keyed by agent name (solo runs one leaf per stack, so the agent name *is* the packet key). Same repair: re-spawn a reviewer over that agent's diff, re-check once, escalate and log `tool-error:review-<agent>` on a second miss. The synthesis must state `reviewed n/n agents`, and one that cannot is a hard failure. Prompt field 8 injects `<K>` and `built_by` so a leaf never invents the key
- `.claude/skills/eng/refs/build/fix-build-orchestrated.md`: Added — Step 3a, the same check before the loop-close. This orchestrator had **zero** review mentions before today, yet a fix is code like any other. Per-issue keys are `<K>-fix-<issue-id>`, which is what stops parallel fix subagents from colliding on one artifact name under the shared issues-file `<K>`
- Sites deliberately not wired, having verified each: `merge`, `pre-merge`, `fix-loop.md` and the `--gui` board only *name* the `eng --build` command in follow-up strings and rendered panels — they spawn no builder and consolidate no wave

### [115] — The team orchestrator verifies review coverage (v5.3 P3)

- `.claude/skills/plan-em/refs/protocol-team.md`: Added — § Build wave step 4, a review-coverage check after **every** wave, sitting beside the existing DB/data guard because that is the proven shape for an after-every-wave control. The orchestrator asks `script-eng-review-check.sh` whether each packet has an artifact and quotes its coverage line; it never asks the leaf, whose self-report is exactly what a skipped review looks like
- Recovery is cheap and silent at first contact: a `MISSING` key re-spawns **one** `eng --review` over that packet's diff — the builder is not re-run and its commits are untouched — then re-checks once. A second miss escalates to the user and logs a `tool-error:review-<k>` DOCTOR row, matching the failed-packet arm exactly. A usage error or absent script is a harness fault logged as `validator-fail`, never read as "reviewed"
- `.claude/skills/plan-em/refs/protocol-team.md`: Changed — consolidation must state coverage (`reviewed n/n packets` per wave plus aggregate finding counts). A consolidation that cannot state coverage is itself a hard failure, because the incident's signature was a wave that consolidated green while saying nothing about review
- `.claude/skills/plan-em/refs/protocol-team.md`: Changed — the build leaf's return contract gains the `**Review:**` line as a required element alongside the v5.2 `status:` line, and the Build row of the subagent contract now injects the packet key `<K>` and `built_by`, so a leaf never invents the key the coverage check expects. A Review row documents the repair spawn
- The line in the summary is a convenience for the human; the filesystem check is the proof, and it runs whether or not a leaf claims a review happened

### [114] — The reviewer leaves a trace (v5.3 P2)

- `.claude/skills/eng/refs/review/protocol.md`: Added — a § Artifact section. The reviewer writes its returned JSON object to `<prd-dir>/reports/review-prd-<N>-<K>.json` **before** returning it, temp-file-then-`mv`, so a reviewer that dies mid-run leaves no half-written file for a checker to read as a completed review. `<K>` is the spawner's packet key, never invented: no key, or a failed write, means say so in the one-liner and log a `write-miss` DOCTOR row, then let the caller's coverage check read the gap and re-spawn
- `.claude/skills/eng/refs/review/protocol.md`: Changed — the return contract gains `reviewed_by` and `built_by`. This is what turns the file's own opening rule — *an agent that did not write the code* — from an aspiration into a checkable fact
- `.claude/skills/eng/refs/build/protocol.md`: Changed — Step 5a injects `built_by` and the artifact key alongside the existing inputs, reusing the build's own run-report `<K>` so a build and its review sit under one key; an orchestrated run passes the orchestrator's packet key through unchanged. The build summary's existing **Review** line now carries the verdict and the artifact path, so the evidence is quotable without opening the file
- Step 5a's unconditional-review wording is untouched. v5.3 changes only whether a review leaves a trace, never what its findings gate — nothing below `high` blocks, and nothing here blocks a merge

### [113] — Regression evals for the review-coverage check (v5.3 P1)

- `evals/cases/review-check-complete`: Added — every expected key covered exits 0 with the single coverage line an orchestrator quotes; severity counts aggregate across artifacts
- `evals/cases/review-check-missing`: Added — one absent key exits 1 naming exactly that key and nothing else, with the coverage line still printed so the caller can report the gap rather than only knowing something failed
- `evals/cases/review-check-corrupt`: Added — an artifact that does not parse, and one that parses without a `verdict`, are both counted missing. A reviewer that died mid-write must never read as a clean review
- `evals/cases/review-check-self-reviewed`: Added — `reviewed_by` equal to `built_by` fails the check; presence alone is not coverage
- `evals/cases/review-check-empty-dir`: Added — the incident's own shape (nine packets built, zero reviewers spawned, no artifacts at all). Exits 1 naming every key and never reports clean. The most important case in the set
- `evals/cases/review-check-expect-from-builds`: Added — the derivation direction of the same contract: keys taken from the build reports on disk, counted once across the `.md`/`.json` pair, fix plans excluded
- Suite: 64/64 green in ~3.9 s (58 cases in ~3.6 s before), so the new coverage costs roughly a quarter-second

### [112] — Review evidence artifact and its presence check (v5.3 P0)

- `.claude/scripts/script-eng-review-check.sh`: Added — the mechanical control behind "review cannot be skipped". `--reports-dir <d> --expect <k1,k2,…>` exits 1 listing `MISSING <k>` for every packet key with no review artifact and 0 with a one-line coverage summary (`reviewed 9/9 — 0 blocker, 1 high, 2 medium`). An artifact that does not parse, or that lacks `verdict`/`findings`, is counted **missing** — never counted as covered, because an unreadable artifact proves nothing
- `reviewed_by` / `built_by` make the review protocol's "an agent that did not write the code" rule checkable rather than aspirational: an artifact whose two identities match prints `SELF-REVIEWED <k>` and fails the check
- `--expect-from-builds` derives the expected key set from the build run reports already in the folder (`report-prd-<N>-<K>.json|.md`, fix plans excluded), for a caller that did not run the wave and has no packet list of its own. No build reports at all exits **3** — expectation unknown, reported as unknown, never as covered
- Artifact location is the PRD's existing `reports/` folder as `review-prd-<N>-<K>.json`, alongside the `report-prd-<N>-<K>.json` issues file — no new location, no new schema. Coreutils plus a `python3` stdlib JSON read; no `jq`

### [111] — Publish the v5.2.0 user-facing release notes

- `RELEASES.md`: Added — the v5.2.0 section covering [104]–[110]: the status heartbeat across builds, gate runs, ships and planning waves, the pre-announcement of long steps, the per-run `--quiet`/`--status` controls and project-level cadence, and the every-exit close. States the checkpoint trade-off in user terms — a run may report slightly later than the interval, but is never interrupted or reshaped to hit it

### [110] — Per-run heartbeat flags, policy key and docs (v5.2 P5)

- `.claude/skills/{eng,merge,plan-em,pre-merge}/SKILL.md`: Added — `[--quiet | --status <n>m]` in each `argument-hint`, a Usage line in each skill's existing style, and a References pointer to `../shared/refs/status-heartbeat.md`. eng's is scoped `(--build only)`; pre-merge is the single place that states the 2-minute floor. No SKILL.md restates the report shape or the checkpoint rule — the contract stays the one source
- `.claude/skills/shared/refs/status-heartbeat.md`: Changed — states the flag→env mapping explicitly (`--quiet` → `MSG_STATUS_INTERVAL=0`, `--status <n>m` → `=<n>`, neither → policy decides), so the four SKILL.md flags have exactly one documented path into the script
- `.claude/skills/shared/refs/policy-schema.md`: Added — `policies.status_cadence` (`{enabled, interval_minutes}`, default on/5). Read only by `script-status-tick.sh` at `--start`, **not** by `script-policy-read.py`, so no skill plumbs the key itself; malformed falls through silently
- `README.md`: Added — "Why did the run go quiet for eight minutes?" answered in the FAQ voice: one long step with no natural pause inside it, pre-announced rather than unexplained
- `ARCHITECTURE.md`: Added — a **Run visibility** section stating the cadence-checked-checkpoint stance and that the heartbeat is purely observational — it never moves a verdict, a refusal or a gate

### [109] — Heartbeat checkpoints in the ship gate (v5.2 P4)

- `.claude/skills/merge/refs/staging.md` and `refs/production.md`: Changed — `--start` after the policy pre-flight, a tick at each numbered step boundary (protection → readiness → CI → merge → deploy → verify, and production's longer chain through the lock, release PR and tag), and a tick inside the smoke v2 `watch_window`/`poll` loops, which already re-enter the orchestrator per iteration
- **The human gates are byte-identical.** No tick sits between a gate's question and its answer: the staging human-test STOP, the production double-confirmation and the `direct`-flow inline attestation are untouched, and production's post-gate tick fires only once every ask has resolved. Ticks sit around the release lock and the rollback offer, never inside them
- Pre-announce durations stay qualitative ("platform-declared, see `devkit/PLATFORMS.md`") rather than invented minute counts — a fabricated progress number is worse than silence
- `.claude/skills/shared/refs/status-heartbeat.md`: Changed — `--end` now explicitly fires on **every** exit, not just the happy one. A phase closing only on success both withholds the summary at the moment a human most wants it and leaks one state file per bad run. Wired into staging's smoke-failure stop and production's failed-ship path

### [108] — Heartbeat checkpoints in eng --build and the team orchestrator (v5.2 P3)

- `.claude/skills/eng/refs/build/protocol.md`: Changed — a **standalone** build opens the heartbeat at the top of the work steps (`--total` = ticket count), ticks per ticket whose `done-when` just passed, pre-announces the two long steps that have no checkpoint inside them (the full-suite gate and the Step-5a review spawn) and ticks on each one's return, then closes at the build summary. Steps 1–4 are input validation and human-facing gates — fast, so they get nothing
- `.claude/skills/plan-em/refs/protocol-team.md`: Changed — the team orchestrator owns the heartbeat for both waves: opens at dispatch with the packet count as `--total`, pre-announces each wave before spawning (it is blocked while leaves run), ticks once per returning leaf, closes at consolidation
- The two contracts cannot blur: an **orchestrated** build never opens its own heartbeat, and the `standards payload` signal the protocol already uses to tell orchestrated from standalone is what decides it. Stated once on each side, cross-referenced, so the files cannot drift
- Subagent return contract gains exactly one line — `status: <packet-or-ticket-id> <done|blocked> — <≤8-word summary>` — the only sanctioned path from a leaf into the heartbeat. Leaves never call the tick script and never emit status themselves

### [107] — Heartbeat checkpoints in the pre-merge executor (v5.2 P2)

- `.claude/skills/pre-merge/refs/executor.md`: Changed — five checkpoint sites woven into the existing spine: `--start` once the pipeline plan is written (§1), a tick at each wave boundary (§3), the three sandbox lifecycle transitions (§3b), a tick at each per-component result-report write (§4 — already one-per-component, so no step was added to create a checkpoint), and `--end` at the terminal (§6). The verdict JSON stays stdout's final machine emission, byte-identical whether the heartbeat ran or was disabled
- Long-component silence is handled by pre-announce only: when the next wave carries an `expensive` component (`e2e`, `perf`, `load`, `regression`), the preceding tick names it and its expected duration in `--next`
- Plan Q2 resolved **against** backgrounding `unit`/`integration` with log polling: those components execute as opaque `Agent` subagent calls that return atomically, so the orchestrator never regains control mid-run to poll. Implementing it would mean changing the execution mechanism itself, putting the wave concurrency and fail-fast model at risk for a visibility gain — gate correctness outranks visibility

### [106] — The heartbeat contract, pulled ahead of the protocol edits (v5.2 P2a)

- `.claude/skills/shared/refs/status-heartbeat.md`: Added — the one home for the cross-skill heartbeat contract: the checkpoint rule (and why a real timer is not expressible in a skill), the call surface, the report shape, the only-the-orchestrator-speaks rule for subagents, the two mitigations for long blocking steps, cadence resolution, and the degradation rule
- Sequencing deviation from the plan: S9 was queued in P5, but the P2–P4 protocol edits all cite it, so it lands first. P5 keeps the flags and the docs

### [105] — Regression evals for the cadence engine (v5.2 P1)

- `evals/cases/status-tick-*`: Added — nine cases pinning the heartbeat's observable contract: `quiet` (silent before the interval), `report` (the full five-line block, glyphs included), `drain` (notes banked across silent ticks surface exactly once, then are gone), `minimal` (a report with nothing set renders two lines — the guard against the empty `now:` line fixed during P0), `disabled`, `corrupt` (garbage state degrades to `QUIET` at exit 0), `clamp` (the 2-minute floor and its stderr note), and two `usage` cases for distinct exit-2 paths
- `evals/cases/prop-status-tick`: Added — the writer property run over the state file: idempotency, byte-preservation outside the keys a tick owns, refusal correctness (exit 2 leaves the file untouched), and injection folding (a note carrying `|`, `=` and a newline lands as one clean `EVENT=` line)
- Every case pins the clock through `--now`, so no golden can carry a real date. Suite now 58 cases, 58/58 green in ~3.8 s. Red-tested by perturbing the script (clamp floor, drain, unconditional `now:` line, header label) and confirming each case goes red before restoring

### [104] — The status heartbeat's cadence engine (v5.2 P0)

- `.claude/scripts/script-status-tick.sh`: Added — the sole owner of the "has the status interval elapsed?" arithmetic behind the 5-minute run heartbeat. Three verbs: `--start` opens a phase and resolves the cadence once, `--tick` is the checkpoint call that either prints `QUIET` or fires `REPORT` plus the rendered status block, `--end` closes with a summary and removes the state. Skills call it at checkpoints; no skill ever does elapsed-time math itself
- State lives at `.claude/msg/cache/status/<run-id>.state` as flat `KEY=VALUE` lines (deviation from the plan's JSON — the eval suite's zero-dependency property would otherwise force `jq` or a hand-rolled parser); the path is already gitignored, so no `.gitignore` change. Notes bank across silent ticks and drain into the next report exactly once
- Cadence resolves `MSG_STATUS_INTERVAL` (minutes; `0` disables) over `policies.status_cadence` in `devkit/policy.json` over a 5-minute default, clamped to a 2-minute floor. Observational by construction: a missing or corrupt state file degrades to `QUIET` at exit 0, and the only non-zero exit is `2` for a caller usage error — the heartbeat can never break a run
- `--now <epoch>` injects a fixed clock so eval goldens stay stable

## 2026-07-31

### [103] — Publish the v5.1.0 user-facing release notes

- `RELEASES.md`: Added — the v5.1.0 section covering [95]–[102]: the self-healing eval loop (48-case regression suite as the release gate, one-ledger incident logging, graduation-mints-an-eval contract, writer guarantees) plus the public-docs rewrite and the security-reporting channel

### [102] — Writer property harness + verb gap-fill (v5.1 P2)

- `evals/lib/properties.sh`: Added — three sourced property checks for writer cases (`prop_idempotent`, `prop_preserves`, `prop_refuses`), each emitting a stable token the case's stdout golden pins; violations surface through the case's own exit code, runner untouched
- `evals/cases/`: Added — eight cases: four `prop-*` (doctor-log append-only + injection folding, prd-stamp idempotence/preservation/refusal, intake-stamp idempotence + folded append, aha/openq placement + resolved-rejection) and four verb gap-fills (intake append-row/remove-row/set-cell, deps-mirror idempotence); suite now 48 cases, 48/48 green in ~3.3 s

### [101] — Promote the 25 v5.0.1 fail-silent assertions into regression evals (v5.1 P1)

- `evals/cases/`: Added — 34 cases (`a01`–`a25` families) promoted from the v5.0.1 assertion fixtures, one per shipped loud-exit contract (drift direction always; happy path where it guards distinct behaviour, e.g. `a16` title-anchored scan, `a18` shifted-ledger tally); all hermetic — throwaway `git init` repos, committed `gh` stubs, sandboxed `$HOME`, pinned dates/identities; suite now 40 cases, 40/40 green in ~2.8 s
- Q3 verified: no contract drift since v5.0.1 — every assertion still emits its documented token and exit code; zero fixtures patched, zero assertions dropped

### [100] — Document the self-healing loop and gate releases on it (v5.1 P5)

- `ARCHITECTURE.md`: Changed — new "Self-healing loop" section (detect → log → diagnose → fix → gate, with real paths, deferred-diagnosis and mechanistic-grading principles) and a "Releasing" note: `bash evals/run.sh` before tagging, any FAIL blocks on the exit code
- `README.md`: Changed — FAQ entry "What happens when the harness itself misbehaves?" (conceptual: log, batch-triage, graduate, every fix leaves a permanent pre-release check)

### [99] — Graduation now mints a regression eval (v5.1 P4)

- `.claude/skills/msg/refs/protocol-doctor.md`: Changed — Step 2 and the graduated-issue block gain a required `**Regression eval**:` line (the doctor names the case; still writes no code); the 🟡 fix-session step's definition of done now includes landing that eval red → green; References gains `evals/run.sh`
- `.claude/skills/shared/refs/doctor-logging.md`: Changed — documents the eval runner as a Channel-1 caller (`validator-fail:eval-<case-slug>`, same appender, same exit-3 skip) and the division of labour: eval failures block on the runner's exit code immediately, the 3-occurrence threshold governs live incidents only

### [98] — Close the eval loop into the incident ledger (v5.1 P3)

- `evals/run.sh`: Changed — a FAIL now appends one row to `devkit/DOCTOR.md` via `script-doctor-log.sh` (`--skill evals`, signature `validator-fail:eval-<slug>`, context = cmd + one-line reason); best-effort, absent-ledger skip, diagnosis stays deferred to `/msg --doctor`
- `.gitignore`: Changed — ignore `devkit/` (the harness's own ledger is local telemetry, per template-DOCTOR.md's never-committed contract)

### [97] — Stand up the regression-eval suite (v5.1 P0)

- `evals/run.sh`: Added — the mechanistic eval runner: case = `fixture/` + `cmd` + `expected/{exit,stdout,files/}`, run in a temp copy with `TZ=UTC`, golden-diff grading, `--only <slug>`, exit 0 iff all pass
- `evals/cases/`: Added — six pilot cases covering the doctor appender (append, enum refusal), the doctor tally (triage threshold, unparsed-header refusal) and the intake stamp (status flip, absent-column refusal); all goldens captured from real script runs
- `.gitignore`: Changed — root `evals/` un-ignored (the ignore was for the May-era scratch suite, which moved to `update/[deprecated]/evals-v2/`)

### [96] — Make the repo readable to strangers and to agents

- `README.md`: Changed — figlet header, badges and nav added; the two skill tables rewritten from dense implementation prose into one-or-two-sentence rows split per mode; the run-report, closing-message and safety-floor blocks condensed from 470 to 180 words; new Install-verify, How-to-update, FAQ and Documentation sections
- `SECURITY.md`: Added — private-advisory reporting channel, supported-version stance (fixes land on `main`, no backports), and a scope naming the installer, the script layer, and the git/`gh` write powers
- `llms.txt`: Added — index for agents landing in the repo: docs, the eight skills described by what changing each would change, the shared contracts, and the gitignored paths not to look for
- `.gitignore`: Changed — ignore `AGENTS.md` and `CLAUDE.local.md`, both machine-local `headroom learn` output

### [95] — Keep local dev-tool caches out of version control

- `.gitignore`: Added — ignore `.serena/` and label the Headroom-related ignore entries with a section header

### [94] — Publish the v5.0.1 user-facing release notes

- `RELEASES.md`: Added — the v5.0.1 section, covering the 8-phase hardening build ([86]–[93]): 25 fail-silent assertions + 4 slims (release bookkeeping for the `v5.0.1` GitHub release)
- `CHANGELOG.md`: Changed — entries [88]–[93] moved under their actual date (`## 2026-07-31`)

### [93] — v5.0.1-P7: merge verdict→action prose tighten (S4)

- `merge/refs/staging.md` / `production.md` / `verify-deploy.md`: Changed — 267 words of table-restating prose reclaimed (9,993 → 9,726 across the refs); every one of the 45 verdict→action table rows proven byte-identical to HEAD (empty extract-diff per file), all 27 verdict vocabulary tokens survive, i100 (macOS model declared-never-inferred), i73 (direct-flow test before the merge) and rollback always-ask intact at every call site
- `deploy.md`: Unchanged — it carries no verdict table; a marginal 9-word trim was made and deliberately reverted (byte-identical to HEAD)

### [92] — v5.0.1-P6: eng build protocol slim (S3)

- `eng/refs/build/protocol.md`: Changed — 5,386 → 4,298 words (−20%), its first dedicated slim: script-return narration, design-history asides, double-homed fragments (merge-floor line, per-ticket-review negation, Engineering-authority note) and rule-repeating examples cut; transitions gone
- Nothing mechanical moved: heading + step inventory proven identical (diff = empty, Steps 0–8 + 5a + commit confirm in place), every script call/failure message/sentinel at the same occurrence count as HEAD, fences 14/14; the fix-complexity chain now names `fix-build-orchestrated.md` at its `report=` pointer (single-home citation, +8 words)

### [91] — v5.0.1-P5: pre-merge SKILL.md router slim (S2)

- `pre-merge/SKILL.md`: Changed — 2,595 → 1,758 words (−32%), the persona/router pass its three peer skills got in v5: Posture replaces the persona essay, one Dispatch table, pipeline narrative and test-selection explainer cut to flag semantics + pointers (executor §3c / policy-schema-pre-merge own the detail), safety-floor prose cites the shared ref
- Everything dispatchable survives, grep-proven: all seven flags, the `no_manifest` refusal (pointing at `--init`), the no-human-gate statement, closing-message + doctor-logging bindings; every refs/ pointer resolves; frontmatter untouched; fences balanced

### [90] — v5.0.1-P4: eng review protocol slim (S1)

- `eng/refs/review/protocol.md`: Changed — 1,258 → 699 words (−44%); the seven priority classes go table→numbered list, meta-commentary/worked-examples/double-homed rules cut (no-threshold spawn rule, /cook exclusion and comment-scan mechanics now cited at their homes instead of restated); every operational item preserved and grep-proven (7 classes, verify-before-report, silence-is-an-outcome, blocker/high gate, `source: eng:review` + schema pointer, diff-only + public-contract trigger, digest-exit awareness); all 6 caller citations resolve, fences balanced
- [i2]'s 150–250-word body band formally re-set: the mode's mandated contract content floors at ~420 words — body landed at 515; the honest target is the ≤700 file total, now met

### [89] — v5.0.1-P3: pipeline + structural fail-silent assertions — components can no longer vanish quietly (A19–A25)

- `script-pipeline-resolve.py`: Changed — an unrecognised PLATFORMS row is named (`WARN=unknown-platform`, stderr) instead of silently unscheduled; an existing-but-unreadable PLATFORMS.md is exit 7 (was: read as "ships nothing", skipping the coverage-gap check); a **mandatory** component absent from the manifest now refuses (exit 6, `MANDATORY_ABSENT=<id>`) instead of resolving a plan without a safety-floor step (A19/A20); the no-diff fail-open stays untouched
- `script-em-exec-collision.py` + `script-cert-mech.py`: Changed — a Files-less exec table is a distinct exit 3 `ERROR=no-files-column` (both modes) instead of a discarded stderr warning + "no collisions"; cert-mech renders it as `SKIP … reason=no-files-column` plus a major finding so the gate stays at least as loud as before (A21)
- `script-eng-plan-shape.py`: Changed — exec-column drift and short rows are named root causes (`exec-columns-unresolved` listing headers seen, `short-exec-row`) instead of cascading into misleading unpointed-ticket noise (A22)
- `script-cert-mech.py` + `script-ci-status.py`: Changed — falling back to the global `~/.claude` copy prints `RESOLVED_VIA=global <path>` (stderr; repo-copy runs stay silent); ci-status resolves its repo-local candidate against `--repo`, not the process cwd — proven: a stale global reader flipped a verdict in the fixture (A23)
- `script-platforms-parse.py`: Changed — >1 platform-header tables ⇒ `WARN=multiple-platform-tables lines=…` (rows above the last header were silently invisible); Q3 verified: last-header-wins is a real accommodation (the template's Column-contract pseudo-header), comment rewritten to say what it actually protects (A24)
- `script-em-branch-resolve.sh`: Changed — `MAIN_BEHIND_REMOTE=true` emitted when origin's prod branch is strictly ahead of local, flagging the stale-local double-merge verdict before it bites (A25)
- Caller docs: executor.md exits 6/7; plan-em collision/decomposition exits 3

### [88] — v5.0.1-P2: parser fail-silent assertions — digests, scans, tallies name their misses (A14–A18)

- `script-prd-digest.py`: Changed — a §3 row digesting with an empty id ⇒ exit 2 `FEATURE_ID_EMPTY=<row>` in every mode (stdout/slice/cache — no poisoned cache left behind); a `--feature` filter that empties a non-empty set ⇒ exit 2 `FEATURE_NOT_RESOLVED=<fid>` naming the ids actually seen (A14/A15); all four real PRDs digest byte-identically
- `script-prd-scan.sh`: Changed — fullness anchors on section titles, not hardcoded §-numbers; decorated ids (`**F1**`) count; "written but unparsed" now distinct from "never written" (`acceptance-criteria-unparsed`/`exec-table-unparsed`); branch names resolve via script-policy-read.py with a loud grep fallback (A16/A17). Bonus fix: the old grep block could abort the whole scan under `set -e` on an ungreppable policy.json — every PRD line silently vanished, exit 1
- `script-doctor-tally.sh`: Changed — Incidents columns resolved from the header by name (a shifted column no longer tallies zero rows / misreads status); body rows present but none parsed ⇒ exit 2 `LEDGER_ROWS_UNPARSED=<n>`; empty and header-less ledgers keep today's behaviour (A18)
- Caller docs: eng build/review protocols + protocol-doctor now say what the new non-zero exits mean (stop and surface — never guess)

## 2026-07-30

### [87] — v5.0.1-P1: Tier 2 fail-silent assertions — writers and ledgers refuse to corrupt (A8–A13)

- `script-em-exec-skeleton.py`: Changed — `--write` refuses (exit 1 `REFUSING_OVERWRITE=<n>`, or `=unresolved-columns` on an unreadable header) instead of wiping a populated exec table; new `--force` overrides; writes now go temp-file + os.replace so a crash can never truncate the PRD (A8/A8b)
- `script-prd-number`: Changed — a lane-agnostic sweep after the four-lane max catches parked PRD folders; a colliding id ⇒ exit 2 `NUMBER_COLLISION=<id>` instead of handing out a duplicate number (A9)
- `script-ledger.py`: Changed — rows present but no parsable `#` ⇒ exit 2 `LEDGER_NUMBERING_UNPARSABLE=<cell>` instead of renumbering from 1 alongside them (A10); a drifted findings heading ⇒ exit 2 `SECTION_TITLE_DRIFT=<heading>` instead of appending a duplicate section; EOF-fallback creation now says so (`LEDGER_PLACEMENT=eof-fallback`) (A11)
- `script-intake-stamp.sh`: Changed — `stamp` and `append-row` refuse (exit 2 `COLUMN_ABSENT=<name>`) when a supplied value's column is missing from the header, instead of silently dropping it; well-formed writes proven byte-identical; GUI intake render verified per [i104] (A12)
- `script-prd-deps-mirror.sh`: Changed — an unmatched §3 heading ⇒ exit 2 `SECTION_NOT_FOUND=features` (and the heading match now tolerates "and"/"&"); a table that mentions dependencies but resolves no such column ⇒ exit 2 `DEPS_COLUMN_UNRESOLVED`; decorated headers like "Dependencies (PRD ids)" now resolve (A13)

### [86] — v5.0.1-P0: Tier 1 fail-silent assertions — safety gates can no longer open quietly (A1–A7)

- `script-cert-status.sh`: Changed — §7 ledger header drift now exits 2 `LEDGER_HEADER_UNRESOLVED=…` instead of reporting CERTIFIED past an open Critical (A1)
- `script-branch-protection.sh`: Changed — verify requires ≥1 required status context (`UNPROTECTED <b> no-required-contexts` on `contexts:[]`); the prod branch (branch list + required-reviews clause) resolves from policy via script-policy-read.py, default `main` — no longer the literal string (A2)
- `script-signoff-coverage.sh`: Changed — a failed `--fetch` exits 2 `FETCH_FAILED=<ref>` instead of grading against a possibly-stale ref (A3)
- `script-release-identity.sh`: Changed — v* tags exist but none reachable from prod ⇒ exit 3 `NO_REACHABLE_TAG=…` instead of proposing v0.1.0 over a live release; `PROD_REF_SOURCE=remote|local-fallback` joins the key set (A4)
- `script-tier-resolve.sh`: Changed — an undiffable base ref now degrades to tier L per AC-TS10 (was: read as an empty diff ⇒ tier S, inverting fail-large); genuinely-empty diffs unchanged (A5)
- `script-cert-mech.py`: Changed — check 6 prints `SKIP … reason=no-prds-matched-glob` when the PRD glob matches nothing (was silent); check 4 emits a critical `features-id-column-unresolved` finding naming the headers seen instead of passing vacuously with zero F-IDs (A6/A7)
- Every assertion fixture-proven both ways (fires on seeded drift, happy path byte-compatible); designed fail-opens untouched

### [85] — README + QUICKSTART point at the release history

- `README.md`: Added — a current-release line (v5.0.0) linking `RELEASES.md` under the install section
- `QUICKSTART.md`: Changed — the closing Next line gains the `RELEASES.md` link alongside README/ARCHITECTURE

### [84] — Retire the last tracked improve/ plan docs

- `.claude/skills/improve/_INDEX.md`, `plan-msg-v2.md`: Removed — improve/ plans are local scratch docs, not shipped skill surface; these two were the last tracked remnants (their siblings were already untracked)

### [83] — Publish the v5.0.0 user-facing release notes

- `RELEASES.md`: Added — the v5.0.0 section, covering the 18-phase v5 build ([65]–[82]) and [64]'s release-history repair (release bookkeeping for the `v5.0.0` GitHub release)
- `CHANGELOG.md`: Changed — the "Unreleased — v5.0.0" section retitled to its release date, its 18 phase entries numbered [65]–[82] per convention

### [82] — v5-P17: the rename commit (i1/i12/i101/Q5)

- Renamed — `plan-tune` → **`plan-review`** (rename only, both modes stay; 91 citations, 38 files) and `post-merge` → **`merge`** (468 citations, 58 files; the old name is retired and reserved); `policy-schema-post-merge.md` → `policy-schema-merge.md`
- Renamed — **37 scripts** to `script-<slug>` (slug carries no skill prefix so future renames never cascade); one sanctioned exception: `changelog-gate.py` (hook-config-pinned, session snapshot cannot reload — documented in ARCHITECTURE); latent glob collision dodged (`preflight-common` → `script-check-common`, outside the `script-preflight-*` ingestion glob)
- Wire tolerance — `"post-merge": "merge"` joins the P7 legacy map; the report envelope's `skill` field now normalizes too (`normalize_skill()`, same imported map); PRD §7 heading → "Plan review findings" with legacy tolerance in all four readers (nothing on disk rewritten); GUI proven rendering a legacy report end-to-end
- Registry — row keys renamed; dead `--roadmap` label gone; plan-em row split plan-wave/build-wave (i83: the old 🟢 step was wrong for both)
- Docs — README/ARCHITECTURE/QUICKSTART fully scrubbed: roadmap-orchestrator remnants dead, 4 wrong §-refs fixed, scripts table → six grouped tables (~58 scripts), eng --review + DOCTOR + ENV.md + lighter manifest documented; pre-existing working-tree doc changes reviewed and absorbed
- `install.sh` — removes retired skill dirs + 21 stale script names on install (the shadow trap); DOCTOR gitignore top-up gap closed (ROW_GAPS + Step 3b row)

### [81] — v5-P16: the calm pass: no unconditional step counters (i80)

- Removed — every unconditional `Step X/N` progress-emission mandate across 10 files/12 sites (plan-pm, plan-em, plan-tune, msg ×3 protocols, intake ×3 protocols + lead-ins); generalises i26/i41 repo-wide
- Kept — three event-driven markers in plan-em's team protocol (agent completions, orchestrator returns): output when something real happens, not per-step ceremony
- eng/pre-merge/post-merge verified mandate-free already (their Step N/M strings are document structure, not output instructions)

### [80] — v5-P15: post-merge mechanisation: five fixed-result scripts (i94–i98)

- `.claude/scripts/`: Added — `script-ci-status.py` (five-way CI verdict + failing names + PR resolution rider, exit-coded), `script-platforms-parse.py` (17-column PLATFORMS table → per-platform key=value; macOS must DECLARE release_model per i100, malformed rows loud), `script-smoke-run.sh` (one-shot/poll/watch loops, bounded ceilings, config-gated macOS notarization/signing/appcast; never asks/rolls back/writes), `script-policy-read.py` (all ?? defaults in one call against the split schema; fail-safe full-default emission on absent/malformed), `script-ts-miss.py` (CI-backstop half only; `HUMAN_HALF=model` standing marker; 30-day window count)
- `stamp-intake.sh`: Changed — read-only `--find-row --prd` verb reusing the existing parser (existing verbs regression-tested)
- Call sites rewired across SKILL/staging/production/deploy/verify-deploy; Step-10 lane move now resolves across all lanes (glob was hardcoded wip/ while claiming otherwise)
- Shared-ref pickups: policy-schema.md:211 now agrees with i73 (ask BEFORE the merge); policy-schema-post-merge.md deploy typing softened per i100
- Honest ledger: protocols +552 words net — verdict→action contract tables and three pieces of owed content (glob fix, i100 rule ×3, scripts inventory); prose parses and loop mechanics are gone

### [79] — v5-P14: post-merge content: three release scripts, router −44%, gate moved pre-merge-side (i54–i61/i73/i99/i100)

- `.claude/scripts/`: Added — `script-signoff-coverage.sh` (ancestry + newest-stamp + uncovered-commit verdicts), `script-release-lock.sh` (acquire/release/status on the transient tag; ~1,100 words of lock spec retired), `script-release-identity.sh` (read-only tag parse/bump/build/monotonicity/regression/provenance); `stamp-prd.sh` gains `staging-signoff` (+ insert-when-absent); both stamp sites call it — no improvised frontmatter edits remain
- `post-merge/SKILL.md`: Changed — pure router, 4,769 → 2,662 words (−44%); Persona → 3-line Posture; sanctioned-writes bridge keeps the floor's citation landing
- Citation strip: 316 decision-ID tokens → 0 across 12 files (fence balance proven per file); submitted-not-live single-homed; resolver boilerplate 4→1; output-schema essays cut (−29%)
- Direct-flow human test: Changed — moved BEFORE the merge (after Step-3 double-confirm, before lock + release PR); Cancel leaves main untouched and holds no lock; matches the floor's Direct-flow bullet (i73)
- Rollback offers for server platforms carry the redeploy-≠-un-migrate caveat (i99); submission.md re-scoped store-agnostic with a MAS row + platform→console table; macOS release-model is declared, never inferred from identity (i100)
- post-merge total 27,170 → 21,795 words (−20%)

### [78] — v5-P13: the preview-gate cut (i93) — v5's one safety-floor amendment, isolated commit

- Removed — the preview component end-to-end: `protocol-preview.md` (212 ln incl. R1–R4, park/resume, the commit-bound approval token — machinery that existed only there), `preflight-check-16-preview.sh`, catalog row 16 (tombstoned, never reused), executor wave/prune/promote wiring, output-schema preview object, PLATFORMS `preview_kind`/`preview_deploy_cmd` columns (19→17; three readers fixed)
- `shared/refs/safety-floor.md`: Changed — "Preview-deploy approval" leaves **Human gates — never removed**; replaced by relocation notes: staging sign-off is THE human look in staged flow, the direct-flow pre-merge attestation ([i73]) is its equivalent; C3's three cleanups landed in the same edit (C9 cites, post-merge row → pointer, doubled secret-scan line)
- smoke: survives re-anchored — depends_on preview→sync, env wave scheduled FIRST (cost `cheap` makes the tie-break mechanical), short-circuit now protects the expensive env-wave checks; api/migration live checks run in the env wave they were always bound for
- manual-test-plan generation survives; sole render site = post-merge --staging's human-test script; pre-merge now explicitly holds no human gate
- Proofs: zero preview references in pre-merge+scripts; resolver parses the 16-row catalog, smoke lands first in the env wave; verdict script unaffected

### [77] — v5-P12: pre-merge protocols: registry subtraction, enrichment cut, single-home, prd-consistency advisory (i65–i67/i69–i71/i74)

- Removed — the dangling D29 flow registry: a11y/perf/smoke/preview each state their real fallback as the behaviour; protocol-e2e.md promises only what it defines; catalog's four enrichment sentences reconciled
- Removed — the enrichment layer's mechanism prose (perf/api ratchets → degrade lines with named skip reasons; consumer-naming → Pact-or-declared-else-endpoint; traffic_mix → runner default; hot_tables/size-aware lock severity → flat default); coverage's ratchet KEPT (it works)
- Single-homed — fail-fast table (severity-rubric, contradiction fixed: critical class = {mechanical, security, migration} everywhere incl. protocol-unit), selection rule (executor §3c), minified boilerplate, refusal + staleness + untagged-test rules; 244 AC-id archaeology citations → 0; pre-v3 "Gate Step" dialect → 0
- `_common.md`: Changed — hollow-green closed: an erroring component whose surface the diff touches grades a medium `component-errored` finding; repeats surface via --prior-issues (i69)
- `--init`: Changed — nine upfront interview blocks → two (env provisioner → ENV.md, CI gap); the rest seeded-not-asked with ask-on-first-activation via --update (i70)
- Grading: a11y minor/best-practice → low; commit-cap audit scoped to commits since the last gated sha (i71)
- prd-consistency + manual-test-plan: blocking → **advisory** (LLM grade = evidence of attempt, incl. out-of-scope), `active_when: prd` auto-discovers features/prd-<N>-*/ from the branch with --prd as override; grades → manual-test-plan wiring intact, render site = post-merge's staging walk-through (i74)

### [76] — v5-P11: pre-merge structure: lighter manifest, pipeline resolver, schema split, ENV.md (i62/i63/i64/i68/i72/i82)

- `components[]` manifest: Changed — entries shrink ~15 fields → 6 (+ user overrides only); catalog constants resolve at run time from component-catalog.md; `test_selector` + `source` dropped; the AC-UP2 drift hole closes by construction (catalog edits are live next run, no migration)
- `shared/refs/policy-schema.md`: Split — core (243 ln, both gates) + `policy-schema-pre-merge.md` (272) + `policy-schema-post-merge.md` (212); a gate run loads 515 ln instead of 693 and none of the other gate's; §-numbers stable; "scripts can't date" premise fixed at all four sites
- `.claude/scripts/script-pipeline-resolve.py`: Added — policy+catalog+flags+diff → plan JSON (prune with reasons, C12 gap findings, topo waves, only-on-green from the catalog marker); `--check-complete` exits 5 with MISSING= lines; fails open without a diff
- `.claude/scripts/pre-merge-aggregate-verdict.sh`: Rewritten — v3 result reports replace the pre-v3 BUCKETS (qa/functional gone); dedup by (category,file,line,rule), §2/§4 path downgrades with exemptions, verdict math, abort signal, gap ingestion; merged `source` joined by comma (GUI wire contract — caught by the i104 grep)
- `devkit/ENV.md` (i82): Added — `shared/refs/env-contract.md` + `template-ENV.md` (init-scaffolded, committed not gitignored) + executor §3b read + `--init` detect/scaffold + `--update` reconcile; `env_provision` OUT of policy.json (zero live refs); absent/placeholder → the same loud sandbox-unprovisioned degrade; compose + seed stubs join refs/stubs/
- v3 residue reaped: Q2 migration table, steps.* dual-write prose, retired-qa tombstones, unit_int, stale P1 banner
- GUI verified: only policy read is release_branches(); build_data green on the new-shape manifest

### [75] — v5-P10: plan-em: resume rules, strips, closing message, roster intent (i76–i79/i81/i83/i92)

- `refs/protocol-em.md`: Changed — Step 3 resume rules (exec table present → verify-never-reappend, duplicate/orphan rows = hard stop; roster matching engineering_agents → one-line confirm, per-PRD not per-wave; 3a /cook payloads still run — build wave needs them); roster gate opens with a 2–3 line PRD-intent summary (suppressed on resume)
- Removed — `refs/principles.md` (665 words); the two house rules ("one innovation token per plan, max" · "extract on the third occurrence") relocated into Step 4 + the team input contract so they bind subagents
- `SKILL.md`: Changed — router (synopsis, Step-0 restatement, References re-documentation gone); Persona → the one non-inferable rule under Outputs; 1,332 → 850 words
- Step 5's next-steps AskUserQuestion menu → the shared closing message (registry row verbatim)
- DOCTOR bindings: the standard sentence + five signature-explicit call sites + protocol-team's respawn logs retry/tool-error rows

### [74] — v5-P9: DOCTOR: the harness-incident ledger + /msg --doctor (i50/i51)

- `msg/refs/init/templates/template-DOCTOR.md`: Added — devkit/DOCTOR.md scaffold (AHA=learned · OPEN-QUESTIONS=undecided · DOCTOR=harness misbehaved); class enum write-miss/retry/tool-error/validator-fail/gate-infra; Incidents table last-in-file so appends are true appends; gitignored, scaffolded by /msg --init + top-up
- `.claude/scripts/script-doctor-log.sh`: Added — validated-enum appender (exit 3 = absent = skip silently; pipes/newlines folded, never dropped)
- `.claude/scripts/script-doctor-tally.sh`: Added — groups by skill+signature, threshold 3-ever, re-flags recurrence after graduation
- `shared/refs/doctor-logging.md`: Added — both channels once (mechanical: undocumented non-zero exits; model: tool error/retry/missed write); designed exit-3 skips carved out; one binding sentence in 7 SKILL.md files (plan-em deferred to P10 per i81)
- `msg/refs/protocol-doctor.md`: Added — /msg --doctor tallies, diagnoses, graduates on the ledger, triage-reports; hard boundary: NEVER fixes, never edits harness files; registry row added

### [73] — v5-P8: msg: policy writer, branch topology, router collapse (i36/i37/i39/i40)

- `.claude/scripts/script-policy-set.py`: Added — the one surgical devkit/policy.json writer (dotted-path set, parent creation, sibling preservation verified in-script, seed-on-absent, --skip-if-exists, --stamp-by dating the file — the "scripts can't date" premise retired); all four msg write sites rewired, ~400 words of be-careful prose gone
- `.claude/scripts/script-branch-topology.sh`: Added — read-only topology resolver (prod branch main→master→current, staging, remotes, gh); four inline git-detection blocks replaced; zero inline show-ref/rev-parse remain in msg
- `msg/SKILL.md`: Changed — pure router (one Dispatch table; inline --init-staging protocol → new `refs/protocol-init-staging.md`); 2,631 → 1,464 words (−44%)
- `--help` table: Removed — 3 unreachable rows (intake --update/--delete rows, the dead roadmap row) + fixed the shadowed rough-idea rows the audit pass surfaced
- `protocol-gui.md`: Changed — projection pointers → script-project-findings.py; Roadmap view no longer claims plan-pm --roadmap authorship

### [72] — v5-P7: eng --review born, per-ticket pair review deleted (i2/i11)

- `eng/refs/review/protocol.md`: Added — whole-change adversarial review by a spawned reviewer subagent: seven priority classes, verify-before-report, diff-only context with the public-contract trigger, silence-is-an-outcome; findings per shared finding-schema with `source: eng:review`; only blocker/high gate the commit confirm; the merge floor stays pre-merge's green run
- `eng/refs/build/protocol.md`: Changed — new Step 5a spawns the reviewer by default on every build with a diff (after the full-suite gate, before the human commit confirm); Step 4e per-ticket review deleted; A4 "enforced twice" → enforced once mechanically + judged at 5a
- Removed — `eng/refs/build/pair-review.md` (406 words); zero live citations remain
- `shared/refs/finding-schema.md`: Changed — `source` enum `pair-review` → `eng:review` + new Legacy wire values section (never-reject rule); the one legacy map lives in `script-project-findings.py` (`LEGACY_SOURCE`), inherited by the GUI via the module import — P17 adds `post-merge`→`merge` as one line; dedup/regression keys verified source-free
- GUI proven rendering both `eng:review` and legacy `pair-review` reports; on-disk files never rewritten

### [71] — v5-P6: eng mechanisation: five scripts (i42/i43/i44/i45/i46)

- `.claude/scripts/script-eng-plan-shape.py`: Added — 7-check fail-loud plan validator (headings, ticket schema, F-ID↔exec alignment both ways, depends-on acyclic, sentinel, pointer resolution, files-vs-reality); wired as eng --plan's closing check
- `.claude/scripts/script-eng-fix-grade.py`: Added — the [i31] rubric executable (fixed-order predicate; fast=sonnet/deep=opus); model may only escalate simple→complex, stated at the script + both call sites
- `.claude/scripts/script-project-findings.py`: Added — the single finding→issue-ticket projection + issues-file validator; `server.py` loads it as a module (26-line duplicate deleted; degrade = explicit skipped entry); board output proven byte-identical before/after
- `.claude/scripts/script-eng-close-loop.py`: Added — the one sanctioned followUp.status write; splices into original bytes, asserts outside-span byte-identity + masked-document equality before os.replace; idempotent
- `.claude/scripts/eng-commit-cap.sh`: Changed — `--message/--message-file` pair the Oversize-reason trailer with an over-cap diff (exit 3 when missing); under-cap never blocked, advisory posture unchanged

### [70] — v5-P5: eng content: roadmap orchestrator removed, tickets-final, fix-* renames (i29/i30/i31/i33/i34/i47/i48/i49)

- Renamed — report-fix.md ×3 → `fix-plan.md` / `fix-build.md` / `fix-build-orchestrated.md`; 39 citations across 9 files; `.gitignore` gains a scoped negation so fix-plan.md isn't eaten by the scratch-plan rule
- Removed — `eng/refs/build/protocol-roadmap.md` (166 ln): roadmap orchestration no longer exists anywhere; its Subagent contract moved into fix-build-orchestrated.md (its one real citer); protocol-team.md now cites its own contract; msg --help's orchestrator row deleted (hand-authored roadmap + GUI tab stay)
- `eng --build`: Changed — todo tickets are the only and final spec (exec-table steps → `→ F2-T1, F2-T2` pointers; fallback path → hard failure); brevity mandate at work-step 4c; AHA/OPEN-QUESTIONS prose → script-aha.sh/script-openq.sh calls; fix-complexity rubric single-homed in fix-build-orchestrated (fast/deep tier naming)
- `eng --plan`: Changed — template gates relaxed ("as many as are real"); §10 Branching-and-CI deleted (§11–13 → §10–12); short-form template deliberately skipped
- `scan-prd-digest.py`: Added — `--verify-rows/--agent` ownership check (ROWS_OK / per-row hard failures); todos join the build slice
- eng total 19,291 → 16,366 words (−15%)

### [69] — v5-P4: the PRD template sweep (i15/i18/i21/i22/i23/i75)

- `plan-pm/refs/template-prd.md`: Changed — 11 sections → 8 in four categories (Intent/Contract/Unresolved/Reserved): User flow, Key user interactions, Glossary deleted; Features §3, Error cases §4 (absorbs template-error.md), Open questions §5, exec table §6, tune ledger §7, Todos §8; template-feature-table.md + template-error.md deleted (folded)
- Cross-skill §-reference sweep: 14 skill files + 7 scripts renumbered; proving grep zero stale references under .claude/
- Fixed — three latent parser bugs the renumber exposed: scan-prd-digest.py + script-cert-mech.py exec-table-vs-features `startswith("feature")` misparse; plan-pm-roadmap-scan.sh exec-table fullness signal could never fire (`| F1 |` vs `| F1: |` + unnumbered heading); script-ledger.py anchored inserts on the deleted Glossary
- `.claude/scripts/script-prd-shape.py`: Added — 5-check PRD shape validator (sections/order, acceptance table, F-ID contiguity, reserved-placeholder integrity, frontmatter), wired as protocol-pm Step 3 Part 5 gate; 11 seeded defects each fail with a distinct code
- `plan-em`: Changed — exec table's one home is §6 (skeleton script gains `--write`, targets the reserved section); protocol-em.md collision-checker awk now matches numbered + legacy headings; dangling `refs/protocol-exec.md` pointers fixed to eng's real path
- GUI verified: parse_features + build_data + scan-prd-digest identical output on new-shape and legacy fixtures

### [68] — v5-P3: plan-pm content: --roadmap removed, principles/persona folded, intake-only entry (i16/i17/i19/i20/i27/i28)

- Removed — `plan-pm --roadmap` (refs/protocol-roadmap.md + plan-pm-roadmap-sequence.py, zero live callers); `roadmap/roadmap.md` is hand-authored now, its format skeleton rescued into new `TEMPLATE-roadmap.md` scaffolded by /msg --init; `plan-pm-roadmap-scan.sh` survives (Step 2 + plan-em consumers)
- Removed — `plan-pm/refs/principles.md`; 5 stable rules relocated (F-ID stability + §6 purity + acceptance-criterion → template-prd.md; one-problem-one-PRD + only-what-was-asked → protocol-pm Step 3)
- `plan-pm/SKILL.md`: Changed — router collapse (step synopsis + --sub delta → pointers), Persona → relocated autonomy rule + [USER:…] convention, closing-message rows per the shared contract; 1,584 → 1,171 words; plan-pm total −32%
- `plan-pm/refs/protocol-pm.md`: Changed — Step 1 "Resolve the intake row": prose invocations auto-capture via Skill("intake"), no bounce question; Step 5 recommends /plan-em (registry drift fixed); protocol-sub.md D2 rewritten to the mandatory marked-row rule

### [67] — v5-P2: intake: deterministic row writer + single-homed rules (i102/i103)

- `.claude/scripts/stamp-intake.sh`: Changed — four new verbs beside the untouched stamp path: `--append-row` (dup-# refused), `--set-cell` (old value on stdout for the diff echo; `#`/`date`/`status`/`prd` refused), `--remove-row` (never renumbers), `--log-append` (lazy-creates `INTAKE-UPDATE.md` with the canonical header, `modify|add|remove` only); exit codes extended 0/1/2 → +3 refused / +4 dup / +5 write-fail; shared awk parser, env-passed values, escaped-pipe safe
- `.claude/skills/intake/refs/*.md`: Changed — the three protocols' write steps call the writer (byte-for-byte-preservation promises → script guarantees); INTAKE-UPDATE format single-homed in `protocol-update.md` § The update log; ≥8-gate split why→rubric / mechanics→protocol-intake; "Two edit surfaces" retitled "Three edit surfaces"

### [66] — v5-P1: plan-tune slim + mechanise (i4–i10)

- `.claude/skills/plan-tune/SKILL.md`: Changed — Persona → 2-line Posture (non-inferable rules relocated), Step-3 re-verification checklist cut, no-op instructions cut, certification.md restatements → pointers, D*/G* plan-history citations stripped, glossary Minor + Step-1 GLOSSARY read cut; §9-ledger and cert-check prose replaced by script calls. 2,946 → 2,239 words (−24%)
- `.claude/scripts/`: Added — `script-cert-mech.py` (mechanical checks 4/5/6: scope map, tickets, edges/buckets; 9 finding codes, exit 0/1/2), `script-ledger.py` (§9 locate/create/fill, carry-forward dedup, severity-sorted monotonic numbering, Clean row), `script-aha.sh` + `script-openq.sh` (file-owned devkit appenders; openq never touches `## Resolved`, rejects `--status resolved`)
- `.claude/skills/plan-tune/refs/certification.md`: Changed — gains the "who runs what" split (scripts own 4/5/6-structure; model keeps 1/2/3/7 + fixes + product pause); citation strip applied

### [65] — v5-P0: Quick wins (one commit per phase; queue: update/plan-msg-v5.md §4) (i13/i14/i35/i38/i52/i53)

- `.claude/skills/plan-pm/SKILL.md`: Changed — `allowed_tools` gains `Edit`, `WebFetch`, `WebSearch`; `refs/principles.md`'s web rule is now executable and scoped to convention lookups
- `.claude/skills/msg/SKILL.md`: Changed — `allowed_tools` gains `Edit`; `--update` precondition corrected to key on `devkit/` (`INITIALISED`), not `policy.json` (also in `refs/protocol-update.md`, where a missing `policy.json` is now explicitly a top-up case, not a refusal)
- 8 files: Removed — every mention of the expired `--doctor` one-release alias for the gates' `--init` (msg, pre-merge, post-merge, `shared/refs/policy-schema.md`); the name is now free
- `features/` is gitignored: Added to `template-gitignore.md` + `protocol-init.md` docs; new `--update` Step 3-FT offers `git rm -r --cached features/` (stage-only, confirmed) for legacy tracked repos; lane moves now branch tracked→`git mv` / untracked→`mv` (`plan-em-branch-resolve.sh`, post-merge refs, `init.sh` comments)

## 2026-07-26

### [60] — The gate can now run only the tests your diff can break (contract core)

- `.claude/skills/shared/refs/policy-schema.md`: Changed — new `policies.test_selection` field spec (`enabled`, `reason`, `full_run_backstop`, `force_full_paths`, `tiers.*`, `max_affected_ratio`, `critical_markers`) plus a §2c read-contract (`ts = policies.test_selection.enabled ?? false` — opt-IN, deliberately inverting `github_actions`' absent ⇒ true default; `--full` > `--minified` > policy); adds the additive `components[].run_minified` field and the `criticality_review` review stamp
- `.claude/skills/shared/refs/component-catalog.md`: Changed — `run_minified` joins the entry schema, `unit`/`integration`/`regression` are marked selection-capable (`ˢᵉˡ`), and the catalog gains per-platform `force_full_paths` and `critical_markers` defaults plus a pointer to `regression`'s born-tagged special contract
- `.claude/skills/pre-merge/refs/executor.md`: Changed — new §3c "Test selection": the 5-step selection rule (force-full → no selector → unresolvable → tier L → minified), the deterministic S/M/L size-tier rubric, per-component contracts, and the tier/trigger recording requirement; §4 result reports gains its heading
- `.claude/skills/pre-merge/refs/output-schema.md`: Changed — additive `test_selection` verdict block (`{mode, tier, signals, per_check}`), emitted only when selection actually ran

Absent policy key ⇒ byte-identical gate behaviour, no migration; the mandatory floor (`mechanical`/`security`/`migration`) and this PRD's newly authored regression tests are never selected away, and every resolution failure fails open to the full suite.

### [61] — Test selection lands per-platform: enabling interview, run_minified detection, and post-merge's miss-detection safety net

- `.claude/skills/pre-merge/refs/protocol-init.md`: Changed — the `policies.test_selection` **enabling interview** (only when a test suite is detected): explains the trade, verifies the declared `full_run_backstop` actually exists (`ci` → a gate workflow present + `github_actions.enabled` ≠ `false`; `post-merge` → `release_flow.mode == "staged"`) or requires an explicit enable-anyway override + `reason` (AC-TS8), runs the initial criticality-tagging pass so the critical floor is non-empty from day one, then writes the key — a settled decision `--update` never re-prompts unasked
- `.claude/scripts/preflight-check-02-unit.sh`, `preflight-check-03-integration.sh`, `preflight-check-04-regression.sh` (regression/unit/integration detect layer): Changed — resolve the additive `run_minified` invocation alongside the unchanged `run` (runner-native affected-test selection or code-graph fallback; unresolvable → `run_minified: null`, silent full-suite fallback per AC-TS4)
- `.claude/scripts/pre-merge-tier-resolve.sh`: Added — deterministic S/M/L size-tier resolver: computes `modules`/`ratio`/`fan_in_pct` from the diff + code graph against `policies.test_selection.tiers`/`max_affected_ratio`, resolves the largest tier any signal lands in (conflicts always widen, AC-TS10/TS11), and emits the `tier`/`signals` pair the executor records verbatim
- `.claude/skills/pre-merge/refs/executor.md`: Changed — §3c wires the tier resolver + `run_minified` detection into the 5-step selection rule end to end (was contract-only prose in [60])
- `.claude/skills/pre-merge/refs/protocol-unit.md`, `protocol-integration.md`, `protocol-regression.md`, `protocol-coverage.md`: Changed — each selection-capable component's own contract under `policies.test_selection`: `unit`/`integration` apply the tier rule directly, `regression` special-cases its accumulated-suite-vs-newly-authored split (new PRD tests always run in full), and `coverage` computes its delta only over the diff's files when its upstream ran minified
- `.claude/skills/pre-merge/SKILL.md`: Changed — new `--update-criticality` mode: inventories untagged tests against the `criticality_review` stamp, proposes critical/not-critical with cited evidence (PRD traceability, failure history, graph position), gates via `AskUserQuestion` (approve all / edit / skip), writes approved markers as one reviewed commit, and restamps `criticality_review`; never re-grades a human-set tag (AC-TS7); a read-only staleness nudge (default threshold 25 untagged tests) prints on minified runs without writing anything
- `.claude/skills/msg/refs/protocol-update.md`: Changed — new Step 3-TS: `policies.test_selection` is the second key `/msg --update` writes; "turn it on" hands off entirely to `pre-merge --init`/`--update`'s enabling interview above (writes nothing here), "turn it off" is the complete single-run disable (AC-TS12) ending in the retained-inert audit line
- `.claude/skills/msg/SKILL.md`: Changed — `--update` invoke line names the test-selection disable switch alongside the GitHub Actions decision
- `.claude/skills/post-merge/refs/staging.md`: Changed — new test-selection-miss detection: attributes a `ci`-backstop `red_ci` failure or a `post-merge`-backstop "Not yet" staging sign-off to a test pre-merge's minified verdict selected away (reading its committed `test_selection.per_check`), records a `high` `test-selection-miss` finding naming the test + exclusion reason (`not-affected`/`not-tagged`/`tier`), and escalates two misses inside a 30-day rolling window into a `--update-criticality`/`--update`-disable recommendation naming the escapee's file as a `force_full_paths` candidate
- `.claude/skills/post-merge/refs/output-schema.md`: Changed — additive `test-selection-miss` finding shape (`category` mirrors the owning component when the closed vocabulary has a slot, else `other`; `rule: "test-selection-miss"`), additive to whatever refusal/finding already covers the backstop failure, never a substitute
- `README.md`, `ARCHITECTURE.md`: Changed — document opt-in minified test selection where pre-merge is described: the affected ∪ critical floor, the S/M/L tier rubric, fail-open, the full-suite backstop, `--minified`/`--full` overrides, and `--update-criticality`
- `RELEASES.md`: Added — v4.0.0 section

Enabling always verifies a real backstop or requires an explicit override; disabling is always one run with every artifact left inert-by-design; a selected-away test breaking at the backstop is always attributed, never silent.

### [62] — Close the cross-wave gaps in test selection: the miss trail is durable, the tier trigger is honest

- `.claude/skills/shared/refs/report-schema.md`: Changed — defines the run report's additive `test_selection` block: the paired `report-prd-<N>-<K>.json` carries the verdict JSON's `{mode, tier, signals, per_check}` object verbatim when (and only when) selection ran, plus a one-line `selected/total` + tier mention in `## Test results`. This is the **durable** source post-merge's miss detection reads — the verdict JSON is stdout and doesn't survive the run
- `.claude/skills/pre-merge/refs/executor.md`, `.claude/skills/pre-merge/SKILL.md`: Changed — §5's aggregate/emit path now states the `test_selection` block is copied into the committed universal report (not stdout only), and §3c.1 names `pre-merge-tier-resolve.sh` as the script that resolves the tier rather than leaving it to judgment
- `.claude/scripts/pre-merge-tier-resolve.sh`: Fixed — the tier-M `trigger` string asserted bounds that had actually held (reporting `fan_in_pct >= 0.90` when fan-in was 0.2 and it was `modules` that failed the S bound); it now names the S bound(s) that genuinely failed. The trigger is the audit trail a selection miss is attributed to (AC-TS10), so it must never assert a bound that held. Tier resolution itself was and stays correct
- `.claude/skills/post-merge/refs/staging.md`: Fixed — the "component ran full" test had `fallback_reason` polarity inverted (a component with no `fallback_reason` is exactly the one that ran **minified**); the detection contract now spells the polarity out and points at the committed report as its source
- `.claude/skills/post-merge/refs/output-schema.md`: Changed — documents `category: "other"` for a `regression`-component `test-selection-miss` as a deliberate convention: the shared category enum is closed with no `regression` member, so the owning component rides in `rule` + `evidence.snippet` instead of extending an enum every consumer switches on
- `.claude/skills/shared/refs/check-report-schema.md`: Changed — the detect section documents the `run_minified` / `test_selector` fields `mk_report` now emits on every check (the round-trip rule requires every emitted key to be in the schema), and the result section documents the additive `selected`/`total`/`fallback_reason` / `coverage`'s `test_selection_note`
- `.claude/skills/pre-merge/refs/universal/protocol-unit.md`, `protocol-integration.md`, `.claude/skills/pre-merge/refs/output-schema.md`: Fixed — `fallback_reason` vocabulary drift: the protocols wrote `no_run_minified` where the schema defines `run_minified: null`, and `integration`'s tier-M widen (`tier: M (widen-to-full)`) wasn't in the schema's value list at all
- `.claude/skills/shared/refs/policy-schema.md`, `component-catalog.md`: Changed — `test_selector` joins the `components[]` field tables alongside `run_minified` (it was emitted by the preflight scripts but defined nowhere)
- `.claude/skills/pre-merge/refs/_common.md`: Changed — one-line disambiguation that `--changed-only` prunes whole platform components while `policies.test_selection` selects tests inside `unit`/`integration`/`regression`; different layers, they compose, both fail open toward running more
- `ARCHITECTURE.md`: Changed — `pre-merge-tier-resolve.sh` joins the script-layer table (it shipped unreferenced by any doc)
- `.claude/scripts/preflight-check-02-unit.sh`, `preflight-check-03-integration.sh`, `preflight-check-04-regression.sh`: Changed — comments pointed at a local-only, gitignored planning doc; they now cite the committed contract files

All twelve AC-TS acceptance criteria are represented in the shipped files; tier bounds, signal names, and the `--full` > `--minified` > policy precedence read identically everywhere.

### [63] — Publish the v4.0.0 user-facing release notes

- `RELEASES.md`: Unchanged — the v4.0.0 section was authored in [61] alongside the feature itself, so this release cuts the `v4.0.0` tag from notes already in the tree (release bookkeeping for the `v4.0.0` GitHub release)

### [64] — Repair two release-history gaps: v2.2.0's lost heading and v3.0.0's missing tag

- `RELEASES.md`: Fixed — restored the `## v2.2.0 — 2026-07-21` heading. The section's body was present and correct (it matches the published v2.2.0 GitHub release verbatim), but with no heading it rendered as a second, unattributed blockquote inside v2.3.0's section — so v2.2.0 appeared to have no notes and v2.3.0 appeared to have two highlights
- Git tags / GitHub releases: Fixed — cut the missing `v3.0.0` tag at its release commit `d6a1c4b` and published its GitHub release from the v3.0.0 notes already in `RELEASES.md`. The v3.0.0 release commit and notes had always existed; only the tag and the published release were absent, which made the tag list appear to skip from v2.5.0 to v3.1.0

Release *numbering* was never non-sequential — every release commit v2.0.0→v4.0.0 exists on `main` in an unbroken run. Both gaps were missing artifacts, so both repairs are additive: no tag was moved or deleted, and no published release was rewritten.

## 2026-07-25

### [59] — Publish the v3.1.0 user-facing release notes

- `RELEASES.md`: Added — v3.1.0 section covering the GitHub Actions CI opt-in policy and the cross-skill closing-message contract (release bookkeeping for the `v3.1.0` GitHub release)

### [58] — Every skill run now ends with a clear pass/warning/fail summary and next step

- `.claude/skills/shared/refs/closing-message.md`: Added — new shared contract: 🟢/🟡/🔴 protocol, message template, and a deterministic next-steps registry mapping skill/mode/verdict to the exact next command
- `.claude/skills/eng/SKILL.md`: Changed — every mode ends its run with the closing message, after the mode's own output contract, report writes, and fix-loop offers
- `.claude/skills/intake/SKILL.md`: Changed — every mode/outcome ends with the closing message, after the row write / update log
- `.claude/skills/msg/SKILL.md`: Changed — `--init`, `--update`, `--init-staging` end with the closing message; pure-emission modes (default picker, `--gui`, `--help`) stay exempt
- `.claude/skills/plan-em/SKILL.md`: Changed — references the closing-message contract; every run ends with it after Step 5's synthesis
- `.claude/skills/plan-pm/SKILL.md`: Changed — all modes end with the closing message after Step 5's termination output
- `.claude/skills/plan-tune/SKILL.md`: Changed — both tune types end with the closing message after the certification verdict / auto-fix table
- `.claude/skills/post-merge/SKILL.md`: Changed — both modes, every outcome including refusals and failed ships, end with the closing message
- `.claude/skills/pre-merge/SKILL.md`: Changed — new step 9 closing message follows the step-8 verdict JSON as the final chat output
- `.claude/skills/shared/refs/report-schema.md`: Changed — clarifies pre-merge's verdict JSON stays the final **machine** emission, with the closing message following as chat prose
- `ARCHITECTURE.md`: Changed — documents the closing-message contract alongside `report-schema.md` and `fix-loop.md` in the shared contract layer
- `README.md`: Changed — documents the closing-message behaviour for users

### [57] — GitHub Actions CI is now an opt-in policy decision

- `.claude/skills/shared/refs/policy-schema.md`: Changed — new `policies.github_actions: {enabled, reason}` field spec plus a §2b read-contract (`ga = policies.github_actions.enabled ?? true`; absent ⇒ prior behaviour, so no migration); `github_actions` outranks `steps.ci` on the empty-check-set path, and `/msg --update` joins the writer table and the `generated_by` enum
- `.claude/skills/msg/refs/protocol-init.md`: Changed — Step 5 asks the GitHub Actions question alongside branch protection in one `AskUserQuestion` (gated on a GitHub remote + `gh`); the two are explicitly independent, and the answer is written by surgical merge — the single documented exception to Step 3's seed-only-these-keys rule
- `.claude/skills/msg/refs/protocol-update.md`: Changed — new Step 3-CI shows the current decision and offers keep / turn on / turn off; an otherwise up-to-date repo now runs it instead of stopping flat; writes no other `policy.json` key
- `.claude/skills/msg/SKILL.md`: Changed — `--init` and `--update` invoke lines name the CI question
- `.claude/skills/post-merge/refs/staging.md`: Changed — Step 2's empty-check-set branch resolves `ga` first: opted out ⇒ proceed silently, no `vacuous-ci` note, no `/pre-merge --init` nudge, one report line naming `/msg --update`
- `.claude/skills/post-merge/refs/production.md`: Changed — same treatment for the "nothing ever reported on staging" precondition and the release-PR CI check
- `.claude/skills/post-merge/refs/protocol-init.md`: Changed — the phantom-check guard stops treating an absent workflow as a gap when Actions is off, but still offers `--bootstrap` (protection needs no named checks); never writes the key, only reads it
- `.claude/skills/post-merge/SKILL.md`: Changed — the CI stage joins the **inactive** column of the three-state table (inactive vs skipped vs relaxed); the safety floor is explicitly not deactivated by any `github_actions` value
- `.claude/skills/pre-merge/refs/protocol-init.md`: Changed — new "Actions opted out" gap flavor: no scaffold offer at all, records `steps.ci: opted_out` with the policy's reason; an existing `pull_request` workflow is still `ready` regardless
- `.claude/skills/pre-merge/SKILL.md`: Changed — `--init` line notes that a missing workflow is a settled opt-out, not a gap, when Actions is disabled
- `ARCHITECTURE.md`: Changed — `devkit/policy.json` row and the co-writer paragraph cover `github_actions` and `/msg --update`
- `QUICKSTART.md`: Changed — explains the CI question and exactly what declining does and does not relax

Red or pending checks from any CI still refuse `red_ci`/`pending_ci`, branch protection is untouched (`required_status_checks.contexts` is already empty), and no human gate moves — the opt-out governs only the empty check set.

## 2026-07-24

### [56] — Publish the v3.0.0 user-facing release notes

- `RELEASES.md`: Added — v3.0.0 section covering the deterministic planning core: collision-proof parallel builds, the branch resolver, the stable roadmap sequencer, the mechanical certification gate, the shared stamp writers, the rendered exec table, and the lane-blind scan + missing `status: eng` stamp fixes (release bookkeeping for the `v3.0.0` GitHub release)

### [55] — v3.0.0 docs: script-layer inventory (v3.0.0 W5)

- `ARCHITECTURE.md`: Changed — script-layer table now lists the seven scripts this release added (`plan-pm-roadmap-sequence.py`, `plan-pm-deps-mirror.sh`, `plan-em-branch-resolve.sh`, `plan-em-exec-skeleton.py`, `plan-tune-cert-status.sh`, `stamp-prd.sh`, `stamp-intake.sh`) plus the previously unlisted `scan-prd-digest.py`, `plan-em-exec-collision.py`, `plan-pm-roadmap-scan.sh`, and `eng-db-touch.sh`

### [54] — Collision checker computes packets and waves (v3.0.0 W4c)

- `.claude/scripts/plan-em-exec-collision.py`: Added — `--waves` mode: partitions exec-table rows by agent, groups file-sharing rows into serial packets (connected components), and layers pairwise-disjoint packets into greedy waves — `PACKET`/`UNPACKETED`/`WAVE` machine lines; under `--waves` a collision is a serialization constraint, not an error (exit 0); no-flag output byte-identical to before
- `.claude/skills/plan-em/refs/protocol-team.md`: Changed — the orchestrator consumes `PACKET`/`WAVE` as the mechanical baseline decomposition; its remaining judgment is model tiering and splitting waves for todo `depends_on` ordering — never merging colliding packets or moving rows
- `.gitignore`: Added — `__pycache__/` (the scripts dir now carries several py_compile-checked Python helpers)

### [53] — Deterministic roadmap sequencing (v3.0.0 W4b)

- `.claude/scripts/plan-pm-roadmap-sequence.py`: Added — mechanises roadmap Step 4: consumes the scanner JSONL (+ optional `INTAKE.md` `S:` bands and existing `roadmap/roadmap.md`), emits `PHASE <k> <id> <kept|new|moved-dep>` / `PHASE 0` / `CYCLE` / `PRUNED` lines; hard `depends_on` edges always win, `S:` bands only bias DAG-free PRDs, rerun-stability pins surviving PRDs to their phase, byte-identical output on identical input
- `.claude/skills/plan-pm/refs/protocol-roadmap.md`: Changed — Step 4 runs the sequencer and consumes its lines as the authoritative assignment (phase names, goals, rationales, and cycle surfacing stay with the LLM); Step 5 tune log keys off the emitted tags

### [52] — Deterministic branch resolution and exec-table rendering (v3.0.0 W4a)

- `.claude/scripts/plan-em-branch-resolve.sh`: Added — read-only, parent-aware branch resolver: emits `BRANCH=`/`ACTION=create|checkout|fresh-cut`/`LANE_MOVE=` from frontmatter + git state (merged-branch reuse impossible; sub-PRDs ride the parent's branch; fresh cuts get a collision-free `-N` suffix)
- `.claude/scripts/plan-em-exec-skeleton.py`: Added — renders the Execution Table skeleton from a JSON `(fid, concern, agent)` spec against §6 (exact row text + `[F<n>](#todos-f<n>)` anchors; unknown F-ID refuses); accepts `ID` or `F-ID` §6 headers
- `.claude/skills/plan-em/refs/protocol-em.md`: Changed — Step 4's branch-resolution/lane-move decision ladder replaced by run-the-resolver-then-execute; Step 3 skeleton build emits the spec through the renderer; branch naming aligned to `feat/<prd-id>` everywhere (was a looser "short name from title" in two places, conflicting with sub-PRD inference and the completion ladder)
- `.claude/skills/plan-em/refs/template-exec-table.md`: Changed — skeleton-build section names the renderer
- `.claude/skills/plan-em/SKILL.md`: Changed — References entries for both scripts

### [51] — The stamp- writer family: deterministic lifecycle writes (v3.0.0 W3)

- `.claude/scripts/stamp-prd.sh`: Added — shared scalar frontmatter writer (`<prd> <field> <value>`, allowed fields: status / product-tuned / eng-tuned / reviewed / completion / module); single-line edit, idempotent, temp+mv write, refuses unknown fields
- `.claude/scripts/stamp-intake.sh`: Added — INTAKE.md ledger row writer (`<path> <row-#> --status <v> [--prd <id>]`); header-derived columns, rewrites only the named row's cells, never renumbers/appends, escaped-pipe and unicode safe
- `.claude/scripts/plan-pm-deps-mirror.sh`: Added — §6 Dependencies → frontmatter `depends_on` union writeback; emits `ADDED <id>` per new edge, idempotent, never mirrors external services or F-IDs
- `.claude/skills/plan-pm/refs/protocol-pm.md`: Changed — Step 3 Part 4 runs the deps-mirror script instead of inline awk + eyeball compare; Step 5 stamps the intake row via `stamp-intake.sh`
- `.claude/skills/plan-pm/SKILL.md`: Changed — lifecycle table and intake-stamp paragraph name the shared writers
- `.claude/skills/plan-em/refs/protocol-em.md`: Changed — plan-wave completion now actually stamps `status: eng` via `stamp-prd.sh` (the lifecycle table promised this stamp but no protocol line implemented it — latent gap closed)
- `.claude/skills/plan-tune/SKILL.md`: Changed — `product-tuned`/`eng-tuned` stamps go through `stamp-prd.sh`
- `.claude/skills/post-merge/refs/production.md` + `SKILL.md`: Changed — production `status: done` and the INTAKE.md `completed` stamp go through the shared writers

### [50] — Mechanical wave-mode detection, certification gate, and roadmap completeness (v3.0.0 W2)

- `.claude/scripts/scan-prd-digest.py`: Added — `engineering_agents` field (ordered `## Engineering — <Agent>` heading names) in the base digest, exposed in the `plan` and `synth` slices
- `.claude/scripts/plan-tune-cert-status.sh`: Added — deterministic certification-gate checker: parses the `product-tuned:`/`eng-tuned:` stamp and §9 Plan tune findings ledger, prints `CERTIFIED` (exit 0) or `UNCERTIFIED no-stamp` / `UNCERTIFIED open-critical <id>` (exit 1); absent §9 with stamp set → certified with a stderr note; bad input → exit 2
- `.claude/scripts/plan-pm-roadmap-scan.sh`: Added — per-PRD `full`/`missing[]` fields (stamps / acceptance-criteria / exec-table completeness computed from §6/§7 body scan) and a `--git` flag refining `completion` via the git/gh ladder mirrored from the GUI server's `infer_completion()` (best-effort, never blocks, degrades to frontmatter-derived buckets with one stderr note)
- `.claude/skills/plan-em/refs/protocol-em.md`: Changed — Step 4 mode detection compares the digest's `engineering_agents` against the roster instead of a prose heading scan; Steps 2 and 4 run the cert checker and branch on its verdict instead of reading-and-interpreting the frontmatter + §9
- `.claude/skills/plan-pm/refs/protocol-roadmap.md`: Changed — Step 1 passes `--git` to the scanner for the refined completion bucket; the Step 2 completeness gate consumes `full`/`missing` instead of the LLM reading §6/§7 of every PRD; ask-user handling unchanged

### [49] — Lane-aware prior-PRD scans + plan-em consumes the collision checker (v3.0.0 W1)

- `.claude/scripts/plan-pm-roadmap-scan.sh`: Added — `--exclude <prd-id>` flag omitting exactly that PRD's line from the JSONL (its nested sub-PRDs still emit); unknown flags refuse with usage on stderr
- `.claude/skills/plan-pm/refs/protocol-pm.md`: Changed — Step 2 enumerates prior PRDs via the scanner's JSONL (lane-aware) instead of the pre-lanes `features/prd-*/prd-*.md` glob that silently missed PRDs sorted into `planned/`/`wip/`/`done/`; overlap and breaking-surface semantics unchanged
- `.claude/skills/plan-em/refs/protocol-em.md`: Changed — Step 1c fast scan runs the scanner with `--exclude` on the input PRD; Step 1a path validation accepts lane-lifecycle paths plus the legacy flat form; Step 4 solo build wave runs `plan-em-exec-collision.py` on §7 before fan-out — colliding rows never dispatch concurrently, `MISSING_FILES` on an in-scope row hard-fails
- `.claude/skills/plan-em/refs/protocol-team.md`: Changed — the orchestrator consumes the collision checker's `COLLISION` lines as the authoritative overlap graph and validates its decomposition against them before spawning any leaf
- `.claude/skills/plan-em/SKILL.md`: Changed — lane-aware path wording (Hard refusals + Inputs) and References entries for the scanner and the collision checker
- `.claude/skills/plan-pm/SKILL.md`: Changed — scanner reference notes it is consumed by Step 2 as well as Roadmap Step 1

### [48] — Publish the v2.5.0 user-facing release notes

- `RELEASES.md`: Added — v2.5.0 section covering the `/plan-em` `--team`/`--solo` execution-mode switch and the Opus orchestrator team (release bookkeeping for the `v2.5.0` GitHub release)

### [47] — Choose how `/plan-em` parallelises work: a `--team` orchestrator or the classic `--solo` roster

- `.claude/skills/plan-em/SKILL.md`: Added — `--team` (default) / `--solo` execution-mode flag, an Execution-mode section explaining the two dispatch lanes, an Inputs row for the flag, and References entries for the new team protocol and shared pref
- `.claude/skills/plan-em/refs/protocol-em.md`: Added — Step 0 resolves the mode (inline flag › persisted pref › default `team`, re-persisting on flag override) and Step 4 routes the wave through either the Opus orchestrator (team) or one leaf `eng` subagent per roster stack (solo)
- `.claude/skills/plan-em/refs/protocol-team.md`: Added — the Opus orchestrator engineer protocol: decomposes each wave below the stack level into file-disjoint, model-tiered work packets (Opus for load-bearing, Sonnet for mechanical) and fans them out to leaf `eng` subagents wave by wave to parallelise as far as the collision graph allows
- `.claude/skills/shared/refs/exec-mode-pref.md`: Added — single source of truth for the persisted `.claude/msg/pref.json` team/solo pref: path resolution (local overrides global), schema, seeding by `/msg --init`/`--update`, and plan-em's read + flag-override precedence
- `.claude/skills/msg/refs/init/init-setup.sh`: Changed — `.claude/msg/pref.json` added to `TARGETS` so it counts toward `ALL_COMPLETE` and is reported as `MISSING` on repos bootstrapped before it existed
- `.claude/skills/msg/refs/init/init.sh`:
  - Added — deterministic write of the pref default `{"exec_mode": "team"}` when absent, so `/msg --init` seeds it and `/msg --update` tops it up
  - Fixed — a latent `set -eo pipefail` crash in the `.gitignore` writer: when no stack section matched, the group's trailing `[[ -n "$stack_content" ]]` test returned non-zero and aborted the whole init; replaced with an `if` block
- `.claude/skills/msg/refs/protocol-init.md`: Changed — documents the `.claude/msg/pref.json` init component and its top-up in `--update` mode
- `README.md`: Changed — `/plan-em` table row describes the `--team` (default) / `--solo` switch

### [46] — Publish the v2.4.0 user-facing release notes

- `RELEASES.md`: Added — v2.4.0 section covering the PRD lifecycle lanes, `/msg --update`, the guided setup path, and the cross-PRD dependency-mirroring fix (release bookkeeping for the `v2.4.0` GitHub release)

### [45] — Headroom runtime wrap marker is no longer tracked in git

- `.gitignore`: Changed — ignore `.claude/.headroom_wrap_marker.json`; it holds only a per-session PID and base URL, so tracking it produced a noise commit every session
- `.claude/.headroom_wrap_marker.json`: Removed from version control (`git rm --cached`); the file stays on disk as local runtime state

### [44] — Headroom runtime wrap marker refreshed

- `.claude/.headroom_wrap_marker.json`: Changed — runtime PID / base-URL marker rewritten by the headroom wrapper (session state, no functional change)

### [43] — `/msg --update` re-scans an already-bootstrapped repo for init components added since setup

- `.claude/skills/msg/refs/protocol-update.md`: Added — the `/msg --update` protocol: re-scans a bootstrapped repo for missing devkit/root files, missing template rows, and PRD lifecycle lanes added since setup, plus flat `features/prd-*/` dirs never sorted into a lane. Hard-refuses if the repo was never bootstrapped (`INITIALISED=false`); warns before offering a full reinit; the update path only adds what's missing (same idempotent guarantee as `/msg --init`'s top-up), and batches ambiguous PRDs to the user via `AskUserQuestion` instead of silently defaulting to `planned`
- `.claude/skills/msg/refs/init/init-setup.sh`: Changed — emits a ninth `FLAT_PRDS` line listing unsorted flat `features/prd-*/` basenames (read-only detection; `init.sh` does the sort)
- `.claude/skills/msg/refs/init/init.sh`: Changed — new `INTERACTIVE_LANES` env var (set by `--update` only) makes rung 3 of the lane migration report ambiguous PRDs via a new `UNRESOLVED` line instead of silently defaulting them to `planned`; plain `--init` still migrates silently
- `.claude/skills/msg/refs/protocol-init.md`: Changed — documents the ninth `FLAT_PRDS` key, the `INTERACTIVE_LANES` behavior, and the new `protocol-update.md` reference
- `.claude/skills/msg/SKILL.md`: Changed — adds `--update` to the argument-hint, invoke docs, and natural-language routing

### [42] — Cross-PRD dependencies listed in a PRD's feature table can no longer go missing from its frontmatter

- `.claude/skills/plan-pm/refs/protocol-pm.md`: Changed — `depends_on` and the §6 Dependencies column were populated independently from the Step 2 scan, so cross-PRD ids named in §6 kept drifting out of frontmatter and were only caught reactively by `plan-tune` check 6 (recurred across PRD-7/8/9/12). §6 is now the source of truth: `depends_on` is seeded from Step 2 then mechanically reconciled from §6 in a new **Part 4 — Dependency mirroring**, an `awk`/`grep` extraction of every `prd-<n>-<slug>` id from the Dependencies column, unioned into the array. `plan-tune` check 6 becomes a backstop rather than the primary catch

### [41] — PRDs now live in a lane that matches their stage — planned, in progress, or shipped

- `.claude/skills/msg/refs/init/init.sh`: Added — `/msg --init` scaffolds three `features/` lifecycle lanes (`planned/`, `wip/`, `done/`) and one-time migrates any pre-lane flat PRD dirs into the right lane by completion ladder
- `.claude/skills/msg/refs/init/init-setup.sh`: Changed — targets the three lane dirs instead of a flat `features/`
- `.claude/skills/plan-pm/refs/protocol-pm.md`: Changed — a freshly-drafted PRD is written into `features/planned/`
- `.claude/skills/plan-pm/refs/protocol-roadmap.md`: Changed — a PRD split into children writes each child into `features/planned/`
- `.claude/skills/plan-pm/refs/protocol-sub.md`: Changed — resolves the parent PRD lane-agnostically across all three lanes and the legacy flat path; a sub-PRD rides its parent's lane
- `.claude/skills/plan-pm/SKILL.md`: Changed — documents the `status: done` stamp and `done/` lane move made by `post-merge --production`
- `.claude/skills/plan-em/refs/protocol-em.md`: Changed — cutting a fresh feature branch relanes the PRD from `planned/` (or wherever it sits) into `wip/`
- `.claude/skills/eng/refs/build/protocol-roadmap.md`: Changed — same relane-on-fresh-cut behavior in the roadmap build loop
- `.claude/skills/post-merge/SKILL.md`: Added — Step 10 stamps `status: done` and moves the PRD folder into `features/done/` on a successful production ship
- `.claude/skills/post-merge/refs/production.md`: Added — the Step 10 protocol detail (lane-agnostic resolution, idempotency, safety-floor note); release-lock window now spans through Step 10
- `.claude/skills/msg/refs/gui/server.py`: Changed — the board resolves PRDs across all three lanes plus the legacy flat path, surfaces each PRD's `lane`, and treats the `done/` lane as a completion signal
- `.claude/skills/msg/refs/gui/index.html`: Changed — empty-state copy no longer names the old flat path
- `.claude/skills/msg/refs/protocol-gui.md`: Changed — documents lane-agnostic PRD resolution and the new `lane` field in the served data
- `.claude/skills/msg/refs/protocol-init.md`: Changed — documents the three lanes and the one-time flat-PRD migration in the init manifest
- `.claude/skills/msg/SKILL.md`: Changed — describes lane-agnostic PRD resolution and writes
- `.claude/scripts/plan-pm-roadmap-scan.sh`: Changed — scans all three lanes plus the legacy flat path, deduped by PRD id
- `.claude/scripts/plan-tune-preflight.sh`: Changed — validates PRD paths against the lane-aware pattern
- `.claude/scripts/scan-n.prd`: Changed — the next-PRD-number scan covers all three lanes
- `.claude/scripts/preflight-check-07-prd-consistency.sh`: Changed — the PRD-surface probe is lane-aware
- `.claude/scripts/preflight-check-18-manual-test-plan.sh`: Changed — the PRD-surface probe is lane-aware
- `.claude/skills/improve/_INDEX.md`: Added — logs improvement #24 (prd-lifecycle-lanes) as done
- `.gitignore`: Added — ignore `.tokensave`
- `.claude/.headroom_wrap_marker.json`: Added — headroom runtime state marker

## 2026-07-22

### [40] — A new user can go from install to first shipped feature without reading the whole README

- `QUICKSTART.md`: Added — the guided onboarding path, ordered as machine setup → repo bootstrap → first feature. Every step carries a **verify** check with the expected output, so a stalled setup fails loudly instead of surfacing later as a gate refusal. Leads with the most-missed precondition: `/pre-merge --init` and `/post-merge --init` are each one-time and separate from `/msg --init` (without them `/pre-merge` refuses `no_manifest` and runs zero components). Carries a prerequisite table, the `--cto`/`--eng` init modes, the pipeline table with the human gates marked, a copy-paste **LLM setup prompt** that instructs the agent to stop rather than skip a failed verify, and a troubleshooting table mapping every refusal code (`no_manifest`, `stale_signoff`, `release_in_flight`, `no_signoff`, `NO_GH`, `NO_REMOTE`) to its fix. Deliberately omits `/plan-tune`, `/todo`, `--loop` and roadmap mode — auto-run or advanced, already in the README
- `README.md`: Changed — a quickstart pointer above the skills table, so the entry point is reachable from the landing doc

- `ARCHITECTURE.md`: Changed — `devkit/PLATFORMS.md` row documents the full v4 column surface (release_model, smoke shapes, staging config, rollback/halt cmds, version probe, macOS surfaces); `devkit/policy.json` row gains the staging-readiness stance; the `INTAKE.md` paragraph notes the gitignored ledger + its `INTAKE-UPDATE.md` sibling; the production run-report sentence carries release identity + per-model outcomes; § Safety floor names the two release tags as metadata-writes and lists the grown human-gate set (pinned sign-off, direct-flow inline human-test, always-ask rollback)
- `README.md`: Changed — the run-reports and safety-floor paragraphs get the same two updates (release-style report contents; the full human-gate list)

### [38] — Publish the v2.3.0 user-facing release notes

- `RELEASES.md`: Added — the `v2.3.0 — 2026-07-22` section (user-facing notes covering entries [27]–[37]: the cross-platform release model — store submissions with monitor-handoff, the always-ask rollback offer, release tagging + provenance, the release lock, staging readiness at `--init`, macOS notarization/signing/appcast, smoke watch/poll, the pinned staging sign-off, the intake history split, and the adversarial-audit fix waves)

## 2026-07-21

### [37] — verification fixes (wave A): the seven governance majors + lifecycle/staleness sweep

- `.claude/skills/post-merge/refs/production.md`: Changed (**verify-F1/F2/F4/F5/F7–F10/F12/F13**) — the big one. Direct flow is now *executable*: the release PR head + every commit range branch by `release_flow` (feature-branch→prod in direct, never a hardcoded `--head staging`). The **inline human-test approval** the direct flow leaned on is finally *defined* — one section, placed after merge/before deploy, exact ask shape, decline → `human_test_declined` skip; all seven former references now cite it. The C2×C8 **TOCTOU closed**: coverage re-verified against a fresh fetch immediately after lock acquire; drift → release lock + `stale_signoff`. Explicit `git fetch origin $PROD` after the Step 5 merge — Steps 6–9 (provenance, monotonicity, tag) no longer read a stale ref. Lock releases at **ship-terminal** (after the rollback offer, before the fix-loop handoff) so a legitimate fix session can't outlive the TTL and invite a live-lock "cleanup"; `no_prd` got its missing post-acquire exit row (13-row table). `$NEWEST` computed by pairwise `merge-base --is-ancestor` (the old `rev-list --topo-order --no-walk` sorted by *date*, not topology — wrong `$NEWEST` on skewed clocks) with no-dominator → refuse. Stale lock = terminal refusal only ("cleared this run" deleted). Multi-PRD coverage refusal now names the `--prd <owning PRD>` remediation instead of dead-ending in `no_pr`. `BUILD` recomputed post-merge at tag-time
- `.claude/skills/post-merge/refs/release-identity.md`: Changed (**verify-F3/F13/F14**) — provenance bounded to `$CURRENT_TAG..origin/$PROD`: a stale artifact built from an *old release* commit (ancestor of prod — the previously-passing named failure case) now **fails**; legacy no-`+build` tag fallback defined (`git rev-list --count <tag>`); sanctioned-writes enumeration defers to SKILL
- `.claude/skills/post-merge/SKILL.md` + `shared/refs/safety-floor.md` + `refs/refusal-patterns.md`: Changed (**verify-F6/F11/F17/F18, S1–S3**) — sanctioned-writes now **single-sourced** (SKILL canonical incl. the re-stamp + issues file; safety-floor matches; release-identity + refusal-patterns defer — a *fourth* stray enumeration found and deferred too); new `version_regression` refusal; `signoff_declined` widened to both modes; intake-stamp citations corrected to **v3** D14; "Each run is independent" → lock-aware; "Steps 1–8" → 1–9; the staging description half release-model-conditioned
- `.claude/skills/post-merge/refs/{submission,verify-deploy}.md` (**verify-L1–L3**) — **AC-SB4 decouple**: an accepted submission stamps `completed` regardless of backend-smoke verdict (a submission cannot be un-submitted by a backend blip); the smoke failure still drives verdict `fail` + the halt offer, and still withholds the Step 9 tag — the asymmetry documented on both sides. Appcast check scoped to `--production`; notarization with no `smoke_poll` gets a default `15m/30s` bound — a non-terminal read inside it is *pending*, only ceiling-exhaustion is `notarization-stall` (no more spurious stalls on healthy 5-minute notarizations)
- `.claude/skills/post-merge/refs/{staging,protocol-init}.md` + `template-PLATFORMS.md` + `refs/output-schema.md` + `shared/refs/policy-schema.md` (**verify-L4, S4–S7, F15/F16 notes**) — policy-conditional protection wording (no more "anything but PROTECTED refuses" under a relaxed policy); dangling `improve-doctor.md` ref removed; `--init` coverage map gains the Step 9 tag row; the manual-unlock one-liner actually printed where policy-schema claims; `$SUBMISSION_ID` provenance + the `—` not-configured marker defined; Test-results lines carry the full verify-deploy vocabulary; design-accepted staleness notes (D14) added

### [36] — verification fixes (wave B): intake delete-flow ordering + the v4 docs scrub

- `.claude/skills/intake/refs/protocol-delete.md`: Changed (**verify-I1/I2/I3/I5**) — migration moved to a **Pre-run step ahead of the warning pass**, so W4's "history preserved" always reads post-migration state (previously, a legacy ledger whose first-ever touch was a `--delete` warned "no history" while history sat in the in-file log); `INTAKE-UPDATE.md` added to the pre-run reads table (may-be-absent); migration wording unified — **entry rows only**, never the legacy heading/column-header row (cites `protocol-update.md` § The update log instead of restating); Step 5's "no longer carries the log" conditioned on post-migration
- `.claude/skills/intake/refs/protocol-update.md`: Changed (**verify-I4**) — stated plainly: migration rides the first *writing* touch; a no-op run leaves the legacy layout by design
- `README.md` + `ARCHITECTURE.md`: Changed (**verify-R1/R2**) — the post-merge descriptions finally match the v4 surface: release-model split (submission platforms never report `live`), pinned sign-off, release identity threaded through confirm→PR→tag, the release lock, the always-ask rollback/halt offer, provenance vs the signed-off sha, per-platform staging readiness at `--init`. "Smoke-verifies every deploy" is gone; "live target" survives only conditioned to deploy-model platforms

  (Fixture-doc errata — Steps 6–9, the pre-v4-schema caveat, macos tense, and the P3 android-row erratum — landed in the gitignored `evals/` alongside)

### [35] — install.sh: retire the stale `/ship`-era comment

- `install.sh`: Changed — the execute-bit rationale comment referenced `/ship`'s Test stage and two scripts that no longer exist (`test-tooling-detect.sh`, `test-aggregate-verdict.sh`); now cites the live reality (`/pre-merge` runs the `preflight-check-*.sh` family and `pre-merge-aggregate-verdict.sh` as `"$S"`). Copy logic unchanged — the wildcard install already ships every v4 addition (`submission.md`, `release-identity.md`, the 30-script `.claude/scripts/` set)

### [34] — v4 P5: release lock — two production ships can no longer race

- `.claude/skills/post-merge/refs/production.md`: Added (**C8/D4**, AC-LK1/LK2) — **§ Release lock**: a remote annotated git tag `release-lock-<prod>` is the lock — the only candidate with true atomic acquire (a tag ref is never fast-forwarded, so pushing an existing name is server-rejected = compare-and-swap-to-absent); survives across machines, no new credentials, no tracked-file write (safety floor, per D8's tag precedent). Holder metadata (who/when/sha/PRDs) rides in the tag message and is read back into the `release_in_flight` refusal. Acquire sits **after Step 3** (pre-flight refusals never touch the lock) and **before Step 4** (covers the whole mutating window); release is wired into **every** post-acquire exit — the 10-row exit-path walk is in the ref, incl. the one honest gap (hard SIGKILL → covered by TTL + manual unlock). **TTL 120m** (clears notarization + poll/watch ceilings with margin); stale → reported with the one-line unlock (`git push origin :refs/tags/release-lock-<prod>`), never blind-refused, never auto-stolen
- `.claude/skills/post-merge/refs/staging.md`: Added (**C8**) — **§ In-flight-production check**: `--staging` *reads* the lock and refuses `release_in_flight` while a production ship is live; it never acquires (a staging merge is near-atomic — the reverse race window is sub-second, not worth the friction)
- `.claude/skills/post-merge/refs/refusal-patterns.md`: Changed (**C8**, AC-LK1) — `release_in_flight` row (both modes) + refusal JSON `lock` block with the stale variant; new Never: never `--force`-steal a live lock
- `.claude/skills/shared/refs/policy-schema.md`: Added (**C8**, CV2) — additive §6 Release lock (mechanism, state location, atomicity, TTL, manual unlock, fail-open); runtime state, **no new policy field**
- `.claude/skills/post-merge/SKILL.md` + `refs/output-schema.md` + `shared/refs/safety-floor.md`: Changed (**C8**, AC-LK3) — lock tag joins sanctioned writes; hard-refusal line; additive `release_lock` report block; safety-floor row names release + lock tags as metadata. Uncontended acquire+release is silent — solo single-run and direct flow gain zero friction; an infra-error on push fails **open** with a `low` note so a flaky network never dead-ends a legit ship

  **v4 bench close-out** (chars/4, same method): post-merge total **86,653** vs the 49,530 P0 anchor — **+74.9%**, the honest cost of going from a web-shaped `smoke; echo $?` gate to a cross-platform, concurrency-safe release model; loaded per ship, never on the per-PRD pipeline

### [33] — v4 P4: macOS notarization/signing/appcast + smoke contract v2

- `.claude/skills/post-merge/refs/verify-deploy.md`: Changed (**C7/D9**, AC-SM1/SM2/SM3) — new **§ Smoke contract v2**: `smoke_cmd` extends to `{cmd, watch_window?, poll?}` while a bare string stays byte-for-byte one-shot; `watch_window` (`<duration>/<interval>`, e.g. `5m/30s`) re-checks health after a passing first verdict — degradation → `smoke-failed` + the P3 rollback offer; `poll` (`<timeout>/<interval>`) waits for late-live targets (CDN/DNS, store processing, notarization) with a **distinct `smoke-never-live` timeout verdict**, never a generic fail; canary/progressive-delivery stated as explicit non-goals. (**C6/D13**, AC-MAC1/2/3) — new **§ macOS release checks**, config-gated, declared-artifact style: `notarize_status_cmd` polled via C7's primitive (terminal `Accepted` = verified, `Invalid` = `notarization-invalid`, stall = `notarization-stall` — never a generic deploy failure; async shape shares `submission.md`'s processing vocabulary), `signing_smoke_cmd` (`spctl`/`codesign`) → distinct `signing-fail`, `appcast_url` → reachable + release-identity's `NEXT_VERSION` present, else `appcast-stale`; undeclared ⇒ nothing runs, nothing flagged
- `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md`: Changed (**C6/C7**) — five new columns (`smoke_watch_window`, `smoke_poll`, `notarize_status_cmd`, `signing_smoke_cmd`, `appcast_url`; 14→19, `—` where N/A); the **macos row unfolded** — deploy cmd is now async `notarytool submit` without `--wait`, notarization verified as its own step instead of stalling inside the deploy
- `.claude/skills/post-merge/refs/output-schema.md`: Added (**C6/C7**, CV2) — additive per-platform `smoke: {mode: one_shot|poll|watch, attempts, window}` (defaults preserve the bare path), `smoke-never-live` rule, macOS finding table + canonical `notarization-stall` shape
- `.claude/skills/post-merge/refs/refusal-patterns.md`: Changed (**C6**) — new § stating the macOS release checks are **findings, not refusals** (they fire post-merge; only `nonmonotonic_build` is genuinely pre-flight)
- `.claude/skills/post-merge/refs/{staging,production,deploy}.md` + `SKILL.md`: Changed (**C6/C7**) — smoke steps aligned to the v2 contract (no ref implies one-shot-only); macOS-check and notarization-unfold notes in the deploy/verify steps

  **Exit gate: all five P0 wrong-model findings now closed** (#1/#2→C1, #3→C5, #5→C3, #4→C6). On macOS, `smoke_poll` deliberately serves double duty as the notarization poll bound — one primitive, no parallel mechanism

### [32] — v4 P3: executable rollback + release artifact identity

- `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md`: Changed (**C3/D12**, I6) — new `rollback_cmd` (deploy model: restore last-good) and `rollout_halt_cmd` (submission model: pause the staged rollout) columns with per-platform examples, mutually exclusive by release model. I6 fix: Android `rollback_possible` `no → limited` (the halt lever exists); iOS stays `no`/`IRREVERSIBLE` (a released build is permanent) **and** gains a `rollout_halt_cmd` — halt ≠ un-ship
- `.claude/skills/post-merge/SKILL.md`: Changed (**C3/C4**, AC-RB1/RB3, AC-RI1) — failed-ship loop restructured: **step 1 is the rollback/rollout-halt offer via `AskUserQuestion`, before the fix loop, never auto** (D12; autonomous runs default to decline); unconfigured lever → notes-only + gap (AC-RB2). `--production` grows to Steps 1–9 (identity resolution, monotonicity, provenance, tag); the release tag joins the sanctioned-writes list; `--bump`/`--version` override documented in usage + argument-hint
- `.claude/skills/post-merge/refs/release-identity.md`: Added (**C4/D8**) — the identity contract: version source of truth = newest `v*` tag reachable on prod, **read-only** (no VERSION file, no bump commit — safety floor); default bump minor, `--bump`/`--version` override; build number = commit count on prod (monotonic by construction, credential-free, platform-shared); tag `v<x.y.z>+<build>` stamped at release — justified as release metadata, not a source modification
- `.claude/skills/post-merge/refs/production.md`: Changed (**C4**, AC-RI1/RI2/RI3) — early identity resolution (resolved tag surfaces in the double-confirm, no third ask); Step 6 build-number monotonicity gate **before** any store submit; Step 7 provenance check — the declared `version_probe` prints the shipped artifact's source commit, checked against C2's certified-sha pin (mismatch → `fail` finding; no probe → `asserted_unverified`, never a fail); Step 9 tags prod on success
- `.claude/skills/post-merge/refs/refusal-patterns.md`: Changed (**C4**, AC-RI3) — new `nonmonotonic_build` refusal
- `.claude/skills/post-merge/refs/output-schema.md`: Added (**C3/C4**, CV2) — additive per-platform `rollback` object (`offered`/`lever`/`approved`/`cmd_exit`/`outcome`), `release_identity` block, `build_number`, `provenance` + provenance-failure finding
- `.claude/skills/post-merge/refs/{deploy,verify-deploy,submission}.md` + `shared/refs/{fix-loop,policy-schema}.md`: Changed (**C3**) — failure paths route to the executable offer before fix-forward; fix-loop.md states the ordering contract (the offer precedes, never replaces); halt-lever wording "offered on failure"

### [31] — v4 P6/C11: the intake update log moves to its own file (`INTAKE-UPDATE.md`)

- `.claude/skills/intake/refs/protocol-update.md`: Changed (**C11**, AC-LS1/LS2/LS5) — log writes target `INTAKE-UPDATE.md` (lazy-created with the canonical header on first write — no template); **migration rule**: first touch of a ledger with an in-file `## Update log` moves the section verbatim, strips it from `INTAKE.md`, idempotently; the blank-line-leak note reframed — unreachable by construction once split
- `.claude/skills/intake/refs/protocol-delete.md`: Changed (**C11**) — same retarget; W4 now says history survives the row's deletion in the separate file; gained its own migration check so a repo whose *first* ledger touch is `--delete` still migrates
- `.claude/skills/intake/refs/protocol-intake.md` + `intake/SKILL.md`: Changed (**C11**, AC-LS5) — file references repointed; a missing `INTAKE-UPDATE.md` is never an error
- `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md`: Changed (**C11**) — `## Update log` dropped from the scaffolded body; writer table retargeted; the v4.1 four-layout parser-tolerance table kept as a condensed historical note (the tested evidence that motivated the split)
- `.claude/skills/msg/refs/init/templates/template-gitignore.md` + `msg/refs/protocol-init.md`: Changed (**C11**, AC-LS3) — `INTAKE-UPDATE.md` gitignored beside `INTAKE.md` (rides v4.1's D4); scaffold rows note lazy-creation
- `.claude/skills/msg/refs/protocol-gui.md`: Changed (**C11**) — `server.py` never reads or writes `INTAKE-UPDATE.md`; status writes touch `INTAKE.md` only
- `README.md`: Changed — `/intake --update` row names the new file

  **Verified by executed test (10/10 PASS**, real `server.py` `build_intake`/`set_intake_status`): post-split ledger parses 3/3; status write preserves the file; a sibling `INTAKE-UPDATE.md` never affects the row scan (server opens only `INTAKE.md`); all four v4.1 legacy layouts reproduce the original table exactly (incl. the 7-row leak case) — parsers stay tolerant of pre-migration files while the split makes the leak unreachable for migrated ones

### [30] — v4 P2: the mobile submission lifecycle — honest handoff, not fake liveness

- `.claude/skills/post-merge/refs/submission.md`: Changed (**C5/D2**, AC-SB1/SB3/SB4/SB5, CV5) — the § Deferred seam becomes the full lifecycle: **submit → (store processing) → review → phased rollout**, with the ownership boundary drawn (post-merge owns through submit-accepted; represents-and-hands-off everything after). Accepted vs **rejected-at-upload** distinguished via fixture-derived worked output shapes (altool/deliver, Play staged-rollout). The **monitor-handoff block** names the real consoles (App Store Connect / Google Play Console) and the future `rollout_halt_cmd` lever (C3). `live_status` polling seam documented (default `handed_off`; v4.1 fills real store states without a breaking change). New § Submission in `direct` flow (CV5): a no-staging mobile repo ships feature→prod as a submission with the staging-scoped stages inactive — cited to `SKILL.md § Release flow`, never re-enumerated
- `.claude/skills/post-merge/SKILL.md`: Changed (**C5**, AC-SB1) — frontmatter description tail now release-model-honest ("smoke the live target, or submission-accepted + monitor-handoff for store apps") — the P1 residual closed; submission rows in both mode tables route through the lifecycle (submitted + track + handoff, never live); rejected-at-upload named a deploy-step failure
- `.claude/skills/post-merge/refs/production.md`: Changed (**C5/D2**, AC-SB3/SB4, CV5) — Step 8 keeps `completed` stamped **on submit** but now carries the required note: live-to-users is downstream + out-of-band, with the monitor pointer; § What to expect gives submission platforms the full handoff block; Step 1's direct-flow paragraph gains the CV5 line (submission lifecycle runs on the direct ship; double-confirm + inline human-test stay active)
- `.claude/skills/post-merge/refs/output-schema.md`: Added (**C5**, AC-SB5, CV2) — additive submission fields on `platforms[]` entries: `track`, `submitted_at`, `monitor`, `live_status` (absence = `handed_off`; v4.1 enum reserved); deploy entries carry none; nothing reshaped
- `.claude/skills/post-merge/refs/verify-deploy.md`: Changed (**C5**) — submission-accepted (exit 0) vs rejected-at-upload (non-zero → deploy-step failure, **not** a smoke failure) made distinct outcomes; review rejection noted as out-of-band

  **Known coupling (pre-existing, flagged not fixed):** a backend smoke failure still sets verdict `fail` and skips the Step 8 stamp even when the submission was accepted — predates C5, outside AC-SB scope, recorded in the P2 re-derivation

### [29] — v4 P1b: `--init` verifies staging is actually set up, not just a branch

- `.claude/skills/post-merge/refs/protocol-init.md`: Added (**C9/D14**, AC-SR1/SR2/SR4) — detection **item 6 · Staging readiness**: per-platform declared-artifact checks (staging cmd/target non-placeholder; declared `staging_config` file exists on disk; submission platforms name an internal/TestFlight/Play track; macOS a staging channel) — release-model-shaped, `staged` flow only, no probing/pings/credentials. Reports `ready`/`gaps[]` per platform with the **exact missing artifact and exact fix**; persists `staging_ready`; item 1 gains the "a branch is not a ready environment" caveat; in `direct` flow the whole item is inactive and writes no record
- `.claude/skills/shared/refs/policy-schema.md`: Added (**C9**, AC-SR3) — new **§5 `staging_ready`** read-contract: per-platform `{ready, gaps[]}` + `resolved_at`/`resolved_by`, framed as a **resolved fact** (re-derived every re-init, absent in `direct`), never settled policy; new governing knob `policies.staging_readiness.mode` ∈ `enforced` (default) | `optional` | `skip`, mirroring `branch_protection`
- `.claude/skills/post-merge/refs/staging.md`: Added (**C9**, AC-SR3) — **staging-readiness guard** pre-flight between Steps 1–2: recorded gaps refuse (`enforced`) / warn (`optional`) / pass (`skip`); an **absent** record (pre-C9 init) always warns + proceeds regardless of mode — a record predating C9 is never grounds for refusal
- `.claude/skills/post-merge/refs/refusal-patterns.md` + `SKILL.md`: Changed (**C9**) — new `staging_unready` refusal (lists each unready platform's gaps + fix, remediation = re-run `--init`); one conditional hard-refusal line. § Release flow / § Release model / sign-off machinery untouched
- `.claude/skills/msg/SKILL.md`: Changed (**C9**) — `--init-staging` Step 4 is now a readiness handoff: creating the branch ≠ staging ready; points at `/post-merge --init`'s per-platform readiness + fix loop
- `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md`: Changed (**C9**, AC-SR2) — optional `staging_config` column (the declaration surface the config-file check reads — without it the `.env.staging` check had nothing to read); `staging_deploy_cmd` annotated as the track/readiness signal

### [28] — v4 P1: per-platform `release_model` split (`deploy` vs `submission`)

- `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md`: Changed (**C1**, AC-RM1, I6) — the platforms contract gains a `release_model` column (`deploy` | `submission`; defaults web/macos→`deploy`, ios/android→`submission`). `smoke_cmd`'s contract is now release-model-aware, and the ios/android examples say **backend/build health only** — closing the contradiction where the template and `verify-deploy.md` disagreed about what a mobile smoke verifies
- `.claude/skills/shared/refs/policy-schema.md`: Added (**C1/D7**, AC-RM1) — new §4: `release_model` is authored in `PLATFORMS.md` and mirrored into the resolved manifest per platform (the tolerance/preview authored-source→resolved-consumer pattern); missing → inferred from platform identity **with a warn, never silently**
- `.claude/skills/post-merge/SKILL.md`: Changed (**C1**, AC-RM2/RM3) — new `## Release model` section (orthogonal to `release_flow`); `--staging` Steps 4–5 and `--production` Steps 6–7 branch on it: deploy-model rows unchanged, submission-model rows route to `refs/submission.md` and report **`submitted`, never `live`**. § Release flow's staging-scoped enumeration and the sign-off machinery untouched
- `.claude/skills/post-merge/refs/submission.md`: Added (**C1**) — the submission-model primitive: deploy-cmd exit 0 = submitted (+ target track), verification = submission *accepted*, smoke labeled backend health; § Deferred marks the full lifecycle, monitor-handoff, completed-on-submit note, and the `live_status` polling seam as P2/C5
- `.claude/skills/post-merge/refs/deploy.md`: Changed (**C1**, AC-RM4) — resolution resolves `release_model` per platform (inference-with-warn); exit-0 meaning defined per model; per-platform resolution independent — a mixed web+ios repo verifies web as live and ios as submitted in one pass
- `.claude/skills/post-merge/refs/verify-deploy.md`: Changed (**C1**, AC-RM2/RM3, I6) — verification split by model: deploy path explicitly unchanged; submission path verifies submission-accepted and reports any smoke as backend/build health — the "release is actually up" framing no longer applies to submission platforms
- `.claude/skills/post-merge/refs/output-schema.md`: Added (**C1**, CV2) — additive `platforms[]` block (per-platform `release_model` + `outcome` incl. `submitted`, `track`); no existing field renamed or reshaped
- `.claude/skills/post-merge/refs/production.md` + `refs/staging.md`: Changed (**C1**) — `## What to expect` liveness claims made release-model-conditional (submission → submitted-not-live)

### [27] — v4 P-Hotfix: staging sign-off pinned to the certified commit; direct flow inactive-not-waived

- `.claude/skills/post-merge/refs/staging.md`: Changed (**C2**, AC-SO1) — Step 3 resolves `CERTIFIED_SHA` (full 40-char `origin/staging` at merge) once and carries it through the run; Step 7 stamps `staging-signoff: <date>@<sha>`, never a sha other than the one deployed and human-tested; commits landing during the test window are stamped-around and noted `low`, not silently certified
- `.claude/skills/post-merge/refs/production.md`: Changed (**C2/C10**, AC-SO2-refined, AC-NS1) — Step 1 gains the **sign-off coverage gate**: ancestry (every stamped sha an ancestor of `origin/staging` — catches rewritten history) + coverage (`origin/staging` equals the topologically newest stamped sha — catches commits merged after sign-off) ⇒ `stale_signoff`, replacing the drafted per-PRD equality rule that would have falsely refused every multi-PRD release (I2). Unpinned legacy stamps **re-ask the human once and re-stamp pinned** instead of dead-ending the release (I4). Direct-flow run reports open `## Work done` with a `Stages:` line naming the inactive set
- `.claude/skills/post-merge/refs/refusal-patterns.md`: Changed (**C2**) — new `stale_signoff` row (both failure shapes, remediation = per-PRD re-sign-off) and a new Never: never stamp a sign-off without its certified sha
- `.claude/skills/post-merge/refs/output-schema.md`: Changed (**C2**) — `staging_signoff` value shape is now `<date>@<sha>`
- `.claude/skills/post-merge/SKILL.md`: Changed (**C2/C10**, AC-NS1–NS4) — hard-refusal line and I/O table pin the sha; § Release flow rewritten around the **three-state vocabulary** (`inactive` = stage doesn't apply ≠ `skipped` = tooling absent ≠ `relaxed` = threshold lowered by policy); the staging-scoped set enumerated **once** here (D11/R1 — every other ref defers, AC-NS5's catalog mechanism deferred to the executor phase); the safety floor declared never-inactive (AC-NS3); the sign-off's inactivity in direct flow derived from its stage's, not special-cased (AC-NS4)
- `.claude/skills/post-merge/refs/protocol-init.md`: Changed (**C10**) — direct flow reframed from "waives the signoff" to "staging-scoped stages inactive because they do not apply, everything applicable at full rigor"
- `.claude/skills/shared/refs/policy-schema.md`: Changed (**C10**) — direct-mode human-gate note defers to `post-merge/SKILL.md` § Release flow as the single authority instead of re-listing the staging-scoped set
- `README.md`: Changed — post-merge row documents the pinned stamp and the `stale_signoff` refusal

### [26] — Publish the v2.2.0 user-facing release notes

- `RELEASES.md`: Added — the `v2.2.0 — 2026-07-21` section (user-facing notes covering entry [25]: intake's new `--update` and `--delete` modes, the ignored ledger, the update log, and `argument-hint` autocomplete across every skill)

### [25] — v4.1: intake gains `--update` and `--delete`, plus `argument-hint` on every skill

- `.claude/skills/intake/SKILL.md`: Changed (**C1/C9/C10**, AC-UM1–5, AC-UD1–6, AC-AH1) — intake becomes a **three-mode skill**. New § Usage blocks for `--update` (browse + one-shot) and `--delete`, mode dispatch resolved once at entry from the arg string, `argument-hint` frontmatter, a § Two edit surfaces table splitting the ledger's writers by cell, and a § Update log section. Hard refusals extended: neither new mode scaffolds a missing ledger, `--update` is never destructive, `--delete` never renumbers and never touches anything but ledger rows
- `.claude/skills/intake/refs/protocol-update.md`: Added (**C1–C7**, AC-UT1–6, AC-US1–5, AC-UF1–6, AC-UL1–5, AC-UG1–6, AC-UW1–7) — the six-step update protocol. Emits every non-`completed` row in full (`in-progress` shown but locked 🔒), resolves the target from free text (`#n` beats text match; 0 or ≥2 matches never guess — a failed one-shot degrades into browse rather than capturing a new row), follows up whenever changes are absent **or vague** (the one-shot form buys speed, not a bypass), re-grades on a material change and re-runs both split gates, then writes a targeted cell rewrite — never a file rewrite
- `.claude/skills/intake/refs/protocol-delete.md`: Added (**C11/D7**, AC-DEL1–10) — the delete protocol, closing the row-removal gap. Lists **every** row including `completed`, runs a four-check warning pass before the confirm (**W1** orphaned PRD · **W2** destroyed ship record · **W3** other rows graded `S:blocked-by-#n` that will dangle · **W4** preserved log history), then removes on explicit confirm. Two invariants: **never renumber** (the `#` gap is the trace of a removal — renumbering would silently repoint every `blocked-by` reference and log entry) and **never delete silently**. Blast radius is the ledger row alone; it reports what it orphans, never cleans up after itself
- `.claude/skills/intake/refs/protocol-intake.md`: Changed (**C1/C6.5**) — marked as the *capture-mode* protocol and cross-linked to the two new ones; capture explicitly writes no update-log entries (the row's own `date` already records it) and appends above the log section
- `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md`: Changed (**C6.5/C7**, AC-UX1–8, AC-UW5) — the ledger gains an append-only **`## Update log`** (`when | row | change | detail`, one entry per changed cell, `change` ∈ `modify`/`add`/`remove`) instead of an `updated` column, so the row table's schema and every downstream parser stay untouched. Writer table extended with the update and delete owners. Carries the **tested** parser-tolerance table: a blank line does *not* end the row scan, so the heading/preamble separating the two tables is structural — strip both and the log's rows leak in as ledger rows (3 → 7)
- `.claude/skills/msg/refs/init/templates/template-gitignore.md`: Changed (**C8/D4**, AC-GI1–4) — `INTAKE.md` added to the Universal `# msg skill artifacts` section. The ledger is a single append-only table every feature branch writes to, so it is a standing merge-conflict magnet; ignoring it removes that class. Accepted cost: `post-merge --production`'s `completed` stamp becomes a local-only write
- `.claude/skills/msg/refs/protocol-gui.md`: Changed (**C9/D5-corrected**) — the Intake tab is documented as the **status-override** surface, not the any-cell override earlier drafts assumed. It is the only surface that moves a row *backwards* through the D14 lifecycle, which makes it the sanctioned escape hatch for `--update`'s `in-progress` refusal. It withholds content edits on purpose: it cannot re-derive the grade, so a hand-edited `idea` would leave the grade asserting a judgment of vanished text
- `.claude/skills/msg/refs/protocol-init.md`: Changed (**C8**) — `.gitignore` and `INTAKE.md` scaffold rows note the new ignore and the log section
- `.claude/skills/msg/SKILL.md`: Changed (**C9/C10**) — skill menu and routing table carry both new modes; `argument-hint` added
- `.claude/skills/{plan-pm,plan-tune,plan-em,eng,pre-merge,post-merge}/SKILL.md`: Changed (**C10**, AC-AH1–7) — `argument-hint` frontmatter on every user-invocable skill, so the accepted modes and placeholders surface in autocomplete rather than after a refusal. Fixed notation (`<>` required, `[]` optional), capped at ~60 chars, and deprecated aliases (`--doctor`, `--todo`) deliberately never advertised
- `README.md`: Changed (**C9**) — `/intake --update` and `/intake --delete` documented in the skill table

### [24] — Publish the v2.1.0 user-facing release notes

- `RELEASES.md`: Added — the `v2.1.0 — 2026-07-21` section (user-facing notes covering entries [22]–[23]: env-needing checks now run inside a fresh, disposable sandbox instead of ambient state, and that sandbox is reused to serve the human-review preview)

### [23] — v3.1/C23: hermetic test runs — env-needing checks now run in one ephemeral, isolated, disposable sandbox

- `.claude/skills/shared/refs/component-catalog.md`: Changed (**C23**, AC-SBX1) — every component row gains an `env` column (`needs_env`): **true** for the checks that need a running app/DB (`integration`, `e2e`, `a11y`, `perf`, `load`, `migration`, `mobile`, `smoke`), **false** for every static check; `regression` is **conditional** on its suite composition (`ᶜ`, resolved at `--init`); `api` is **live-half only** (`ˡ` — spec-diff static, live-conformance sandboxed); `preview` is the **promoted-sandbox consumer** (`ᵖ` — provisions nothing). New "env-needing tier" section carries the lifecycle, the seed strategy (migrate-from-zero + versioned fixture, never a prod snapshot), warm fix-loop reset, and the loud no-provisioner degrade
- `.claude/skills/shared/refs/policy-schema.md`: Added (**C23**, AC-SBX6) — the `needs_env` manifest field and the **`env_provision` resolution**: a neutral provision / seed / reset / teardown verb interface with `seed_script` + `scale_factor`, `provisioner: "none"` valid-but-loud, designed **post-merge-consumable** (shared schema, never shared machinery). Composite **`stacks[]`** supports full-stack-mobile repos needing two provisioners at once (simulator + compose backend) as **one logical sandbox**; the flat shape stays valid as the single-stack case
- `.claude/skills/pre-merge/refs/executor.md`: Added (**C23**, AC-SBX2–5) — **§3b sandbox lifecycle**: provision **only-on-green** (a `mechanical`/`unit` fail never provisions — zero env cost on fail-fast) → run the env wave inside **exactly one** sandbox per run (own DB/state/ports, concurrent-run safe) → **promote the same env** to serve as the C20 preview (fresh-provisioned after warm resets; never a second env) → teardown after every run, pass or fail. Wave scheduling splits on `needs_env`; no provisioner ⇒ ambient run + `high` `sandbox-unprovisioned` finding (destructive checks skip-with-note, never against shared state)
- `.claude/skills/pre-merge/refs/protocol-init.md`: Changed (**C23**, AC-SBX6/SBX8) — two new resolutions: **env-provisioner detection** (compose / testcontainers / DB-branch / preview-deploy / simulator; composite → `stacks[]`) + seed-script question, and **`regression.needs_env`** resolved from the suite's composition; `--update` re-resolves both as facts, never re-prompting settled policy
- `.claude/skills/pre-merge/refs/platform/protocol-preview.md`: Changed (**C23**, AC-SBX5) — the human-review gate now **consumes the promoted sandbox** instead of provisioning its own; the preview-scoped `preview_env` field is superseded by `env_provision`; F3 kept as lineage
- `.claude/skills/pre-merge/SKILL.md`: Changed — the pipeline outline gains the env wave (static waves → sandboxed env wave → coverage → regression tail)

  **Verified by test (14/14 assertions):** the §3b lifecycle was exercised end-to-end against a real DB-backed fixture app — only-on-green, own-port/own-DB provision, seeded integration check inside the sandbox, two concurrent sandboxes with zero state leak, warm data-only reset (same server pid), promotion with env count still 1, and full teardown with no residue. Additive throughout (AC-SBX7) — no static check's behavior changed

## 2026-07-20

### [22] — Publish the v2.0.0 user-facing release notes

- `RELEASES.md`: Added — the `v2.0.0 — 2026-07-20` section (user-facing notes covering entries [6]–[21]: the v3 preflight-driven pipeline overhaul — secret-scan floor, diff-scoped coverage, migration safety, native mobile coverage, the merged human-review gate, the breaking `/pre-merge` manifest requirement, and the `--doctor`→`--init` rename)

### [21] — v3 P6: merged human-review gate (R1–R4), hardened smoke, a11y upgrade, manual-test-plan rendered at both gates

- `.claude/skills/pre-merge/refs/platform/protocol-preview.md`: Changed (**C20/D26**, AC-PRV1–8) — `qa` (id 15) **merged into `preview`** (id 16): the two components did the same act (stand up the feature → serve it to a human → block on sign-off), so they collapse into **one** human-review gate with one unified approval artifact and one Approve/Reject. `preview` is now the **sole human gate** in pre-merge. Four robustness items harden it: **R1** — the approval prompt never fires until `smoke` passes green (no approving a dead preview); **R2** — one informed-approval artifact `.pre-merge/<ts>/preview-approval.json` bundling smoke + api spec-drift + migration round-trip + a11y + visual-diff evidence **and** the C22 manual-test-plan checklist (HIGH first — **render site (a)**, AC-MTP6); **R3** — commit-bound approval (`sha256(commit:capture:run)` recomputed on resume; new commit or expiry ⇒ re-fire, never auto-pass); **R4** — a Reject emits a canonical finding into the universal report → `eng --build` fix-loop. The parked live-env sweep lands here — **api #3** (live spec-conformance) + **migration #3** (up→down→up) run against the ephemeral env pre-approval and feed R2. **F3 spike resolved** the harness mechanics: async **park/notify/resume** (no persistent process — the gate parks with verdict `parked`, prints the resume paths `--resume <token>` / `--gui` card, and ends the run) and an **ephemeral + isolated** preview env (own DB + service, torn down after the decision; no `preview_env` provisioning ⇒ loud `preview-env-unprovisioned` degrade). This env is **preview-scoped only** — **v3.1/C23** generalizes it into the shared `needs_env` test-sandbox; not built here
- `.claude/skills/pre-merge/refs/platform/protocol-smoke.md`: Added (**C21/D27**, AC-SMK1–5) — the `smoke` component's dedicated home. A fired preview with no `smoke_cmd` now runs a **default-liveness floor** (URL 200 / artifact launches) instead of a silent skip, so C20's R1 health precondition can **never pass vacuously** (safety-floor pattern like C9, D28 present-but-hollow — AC-SMK1). A genuinely **un-smokeable** surface degrades **loudly** — a `high` `smoke-unsmokeable` finding surfaced in the R2 approval evidence, never silent green (AC-SMK2). Smoke runs the **critical-tagged e2e-flow subset** (1–3 golden paths incl. the core action — `e2e` owns the flows, D29; backend-only degrades to the liveness floor), not just a homepage 200 (AC-SMK3). It runs **first among the preview-tail checks and short-circuits** the expensive api-drift / migration up→down→up / capture suite on failure (`preview-unhealthy`) and feeds R2 evidence (AC-SMK4); a smoke failure **blocks the R1 approval prompt** — no approval is requested on an unhealthy preview (AC-SMK5). Shared surface with post-merge `--staging`'s deploy smoke-verify (`verify-deploy.md`)
- `.claude/skills/pre-merge/refs/platform/protocol-a11y.md`: Changed (**C13/D19**, AC-A11Y1–5) — `a11y` now audits **meaningful interactive states the e2e flows reach** (dialog open / validation error / menu expanded — D29, `e2e` owns the flows), not just static page loads, catching dynamic-state bugs (unlabeled dialog close, broken focus-trap) invisible to a static crawl (AC-A11Y1). Added **native a11y** — iOS/macOS `XCUIApplication.performAccessibilityAudit()` + Android accessibility-test-framework — turning C12's a11y gap into **real coverage** when the platform is targeted and a native runner is present (AC-A11Y2). Findings now **lead with user impact + flow**, WCAG id secondary (references `../../../shared/refs/name-the-user-impact.md` — AC-A11Y3). Default enablement/criticality is a **project-level `--init` decision** (public-facing → on/blocking; internal/backend → off/advisory — AC-A11Y4). Tagged **low-priority** in the build sequence (AC-A11Y5)
- `.claude/skills/pre-merge/refs/protocol-init.md`: Changed (**C13**, AC-A11Y4) — the per-component interview gains an **a11y-relevance `AskUserQuestion`**: is the project public-facing (product) or internal/backend (admin tool / service)? The answer sets the `a11y` component's default enablement + criticality in the manifest (public → default-on/blocking; internal/backend → default-off/advisory) — a11y is no longer an unconditional default. Policy, not a tool — nothing is installed
- `.claude/skills/post-merge/refs/human-test-script.md`: Changed (**C22 render site (b)**, AC-MTP6) — post-merge `--staging`'s Step 6 now **consumes the structured, significance-rated manual-test-plan** generated once at pre-merge (the machine artifact `.pre-merge/<ts>/manual-test-plan.json` **or** the run report's structured `## How to verify` section) and renders it **HIGH first** — instead of re-deriving the list from report prose. This is the **second render site** of the same generate-once checklist (the pre-merge preview gate is the first, C20/R2). A **graceful fallback** preserves the old prose-derivation (report `## How to verify` prose → acceptance criteria) when the artifact is absent (older/pre-C22 PRDs). The existing **STOP-and-sign-off** flow (Step 7 `AskUserQuestion`) and the verbatim write into the staging report are unchanged — only the *source* of the list changed. **The one approved post-merge touch in this plan** besides the P1 `--doctor`→`--init` rename; the post-merge *executor* is a separate future plan
- `.claude/skills/shared/refs/component-catalog.md`: Changed (**C21/C13**) — `smoke` (17) run-field + firming note gain the **default-liveness floor** + **critical-tagged e2e-flow subset** behavior (depends_on `preview` unchanged, still the 2nd hard edge; runs first + short-circuits + blocks R1). `a11y` (09) run-field + firming note gain **native-runner detection** (iOS/macOS `performAccessibilityAudit` + Android accessibility-test-framework), **interactive-state auditing**, user-impact framing, and the **project-enablement/criticality `--init` flag** (default `blocking` is the public-facing default, not unconditional). Still **17 live / 18 authored**, id 15 (`qa`) retired
- `.claude/skills/pre-merge/refs/executor.md`: Changed (**C21**) — the wave sequencing documents that `preview` first *fires* (provisions the ephemeral env), then `smoke` runs **before** `preview`'s expensive pre-approval work (captures + the api-drift / migration up→down→up live-env sweep + R2), and a `blocking` smoke failure **short-circuits** the rest (`preview-unhealthy`) and never serves the R1 prompt; the default-liveness floor means R1 can never pass vacuously
- `ARCHITECTURE.md`, `README.md`: Changed — the pre-merge pipeline description now reflects the **merged `preview` gate** (absorbs the retired `qa`; the sole human gate — captures visual states **and** stands up an ephemeral pokeable env for one unified Approve/Reject) and **`smoke` as its health precondition** (default-liveness floor + critical-path golden flows, runs first, short-circuits so a dead preview never reaches the human)

  **`preview` is the sole human gate; `smoke` guards it; both human gates render the same checklist.** P6 merges `qa`→`preview` (17→ still 17 live after C22's row 18; id 15 retired, never reused) and hardens the gate with R1–R4. The **F3 spike** resolved this harness's async/ephemeral mechanics — park/notify/resume (verdict `parked`, no persistent process) and an ephemeral + isolated preview env, **preview-scoped only** (v3.1/C23 widens it to the shared `needs_env` sandbox). The C22 manual-test-plan checklist (generated once at pre-merge, emit-only) is now **rendered at both human gates** — the preview approval artifact (C20/R2, site a) and post-merge `--staging`'s human-test-script (site b), which **consumes the structured artifact** with a prose fallback for older PRDs. Verdict/issues JSON shape held (AC-PF16) — only the `preview` Approve/Reject blocks; `manual-test-plan` stays emit-only. **This completes plan-msg-v3 (P0–P6)** — the post-merge executor refactor is a separate future plan (Phase 7, out of scope)

### [20] — v3 P5: native mobile, api breaking-change diff, perf ratchet + interaction, diff-scoped load + shared theme fragments

- `.claude/skills/shared/refs/ratchet-vs-base.md`: Added (**D21/F5**) — the shared **no-regression ratchet** pattern factored once: measure the base, compare **like-for-like**, apply a **noise margin**, and a **worsening vs base is a finding even with no absolute budget** (configured budgets stay the hard bar; the ratchet is additive); base unavailable → skip with a noted reason, never fabricate. Referenced (not restated) by coverage (C10), perf (C14), api contract-compat (C15)
- `.claude/skills/shared/refs/attribute-the-cause.md`: Added (**D22/F5**) — the shared **name the cause, not the symptom** finding pattern: correlate the breach with its specific culprit + suggest a fix, degrade honestly when the causal signal is absent (never fabricate). Referenced by perf bundle→import (C14), api contract-break→consumer (C15), load threshold→bottleneck (C16). Sibling of `name-the-user-impact.md`
- `.claude/skills/shared/refs/name-the-user-impact.md`: Added (**D20/D21/F5**) — the shared **lead with user impact + flow, id secondary** finding pattern (reuses the e2e-flow/state context per D29); the mechanical id stays as the dedup key, just not first. Referenced by a11y (C13, built P6), perf (C14), api (C15), mobile (C18)
- `.claude/skills/pre-merge/refs/platform/protocol-mobile.md`: Changed (**C18**, AC-MOB1–5) — `mobile` now **detects + runs native iOS XCUITest/XCTest (Swift) and native Android Espresso/JUnit (Kotlin)** alongside the preserved Flutter path (widget/integration + Patrol/Maestro) — a native app with no Dart files is **no longer green** (AC-MOB1); `mobile_runner` becomes a runner **set**. The declared `{platform, os}` matrix is **enforced**: a declared target with no available device/simulator (incl. **no macOS host** for iOS XCUITest) is a **`high` `platform-coverage-gap`** (ties to C12), never `pass_with_warnings` (AC-MOB2); a running native runner **satisfies** C12's native-mobile gap (AC-MOB3). Failures are **flow-named** (references `name-the-user-impact.md` — "swipe-to-delete broken on iOS 17", test name secondary — AC-MOB4); `--init` establishes the matrix when absent, Flutter path preserved (AC-MOB5)
- `.claude/skills/pre-merge/refs/platform/protocol-api.md`: Changed (**C15**, AC-API1–4) — added a **backward-compatibility spec-diff vs base** (`oasdiff`/`openapi-diff`): removed field / removed endpoint / optional→required / narrowed type / tightened enum → `high`/blocking (references `ratchet-vs-base.md` — contract-compat is the ratchet; base absent → `no_base_spec`, no fabricated break — AC-API1). A **valid-but-breaking** change that passes Spectral + updated contract tests is still caught (AC-API2). Findings are **consumer-named** (references `attribute-the-cause.md` + `name-the-user-impact.md`): Pact broker → declared `consumers[]` hint → **degrade to endpoint+change** (no fabricated consumer — AC-API3/API4). Rec #3 (live-server conformance) **noted PARKED to the `preview` pass**, not built
- `.claude/skills/pre-merge/refs/platform/protocol-perf.md`: Changed (**C14**, AC-PERF1–5) — `perf` now measures **interaction latency under e2e-flow-driven heavy state** (INP-under-load / long-task / scroll jank — D29: `e2e` owns the flows, perf consumes them; backend-only degrades to cold-load), not only Lighthouse cold-load (AC-PERF1). Added a **no-regression ratchet vs base** — runtime + bundle may not worsen vs base even with **no** absolute budget (references `ratchet-vs-base.md`, like-for-like + noise margin so jitter isn't a false regression — AC-PERF2/PERF5); **configured budgets stay the hard blocking bar** (config-driven `†` unchanged — AC-PERF3). Bundle findings **attribute the culprit import** + suggest a lighter alternative (references `attribute-the-cause.md` — AC-PERF4)
- `.claude/skills/pre-merge/refs/platform/protocol-load.md`: Changed (**C16**, AC-LOAD1–4) — `load` is now **diff-scoped**: runs **and** gates only when the PR touches an endpoint handler / shared data-access path (via the executor's `resolve-diff`), scoped to the affected endpoints; PRs touching neither **skip** load (AC-LOAD1). The profile uses a **declared read/write `traffic_mix`** (ratio + concurrency + think-time) and **exercises the write path** so contention surfaces; `--init` captures the mix with a sane default (AC-LOAD2). Breaches **name the bottleneck** (slowest endpoint / query / error cluster + suggestion — references `attribute-the-cause.md` — AC-LOAD3). Config-driven criticality unchanged — absolute thresholds stay the hard bar; diff-scoping governs *when* it runs, not *whether* thresholds block (AC-LOAD4)
- `.claude/skills/pre-merge/refs/universal/protocol-coverage.md`: Changed (**C10 back-reference**) — the existing total-coverage ratchet now **cites the factored `ratchet-vs-base.md`** as one of its three consumers (coverage + perf C14 + api C15); no behavior change
- `.claude/skills/shared/refs/component-catalog.md`: Changed (**C14/C15/C16/C18**) — `mobile` (14) detection field is now a **native+Flutter runner set** with the **enforced declared `{platform,os}` matrix**; `api` (11) gains the **spec-diff** tool + optional `consumers[]` hint; `perf` (10) notes the **ratchet + e2e-flow interaction**; `load` (12) `active_when` gains **`+ diff-scoped`** (new legend `ᵈ`) + declared `traffic_mix`. Firming-notes section rewritten for all four (native mobile is **real coverage**, no longer a C12 flag; the two ratchet + two attribute-the-cause consumers named)
- `.claude/skills/pre-merge/refs/protocol-init.md`: Changed (**C18/C15/C16**) — the per-component interview grows three compact `AskUserQuestion`s: the **mobile device/OS matrix** (enforced, AC-MOB5), the **optional api `consumers[]` hint** (when no Pact broker, AC-API4), and the **load read/write `traffic_mix`** (sane default, AC-LOAD2). All are policy, not tools — nothing is installed

  **Shared themes factored first (D21/F5).** The three recurring cross-component patterns are now **single fragments** under `shared/refs/` — the four platform protocols **reference** them rather than restating: `ratchet-vs-base.md` (coverage/perf/api), `attribute-the-cause.md` (perf/api/load), `name-the-user-impact.md` (a11y/perf/api/mobile). Verdict/issues JSON shape held (AC-PF16) — all changes are grading-logic + finding-framing within the existing envelope; no new top-level finding fields, no verdict-shape change. These are `active_when` surface-gated platform components, so on a skills repo most don't run live — this phase edits protocols + catalog + shared fragments, not runtime behavior.

### [19] — v3 P4: gate honesty (security floor, diff-coverage, prd-consistency grading, platform-gap, migration safety) + manual-test-plan

- `.claude/skills/pre-merge/refs/universal/protocol-security.md`: Changed (**C9**) — added the **guaranteed secret-scan floor**. When **no** secret scanner is detected, `security` emits a `blocker` (`rule: no-secret-scanner`, `safety-floor-unmet`) — there is **no green-gate path without secret-scan coverage** (AC-SF1/SF4). The blocker is not declinable at gate time; only `--init` recording a scanner (or the user installing one) clears it. SAST / deps / container / `/cook` layers stay best-effort — absence is a `skipped` note, never a blocker (AC-SF3). The scanner *install* stays per-item approved (`AC-DR2` preserved)
- `.claude/skills/shared/refs/safety-floor.md`: Changed (**C9**) — new "Secret-scan floor — never hollow" section recording the guarantee (no-scanner blocks, install stays gated); the always-on list now names the secret scan as a guaranteed floor
- `.claude/skills/pre-merge/refs/protocol-init.md`: Changed (**C9 + C17**) — `--init` **strongly offers** gitleaks and records declining it as an explicit **safety-floor gap** ("the gate will `blocker` until a secret scanner is configured"), not a quiet `opted_out` (AC-SF2); the install still goes through per-item approval. Added the **large/hot-tables** `AskUserQuestion` (C17) → recorded as the `migration` component's optional `hot_tables[]` hint (AC-MIG3)
- `.claude/skills/pre-merge/refs/universal/protocol-coverage.md`: Changed (**C10**) — coverage now **judges the diff**: **diff-coverage** (lines this diff touched, via the executor's `resolve-diff`) is the **blocking** signal, honoring config-driven criticality (blocking when a budget is set, advisory otherwise — AC-CV1/CV3); **total** coverage is advisory context + a **no-regression ratchet** vs base (total may not decrease vs base — a drop is a `coverage-regression` finding; a low total alone never blocks a well-covered diff — AC-CV2). Ratchet compares like-for-like vs base; base unavailable → skipped with `no_base_coverage`, never a fabricated regression; generated/test/mock exclusions unchanged (AC-CV4)
- `.claude/skills/pre-merge/refs/prd/protocol-prd-consistency.md`: Changed (**C11**) — rewritten from a 2-check binary pass into a **3-check, evidence-graded** pass (**coverage · error-cases · scope**). (1) each in-scope F-ID acceptance criterion graded by evidence: met+tested→pass, met+untested→`medium` `acceptance-untested`, unmet→`high` `acceptance-unmet` — static test-*existence* check, **stays Wave 1**, no new dependency (AC-PC1/PC2). (2) a third check consumes the eval digest's `error_cases[]` (no longer loaded-but-ignored): unhandled→`high` `error-case-unhandled`, handled+untested→`medium` `error-case-untested`, handled+tested→pass (AC-PC3/PC4). (3) scope-creep `out-of-scope` escalated `medium`→`high` (AC-PC5). Stage verdict = worst finding (AC-PC6). **Emits a machine artifact** `.pre-merge/<ts>/prd-consistency-grades.json` — a per-item `{id, kind, evidence}` grade for every acceptance criterion + error_case — that `manual-test-plan` (C22) reuses instead of re-walking the diff
- `.claude/skills/pre-merge/refs/executor.md`: Changed (**C12**) — new **§1b platform coverage-gap check** (post-detection, pre-ordering): for each repo **target** platform (from `devkit/PLATFORMS.md`), each **applicable** component (catalog `platforms` = applicability, not runner coverage — AC-GAP1) with **no detected runner** emits a `high` `platform-coverage-gap` naming platform + component + remediation (AC-GAP2/GAP3). Scoped: a component whose concern doesn't apply (e.g. `e2e` on iOS — owned by `mobile`) fires **no** gap (AC-GAP5); no declared target ⇒ no gap (AC-GAP6); AC-CAT14's documented gaps become **enforced** when targeted (AC-GAP4). Wave table updated so `manual-test-plan` joins Wave 2 (depends_on `prd-consistency`)
- `.claude/skills/pre-merge/refs/platform/protocol-migration.md`: Changed (**C17**) — added **expand/contract safety**: a same-PR `DROP`/`RENAME` column/table correlated (via `resolve-diff`) with app-code that still references the changed name → `high` `expand-contract-unsafe` with the add→backfill→dual-write→switch→drop remedy (AC-MIG1); **split across PRs → no finding** (AC-MIG2). Lock-risk findings (`CREATE INDEX` non-concurrent, table rewrites) now **scale severity by table size** — schema/stats hint else `--init`-declared `hot_tables[]` (large/hot escalates, tiny quiets); **no size context → current flat severity** (AC-MIG3/MIG4)
- `.claude/skills/shared/refs/component-catalog.md`: Changed — **new row 18** `manual-test-plan` (**C22**): group `prd`, kind `subagent`, criticality `advisory` (**EMIT-ONLY — never blocks the PR**, legend `ᵐ`), cost `moderate`, `active_when --prd`, `depends_on [prd-consistency]`, ref `prd/protocol-manual-test-plan.md`, check `preflight-check-18-manual-test-plan.sh`. **Count 16→17 live / 18 authored**; the **4th hard `depends_on` edge** (`manual-test-plan → prd-consistency`, amends AC-CAT3/AC-SEQ6 — one-directional, DAG stays acyclic) added to the Hard-edges list. Also: the C9 secret-scan-floor note on the `security`/`mandatory` entry, and the C17 optional `hot_tables[]` hint on the `migration` firming note
- `.claude/skills/pre-merge/refs/prd/protocol-manual-test-plan.md`: Added (**C22**) — the new component's protocol: maps every in-scope acceptance criterion + `error_case` + `edge_case` to a plain-language `do X → see Y` step (reusing `post-merge/refs/human-test-script.md`'s style + anti-fabrication rule — no invented steps), each rated `significance = user_impact × automation_gap` where **automation_gap REUSES C11's per-item evidence grade** (met+tested→low; untested/unmet & error-case untested/unhandled→high) — no diff re-walk (AC-MTP3/MTP8). HIGH first; the 🔴 HIGH set equals C11's untested/unmet items surfaced as human tasks (AC-MTP4). Writes the rated checklist to the report's `## How to verify` **and** a machine artifact `.pre-merge/<ts>/manual-test-plan.json`; C11 absent/errored → degrades to a priority-only list + a `degraded:true` note (AC-MTP8). **Emit-only invariant: never flips a verdict** (AC-MTP1)
- `.claude/scripts/preflight-check-18-manual-test-plan.sh`: Added (**C22**) — the row-18 detect script (prd-surface probe, same normalized `detect` shape as the other 16; kind=subagent so `run` names the protocol ref; `depends_on ["prd-consistency"]`; criticality `advisory`). Emits schema-valid JSON to `.pre-merge/preflight/manual-test-plan.json` + stdout
- `.claude/scripts/scan-prd-digest.py`: Changed (**C22**) — added `edge_cases[]` extraction (mirrors the `error_cases[]` table parse: id + scenario/condition + expected behavior) and included it in the **`eval` consumer slice** so `manual-test-plan` gets features + error_cases + edge_cases; `features` + `error_cases` continue to parse (AC-MTP7)
- `.claude/skills/shared/refs/report-schema.md`: Changed (**C22**) — the `## How to verify` section becomes a **structured, significance-rated** list on a `--prd` run (grouped 🔴 HIGH → 🟡 MEDIUM → 🟢 LOW), emitted alongside the `manual-test-plan.json` machine artifact the human gates render (C20/R2, post-merge `--staging`, both wired in P6); explicitly emit-only
- `.claude/skills/pre-merge/refs/severity-rubric.md`: Changed — added the `no-secret-scanner` (C9, blocker), `platform-coverage-gap` (C12, high), same-PR `expand/contract` (C17, high), and C11 acceptance/error-case grading rows to the base-severity + per-stage-floor tables; noted the repo-level C9/C12 findings are exempt from the out-of-diff file downgrade

  **manual-test-plan is EMIT-ONLY** — it is `advisory` and never contributes a blocker/high to the verdict; nothing in C22 can flip a `pass` to a `fail` (AC-PF16 verdict/issues JSON shape held). It adds the **4th hard `depends_on` edge** (`manual-test-plan → prd-consistency`); the DAG stays acyclic (prd-consistency `depends_on sync` only, no back-edge). Live component count **16→17**. `scan-prd-digest.py` gains the `edge_cases[]` digest field. The C20/R2 preview render and the post-merge `human-test-script.md` consumption are **P6** — this phase only makes the checklist artifact + report section exist.

### [18] — v3 P3: preflight-driven executor cutover (BREAKING)

- `.claude/skills/pre-merge/refs/executor.md`: Added — **the pipeline executor** (C1/C5/C6/C7). Reads the `components[]` manifest from `devkit/policy.json` → prunes to `present`/`mandatory` + `active_when`/flag-active components (an absent component produces **no** step and **no** skip note — AC-PF6) → topo-sorts on `depends_on`, ties broken by `criticality` then `cost` (AC-PF7) → runs independent components as **parallel-subagent waves**, dependents never concurrent (AC-PF8/9) → `SYNC` is the un-prunable DAG root, `OPEN-PR`/issues-loop the terminal (AC-PF10) → **fail-fast by criticality**: `critical` aborts the remaining pipeline, `blocking` fails the verdict + marks downstream `blocked` but lets independent branches finish, `advisory` never aborts (AC-PF11) → writes a per-check **result report** every run and aggregates them into the verdict + universal report (C6/C7). For universal+prd the topo-sort collapses the 6 old serial steps into 3 waves: `{mechanical·security·unit·integration·prd-consistency}` ‖ → `{coverage}` → `{regression}` tail (C5, AC-SEQ1)
- `.claude/skills/pre-merge/SKILL.md`: Changed (**BREAKING**) — "The gate sequence (Steps 0–9)" rewritten as a pipeline executor spine pointing at `refs/executor.md`; the per-step `steps.<key>` self-consult **retired** (superseded by component presence); pre-flight lifecycle table now gates on the **manifest** — no `components[]` (file absent, malformed, or a **pre-v3** policy with `init`/`release_flow` but no `components[]`) **refuses `no_manifest`**, names `/pre-merge --init`, runs **zero** components (Fork C, AC-PF13/PF14). The old "file absent → run on built-in defaults" fallback and the inline auto-`--init` are **retired** (`AC-LC6`/`AC-ST5` retired). Aggregate/emit now reads the per-check result reports as its single uniform input; `## Test results` is one line per check pass+fail; description + References repointed. **Verdict/issues JSON shape held (AC-PF16)** — `pipeline` (verdict JSON) and `checks[]` (issues file) are the only additions, both additive, never renames
- `.claude/skills/pre-merge/refs/refusal-patterns.md`: Added — the `no_manifest` refusal shape (`reason: "no_manifest"`, names `/pre-merge --init`, runs zero components); added to the intro + the refusal-vs-fail table
- `.claude/skills/pre-merge/refs/output-schema.md`: Changed — `no_manifest` added to the refusal `reason` enum; documented the **additive optional `pipeline`** observability field (resolved ordered waves + flag-pruned components — AC-PF15) and the **universal report** (`checks[]` additive to the pre-v3 issues-file `issues[]`+`context`+`summary`+`followUp`; `followUp.status` stays camelCase — AC-UR2/UR4). Both explicitly flagged additive, not renames (AC-PF16)
- `.claude/skills/pre-merge/refs/severity-rubric.md`: Added — the "Fail-fast by component `criticality`" section — the old fixed red-step short-circuit generalized to a DAG fail-fast keyed on `critical`/`blocking`/`advisory` (AC-PF11)
- `.claude/scripts/pre-merge-tooling-detect.sh`: **Removed** — the monolithic tooling detector is retired (AC-CK6); the `preflight-check-*.sh` family (sharing `preflight-common.sh`) + the resolved `components[]` manifest are the only detector now. Every live caller repointed
- `.claude/skills/shared/refs/{verify-prelude,tooling-detection,policy-schema}.md`, `.claude/skills/pre-merge/refs/{protocol-init,_common}.md`, `.claude/skills/pre-merge/refs/universal/{protocol-unit,protocol-integration}.md`, `.claude/skills/pre-merge/refs/stubs/pre-merge.yml`, `.claude/scripts/preflight-common.sh`: Changed — all `pre-merge-tooling-detect.sh` references repointed to the `preflight-check-*.sh` family / the resolved `components[]` `run` commands. The `verify-prelude` no longer caches a tooling fingerprint (executor reads the manifest); `tooling-detection.md` names the per-check family as the deterministic detector; `policy-schema.md` marks the pre-merge `components[]` executor **live** (no `components[]` → refuse), notes the v3 pre-merge override on the §0 `init` lifecycle, and retires the pre-merge `steps.<key>` consult + the `steps` dual-write in §3 / `protocol-init.md` (post-merge's `ci`/`deploy_*`/`smoke` step-keys unchanged)
- `ARCHITECTURE.md`, `README.md`: Changed — the "fixed 0–9 gate" language replaced with the preflight-driven pipeline model (manifest → prune → topo-sort → parallel waves → refuse `no_manifest` with no manifest); the scripts table swaps the deleted `pre-merge-tooling-detect.sh` row for the `preflight-check-*.sh` family

  **BREAKING (Fork C).** `/pre-merge` on a repo with no `components[]` manifest now **refuses** instead of running on built-in defaults — `AC-LC6`/`AC-ST5` retired. Run `/pre-merge --init` (which detects the pipeline and writes the manifest; a pre-v3 `policy.json` is upgraded in place). The emitted verdict/issues JSON **shape is unchanged** (AC-PF16) — `eng --build report=`, `fix-loop.md`, and `/msg --gui` keep working; only the *source* of the stages changed (fixed list → resolved `components[]` pipeline). The monolithic `pre-merge-tooling-detect.sh` is deleted.

  **F1 CHECK — PASS.** C6 writes a per-check result report on **every** run, including clean passes. Result JSON is deliberately lean (~250 bytes/check; a 10-component clean pass ≈ 2.5 KB, ≈ 650 tokens if re-read for aggregation). `evals/bench.py` post-cutover: the **per-run pipeline footprint dropped to 159,228 tok (−3.7% vs the P0 165,263 baseline)** — the executor reads a compact manifest instead of the monolithic `pre-merge-tooling-detect.sh` output + `steps.<key>` prose, so the run got *cheaper* even with C6's receipts. (Static ref surface grew +10.4% to 153,837 tok from the new executor/catalog/schema refs, but those are lazy-loaded — the per-run number is what fell.) C6 stays at always-write; no degrade needed.

### [17] — v3 P2: preflight check family + manifest assembly + --update

- `.claude/scripts/preflight-check-[01..17]-<slug>.sh` (16 scripts; id 15/`qa` retired): Added — the gate-neutral, one-per-check detect+normalize family (C4): mechanical, unit, integration, regression, security, coverage, prd-consistency, e2e, a11y, perf, api, load, migration, mobile, preview, smoke. Each is a thin wrapper that probes the project's **own** tooling/surface (never hardcodes a tool — AC-CK3) and emits one normalized check-report `detect` section to `.pre-merge/preflight/<slug>.json` + stdout (AC-CK2). Detection logic is mined + split out of the monolithic `pre-merge-tooling-detect.sh`; **new surface probes** added where the old detector had none — integration-test dirs (03), PRD dir (07), OpenAPI/Swagger spec (11), migrations dirs (13), native Xcode/Gradle projects (14), deploy/preview config (16), smoke suite (17). `[NN]` is a stable, never-reused, group-orthogonal catalog id, **not** run order (AC-CK1/SEQ7)
- `.claude/scripts/preflight-common.sh`: Added — sourced helper library (detection primitives + `mk_report` normalized emit) shared by all 16 checks; DRY so adding a component is one script + one catalog row (AC-CK7). Filename intentionally lacks the `preflight-check-` prefix so the check glob (ingestion / exit-check) skips it; running it directly is a harmless no-op
- `.claude/skills/shared/refs/check-report-schema.md`: Added — the **single** normalized check-report schema (resolves **Q8**: one schema, not two): a `detect` section (written now by the preflight scripts) + a `result` section (**written by the executor from P3** — documented now, not emitted this phase). Documents both artifact paths (`.pre-merge/preflight/<slug>.json` detect; `.pre-merge/<ts>/<slug>.json` result), the mandatory-always-emit note (AC-PF2), and the round-trip rule (AC-CK5)
- `.claude/skills/pre-merge/refs/protocol-init.md`: Changed — `--init` gains the preflight ingestion flow (run all `preflight-check-*.sh` → ingest the 16 reports → assemble `components[]` from catalog defaults + detection overlay + user overrides → validate the DAG is acyclic (AC-PF3) → write **no** `order` field (AC-PF4) → stamp `source_signature` (AC-UP4), keeping the interview/gated-install/`init:true` flip). Added the **`--update`** reconcile mode (re-scan → diff → approve delta → apply only `present`/`active_when`/new-component changes, never re-prompt settled opt-outs or re-grade user-set criticality (AC-UP1–4), reuse `--init`'s gated install for new gaps) + the **Q2** `steps.*`→`components[]` migration with dual-write of `steps` kept until P3, and the Fork-E read-only staleness nudge
- `.claude/skills/shared/refs/policy-schema.md`: Changed — added the `components[]` sub-schema (full per-component shape: `id`/`nn`/`group`/`kind`/`present`/`mandatory`/`active_when`/`criticality`/`cost`/`depends_on`/`run`/`tooling`/`status`; additive — AC-PF5; executor requires it from P3, **noted not enforced**), the `source_signature` staleness hash (precise sha256 definition), the Q2 `steps.*`→`components[]` mapping table, `generated_by` gains `pre-merge/post-merge --update`, and the `--update` writer row; `steps` marked deprecated-but-dual-written until P3
- `.claude/skills/pre-merge/SKILL.md`: Changed — Usage gains `--update`; the pre-flight lifecycle prose gains the read-only manifest staleness nudge (recompute `source_signature`, warn "run `/pre-merge --update`", proceed, never write — AC-UP5/6); References list the new preflight family + check-report schema, and mark `pre-merge-tooling-detect.sh` deprecated. **The gate sequence (Steps 0–9) is unchanged this phase** — Fork C flips at P3
- `.claude/scripts/pre-merge-tooling-detect.sh`: Changed — prominent DEPRECATED header only (superseded by the `preflight-check-*.sh` family; still consumed by the pre-P3 gate prelude; removed at P3). **No logic change** — AC-CK6's retirement is intentionally deferred to P3 since deleting now would change gate behavior
- `.gitignore`: Added — `.pre-merge/` (runtime preflight/result artifacts, never committed)

  **Gate behavior unchanged this phase.** The 16 scripts and the manifest are produced by `--init`/`--update` and read by the executor only from P3; today's Steps 0–9 gate still runs on `pre-merge-tooling-detect.sh` + `steps.*`. `install.sh` already ships `.claude/scripts/*` wholesale, so the new family and the common lib install without an edit.

### [15] — v3 build P0: pre-v3 token baseline recorded

- `evals/token-baseline.md`: Added — a dated **pre-v3 baseline** checkpoint (pipeline 165,263 tok/PRD; static surface 139,303 tok; pre-merge stage 22,514 tok) recorded before any plan-msg-v3 phase lands, so the P3 executor cutover and P6 close-out measure against a fixed number instead of an estimate
  - includes the F1 gate rule: the clean-run cost of C6's always-write result reports must stay ≤ ~5% of the pre-merge stage footprint at P3, else C6 degrades to fail/skip-only writes

### [16] — v3 P1: three-way protocol folders, component catalog, --doctor→--init rename

- `.claude/skills/pre-merge/refs/universal/protocol-unit.md`, `protocol-integration.md`: Added — the two missing universal protocols (Step 3's unit/integration halves), extracted from the old combined Step 3 semantics + `_common.md`'s `--flaky` contract; every universal component now has a dedicated file
- `.claude/skills/shared/refs/component-catalog.md`: Added — the keystone artifact: the 16-live/17-authored component table (entry schema `{id, nn, group, kind, criticality, cost, depends_on[], active_when, platforms[], mandatory, run, ref, check}`), the `qa`(15)-retired tombstone, the merged `preview`(16) human-review gate, the three hard `depends_on` edges, the only-on-green tier, and the platform-applicability legend
- `.claude/skills/pre-merge/refs/protocol-init.md`, `.claude/skills/post-merge/refs/protocol-init.md`: Changed — swept the body of both already file-renamed (`protocol-doctor.md` → `protocol-init.md`) specs from `--doctor`/"Doctor" prose to `--init`, added a one-line deprecated-alias note to each (`--doctor` still runs `--init` and prints a deprecation note for one release)
- `.claude/skills/pre-merge/SKILL.md`: Changed — every `refs/…` path repointed to the new `universal/`/`platform/`/`prd/` folders and `refs/_common.md`; `--doctor` → `--init` (+ alias line) in Usage, the pre-flight lifecycle table, and References; "platform buckets"/"bucket(s)" → "platform components"/"component(s)" throughout (except the literal on-disk `required_buckets` column name and the `bucket` wire-field keys other skills already read — both explicitly called out as unchanged this phase)
- `.claude/skills/pre-merge/refs/{output-schema,finding-schema}.md`, `refs/stubs/{README,pre-merge.yml,playwright.config.ts,vitest.config.ts,ruff.toml,eslint.config.js}`: Changed — remaining `--doctor`/"bucket" prose swept to `--init`/"component"; stub placeholders `[doctor: …]` → `[init: …]`; the literal `bucket`/`pre-merge:bucket:<name>` wire fields left untouched (documented as unchanged this phase, same reason as `_common.md`)
- `.claude/scripts/pre-merge-aggregate-verdict.sh`, `.claude/scripts/doctor-detect-repo.sh`: Changed — header/usage comments swept ("bucket" → "component", "--doctor" → "--init"/alias note); no logic, variable-name, or JSON-field changes (`BUCKETS`, `.buckets` stay as-is — literal wire contract); `doctor-detect-repo.sh` keeps its filename this phase
- `.claude/skills/post-merge/SKILL.md`, `.claude/skills/post-merge/refs/staging.md`: Changed — `--doctor` → `--init` (+ alias line) in Usage, the pre-flight lifecycle table, and References
- `.claude/skills/msg/SKILL.md`, `.claude/skills/msg/refs/protocol-init.md`: Changed — remaining `--doctor` prose updated to name `--init` (+ alias note) where it described the gate skills' setup mode
- `.claude/skills/shared/refs/policy-schema.md`: Changed — `generated_by` enum → `pre-merge --init` / `post-merge --init` (aliases noted); every prose `--doctor` reference in the lifecycle table, the writers table, the JSON example, and the validation rules updated to `--init`
- `ARCHITECTURE.md`, `README.md`: Changed — `--doctor` → `--init` (+ alias notes), "platform buckets" → "platform components" in the pre-merge pipeline description; `ARCHITECTURE.md`'s shared-skill paragraph now names `component-catalog.md`

  Strictly structural — zero behavior change; `--doctor` stays a deprecated alias for one release.

## 2026-07-16

### [14] — `/msg --init` now repairs older projects instead of dead-ending on them

- `.claude/skills/msg/refs/init/init-setup.sh`: Fixed — `ALL_COMPLETE` was computed from a `TARGETS` list that predated `INTAKE.md`, `devkit/PLATFORMS.md` and `devkit/policy.json`, so a repo bootstrapped before those existed reported "all foundational files exist", stopped, and could **never** receive them — even though `init.sh` writes any absent file
  - Added — the three missing files to `TARGETS`, plus a comment recording that this list gates the early exit, so a future file added without listing it repeats the bug
  - Added — `INITIALISED` (does a `devkit/` already exist?) and `ROW_GAPS` (rows a template gained after an existing file was written) to the scanner output
- `.claude/skills/msg/refs/protocol-init.md`: Added — a run-mode resolution at Step 1 (nothing-to-do / top-up / bootstrap) and **top-up mode**, which repairs an already-bootstrapped repo
  - it asks **only the questions the missing files need** — a repo missing only `INTAKE.md` asks nothing at all; production branch and language come from detection rather than questions
  - Added — Step 3b: missing template rows are **inserted** into existing files behind a preview and a confirmation, never rewriting a line that's already there
  - top-up skips the cto/eng mode gate: cto recommends an architecture for a project that doesn't exist yet, and a top-up repo already has one
- `.claude/skills/msg/refs/protocol-eng.md`: the interview accepts a required-variable subset and asks only what resolves it
- `.claude/skills/msg/SKILL.md`: document the top-up path

  **Strictly additive — nothing that exists is ever rewritten.** `init.sh` keeps its "writes only absent files" rule verbatim, which is why the row top-up lives in the skill instead. Verified on a simulated v1-era project: the unreachable files are created and hand-written `devkit/AHA.md` comes out byte-identical.

### [13] — Fixed: the PRD board showed every shipped PRD as un-shipped on a `master` repo

- `.claude/skills/msg/refs/gui/server.py`: Fixed — the completion ladder hardcoded `--base "main"` and `--base "staging"` instead of reading `devkit/policy.json`, so on a repo whose production branch is `master` the production rung never fired and every shipped PRD rendered as un-shipped
  - Added — a cached `release_branches()` helper reading `policies.release_flow.prod_branch` / `staging_branch`, with the `?? "main"` / `?? "staging"` fallbacks `shared/refs/policy-schema.md` already publishes; an absent or malformed policy degrades to those fallbacks so the board never errors
  - a custom staging branch name is now honoured too, not just `staging`

  Pre-existing defect, found during this refactor's GUI audit rather than caused by it.

### [12] — CLAUDE.md now tells every agent what language the project is written in

- `.claude/skills/msg/refs/init/templates/template-CLAUDE.md`: Added — a `**Language**` row to the Project section. `init.sh` already substituted `{{language}}`, but no template used the placeholder, so the language never reached the one file every agent reads on session start
- `.claude/skills/msg/refs/protocol-eng.md`: the note on why the `LANGUAGE` key survives its removed question now cites CLAUDE.md as well as the `.gitignore` selection

  Note: `/msg --init` is the only writer of CLAUDE.md and never overwrites an existing file, so this reaches **new bootstraps only** — projects that already have a CLAUDE.md keep theirs unchanged.

### [11] — `/msg --init` can now recommend your architecture instead of quizzing you about it

- `.claude/skills/msg/refs/protocol-cto.md`: Added — new advisory setup mode. Describe the project in your own words and msg recommends architecture, language, conventions, release flow and design system against five objectives, then derives every remaining variable from its own recommendations
  - the recommendations follow stated decision rules (less code is more, bias to agentic coding, comments carry the why, boring by default) — an unopinionated "it depends" is defined as a protocol failure
  - bounded at ≤4 questions; on reaching the ceiling it takes its own recommendation rather than asking again
- `.claude/skills/msg/refs/protocol-eng.md`: Added — the existing ask-and-build interview, now its own protocol and **six questions shorter**: team type, conventions, auth approach, production branch, staging branch, and the UI-layer gate are all gone
  - Changed — the interview budget drops from ≤5 calls (≤4 with no UI layer) to **≤4 (≤3 with no UI layer)**
  - Removed — the production/staging branch questions; branch topology is detected instead, so a `master` repo bootstraps a production branch that actually exists
  - Removed — the "does this project have a UI layer?" question; it's derived from the platforms you ship to, defaulting to yes when ambiguous so a design system is never silently dropped
- `.claude/skills/msg/refs/protocol-init.md`: Changed — Step 2 is now a mode gate that delegates to either protocol; both converge on the identical variable set, so the rest of setup never branches on the mode. `--init --cto` / `--init --eng` skip the gate; a bare `--init`, natural language, or an unrecognised sub-flag lands on it
- `.claude/skills/msg/refs/init/init-setup.sh`: Added — a sixth detection line (`LANG_DEFAULT`) mapping stack files to a language (`pubspec.yaml`→Dart/Flutter, `Cargo.toml`→Rust, `tsconfig.json`→TypeScript, …), so the language question is asked only when detection finds nothing
- `.claude/skills/msg/SKILL.md`: document the two sub-flags — msg's first — and the gate fallback
- `.claude/skills/msg/refs/init/init.sh`, `.claude/skills/msg/refs/init/templates/template-CLAUDE.md`: Removed — `TEAM_TYPE` end-to-end (msg is solo-only by design). `CONVENTIONS` survives: cto derives it, eng defaults it

### [10] — Todo tickets drop the `priority` field; fixes are ordered by severity, which is finer than before

- `.claude/skills/eng/refs/plan/template-todo.md`: Removed — the `priority` (`P0|P1|P2`) row from the ticket schema, the rendering block, and both worked examples; tickets now carry seven fields
  - the field's "deliberately not an estimate — no story-point / sizing field" note is preserved as a standalone rule; it outlives the field that carried it
- `.claude/skills/eng/refs/build/protocol.md`: Changed — build order among unblocked tickets is now **ticket-id order** (`F1-T1` → `F1-T2` → `F2-T1`), which is deterministic and reproducible across runs; `depends-on` ordering and the cycle/unknown-id hard stop are untouched
- `.claude/skills/eng/refs/build/report-fix.md`, `.claude/skills/eng/refs/plan/report-fix.md`: Changed — fix tickets order by `severity` directly (`blocker` → `high` → `medium` → `low`) and the derived severity→priority mapping is deleted; because that mapping collapsed `medium` and `low` into `P2`, ordering by severity is **finer** than before, not merely equivalent
- `.claude/skills/eng/refs/plan/protocol.md`, `.claude/skills/eng/SKILL.md`: "the eight fields" now reads "the seven fields"
- `.claude/skills/msg/refs/gui/server.py`, `.claude/skills/msg/refs/gui/index.html`, `.claude/skills/msg/refs/gui/styles.css`: Removed — the board's Priority column, pill, detail row, `.prio-P*` styles, and the GUI's private duplicate of the severity→priority map

  Note: the `/cook` standards floor uses `P0`/`P1` in an unrelated sense and was deliberately left untouched — a blanket sweep would have broken standards resolution on every build.

### [9] — Commit size is measured and judged, never vetoed by a line count guessed before the code exists

- `.claude/scripts/eng-commit-cap.sh`: Changed — the over-cap branch now exits 0 instead of 1, so the script measures rather than blocks; `CAP_OK`/`CAP_EXCEEDED <loc>/<cap>` still print, usage/env errors still exit 2
  - Removed — the single hard block in the whole A5 contract; the agent now reads the count and decides split-or-commit
- `.claude/skills/eng/refs/plan/template-todo.md`: Removed — rule 2's `<500`/`<300` LOC ticket-sizing cap; a ticket is now scoped to one coherent reviewable unit, because a line count predicted before the code exists is the fake precision the intake rubric already forbids
- `.claude/skills/eng/refs/plan/protocol.md`: Removed — the plan-time A1 ticket-sizing rule
- `.claude/skills/eng/refs/build/protocol.md`: `CAP_EXCEEDED` reworded from a hard stop to a judgment call; the `Oversize-reason:` trailer stays mandatory when committing over-cap; recurring oversize now feeds `devkit/AHA.md` only (its old "feed back to plan time (A1)" terminus no longer exists)
  - re-worded the two dangling references to the deleted plan-time rule
- `.claude/skills/eng/refs/build/pair-review.md`, `.claude/skills/eng/SKILL.md`: the pair-review cost bound is restated against the measured count rather than a guaranteed cap; the script is described as advisory
- `.claude/skills/plan-tune/refs/certification.md`, `.claude/skills/plan-tune/SKILL.md`: check 5 keeps its Critical graph-validity half (cycles, unknown ids, missing `done-when`) and drops size-feasibility; check 2 no longer cites the 300-LOC cap as a consumer

  Note: pre-merge's per-commit `commit-cap` audit is deliberately retained — it never blocked, it honours the `Oversize-reason:` trailer, and it is now the only signal showing whether commit judgment is drifting.

### [8] — Ideas are graded by how many moving parts they have, not how many files they touch

- `.claude/skills/intake/refs/rubric.md`: Changed — `C:` and `T:` move from `S/M/L/XL` + `$/$$/$$$` to a Fibonacci scale (`1/2/3/5/8/13`)
  - complexity anchors now count **moving parts** (business rules, application-logic units, integration points, platforms, migration/breaking surface), so a single module carrying six rules grades `C:5` instead of the smallest band — added a worked promo-code example proving it
  - the split gate fires at `C: ≥ 8` (six bands spread what four crammed into `XL`; firing on `13` alone would catch less than `XL` did)
  - Changed — the gate's rationale is now **reviewability**, not the deleted A5 LOC caps; the accept/decline behaviour is preserved because the `≥8` threshold depends on decline staying cheap
  - `S:` (sequencing) is untouched — it's a position, not a size
- `.claude/skills/intake/refs/protocol-intake.md`: the capture-time gate renamed to the `≥8`-split gate; re-grade guidance now `3`/`5`
- `.claude/skills/intake/SKILL.md`: trigger text and grading examples re-pointed to the new scale
- `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md`: the scaffolded ledger's documented scale now matches the rubric exactly
- `.claude/skills/msg/refs/gui/server.py`, `.claude/skills/msg/refs/protocol-gui.md`: grade-cell examples updated — the board's parser needed no change (`\bC:\s*(\S+)` already accepts any band)
- `.claude/skills/plan-pm/refs/protocol-pm.md`: reference to the split gate re-pointed

### [7] — `--doctor` now detects a missing CI pipeline and offers to set one up

- `.claude/skills/pre-merge/refs/stubs/pre-merge.yml`: new — minimal `pull_request` workflow stub the doctor scaffolds into `.github/workflows/`, with the detected mechanical/unit/security gate commands substituted in
- `.claude/skills/pre-merge/refs/protocol-doctor.md`: added the `ci` step — direct `.github/workflows/*` probe, a new "workflow-missing" gap flavor, and the scaffold-or-skip interview that writes `steps.ci`
- `.claude/skills/pre-merge/refs/stubs/README.md`, `.claude/skills/pre-merge/SKILL.md`: document the workflow-missing stub and CI-pipeline detection
- `.claude/skills/post-merge/refs/protocol-doctor.md`: branch-protection offer now guarded on a CI workflow existing — never bootstraps protection around checks nothing produces; delegates scaffolding to `/pre-merge --doctor`
- `.claude/skills/post-merge/refs/staging.md`: an empty PR check set (no pipeline ran) no longer passes as "green" — emits a `low` `vacuous-ci` note when `steps.ci` expected a workflow
- `.claude/skills/post-merge/SKILL.md`: document the protection guard
- `.claude/skills/shared/refs/policy-schema.md`: added `ci` to the closed step-key vocabulary (15→16) and its post-merge read-contract (the `vacuous-ci` note)
- `README.md`: `/pre-merge` and `/post-merge` rows note CI-workflow detection and the protection guard

### [6] — Publish the v1.1.0 user-facing release notes

- `RELEASES.md`: new — added the `v1.1.0 — 2026-07-16` section (user-facing notes for the `--doctor` gate setup, direct-flow shipping without a staging branch, self-fixing failed gate runs, and policy-conditional branch protection; covers changelog entries [3]–[5])

### [5] — Document the `--doctor` mode and `policy.json` in the project docs

- `ARCHITECTURE.md`: added `doctor-detect-repo.sh` to the scripts table; added `devkit/policy.json` to the devkit layer — the one co-written devkit file (seeded by `--init`, completed by `--doctor`, flipped by `--init-staging`) — with its init-gated pipeline behavior; noted `--doctor`/`--init-staging` on the skill surface
- `README.md`: the `/pre-merge` and `/post-merge` rows now describe `--doctor`; new `/msg --init-staging` row; `/msg --init` notes the release-flow interview + `policy.json` seed; post-merge branch protection flagged policy-conditional (enforced/optional/skip)

### [4] — One-time `--doctor` setup for the gates: detect tooling, record release + protection policy

- `.claude/skills/shared/refs/policy-schema.md`: new — canonical `devkit/policy.json` schema, fail-safe validation rules, and the gate read-contract (init lifecycle, release_flow, branch_protection, per-step decisions) both gates consult
- `.claude/skills/pre-merge/refs/protocol-doctor.md`: new — `/pre-merge --doctor` spec: detector-null→gap mapping, the three-flavor gap taxonomy, the OSS-first (free-only) install catalog, gated interview, and stub scaffolding
- `.claude/skills/post-merge/refs/protocol-doctor.md`: new — `/post-merge --doctor` spec: branch-topology + branch-protection (Free-plan-403 auto-detect) + deploy/smoke CLI detection, PLATFORMS.md gaps delegated to `/msg --init`
- `.claude/scripts/doctor-detect-repo.sh`: new — read-only probe of repo visibility, branch-protection availability, and staging/prod topology → JSON for the doctor to consume
- `.claude/skills/pre-merge/refs/stubs/`: new — minimal runnable config templates (eslint, biome, prettier, ruff, vitest, playwright, size-limit) the doctor scaffolds for config-missing tools
- `.claude/skills/pre-merge/SKILL.md`: `--doctor` usage, an `init` pre-flight that auto-runs the doctor until setup completes, `release_flow`-based PR base, and a Steps 2/3/5/6 policy consult — an absent `policy.json` keeps today's behavior
- `.claude/skills/post-merge/SKILL.md`: `--doctor` usage, the `init` pre-flight, policy-conditional branch protection (enforced/optional/skip), and release-flow handling incl. the direct-mode single ship
- `.claude/skills/post-merge/refs/protection.md`: branch-protection precondition is now policy-conditional — only `enforced` refuses on unprotected; `optional` warns and proceeds, `skip` skips
- `.claude/skills/post-merge/refs/refusal-patterns.md`: `unprotected` refusal made conditional; new `no_staging_stage` refusal for direct-mode `--staging`
- `.claude/skills/msg/SKILL.md`: `--init` now captures the release flow and seeds `policy.json`; new `--init-staging` mode adds a staging branch and flips the flow to staged
- `.claude/skills/msg/refs/protocol-init.md`: the `--init` interview gains the release-flow call and the idempotent `policy.json` seed write

### [3] — Add the failure→fix→re-gate loop and unify run reports into one artifact per run

- `.claude/skills/shared/refs/fix-loop.md`: new — after a failed pre-merge/post-merge run, a two-offer sequence walks the user from "issues found" to "fixes planned + built": Offer #1 runs `eng --plan report=` (writes a fix plan), Offer #2 runs the orchestrated `eng --build report=`. Autonomy-aware (both offers pre-approved under a roadmap orchestrator)
- `.claude/skills/eng/refs/plan/report-fix.md`: new — the `eng --plan report=` source; projects the issues file's findings into a fix plan (exec-table + fix tickets), one ticket per issue, each tagged `complexity: simple|complex`
- `.claude/skills/eng/refs/build/report-fix-orchestrated.md`: new — the default `eng --build report=` route; an Opus orchestrator grades each issue's complexity and fans the fixes out to per-issue subagents (`model: sonnet` simple / `model: opus` complex), one commit per issue, re-verifies each ticket, then writes `followUp.status`
- `.claude/skills/eng/refs/build/report-fix.md`: renamed from `protocol-build-gatejson.md`; routes the fix build to the orchestrated ref by default (`orchestrate=off` escape hatch to the flat flow)
- `.claude/skills/eng/SKILL.md`, `refs/build/protocol.md`, `refs/build/protocol-roadmap.md`, `refs/plan/template-todo.md`: the eng fix flag `gate-json=` is now `report=`; `--plan report=` is now accepted (was a hard failure)
- `.claude/skills/pre-merge/SKILL.md`, `.claude/skills/post-merge/SKILL.md`: on a failed run write the colocated machine issues file and hand off to `fix-loop.md`; post-merge now enters the loop on a deploy/smoke failure (both modes) instead of dead-ending; terminal issue-count block printed on every report write
- `.claude/skills/shared/refs/report-schema.md`: unified run report — the three forms of a run share one stem in `features/prd-<N>-<slug>/reports/`: `report-prd-<N>-<K>.md` (human), `report-prd-<N>-<K>.json` (machine issues, on failure), `report-prd-<N>-<K>-fix-plan.md`; per-PRD `K` numbering; new `## Issue summary` body section
- `.claude/skills/shared/refs/finding-schema.md`, `.claude/skills/pre-merge/refs/output-schema.md`, `refs/mechanical.md`, `refs/regression.md`, `.claude/skills/post-merge/refs/staging.md`, `refs/production.md`: retired the `msg-gate/gate-<n>.json` / `gate-json` vocabulary in favour of the issues file
- `.claude/skills/msg/refs/gui/server.py`, `index.html`, `.claude/skills/msg/refs/protocol-gui.md`: the GUI reads the issues `.json` from the reports folders (not `msg-gate/`), skips `-fix-plan.md` when collecting reports, and deep-links `report=`
- `.claude/scripts/pre-merge-aggregate-verdict.sh`, `.claude/skills/improve/plan-msg-v2.md`: stale-token cleanup

## 2026-07-14

### [2] — /pre-merge now works in repos with no staging branch instead of refusing

- `.claude/skills/pre-merge/SKILL.md`: staging→main fallback threaded through the constraints, the Inputs/Outputs base row, the Step 1 sync + Step 9 PR-base rows, and the `followUp.suggested_command` PR base — a missing `staging` is no longer a blocker
- `.claude/skills/pre-merge/refs/sync.md`: precondition 2 now resolves the sync target (`staging`, else `main`) instead of refusing; merge command and sync-merge commit message parameterised on the resolved target
- `.claude/skills/pre-merge/refs/refusal-patterns.md`: Removed — deleted the retired `no_staging` refusal section and its outcomes-table row
- `.claude/skills/pre-merge/refs/output-schema.md`: dropped `no_staging` from the refusal `reason` enum

### [1] — Drop the one-time install manifest now that its purge has run

- `remove-manifest.txt`: deleted — the removal list it shipped has already been scrubbed from every global install
- `install.sh`: removed the manifest-driven removal block (parser, guardrails, `rm -rf` loop)
- `ARCHITECTURE.md`: dropped the removal-manifest paragraph from the install-layer description

- **post-merge now verifies its deploys — a smoke check runs after every staging and production deploy.** "The deploy command exited 0" is no longer treated as "the app works": both modes gain a verification step that runs each shipping platform's new `smoke_cmd` (a `devkit/PLATFORMS.md` column — e.g. `curl -f <health url>`) against the **deployed** target. Exit 0 → verified; non-zero → a `high` `smoke-failed` finding and verdict `fail` — in `--staging` (new Step 5) the human test script + sign-off are skipped (never hand a human a script for a broken environment; fix forward via `/pre-merge`), in `--production` (new Step 7) the intake `completed` stamp is skipped (an unverifiably-live release doesn't close its PRD) and the per-platform rollback notes are surfaced prominently. Unconfigured / `[USER: …]` smoke cells skip verification with a visible note — never invented, never a failure — so existing PLATFORMS.md files stay valid. The clean-run summary gains a `verify: { ran, passed, skipped }` block and the run report a per-platform verified/smoke-failed/skipped line; new hard refusal: post-merge never reports a deploy as shipped without running (or explicitly noting the absence of) the smoke check.
  - `.claude/skills/post-merge/refs/verify-deploy.md` — new: the verification contract (resolve, run, finding shape, per-mode consequences, summary block)
  - `.claude/skills/post-merge/refs/staging.md` + `refs/production.md` — verify steps inserted; human-script/sign-off and intake-stamp steps renumbered + gated on a verified deploy
  - `.claude/skills/post-merge/SKILL.md` — mode tables now Steps 1–7 (staging) / 1–8 (production); smoke-check hard refusal; verify-deploy ref listed
  - `.claude/skills/post-merge/refs/output-schema.md`, `refs/deploy.md`, `refs/human-test-script.md` — `verify` block, verdict rules, and step cross-references aligned
  - `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md` — new `smoke_cmd` column (contract row, header, all four platform default rows)
  - `README.md`, `ARCHITECTURE.md` — post-merge descriptions gain the smoke-verify step
  - `.claude/kermit/pref.json`, `.gitignore` — kermit pref/state split migration (volatile state moved to git-ignored `state.json`)

- **Remove flash mode from the msg harness — comprehensive is now the only run mode.** The two-mode system (comprehensive vs flash) is retired: flash traded execution count for speed, and every skill now always runs its full comprehensive protocol. Deleted the shared mode machinery — `shared/refs/mode-resolution.md` (precedence resolver) is gone, and `shared/refs/flash-floor.md` is replaced by mode-neutral `shared/refs/safety-floor.md` (the never-relaxed write-power/human-gate/pause floor, with all flash framing removed). Every per-skill `refs/flash/mode-flash.md` deleted, every `--flash` flag and Step-0 mode-resolution pointer stripped from SKILL.md files and protocols, the `/msg --set-mode` command and flash-only quick paths (`/msg --init --flash`, `/msg --flash`, `/intake --flash`) removed. The safety floor, all human gates, and every pause are preserved unchanged (they were never mode-dependent). Stale `--flash` flags on any skill are silently ignored. Done in phased commits (P1 shared core → P7 root docs); skill-internal ref integrity verified clean before and after.
  - P1 — shared core: `safety-floor.md` replaces `flash-floor.md`; `mode-resolution.md` deleted; three surviving safety-floor references repointed.
  - P2 — deleted the six per-skill `refs/flash/` directories (eng plan+build, plan-tune, plan-em, plan-pm, pre-merge — 7 files).
  - P3 — eng skill: dropped the `--flash` routing rows and the Step-0 mode-resolution sentence from SKILL.md; removed the roadmap "Mode propagation" paragraph; stripped every "skipped in flash" note from pair-review and build protocol.
  - P4 — plan-tune / plan-em / plan-pm: removed `[--flash]` from invoke lines, deleted each Flash-mode paragraph and refs bullet, and dropped plan-em's forwarded-mode dispatch bullet and the protocol-em flash parenthetical.
  - P5 — pre-merge / intake / post-merge: deleted the `/pre-merge --flash` flag and intake's Flash-mode paragraph, collapsed post-merge's "No flash mode — ever" note to a mode-neutral "ship gates never collapse", and dropped the "or flash" clause in pre-merge sync.
  - P6 — msg skill: removed `--set-mode` from the description and the entire `## Protocol: --set-mode` section, deleted the `/msg --flash` and `/msg --set-mode` invoke lines and the default-protocol "Show active mode" step, dropped `--init --flash` / `--flash` mentions, and renumbered the dispatch list.
  - P7 — root docs: retitled the ARCHITECTURE and README "Run modes" sections to "Safety floor" (mode framing removed) and dropped every "no flash mode" note; retired the obsolete root `msg-minor.md` flash-residuals doc. (Local, gitignored `evals/bench.py` also de-flashed so it keeps running; comprehensive footprint 162,962 tok.)

- **msg v2 P7 — certification layer: plan-tune is a 7-check contract certifier; plan-em enforces it on both waves (Part G, I2, I3).** plan-tune is rebuilt from a 5-dimension adversarial auditor into a **contract certifier** (D17): the v1 "assume the PRD is broken, audit everything" posture is retired for a fixed **seven-check certification**, each check bound to a named downstream consumer that executes a PRD field *blindly* — **governing rule: no check without a consumer.** Checks: (1) criteria testability → regression authoring + pre-merge PRD-consistency; (2) breaking/DB surface labeled → the 300-LOC cap, pre-merge breaking pause, plan-pm critical pause, `eng-db-touch.sh`; (3) intent fidelity vs the intake row → the only guard on autonomous plan-pm drift; (4) exec-table/eng-section integrity → `eng --build` reads + `plan-em-exec-collision.py`; (5) ticket sizing + graph validity → the A5 cap + `eng --build` ordering (hard-stops on cycles/unknown ids); (6) frontmatter graph (+ platform-profile bucket coverage, D12) → roadmap sequencing, plan-em preflight, pre-merge bucket selection; (7) cross-agent integration-contract coherence → parallel build agents that build against each other's contracts blindly. Product tune runs 1/2/3/6 on the `product` slice; eng tune runs 2/4/5/6/7 on the `eng-audit` slice **only** (the v1 eng tune's redundant second product-slice read is gone). **Autonomy (D15):** the 4-step flow collapses to 3 — tune-type is auto-selected (no ask), every Critical+Major is auto-fixed and emitted as a `# | Sev | Found | Fixed` terminal table, one Minor ask remains, and a product-decision finding is the only hard pause (the v1 tune-type ask, fix-selection multiSelect, and step-4 human gate are all deleted). **Self-healing (D16):** each auto-fixed Critical/Major appends a `[tune:<category>]` learning to `devkit/AHA.md` — which plan-pm already reads pre-draft and intake reads for grading calibration, closing the loop with zero new plumbing; a category recurring across ≥3 runs emits a protocol-repair flag (fix the drafting protocol, not the PRDs). **plan-em (I2/I3/I5):** the certifier now auto-runs inline as a **precondition** before each wave — `plan-tune --product` before the plan wave (Step 2), `plan-tune --eng` before the build wave (Step 4, D18) — no ask, closing the v1 hole where the eng tune was merely *recommended*; Step 1c's three per-relationship AskUserQuestions are **deleted** (plan-em consumes the intake-graded + certifier-verified graph silently and asks only on a genuine graph-vs-scan conflict — zero relationship questions on a clean run); the synth eng-tune menu option is deleted (I5), and Critical synth findings are batched, not a blocking terminal gate. The §9 findings-table schema is preserved verbatim — the GUI parser and plan-pm's template-prd §9 are untouched. Bench: pipeline **178,141 → 163,904 tok** (P7 cut ~14.2k; the eng tune's dropped second-slice read + `tune-product.md`+`tune-eng.md` → one `certification.md`); **cumulative vs the original v1 baseline: −56.9%** (380,704 → 163,904), clearing the ≥40% gate. *Residual: the full live intake→…→pre-merge autonomous dry run needs a multi-session LLM pipeline (bench.py is a token model, not an executor) — mechanically verified instead via the seeded PRDs' certifier inputs + precondition stamps (clean-run path coherent).*

- `.claude/skills/plan-tune/` — SKILL.md rebuilt (certifier persona, 3-step flow, auto-select/auto-fix/self-heal); new `refs/certification.md` (the 7 checks + consumers + severity rubric + §9 schema + terminal table + AHA loop); `refs/tune-product.md` + `refs/tune-eng.md` deleted; `refs/flash/mode-flash.md` re-cut to the critical subset of the 7 checks
- `.claude/skills/plan-em/` — `refs/protocol-em.md` Step 2 = product certification precondition (auto-run, was an ask), Step 4 build branch = eng certification precondition, Step 1c = certified-graph consumption (relationship AUQs deleted), Step 5 eng-tune menu option removed + synth Criticals batched; SKILL.md + `refs/flash/mode-flash.md` aligned (roster is the single gate)
- `.claude/scripts/scan-prd-digest.py` — `eng-audit` slice gains `exec_table` + `todos` (checks 4/5 inputs)
- `README.md`, `ARCHITECTURE.md`, `.claude/skills/msg/SKILL.md`, `.claude/skills/msg/refs/init/templates/template-CLAUDE.md` — plan-tune re-advertised as contract certifier; plan-em's inline certification documented as a deliberate autonomous exception
- `evals/bench.py` — plan-tune stages repointed at `certification.md`, eng tune drops the second product-slice read; `evals/token-baseline.md` — P7 milestone (−56.9% vs v1)
- `.claude/skills/improve/plan-msg-v2.md` + `_INDEX.md` — plan marked shipped (P1–P7 complete)

- **msg v2 P6 — intake layer + autonomous plan-pm (Part F, H2, H5).** New `/intake` skill is the planning front-door: captures feature ideas and bugs as rows in a root `INTAKE.md` ledger (`# | date | type | idea | goal | grade | status | prd`, D13 — repo root, not devkit) and **owns the requirements interview** that used to live in plan-pm (flesh out thin ideas, proactively suggest adjacent ideas, ask for the core goal — batched, ≤2 AskUserQuestion calls for a well-formed idea). Hybrid asks ("streaks + notifications + rewards") split into discrete rows at capture — this replaces plan-pm's epic-split gate. Every idea gets a **single-turn banded grade** (`C: S/M/L/XL` complexity, `T: $/$$/$$$` token cost, `S: now/next/later/blocked-by-#n` sequencing) — never an analysis pass, fake-precise numbers forbidden by the template; an `XL` grade fires the split question (front-door defence of the commit caps). **plan-pm is now an autonomous PRD writer** (F3): the 5-question interview and epic gate are deleted (interview-parity audited — every old capture now comes from the intake row, autonomous drafting, or a batched open question); no-args lists non-completed intake rows; the full PRD (edge cases, features/acceptance, flows, error handling) is drafted solo; it pauses ONLY for batched open questions and breaking/critical touches, then terminates with one follow-up ask, recommending plan-tune --product. Lifecycle stamps wired (D14): intake writes `backlog` → plan-pm stamps `in-progress` + the `prd-<n>` mapping → post-merge --production stamps `completed`. GUI gains the **Intake tab** (H2): lanes backlog/in-progress/completed, three grade chips per card, PRD cross-links; INTAKE.md **status cells are the only new GUI write path** (H5 — the `prd` mapping stays plan-pm-owned, read-only). `/msg --init` scaffolds INTAKE.md from new `TEMPLATE-INTAKE.md`, idempotent. Bench: intake costs 3.7k tok once per idea; plan-pm main drops 11.5k → 10.0k.

- `.claude/skills/intake/` — new: SKILL.md, refs/protocol-intake.md (capture flow), refs/rubric.md (C/T/S bands + single-turn constraint)
- `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` — new; init.sh scaffolds root INTAKE.md
- `.claude/skills/plan-pm/` — protocol-pm.md rewritten (5-step autonomous flow), protocol-interview.md deleted, SKILL/flash/sub/roadmap/template refs aligned; --roadmap reads intake `S:` grades
- `.claude/skills/post-merge/refs/production.md` — stamps shipped PRDs' intake rows `completed`
- `.claude/skills/msg/` — GUI Intake tab (server.py build_intake + status endpoint, index.html lanes/chips, styles, protocol-gui.md); menu/--help/README/ARCHITECTURE start the pipeline at intake
- `evals/bench.py` — intake stage added; plan-pm interview ref pruned

- **msg v2 P5 — ship layer: post-merge takes staging → main (Part C, H1, H4).** New `/post-merge` skill — the harness's ONLY merger, with NO flash mode (ship gates never collapse). `--staging` (C1): verify the feature→staging PR's CI is green (branch protection enforces; this is the check) → merge → run the platform's `staging_deploy_cmd` from devkit/PLATFORMS.md (template extended with `staging_deploy_cmd` + `production_deploy_cmd` columns) → emit a human test script derived from the report's "How to verify" + acceptance criteria → STOP (post-merge never self-certifies staging) → on explicit approval stamp `staging-signoff: <date>` into the PRD frontmatter (D11's harness-readable half). `--production` (C2): refuses without the stamp + green staging; double-confirmation (intent, then a final confirm listing exactly what ships); opens a release-style staging→main PR (PRDs, reports, per-platform rollback notes, iOS flagged IRREVERSIBLE); merges only on green CI + the required human GitHub review. New `.claude/scripts/post-merge-protection.sh` (C3): `--bootstrap` sets required status checks (+ optional `--contexts "ci/pre-merge"` so a named red check hard-blocks a PR), no-force-push on staging+main, and ≥1 required review on main (D11's machine half) via `gh api`; `--verify` emits `PROTECTED`/`UNPROTECTED <missing>` machine lines (validated live against this repo) and post-merge Step 1 refuses when unprotected; `/msg --init` offers the bootstrap when a GitHub remote exists. **`shared/refs/flash-floor.md` rewritten to Safety floor v2:** per-skill write powers replace the blanket "never push/PR/merge" (eng → feature branches only; pre-merge → one PR + sync-merge, never merges; post-merge → the only merger; nothing reaches main except the double-confirmed release), human gates never removed (preview approval, staging sign-off, production double-confirm), v1 items unchanged. Roadmap orchestrator rewired: per-PRD chain `eng --build → pre-merge → post-merge --staging → STOP` — `--production` is always human-initiated, never orchestrated. GUI: completion ladder v2 (H1 — override → shipped → staged·human-approved → staged → gated → building → planned → product, PR rungs via gh with silent degrade), board pills/columns for the new states, post-merge reports in the per-PRD grouping with the staging human-test script and a prominent IRREVERSIBLE callout (H4). *Deferred AC: the live "protection blocks a red PR" test needs a user-named scratch GitHub repo (autonomous repo creation is permission-gated) — script payloads JSON-validated and `--verify` exercised live instead.*

- `.claude/skills/post-merge/` — new: SKILL.md + refs (staging, production, protection, deploy, human-test-script, refusal-patterns, output-schema)
- `.claude/scripts/post-merge-protection.sh` — new: bootstrap/verify branch protection (+`--contexts`)
- `.claude/skills/shared/refs/flash-floor.md` — Safety floor v2 rewrite; `report-schema.md`/`finding-schema.md` gain post-merge
- `.claude/skills/eng/refs/build/protocol-roadmap.md` — chain ends at `post-merge --staging`; production never orchestrated
- `.claude/skills/msg/` — GUI ladder v2 + IRREVERSIBLE rendering (server.py, index.html, styles.css, protocol-gui.md); menu/--help post-merge row; --init protection-bootstrap offer; PLATFORMS template deploy columns
- `README.md`, `ARCHITECTURE.md` — pipeline through post-merge; scoped write powers; script table

- **msg v2 P4 — pre-merge is THE CI gate; /review and /test are retired (Part B, H3, I5-partial).** The rebuilt `/pre-merge` takes a feature branch from "eng says done" to "PR open against `staging` with green checks and a human-approved preview" through gate sequence 0–9: platform-mode resolution from new `devkit/PLATFORMS.md` (strict/standard/lenient tolerance profiles; scaffolded by `/msg --init`, whose interview gains exactly one platforms question) → SYNC (D7: trivial conflicts auto-resolved, semantic same-hunk pauses; the sync-merge commit is pre-merge's only direct write) → MECHANICAL (lint/format/typecheck + comment-scan + per-commit cap audit, scripts not LLM) → UNIT+INT re-run post-sync → REGRESSION (D9: a spawned eng subagent authors this PRD's tests to `tests/regression/prd-<n>/` and commits them once graded green — pre-merge never authors what it grades; D5: prior-test edits require a PRD-clause citation or grade `high`) → PLATFORM BUCKETS (e2e/qa/mobile/perf/a11y/coverage/api/load per profile, migrated from /test with `--flaky`/`--changed-only`) → SECURITY+MIGRATION (the two surviving review stages, safety floor in every profile) → PRD-CONSISTENCY (one spec-match pass replacing review's Functional mode, with a vacuous-pass guard) → PREVIEW DEPLOY (D6 path heuristic; D10 `preview_kind` url/artifact/screenshots; blocks on human approval) → OPEN PR feature→staging. Fail loop renamed: `msg-gate/gate-<n>.json` → `eng --build gate-json=` (was msg-test/test-json); GUI's Test Issues tab becomes **Gate Issues** with per-gate-step source badges. Scripts renamed `pre-merge-tooling-detect.sh`/`pre-merge-aggregate-verdict.sh`; `test-init-profile.sh` retired; manifest += review, test + 3 old script names. A live smoke run on a seeded PRD came back clean (`pass_with_warnings`, 1 justified low) and its six robustness findings were fixed in-phase (Step-3 null-runner guard + bare-pytest detection, resolve-diff.sh de-rtk'd, local-staging merge fallback, vacuous-pass guard, `/cook`-missing degrade paths, regression-test commit ownership, `followUp` casing aligned). Bench: pipeline 185.4k → **159.9k tok** (review 25.2k + test 19.1k out; pre-merge 9.6k → 21.4k absorbing them); static surface 137.9k → **100.9k** (−26.8%).

- `.claude/skills/pre-merge/` — SKILL.md rebuilt as the gate spine; new refs: platform-profiles, sync, mechanical, regression, buckets/{_common,e2e,qa,mobile,perf,a11y,coverage,api,load}, security, migration, prd-consistency, preview; flash = mechanical+unit/int+security only; bucket-runners.md superseded
- `.claude/skills/review/`, `.claude/skills/test/` — deleted (27 files); useful content migrated into pre-merge refs
- `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md` — new; `protocol-init.md`/`init.sh` scaffold devkit/PLATFORMS.md from the P1 interview answer
- `.claude/skills/eng/` — `test-json=` → `gate-json=` (file renamed protocol-build-gatejson.md), msg-gate/gate-<n>.json paths, roadmap chain repointed to pre-merge
- `.claude/skills/plan-em/` — `/test --prd` eval-set preview deleted (I5); references scrubbed
- `.claude/skills/msg/` — GUI Gate Issues tab (gateIssues key, srcBadge per gate step, gate-json deep-links); menu/--help rows for review/test removed
- `.claude/skills/shared/refs/` — finding/report schema source enums re-cut to pre-merge stages; verify-prelude producer = pre-merge; session-cache/tooling-detection consumers updated
- `.claude/scripts/` — pre-merge-tooling-detect.sh (+ bare-pytest signal), pre-merge-aggregate-verdict.sh renamed in; test-init-profile.sh deleted
- `remove-manifest.txt` — += skills/review, skills/test, scripts/test-{tooling-detect,aggregate-verdict,init-profile}.sh
- `evals/bench.py` — manifest models the v2 pipeline (review/test stages removed; pre-merge gate stages + pair-review/template-todo fan refs)
- `README.md`, `ARCHITECTURE.md`, `.claude/settings.json` — pipeline/inventory/scripts scrubbed; stale test permissions dropped

- **msg v2 P3 — install layer: manifest-driven removals (Part E).** Retiring a skill is now a one-line data change, not a script edit: new `remove-manifest.txt` at repo root ships 9 entries (`skills/msg-init` — previously hardcoded — plus `docu`, `handoff`, `ship`, `plan`, `design`, `improve`, and the orphaned `scripts/ship-db-touch.sh` + `ship-find-prd.sh`); install.sh reads it from the cloned repo after the install-skills loop and `rm -rf`s each entry under `~/.claude/`, logging `Removed retired: <entry>` (absent target = silent idempotent skip). Guardrails in the parser: exact paths only (globs `*?[` rejected), no `..`/absolute/backslash paths, entries must be exactly `skills/<name>` or `scripts/<file>` with one segment after the prefix (so `skills/plan` can structurally never touch `plan-em`/`plan-pm`/`plan-tune`), and an entry the current run also installs is skipped as a manifest bug — with `skills/improve` exempted from that conflict check because it lives in the source tree but is now **excluded from the copy loop entirely** (repo-internal plan tracker; the stale global copy gets scrubbed, and it never ships again). `MSG_REPO` became env-overridable (dry-run/pin hook). Verified against a scratch `$HOME`: all 9 retired artifacts removed, `plan-em`/`plan-pm`/`plan-tune`/`eng`/`msg` untouched, second run fully silent, all seven malicious-entry probes rejected.

- `remove-manifest.txt` — new: 9 retirement entries + format doc
- `install.sh` — manifest reader + guardrails replace the hardcoded `msg-init` loop; `improve/` copy exclusion; `MSG_REPO` overridable
- `ARCHITECTURE.md` — install-layer notes: copy exclusion + manifest mechanism

- **msg v2 P2 — build discipline: per-ticket pair review, plain-English comments, small-commit caps (A3, A4, A5).** `eng --build` gains a blocking **pair-review subagent** per todo ticket (new `eng/refs/build/pair-review.md`, protocol Step 4e): a principal-engineer persona parameterised by the exec-table Agent column, with a single mandate — **unnecessary lines of code** (dead code, needless abstraction, duplicated logic, over-engineering, hand-rolled stdlib replacements) — plus the A4 comment check; it does not re-review correctness/style/security. Contract: the ticket's diff (cost-capped at ≤500 LOC by the P1 sizing rule) + its `done-when` + the parent's already-compiled standards payload, no `/cook` call; exactly one revision round, then unresolved findings are logged to the §12 Findings ledger with justification and the commit proceeds. The **plain-English comment convention** (A4) lands in the build protocol — every new/modified function/module/class/exported symbol gets a what-not-how comment — enforced by the pair reviewer per ticket and mechanically by new `.claude/scripts/eng-comment-scan.sh` (heuristic diff grep across js/ts/py/go/rs/swift/kt/dart/rb/java; `UNCOMMENTED <file>:<line>` machine lines, exit 1 on flags). **Small-commit caps** (A5) land as new `.claude/scripts/eng-commit-cap.sh` on the staged diff: >500 changed LOC blocks (>300 with `--breaking`), lockfiles/generated excluded; the `--oversize-reason` escape hatch exits 0 but requires an `Oversize-reason:` trailer in the commit body and a §12 ledger entry, with recurring oversize flagged as a plan-time ticket-sizing failure. Commits are now **per ticket** after Step 6's single human confirmation (no new prompts). Flash: pair review explicitly skipped (single end-of-run gate, no per-ticket cadence); both mechanical gates ride flash's one commit gate.

- `.claude/skills/eng/refs/build/pair-review.md` — new: persona, mandate, contract, one-round blocking rule
- `.claude/scripts/eng-comment-scan.sh` — new: deterministic A4 comment scan (tested: flags uncommented, passes commented, excludes fixtures)
- `.claude/scripts/eng-commit-cap.sh` — new: A5 cap gate (tested: 40/500 OK, 640/500 blocked, 390/300 blocked w/ --breaking, oversize-reason escape, lockfile excluded)
- `.claude/skills/eng/refs/build/protocol.md` — A4 rule (4c), pair-review step (4e), per-ticket commit gate running both scripts (Step 7)
- `.claude/skills/eng/refs/build/flash/mode-flash.md` — cap + comment scan on the single flash gate; pair review skipped by decision
- `.claude/skills/eng/SKILL.md`, `ARCHITECTURE.md` — references + script table updated

- **msg v2 P1 — eng core: one plan wave, lean build loop (A1, A2, I1).** The separate `eng --todo` mode and dispatch wave are gone: `eng --plan` now writes the `## Engineering — <Agent>` section, fills the Execution steps + Files columns, **and** writes the `## Todos — <Agent>` tickets in a single pass — one full subagent dispatch round per platform eliminated, plus one PRD re-read per agent. The ticket schema moved to `eng/refs/plan/template-todo.md` unchanged (`F<n>-T<k>` ids, eight fields, empty-block sentinel — `eng --build` reads the same shape), and gains the **ticket-sizing rule**: every ticket must be scoped at plan time to fit the per-commit caps (<500 changed LOC, <300 when breaking), split at plan time never at build time. The finding→issue-ticket projection + `kind` discriminator moved to `eng/refs/build/protocol-build-testjson.md` (its actual consumers' side); `/test` and the GUI repoint there. `eng --build`'s TDD loop and full-suite gate rescope to **unit + integration only** — e2e/visual/perf/a11y/coverage exit the fix-iteration loop and become pre-merge's job (A2). plan-em loses Step 0 entirely: `prefs.json` + `refs/prefs-bootstrap.md` deleted, `$TODOS` toggle gone, the exec table always carries the Todos column, mode detection collapses to `plan` | `build`, the synth "Run todo breakdown" option is deleted, and plan-em creates the `## Todos` umbrella once before dispatching the plan wave (race-safe). An invocation carrying `--todo` hard-fails with a pointer to `--plan`. Bench: plan-em main −775 tok modeled, static skill surface −2,153 tok, plus the unmodeled todo wave itself (~7.3k input tok per agent per run) eliminated.

- `.claude/skills/eng/SKILL.md` — two-mode routing, `--todo` hard-fail block, single-pass `--plan` contract, references repointed
- `.claude/skills/eng/refs/plan/protocol.md` — "Todo tickets — written in the same pass" spec: schema by reference, sizing caps, self-consistency checks, extended write confirmation
- `.claude/skills/eng/refs/plan/template-todo.md` — new: ticket schema migrated from `refs/todo/template-todo.md` + ticket-sizing rule (rule 2)
- `.claude/skills/eng/refs/plan/flash/mode-flash.md` — flash plan writes tickets in the same pass, same schema/caps
- `.claude/skills/eng/refs/todo/` — deleted (both `protocol-todo.md` and `template-todo.md`)
- `.claude/skills/eng/refs/build/protocol.md` — spec source: todos always written by `--plan` (exec-table = degraded fallback); TDD loop + full-suite gate scoped to unit + integration
- `.claude/skills/eng/refs/build/protocol-build-testjson.md` — received the finding→issue-ticket projection + `kind` discriminator
- `.claude/skills/eng/refs/build/flash/mode-flash.md`, `.claude/skills/eng/refs/build/protocol-roadmap.md` — suite scope + rejection lines aligned
- `.claude/skills/plan-em/SKILL.md` — Step 0 deleted, references scrubbed
- `.claude/skills/plan-em/prefs.json`, `.claude/skills/plan-em/refs/prefs-bootstrap.md` — deleted
- `.claude/skills/plan-em/refs/protocol-em.md` — two-mode detection, todo wave deleted, umbrella created before the plan wave, synth menu trimmed
- `.claude/skills/plan-em/refs/template-exec-table.md` — Todos column unconditional
- `.claude/skills/plan-em/refs/flash/mode-flash.md` — always-on Todos column + same-pass tickets
- `.claude/skills/test/SKILL.md`, `.claude/skills/msg/refs/protocol-gui.md`, `.claude/skills/msg/refs/gui/server.py`, `.claude/skills/msg/refs/gui/index.html` — projection/schema references repointed off removed concepts
- `README.md`, `ARCHITECTURE.md` — eng described as two-mode; execution chain `eng --plan → eng --build`

- **msg v2 plan — contract certifier, plan-em rework, and the 7-phase execution model.** plan-tune's adversarial posture is retired (D17): it becomes a **contract certifier** running a fixed seven-check certification on digest slices, every check tied to a named downstream consumer under the governing rule *no check without a consumer* — criteria testability, breaking/DB labeling, intent fidelity vs the intake row, exec-table integrity, ticket sizing + graph validity, frontmatter graph/platform coverage, and cross-agent integration-contract coherence (the one check only the certifier can perform, since row-scoped eng agents are structurally blind across sections). Blanket completeness/consistency/prose sweeps are cut; product judgment stays with the human touchpoints (intake, preview, staging). plan-em drops from ~4 interactive pauses to one (D19: roster approval): certifiers auto-run inline as preconditions before *both* dispatch waves (D18 — product before plan, eng before build; an unenforced gate decays into documentation), and relationship questions are replaced by silent consumption of the certified dependency graph. Execution is re-cut into **7 phases (P1–P7), one commit each** (D8 amended): a Fable session orchestrates — dispatch, acceptance-criteria verification, commit — while Opus subagents execute; no phase commits until its full AC checklist is green. P1 eng core → P2 build discipline → P3 install manifest → P4 pre-merge CI gate → P5 ship layer → P6 intake + autonomous plan-pm → P7 certification layer, exiting on a full autonomous dry run and a ≥40% net token cut vs the v1 baseline.

- `.claude/skills/improve/plan-msg-v2.md` — Part G rewrite (7-check table, cuts, trade note), Part I (I1–I5), D8/D12 amendments, D17–D19, § Execution phases with per-phase AC checklists

- **msg v2 plan addendum — plan-tune as certification authority (Part G) + GUI v2 (Part H).** With plan-pm autonomous and review deleted, the PRD's acceptance criteria became executable (regression tests, PRD-consistency gate, preview gate all run off them) — so plan-tune is rebuilt as the planning layer's certification authority: intent-fidelity audit against the intake row (scope-creep/scope-loss/grade consistency), hardened criteria-testability (an unassertable criterion is a Major — it would otherwise become a vacuous regression test), and an unlabeled-breaking-surface hunt on the eng tune (unlabeled = Critical, since the 300-LOC cap, pre-merge pause, and plan-pm pause all key off the label). Severity policy (D15): auto-fix Critical+Major, emit a compact found→fixed terminal table, ask once about Minors — the fix-selection and step-4 gates are deleted. Self-healing (D16): every auto-fixed Critical/Major logs a category-tagged learning to `devkit/AHA.md`, which plan-pm already reads pre-draft (zero new plumbing); a category recurring ≥3 runs escalates to a protocol-repair flag, and the benchmarkable metric is Critical+Major per fresh PRD trending to zero. Part H consolidates the GUI v2 rework: completion ladder gains gated/staged/shipped states, an Intake tab with rubric grade chips, the Gate Issues tab (renamed from Test Issues, reading `msg-gate/gate-*.json`), post-merge reports rendered release-style with the iOS IRREVERSIBLE flag surfaced, and exactly one new write carve-out (INTAKE.md status cells). Decisions log now D1–D16.

- `.claude/skills/improve/plan-msg-v2.md` — Part G (G1–G5, D15/D16), Part H (H1–H5), inventory/pipeline/token-accounting/migration updates

- **msg v2 — harness restructure plan (improve ID 23).** The full architectural blueprint for v2, developed and settled across 14 logged decisions (D1–D14), targeting faster development through the harness and lower token cost per coding run (−40%+ expected, to be proven via `evals/bench.py`). Headlines: `/review` and `/test` fold into a rebuilt `pre-merge` — the single CI gate (sync → mechanical → unit/int → compounding regression suite → platform buckets → security/migration → PRD-consistency → preview-deploy human gate → opens PR feature→staging) with per-platform failure tolerances from a new `devkit/PLATFORMS.md`; a new `post-merge` skill ships staging→main behind sign-off stamps, double-confirmation, and branch protection; `eng` is rebuilt around a merged plan+todo pass, unit+integration-only builds, a blocking per-ticket pair-programmer persona, plain-English comment convention, and <500/<300-LOC commit caps; a new `intake` skill owns idea capture + the interview into a graded `INTAKE.md` ledger while `plan-pm` goes autonomous (pauses only for open questions and breaking/critical touches); `install.sh` gains manifest-driven removals (`remove-manifest.txt`) and stops shipping `improve/`. Migration is phased V2-A→D, benchmark-gated, harness working at every step. Plan force-added past the `improve/` gitignore by explicit decision — the v2 blueprint travels with the branch.

- `.claude/skills/improve/plan-msg-v2.md` — new: the full v2 plan (Parts A–F, decisions log, safety floor v2, token accounting, migration phases)
- `.claude/skills/improve/_INDEX.md` — plan registered as ID 23 (in-progress)

- **Token-cut Wave 2a — exec-table `files:` column + diff-scoped standards flags.** Second execution wave of the Phase-4 token-efficiency plan, all assertion-gated and independently re-verified. The execution table gains a `Files` column (both `$TODOS` forms), populated by the eng agent alongside its Execution steps and carried through `scan-prd-digest.py` (legacy tables degrade to an empty `files` value, no regression); a new `plan-em-exec-collision.py` helper turns parallel-safety into a mechanical set-intersection over row Files (`COLLISION`/`MISSING_FILES` machine lines, non-zero exit on any overlap). On top of that, `eng --build` and `plan-em` now derive **diff-scoped sub-ref flags** for `/cook` instead of bare domain flags — dropping only refs the PRD/devkit provably excludes, and falling back to the full shelf on any uncertainty (never under-loads). Realizing that win required a companion change in the cook source repo so a bare domain flag paired with its own sub-refs resolves to the SKILL.md floor + only those named refs (previously the full shelf, making the scoped flags a no-op). Source-verified: the macOS shelf compiles from 8 sections to 3 with `degraded: []`. Two candidate defects the wave surfaced were fixed by the orchestrator, not the workers: a collision helper shipped as `.sh` with a python shebang (renamed `.py`), and the scoped-flag no-op traced through cook's resolver.

- `.claude/skills/plan-em/refs/template-exec-table.md` — `Files` column added to both table forms, column definition, worked examples, quality gate
- `.claude/skills/eng/refs/build/protocol-exec.md` — instruction to populate `Files` alongside Execution steps
- `.claude/scripts/scan-prd-digest.py` — `files` carried through the exec-table digest (legacy → `""`)
- `.claude/scripts/plan-em-exec-collision.py` — new: mechanical row-Files collision / parallel-safety checker
- `.claude/skills/eng/refs/build/protocol.md`, `.claude/skills/plan-em/refs/protocol-em.md` — diff-scoped sub-ref flag derivation with never-under-load fallback (companion cook resolver change lives in the cook source repo)

- **Token-cut Wave 1 — six cross-skill contract fixes.** First execution wave of the Phase-4 token-efficiency plan, drawn from two live token/latency analyses. Each fix was assertion-gated and independently re-verified before landing; two further candidate fixes were retired as already-repaired upstream (commit `7466791`), a plan-drift finding surfaced by the wave itself. `scan-prd-digest.py` now preserves `parent:` through the digest so a sub-PRD's branch resolution isn't misread as top-level. The `eng --build` standards flag table gains the missing `--swift`/`--macos`/`--css` shelf rows (plus `--swift:testing`), and its `report-[n].md` step is reframed as optional/best-effort with the inline build summary as the sanctioned report-of-record. `plan-em` branch resolution gates parent-branch reuse on `git branch --merged main`, cutting a fresh branch when the parent has already shipped, and no longer implies `/test --prd` persists `eval_set.json` (only `/review` does). `/review` Coverage mode gains a `sub-verdict` (`convention` | `behavior`) so a missing-dedicated-test `block` reads as "add a test file," not "something is broken."

- `.claude/scripts/scan-prd-digest.py` — `parent` added to the digest frontmatter allow-list (1.4)
- `.claude/skills/eng/refs/build/protocol.md` — `--swift`/`--macos`/`--css` + `--swift:testing` flag rows (1.3); report file made optional with inline report-of-record fallback (1.6)
- `.claude/skills/plan-em/refs/protocol-em.md` — `git branch --merged main` gate on parent-branch reuse (1.5); `/test --prd` no longer implies a persisted `eval_set.json` (1.7)
- `.claude/skills/review/refs/modes/coverage.md`, `.claude/skills/review/refs/schema.md` — `sub-verdict` on Coverage's block verdict (1.8)

- **Run reports — every build/review/gate run now tells you what you got and how to check it.** `eng --build`, `/review`, and `/pre-merge` end each completed run by writing `report-[n].md` into the PRD's `features/prd-<n>-<slug>/reports/` folder (`features/reports/` when no PRD applies; `[n]` = per-directory max+1). The report is a plain-language record for a human: work done, code changes with lines added/deleted, tests passed/failed, **what you can expect**, and **how to verify** it works — verification steps written in simple, everyday language (what to do, what you should see; commands only when unavoidable, copy-pasteable with the expected outcome in plain words). One canonical contract in `shared/refs/report-schema.md` (GUI-parseable frontmatter + fixed `##` sections) keeps all three producers and the board in agreement; writes are best-effort and never fail, block, or re-verdict a run, and each skill's existing output contract (build summary, findings JSON, final JSON emission) is unchanged. The `/msg --gui` board gains a dedicated **Reports** tab — cards grouped by PRD with skill/verdict/stat pills, a detail page rendering the report markdown, and a ↗ cross-link to the mapped PRD — verified end-to-end against a fixture project (server parse, PRD mapping, live serve, JS syntax).

- `.claude/skills/shared/refs/report-schema.md` — new: canonical `report-[n].md` contract (path resolution, numbering, frontmatter, section contract, per-skill field mapping, rules)
- `.claude/skills/eng/refs/build/protocol.md` — Run report step in the Output contract; `**Report:**` line in the build summary; run-artifact exemption in Constraints
- `.claude/skills/review/SKILL.md` — Step 7 report write (full unfiltered finding set), Outputs row, References entry
- `.claude/skills/review/refs/flash/mode-flash.md` — flash Emit step writes the report too
- `.claude/skills/pre-merge/SKILL.md` — Step 7 report written before the final JSON emission (skipped on refused/skipped); `Write` added to allowed_tools; hard-refusal scope + Outputs table extended
- `.claude/skills/pre-merge/refs/flash/mode-flash.md` — flash Emit step writes the report too
- `.claude/skills/msg/refs/gui/server.py` — `parse_report_file()`/`collect_reports()` (nested sub-PRD dirs included, unparseable → `skipped[]`), `reports[]` in `build_data()`
- `.claude/skills/msg/refs/gui/index.html` — `REPORTS` global, Reports nav tab, `#/reports` + `#/reports/<file>` routes, PRD-grouped card list, markdown detail view with PRD cross-link
- `.claude/skills/msg/refs/protocol-gui.md` — reports in the read model, data-contract example, Reports-tab rendering rules
- `README.md` — run-reports blurb; Reports tab in the `--gui` line
- `ARCHITECTURE.md` — new Run reports section; msg inventory row mentions the run-report reader

- **Fold `msg-init` into `/msg --init`.** The standalone bootstrap skill is retired; project bootstrap is now a mode of the `/msg` root menu, consolidating all harness-meta operations (`--init`, `--gui`, `--set-mode`, `--help`) under one skill. The protocol moved verbatim to `msg/refs/protocol-init.md` (git-mv, history preserved); `init.sh`, `init-setup.sh`, and the nine templates moved to `msg/refs/init/{,templates/}` with a one-line `REFS` repoint. msg's frontmatter description now carries the bootstrap trigger phrases ("initialise project", "bootstrap repo", "set up the framework", "start a new project") so natural-language triggering is preserved, and the Dispatch table gained an `--init` branch. Every reference site was swept to `/msg --init`: README, ARCHITECTURE (skill-inventory row removed, msg row extended), install.sh's next-steps echo, plan-pm/plan-em devkit hints, plan-em's msg-skill-set list, the three hard-coded template paths (plan-pm AHA header, eng OPEN-QUESTIONS entry template, `bench.py`'s devkit proxy), both self-referencing templates, and the tracked PRD-fixture hint strings. `install.sh` now deletes a stale `~/.claude/skills/msg-init/` on install so old copies can't shadow the new mode. Integrity verified identical to pre-fold: fresh-dir bootstrap creates all 11 outputs with clean substitution and stack-specific .gitignore, second run fully idempotent (0 created / 11 skipped), `ALL_COMPLETE=true` on rescan, stack-hint detection intact; `bench.py` resolves all new paths (pipeline +21 tok = noise; static +413 tok for the `--init` routing in the always-loaded msg SKILL.md).

- `.claude/skills/msg/refs/protocol-init.md` — moved from `msg-init/SKILL.md`; paths/usage rewritten for the mode form
- `.claude/skills/msg/refs/init/{init.sh,init-setup.sh,templates/}` — moved from `msg-init/`; `REFS` → `templates/`
- `.claude/skills/msg/SKILL.md` — trigger-bearing description, `--init` usage + dispatch + protocol section, menu/happy-path/--help updates
- `install.sh` — retired-skill cleanup (`msg-init`), next-steps echo
- `README.md`, `ARCHITECTURE.md` — `/msg --init` docs; inventory row folded into msg
- `.claude/skills/plan-pm/{SKILL.md,refs/protocol-pm.md}`, `.claude/skills/plan-em/{SKILL.md,refs/protocol-em.md,refs/prefs-bootstrap.md}`, `.claude/skills/eng/refs/build/protocol.md` — hint strings + template paths repointed
- `evals/bench.py` — devkit-proxy template paths repointed
- `features/prd-10x/*` — fixture hint strings updated

- **Harness audit Tier 1 — repair nine cross-skill contract breaks.** A deep audit of the skill suite surfaced nine places where one skill writes what another can't read; all fixed without redesign. `plan-tune` now stamps `product-tuned:`/`eng-tuned:` with the literal `yes` (a date never matched the consumers' `yes` gates, so tuned PRDs re-fired the tune gate and never passed roadmap readiness). The `/test` aggregate stamps a top-level `head` sha and `pre-merge --test-json` reads it — the ship-time integration/e2e skip could previously never fire — with integration coverage now keyed off the merged `unit` bucket. `install.sh` implements the README-advertised `--with-cook` instead of dying on it. The flash PRD template is digest-parseable again (canonical frontmatter, §6 features table, `## 9. Plan tune findings` instead of "Ledger"). Standalone `eng --build` gains the DB-touch/breaking-change pause the flash floor always promised — never waived by autonomy contracts. eng build refs write `followUp.status` (the key the `--gui` board actually reads, so resolved test issues no longer render forever-open). `review` emits `eval_set_path` only when Functional actually wrote the file. `resolve-diff.sh` distinguishes a `bad_base` setup error from a clean-tree `no_diff`. And `/test`'s user-cancel verdict is now `skipped`, matching `/pre-merge` (`refused` reserved for error paths; both defined in the shared schema).

- `.claude/skills/plan-tune/SKILL.md` — frontmatter writeback stamps `yes`, not a date
- `.claude/scripts/test-aggregate-verdict.sh`, `.claude/skills/test/refs/schema.md` — top-level `head` sha; user-cancel verdict `refused` → `skipped`
- `.claude/skills/test/SKILL.md`, `.claude/skills/shared/refs/finding-schema.md` — `skipped` (user cancel) vs `refused` (error path) defined once, shared
- `.claude/skills/pre-merge/SKILL.md`, `scripts/resolve-diff.sh` — `head`-based freshness, `unit`-bucket coverage key, `bad_base` refusal, `rtk git fetch`
- `install.sh` — `--with-cook` implemented (cook bootstrap, warn-on-failure)
- `.claude/skills/plan-pm/refs/flash/{template-flash,mode-flash}.md` — digest-parseable flash PRD shape
- `.claude/skills/eng/refs/build/{protocol,protocol-build-testjson}.md` — leaf-build production guardrail; `followUp.status` key
- `.claude/skills/review/SKILL.md` — `eval_set_path` never points at an unwritten file

- **Housekeeping: add `LICENSE` + `msg-minor.md`, drop superseded planning docs.** Added the project `LICENSE` and `msg-minor.md` — a plain-English tracker for the three open flash-mode residuals (live end-to-end verification, the +0.45% comprehensive-mode regression, and re-basing the per-stage flash targets from token-% to execution-count). Removed the superseded `msg-v1.md` / `msg-v2.md` planning docs (their content shipped as the delivered token-efficiency phases).

- **Retire the `improve` skill.** Removed the repo-local improvement-planner skill from the installed surface: deleted its `SKILL.md` + `refs/`, untracked `_INDEX.md`, and gitignored the whole `.claude/skills/improve/` folder (its plan docs persist on disk as local scratch). Cleaned up every reference — dropped the now-unused `LOCAL_ONLY_SKILLS` skip mechanism from `install.sh`, the stale `Edit(/.claude/skills/improve/**)` permission from `.claude/settings.json`, the improve-exclusion note from `ARCHITECTURE.md`, and the `improve` entry from plan-em's msg-skill-set list. `/msg` and `msg-init` never referenced it.

- **Consolidate flash protocols under a uniform `flash/mode-flash.md` path.** Renamed every skill's flash protocol from `flash.md` / `protocol-flash.md` to `<skill>/refs/[…/]flash/mode-flash.md`, so the layout is identical across review/test/pre-merge/eng/plan-pm/plan-tune/plan-em. Repointed all routing references (SKILL.md route lines, `mode-resolution.md`, `flash-floor.md`, ARCHITECTURE) and re-depthed the moved files' relative `../shared/refs/` links for the deeper nesting — also fixing two pre-existing broken links in review's flash rubric. Empty skill folders (`pre-merge/archive`, `plan-em/refs/{plan,build}`) removed. Behavior-neutral; the flash/comprehensive benchmark is unchanged.

- **msg-v1 Phase 3 — opt-in flash mode + harness-wide mode toggle.** Every user-facing skill now runs in one of two modes: **comprehensive** (default, unchanged) or **flash**, an opt-in fast pass that trades *execution count* (subagents, buckets, gates, interview turns) — **not** correctness or safety — for speed. Flash reuses the msg-v2 substrate rather than re-implementing it: PRD-digest slices, the shared verify prelude, flag-based injected cook, and the session cache. Each skill loads a small `refs/flash.md` **instead of** its comprehensive refs — `review` runs mechanical gates + **1** combined semantic agent (vs ≤4) and produces the verify prelude; `test` runs unit+functional **in-process** (0 subagents) consuming the prelude; `pre-merge` runs build+security only (integration/e2e emit the `--test-json` skip shape); `eng --build` uses **1** agent (no per-platform fan-out) off the `build` digest slice; `plan-pm` collapses the interview to **2** `AskUserQuestion` calls; `plan-tune` runs critical-severity checks only with 0 gates; `plan-em` uses **1** generalist agent (≤2 platforms) + one merged gate. A harness-wide toggle (`shared/refs/mode-resolution.md`, precedence *flag > forwarded > local pref > global pref > comprehensive*) resolves the mode at each skill's Step 0; `/msg --set-mode --flash|--comprehensive` persists it to `.claude/msg/pref.json` (not gitignored; `install.sh` never writes it), and in-repo orchestrators (`plan-em`, roadmap `eng --build`, `review`) forward the resolved mode into every subagent so a run never drifts. The **safety floor is never relaxed in either mode** (`shared/refs/flash-floor.md`): DB/breaking-change pauses, branch isolation, never push/merge, secret scan, frontmatter stamps, F-ID stability, §9 ledger, test-fail ticket, pre-merge refusals. Measured via a new `BENCH_MODE=flash` manifest in `evals/bench.py`: flash pipeline **84,987–85,198 tok = 47.7% of post-v2 comprehensive**, run-wide subagents ~75% fewer; comprehensive stays within +0.45% (the flash-flag/Step-0 routing docs now in each always-loaded entry file). Structural verification green (11/11 flash refs, 9/9 routes, floor + v2-reuse + digest-slice checks); the live end-to-end functional verification (build-green / seeded-blocker / clean pre-merge) is a tracked follow-up a static benchmark cannot execute.

- `.claude/skills/shared/refs/flash-floor.md` — new: never-relaxed safety floor + common flash semantics (auto-proceed, capped stdout, v2-substrate reuse, mode-propagation sentence)
- `.claude/skills/shared/refs/mode-resolution.md` — new: mode precedence + `pref.json` format (flag > forwarded > local > global > comprehensive; corrupt/missing → comprehensive)
- `.claude/skills/review/{SKILL.md,refs/flash.md}` — new flash path (Step 0 mode route, 1 combined semantic agent, verify-prelude producer, top-10 @ min-severity high); Step 6 mode-propagation note
- `.claude/skills/test/{SKILL.md,refs/flash.md}` — new flash path (unit+functional in-process, consumes verify prelude, fail ticket intact)
- `.claude/skills/pre-merge/{SKILL.md,refs/flash.md}` — new flash path (build+security, integration/e2e `--test-json` skip shape, no gate)
- `.claude/skills/eng/{SKILL.md,refs/plan/flash.md,refs/build/flash.md}` — `--plan`/`--build` flash variants (compressed 5-section plan; 1 build agent off the `build` slice, 1 injected cook, single commit gate)
- `.claude/skills/eng/refs/build/protocol-roadmap.md` — mode propagation into roadmap `eng`/`review`/`test`/`pre-merge` subagents
- `.claude/skills/plan-pm/{SKILL.md,refs/flash/protocol-flash.md,refs/flash/template-flash.md}` — flash path (2-call interview, GLOSSARY+ARCHITECTURE only, digest-parseable slim template)
- `.claude/skills/plan-tune/{SKILL.md,refs/flash.md}` — flash path (critical-severity checks only, 0 gates, auto-fix to canonical PRD)
- `.claude/skills/plan-em/{SKILL.md,refs/flash.md,refs/protocol-em.md}` — flash path (1 generalist agent ≤2 platforms, merged gate, synth from agent returns); resolved-mode forwarding in the subagent-injection block
- `.claude/skills/msg/SKILL.md` — `--flash` menu resolution + `/msg --set-mode` (scope-asking, merge-safe pref write) + active-mode line
- `.claude/skills/msg-init/SKILL.md` — `--flash` zero-interview bootstrap (≤1 confirm)
- `README.md`, `ARCHITECTURE.md` — Run modes section (pref, precedence, propagation, v2-substrate reuse, never-relaxed floor)

- **msg-v2 — input digestion + protocol slimming (−53% modeled input footprint).** Aggressive, breaking-allowed token cuts on top of msg-v1 Phase 1, driven by a measured benchmark rather than estimates. The dominant lever is a **PRD digest**: `scan-prd-digest.py` deterministically parses a PRD (no LLM) into a sliceable JSON — `--slice product|plan|eng-audit|build|eval|synth` — so each pipeline stage reads only its ~2–8k-token slice instead of re-reading the full ~20k-token PRD prose (it was re-read ~8× across the pipeline, ≈57% of the footprint). Contractual fields (F-IDs, acceptance criteria, integration contracts, glossary, exec rows) are copied verbatim; narrative prose is dropped but every entry keeps a `prose_lines` escape-hatch pointer; the parser is number-agnostic + fuzzy-column and flags unknown sections in `unparsed_sections` (validated across prd-100…103). Wired into all six PRD consumers (plan-tune ×2, plan-em pre-flight + synthesis, eng --build, review + test eval bootstrap). A hash-keyed **session cache** (`shared/refs/session-cache.md`, `.claude/msg/cache/`, gitignored) governs it and the new **verify prelude** (`shared/refs/verify-prelude.md`) — review produces one shared diff+tooling+eval_set artifact that test and pre-merge consume instead of each re-resolving/re-detecting/re-deriving (standalone runs self-setup unchanged). Protocol slimming (hot/cold split of `eng/refs/build/protocol.md`, prose→tables on `protocol-em.md`, checklist-tighten on `tune-product.md`) contributed a marginal ~2 points — these protocols are dense with load-bearing instructions, not bloat. A reproducible harness `evals/bench.py` measured every step (380,704 → 177,663 tok; `BENCH_PRD=full` recomputes the pre-digest baseline). No behavior/finding change: every invariant (verdict enums, refusal patterns, branch/commit/scope/DB-pause guards, `--global` P0 floor, frontmatter stamps, §9 ledger, `--test-json` handoff, secret scan) grep-verified intact.

- `.claude/scripts/scan-prd-digest.py` — new: deterministic PRD → sliceable digest generator (verbatim contractual fields, prose_lines pointers, source_hash cache key, fuzzy/number-agnostic parsing)
- `.claude/skills/shared/refs/session-cache.md` — new: hash-keyed session-cache contract (source canonical, cache derived/disposable, generate-if-stale, never-hard-fail)
- `.claude/skills/shared/refs/verify-prelude.md` — new: shared diff+tooling+eval_set prelude spec for the review→test→pre-merge triad
- `.claude/skills/plan-tune/SKILL.md`, `refs/tune-product.md`, `refs/tune-eng.md` — read `product`/`eng-audit` digest slices; tune-product checklist tightened
- `.claude/skills/plan-em/refs/protocol-em.md` — `plan` slice at pre-flight, `synth` slice at synthesis (was full-PRD re-read); prose→tables/checklists
- `.claude/skills/eng/refs/build/protocol.md` — `build --feature` slice read; hot/cold split (test-json + debug paths → new `protocol-build-testjson.md` / `protocol-build-debug.md`, lazily loaded); OPEN-QUESTIONS dedup; example trim
- `.claude/skills/eng/refs/build/{protocol-build-testjson.md,protocol-build-debug.md}` — new: lazily-loaded cold paths
- `.claude/skills/review/SKILL.md` — `eval` slice bootstrap; producer of the verify prelude
- `.claude/skills/test/SKILL.md`, `.claude/skills/pre-merge/SKILL.md` — consume the verify prelude when fresh (tooling/diff/eval_set), self-setup otherwise
- `.gitignore` — add `.claude/msg/cache/`
- `msg-v2.md` — the aggressive-cuts plan (delivered; tiering dropped per decision)

- **msg-v1 Phase 1 — token-efficiency structural fixes (no behavior change).** Cut the pipeline's dominant token costs without altering any artifact, safety, scope, or branch guarantee. `review` now spawns **one `/cook` sub-agent per mode instead of per flag** (~12–13 → ≤4 semantic agents) and the orchestrator **compiles `/cook` once per stack and injects the compiled standards payload** into each sub-agent prompt rather than every leaf re-invoking cook; `eng`/`plan-em` call cook via **explicit `--<domain>` flags** (cacheable, P0-guaranteed) instead of the uncacheable prose path, and drop cook from `--todo`/`--plan` entirely. Build sub-agents receive **row-scoped context** (exec rows + relevant PRD feature sections + a devkit digest) instead of re-reading the full PRD and all devkit. The finding object is now defined **once** in `shared/refs/finding-schema.md` — the ~17 inlined copies across `test`/`review`/`pre-merge` collapse to path references. `test`'s 10 mode files share a new `_common.md` (guard + error rule + output envelope + schema pointer) and drop all 7 redundant runner-detection tables (the detect script is authoritative); `review`'s cook-backed modes share a `_common.md` Execution contract, conditional-mode triggers are hoisted into `SKILL.md` Step 6 (mode files loaded only on match), and `performance.md` is folded in and deleted. Tooling detection moves out of hot paths into `test-tooling-detect.sh` JSON (now also emitting mechanical runners, secret scanners, build tool, bundle analyzer), and the GUI static fallback is a `fill-static.py` call instead of a ~35k-token manual splice. `pre-merge` accepts `--test-json` to skip integration/e2e buckets already covered by a fresh, clean `/test` run. Hot `SKILL.md` files slim down (`eng` 2222→1492w, `plan-pm` 1909→1274w) by moving rare-mode content to refs; `msg-init`'s interview batches into ≤4 `AskUserQuestion` calls; and `review`'s dedup key is fixed to the canonical `(category, file, line, rule)`. Net −459 lines. Cook-internal tasks (T1.12 budget, cook `_INDEX` archives, cook `--flash`) are deferred — cook is a separate repo.

- `.claude/skills/review/SKILL.md` — Step 6 rewrite: compile-once/inject, one sub-agent per mode, inline conditional triggers, folded performance mode, dedup key → `(category, file, line, rule)`; Step 2 consumes detect-script JSON
- `.claude/skills/review/refs/modes/_common.md` — new: shared cook-backed Execution contract
- `.claude/skills/review/refs/modes/{quality,security,migration}.md` — Execution block → `_common.md`; `performance.md` deleted; `schema.md` → pointer at shared
- `.claude/skills/test/refs/modes/_common.md` — new: guard + error rule + output envelope + schema pointer
- `.claude/skills/test/refs/modes/*.md`, `test/refs/schema.md` — inlined finding schema → pointer; runner tables removed; boilerplate factored to `_common.md`
- `.claude/skills/eng/SKILL.md`, `eng/refs/build/protocol.md`, `protocol-roadmap.md` — flag-based cook, compile-once/inject, row-scoped sub-agent context, slimmed hot file (test-json/roadmap docs → build refs)
- `.claude/skills/plan-em/{SKILL.md,refs/protocol-em.md,refs/prefs-bootstrap.md}` — flag-based cook, payload injection, row-scoped context, Step 0 prefs prose → ref
- `.claude/skills/plan-pm/{SKILL.md,refs/protocol-pm.md,refs/protocol-sub.md}` — sub-PRD/roadmap sections → refs; open-questions batched
- `.claude/skills/plan-tune/SKILL.md` — persona/outputs de-duplicated; `refs/principles.md` deleted (stale copy)
- `.claude/skills/msg-init/SKILL.md` — 14-question interview → 4 batched `AskUserQuestion` calls
- `.claude/skills/pre-merge/{SKILL.md,refs/finding-schema.md,refs/output-schema.md}` — schema → pointer; `--test-json` bucket-skip; Step 2 detect-script JSON; `pre-merge-plan.md` deleted
- `.claude/scripts/test-tooling-detect.sh` — emit build tool, mechanical runners, secret scanners, bundle analyzer as JSON
- `.claude/skills/msg/refs/gui/fill-static.py` — new: GUI static-fill substitution; `protocol-gui.md` Step 4 invokes it
- `.claude/skills/shared/refs/tooling-detection.md` — demoted to maintainer documentation
- `README.md`, `ARCHITECTURE.md` — docu: msg-init step count, detect-script scope, cook-integration paragraph
- `msg-v1.md` — the four-phase plan (Phase 1 marked done)

- Gitignore the generated `roadmap/` directory. `roadmap/roadmap.md` is per-project output of `plan-pm --roadmap` (same generated-content class as the already-ignored `features/` and `plans/`), so it is local-only and no longer tracked.

- `.gitignore` — add `roadmap/` under the working-dirs section

- Teach `plan-pm` to author the PRD `summary` frontmatter field that the `/msg --gui` detail page renders. The PRD template grows a `summary:` field (a single-line 2–3 sentence gist of the core objective + headline features); Step 4 initializes it from the Q1 brief and Step 5 reconciles it against the finalized §1 Product objective and §6 feature list. Sub-PRDs author their own `summary` (not inherited from the parent), and the `protocol-gui.md` data-shape doc records the new field. New PRDs now ship a summary out of the box; older PRDs without one still fall back to the GUI's feature-title list.

- `.claude/skills/plan-pm/refs/template-prd.md` — add `summary:` to the file-header frontmatter with authoring guidance
- `.claude/skills/plan-pm/refs/protocol-pm.md` — Step 4 frontmatter bullet for `summary`; Step 5 reconciliation note
- `.claude/skills/plan-pm/SKILL.md` — sub-PRD D4 authors a fresh `summary` rather than inheriting the parent's
- `.claude/skills/msg/refs/protocol-gui.md` — document `summary` in the PRD data payload shape

- Polish the `/msg --gui` **Roadmap tab** and add a PRD summary to the detail page. Roadmap PRD cards that have **shipped** now render in a greyed-out `done` state with a ✓ (kept visible, not hidden), and a roadmap phase whose PRDs have *all* shipped gets a ✓ on its lane header. The phase **goal** line is inset to sit within the lane padding instead of hugging the edges, and the **roadmap tune log** is no longer rendered on the board (it stays in `roadmap/roadmap.md` for rerun-stability). The **PRD detail page** now shows a 2–3 sentence summary below the title, sourced from a new frontmatter `summary` field with a feature-title-list fallback when absent. Verified: `server.py` change exercised via `/api/data`, `index.html` passes node --check, and the live roadmap/summary payloads were confirmed end-to-end.

- `.claude/skills/msg/refs/gui/index.html` — detail-page `summary` render (`detailSummary` w/ feature-title fallback); roadmap card `done`/✓ state for shipped PRDs; `phase-done` ✓ on fully-shipped lanes; drop tune-log render
- `.claude/skills/msg/refs/gui/server.py` — surface frontmatter `summary` in the PRD data payload
- `.claude/skills/msg/refs/gui/styles.css` — inset `.roadmap-goal` within lane padding; add `.card.done`, `.phase-done`, `.done-check`, `.phase-check`, `.detail-summary` rules

- Add an end-to-end **roadmap capability** that takes the project from a pile of PRDs to sequenced, autonomously-executed phases. `plan-pm` gains a `--roadmap` mode that inventories every PRD (new `plan-pm-roadmap-scan.sh` JSONL scanner with a derived `complete` flag), **accepts only full PRDs** — an incomplete one (missing §6 acceptance criteria, §7 exec rows, or unfinished tune stamps) exits and asks Amend-now-via-msg-flow / Skip / Stop — then analyses the survivors for bloat and overlap, proposes approval-gated `SPLIT`/`MERGE`/`FOLD`/`TRIM` reshaping (retire, never delete), sequences them into stable roadmap phases by the `depends_on`/`affects` DAG (reruns preserve existing phases), and writes `roadmap/roadmap.md`. The `/msg --gui` board gains a **Roadmap tab** (phases as lanes, PRD cards with live completion pills, tune-log accordion; `/api/roadmap` + `--view roadmap`; read-only v1). `eng --build` gains a `roadmap=` input source that turns the session into a **product-operations orchestrator**: it emits a step-by-step execution plan and asks once, then runs each phase autonomously — per PRD: acceptance-based readiness gate (same only-full-PRDs exit-and-ask), branch, parallel `eng --build` subagents (msg skills only, JSON returns), `review --min-severity high` + `test` measured against the PRD's **acceptance done-set**, a fix loop that must close every critical/major finding *and* every unmet acceptance criterion (max 5 rounds, then pause-and-escalate), `pre-merge` — with guardrails throughout (new `eng-db-touch.sh` pauses on any DB/data/prod-config touch; branch isolation; never push/merge; branches left merge-ready). Interval standup digests plus on-demand `status`; the session stays alive until the phase completes. Verified: scan + guard scripts tested against the live repo, `server.py` py_compile and `index.html` node --check pass, and the roadmap endpoint was exercised end-to-end against a sample `roadmap/roadmap.md` (including an id-separator parser fix caught in testing).

- `.claude/skills/plan-pm/SKILL.md` — declare `--roadmap` (Usage triggers, Modes line, § Roadmap mode, References)
- `.claude/skills/plan-pm/refs/protocol-roadmap.md` — new: 6-step roadmap protocol (inventory → completeness gate → analyse → gated reshaping → stable sequencing → write + GUI/exec handoff)
- `.claude/scripts/plan-pm-roadmap-scan.sh` — new: deterministic JSONL PRD inventory incl. `complete` flag
- `.claude/skills/eng/SKILL.md` — `roadmap=` third `--build` input source, Step 0 orchestrator routing, hard-failure strings, References
- `.claude/skills/eng/refs/build/protocol-roadmap.md` — new: product-operations orchestrator protocol (readiness gate, plan-first approval, phase loop, subagent contract, guardrails, reporting)
- `.claude/scripts/eng-db-touch.sh` — new: DB/data/production-config diff guardrail
- `.claude/skills/msg/refs/gui/server.py` — `build_roadmap()` parser, `/api/roadmap`, roadmap folded into `/api/data`, `--view` arg
- `.claude/skills/msg/refs/gui/index.html` — Roadmap tab (lanes, cards, tune-log accordion), router + boot default-view
- `.claude/skills/msg/refs/gui/styles.css` — roadmap lane/goal/rationale/tune-log rules on existing tokens
- `.claude/skills/msg/refs/protocol-gui.md` — document the Roadmap view, endpoint, and `--view`
- `.claude/skills/msg/SKILL.md` — `--help` gains "A roadmap" output + routing rows to `plan-pm --roadmap` / `eng --build roadmap=`
- `README.md` — plan-pm `--roadmap` + eng `roadmap=` descriptions
- `ARCHITECTURE.md` — Roadmap pipeline lane + autonomy caveat

- Slim the `plan-pm` and `plan-em` skills by extracting their step-by-step protocols into dedicated ref files, leaving each `SKILL.md` as a thin overview that points to the protocol. No behaviour change — the extracted protocols are the originals verbatim, plus a cleanup pass on `plan-em` that removes dead `refs/$MODE/` path references and repairs a broken Step 1 read-list. `plan-pm/SKILL.md` drops 307→122 lines and `plan-em/SKILL.md` 350→106; the full protocols now live in `refs/protocol-pm.md` and `refs/protocol-em.md`. A stale `plan-em/SKILL.md:88–106` line citation in `plan-tune` was repointed to the new ref.

- `.claude/skills/plan-pm/SKILL.md` — replace inline six-step protocol + multi-PRD summary with a pointer to `refs/protocol-pm.md`; add ref entry; retarget Sub-PRD "steps below" wording to the ref
- `.claude/skills/plan-pm/refs/protocol-pm.md` — new: full six-step execution protocol + multi-PRD final summary
- `.claude/skills/plan-em/SKILL.md` — replace inline five-step protocol with a pointer to `refs/protocol-em.md`; add ref entry (Step 0 todo-preference stays in `SKILL.md`)
- `.claude/skills/plan-em/refs/protocol-em.md` — new: full five-step execution protocol; drop dead `refs/$MODE/` path claims, fix Step 1 read-list numbering
- `.claude/skills/plan-tune/refs/tune-eng.md` — repoint stale `plan-em/SKILL.md:88–106` citation to `plan-em/refs/protocol-em.md`, Step 1

- Simplify the installer by dropping the `--with-cook` install option. `install.sh` no longer accepts `--with-cook`/`--cook`, drops the interactive `[1] msg / [2] msg + cook` prompt, and removes the inline cook install step — installing msg now always installs the msg skills only. In its place the completion footer prints a note pointing at the cook repo with its one-line install command, plus a dedication to JC.

- `install.sh` — remove `--with-cook`/`--cook` flag, interactive install prompt, and inline cook install; add footer note linking the cook repo + install command and a dedication

- Restructure the PRD template into a single canonical section order and separate user-goal content from engineering detail. The template (`plan-pm`) now emits eleven H2 sections in a fixed order — **Product objective** (new), Out-of-scope, User flow, Key user interactions, Error cases, Features & acceptance criteria (reframed to user goals, no eng detail), **Feature execution table** (reserved placeholder), Open questions, **Plan tune findings** (reserved), Glossary, **Todos** (reserved placeholder) — with **Target platform** removed as a body section (it survives only as frontmatter metadata). `plan-tune` now writes its audit findings as one **growing table** (create-once, append rows; `# | Date | Auditor | Severity | What is wrong | Suggested fix | Why it matters | Status`) into the reserved Plan tune findings slot instead of appending dated `## Audit` prose blocks, normalizes Open questions into a `# | Question | Answer | Status` table, and rebinds every audit dimension from brittle `§N` numbers to **section titles** (dropping the Target-platform checks). The `--gui` board parsers were made number-tolerant and taught to render the new findings table (legacy formats still parse). Stale `PRD §N` reads across `plan-em`, `eng`, and the todo/feature-table refs were repointed to section titles so the downstream pipeline still resolves. Verified: 32/32 acceptance criteria passed independent review, `server.py` py_compile + `index.html` node --check pass, and the server parsers were exercised against new, legacy, and exec-table-fallback PRDs. Feature-execution-table population (plan-em) and Todos population (`/todo`) are reserved placeholders — wiring deferred.

- `.claude/skills/plan-pm/refs/template-prd.md` — 11-section H2 canonical order; add Product objective, remove Target platform, reserve Feature execution table / Plan tune findings / Todos; Open questions + findings as tables
- `.claude/skills/plan-pm/SKILL.md` — Step 5 population map, devkit table, persona, and open-questions loop repointed to titles; drop Target platform prompt
- `.claude/skills/plan-pm/refs/template-feature-table.md` — F-IDs reference the Features & acceptance criteria section by title
- `.claude/skills/plan-tune/SKILL.md` — findings write into the reserved Plan tune findings section (create-once, append rows, status lifecycle); Open questions normalization; scan-exclusion + outputs repointed
- `.claude/skills/plan-tune/refs/tune-product.md` — single findings-table schema; title-bound Dimensions 1–4; Target-platform checks removed; eng-detail-in-criterion check added
- `.claude/skills/plan-tune/refs/tune-eng.md` — title-bind eng-plan subsections and the platform check
- `.claude/skills/msg/refs/gui/server.py`, `index.html`, `../protocol-gui.md` — number-tolerant Features/Todos/findings section matching; findings-table parse + 8-column render; legacy prose fallback
- `.claude/skills/plan-em/SKILL.md`, `eng/SKILL.md`, `eng/refs/todo/protocol-todo.md`, `eng/refs/todo/template-todo.md`, `eng/refs/plan/template-eng-plan.md` — repoint stale PRD `§N` reads to section titles
- `.claude/skills/msg-init/refs/template-DESIGN-SYSTEM.md` — component detail now recorded in the Feature execution table, not the user-flow section

- Turn `/msg --gui` from a read-only static board into a fully interactive PRD workspace. The default path now launches a local `refs/gui/server.py` bound to `127.0.0.1` that parses `features/prd-*/` (frontmatter + F-IDs + `## Todos`), infers completion, and exposes token-guarded `/api/*` endpoints so the browser board can **edit PRD bodies, change status (dropdown or drag-and-drop between columns), toggle todos, browse project docs (README, CLAUDE.md, `devkit/`), and run Claude prompts from a console** — with all writes confined to `features/prd-*/` markdown. The client gained an offline, injection-safe markdown→HTML renderer (headings, fenced code, blockquotes, tables, nested/checkbox lists, inline formatting), `## `-split section accordions, a plan-tune findings table (product `## Audit` + eng `### 12. Findings`), a light/dark theme toggle, toasts, and modals. When `python3` is unavailable or a read-only snapshot is wanted, the same file falls back to the static template + data-fill path — identical board, editing UI hidden, nothing ever written.

- `.claude/skills/msg/refs/gui/server.py` — new local `127.0.0.1` API server exposing `/api/*` for PRD edits, status changes, todo toggles, the prompt console, and the file viewer; writes confined to `features/prd-*/`
- `.claude/skills/msg/refs/gui/index.html` — live-mode client plumbing (token/ping, fetch API, data refresh), markdown renderer, section accordions, findings parsing, drag-and-drop status, theme toggle, toasts, modals
- `.claude/skills/msg/refs/gui/styles.css` — interactive-board styling, light/dark themes, modal scrim + dialog, toast, drag-over/drop states
- `.claude/skills/msg/refs/protocol-gui.md` — rewrite for interactive-default mode (server launch, API contract) with the static snapshot as fallback
- `.claude/skills/msg/SKILL.md` — describe the interactive board surface (editing, todos, prompt console, project docs)
- `.claude/skills/plan-em/prefs.json` — pref tweak
- `.gitignore` — ignore gui runtime artifacts
- `ARCHITECTURE.md`, `README.md` — reflect the interactive `--gui` board

- Add a persistent test-issue tracker (Feature 6) that closes the loop from a non-clean `/test` run to the thing that fixes it. `/test` gains a new **Step 6**: when the aggregated verdict is `fail`/`pass_with_warnings` (a clean `pass`/`refused` writes nothing and asks nothing), it creates `msg-test/` at the repo root on demand, numbers the next ticket `max(numeric suffix of test-*.json) + 1` (or `1`), and writes `msg-test/test-<n>.json` — a self-contained ticket carrying `context` (prd/branch/base, reused from Step 2), `source_run`, `summary`, the Step 5 `findings[]` copied **verbatim as canonical findings**, and a `follow_up` pointer. A second, conditional `AskUserQuestion` (scoped to this step, reconciled against the "exactly ONE gate" hard-refusal) offers **Fix now** / **Investigate first** / **Not now**. `eng --build` gains a **`test-json` input path** (build-only; both `prd-path` and `test-json` is a hard failure; `agent` defaults to `eng-fix`; `branch` defaults to the file's `context.branch`) that projects each finding into an issue-ticket standing in for an exec-table row, then runs a three-phase fix flow — **(a) reproduce → (b) fix via `/cook` → (c) verify green** (Item 0 skipped, flaky issues fixed only on a reproducible root cause) — and writes `follow_up.status` `open → resolved`/`partially_resolved` on completion. A single read-time **finding→ticket projection** (with a `kind` discriminator, `todo` vs `issue`) is defined once in `template-todo.md` and consumed by both `eng --build` and `--gui`; the on-disk file stays canonical findings. The `/msg --gui` board renders a distinct **🐞 Test Issues** grouping (one card per file with `runId`, verdict pill, `summary` counts, `followUp.status`), an issue-detail page, issue-ticket cards with a kind tag + `severity` pill, a `repro`+`evidence.snippet` side panel, honest `open`/`resolved`/`partially_resolved` done-state read from the file (never invented), and a PRD cross-link surfacing an issue file's tickets on a matching PRD's detail page tagged `kind:"issue"`. Verified: the GUI app JS passed `node --check`, a jsdom harness rendered the real filled template against a dummy `msg-test/test-1.json` for 41/41 assertions with zero render errors, and the Step 6 numbering + template shape were unit-tested.

- `.claude/skills/test/SKILL.md` — new Step 6 (conditional ticket write + follow-up gate); `msg-test/` numbering + template; reconciled the single-gate hard-refusal; Inputs/Outputs + References
- `.claude/skills/eng/SKILL.md` — Step 1 `test-json` alternate input (build-only, ambiguous-source + missing/unparseable hard-refusals); Step 2 finding-projection pre-flight branch
- `.claude/skills/eng/refs/build/protocol.md` — `test-json` input contract + `context.branch` default; three-phase fix flow; flaky handling; `Issue`-keyed summary; `follow_up.status` writeback
- `.claude/skills/eng/refs/todo/template-todo.md` — new: shared finding→issue-ticket projection, `kind` discriminator, field mapping, preserved diagnostic fields
- `.claude/skills/msg/refs/protocol-gui.md` — new Step 1b (`msg-test/` glob); `testIssues[]` data contract; Test Issues surface, done-state, PRD cross-link notes
- `.claude/skills/msg/refs/gui/index.html` — `testIssues` load + projection helpers; Test Issues surface + issue-detail route; kind/severity rendering; repro/snippet panel; PRD cross-link
- `.claude/skills/msg/refs/gui/styles.css` — 🐞 kind tag, severity pills, verdict pills, issue-card accent, Test Issues grid, cross-link style

- Document the `eng --todo` mode in the human-facing docs (follow-up to the feature commit): README's `/eng` row now lists all three modes and notes `--build` is todos-first (falling back to exec-table rows); ARCHITECTURE's execution pipeline shows `eng --plan → eng --todo → eng --build` with a note that the todo phase runs only when `plan-em`'s `prefs.json` `todos` toggle is on, and the skill-inventory row for `eng` adds `--todo`. `install.sh` is unchanged — it installs skill files and never enumerated eng modes.

- `README.md` — `/eng` row: add `--todo`, reword `--build` as todos-first
- `ARCHITECTURE.md` — execution pipeline + `eng` inventory row note the `--todo` phase and its `prefs.json` gate

- Add `eng --todo`, a third eng mode between `--plan` and `--build` (design doc → task breakdown → build). It reads the confirmed `## Engineering — <Agent>` section(s) plus the PRD's F-ID feature table and decomposes each F-ID into agent-executable **tickets** under a `## Todos — <Agent>` sub-heading (one `### F<n>` block per feature; empty features get an explicit `_No discrete work_` block so the anchor still resolves). Each ticket is modelled on a JIRA/Linear ticket minus estimation: `id` (`F<n>-T<k>`), `title`, `objective` (the product/user goal it serves), `type` (`code|test|config|migration|doc`), `priority` (`P0|P1|P2` — a build-order signal, not story points), `files` (each tagged `add|edit|remove`), `depends-on` (ticket ids, kept acyclic), and `done-when` (a verifiable acceptance check). `plan-em` owns the layer: a new Step 0 resolves a persisted `todos` boolean in `.claude/skills/plan-em/prefs.json` (set on first run by scanning for a pre-existing user task-breakdown skill — found → defer/off, none → on), which gates a new **Todos** column in the Step 3 execution table (`[F<n>](#todos-f<n>)` anchors), a three-state Step 4 mode detection (plan → todo → build), a todo-phase dispatch branch, and a Step 5 "Run todo breakdown" handoff. `eng --build` now prefers a feature's tickets and walks them in dependency order (higher priority first among the unblocked), falling back to exec-table rows when no todos exist and hard-stopping when neither exists. The already-shipped `/msg --gui` board was migrated to consume the ticket shape — parser, data contract, and the card/table/side-panel renderer now surface id, objective, priority, files, and depends-on (no stored `done` state; `done-when` is the check, not a status).

- `.claude/skills/eng/SKILL.md` — add `--todo` to Step 0 routing (between `--plan`/`--build`), input validation, mode divergence, references; frontmatter now three modes
- `.claude/skills/eng/refs/todo/protocol-todo.md` — new: `--todo` work steps — read engineering section + F-ID table, decompose into tickets, validate ids/dependencies
- `.claude/skills/eng/refs/todo/template-todo.md` — new: JIRA/Linear ticket schema, `## Todos` structure, per-`### F<n>` block rules
- `.claude/skills/eng/refs/build/protocol.md` — prefer tickets over exec-table rows; dependency-ordered build; hard-stop when neither exists
- `.claude/skills/plan-em/SKILL.md` — Step 0 `prefs.json` todo-preference; Todos column; three-state mode detection; todo-phase branch; Step 5 handoff
- `.claude/skills/plan-em/refs/template-exec-table.md` — optional Todos column with `#todos-f<n>` anchors
- `.claude/skills/msg/refs/protocol-gui.md` — parse tickets (id/objective/priority/files/depends-on) into the data contract, keep legacy single-file compat
- `.claude/skills/msg/refs/gui/index.html` — render ticket fields in card, table, and side panel
- `.claude/skills/msg/refs/gui/styles.css` — priority pills, multi-line panel field values

- Add `/msg --gui`: a local-only, read-only static-HTML board over `features/prd-*/`. The bare word `/msg gui` and natural-language triggers ("show me the PRD board", "open kanban", "visualize my PRDs") route straight to rendering — via a new `## Dispatch` block and `Protocol: --gui` section in `msg/SKILL.md`, with no picker and no `AskUserQuestion`. The new `refs/protocol-gui.md` enumerates PRDs (including nested sub-PRDs), parses frontmatter, F-ID rows (`## 3. Features & acceptance criteria` → `## Execution Table` fallback) and any `## Todos`, infers each PRD's completion bucket (branch → open PR → last `pre-merge` → frontmatter `status`), fills the `refs/gui/` templates with the collected data as inline JSON, and serves the result GET-only via `python3 -m http.server --bind 127.0.0.1`, opening the default browser. The board is a pure read model: a list page (Kanban ↔ Table toggle, cards grouped into `product/eng/building/review/shipped` columns with tuned/reviewed pills and a todo progress fraction) → a per-PRD detail page (collapsible full PRD body + a TODOs section with its own Kanban ↔ Table toggle and a per-todo side panel showing type/file/action/done-when). Nothing is editable and no PRD file is ever written. The Notion/Legora/Manus look is hardcoded in `refs/gui/styles.css`, identical across every project. With Feature 2's persisted todo `done` field not yet shipped, the GUI degrades gracefully — PRDs with no todos show no fraction (never `0/0`), and where todos exist every item renders Open.

- `.claude/skills/msg/SKILL.md` — add `--gui` dispatch + `Protocol: --gui`; widen `allowed_tools` to add Read/Write/Bash
- `.claude/skills/msg/refs/protocol-gui.md` — new: enumerate PRDs, parse frontmatter/F-IDs/todos, infer completion, fill templates, serve GET-only via `python3 -m http.server`
- `.claude/skills/msg/refs/gui/index.html` — new: self-contained SPA template (kanban/table list, per-PRD detail, todo side panel, hash router)
- `.claude/skills/msg/refs/gui/styles.css` — new: hardcoded Notion/Legora/Manus design system
- `.claude/kermit/pref.json` — bump last_logged_commit pointer

- Add sub-PRD follow-up scope: `/plan-pm --sub [parent path|number]` (plus natural-language triggers like "create a sub-PRD" / "more changes to PRD N") spins off a numbered follow-up PRD (`prd-<n>.<m>`) nested under an existing parent and built on the parent's existing feature branch rather than a new one. Parent is resolved by explicit arg → current-branch inference (`feat/prd-<n>-<slug>`) → an `AskUserQuestion` picker; intake is pre-seeded with the parent title; the sub-PRD gets a new `parent:` frontmatter field and inherits the parent's `module`/`platform`. `scan-n.prd` gains a `sub <parent-n>` mode returning the next nested minor (`.1` if none, numeric-boundary safe); `plan-em`'s build-mode branch step becomes parent-aware and idempotent (reads `parent:`, resolves the parent branch, `git branch --list` → checkout-or-create) and accepts the nested sub-PRD path form; `eng --build` gains the same parent-aware `branch` default for direct invocations; `review` Step 7 prints a sub-PRD next-step offer (no new question). The design named `ship` as the branch owner, but `ship` is no longer in the repo, so that logic landed in `plan-em`, the extant orchestrator. Also bundles an unrelated README credits note and a kermit pointer bump.

- `.claude/scripts/scan-n.prd` — new `sub <parent-n>` next-minor resolver
- `.claude/skills/plan-pm/SKILL.md` — `--sub` mode: triggers, parent resolution, pre-seeded intake, nested path, `parent:` frontmatter
- `.claude/skills/plan-pm/refs/template-prd.md` — document optional `parent:` frontmatter field
- `.claude/skills/plan-em/SKILL.md` — parent-aware + idempotent branch create/checkout; accept nested sub-PRD paths
- `.claude/skills/eng/refs/build/protocol.md` — parent-aware `branch` default for direct sub-PRD builds
- `.claude/skills/review/SKILL.md` — Step 7 prints a sub-PRD next-step offer
- `README.md` — add credits note
- `.claude/kermit/pref.json` — bump last_logged_commit pointer

- Make `/test` run buckets in parallel by default: dispatch each selected, non-skipped bucket as its own `Agent` subagent (replacing the old sequential 1→10 default), carve `load` and `perf` out of the concurrent batch to run isolated so contention can't skew their numbers, and stream each bucket's verdict as its subagent returns before a single final aggregation pass. **Breaking:** the `--fast` flag is removed (ignored with a printed note if passed, not a hard error) and a new `--sequential` flag restores the old in-order in-process run. Propagated through the frontmatter description, Step 3 plan-header tags, the Step 5 aggregator `--parallel` note, `refs/schema.md`'s `parallel` field semantics, and the seven `refs/modes/*` "When it runs" lines that referenced `--fast` (`load`/`perf` reworded to note isolation).

- Remove `plan` and `ship` autonomous orchestrator skills: delete `.claude/skills/plan/SKILL.md` and `.claude/skills/ship/SKILL.md` along with their supporting scripts (`ship-find-prd.sh`, `ship-db-touch.sh`) and settings.json permissions; drop `plan`/`ship` rows and the autonomous-loop-shortcuts section from msg's skill menu and routing tables; remove `/plan` and `/ship` entries from README.md; update ARCHITECTURE.md's pipeline diagram and skill inventory for standalone-only invocation; remove the completed `19-plan-loop-modes` improvement plan/acceptance docs and its `_INDEX.md` entry.

- Sync `kermit`'s `last_logged_commit` pointer in `.claude/kermit/pref.json` to the latest changelog-synced commit.

- Fix msg-init stack detection: carry `STACK_HINTS` through from `init-setup.sh` alongside `PRESENT`/`MISSING`/`STACK_DEFAULT`, skip the platform question only when `STACK_HINTS` has exactly one entry (assigning `PLATFORM` directly) and otherwise pre-select `STACK_DEFAULT` as the question's default; remove a stray `.dart_tool/` duplicate line from the gitignore template.

- Sync `kermit`'s `last_logged_commit` pointer in `.claude/kermit/pref.json` to the latest changelog-synced commit.

- Fix msg skill routing: split hands-off/step-by-step disambiguation for categories with more than 4 rows in Step 2 of the dispatch protocol; add missing `plan` and `ship` rows to the routing table for rough-idea inputs; correct the Reviewing/engineering-plan routing target from `improve` to `eng`.

- Sync `kermit`'s `last_logged_commit` pointer in `.claude/kermit/pref.json` to the latest changelog-synced commit.

- Add `/test --flaky <N>` and `--changed-only` modes: retry failing unit/e2e tests up to N times before counting them as real failures (reclassified with `evidence.flaky`/`evidence.retries` and a `totals.flaky` count); skip whole buckets whose surface a diff doesn't touch when `--changed-only` is paired with `--base`, failing open on ambiguous classification. Restructure `/plan-tune` from 5 to 4 steps, add a `devkit/GLOSSARY.md` §8 cross-check, dedup findings against prior `## Audit` sections with a no-findings clean path, and add Dimension 5g cross-PRD breaking-change consistency to the eng tune. Add an eng-plan self-consistency check (§7 identifiers must appear in Execution steps) and unpin eng's model (warns on Haiku sessions instead).

- Fix 8 pre-merge correctness bugs and cleanup: remove leaked eval_set_path from output schema, delete dead prd_criteria[] input threading, harden resolve-diff.sh with visible git-fetch errors and proper JSON escaping, collapse inconsistent skipped[]/skipped_buckets[] naming, align package-manager examples (npx vs pnpm) and add substitution guidance, delete duplicate detect-tooling.sh script (use shared tooling-detection.md instead), and archive stale pre-merge-plan.md with deprecation notice

- Align /test and /review finding output to the canonical shared finding schema: switch severity from fail/warn to high/medium and nest evidence as an object (tool/file/line/snippet, plus bucket-owned extension keys like mobile's platform/device) across all nine /test mode refs; move assertion classification into /review Step 3 so Coverage and Functional modes share one classification instead of duplicating it, and add an undetected_domain_note surface warning for changed files with no /cook standards shelf; scope FLAG-LIST.md to domain detection only; fix stale §6→§7 and §2→§1 section cross-references in plan-pm; add a multi-platform priority table format to the PRD template

- Remove docu and todo skills: delete SKILL.md, refs/, and scripts/ for both; strip docu and todo from the msg dispatch table, pipeline diagram, and routing table; remove /docu step and hard-refusal note from review pipeline; drop skill references from ARCHITECTURE.md and README.md

- Add pre-flight cross-check step to build protocol: before reading any file, verify the §Engineering section is consistent with the exec-table (every assigned row present, non-blank Execution steps, referenced in §Engineering); surface missing/blank rows as a blocking gap via AskUserQuestion. Tag AHA entries with `severity: escalated` when written at the 3rd failed debug cycle.

- Fix undocumented hidden behaviour and naming convention collision in eng skill: add "Caller override" notes to build/protocol.md Step 5 (full-suite gate) and Step 6 (commit gate) so auditors know ship suppresses both; add a shared-contract warning for the `## Engineering — <Agent>` heading in SKILL.md References; replace `backend-eng`/`mobile-eng` with the correct `eng-backend`/`eng-ios` format across SKILL.md, template-eng-plan.md, and protocol-exec.md so worked examples match the agent naming format plan-em actually produces

- Fix four factual errors in eng skill docs: remove non-existent `--review` mode from the msg router menu entry; fix field count from "shared three" to "shared four" (adds `agent`) in both plan and build mode protocols; replace "single target platform" with "agent's owned stack" in template §1 and §5 (multi-agent PRDs run one eng per stack, not one per platform); label `CLAUDE.md` as project root in the eng pre-flight ref table to distinguish it from `devkit/`-prefixed entries

- Remove completed skills audit plan (update-plan.md) and add update/, update-plan.md, update-plan-done.md to .gitignore

- Align skills pipeline to devkit/ layout, slugged PRD paths (prd-[n]-[slug]), and eng commit-mode contract: migrate all ARCHITECTURE.md/AHA.md/GLOSSARY.md references to devkit/ prefix; add §3 Features & acceptance criteria table to plan-pm PRD template with stable F-IDs carried through to plan-em; add commit_mode direct/sub-branch branch contract to eng --build with direct as default under ship; stamp product-tuned/eng-tuned frontmatter on plan-tune runs; extract shared finding schema to shared/refs/finding-schema.md; align pre-merge, review, test schemas; rewrite plan-tune product-tune dimension checks against new section numbering

- Add source-keyed deduplication to /todo: tasks now carry a `source` field (`<origin>:<stable-key>`) derived deterministically from the source item; append-tasks.sh drops any incoming task whose source already exists in TODOs.json and de-duplicates within the batch, so re-running /todo on the same PRD never doubles tasks; update schema.json to require source, parsing-rules.md with slug rules per input type, and SKILL.md with the assignment step; wire kermit into the msg router skill table and routing table; add update-plan.md with a comprehensive audit of 15 msg skills covering cross-cutting contract failures and per-skill findings

- Add ARCHITECTURE.md documenting MSG layers, scripts, devkit, skill inventory, pipelines, and cook integration; update README skill table with expanded msg-init description and new /plan and /ship entries

- Expand msg-init bootstrap from 5 to 7 steps: add architecture interview (Step 3, five questions covering components, external services, data stores, auth, deployment) and design system interview (Step 4, four questions covering UI layer, component library, tokens, conventions); pass ARCH_* and DS_* env vars to init.sh; replace [USER:] stubs in template-ARCHITECTURE.md and template-DESIGN-SYSTEM.md with {{arch_*}} and {{ds_*}} placeholders; update plan-tune to write full audit section to PRD file and emit a terse per-finding summary table inline; update kermit pref.json with auto_approve/auto_commit/auto_merge flags

- Update kermit pref.json with automation preference flags (auto_approve, auto_commit, auto_merge) and refreshed init_commit SHA

- Ensure installed scripts are executable: chmod +x .sh files and scan-n.prd after copy, and chmod +x any .sh files bundled inside skill directories

- Wire the `/test` skill into the `/ship` pipeline as a dedicated Test stage: restructure the review→fix loop into review → test → fix (loops until both `/review` and `/test` report no issues); route full-suite verification through `/test`, consuming the eval_set via `--eval-set` (falling back to `--prd`), instead of raw runner commands; instruct build agents to skip eng's raw-runner full-suite gate while keeping their per-feature TDD red/green checks; update the pipeline diagram, five-stage table, autonomy contract, permission gates, fix prompt, final summary, and references

- Remove the `design` skill and its `creativity-levels.md` / `ux-laws.md` refs; drop design from the msg menu, routing table, and pipeline diagram, and from the README skill list; rewrite `/plan` from an autonomous loop into a single-pass sequential driver (plan-pm → plan-tune --product → plan-em → plan-tune --eng, each run once with its own gates intact); document ship's four-stage pipeline and align its step titles to the Build / Review → Fix / Pre-merge stages

- Add `/test --init` setup mode: profiles codebase shape, computes the gap against installed runners, gates on a plan, optionally installs tools, and writes a `.claude/test/test.json` cache the execution path reads; add deterministic `test-init-profile.sh` shape profiler and `refs/modes/init.md` decision tables + schema; bootstrap the development eval_set via `/test --prd` in plan-em plan mode and note it in the /plan loop; allow profiler script, test scaffold paths, and test-skill edits in settings.json

- Extract autonomous loop orchestration into new /plan and /ship skills; remove inline --loop / --from-loop modes from eng, plan-pm, plan-tune, and plan-em; add ship-find-prd.sh and ship-db-touch.sh helpers; wire plan/ship into the msg menu; add skill Edit permissions, ship script allowances, and a $CLAUDE_PROJECT_DIR-resolved changelog gate path to settings.json

- Add PRD status lifecycle table to plan-pm (split `tuned` into `product-tuned`, `eng-tuned`, `reviewed`); add §3 per-feature supplement for design-system components and files-touched; update next-step and loop handlers to patch frontmatter after each skill run; update template-prd.md to match

- Add loop mode to plan-pm, plan-em, plan-tune, and eng --build; upgrade next-step prompts from recommend to invoke; add --from-loop flag to plan-tune with [LOOP: PASS/FAIL] signal; add --review flag and adversarial Opus review to improve skill; add review-protocol.md reference

- Add feature-slug suffix to PRD directory and file names (prd-N → prd-N-[slug]); update plan-tune-preflight and scan-n.prd scripts for slugged paths; add improve plan #19 for --loop orchestration; extend .gitignore with al-*.jsonl, evals/, improve subdirs, scheduled tasks lock
- Resolve helper script paths in plan-tune/test/plan-pm independent of cwd, with $HOME/.claude/scripts fallback (fixes exit 127); untrack improve plans, evals, and pre-merge planning artifacts
- Apply eval fixes to eng skill: row matching, agent field, branch locking, test gates
- Remove handoff tracking files and add to .gitignore
- Integrate design skill into msg routing, menu, and handoff; add Figma MCP preflight validation and post-merge evaluation plan
- Add ux-design skill with UX design planning, creativity tiers, and UX laws reference
- Force reinstall of skills and scripts instead of skipping existing ones
- Remove install-standards script and related setup documentation
- Enhance installation script with next steps and GitHub repository update link
- Add deterministic test tooling detection and verdict aggregation scripts to replace manual priority-table walking in /test skill

- Expand tooling-detection rules for bun, biome, oxlint, pip-audit, osv-scanner, webpack, astro, svelte, size-limit

- Add installation script and instructions to README

- Add coverage and mobile test modes to /test skill; update skill suite (eng, handoff, msg-init, msg, plan-em, plan-pm, plan-tune, review, todo)

- Add `/pre-merge` skill with integration, e2e, build, security, and bundle gates
- Reorder improve/_INDEX.md rows to restore monotonic ID sequence
- Add `/test` skill for execution-focused testing (unit, e2e, functional assertions) with eval_set handoff from `/review`
- Refactor `/review` to split test execution: Coverage is now static-only (sibling-test + assertion-reference checks); Functional defers executable assertions to `/test`
- Archive completed 15-review-test-split improvement to done/ subdirectory
- Add review-test-split skill, pre-merge skill, shared tooling-detection refs, and reorganize improve registry numbering
- Add mechanical gates to Quality and Security modes in /review
- Add plan registry (_INDEX.md) to improve skill for centralized plan tracking
- Archive completed improve skills (preflight-rigor, quality-mode-rigor) to done/ subdirectory
- Add Quality-mode rubric, scope-creep wiring via `uncovered_changes[]`, and `(file, line, category)` dedup pass to `/review`
- Add `/review` skill with preflight rigor: eval-set discovery from tests/schemas, FLAG-LIST.md consolidation, main-branch support, flag inventory validation

### Add handoff skill; refactor eng skill to modular protocols

- `.claude/skills/eng/SKILL.md`
- `.claude/skills/eng/refs/build/protocol.md`
- `.claude/skills/eng/refs/plan/protocol.md`
- `.claude/skills/eng/refs/review/protocol.md`
- `.claude/skills/handoff/SKILL.md`
- `.claude/skills/improve/7.1-eng-build/acceptance.md`
- `.claude/skills/improve/7.1-eng-build/plan.md`
- `.claude/skills/improve/7.3-eng-review/acceptance.md`
- `.claude/skills/improve/7.3-eng-review/plan.md`
- `.claude/skills/improve/done/7.2-eng-plan/acceptance.md`
- `.claude/skills/improve/done/7.2-eng-plan/plan.md`
- `.claude/skills/improve/done/8-handoff/acceptance.md`
- `.claude/skills/improve/done/8-handoff/plan.md`
- `handoff/1.md`

---

### `a009b15` — Add CHANGELOG gate hook and `eng` engineering skill

- `.claude/scripts/changelog-gate.py`
- `.claude/settings.json`
- `.claude/skills/eng/SKILL.md`
- `CHANGELOG.md`

---

### `124cfec` — Add agent-creation routing to `/improve`; reorganize devkit

- `.claude/skills/improve/SKILL.md`
- `.claude/skills/improve/done/9-agent-creation-option/acceptance.md`
- `.claude/skills/improve/done/9-agent-creation-option/plan.md`
- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init-setup.sh`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/build/protocol-eng-agent.md`
- `.claude/skills/plan-em/refs/plan/protocol-eng-agent.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `d8e4b00` — Add session-handoff plan to `/improve`; fix `AskUserQuestion` usage

- `.claude/skills/improve/8-handoff/acceptance.md`
- `.claude/skills/improve/8-handoff/plan.md`
- `.claude/skills/improve/SKILL.md`

---

### `8e56788` — Split `7-dev-agent` into three focused sub-skill plans

- `.claude/skills/improve/7-dev-agent/acceptance.md`
- `.claude/skills/improve/7-dev-agent/plan.md`
- `.claude/skills/improve/7.1-eng-build/acceptance.md`
- `.claude/skills/improve/7.1-eng-build/plan.md`
- `.claude/skills/improve/7.2-eng-plan/acceptance.md`
- `.claude/skills/improve/7.2-eng-plan/plan.md`
- `.claude/skills/improve/7.3-eng-review/acceptance.md`
- `.claude/skills/improve/7.3-eng-review/plan.md`
- `.claude/skills/improve/2-plan-major-enhancement/acceptance.md`
- `.claude/skills/improve/2-plan-major-enhancement/plan.md`
- `.claude/skills/improve/done/2-plan-major-enhancement/acceptance.md`
- `.claude/skills/improve/done/2-plan-major-enhancement/plan.md`

---

### `cba7b8a` — Add dev-agent improve plan; triage backlog; streamline `plan-em`

- `.claude/skills/improve/7-dev-agent/acceptance.md`
- `.claude/skills/improve/7-dev-agent/plan.md`
- `.claude/skills/improve/backlog/4-msg-health/acceptance.md`
- `.claude/skills/improve/backlog/4-msg-health/plan.md`
- `.claude/skills/improve/backlog/5-msg-insights/acceptance.md`
- `.claude/skills/improve/backlog/5-msg-insights/plan.md`
- `.claude/skills/improve/backlog/6-msg-learnings/acceptance.md`
- `.claude/skills/improve/backlog/6-msg-learnings/plan.md`
- `.claude/skills/improve/done/3-msg-root-skill/acceptance.md`
- `.claude/skills/improve/done/3-msg-root-skill/plan.md`
- `.claude/skills/plan-em/SKILL.md`

---

### `9f44471` — Add `/msg` root menu skill for discovery

- `.claude/skills/msg/SKILL.md`
- `.gitignore`

---

### `4d234a2` — Add `/improve` skill; restructure `plan-em` refs into build/plan subdirs

- `.claude/settings.json`
- `.claude/skills/improve/SKILL.md`
- `.claude/skills/improve/refs/template.md`
- `.claude/skills/improve/done/1-split-protocol-refs/acceptance.md`
- `.claude/skills/improve/done/1-split-protocol-refs/plan.md`
- `.claude/skills/improve/2-plan-major-enhancement/acceptance.md`
- `.claude/skills/improve/2-plan-major-enhancement/plan.md`
- `.claude/skills/improve/3-msg-root-skill/acceptance.md`
- `.claude/skills/improve/3-msg-root-skill/plan.md`
- `.claude/skills/improve/4-msg-health/acceptance.md`
- `.claude/skills/improve/4-msg-health/plan.md`
- `.claude/skills/improve/5-msg-insights/acceptance.md`
- `.claude/skills/improve/5-msg-insights/plan.md`
- `.claude/skills/improve/6-msg-learnings/acceptance.md`
- `.claude/skills/improve/6-msg-learnings/plan.md`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/build/protocol-eng-agent.md`
- `.claude/skills/plan-em/refs/build/protocol-exec.md`
- `.claude/skills/plan-em/refs/plan/protocol-eng-agent.md`
- `.claude/skills/plan-em/refs/plan/template-eng-plan.md`
- `README.md`

---

### `de51e9a` — Remove standalone scripts; consolidate logic inline into skills

- `.claude/scripts/check-staged.sh`
- `.claude/scripts/detect-platform.sh`
- `.claude/scripts/plan-em-eng-scan.sh`
- `.claude/scripts/validate-prd.sh`
- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/refs/protocol-interview.md`
- `.gitignore`
- `README.md`

---

### `0e7a4d8` — Remove `eng-web` skills and scripts after consolidation

- `.claude/scripts/eng-web-build-preflight.sh`
- `.claude/scripts/eng-web-plan-check-prd.sh`
- `.claude/scripts/eng-web-plan-extract-rows.sh`
- `.claude/settings.json`
- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-build/refs/performance.md`
- `.claude/skills/eng-web-build/refs/testing.md`
- `.claude/skills/eng-web-plan/SKILL.md`

---

### `9012b50` — Harden `plan-tune` preflight into script; split `tune.md` by mode

- `.claude/scripts/plan-tune-preflight.sh`
- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune-eng.md`
- `.claude/skills/plan-tune/refs/tune-product.md`
- `.claude/skills/plan-tune/refs/tune.md`

---

### `2be7b06` — Add two tune modes to `plan-tune` with dimension 5 eng audit

- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune.md`

---

### `38af510` — Move `msg-commit` protocol rules inline; add auto-trigger hook

- `.claude/settings.json`
- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/msg-commit/refs/protocol.md`

---

### `3d3e4af` — Add on-demand performance and testing refs for `eng-web`

- `.claude/scripts/eng-web-build-preflight.sh`
- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-build/refs/performance.md`
- `.claude/skills/eng-web-build/refs/testing.md`
- `.claude/skills/eng-web-plan/SKILL.md`

---

### `d3e6a02` — Add preflight and extraction scripts to `eng-web` skills

- `.claude/scripts/eng-web-build-preflight.sh`
- `.claude/scripts/eng-web-plan-check-prd.sh`
- `.claude/scripts/eng-web-plan-extract-rows.sh`
- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-plan/SKILL.md`

---

### `c46c303` — Add `CHANGELOG.md` and `OPEN-QUESTIONS.md` templates to `msg-init`

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init-setup.sh`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/refs/template-CHANGELOG.md`
- `.claude/skills/msg-init/refs/template-OPEN-QUESTIONS.md`
- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-build/refs/protocol-build.md`
- `.claude/skills/eng-web-plan/SKILL.md`
- `.claude/skills/plan-em/SKILL.md`

---

### `c438a5a` — Split `eng-web` into separate plan and build skills

- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-build/refs/protocol-build.md`
- `.claude/skills/eng-web-plan/SKILL.md`
- `.claude/skills/eng-web/SKILL.md`

---

### `ce1ca7f` — Add `eng-web` SKILL.md definition

- `.claude/skills/eng-web/SKILL.md`

---

### `b6e3905` — Add `DESIGN-SYSTEM.md` template to `msg-init` for component registry tracking

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init-setup.sh`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/refs/template-DESIGN-SYSTEM.md`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `60e845b` — Clarify `plan-em` two-mode protocol; suggest branch names at synthesis

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/protocol-eng-agent.md`
- `.claude/skills/plan-em/refs/template-eng-plan.md`
- `.claude/skills/msg-init/refs/template-CLAUDE.md`
- `.claude/skills/msg-init/refs/template-GLOSSARY.md`

---

### `bc7f8a3` — Add `plan-em-eng-scan.sh` for deterministic codebase search

- `.claude/scripts/plan-em-eng-scan.sh`
- `.claude/skills/plan-em/SKILL.md`

---

### `00f0f19` — Add multi-PRD dependency and conflict tracking via frontmatter

- `.claude/scripts/plan-em-eng-scan.sh`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/template-prd.md`

---

### `8cf629b` — Rename `plan-pm` interview protocol ref to `protocol-interview`

- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/interview-protocol.md`
- `.claude/skills/plan-pm/refs/protocol-interview.md`

---

### `0657d92` — Add multi-PRD mode and execution step protocol to `plan-em`

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/protocol-exec.md`
- `.claude/skills/plan-em/refs/template-exec-table.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `b97ceb1` — Defer execution step format to per-agent specs in `plan-em`

- `.claude/skills/plan-em/refs/template-exec-table.md`

---

### `d511067` — Rename RFC template to `eng-plan`; add execution table template

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/principles.md`
- `.claude/skills/plan-em/refs/template-eng-plan.md`
- `.claude/skills/plan-em/refs/template-exec-table.md`
- `.claude/skills/plan-em/refs/template-rfc.md`

---

### `0e9fd9c` — Remove problem statement; add open questions loop and expand integration contracts

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/template-rfc.md`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/template-prd.md`

---

### `a51f474` — Consolidate `plan-em` refs; redesign agent orchestration

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/emit-protocol.md`
- `.claude/skills/plan-em/refs/scope-matrix.md`

---

### `488658b` — Add `platform`, `status`, and `tuned` fields to `plan-pm` PRD template

- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/template-prd.md`

---

### `efb475f` — Consolidate `plan-tune` spec audit details into `refs/tune.md`

- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune.md`

---

### `dabf369` — Add Flutter, Expo, Desktop, and Backend to `detect-platform`

- `.claude/scripts/detect-platform.sh`

---

### `29c3529` — Conditionally capture `AHA.md` in `plan-pm` and `plan-em`

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `60c2764` — Include `CLAUDE.md` in `plan-pm` foundational files check

- `.claude/skills/plan-pm/SKILL.md`

---

### `1c8f42d` — Clarify `plan-pm` PRD steps; extract error template ref

- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/template-error.md`
- `.claude/skills/plan-pm/refs/template-prd.md`
- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune-checklist.md`
- `.claude/skills/plan-tune/refs/tune.md`

---

### `3560da2` — Fix `plan-tune` audit findings for specificity and consistency

- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune-checklist.md`

---

### `fc4cbbd` — Simplify `plan-pm` interview; auto-detect platform; always recommend features

- `.claude/scripts/detect-platform.sh`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/interview-protocol.md`

---

### `a4be5b5` — Clarify `msg-commit` protocol steps; extract subject line rules

- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/msg-commit/refs/protocol.md`

---

### `d821302` — Simplify `plan-pm` PRD template

- `.claude/skills/plan-pm/refs/template-prd.md`

---

### `d06df46` — Extract `plan-em` emit protocol to separate reference file

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/emit-protocol.md`

---

### `20a8bb8` — Remove redundant inputs and outputs sections from `msg-commit`

- `.claude/skills/msg-commit/SKILL.md`

---

### `e379209` — Simplify `msg-init` language selection to free text with normalization

- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/install-standards.sh`

---

### `411cb4a` — Add commit & push option; extract examples to `protocol.md`

- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/msg-commit/refs/protocol.md`

---

### `2040008` — Add language selection and coding standards installation to `msg-init`

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init-setup.sh`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/install-standards.sh`
- `.claude/skills/msg-init/refs/template-gitignore.md`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/interview-protocol.md`

---

### `1d035e2` — Harden `msg-init` Step 3 with deterministic `init.sh` script

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/refs/substitution-rules.md`

---

### `60908e4` — Add output rules to `msg-commit` to suppress step progress messages

- `.claude/skills/msg-commit/SKILL.md`

---

### `55e2f54` — Add `check-staged.sh` to gate `msg-commit` on non-empty diffs

- `.claude/scripts/check-staged.sh`
- `.claude/skills/msg-commit/SKILL.md`

---

### `bbd9b6a` — Add `msg-init` project bootstrap skill with template files

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/refs/substitution-rules.md`
- `.claude/skills/msg-init/refs/template-AHA.md`
- `.claude/skills/msg-init/refs/template-ARCHITECTURE.md`
- `.claude/skills/msg-init/refs/template-CLAUDE.md`
- `.claude/skills/msg-init/refs/template-GLOSSARY.md`
- `.claude/skills/msg-init/refs/template-README.md`
- `.claude/skills/msg-init/refs/template-gitignore.md`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/interview-protocol.md`

---

### `a0a1113` — Improve `msg-commit` empty-diff message

- `.claude/skills/msg-commit/SKILL.md`

---

### `96c8952` — Restrict `msg-commit` to staged diff only; switch model to Haiku

- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `ff9e32b` — `plan-tune` applies audit findings inline instead of writing a report file

- `.claude/skills/plan-tune/SKILL.md`

---

### `fd1ddf9` — Add copy/commit prompt after message generation in `msg-commit`

- `.claude/skills/msg-commit/SKILL.md`

- Document OPEN-QUESTIONS.md logging protocol in eng build/protocol.md for unresolved ambiguities during build; clarify CHANGELOG.md is now maintained by the kermit commit-gate hook (not written by subagents) in msg-init SKILL.md and its template; add /plan resume mode (start mid-pipeline from an existing PRD path via frontmatter status), a between-stage guard verifying prior-stage artifacts exist, explicit failure handling on sub-skill refusal, and an end-of-run prompt to chain into /ship on a clean eng-tune.

- Sync `kermit`'s `last_logged_commit` pointer in `.claude/kermit/pref.json` to the latest changelog-synced commit.

- Exclude `handoff` and `improve` from the installed skill set — `handoff` is deleted from the repo entirely (no longer part of the msg suite), and `improve` is now explicitly kept repo-local via a `LOCAL_ONLY_SKILLS` list in `install.sh` so it never ships to `~/.claude/skills`; `msg/SKILL.md`, `README.md`, and `ARCHITECTURE.md` menus/inventories updated to match.

- `.claude/skills/handoff/SKILL.md` — deleted
- `.claude/skills/msg/SKILL.md` — dropped handoff row, routing entry, and pipeline branch; reworded Delivery/Wrapping-up copy
- `ARCHITECTURE.md` — removed handoff from skill inventory; documented improve's install exclusion
- `README.md` — removed handoff and improve rows from skills table
- `install.sh` — added `LOCAL_ONLY_SKILLS` exclusion list

- Remove per-skill `model:` frontmatter pins so skills run on whichever model the invoking session is already using, instead of forcing a specific one; also drop a stale model-upgrade note from `eng` and Opus-specific wording from `improve`'s `--review` mode.

- `.claude/skills/eng/SKILL.md` — drop stale model-upgrade note
- `.claude/skills/improve/SKILL.md` — remove `model:` pin; drop Opus-specific wording in `--review` mode
- `.claude/skills/msg/SKILL.md` — remove `model:` pin
- `.claude/skills/msg-init/SKILL.md` — remove `model:` pin
- `.claude/skills/plan-em/SKILL.md` — remove `model:` pin
- `.claude/skills/plan-pm/SKILL.md` — remove `model:` pin
- `.claude/skills/plan-tune/SKILL.md` — remove `model:` pin
- `.claude/skills/pre-merge/SKILL.md` — remove `model:` pin
- `.claude/skills/review/SKILL.md` — remove `model:` pin
- `.claude/skills/test/SKILL.md` — remove `model:` pin

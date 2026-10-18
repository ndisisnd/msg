---
name: eng --build — report orchestrated
description: The default route for eng --build report=<path>. An Opus fix-build orchestrator session that reads the fix plan (or projects issues from the issues file report-prd-<N>-<K>.json), grades each issue simple|complex, and fans the fixes out to per-issue subagents (model=sonnet for simple, model=opus for complex). Bypassed by orchestrate=off, which runs the flat single-agent flow in fix-build.md.
type: reference
---

# eng --build — `report` orchestrated

Loaded **by default** when `--build` is invoked with `report=<path>` (the `orchestrate=on` default — see `fix-build.md` § Orchestration routing). Pass `orchestrate=off` to skip this orchestrator and run the flat single-agent flow documented in `fix-build.md` instead.

This ref owns only the **orchestration layer** — session model, plan/rubric-driven complexity grading, per-issue subagent fan-out, post-return re-verification, and loop-close. Every leaf contract it drives — the finding→issue-ticket projection, the per-issue reproduce→fix→verify-green flow, one-commit-per-issue, the 3-attempt limit per bug, and the `followUp.status` write — lives in the sibling refs below and is **cited, never duplicated**.

## Session model — Opus orchestrator

This session runs as **Opus** and does not write code itself. It coordinates per-issue fix **subagents** spawned via the `Agent` tool, keeping the orchestrator on Opus regardless of which tier each subagent runs on. The only tiers in play are the two named in § Complexity rubric (fast and deep).

## Step 0 — Load tickets + complexity grades

Resolve the issue set and each issue's `complexity` (`simple` | `complex` — § Complexity rubric), in priority order:

1. **Fix plan present** — `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>-fix-plan.md` exists (same `<N>`/`<K>` as the issues file; written by `eng --plan report=…` per `../plan/fix-plan.md`). Read its tickets and take each ticket's `complexity` tag as authoritative. This is the normal path — `pre-merge`/`merge` reach here through the automatic fix loop (`../../../shared/refs/fix-loop.md`), which plans before it builds.
2. **No fix plan** — project the tickets directly from the issues file's `issues[]` by running `script-project-findings.py` (**`fix-build.md` § Finding → issue-ticket projection** — read-time view, never a rewrite; call it, do not re-derive), then grade each projected issue's `complexity` via the rubric below.

## Complexity rubric

**This is the one definition of simple-vs-complex in eng, and it is executable, not prose.** `../plan/fix-plan.md` grades ahead of time by calling the same script; this file carries the definition because it is the fallback grader when no plan tag exists. The plan's tag, when present, always wins.

```bash
G=.claude/scripts/script-eng-fix-grade.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-eng-fix-grade.py"; python3 "$G" "<report-path>"
```

Pipe tickets in on `-` to grade a grouped ticket carrying more than one file. **Inputs:** `files` length (or `file`) · `category` · `suggestion` · `regression_of` · `file` null · `repro`. Each issue returns `GRADE id=… complexity=simple|complex tier=fast|deep model=… reason=…`.

**Escalate, never downgrade.** `simple` → `complex` is the orchestrator's one power over the grade — use it when an issue looks scarier than its fields suggest. `complex` → `simple` is forbidden: an over-powered subagent is safe, an under-powered one on a security or migration fix is not.

**Tier → model (the one mapping line):** fast = `model: sonnet` · deep = `model: opus`, in the script's `TIER` table. A model-family change is that line, nowhere else.

## Step 1 — Route each issue to a fix subagent

For each issue/ticket, spawn one fix subagent via the `Agent` tool with `model` set from the grade's tier (§ Complexity rubric — tier → model), per the § Subagent contract below. In particular:

- Each subagent runs the msg skill `eng --build report=<path> orchestrate=off attempts_left=<n>` scoped to its **single** issue, with `branch` defaulted from the issues file's `context.branch` and `commit_mode=direct` (per `fix-build.md` § Branch default). **`orchestrate=off` is always passed**, so a fixer never starts another coordinator. `attempts_left` is 3 on the first spawn (§ Step 3).
- **Inject the review-artifact identity** with the ticket: `<K>` = `<K-of-the-issues-file>-fix-<issue-id>` and `built_by` = the subagent's assigned tier/agent. A fix produces a diff, so its review is unconditional (`protocol-packet.md` Step 5) and writes `reports/review-prd-<N>-<K>-fix-<issue-id>.json`. The per-issue suffix keeps parallel fixers from colliding on one artifact name.

Independent issues fan out in parallel (spawn in a single message). Order any issue whose fix another issue depends on first — findings carry no `depends-on`, so this only matters when two issues touch the same file; serialize those onto one subagent to avoid a race on the shared branch.

## Subagent contract

Every fix subagent is spawned via the `Agent` tool and **runs an msg skill — never general-purpose**. Each prompt is prefixed with the **autonomy paragraph**:

> You are running autonomously with no user present, as part of an orchestrated fix build. When the skill's protocol reaches an approval gate (`AskUserQuestion`), treat it as pre-approved and proceed. Only stop if genuinely blocked by missing information you cannot derive — if so, return the blocker instead of guessing. Read `.claude/skills/<skill>/SKILL.md` fully and follow its protocol.

**Injected context.** The orchestrator has already read the issues file, so each prompt carries the subagent's **single** issue-ticket (its `files`, `repro`, `done-when`, and preserved diagnostic fields) rather than making the leaf re-read and re-project the whole issues file. Include this escape hatch in the prompt: *"The full issues file is at `<report-path>`; read it on demand only if the scoped ticket is insufficient."* Scope-enforcement and the branch contract are unchanged — the subagent touches only its own issue's files and commits only to `branch`.

**Return contract:** each fixer returns the one JSON object defined in `fix-build.md` § Output — the same shape this coordinator parses, **never** free-form prose. A fixer that dies or returns output that does not parse as that object is re-spawned once, and the re-spawn counts as one attempt (§ Step 3). A second failure escalates.

## Step 2 — Per-issue fix flow (inside each fixer)

Each fixer runs the **flat per-issue flow — cited, not duplicated**:

- Reproduce → fix → verify, and flaky handling: `fix-build.md` § Deltas on the build loop.
- **One commit per issue**, with the two staged-diff gates (comment scan, commit cap): `protocol-packet.md` Step 7.
- A still-red issue enters debug mode (`protocol-build-debug.md`) with the `attempts_left` it was given.

## Step 3 — Re-verify on return; 3 attempts per bug in total

After a fixer returns, the **coordinator re-runs that ticket's covering test / `done-when`** itself before marking it done — a fixer's self-reported green is not trusted blind.

**Count every attempt on one bug together** — the fixer's first fix, its debug rounds, and each re-entry or re-spawn here — and stop at **3** (`protocol-build-debug.md` § The limit). The returned `attempts` field carries the fixer's share.

- **Green** — mark the ticket done.
- **Still red, attempts used < 3** — re-enter a fixer with the residual failure and `attempts_left = 3 − used`.
- **Still red, 3 attempts used** (or the fixer returned `escalated`) — stop. The bug is not retried again in this run. Mark it escalated and keep its escalation block for § Step 4.

## Step 3a — Review coverage before closing the loop

This coordinator spawns builds and consolidates them, so it runs the same mechanical check every other spawn site runs — a fix is code, and code is never left unreviewed. Before the loop-close below:

```bash
R=.claude/scripts/script-eng-review-check.sh; [ -f "$R" ] || R="$HOME/.claude/scripts/script-eng-review-check.sh"
bash "$R" --reports-dir "features/prd-<N>-<slug>/reports" --expect "<K>-fix-<id1>,<K>-fix-<id2>,…"
```

Exit 0 → quote the coverage line in the roll-up summary. Exit 1 → spawn **one** `eng --review` over that issue's commits (never the subagent that wrote the fix), injecting `built_by` and the same `<K>-fix-<issue-id>`, then re-check once; a second miss escalates in the roll-up and logs a `tool-error:review-<K>-fix-<id>` row per `../../../shared/refs/doctor-logging.md`. Exit 2 or an absent script is `validator-fail:script-eng-review-check`, never coverage. A re-review never re-runs a fix subagent and never touches its commits.

**Re-test after a re-review.** When the re-reviewer's `fixed[]` is not empty, run the project's unit + integration suite before the loop-close. A failure goes to debug mode (`protocol-build-debug.md`). Then commit the reviewer's fixes as `fix(review): <what> [<K>-fix-<issue-id>]`. When `fixed[]` is empty, nothing extra runs.

The roll-up must state coverage (`reviewed <n>/<n> issues`); one that cannot is a hard failure, not a footnote.

## Step 4 — Close the loop

Once every ticket is done or escalated, write the **single** issues-file mutation — `followUp.status` — by running `script-eng-close-loop.py` per `fix-build.md` § Closing the loop (call it, never hand-edit the JSON):

```bash
C=.claude/scripts/script-eng-close-loop.py; [ -f "$C" ] || C="$HOME/.claude/scripts/script-eng-close-loop.py"; python3 "$C" "<report-path>" resolved|partially_resolved
```

- every issue verified green → `resolved`
- one or more issues escalated (3 attempts used) or left unreproduced (flaky) → `partially_resolved`

This is the **only** write to the issues file `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`, and the script proves it — `issues[]` and every other field stay byte-identical. Then write the escalation blocks of every escalated bug to `report-prd-<N>-<K>-escalation.md` (`fix-build.md` § Escalations).

Emit an `Issue`-keyed roll-up (per ticket: status, attempts, model), result line first. For each escalated bug, the closing message says it needs a deeper investigation in a separate session, shows what was tried, and names the command: `/eng --plan report=<issues path>` in a new session. After loop-close the user re-runs the gate (`/pre-merge` or `/merge`) — the fixed branch comes back through the same gate (`fix-loop.md` § Re-entry).

## References (cited, not duplicated)

- `fix-build.md` — finding→issue-ticket projection, the per-issue deltas, the one return format, escalations, `followUp.status` loop-close, `orchestrate=off`
- `.claude/scripts/script-project-findings.py` — the one projection implementation + issues-file validator · `.claude/scripts/script-eng-fix-grade.py` — the executable complexity rubric (escalate-only) · `.claude/scripts/script-eng-close-loop.py` — the one sanctioned `followUp.status` write
- `protocol-packet.md` Step 5 — the unconditional whole-change review each fixer spawns · Step 7 — one commit per issue + the two commit gates
- `../review/protocol.md` § Artifact — the review evidence file Step 3a checks for · `.claude/scripts/script-eng-review-check.sh` — the coverage check itself
- `protocol-build-debug.md` — the 3-attempt limit per bug and the escalation block
- `../plan/fix-plan.md` — writes `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>-fix-plan.md` with the `complexity` tags this orchestrator reads
- `../../../shared/refs/fix-loop.md` — the post-failure sequence that routes here as its **Build** step

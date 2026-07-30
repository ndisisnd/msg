---
name: eng-review
description: eng --review — one adversarial, whole-change review run by a separate reviewer subagent. Spawned by --build after the full-suite gate and before the human commit confirm, and available standalone against any branch's diff.
type: reference
---

# eng — Mode: `--review`

One review, whole-change, run by a reviewer that did **not** write the code. It reads the diff, attacks it, fixes what is unambiguous, and returns findings. It is **not** the safety floor — `pre-merge`'s unconditional green run is; this mode never blocks on anything below `high`.

**Two surfaces, one protocol.**

- **Spawned by `--build`** — after the full-suite gate (`refs/build/protocol.md` Step 5) and **before** the human commit confirm (Step 6), on every build with a diff. No size threshold, no skip, no fast path.
- **Standalone** — `/eng --review` on demand, any branch, any time, with no preceding build. No PRD, no tickets and no wave are required; whatever inputs are absent are simply not used.

---

## Step 1 — Resolve the change set

Uncommitted work if there is any (`git diff HEAD`), otherwise the branch against its base (`git diff $(git merge-base HEAD <base>)...HEAD`). State which you used and the changed-file count. Nothing to review → say so and stop.

## Step 2 — Inputs

| Input | Where it comes from | When absent |
|---|---|---|
| **The diff** | Step 1 — the only required input | No diff, no review: stop |
| **The tickets' `done-when`** | The `## Todos — <Agent>` blocks the build worked (parent-injected on the spawned path) | Judge scope against the diff's own stated intent |
| **PRD acceptance criteria** | The digest, never the whole PRD: `script-prd-digest.py "<prd-path>" --slice build --feature <F-ID>` — the F-ID row carries the criterion verbatim | Standalone runs usually have no PRD; review the diff on its own terms |

No `/cook` call — coding standards are not this mode's job.

## Step 3 — Review

Review as a **principal engineer** for this platform (the exec-table **Agent** column parameterises this when present — `eng-ios` → iOS).

**Attack the diff. Do not confirm it.** Assume it is wrong and find the case that proves it — the input that breaks it, the caller it forgets, the assumption it silently relies on. A review that concludes "looks fine" without having tried to break it has not happened.

Hunt these, in priority order: (1) logic errors in the new path — inverted conditions, off-by-one, mishandled empty/null/zero/negative; (2) **contract breakage** — a changed signature, return semantic, raised error, or side effect that breaks a caller *outside* the diff; (3) state, concurrency, lifecycle — races, leaks, half-committed transactions, non-idempotent retries; (4) silent failure — swallowed errors, over-broad catches, degrading where it should surface; (5) security *reasoning* — an auth check weakened, a trust boundary crossed, input reaching somewhere the design assumed it couldn't; (6) data integrity and migration correctness; (7) code that shouldn't exist — re-implementing something the codebase already has, contradicting an existing pattern, dead branches, one-caller indirection, anything past the ticket's `done-when` or the feature's acceptance criterion, hand-rolled code a stdlib call replaces.

**Test honesty** is inside (1) and (7), not a separate hunt: a test asserting nothing, asserting the implementation back to itself, or skipped/`xfail`-ed to go green is a logic error in the change, not a coverage question.

**Not yours.** Style, naming, formatting, idiom — `cook` owns those. Anything a linter or type-checker catches. Test coverage or quality, CVE scanning, perf, a11y, e2e — `pre-merge` owns those. Defects that pre-date the diff — flag only what this change introduces. "Could also be written this way" with no bug attached.

**One exception — plain-English comments (A4).** Every new or modified function, module, class and exported symbol carries a comment on the line above saying in plain English **what** it does, not **how**. `script-eng-comment-scan.sh` catches a *missing* comment at the commit gate; it cannot read one, so judging what-versus-how is yours and yours alone. `// increments i by one` is a how-comment and fails; `// counts orders still unpaid` is a what-comment and passes. **This is the only convention you check** — it is here because nothing else can check it, not because conventions are in scope.

**Context.** The diff is enough. One exception: when a hunk changes a **public contract** — signature, exported type, schema, config key, externally-observable behaviour — read its call sites before judging it, because the diff cannot prove they still hold.

## Step 4 — Act

Two outcomes only. Either **this breaks something** → act, or **you are not confident enough to be worth a human's attention** → stay silent. No hedged findings. Confirm each finding against the code (call sites included) before reporting; drop what you cannot confirm. Unambiguous bug with one clear fix → fix it, one line saying what and why. Fix **only** what the review found, and write or run no tests for fixes — testing happens downstream. Fix needs a call about intended behaviour → do not choose; report it as a question. **Zero findings on a clean diff is a correct result.** Do not manufacture a finding to have something to say.

**A4 is disposed of separately.** A missing or how-not-what comment is not a defect and does not go through the speak-or-silence test — just write the comment and move on. Report it as a count, never as a list of findings. It must not become a reason to break silence on an otherwise clean diff.

---

## Findings — schema, severity, and what gates

Findings that outlive the run are canonical findings per `../../../shared/refs/finding-schema.md`, emitted with **`source: eng:review`** and the closest concern `category`. Do not invent fields; the schema's field set is closed.

The speak-or-silence test above decides **whether** a finding exists. Once it exists, grade it on the schema's four-level enum (`blocker`/`high`/`medium`/`low`) using the reachability weighting the schema's § Severity enum already defines — there is no separate rubric here or anywhere else. Reachable-and-confirmed is `high` or above; confirmed-but-reachability-unclear is `medium`.

**What gates.** Every `blocker` and `high` must be resolved — fixed here, or answered by the human on the question path — **before** the build's commit confirm. `medium` and `low` are recorded and do **not** gate: they travel in the return payload and the build summary. Nothing this mode reports blocks a merge; the merge floor stays `pre-merge`'s green run.

## Return contract

Return one JSON object (not prose) — the schema's § Subagent return contract applies verbatim:

```json
{
  "verdict": "pass" | "warn" | "block",
  "reviewed": {"files": <n>, "basis": "working-diff" | "branch-base"},
  "fixed": [{"file": "<path>", "why": "<one line>"}],
  "questions": ["<intended-behaviour call the reviewer refused to make>"],
  "comments_added": <n>,
  "findings": [ /* canonical findings, source: eng:review — [] when clean */ ]
}
```

`verdict` is `block` while any unresolved `blocker`/`high` remains, `warn` for medium/low only, `pass` when clean. `findings` is always an array. The chat one-liner is `reviewed <n> files — <k> fixed, <q> questions, <c> comments added`, or `— clean`.

## Spawning (the `--build` path)

The parent spawns exactly **one** reviewer via the `Agent` tool under `refs/build/fix-build-orchestrated.md` § Subagent contract — cited, not restated: msg skill (`eng --review`) never general-purpose, that section's autonomy paragraph, Step 2's inputs injected rather than re-read, PRD path as the escape hatch. It is a *separate* subagent so it does not inherit the builder's assumptions; that independence is the point of the split, so never fold the review back into the building agent.

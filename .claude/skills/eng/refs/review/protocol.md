---
name: eng-review
description: eng --review — adversarial whole-change review by a separate reviewer subagent.
type: reference
---

# eng — Mode: `--review`

One review, whole change, by an agent that did not write the code. Not the safety floor — `pre-merge`'s green run is; nothing below `high` blocks here. Spawned by `--build` at `refs/build/protocol.md` Step 5a, or standalone.

## Step 1 — Resolve the change set

Uncommitted work if any (`git diff HEAD`), else branch vs base (`git diff $(git merge-base HEAD <base>)...HEAD`). State which, and the changed-file count. Nothing to review → stop and say so.

## Step 2 — Inputs

| Input | Source | When absent |
|---|---|---|
| **The diff** | Step 1; required input | Stop |
| **Tickets' `done-when`** | `## Todos — <Agent>` blocks the build worked; injected when spawned | Judge scope from the diff's stated intent |
| **PRD acceptance criteria** | The digest, never the whole PRD: `script-prd-digest.py "<prd-path>" --slice build --feature <F-ID>` | Review the diff on its own terms; a non-zero digest exit (`FEATURE_NOT_RESOLVED`/`FEATURE_ID_EMPTY`) counts as absent — itself worth a finding |


## Step 3 — Review

Review as a **principal engineer** for this platform (the exec-table **Agent** column parameterises it). **Attack the diff; do not confirm it.** Hunt in priority order:

1. **Logic errors in the new path** — inverted conditions, off-by-one, empty/null/zero/negative.
2. **Contract breakage** — signature, return semantic or side effect breaking a caller *outside* the diff.
3. **State, concurrency, lifecycle** — races, leaks, non-idempotent retries.
4. **Silent failure** — swallowed errors, over-broad catches.
5. **Security *reasoning*** — weakened auth check, crossed trust boundary.
6. **Data integrity and migration correctness**.
7. **Code that shouldn't exist** — duplication, dead branch, one-caller indirection, work past `done-when` or the acceptance criterion.

Test honesty is inside (1) and (7): asserting nothing, asserting the implementation back, skipped to go green.

**Not yours.** Style, naming, idiom (`cook`); linter/type-checker catches; coverage, CVE, perf, a11y, e2e (`pre-merge`); pre-existing defects; rewrites with no bug.

**A4 comments — the only convention you check.** Every new or modified function, module, class and exported symbol carries a comment above it saying **what** it does, not how. The commit-gate scan (`script-eng-comment-scan.sh`) proves presence only; judging what-versus-how is yours.

**Context.** Diff-only — except a hunk changing a **public contract** (signature, exported type, schema, config key, externally-observable behaviour): read its call sites first.

## Step 4 — Act

Two outcomes: **it breaks something** → act; **not confident enough for a human's attention** → stay silent. No hedged findings. Confirm each finding against the code, call sites included, **before reporting**; drop what you cannot. Unambiguous bug, one clear fix → fix it, one line why; nothing else, no tests. A behaviour call is a question, not yours. **Zero findings on a clean diff is a correct result** — never manufacture one. A4 is separate: write the comment, report a count, never a finding; it never breaks silence.

## Findings — severity and gating

Canonical findings per `../../../shared/refs/finding-schema.md`, **`source: eng:review`**, closest concern `category`, closed field set. Step 4 decides *whether* a finding exists; grade it on the schema's `blocker`/`high`/`medium`/`low` enum by its § Severity reachability weighting. Reachable-and-confirmed is `high`+; reachability-unclear `medium`.

**What gates.** Every `blocker`/`high` resolves — fixed here or answered by the human — **before** the build's commit confirm. `medium`/`low` are recorded, do **not** gate; nothing here blocks a merge.

## Return contract

One JSON object — the schema's § Subagent return contract:

```json
{
  "verdict": "pass" | "warn" | "block",
  "reviewed": {"files": <n>, "basis": "working-diff" | "branch-base"},
  "reviewed_by": "<this reviewer's agent identity>",
  "built_by": "<the packet key or agent that wrote the code under review>",
  "packets": ["<packet key>", …],   // batched wave review only — see § Batched wave reviews
  "fixed": [{"file": "<path>", "why": "<one line>"}],
  "questions": ["<behaviour call the reviewer refused to make>"],
  "comments_added": <n>,
  "findings": [ /* canonical findings — [] when clean */ ]
}
```

`verdict` is `block` while any `blocker`/`high` is unresolved, `warn` for medium/low only, `pass` when clean; `findings` always an array. One-liner: `reviewed <n> files — <k> fixed, <q> questions, <c> comments added`, or `— clean`.

`reviewed_by` and `built_by` are what make this file's opening rule — *an agent that did not write the code* — a checkable fact rather than an aspiration: the coverage check (§ Artifact) fails an artifact whose two identities match. Both come from the spawner's injected context; a reviewer never invents them.

## Artifact — the proof the review ran

**Write the same object to `<prd-dir>/reports/review-prd-<N>-<K>.json` before returning it.** A self-reported review is exactly what a skipped review looks like from the outside, so presence must be a filesystem fact. The folder is the PRD's existing `reports/`, alongside the `report-prd-<N>-<K>.json` issues file (`../../../shared/refs/finding-schema.md`) — no new location, no new schema; the findings inside are byte-identical to the ones returned.

- `<N>` is the PRD number; `<K>` is the **packet/agent key the spawner injected** — the orchestrator's packet key (`P1`, `P2`, …), which is the same key the coverage check is handed as `--expect` and the same one that appears in the decomposition table. A standalone build injects the `<K>` of its own run report.
- **Write-then-return.** Write to a temp file in the same folder and `mv` it into place, so a reviewer that dies mid-run leaves no half-written artifact for a checker to read as a completed review.
- No injected `<K>`, or the write fails: say so in the returned one-liner and log one `write-miss:review-prd-<N>-<K>.json` row per `../../../shared/refs/doctor-logging.md`. Do **not** invent a key — the caller's coverage check will read the gap as a miss and re-spawn a reviewer, which is the cheap and correct repair.

Presence is verified mechanically by the caller, never by reading a summary:

```bash
R=.claude/scripts/script-eng-review-check.sh; [ -f "$R" ] || R="$HOME/.claude/scripts/script-eng-review-check.sh"
bash "$R" --reports-dir "<prd-dir>/reports" --expect "<k1,k2,…>"
```

Exit 0 = every expected key covered, with a one-line coverage summary; exit 1 = one `MISSING <k>` / `SELF-REVIEWED <k>` line per gap; 2 = usage; 3 = expectation underivable. An artifact that does not parse counts as **missing**, never as covered.

## Batched wave reviews (`packets`)

One reviewer may cover **several mechanical packets at once** — the orchestrator's batched wave review (`plan-em/refs/protocol-team.md` § Build wave step 4). Nothing about the review itself changes; only the artifact's identity does:

- `<K>` is the **wave key** the orchestrator injects (`W1`, `W2`, …), so the file is `review-prd-<N>-W<w>.json` and cannot collide with a per-packet artifact.
- **`packets` is required on a batched artifact** and lists every packet key the review covered. This is what makes the batch checkable: the coverage check accepts the wave artifact as satisfying each of those member keys, so `--expect P2,P3` passes on a single `review-prd-12-W1.json` carrying `"packets": ["P2","P3"]`. Omit the field and the batch proves nothing — each member key reads as `MISSING` and gets a reviewer re-spawned.
- `built_by` becomes the **list** of the covered packets' builders (a single string stays legal for a single-packet review). The self-review rule tightens accordingly: the artifact fails if `reviewed_by` matches *any* builder in that list, because a reviewer that built one of the packets it is reviewing is exactly the conflict the rule exists to prevent.
- A per-packet review never carries `packets`. Coverage granularity is a property of who spawned the reviewer, never something the reviewer decides for itself.

## Spawning

Spawn exactly **one** reviewer via `Agent` under `refs/build/fix-build-orchestrated.md` § Subagent contract — cited, not restated: msg skill (`eng --review`), never general-purpose; its autonomy paragraph; Step 2 inputs injected, not re-read; PRD path as escape hatch. Separate by design — never fold review into the builder.

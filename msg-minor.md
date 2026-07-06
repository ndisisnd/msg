---
name: msg-minor
status: open
source: Phase 21 (flash-modes-toggle) residuals — 2026-07-06
description: Three leftover items from the flash-mode work — a real test-drive, a tiny weight cleanup, and fixing the scorecard so it measures the right thing.
---

# msg-minor — three leftover items from the flash-mode work

We finished building "flash mode" (a fast, lighter way to run every msg tool). It works and it's committed. But three small things were left open. This doc explains each one in plain English first, then gives the technical detail needed to actually do it.

## The short version (plain English)

Think of msg as a factory assembly line that turns an idea into shipped software. We just added a **"fast lane"** to every station on that line — fewer workers, fewer meetings, fewer sign-off stops — for when you want a quick pass instead of the full, careful one.

Three things are still open:

1. **We never did a real test-drive of the fast lane.** We checked that every station *has* a fast lane and that all the switches point the right way — but we never actually sent a real job down the fast lane end-to-end to watch it come out the other side. Did it actually produce working software? If we hide a deliberate mistake in the work, does the fast lane's quality-check still catch it? Does the final safety gate still pass? We haven't watched that happen yet. This is the big one.

2. **The normal lane got very slightly heavier.** To add the fast lane, we had to write a one-line note on every station's main instruction board saying "a fast lane exists, here's how to switch to it." Those notes are read *every* time — even when you're using the normal lane and don't care about the fast one. So the normal lane picked up a tiny bit of extra weight (about half a percent — smaller than a rounding error). We'd promised the normal lane wouldn't get heavier *at all*, so we want to trim those notes back down to basically nothing.

3. **We were grading the fast lane on the wrong scorecard.** When we first planned this, we set each station a goal like "the fast lane should use X% less *reading material*." But it turns out the fast lane's real saving isn't in reading material — an earlier project already cut most of that. The fast lane's real saving is in **doing fewer steps**: hiring fewer workers, asking fewer questions, running fewer checkpoints. So several stations "failed" a goal that was never the right goal to begin with. We want to rewrite those goals to count the thing that actually matters — number of steps and helpers — so we're grading on the right scorecard.

None of these change how anything behaves for a user. They're cleanup and proof.

---

## The detail (for execution)

### Residual 1 — Live end-to-end verification of flash mode

**Plain English:** Actually run a real job through the fast lane, start to finish, and confirm the results are good.

**Why it's still open:** The benchmark we used (`evals/bench.py`) is a *calculator*, not a *runner* — it estimates how much "reading material" each mode loads, but it can't actually execute the tools. So it proved the wiring is correct but could never prove the *behavior*. That needs a real run, and a real run means several separate live sessions (each tool is its own session), which is a large operation we chose to defer.

**What "done" looks like (from the original plan, T4.1):**
- Run the fixture feature end-to-end **twice** — once normal, once flash — against `features/prd-101-task-crud/`.
- **Flash run must:** produce a build that passes its own unit tests; a review that catches a **deliberately planted blocker bug** (e.g. a hardcoded secret or a guaranteed crash in the generated code); and a clean final gate (build + security).
- **Normal run must:** come out functionally identical to the Phase 1 exit run (no accidental flash contamination).
- Record both token totals and any quality differences in `evals/token-baseline.md`; log any miss with a follow-up.

**How to run it:** `plan-em <prd> --flash → eng --build --flash → test --flash → review --flash → pre-merge --flash`, with the blocker seeded at build time. Each stage is a separate live LLM session; the flash review rubric (`review/refs/flash/mode-flash.md`) already covers correctness/security/perf, so the blocker is in-scope by design — but that must be *confirmed by running it*, not asserted.

**Effort:** large — multiple live autonomous sessions.

---

### Residual 2 — Return the normal (comprehensive) mode to zero added weight

**Plain English:** Trim the little "a fast lane exists" notes so the normal lane stops carrying any extra weight.

**Why it's still open:** Adding `--flash` and the Step 0 mode-resolution pointer to each always-loaded entry file (`review/SKILL.md`, `test/SKILL.md`, etc.) added ~793 tokens across the pipeline — **+0.45%** to the comprehensive footprint (measured: 177,663 → 178,456). It's below the tokenizer's own approximation error, but the Phase 21 exit gate said comprehensive must be **regression-free**, so strictly it isn't met.

**What "done" looks like:**
- Comprehensive `python3 evals/bench.py` back to **≤177,663** (or within a handful of tokens — genuinely noise).
- `--flash` remains discoverable and routable (the capability can't become invisible).
- Flash mode stays regression-free relative to its current numbers.

**Approach options (pick during execution):**
- Collapse each skill's flash mention + Step 0 pointer into a **single shared token** (e.g. one short line that references `shared/refs/mode-resolution.md` and nothing else), shaving the per-file prose to the bare minimum.
- Or move the routing sentence out of the always-loaded `SKILL.md` bodies into a spot that only loads when `--flash` is actually present, leaving comprehensive untouched.
- Re-run `bench.py` both modes after each trim; log the delta in `evals/token-baseline.md`.

**Effort:** small — mechanical, benchmark-gated.

---

### Residual 3 — Re-base the per-stage flash targets to the right metric

**Plain English:** Rewrite each station's fast-lane goal so it counts *fewer steps* instead of *less reading material* — because fewer steps is what the fast lane actually delivers.

**Why it's still open:** The plan's per-stage flash targets were written as "≤X% of the comprehensive **token** cost." But msg-v2 already banked the big token savings, so flash's real lever is **execution count** (subagents, buckets, gates, interview turns), not tokens. Measured on tokens, 5 of 8 stages "miss" their target (test 59%, pre-merge 59%, plan-tune 64–78%, review 50% vs ≤30–40% targets) — even though those same stages win big on execution count (test 5→0 subagents; review 3→1; pre-merge 5→2 buckets). The plan's own Part 3 reconciliation banner already flagged this; the targets just weren't rewritten.

**What "done" looks like:**
- In the phase-21 plan doc (now local-only under `improve/`, which has been retired from the installed skill surface — the folder persists on disk as scratch), replace the token-% targets for **review, test, pre-merge, plan-tune** (and any other execution-count-driven stage) with **execution-count targets**, and mirror the change in `evals/token-baseline.md`, e.g.:
  - review: ≤1 semantic subagent, 0 confirmation questions.
  - test: 0 subagents (in-process), 0 plan gate.
  - pre-merge: ≤2 buckets, 0 gate.
  - plan-tune: 0 gates, critical-severity checks only.
- Keep a token target **only** where tokens are genuinely the lever (plan-pm, plan-em, eng --build).
- Note in `evals/token-baseline.md` that the flash scorecard is now execution-count-based for those stages, so the earlier "misses" are re-classified as passes on the correct axis.

**Effort:** small — documentation only, no code.

---

## Suggested order

Cheap and contained first, the big live run last:

1. **Residual 3** (re-base targets — doc only).
2. **Residual 2** (trim the normal-mode weight — mechanical, benchmark-gated).
3. **Residual 1** (live end-to-end test-drive — large, multi-session).

Each is independent; each ends at a clean stopping point with a benchmark and a human gate before the next.

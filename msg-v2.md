# msg-v2 — Aggressive token cuts (breaking-allowed)

**Goal:** cut msg's *remaining* input-token footprint ≥50% on top of the msg-v1 Phase-1 win, via **input digestion** and **protocol slimming** — changes that **may alter pipeline shape or output profile** (unlike v1, which was strictly no-behavior-change). Every safety guarantee is still never relaxed (see Safety floor).

**Decision (2026-07-06):** model/effort **tiering is dropped** — the user prefers input digestion + protocol slimming. This plan is scoped to those two levers (plus an optional plan-tune collapse). Tiering can be revisited later; it composes cleanly with everything here.

> ✅ **DELIVERED (2026-07-06) — −53.3% measured.** B1 (session cache), B2 (PRD digest — the dominant lever, ~48pts), C1 (protocol slimming — marginal, ~2pts), B2-follow-up (plan-em synthesis slice, ~4pts), B4 (verify prelude — architectural). Pipeline input-footprint 380,704 → **177,663 tok** via `evals/bench.py`. **Deferred as marginal:** B3 devkit digest (no real `devkit/` in this repo), C2 tooling-detection trim, C1 template tightening, Phase D plan-tune collapse. Full log: `evals/token-baseline.md`.

**Measured baseline (`evals/bench.py`, post-Phase-1):** **303,085 tok / PRD run**; static skill surface 123,309 tok. Composition:
- **PRD re-reads ≈ 173k (≈57%)** — the PRD is loaded ~8.4× across the pipeline. → the dominant lever (Phase B digest).
- **Protocol/ref loading ≈ 106k (≈35%)** → Phase C slimming.
- devkit re-reads + injected cook payloads ≈ 24k.

**Every task below is benchmark-gated:** re-run `evals/bench.py` after each and record the delta in `evals/token-baseline.md`. The harness tokenizes live files against a fixed load manifest, so slimming a ref or repointing a stage at a digest produces a real, comparable number.

**Sequencing rule:** B (digestion) first — it owns 57% of the footprint and is foundational (digests unblock further slimming and the verify prelude). C (slimming) second. D (collapse plan-tune) last and optional — most pipeline-breaking, benefits from B's digests. Each phase is a clean stopping point.

**Safety floor (never relaxed, any phase):** DB/data/prod-config pauses, breaking-change pauses, branch isolation (`feat/prd-<n>-*`), never push/merge, secret scan, frontmatter stamps, F-ID stability, PRD §9 ledger, test-fail ticket, pre-merge refusals.

---

## Phase 0 — Benchmark harness  ✅ DONE

`evals/bench.py` measures the input-token footprint of one comprehensive PRD run via a path-based load manifest (per stage: files loaded on the hot path + PRD/devkit re-read multipliers + subagent fan-out), tokenizing the live files. Baseline recorded in `evals/token-baseline.md`. Re-run after every task to prove the delta. When Phase B adds a digest, its manifest entry is repointed from the prose file to the digest so the measured drop reflects the new read path.

---

## Phase B — Input digestion (caching + digests)

**Precedent:** `review/refs/cache.md` and test's `test.json` already cache; extend that pattern, don't invent a new one.

### B1 — Session cache convention
**What:** `shared/refs/session-cache.md` — a content-hash-keyed cache under `.claude/msg/cache/` (gitignored): each artifact records the source paths + their hash; a consumer regenerates only on hash mismatch. Prose/source is always canonical; the cache is derived and disposable.
**Blast radius:** new spec + `.gitignore` entry.
**Acceptance:** spec defines key = hash(source paths); staleness = hash mismatch → regenerate; cache miss/corrupt → fall back to reading source (never a hard failure).

### B2 — PRD digest
**What:** a deterministic generator script (`scan-prd-digest.py`) that splits the PRD on its standardized headings (`## N.` product sections, `## Execution Table`, `## Engineering — <agent>`, `### N.` eng subsections) and emits a compact JSON the downstream stages consume instead of re-parsing full prose. Contractual fields are copied **verbatim**; narrative prose (Alternatives-considered, Design-decision rationale, DX, Risks prose, audit logs, flow walkthroughs) is dropped; every entry keeps a `prose_lines` pointer for on-demand prose access. Generation is **lazy + cached** (hash-keyed under `.claude/msg/cache/`, B1) — the first consumer that finds it missing/stale regenerates it; no new mandatory stage.

**Digest shape:** `{ prd, source_hash, frontmatter (stamps: product-tuned/eng-tuned/reviewed, depends_on, affects, platform), features[{id, title, acceptance[verbatim], prose_lines}], out_of_scope[], error_cases[], glossary{}, exec_table[{feature, platform, files, steps}], integration_contracts{<agent>[verbatim]}, migration_breaking{<agent>}, open_questions[], audits_present[] }`.

**Per-stage consumption (each reads only its slice):** plan-tune --product → features + out_of_scope + glossary + error_cases + stamps; plan-em → features + exec_table + platform; plan-tune --eng → integration_contracts + migration_breaking + open_questions + features; eng --build → this feature's acceptance + its exec_table rows + integration_contracts; review eval-bootstrap → features.acceptance + error_cases; test → exec_table + acceptance.

**Files:** new `scan-prd-digest.py`; read-path edits in `plan-tune/refs/tune-*.md`, `plan-em/refs/protocol-em.md`, `eng/refs/build/protocol.md`, `review/SKILL.md`, `test/SKILL.md`; `bench.py` manifest repointed PRD reads → digest to measure the delta.
**Blast radius:** every planning/verify stage's PRD read path.
**Risk/mitigation:** (a) digest drifts from prose → `source_hash` = hash of the PRD file; every consumer regenerates on mismatch; prose stays canonical. (b) non-standard PRD headings → generator flags unparsed sections and the stage falls back to prose for those (graceful degradation, never a hard failure).

**Acceptance criteria:**
1. `scan-prd-digest.py` parses the fixture PRD into the digest shape above with **zero LLM calls**; F-IDs, acceptance criteria, integration contracts, and glossary terms are byte-for-byte verbatim from the prose.
2. Narrative-only sections (Alternatives, Design-decision rationale, DX, Risks prose, audit logs, flow walkthroughs) are **absent** from the digest; every retained section carries a `prose_lines` pointer resolving to the correct line range.
3. `source_hash` equals the hash of the PRD file; editing the PRD and re-consuming **regenerates** the digest (mismatch → rebuild); an unchanged PRD is a **cache hit** (no regeneration).
4. Each of the 6 consumer stages reads only its declared slice, not full prose, on the happy path; the `prose_lines` escape hatch is documented per stage for insufficient-digest cases.
5. A PRD with a non-standard/missing heading yields a digest that **flags** the unparsed section; the affected stage falls back to prose for it without error.
6. On the fixture, each consumer stage produces artifacts **identical** to the full-prose read path (PRD unchanged in meaning).
7. `bench.py` re-run (manifest repointed) shows the PRD-read contribution drop from ~173k toward the ≤60k target; delta logged in `evals/token-baseline.md`.

### B3 — devkit digest
**What:** a generator emitting condensed, agent-relevant constraints from AHA/GLOSSARY/ARCHITECTURE/DESIGN-SYSTEM/OPEN-QUESTIONS (the "digest" v1 already references informally — make it a real cached artifact). Consumers: plan-em preflight, eng, review fingerprint.
**Files:** new generator; read-path edits in plan-em, eng, review.
**Risk/mitigation:** same drift risk → hash-keyed on the five devkit files.
**Acceptance:** digest ≤ a fixed budget; regenerates on any devkit edit; preflight/fingerprint read it; full-file escape hatch stated.

### B4 — Shared verify prelude
**What:** resolve-diff + tooling-detect + eval-set bootstrap run **once** and are cached (B1), then consumed by review, test, and pre-merge instead of each redoing them.
**Files:** `review/SKILL.md` Step 2, `test/SKILL.md`, `pre-merge/SKILL.md`, `resolve-diff.sh` (shared).
**Blast radius:** the three verify skills' setup steps; ship must generate the prelude before fanning out.
**Risk/mitigation:** stale prelude on a changed diff → hash on HEAD + diff range (reuse T1.11's freshness check). Standalone runs still self-setup (fallback).
**Acceptance:** on an orchestrated verify, diff/tooling/eval-set computed once; each skill records "prelude consumed"; standalone invocation unchanged.

---

## Phase C — Protocol slimming (aggressive, behavior-preserving)

### C1 — Split & compress fat protocols
**What:** cut the largest refs via six grounded techniques. Targets: `eng/refs/build/protocol.md` (4,009w), `protocol-em.md` (3,658w), `protocol-roadmap.md` (2,609w), `protocol-gui.md` (2,217w), `template-eng-plan.md` (1,908w), `tune-product.md` (1,680w), `template-todo.md` (1,661w).

**Two metrics moved:** *static surface* (123k tok, all refs) and *per-run hot-path load* (the ~106k ref slice of the 303k footprint). Hot/cold splitting cuts mainly the hot-path load; the other five cut both.

**Techniques → target:**
1. **Hot/cold split (lazy cold branches):** move `protocol.md`'s `test-json` fix-from-tickets sub-protocol (~lines 108–159) and Debug mode to `protocol-build-testjson.md` + a debug ref, loaded only when that source/condition is active. A plain `--build` stops loading them.
2. **De-dup canonical defs:** replace `protocol.md`'s embedded AHA.md / OPEN-QUESTIONS.md entry-format blocks (~lines 188–232) with pointers to the devkit templates.
3. **Extract sibling boilerplate:** hoist branch-contract / commit-gate / scope-enforcement / output-contract shared across `protocol.md`, `protocol-roadmap.md`, `protocol-exec.md` into `eng/refs/build/_common.md`; each references it.
4. **Trim examples to skeletons:** collapse fake-data example tables (`F2: Track streak…`, `unit-002…`) to header + one skeleton row.
5. **Prose walls → tables/checklists:** convert `protocol-em.md` (3,658w, only 4 table rows) procedural prose to numbered checklists/tables.
6. **Tighten dense checklists/templates:** compress per-row descriptions and hoist repeated severity/format preamble in `tune-product.md` (65 rows), `template-eng-plan.md` (37), `template-todo.md` (22).

**Blast radius:** the hottest ref files. Behavior-preserving (same instructions, denser / lazily loaded).
**Risk/mitigation:** an instruction lost in compression → per-file before/after diff + a **grep matrix** confirming every scope / branch / safety / stamp / integration-contract instruction still present; spot-run each mode/path.

**Acceptance criteria:**
1. `protocol.md`'s `test-json` and Debug paths live in lazily-loaded refs; a plain `--build` run's manifest no longer loads them (bench.py hot-path drop reflects it).
2. No embedded AHA/OPEN-QUESTIONS format block remains in `protocol.md`; both are pointers to the devkit templates.
3. `eng/refs/build/_common.md` exists; `protocol.md`/`protocol-roadmap.md`/`protocol-exec.md` reference it and no longer each repeat the branch/commit/scope/output boilerplate.
4. `protocol-em.md` procedural prose is table/checklist form; no instruction dropped (grep matrix).
5. Fat-ref set (~17.7k w) → ≤11k w; refs total → ≤40k words; **every** scope/branch/safety/stamp/contract instruction grep-verified present after.
6. Each affected mode/path still functions on a spot-run; `bench.py` per-run footprint drop logged in `evals/token-baseline.md`.

### C2 — Retire superseded maintainer docs
**What:** `shared/refs/tooling-detection.md` (2,112w) is now maintainer-only (v1 T1.8). Trim to a short "the script is authoritative; here's the field map" doc, or delete if the script's `--help`/comments fully cover it.
**Acceptance:** file ≤ 400w or deleted; nothing runtime references it.

---

## Phase D — Collapse plan-tune into inline self-audits (most breaking)

### D1 — Product self-audit inside plan-pm
**What:** plan-pm runs the **critical-severity** product-tune checks (placeholder/vague ACs, feature↔out-of-scope contradiction, conflicting ACs, timezone basis, glossary conflicts) as a final self-audit step before emitting — instead of a separate `plan-tune --product` stage re-reading the whole PRD.
**Files:** `plan-pm/SKILL.md` + a slim `plan-pm/refs/self-audit.md` (reuses `plan-tune/refs/tune-product.md` critical checks).
**Blast radius:** removes a default pipeline stage; `plan`/`ship` orchestration and README/ARCHITECTURE pipeline diagrams change.

### D2 — Eng self-audit inside plan-em
**What:** plan-em runs the **critical-severity** eng-tune checks (feature coverage, integration contracts, migration paths, open questions) as a final step before synthesis emit.
**Files:** `plan-em/refs/protocol-em.md` + reuse of `plan-tune/refs/tune-eng.md` critical checks.

### D3 — Preserve standalone plan-tune + reconcile docs
**What:** `plan-tune` stays fully invokable manually (full multi-severity audit); only the *default auto-run* between stages is removed. Update `plan` orchestrator, `ship`, README, ARCHITECTURE pipeline lines, and any end-of-run "next: plan-tune" gate to reflect the inline self-audit.
**Risk/mitigation:** losing the independent adversarial gate reduces catch-rate on non-critical issues. Mitigation: inline audit covers **critical** severities (the ones that block a ship); the full standalone tune remains one command away; `plan` may still offer an optional full tune.
**Acceptance:** default planning flow runs zero separate tune stages; critical checks still execute inline and still write §9-ledger findings + frontmatter stamps; `plan-tune <path>` standalone unchanged; pipeline docs updated.

---

## Phase E — Verification benchmark

**What:** run the fixture end-to-end post-v2 and record in `evals/token-baseline.md`: total vs post-Phase-1 baseline, per-phase contribution, and any quality deltas from tiering/digests/collapse.
**Acceptance:** total ≤ ~50% of post-Phase-1 comprehensive; fixture still produces a correct PRD, exec table, green build, seeded-blocker catch, clean pre-merge; any regression logged with a follow-up.

---

## Out of scope for v2
- **Model/effort tiering** — dropped per the 2026-07-06 decision; revisit later.
- cook-internal changes (separate repo): budget cap, `_INDEX` archives, `cook --flash`.
- The Phase-2/3 per-skill **flash modes + toggle** from msg-v1 (orthogonal; flash can layer on later and inherits digests/slimming for free).
- Any relaxation of the safety floor, in any mode, ever.

## Open decision to confirm before Phase D
- **Phase D aggressiveness** — remove the auto-run tune entirely (full collapse into plan-pm/plan-em, as written), OR keep plan-tune as a stage but make it digest-based + critical-only (keeps the independent adversarial gate), OR defer D until A+B+C savings are measured. Not needed to start B/C.

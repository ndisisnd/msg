---
name: smoke
description: Component 17 (platform group, blocking, depends_on preview) — the preview's health precondition (C21). Runs BEFORE the expensive preview checks and short-circuits on failure ("preview unhealthy"); a fired preview always gets at least a DEFAULT liveness check (never a silent skip), then runs the critical-tagged e2e-flow subset (1–3 golden paths incl. the core action, D29). Feeds C20/R2 evidence and gates the R1 approval prompt. Genuinely un-smokeable surface degrades LOUDLY. Also the shared surface post-merge --staging smoke-verifies a deploy through.
---

# Component 17 — SMOKE (the preview's health precondition)

`smoke` is the fast, cheap check that answers **"is this preview actually alive and
does its core action work?"** before anyone — human or the expensive machine checks —
spends time on it. It `depends_on: preview` (the catalog's 2nd hard edge) and runs
**first among the preview-tail checks and short-circuits** the rest on failure, so a
dead or broken preview never reaches the human approval prompt (C20/R1) and never has
the api-drift / migration up→down→up / capture suite run against it. It is `blocking`,
`platforms: all‡` (forks per platform — url / artifact / sim).

Guard, error rule, envelope: `../_common.md`. Runner (`smoke_runner`) from the Step 1
fingerprint. The same check is the shared surface post-merge `--staging` runs to
smoke-verify a deploy (`post-merge/refs/verify-deploy.md`) — one liveness+critical-path
contract, two callers.

## 1 · The no-vacuous-skip default-liveness floor (AC-SMK1)

**A fired preview always gets at least a default liveness check — never a silent skip.**
`verify-deploy` used to degrade an unconfigured smoke to *skipped-with-note*; after C20
that would let `preview`'s R1 health precondition pass **vacuously** — no `smoke_cmd` ⇒
skip ⇒ green ⇒ a human approves a possibly-dead preview. So:

- **`preview` fired + no `smoke_cmd` configured** → run a **default liveness check** so R1
  always has real signal:
  - `preview_kind: url` → HTTP **200** (not 3xx-to-error, not 5xx) on the preview URL,
    with a bounded retry/backoff for cold-start.
  - `preview_kind: artifact` (iOS / Android / macOS) → the build **launches without
    crashing** to first interactive screen (simulator/emulator boot + no immediate crash).
  - `preview_kind: screenshots` → the capture run itself completed without a crash/blank.
- This is the **same safety-floor pattern as C9** (security's guaranteed secret-scan
  floor) and the D28 present-but-hollow family: the check that *runs* must actually check
  something — the precondition **can never pass vacuously** (`safety-floor.md`).

The default liveness floor is not a substitute for the critical-path smoke (§2) — it is
the **minimum** signal a fired preview must produce; a configured `smoke_runner` runs the
richer critical-path subset on top.

## 2 · Critical-path smoke — the golden-path e2e subset (AC-SMK3)

Liveness alone is too weak: an app can serve its homepage 200 while the **core action is
broken**. So smoke runs the **critical-tagged subset of the e2e-flow definitions** — the
1–3 **golden paths** (e.g. login + the core action), fast.

- **`e2e` owns the flows (D29).** smoke **consumes** the canonical flow set + its
  critical tags from `protocol-e2e.md`; it does **not** invent its own list (the same
  shared dependency `a11y`/`perf`/`preview` consume). It runs only the `critical`-tagged
  subset — not the full suite (that is `e2e`'s own component) and not just a homepage ping.
- **Backend-only / no `e2e` (D29 degrade).** With no UI flow set, smoke falls back to its
  **non-flow path** — the default-liveness floor (§1) against the endpoint/health target —
  rather than fabricating a flow. This is a graceful degrade, not a skip.

## 3 · Runs first + short-circuits the expensive preview checks (AC-SMK4)

Because smoke is cheap and **gates** the expensive human gate, the executor runs it
**before** the pre-approval preview suite and **short-circuits** on failure:

- **smoke green** → the executor proceeds to `preview`'s §2 captures + §3 live-env checks
  (api spec-drift, migration up→down→up) and the R2 assembly.
- **smoke fail / preview unhealthy** → **stop**: do **not** stand up captures, do **not**
  run api-drift / migration up→down→up against a dead preview, do **not** prompt. Report
  `preview-unhealthy` immediately. This mirrors the executor's fail-fast — a `blocking`
  smoke failure blocks its downstream dependent (`preview`).

The smoke result — pass or the short-circuit failure — becomes **R2 evidence** in the
unified approval artifact (`protocol-preview.md` §4): the human sees the health pass and
the critical-path golden-path outcomes before approving.

## 4 · A smoke failure blocks the R1 approval prompt (AC-SMK5)

The human approval prompt in `preview` **does not fire until smoke passes green** (C20/R1).
Since `smoke depends_on preview` and runs before the expensive checks (§3), the executor
already holds smoke's result when the gate reaches R1:

- **smoke green** → R1 precondition met → proceed to serve the gate.
- **smoke fail** → R1 precondition **unmet** → the gate terminates `preview-unhealthy`;
  **no approval is requested on an unhealthy preview.** The §1 default-liveness floor
  guarantees this precondition can never be satisfied vacuously.

## 5 · Genuinely un-smokeable surface degrades LOUDLY (AC-SMK2)

A surface with **no smokeable target at all** (no URL, no launchable artifact, no health
endpoint — nothing the floor can even probe) does **not** silently go green. It degrades
**loudly**:

- Emit a `high` finding (`rule: smoke-unsmokeable` / `safety-floor.md` present-but-hollow)
  naming *why* nothing could be probed, and **surface it in the R2 approval evidence** so
  the human sees the health gap before approving — the opposite of a silent pass.
- Frame the finding user-first (`../../../shared/refs/name-the-user-impact.md`): what the
  human is being asked to approve **without** health signal, in which surface — never a
  bare "no smoke target."

The only path to a green R1 is a **real** liveness/critical-path result; "un-smokeable"
is a visible degrade, not an absence of a gate.

## Parse + result report

- **Liveness/critical-path pass** → `pass`.
- **Liveness or a critical golden path fails** → `fail` (`preview-unhealthy`); short-circuit
  §3; feed the finding to R2. Each failing golden path is one finding, `severity: high`
  (matches the e2e severity floor), `rule` = the flow's title/critical tag, `repro` = the
  single-flow re-run.
- **Un-smokeable surface** → `high` `smoke-unsmokeable`, surfaced in R2 (never silent green).
- **preview did not fire** → the component is not present (`active_when: preview-fired`);
  no smoke, no skip note.

Component fields: `runner`, `command`, `preview_kind`, `liveness` (`floor` | `configured`),
`critical_flows_run[]`, `errors[]`, `totals` `{ passed, failed }`.

## References

- `platform/protocol-preview.md` — C20/R1 precondition (this check gates its prompt) + R2
  evidence (this check feeds it); the executor short-circuits preview's §3 on smoke fail
- `platform/protocol-e2e.md` — the canonical flow definitions + critical tags smoke
  consumes (D29 — `e2e` owns them; smoke runs only the `critical` subset)
- `refs/executor.md` — sequences smoke **before** the expensive preview checks and applies
  the `blocking` short-circuit onto its `preview` dependent
- `../../../shared/refs/safety-floor.md` — the present-but-hollow floor pattern (C9/C21/D28)
- `../../../shared/refs/name-the-user-impact.md` — the finding-framing for a health gap
- `post-merge/refs/verify-deploy.md` — the shared smoke surface post-merge `--staging` runs
  to smoke-verify a deploy (same liveness + critical-path contract)
- `../_common.md` — guard / error rule / output envelope

---
name: smoke
description: Component 17 (platform group, blocking, env wave) — the build's liveness + golden-path check (C21). Runs FIRST inside the C23 sandbox and short-circuits the expensive env-wave checks on failure; an app that fired always gets at least a DEFAULT liveness check (never a silent skip), then runs the project's configured smoke command (1–3 golden paths incl. the core action). Genuinely un-smokeable surface degrades LOUDLY. Also the shared surface post-merge --staging smoke-verifies a deploy through.
---

# Component 17 — SMOKE (the build's liveness + golden-path check)

`smoke` is the fast, cheap check that answers **"is this build actually alive and
does its core action work?"** before the expensive machine checks spend time on it.
It has **no hard edge** — it is an ordinary env-wave component (`needs_env: true`) that
runs against the C23 sandbox the executor stood up, scheduled **first within that wave**
so a dead app short-circuits the rest. It is `blocking`, `platforms: all‡` (forks per
platform — url / artifact / sim), `active_when` the diff touches a UI **or**
api/migration/deploy surface.

Guard, error rule, envelope: `../_common.md`. Runner (`smoke_runner`) from the component's
resolved tooling. The same check is the shared surface post-merge `--staging` runs to
smoke-verify a deploy (`post-merge/refs/verify-deploy.md`) — one liveness+critical-path
contract, two callers.

## 1 · The no-vacuous-skip default-liveness floor

**A smoke that runs always produces real signal — never a silent skip.** `verify-deploy`
used to degrade an unconfigured smoke to *skipped-with-note*, which let a `blocking`
component pass **vacuously** — no `smoke_cmd` ⇒ skip ⇒ green ⇒ a possibly-dead build
sails through. So:

- **No `smoke_cmd` configured** → run a **default liveness check**, shaped by the
  platform row in `devkit/PLATFORMS.md`:
  - **web / backend** → HTTP **200** (not 3xx-to-error, not 5xx) on the sandbox app's
    URL or health endpoint, with a bounded retry/backoff for cold-start.
  - **iOS / Android / macOS** → the build **launches without crashing** to first
    interactive screen (simulator/emulator boot + no immediate crash).
- This is the **same safety-floor pattern as** security's guaranteed secret-scan
  floor and the D28 present-but-hollow family: the check that *runs* must actually check
  something — it **can never pass vacuously** (`safety-floor.md`).

The default liveness floor is not a substitute for the critical-path smoke (§2) — it is
the **minimum** signal the component must produce; a configured `smoke_runner` runs the
richer critical-path subset on top.

## 2 · Critical-path smoke — the configured golden paths

Liveness alone is too weak: an app can serve its homepage 200 while the **core action is
broken**. So when the project configured a `smoke_runner`, smoke runs **that command** —
the project's own 1–3 golden paths (login + the core action), fast. That configured
command *is* the critical-path definition; smoke keeps no flow list of its own and does
not reach into another component's suite for one.

- **`smoke_runner` configured** → run it. Each failing golden path is one finding.
- **No `smoke_runner`** (backend-only, or simply unconfigured) → the **default-liveness
  floor** (§1) is the whole check: an HTTP 200 or a clean launch. A graceful degrade,
  never a skip — and never a fabricated flow.

## 3 · Runs first + short-circuits the expensive env-wave checks

Because smoke is cheap and every other env-wave component is expensive, the executor
runs it **first inside the sandbox** and **short-circuits** on failure:

- **smoke green** → the env wave proceeds normally (`e2e`, `a11y`, `perf`, `load`,
  `mobile`, `api`'s live-conformance half, `migration`'s up→down→up round-trip).
- **smoke fail** → **stop the wave**: do **not** run api-drift or migration
  up→down→up against a dead app. This is the executor's ordinary fail-fast — a
  `blocking` failure fails the verdict and blocks the wave (`refs/executor.md` §2/§3).

## 4 · Genuinely un-smokeable surface degrades LOUDLY

A surface with **no smokeable target at all** (no URL, no launchable artifact, no health
endpoint — nothing the floor can even probe) does **not** silently go green. It degrades
**loudly**:

- Emit a `high` finding (`rule: smoke-unsmokeable` / `safety-floor.md` present-but-hollow)
  naming *why* nothing could be probed — the opposite of a silent pass.
- Frame the finding user-first (`../../../shared/refs/name-the-user-impact.md`): what is
  shipping **without** health signal, in which surface — never a bare "no smoke target."

The only path to a green smoke is a **real** liveness/critical-path result;
"un-smokeable" is a visible degrade, not an absence of a check.

## Parse + result report

- **Liveness/critical-path pass** → `pass`.
- **Liveness or a critical golden path fails** → `fail`; short-circuit the env wave (§3).
  Each failing golden path is one finding, `severity: high` (matches the e2e severity
  floor), `rule` = the flow's title/critical tag, `repro` = the single-flow re-run.
- **Un-smokeable surface** → `high` `smoke-unsmokeable` (never silent green).
- **No UI/api/migration/deploy surface in the diff** → the component is not present
  (`active_when` union unmet); no smoke, no skip note.

Component fields: `runner`, `command`, `liveness` (`floor` | `configured`),
`critical_flows_run[]`, `errors[]`, `totals` `{ passed, failed }`.

## References

- `refs/executor.md` — schedules smoke first inside the env wave (§2/§3b) and applies the
  ordinary `blocking` fail-fast to the rest of the wave
- `../../../shared/refs/safety-floor.md` — the present-but-hollow floor pattern (C9/C21/D28)
- `../../../shared/refs/name-the-user-impact.md` — the finding-framing for a health gap
- `post-merge/refs/verify-deploy.md` — the shared smoke surface post-merge `--staging` runs
  to smoke-verify a deploy (same liveness + critical-path contract)
- `../_common.md` — guard / error rule / output envelope

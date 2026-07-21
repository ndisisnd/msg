---
name: preview
description: The single human-review gate (component 16, kind gate, blocking) — the merged qa+preview component (C20). Captures the feature's visual states in the promoted C23 test-sandbox (the same ephemeral isolated env the needs_env wave ran in — this gate provisions nothing itself, AC-SBX5), runs the pre-approval live-env checks (api spec-drift, migration up→down→up), then serves ONE unified approval artifact (evidence + the C22 manual-test-plan checklist) for a single Approve/Reject. R1 smoke-precondition · R2 informed approval · R3 commit-bound · R4 structured reject. Async park/notify/resume, ephemeral + isolated. active_when = union of UI-surface OR api/migration/deploy surface.
---

# Component 16 — PREVIEW (the single human-review gate)

The **one human gate** in pre-merge. When the diff touches material UI **or** backend
surface, a human must **see, poke at, and approve** a preview — with the machine
evidence in hand — before the PR opens. `kind: gate`, `blocking`; never removed in any
profile; in `strict` it **always** fires. This component is the **merged `qa` +
`preview`** (C20/D26): `qa` (visual capture) and `preview` (live env) performed the same
act — stand up the feature → serve it to a human → block on sign-off — so they collapse
into **one** component, one unified approval artifact, one Approve/Reject. The former
`qa` id `15` is **retired, not reused** (`shared/refs/component-catalog.md`).

Guard, error rule, envelope: `../_common.md`.

## Trigger — `active_when` = the union (C20)

Fires when the diff touches **either** surface (the union of the old qa + preview
triggers, per the catalog's union `active_when`):

- **UI-surface** — `.tsx`/`.jsx`/`.vue`/`.svelte`; any path under `/components/`,
  `/pages/`, `/views/`, `/screens/`; `.css`/`.scss`; Flutter `.dart` with a `Widget`
  build method.
- **API / schema / migration / deploy surface** — paths under `/routes/`,
  `/controllers/`, `/handlers/`, `/api/`, `/server/`, `/services/`; `*.proto` / OpenAPI
  specs; any migration path (the `migration` trigger set); ORM schema/model files;
  deploy/infra manifests.

`strict` → fires regardless (always). `lenient` → fire only on UI-surface (visual)
paths. No trigger match (and not strict) → **skip** and record it
(`preview: { fired: false }`). The executor only runs `preview` when this union gate is
met — an absent surface means no gate.

## The gate runs in the promoted C23 sandbox (AC-SBX5)

Everything below runs against the **promoted test-sandbox** — the same ephemeral,
isolated environment the executor provisioned for the `needs_env` wave
(`refs/executor.md` §3b), promoted to serve as this preview. **This gate never
provisions an environment of its own — no second env, ever.** The mechanism is the
manifest's `env_provision` resolution (`shared/refs/policy-schema.md` — provision /
seed / reset / teardown; recorded at `--init`), which **supersedes** the old
preview-scoped `preview_env` field. The promoted sandbox is a **fresh provision**
(S-Q2): a run that arrived via warm fix-loop resets is re-provisioned before
promotion, so the artifact the human approves is provably hermetic.

**No provisioner declared (`env_provision` absent / `provisioner: "none"`) ⇒ the gate
degrades loudly** (a `high` `sandbox-unprovisioned` finding surfaced in the evidence,
and the destructive pre-approval checks are skipped-with-note) — it never runs
up→down→up against shared state. The env is **torn down after the decision**
(approve or reject), always.

> **Lineage (F3 → C23):** the F3 spike stood this env up preview-scoped; **v3.1 / C23**
> generalized it into the shared test-sandbox for the whole `needs_env` wave. This gate
> is now a **consumer** of that sandbox, not a provisioner.

## 1 · R1 precondition — never prompt on a broken preview

The human approval prompt **does not fire until `smoke` passes green** (AC-PRV3). Because
`smoke depends_on preview` and runs **before** the expensive preview checks
(`platform/protocol-smoke.md`, C21), the executor already has smoke's result when the
gate reaches this point:

- **`smoke` green** → proceed to §2.
- **`smoke` fail / preview unhealthy** → **do not** stand up captures, **do not** run the
  api-drift / migration up→down→up suite against a dead preview, **do not** prompt.
  Terminate this component with a `preview-unhealthy` result — the human is never asked to
  approve a 502. Smoke's `no smoke_cmd → default liveness` floor (C21/AC-SMK1) guarantees
  this precondition can never pass **vacuously**.

## 2 · Produce the preview_kind + capture the visual states (merged qa)

For each platform in the `preview_map`, produce its `preview_kind` (D10):

| `preview_kind` | What pre-merge produces | Presented to the human |
|---|---|---|
| `url` (web) | run `preview_deploy_cmd` in the ephemeral env → a deployed link | the URL to open + poke |
| `artifact` (iOS/Android/macOS) | run `preview_deploy_cmd` → an installable build (TestFlight / simulator / `.apk` / `.app`) | the build location + **what-to-poke-at notes** (the flows this diff changed) |
| `screenshots` (explicit opt-down) | drive the changed flows and capture **before/after** | the before/after captures |

A multi-platform run produces one preview per platform.

**Visual capture (folded from qa).** Drive the changed flows and capture their real
states. The flow set is **owned by `e2e`** (D29 — `e2e` defines the canonical flows +
critical tags; this gate **consumes** them, it does not reinvent a list):

- **e2e-flow-driven real states** — capture the states the flows actually reach (dialog
  open, validation error shown, list populated), not just a static homepage.
- **Render variants** — light/dark, key breakpoints, RTL where declared.
- **Noise-masking** — mask timestamps, avatars, animation frames so churn isn't a diff.
- **Unexpected-diff prioritization** — surface the visual diffs the diff didn't obviously
  cause first (the regression signal), routine expected diffs after.

Runner (`qa_runner`: Playwright visual / Chromatic / Percy / BackstopJS / Loki) from the
fingerprint. **Baseline check:** no local baseline and not Chromatic/Percy →
`pass_with_warnings`, note `"No visual baselines found — run once in update mode."`
Visual diffs become evidence for the human (each diff: `rule` = story/snapshot name,
`evidence.file` = diff-image path), **not** an automatic pixel-threshold pass/fail — the
human decides.

## 3 · Pre-approval live-env checks (the parked sweep — feed R2)

Against the same ephemeral env, **before** the human sees it, run the two live-env checks
parked from their components onto this preview (AC-PRV8) — safe because the env is
disposable:

- **`api` #3 — spec-vs-implementation drift.** schemathesis / Dredd vs the **live**
  preview endpoint: does the running service actually match its OpenAPI spec? (The
  base-vs-PR spec-diff still runs in the `api` component; this is the live-conformance
  half that needs a running server.)
- **`migration` #3 — apply up→down→up.** Run the migration **up → down → up** against the
  **preview DB** and assert a clean round-trip (reversible, no drift). Destructive by
  nature — safe **only** because the env is ephemeral + isolated.

Both results become R2 evidence. A failure here is a `high` finding in the evidence
bundle (the human sees it before approving); it does not silently pass.

## 4 · R2 — assemble the unified approval artifact (informed approval)

Write **one** approval artifact — `.pre-merge/<ts>/preview-approval.json` — carrying the
preview handle **and all the machine evidence**, so the human decides with the results in
hand, never blind (AC-PRV4). It bundles:

- The preview handle(s) — URL / artifact location / before-after captures, per platform.
- **`smoke`** result (the R1 health pass + the critical-path golden-path outcomes — C21).
- **`api` spec-drift** (base-vs-PR breaking-change diff **and** the §3 live-conformance
  result), **consumer-named** (`shared/refs/name-the-user-impact.md`).
- **`migration`** up/down round-trip result (§3) + the static-scan lock findings.
- **`a11y`** findings (interactive-state, user-impact-framed — `protocol-a11y.md`).
- **Visual-diff summary** (§2 — unexpected diffs first).
- **The C22 manual-test-plan checklist (AC-MTP6).** Render the **significance-rated**
  human-test checklist from the machine artifact `.pre-merge/<ts>/manual-test-plan.json`
  (generated once by the `manual-test-plan` component, `prd/protocol-manual-test-plan.md`)
  — grouped 🔴 HIGH → 🟡 MEDIUM → 🟢 LOW, **HIGH first**, so the human walks exactly what
  automation could **not** verify before approving. This is a **render**, not a
  re-derivation — the same generate-once artifact post-merge `--staging` also renders. No
  `--prd` (hotfix) ⇒ no checklist; the rest of the evidence still renders.

The artifact also carries the **R3 state token** (§6).

## 5 · Serve the gate — Approve / Reject (async park; F3 spike §A)

This harness has **no persistent process** to await a human, so the gate **parks and
ends the run** rather than blocking:

1. **Park.** With R1 green (§1) and the R2 bundle assembled (§4), **write the approval
   artifact** and **print the resume instruction**, then **STOP** — verdict `parked`
   (a non-terminal "awaiting-human" state; **not** `pass`, **not** a PR-open). No process
   lingers; the env stays up only until the decision returns, then is torn down (§B).
2. **Notify.** The parked run's terminal output *is* the notification: the preview
   URL/artifact, the rendered evidence + HIGH-first checklist, and the **two resume
   paths** — `/pre-merge --resume <token>` **or** the `/msg --gui` approval card (which
   records the same decision + token and serves the same unified artifact).
3. **Resume.** The human re-invokes with their decision:
   - **Approve** → §7 (open the PR). Record `preview: { fired: true, approved: true,
     kind, artifact, token }`.
   - **Reject** → §R4 (structured finding → fix-loop).

## 6 · R3 — commit-bound approval (no stale approvals)

**State token = `sha256(commit_sha : capture_hash : run_id)`** (AC-PRV5, F3 spike §A):
`commit_sha` = reviewed branch HEAD; `capture_hash` = hash over the visual captures +
evidence bundle; `run_id` = the parking run's id. On **resume** the token is
**recomputed against the current branch HEAD**:

- **Match** → the decision applies (approval is bound to exactly the reviewed
  commit + captures).
- **Mismatch** (a new commit landed, or captures changed) → the approval is
  **invalidated** and the gate **re-fires** (re-park with a fresh token) — closing the
  "approved at commit A, PR opens at commit C" hole.
- **Expiry ≠ auto-pass** (AC-PRV7). The parked artifact carries a TTL; a stale/expired
  token on resume is **rejected the same as a mismatch** — it never silently becomes an
  approval. Re-run the gate. Expiry only ever forces re-review.

## R4 · Structured rejection → the universal report (AC-PRV6)

A **Reject** is not a freetext dead-end — it emits a **canonical finding**
(`shared/refs/finding-schema.md`) into the universal report (C7) so a visual/UX rejection
feeds `eng --build report=<path>` like any failing test:

```json
{ "source": "pre-merge:preview", "severity": "high", "category": "qa",
  "rule": "preview-rejected:<flow-or-capture-id>",
  "message": "<what the human found wrong, in which flow/state>",
  "file": "<the changed source/spec for that flow, or null>", "line": null,
  "evidence": { "file": "<capture/diff-image path or preview URL>" },
  "suggestion": "<the human's stated reason / what to fix, or null>",
  "repro": "<the flow to re-poke, or null>" }
```

The verdict becomes `fail` (the PR does not open); the finding flows through the normal
issues-file loop → `fix-loop.md`, so the human's rejection is actionable, not a note. If
the human gives no specifics, record the reject with the flow/capture context the gate
already has — never fabricate a reason.

## Result report + verdict

`preview` writes its per-check result report (`shared/refs/check-report-schema.md`)
on every path: `parked` (awaiting human — carries the approval-artifact path + token),
`pass` (approved), `fail` (rejected — carries the R4 finding), `pass_with_warnings`
(unhealthy/degraded env, if not aborting), or `skipped` (surface absent). Pre-merge
**never opens the PR without an approved preview when the gate fired**; a `parked` run
ends without a PR until the human resumes.

## References

- `platform/protocol-smoke.md` — the R1 health precondition (default-liveness floor +
  critical-path golden paths; runs before this gate and short-circuits on failure)
- `prd/protocol-manual-test-plan.md` — the C22 checklist this gate renders in R2 (same
  generate-once artifact post-merge `--staging` renders)
- `platform/protocol-api.md` / `platform/protocol-migration.md` — the base checks; their
  live-env halves (#3) run here against the ephemeral preview (§3)
- `platform/protocol-a11y.md` — a11y evidence bundled into R2
- `../../shared/refs/name-the-user-impact.md` — the finding-framing the R2 evidence uses
- `refs/executor.md` — how the executor sequences smoke→preview, provisions/promotes
  the C23 sandbox (§3b), and handles the async `parked` gate + `--resume`
- `refs/_common.md` — guard / error rule / output envelope

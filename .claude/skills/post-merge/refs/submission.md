---
name: post-merge-submission
description: The submission release model (iOS / Android). deploy-cmd exit 0 = SUBMITTED to store review, never "live"; verification = submission accepted (not app liveness); a configured smoke is reported as backend/build health only. The full submission lifecycle (processing → review → phased rollout), the monitor-handoff, completed-on-submit, and the live_status polling seam are extended by P2/C5.
---

# Submission release model — `release_model: submission`

For a platform whose `release_model` is `submission` (iOS, Android by default —
`../shared/refs/policy-schema.md` §4), release is **asynchronous**. The deploy
command uploads/submits an artifact to a store track; the app becomes available to
users **later, out-of-band**, after store processing and review that post-merge
neither owns nor blocks on. This ref is the C1 contract for that model — the
minimum every `submission` platform obeys. The full lifecycle is deferred (below).

## What deploy-cmd exit 0 means

Exit 0 means the artifact was **submitted / uploaded to its target track** — it is
**not** "live". Concretely:

- `--staging` → submitted to the internal / TestFlight track (near-immediate, but
  still "submitted", not verified installable).
- `--production` → submitted to the store's production/review track (App Store
  review, Play production with staged rollout) — days out, and possibly rejected.

Post-merge records the **target track** with the outcome and reports the platform
as `submitted`, **never** `live` (AC-RM3, AC-SB1). A non-zero exit is a submission
failure — the same `deploy` finding as any platform (`refs/deploy.md`), not a
liveness claim either way.

## Verification = submission accepted, not app liveness

There is nothing live to smoke pre-review, so "smoke the live target" does not
apply here (`refs/verify-deploy.md`). Verification for a `submission` platform is
that the **submission was accepted** (deploy-cmd exit 0 + target track recorded).

A configured `smoke_cmd` still runs, but it can only be checking the **backend or
the build artifact** — never the released app. Post-merge runs it and **labels its
result backend/build health**, never "app is live" (AC-RM3, AC-SB2). A backend
smoke failure is a backend finding; it does not mean the submission failed, and a
backend smoke pass does not mean the app is live.

## Deferred to P2 / C5 (do not build here)

This file is the **C1 primitive only**. The following extend it and are owned by
the **submission lifecycle phase (P2 / C5)** — they are named here as seams, not
implemented:

- **Full lifecycle states** — submit → (processing) → review → phased rollout,
  represented as real states rather than a single exit code.
- **Monitor-handoff** — the explicit "now in Apple/Google review; monitor here;
  halt via `rollout_halt_cmd`" handoff in the run report (AC-SB3).
- **`completed`-on-submit note** — intake `completed` stamps on submit (the
  pipeline's last controllable moment, D2), with a report note that live-to-users
  is downstream and out-of-band (AC-SB4).
- **`live_status` polling seam** — an optional report/status field defaulting to
  `handed_off`, so v4.1 can populate real store-review/rollout state without a
  breaking schema change (AC-SB5).

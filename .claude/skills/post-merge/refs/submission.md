---
name: post-merge-submission
description: The submission release model (iOS / Android). deploy-cmd exit 0 = SUBMITTED to store review, never "live"; verification = submission accepted (not app liveness); a configured smoke is reported as backend/build health only. Carries the full lifecycle (submit → processing → review → phased rollout), the monitor-handoff the run report emits, completed-on-submit, and the live_status polling seam.
---

# Submission release model — `release_model: submission`

For a platform whose `release_model` is `submission` (iOS, Android by default —
`../shared/refs/policy-schema.md` §4), release is **asynchronous**. The deploy
command uploads/submits an artifact to a store track; the app becomes available to
users **later, out-of-band**, after store processing and review that post-merge
neither owns nor blocks on. This ref specifies the whole model: the primitive
(submitted-not-live, backend-health smoke) **and** the lifecycle post-merge
represents and hands off (C5).

## The submission lifecycle — four states, one ownership boundary

Release under `submission` moves through four states. Post-merge **owns** exactly
one of them and **represents + hands off** the rest — it never polls the store,
holds store credentials, or blocks on review (D2):

| State | Who | What it is |
|---|---|---|
| **submit** | **post-merge owns** | the deploy-cmd runs; exit 0 = the artifact was accepted onto its target track |
| **processing** | represented, handed off | the store validates/transcodes the binary (TestFlight *Processing*, Play *in review queue*) |
| **review** | represented, handed off | Apple App Store review / Google Play review — days out, and **may reject** |
| **phased rollout** | represented, handed off | Play staged rollout (`userFraction`), iOS phased release — where the **halt** lever acts (`rollout_halt_cmd`, built by C3/P3) |

Post-merge owns **through submit-accepted**. The moment the store takes custody,
the lifecycle is out-of-band: post-merge records the state it last observed
(submitted, to a named track), emits the monitor-handoff, and stops. It does
**not** watch processing, poll review, or track rollout percentage — those are
represented as a handoff to the human, not orchestrated (D2).

## What deploy-cmd exit 0 means

Exit 0 means the artifact was **submitted / uploaded to its target track** — it is
**not** "live". Concretely:

- `--staging` → submitted to the internal / TestFlight track (near-immediate, but
  still "submitted", not verified installable).
- `--production` → submitted to the store's production/review track (App Store
  review, Play production with staged rollout) — days out, and possibly rejected.

Post-merge records the **target track** with the outcome and reports the platform
as `submitted`, **never** `live` (AC-RM3, AC-SB1).

## Reading the submit output — accepted vs rejected-at-upload

The accept/reject verdict at *this* step is the **deploy-cmd's exit code**, not a
log grep — exit 0 = submission accepted, a non-zero exit = **rejected-at-upload**,
which is a **deploy-step failure** (`refs/deploy.md`, category `deploy`), not a
smoke failure and not a review rejection. Parse the log **only** to name the track
for the report; never let the log override the exit code. The store's later
**review** rejection is out-of-band — post-merge never sees it (it was handed off).

Worked shapes, from the fixture store outputs (`evals/fixtures/post-merge/`):

| Fixture | Accepted marker (exit 0) | Track recorded |
|---|---|---|
| iOS `--production` (fastlane deliver) | `Successfully submitted the app for review!` / `App Store status: Waiting for Review` | `App Store review (Waiting for Review)` |
| iOS `--staging` (altool → TestFlight) | `Build … delivered to TestFlight — status: Processing` | `TestFlight (Processing)` |
| Android `--production` (supply) | `Updating track 'production' (releaseStatus: inProgress, userFraction: 0.1)` / `pending Google Play review; staged rollout 10%` | `Play production (staged rollout 10%, pending review)` |
| Android `--staging` (supply) | `Updating track 'internal' (releaseStatus: completed)` | `Play internal` |

A **rejected-at-upload** run (e.g. altool `Error uploading` / `The bundle is
invalid`, supply `AAB rejected`) exits non-zero → the deploy-failure finding
(`refs/output-schema.md` § Deploy-failure finding) and the failed-ship loop — it is
never reported as `submitted`, and it never becomes a smoke failure.

## Verification = submission accepted, not app liveness

There is nothing live to smoke pre-review, so "smoke the live target" does not
apply here (`refs/verify-deploy.md`). Verification for a `submission` platform is
that the **submission was accepted** (deploy-cmd exit 0 + target track recorded).

A configured `smoke_cmd` still runs, but it can only be checking the **backend or
the build artifact** — never the released app. Post-merge runs it and **labels its
result backend/build health**, never "app is live" (AC-RM3, AC-SB2). A backend
smoke failure is a backend finding; it does not mean the submission failed, and a
backend smoke pass does not mean the app is live.

## Monitor-handoff (the run report block) — AC-SB3

Because post-merge stops at submit-accepted, its final act for a `submission`
platform is an **explicit handoff**, carried in the run report (`--production`
§ *What to expect*; `--staging` report `## Test results`). It names the real
console and the halt lever, generically:

> **Submission handoff — `<platform>`**
> Submitted to **`<track>`** at `<submitted_at>`. Now in **Apple App Store review**
> (iOS) / **Google Play review** (Android) — **not yet live to users**.
> Monitor here: **App Store Connect** (Apple) / **Google Play Console** (Google) —
> review status and (Play) staged-rollout percentage show there.
> Halt lever: **`rollout_halt_cmd`** halts the staged rollout / phased release —
> offered on failure once C3/P3 lands; until then, halt manually in the console.

Never render a `submission` platform as `live` anywhere (AC-RM3/AC-SB1). The
`--staging` handoff is lighter (internal/TestFlight track — "processing; testers
notified when ready") but still names the track and never says "live".

## `completed` on submit — AC-SB4

Intake `completed` stamps **on submit** (the pipeline's last controllable moment,
D2) — `refs/production.md` Step 8 owns the stamp. It is **not** deferred until the
app is live, which would require store-status polling post-merge deliberately does
not do. The stamp always ships with the report note that **live-to-users is
downstream and out-of-band** (store review + rollout), pointing at the
monitor-handoff above. Stamp-on-submit + honest note, never a silent "shipped =
live".

## `live_status` polling seam — AC-SB5

The lifecycle report/status schema carries an **optional** `live_status` field on
each `submission` platform entry (`refs/output-schema.md`), **defaulting to
`handed_off`**. In v4 post-merge always emits `handed_off` — it does not poll (D2).
The field exists so **v4.1 can populate real store state** (`processing` |
`in_review` | `rejected` | `rolling_out` | `live`) without a breaking schema change:
readers must treat any unknown value as opaque and absence as `handed_off`. It is
**additive** — it never reshapes the existing `platforms[]` fields (CV2).

## Submission in `direct` flow — CV5

A mobile repo with `release_flow: direct` (no staging) ships feature→`prod` as a
submission. `release_model` (submission) is **orthogonal to** `release_flow`
(direct): direct decides *which stages run*, submission decides *what a
deploy/verify stage means*. So the **full submission lifecycle runs on the single
feature→`prod` ship** — submit → accepted → monitor-handoff, exactly as above.

The staging-scoped stages are **inactive** in this flow (enumerated once in
`SKILL.md` § *Release flow* — not restated here). That does **not** drop human
judgment: the **double-confirmation** and the **inline human-test approval** are
both active on the direct-flow production ship (`refs/production.md` Step 1
direct-flow paragraph). The sign-off stage being inactive removes a *stage*, not
the *gate* — a human still approves before the submission goes out.

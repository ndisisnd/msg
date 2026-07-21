---
name: post-merge-verify-deploy
description: Post-deploy verification per release_model. deploy platforms — run the platform's smoke against the live target (exit 0 = verified). submission platforms — verification = submission accepted; a configured smoke is reported as backend/build health, never app liveness. Smoke is the v2 contract — a bare smoke_cmd is one-shot (back-compat), an optional watch_window re-checks health over a bounded window, and an optional poll waits for a late-live target up to a bounded timeout. Non-zero smoke = a high `smoke-failed` finding that fails the run; a watch-window degrade or a poll timeout are distinct verdicts. Unconfigured ⇒ skipped with a note, never invented. macOS deploy platforms additionally get config-gated notarization, signing/Gatekeeper, and appcast checks (C6) — each a distinct finding, silent when undeclared.
---

# Verify the deploy — verification per `release_model`

"The deploy command exited 0" is not "the release is verified". After every
deploy — `--staging` Step 5 and `--production` Step 7 — post-merge verifies each
platform **according to its `release_model`** (`../shared/refs/policy-schema.md`
§4):

- **`deploy`** (web, macOS, server) → the target is live, so post-merge runs the
  platform's `smoke_cmd` **against the live target** and treats its exit code as
  the verdict on whether the release is actually up. This is the pipeline's only
  look at the running system; without it a mechanically-clean deploy of a broken
  app reports `pass`. This path is **unchanged from before the release-model
  split** (AC-RM2).
- **`submission`** (iOS, Android) → **nothing is live yet** — the artifact is in
  store review. "Smoke the live target" does not apply. Verification is that the
  **submission was accepted** (deploy exit 0 + track recorded, `refs/deploy.md`).
  The accept/reject verdict is the deploy-cmd's **exit code**: exit 0 = accepted;
  a non-zero exit = **rejected-at-upload**, which is a **deploy-step failure**
  (`refs/deploy.md`), not a smoke failure. A later **review** rejection is
  out-of-band — post-merge never sees it (`refs/submission.md`). A configured
  `smoke_cmd` still runs, but it is checking the **backend or the build** and is
  **reported as backend/build health, never as "the app is live"** (AC-RM3,
  AC-SB2). See `refs/submission.md`.

## Resolve

1. From the same `devkit/PLATFORMS.md` parse as `refs/deploy.md`, read each
   shipping platform's smoke declaration. The declaration resolves to the
   **structured form** `smoke: {cmd, watch_window?, poll?}` (§ *Smoke contract v2*):
   the `smoke_cmd` column is `cmd`; the optional `smoke_watch_window` /
   `smoke_poll` columns fill `watch_window` / `poll` when present. A row with only
   `smoke_cmd` filled resolves to `{cmd}` — a **bare, one-shot** smoke, unchanged
   from before v2 (AC-SM1).
2. Missing file, missing column (pre-`smoke_cmd` PLATFORMS.md), empty `smoke_cmd`
   cell, or a `[USER: …]` placeholder → **skip verification for that platform with
   a note** (`verify.skipped += <platform>`). Never invent or infer a smoke
   command, and never treat a skipped check as a failure — but always surface the
   skip in the run report so the gap is visible. An empty `smoke_watch_window` /
   `smoke_poll` is **not** a gap — it just means one-shot (the common case).
3. A platform whose deploy was itself skipped (no deploy command) skips
   verification silently — there is nothing to verify.

## Run

For each platform with a resolved smoke declaration, run the **first-verdict**
step below. A bare one-shot smoke ends here; a declared `poll` runs *before* this
step (§ *Smoke contract v2* — poll), a declared `watch_window` runs *after* a pass
(§ *Smoke contract v2* — watch-window). The exit-code semantics are identical in
all three modes — v2 only changes *when and how many times* `cmd` is run, never
what an exit code means.

- Run `cmd` (the `smoke_cmd` column) from the repo root, after the deploy
  completes; capture stdout/stderr to a log alongside the deploy log.
- **Exit 0** → for a `deploy` platform, the live target is **verified**; for a
  `submission` platform, the **backend/build is healthy** (never "the app is
  live" — nothing is live pre-review, `refs/submission.md`). Record it under the
  right label.
- **Non-zero exit** → for a `deploy` platform the deploy is live but broken; for a
  `submission` platform the **backend/build check failed** (the submission itself
  may still be valid — the two are unrelated targets). Emit a canonical finding
  (`../shared/refs/finding-schema.md`) — set `message` to name the actual target
  checked (live target vs backend/build health), never "app is live":

```json
{
  "id": "verify-001",
  "source": "post-merge",
  "severity": "high",
  "category": "deploy",
  "rule": "smoke-failed",
  "message": "Staging deploy for web is up but failing its smoke check (exit 1)",
  "file": null,
  "line": null,
  "evidence": {
    "tool": "post-merge",
    "snippet": "<last lines of the smoke log — redact secrets>"
  },
  "suggestion": "The deployed target is not healthy. The failed-ship loop offers to run the platform's rollback_cmd / rollout_halt_cmd (if configured) before the fix loop; then fix forward via /pre-merge.",
  "repro": "<the exact smoke_cmd>",
  "regression_of": null
}
```

## Smoke contract v2 (watch-window + poll)

Smoke is no longer inherently one-shot. The declaration is
`smoke: {cmd, watch_window?, poll?}` (§ *Resolve*); the two optional modifiers are
independent and composable. **In-scope: watch-window + poll only. Explicit
non-goals (D9/CV1):** canary / percentage traffic-splitting, progressive delivery,
and **auto-rollback triggers** — a small-team harness has none of that
infrastructure. v2 re-runs one health `cmd`; it never splits traffic and never
reverts on its own.

The mode is recorded per platform as `one_shot` | `watch` | `poll` (both modifiers
present ⇒ `poll` then `watch`, recorded `poll+watch`) alongside `attempts` and a
`window` outcome (`refs/output-schema.md`).

### one-shot — a bare `smoke_cmd` (AC-SM1, back-compat is sacred)

`smoke_watch_window` and `smoke_poll` both absent ⇒ the smoke runs **exactly once**
and its exit code is the verdict, byte-for-byte the pre-v2 behavior. This is the
default and the common case; nothing about the bare-string path changes. `attempts:
1`, `mode: one_shot`.

### poll — wait for a late-live target (AC-SM3)

Some targets go live **after a delay**: CDN / DNS propagation, store processing, a
just-published appcast, macOS notarization. A one-shot smoke fired the instant the
deploy cmd exits would spuriously fail against a target that is simply not up
*yet*. `smoke_poll: <timeout>/<interval>` (e.g. `10m/20s`) runs the poll loop
**before the first verdict**:

- Retry `cmd` every `<interval>` until it exits 0 or `<timeout>` elapses.
- **First exit 0 within the window** → the target went live → proceed to the
  first-verdict pass (and then `watch_window`, if declared). Record `attempts: <n>`.
- **`<timeout>` elapses with no exit 0** → a **distinct** verdict:
  `never-went-live-within-window`, rule **`smoke-never-live`** (not a generic
  `smoke-failed`). It says *the target never came up inside the bounded wait*, which
  is a different diagnosis than *the target is up but unhealthy*. Severity `high`,
  verdict `fail`; `window: "timed_out"`, `attempts: <n>`. The failed-ship loop then
  runs (rollback offer before the fix loop, as for any failed ship).

Poll never waits unbounded — the `<timeout>` is the hard ceiling. post-merge does
not background-wait or re-invoke itself; the loop runs inline within the run.

### watch-window — re-check health after it passes (AC-SM2)

A deploy that passes its *first* health check can still degrade seconds later
(a bad rollout that only fails under warm traffic, a leaking process, an appcast
that 200s once then 404s). `smoke_watch_window: <duration>/<interval>` (e.g.
`5m/30s`) runs **after a passing first verdict**:

- Re-run `cmd` every `<interval>` across `<duration>`.
- **Every re-check exit 0** → health held → `window: "held"`, verdict stays `pass`,
  `attempts: 1 + <re-checks>`.
- **Any re-check exits non-zero** → **health degraded during the window** →
  verdict flips to **`fail`** with a `smoke-failed` finding whose `message` names
  the degradation (`"web live target passed initially then degraded at <t> into a
  5m watch-window (exit <code>)"`), `window: "degraded"`. This routes to the
  **same failed-ship loop as any smoke failure** — including the **executable
  rollback/rollout-halt offer before the fix loop** (P3; `SKILL.md` § *Failed-ship
  loop*, `deploy` platforms' `rollback_cmd`). The watch-window is exactly the
  signal a redeploy-last-good rollback exists to answer — but the revert is still
  **always-ask, never auto** (D12): a degrade *offers* the rollback, it never fires
  it.

Watch-window is bounded by `<duration>`; post-merge does not monitor indefinitely.
A `submission` platform's `watch_window` (if a backend-health smoke is configured)
watches **backend health**, never app liveness (`refs/submission.md`) — the same
label discipline as the one-shot case.

### poll + watch composed

Both declared ⇒ **poll first** (wait for live) → first-verdict pass → **watch**
(stability over the window). A poll timeout short-circuits (no watch runs — nothing
went live to watch). Recorded `mode: poll+watch`.

## Consequences by mode

| Mode | On smoke failure |
|---|---|
| `--staging` | Verdict `fail`. **Skip the human test script and the sign-off ask** (Steps 6–7) — never hand a human a script for a broken environment. The report points at fixing forward through `/pre-merge`. |
| `--production` | Verdict `fail`. **Skip the intake `completed` stamp** (Step 8) **and the release tag** (Step 9) — a release that isn't verifiably live doesn't close its PRD or earn a version identity. The failed-ship loop **offers to execute the rollback / rollout-halt** (`rollback_cmd` / `rollout_halt_cmd`) before the fix loop (`SKILL.md`, D12/AC-RB1/RB3); an unconfigured lever falls back to the `rollback_possible` notes for manual restore, flagged as a gap (AC-RB2). |

The merge already happened in both cases — verification failure is surfaced
loudly, never silently swallowed, and never pretends to un-merge anything. The
rollback offer is **always-ask, never auto** (D12): a false-positive smoke must not
revert a good release.

## Record

Carry the outcome into the clean-run summary (`refs/output-schema.md`). The
per-platform smoke result carries the v2 fields (all **additive** — the top-level
`verify` block is unchanged, CV2):

```json
"verify": { "ran": true, "passed": true, "skipped": [] }
```

- `ran: false` when every platform skipped (nothing configured).
- `passed: false` (with the finding) on any smoke failure; `null` when `ran` is false.
- `skipped` lists platforms with no usable `smoke_cmd`.

Each platform's entry in `platforms[]` additionally carries the smoke `mode`
(`one_shot` | `poll` | `watch` | `poll+watch`), `attempts` (how many times `cmd`
ran), and the `window` outcome (`held` | `degraded` | `timed_out` | `null` for
one-shot) — see `refs/output-schema.md` § *Smoke v2 fields*. A bare one-shot smoke
emits `mode: one_shot`, `attempts: 1`, `window: null`, so a pre-v2 reader sees no
change (AC-SM1).

The run report's `## Test results` gets one line per platform: for `deploy`
platforms — verified / smoke-failed / **smoke-never-live** (poll timeout) /
**degraded-in-window** (watch-window) / skipped (no smoke_cmd configured); for
`submission` platforms — submitted (+ track) / backend-health-ok /
backend-health-failed / skipped, never "live" (`refs/submission.md`).

## macOS release checks — notarization / signing / appcast (C6, `deploy` model)

A macOS (`release_model: deploy`) release has three verifiable facts the generic
smoke cannot express: the artifact was **notarized** by Apple, it is **signed** and
will pass Gatekeeper, and the **Sparkle appcast** update feed carries the new
version. Today these are folded invisibly into `production_deploy_cmd` — a stall or
a Gatekeeper reject looks like a generic deploy failure (P0 finding #4). C6 makes
each a **distinct, config-gated, declared-artifact check** run during verification
(`--staging` Step 5 / `--production` Step 7), alongside the smoke. **Every check is
gated on its own declared surface: undeclared ⇒ it does not run and nothing is
flagged** (D13). They apply only to `deploy`-model platforms (a `submission`
platform's App Store notarization is Apple-internal and out-of-band —
`refs/submission.md`).

### Notarization — a distinct verifiable step (AC-MAC1)

Notarization is an **asynchronous Apple call**: the notary service accepts the
upload, then works through `In Progress` → a terminal `Accepted` / `Invalid`. This
is the **same async shape as a `submission`'s *processing* state**
(`refs/submission.md` § *The submission lifecycle* — submit → **processing** →
review): a bounded wait for a store/service to reach a terminal status. C6 **reuses
that vocabulary and C7's poll primitive** rather than inventing a parallel
mechanism.

When the macos row declares `notarize_status_cmd` (the minimal surface — a command
that prints the notary status, `status: Accepted` / `In Progress` / `Invalid`, the
`xcrun notarytool info` / `notarytool submit --wait` shape; the fixture deploy logs
show this exact output, `evals/fixtures/post-merge/macos/`), post-merge treats
notarization as a **distinct step**, polled with the **C7 poll primitive** bounded
by the platform's `smoke_poll` (or a single read when `smoke_poll` is absent —
`notarytool --wait` already blocks to a terminal status, so one read usually
suffices). Grep the terminal `status:` line from the cmd output:

- **`Accepted`** → notarization **verified**; record it, continue.
- **`Invalid` / `Rejected`** (terminal) → a **specific** finding — rule
  **`notarization-invalid`**, category `deploy`, severity `high`,
  `message: "macOS notarization returned Invalid for <artifact> (submission <id>)"`.
  This is **not** a generic deploy failure — it names notarization as the failing
  step (AC-MAC1). Verdict `fail`; the failed-ship loop runs.
- **Still non-terminal (`In Progress`) at the poll ceiling** → a **specific** finding
  — rule **`notarization-stall`**, category `deploy`, severity `high`,
  `message: "macOS notarization did not reach a terminal status within <timeout>
  (last: In Progress, submission <id>)"`. A **stall is diagnostically distinct** from
  an outright reject and from a build break — exactly the P0 finding #4 defect
  (a stall folded into the deploy cmd read as a generic failure). Verdict `fail`.

Undeclared `notarize_status_cmd` → notarization stays folded in the deploy cmd
(today's behavior, unchanged and unflagged — config-gated).

### Signing / Gatekeeper smoke (AC-MAC2)

When the macos row declares `signing_smoke_cmd`, run it against the **built
artifact** during verification — the Gatekeeper/signing assessment a user's machine
will make on first launch (`spctl --assess --type execute --verbose` /
`codesign --verify --deep --strict` style; the fixture `smoke-pass.sh` /
`smoke-fail.sh` show `accepted` / `rejected` output). Exit 0 = signed and
Gatekeeper-accepted. **Non-zero → a distinct finding**, rule **`signing-fail`**,
category `deploy`, severity `high`, `message: "macOS signing/Gatekeeper check
rejected <artifact> (spctl: rejected)"` — separate from a generic `smoke-failed`,
because "the shipped app will not open on a user's Mac" is its own diagnosis.
Verdict `fail`. Undeclared ⇒ no signing check runs, nothing flagged.

### Appcast (AC-MAC3, D13 — config-gated)

When the macos row declares `appcast_url` (the Sparkle update feed), verify the
feed is **reachable** and carries the **new version**. The "new version" is tied to
P3's release identity — the resolved `NEXT_VERSION` (`refs/release-identity.md`),
so the check asserts *the version this release actually cut* is published, not a
hard-coded guess:

```bash
curl -fsS "$APPCAST_URL" | grep -q "$NEXT_VERSION"   # feed reachable AND new version present
```

- Reachable + `NEXT_VERSION` present → appcast **verified**.
- Unreachable (curl non-zero / non-200) **or** `NEXT_VERSION` absent from the feed →
  a distinct finding, rule **`appcast-stale`**, category `deploy`, severity `high`,
  `message: "macOS appcast <url> is unreachable or missing version <NEXT_VERSION>"`
  — the update channel did not publish, so existing users will never be offered the
  update. Verdict `fail`. On `--staging` the tie is to the staging channel's
  expected version; the same rule applies.
- **Undeclared `appcast_url` ⇒ nothing runs, nothing is flagged** (D13) — a repo
  that ships macOS without Sparkle sees zero added friction.

### Ordering + failure routing

The macOS checks run **within verification**, after the deploy and around the smoke:
notarization (poll to terminal) → signing/Gatekeeper → appcast, then the generic
`smoke_cmd`/watch-window. Any of the four distinct findings above sets verdict
`fail` and enters the **same failed-ship loop** as a smoke failure — the
`deploy`-model `rollback_cmd` (re-publish the prior appcast build) is **offered
before the fix loop**, always-ask/never-auto (D12; `SKILL.md` § *Failed-ship loop*).
None of these is a **refusal** — the merge already stands; they are ship *failures*
surfaced loudly (`refs/refusal-patterns.md` § *macOS release-check findings*).

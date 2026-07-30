---
name: post-merge-verify-deploy
description: Post-deploy verification per release_model. deploy platforms — run the platform's smoke against the live target (exit 0 = verified). submission platforms — verification = submission accepted; a configured smoke is reported as backend/build health, never app liveness. Smoke is the v2 contract — a bare smoke_cmd is one-shot (back-compat), an optional watch_window re-checks health over a bounded window, and an optional poll waits for a late-live target up to a bounded timeout. Non-zero smoke = a high `smoke-failed` finding that fails the run; a watch-window degrade or a poll timeout are distinct verdicts. Unconfigured ⇒ skipped with a note, never invented. macOS deploy platforms additionally get config-gated notarization, signing/Gatekeeper, and appcast checks — each a distinct finding, silent when undeclared.
---

# Verify the deploy — verification per `release_model`

"The deploy command exited 0" is not "the release is verified". After every
deploy — `--staging` Step 5 and `--production` Step 7 — post-merge verifies each
platform **according to its `release_model`** (`../shared/refs/policy-schema-post-merge.md`
§4):

- **`deploy`** (web, server, directly-distributed macOS) → the target is live, so
  post-merge runs the platform's `smoke_cmd` **against the live target** and
  treats its exit code as the verdict on whether the release is actually up. This
  is the pipeline's only look at the running system; without it a
  mechanically-clean deploy of a broken app reports `pass`.
- **`submission`** (iOS, Android, Mac App Store macOS) → **nothing is live yet** —
  the artifact is in store review, so "smoke the live target" does not apply.
  Verification is that the **submission was accepted** (deploy exit 0 + track
  recorded), the accept/reject verdict being the deploy-cmd's **exit code**; a
  non-zero exit is **rejected-at-upload**, a deploy-step failure (`refs/deploy.md`),
  not a smoke failure. A configured `smoke_cmd` still runs but checks the backend
  or the build. The full rule — submitted-not-live, the backend/build-health
  label, the out-of-band review rejection — is specified once in
  `refs/submission.md`.

## Resolve

1. From the **same scripted parse** `refs/deploy.md` runs
   (`script-platforms-parse.py` — one parser, no second read path), take each
   shipping platform's `smoke_cmd`, `smoke_watch_window`, `smoke_poll` and the
   derived `smoke_mode`. That is the **structured form**
   `smoke: {cmd, watch_window?, poll?}` (§ *Smoke contract v2*) already
   resolved; `smoke_mode` is exactly what the run report records.
2. `smoke_mode=none` — missing file, missing column (pre-`smoke_cmd`
   PLATFORMS.md), empty cell, or a `[USER: …]` placeholder, all normalised
   alike → **skip verification for that platform with a note**
   (`verify.skipped += <platform>`). Never invent or infer a smoke command, and
   never treat a skipped check as a failure — but always surface the skip in the
   run report so the gap is visible. An empty `smoke_watch_window` /
   `smoke_poll` is **not** a gap — it just means `one_shot` (the common case).
3. A platform whose deploy was itself skipped (no deploy command) skips
   verification silently — there is nothing to verify.

## Run — scripted

**The retry mechanics are executed, not reasoned.** One-shot, poll and
watch-window are all "run a command, read the exit code, maybe sleep and repeat"
— fixed results given their inputs — and a hand-rolled bounded loop miscounts
attempts or drops its ceiling. `script-smoke-run.sh` runs them; the model relays
the outcome and writes the finding.

```bash
S=.claude/scripts/script-smoke-run.sh
bash "$S" --platform <p> --cmd "<smoke_cmd>" \
          [--poll "<smoke_poll>"] [--watch-window "<smoke_watch_window>"] \
          --model <deploy|submission> --mode <staging|production> \
          [--notarize-cmd …] [--signing-cmd …] [--appcast-url …] [--version <NEXT_VERSION>]
```

Read `RESULT` and, on a failure, `FINDING` — a one-line finding skeleton to fill
in and relay, never to re-derive:

| `RESULT` (exit) | Meaning | Verdict |
|---|---|---|
| `verified` (0) | for a `deploy` platform the live target is up; for a `submission` platform the **backend/build is healthy** — never "the app is live" (`refs/submission.md`) | pass |
| `skipped` (0) | nothing configured — noted, never a failure | pass |
| `smoke-failed` (3) | a non-zero first verdict: a `deploy` target is live but broken; a `submission` platform's backend/build check failed (the submission itself may still be valid — unrelated targets) | **fail** |
| `smoke-never-live` (4) | the poll ceiling was exhausted, `WINDOW=timed_out` | **fail** |
| `degraded-in-window` (5) | it passed, then a re-check failed, `WINDOW=degraded` | **fail** |
| — (6) | `MACOS_RULE` names a macOS release-check finding (§ *macOS release checks*) | **fail** |

The `LABEL` key says what the pass/fail was **about** (`live-target` vs
`backend-build-health`) — use it so a finding's `message` never says "app is
live" for a `submission` platform. The canonical finding shape
(`../shared/refs/finding-schema.md`):

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
non-goals:** canary / percentage traffic-splitting, progressive delivery,
and **auto-rollback triggers** — a small-team harness has none of that
infrastructure. v2 re-runs one health `cmd`; it never splits traffic and never
reverts on its own.

The mode is recorded per platform as `one_shot` | `watch` | `poll` (both modifiers
present ⇒ `poll` then `watch`, recorded `poll+watch`) alongside `attempts` and a
`window` outcome (`refs/output-schema.md`).

### one-shot — a bare `smoke_cmd` (back-compat is sacred)

`smoke_watch_window` and `smoke_poll` both absent ⇒ the smoke runs **exactly once**
and its exit code is the verdict, byte-for-byte the pre-v2 behavior. This is the
default and the common case; nothing about the bare-string path changes. `attempts:
1`, `mode: one_shot`.

### poll — wait for a late-live target

Some targets go live **after a delay**: CDN / DNS propagation, store processing, a
just-published appcast, macOS notarization. A one-shot smoke fired the instant the
deploy cmd exits would spuriously fail against a target that is simply not up
*yet*. `smoke_poll: <timeout>/<interval>` (e.g. `10m/20s`) runs the poll loop
**before the first verdict** — `--poll` on the script.

- **First exit 0 inside the ceiling** → the target went live → the first-verdict
  pass runs (then `watch_window`, if declared). `ATTEMPTS` counts the tries.
- **The ceiling elapses with no exit 0** → the **distinct** verdict
  `smoke-never-live` (not a generic `smoke-failed`): *the target never came up
  inside the bounded wait*, a different diagnosis than *the target is up but
  unhealthy*. Severity `high`, verdict `fail`, `WINDOW=timed_out`. The failed-ship
  loop then runs (rollback offer before the fix loop, as for any failed ship).

Poll never waits unbounded — the `<timeout>` is the hard ceiling. post-merge does
not background-wait or re-invoke itself; the loop runs inline within the run.

### watch-window — re-check health after it passes

A deploy that passes its *first* health check can still degrade seconds later
(a bad rollout that only fails under warm traffic, a leaking process, an appcast
that 200s once then 404s). `smoke_watch_window: <duration>/<interval>` (e.g.
`5m/30s`) runs **after a passing first verdict** — `--watch-window` on the script.

- **Every re-check exit 0** → health held → `WINDOW=held`, verdict stays `pass`.
- **Any re-check non-zero** → health **degraded during the window** →
  `RESULT=degraded-in-window`, `WINDOW=degraded`, verdict flips to **`fail`** with
  a `smoke-failed` finding naming the degradation. This routes to the **same
  failed-ship loop as any smoke failure** — including the **executable
  rollback/rollout-halt offer before the fix loop** (`SKILL.md` § *Failed-ship
  loop*, `deploy` platforms' `rollback_cmd`). The watch-window is exactly the
  signal a redeploy-last-good rollback exists to answer — but the revert is still
  **always-ask, never auto**: a degrade *offers* the rollback, it never fires it.
  **The script never rolls back**; it reports, and the human decides.

Watch-window is bounded by `<duration>`; post-merge does not monitor indefinitely.
A `submission` platform's `watch_window` (if a backend-health smoke is configured)
watches **backend health**, never app liveness (`refs/submission.md`) — the same
label discipline as the one-shot case.

### poll + watch composed

Both declared ⇒ **poll first** (wait for live) → first-verdict pass → **watch**
(stability over the window). A poll timeout short-circuits (no watch runs — nothing
went live to watch). Recorded `MODE=poll+watch`.

## Consequences by mode

| Mode | On smoke failure |
|---|---|
| `--staging` | Verdict `fail`. **Skip the human test script and the sign-off ask** (Steps 6–7) — never hand a human a script for a broken environment. The report points at fixing forward through `/pre-merge`. |
| `--production` | Verdict `fail`. **Skip the intake `completed` stamp** (Step 8) **and the release tag** (Step 9) — a release that isn't verifiably live doesn't close its PRD or earn a version identity. The failed-ship loop **offers to execute the rollback / rollout-halt** (`rollback_cmd` / `rollout_halt_cmd`) before the fix loop (`SKILL.md`); an unconfigured lever falls back to the `rollback_possible` notes for manual restore, flagged as a gap. |

The merge already happened in both cases — verification failure is surfaced
loudly, never silently swallowed, and never pretends to un-merge anything. The
rollback offer is **always-ask, never auto**: a false-positive smoke must not
revert a good release.

## Record

Carry the outcome into the clean-run summary (`refs/output-schema.md`). The
per-platform smoke result carries the v2 fields (all **additive** — the top-level
`verify` block is unchanged):

```json
"verify": { "ran": true, "passed": true, "skipped": [] }
```

- `ran: false` when every platform skipped (nothing configured).
- `passed: false` (with the finding) on any smoke failure; `null` when `ran` is false.
- `skipped` lists platforms with no usable `smoke_cmd`.

Each platform's entry in `platforms[]` additionally carries the smoke `mode`
(`one_shot` | `poll` | `watch` | `poll+watch`), `attempts` (how many times `cmd`
ran), and the `window` outcome (`held` | `degraded` | `timed_out` | `null` for
one-shot) — see `refs/output-schema.md` § *`platforms[]`*. A bare one-shot smoke
emits `mode: one_shot`, `attempts: 1`, `window: null`, so a pre-v2 reader sees no
change.

The run report's `## Test results` gets one line per platform: for `deploy`
platforms — verified / smoke-failed / **smoke-never-live** (poll timeout) /
**degraded-in-window** (watch-window) / skipped (no smoke_cmd configured); for
`submission` platforms — submitted (+ track) / backend-health-ok /
backend-health-failed / skipped, never "live" (`refs/submission.md`).

## macOS release checks — notarization / signing / appcast (`deploy` model only)

These apply to a **directly-distributed** macOS app — the `.app` a user downloads
and Sparkle updates. A macOS platform declared `release_model: submission` (the
Mac App Store) does **not** run them: Apple notarizes and signs Mac App Store
builds internally, and there is no appcast feed — it follows `refs/submission.md`
exactly as iOS does.

A macOS (`release_model: deploy`) release has three verifiable facts the generic
smoke cannot express: the artifact was **notarized** by Apple, it is **signed** and
will pass Gatekeeper, and the **Sparkle appcast** update feed carries the new
version. Today these are folded invisibly into `production_deploy_cmd` — a stall or
a Gatekeeper reject looks like a generic deploy failure. Each is instead a
**distinct, config-gated, declared-artifact check** run during verification
(`--staging` Step 5 / `--production` Step 7), alongside the smoke. **Every check is
gated on its own declared surface: undeclared ⇒ it does not run and nothing is
flagged**. They apply only to `deploy`-model platforms (a Mac App Store
macOS build is notarized and signed by Apple internally, out-of-band —
`refs/submission.md`).

### Notarization — a distinct verifiable step

Notarization is an **asynchronous Apple call**: the notary service accepts the
upload, then works through `In Progress` → a terminal `Accepted` / `Invalid`. This
is the **same async shape as a `submission`'s *processing* state**
(`refs/submission.md` § *The submission lifecycle* — submit → **processing** →
review): a bounded wait for a store/service to reach a terminal status. It
**reuses that vocabulary and the smoke `poll` primitive** rather than inventing a
parallel mechanism.

When the macos row declares `notarize_status_cmd` (the minimal surface — a command
that prints the notary status, `status: Accepted` / `In Progress` / `Invalid`, the
`xcrun notarytool info` / `notarytool submit --wait` shape; the fixture deploy logs
show this exact output, `evals/fixtures/post-merge/macos/`), post-merge treats
notarization as a **distinct step**. **`script-smoke-run.sh --notarize-cmd` runs the
poll** — the same bounded primitive, bounded by the platform's `smoke_poll`, or
`--notarize-poll`, or the **default `15m/30s`** when neither is declared. Never a
single one-shot read: a lone `In Progress` would spuriously report a stall on a
notary that is simply still working. A non-terminal read **inside** the bound is
**pending** (the loop keeps polling); **only ceiling-exhaustion** is a
`notarization-stall`. The script reads the terminal `status:` line and reports
`NOTARIZATION` / `NOTARIZATION_STATUS` / `NOTARIZATION_ATTEMPTS`:

- **`Accepted`** → `NOTARIZATION=verified`; record it, continue.
- **`Invalid` / `Rejected`** (terminal) → a **specific** finding — rule
  **`notarization-invalid`**, category `deploy`, severity `high`,
  `message: "macOS notarization returned Invalid for <artifact> (submission <id>)"`.
  This is **not** a generic deploy failure — it names notarization as the failing
  step. Verdict `fail`; the failed-ship loop runs.
- **Still non-terminal (`In Progress`) at the poll ceiling** → a **specific** finding
  — rule **`notarization-stall`**, category `deploy`, severity `high`,
  `message: "macOS notarization did not reach a terminal status within <timeout>
  (last: In Progress, submission <id>)"`. A **stall is diagnostically distinct** from
  an outright reject and from a build break (a stall folded into the deploy cmd
  reads as a generic failure). Verdict `fail`.

Undeclared `notarize_status_cmd` → notarization stays folded in the deploy cmd
(today's behavior, unchanged and unflagged — config-gated).

### Signing / Gatekeeper smoke

When the macos row declares `signing_smoke_cmd`, `--signing-cmd` runs it against
the **built artifact** during verification — the Gatekeeper/signing assessment a user's machine
will make on first launch (`spctl --assess --type execute --verbose` /
`codesign --verify --deep --strict` style; the fixture `smoke-pass.sh` /
`smoke-fail.sh` show `accepted` / `rejected` output). Exit 0 = signed and
Gatekeeper-accepted. **Non-zero → a distinct finding**, rule **`signing-fail`**,
category `deploy`, severity `high`, `message: "macOS signing/Gatekeeper check
rejected <artifact> (spctl: rejected)"` — separate from a generic `smoke-failed`,
because "the shipped app will not open on a user's Mac" is its own diagnosis.
Verdict `fail`. Undeclared ⇒ no signing check runs, nothing flagged.

### Appcast (config-gated)

The appcast check is **`--production`-only**. The "new version" it asserts is
the release identity — the resolved `NEXT_VERSION` (`refs/release-identity.md`) —
which **exists only in `--production`** (there is no release version in `--staging`).
So in `--production`, when the macos row declares `appcast_url` (the Sparkle update
feed), `--appcast-url` + `--version "$NEXT_VERSION"` verify the feed is
**reachable** and carries that version — asserting *the version this release
actually cut* is published, not a hard-coded guess (the script runs
`curl -fsS <url> | grep -q <version>` and reports `APPCAST`):

- Reachable + `NEXT_VERSION` present → `APPCAST=verified`.
- Unreachable (curl non-zero / non-200) **or** `NEXT_VERSION` absent from the feed →
  a distinct finding, rule **`appcast-stale`**, category `deploy`, severity `high`,
  `message: "macOS appcast <url> is unreachable or missing version <NEXT_VERSION>"`
  — the update channel did not publish, so existing users will never be offered the
  update. Verdict `fail`.
- **On `--staging`** there is no `NEXT_VERSION` to assert, so the appcast check does
  **not** run — `--mode staging` reports `APPCAST=inactive-staging`; at most emit
  a note that the appcast is verified at release (`--production`). Never
  fabricate a staging version to check against.
- **Undeclared `appcast_url` ⇒ nothing runs, nothing is flagged** — a repo
  that ships macOS without Sparkle sees zero added friction.

### Ordering + failure routing

The macOS checks run **within verification**, after the deploy and around the
smoke — `script-smoke-run.sh` runs them in this fixed order in the same call:
notarization (poll to terminal) → signing/Gatekeeper → appcast, then the generic
`smoke_cmd`/watch-window. `MACOS_RULE` names whichever fired (exit 6). Any of the
four distinct findings above sets verdict
`fail` and enters the **same failed-ship loop** as a smoke failure — the
`deploy`-model `rollback_cmd` (re-publish the prior appcast build) is **offered
before the fix loop**, always-ask/never-auto (`SKILL.md` § *Failed-ship loop*).
None of these is a **refusal** — the merge already stands; they are ship *failures*
surfaced loudly (`refs/refusal-patterns.md` § *macOS release-check findings*).

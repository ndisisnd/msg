# Releases

What's new for you, release by release.

## v2.3.0 — 2026-07-22

> Shipping is now honest on every platform. Web and desktop deploys still go live and get verified live — but iOS and Android releases are treated as what they really are: store submissions, tracked to the handoff, never falsely reported as "live". Around that, production releases gained real guardrails: a one-confirm rollback when a ship goes bad, a version tag and provenance check on every release, and a lock so two ships can't race each other.

### ✨ New
- iOS and Android releases now follow the store's actual lifecycle. A successful push means "submitted for review" — you're told the track it went to, where to monitor it (App Store Connect / Google Play Console), and how to halt the rollout — instead of the old behavior, which declared the app "live" the moment the upload finished.
- When a production ship fails its checks, you're now offered the recovery action — restore the last good deploy, or halt a staged rollout — as a one-confirm step *before* the fix-it conversation starts. It always asks; it never rolls anything back on its own.
- Every production release is now tagged with a version and build number, computed read-only from your release history — and the shipped artifact is checked against the exact commit that was signed off, so a stale build from an old checkout can't slip into a release.
- Two production ships can no longer race each other: if a release is already in flight, a second one refuses cleanly and tells you who's mid-ship. A stuck lock tells you the one-line command to clear it.
- Project setup now verifies your staging environment actually exists per platform — config file present, deploy target real, store track named — instead of assuming a `staging` branch means staging works. Gaps are reported with the exact fix.
- macOS releases get first-class treatment: notarization is tracked as its own step (a stall is named as such, not disguised as a failed deploy), the shipped app's signature is verified, and your update feed is checked for the new version — each only when you've configured it.
- Deploy verification can now watch a window ("stay healthy for 5 minutes") or wait for targets that go live slowly (CDN propagation, store processing) — while a plain one-shot smoke command keeps working exactly as before.

### 📈 Improved
- Running without a staging environment now means *fewer* checks, never *weaker* ones. Stages that don't apply are reported as "inactive" — distinct from "skipped" (tooling missing) and "relaxed" (threshold lowered) — and everything that still applies runs at full strictness.
- The backlog's edit history now lives in its own file next to the backlog, so reading your ideas no longer means paging past every edit ever made — and the history can no longer bleed into the idea list itself.

### 🐛 Fixed
- An adversarial audit of the new release pipeline closed a batch of correctness gaps before they could bite — among them: the no-staging ship path was unrunnable as written, a stale artifact from an *old* release could pass the provenance check, and a well-timed staging merge could slip uncertified commits into a production ship.
- Deleting a backlog idea on a ledger that had never been touched since the history split now correctly reports the history that will be preserved, instead of claiming there is none.

### 🔒 Security
- Staging sign-off is now pinned to the exact commit you tested. If anything lands on staging after you signed off, production refuses to ship until that new work is signed off too — closing the hole where late commits could ride an old approval into production unreviewed.

> Your backlog is no longer append-only: you can now edit an idea you've already logged, or remove one outright — and the removal tells you what it breaks before it happens.

### ✨ New
- You can now change an idea that's already in your backlog with `/intake --update` — sharpen the wording, correct the goal, or have it re-graded — instead of logging a near-duplicate row and untangling it later. Say what you want changed in one line, or browse the open rows and pick one.
- You can now remove a backlog row with `/intake --delete`. Before anything is removed, it tells you what the removal costs you — a PRD left orphaned, a shipped record destroyed, other ideas that were waiting on this one — so you decide with the consequences in front of you.
- Autocomplete now shows each skill's accepted modes and arguments as you type `/`, so you find out what a skill takes before you run it rather than after it refuses.

### 📈 Improved
- Your backlog file is no longer tracked by git. Every feature branch appends to the same table, which made it a standing source of merge conflicts — that whole class of conflict is now gone. The trade-off: the "shipped" stamp a production release puts on a row now stays on your machine only.
- Edits to an idea are recorded in a running log at the bottom of the backlog, so you can see how a feature's definition drifted over time instead of only where it landed.
- Updating an idea never guesses which row you meant. If your description matches nothing, or matches two rows, you get the list and a question — it will never quietly log a new idea when you meant to edit an existing one.
- Ideas already in progress are shown but locked when updating, so an edit can't rewrite the brief out from under work that's already underway. The board (`/msg --gui`) remains the place to move one backwards through its lifecycle.
- Removing a row never renumbers the rows around it. The gap left in the numbering is the record that something was removed — renumbering would silently repoint every reference pointing at those rows.

## v2.1.0 — 2026-07-21

> Checks that need a live app or database — integration, e2e, accessibility, performance, load, migration, mobile, and smoke — now run inside a fresh, disposable sandbox instead of against ambient state, and that same sandbox now doubles as your preview environment.

### ✨ New
- Env-needing checks (integration, e2e, accessibility, performance, load, migration, mobile, smoke) now run inside their own isolated, disposable environment, seeded from scratch each time — so they can't interfere with each other, a concurrent run, or leave anything behind.
- That same sandbox is now reused to serve the human-review preview, so you no longer stand up a separate environment just to let someone poke at the change before approving it.

### 📈 Improved
- The sandbox is only provisioned after your static checks pass, so a run that fails early never pays the cost of spinning one up.
- If your project has no way to provision a sandbox, the gate now says so loudly and skips the checks that need one with a clear note, instead of quietly running them against shared state.

## v2.0.0 — 2026-07-20

> **Heads up:** if you haven't run gate setup yet (or set it up before this release), `/pre-merge` now refuses to run instead of quietly falling back to defaults — a one-time `/pre-merge --init` fixes it. In exchange, the gate got a lot more trustworthy: real secret-scan and migration-safety floors, coverage and load checks that focus on what your change actually touches, native iOS/Android test coverage, and one unified human review step instead of two.

### ✨ New
- One-time setup now also checks whether your project has a CI pipeline and offers to scaffold one for you if it's missing.
- Describe your project in your own words during setup and get a recommended architecture, language, conventions, and release flow — instead of answering a long interview.
- Gate setup can be refreshed after the fact: re-scan your project to pick up new gaps without re-answering questions you've already settled.
- If you've declared a target platform (like iOS or web) but have no test runner set up for it, the gate now flags that gap explicitly instead of silently skipping the check.
- Database migrations that drop or rename something still used elsewhere in the same change are now caught before they ship, with a safe migration path suggested.
- The gate now generates a plain-language, priority-ordered manual test checklist for whatever your automated tests didn't verify — shown to whoever approves the preview, and again to whoever signs off on staging.
- Native iOS and Android test suites are now detected and run automatically alongside Flutter tests, so a native app's mobile checks are real coverage, not a gap.
- API checks now catch backward-incompatible changes to your API spec — removed fields, tightened types — even when your existing tests still pass.

### 📈 Improved
- Idea grading now measures how many moving parts a feature actually has, on a finer six-level scale, instead of a coarse T-shirt size.
- Oversized commits are no longer auto-blocked by a size guess made before the code even exists — the size is measured and left to your judgment, with a brief reason required when you go over.
- Running setup again on a project you've already bootstrapped now fills in whatever's missing instead of stopping because it thinks everything's already there.
- Test coverage checks now focus on the lines your change actually touches, rather than penalizing an imperfect codebase total — and your overall coverage is tracked so it never quietly drops.
- PRD-consistency checks are more thorough: every acceptance criterion needs an actual passing test, unhandled error cases named in your PRD get caught, and scope creep is flagged more strictly.
- Performance checks now also measure how your app responds under realistic load, not just a cold page load, and flag it if things quietly get slower compared to your base branch.
- Load testing now runs only when your change actually touches an endpoint or data path, so it's not wasted on unrelated changes.
- Preview and QA review are now one unified human review step — one clear approve/reject decision with all the evidence in one place.
- A broken preview can no longer be sent for review — a health check now runs first and blocks the request if the preview is down.
- Accessibility checks now cover interactive states like an open dialog or a validation error, not just the initial page load, and can run native accessibility audits on iOS/macOS/Android apps.

### 🐛 Fixed
- The project board no longer misreports every shipped feature as unshipped when your production branch is named `master` instead of `main`.

### 🔒 Security
- Your project can no longer pass the gate without secret-scanning coverage — if no scanner is configured, the gate now blocks instead of quietly skipping this check.

### ⚠️ Breaking
- If your project doesn't have gate configuration yet (or has one from before this release), `/pre-merge` now refuses to run instead of silently falling back to built-in defaults. Run `/pre-merge --init` once — it detects your pipeline and writes the config for you.

### 🗑️ Deprecated
- `--doctor` is renamed to `--init`. `--doctor` still works as an alias for one more release, but switch over now.

## v1.1.0 — 2026-07-16

> A new one-time setup checks that your project has the tools each gate needs and offers to install the missing, free ones — and when a gate run turns up problems, it now offers to fix them and re-run instead of dead-ending.

### ✨ New
- One-time gate setup. Run the new setup once and it checks whether your project has the tools each pre-merge and post-merge step needs — linters, test runners, security scanners, deploy tools — and offers to install the missing ones for you, choosing only free, open-source options and never anything paid. Your answers are remembered, so the gates know what to run, quietly skip what you've opted out of, and stop nagging about tools you deliberately don't use.
- Ship straight to production when you don't have a staging branch yet. A brand-new project can now release directly to your main branch with every safety check still in place — you simply skip the staging step. When you're ready to add a staging stage later, a single command creates it and switches you over.
- Failed gate runs can fix themselves. When a pre-merge or post-merge run finds problems, it no longer stops at "here's what's wrong" — it offers to plan the fixes, build them, and send the branch back through the gate. This now happens even when a deploy or health check fails after a merge, so you're not left stuck.

### 📈 Improved
- Private repositories on free plans are no longer blocked from shipping. If your repo can't turn on branch protection (a paid feature for private repos), the gate now recognises that and warns instead of refusing — so you can still release.
- Every run leaves one tidy, predictably-named report. The plain-language summary, the machine-readable issues, and any fix plan now live together per feature, so finding what a run produced is no longer a hunt across folders.
- Various documentation and under-the-hood improvements.

## v1.0.0 — 2026-07-14

> Flash mode is gone — every msg skill now always runs its full, comprehensive protocol, so thorough gating is the default rather than an opt-in. Alongside it, deploys are now smoke-verified before they count as shipped, and the pre-merge gate works even before you've set up a staging branch.

### ✨ New
- Deploys are now smoke-verified before they're called shipped. After every staging and production deploy, a health check runs against the actual deployed target — "the deploy command exited 0" no longer counts as "the app works". A failed check blocks sign-off and surfaces the rollback notes, so a broken environment can't slip through.

### 📈 Improved
- The pre-merge gate now works in repos that don't have a staging branch yet — it falls back to your main branch as the sync and PR target instead of refusing. You can gate a branch before your branch setup is finished.
- Planning checks are sharper and ask you less. Plan certification now runs a fixed set of checks, auto-fixes what it can, and only stops to ask on genuine product decisions — so getting a plan certified takes fewer interruptions.
- Various under-the-hood cleanups to the installer.

### ⚠️ Breaking
- Flash mode has been removed. Every skill now always runs its full comprehensive protocol. If you used `--flash`, `/msg --flash`, or `/msg --set-mode`, drop them — the flags are now ignored. Runs are more thorough as a result, but the old speed shortcut is no longer available.

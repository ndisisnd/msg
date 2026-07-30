# Releases

What's new for you, release by release.

## v5.0.1 — 2026-07-31

> v5.0.1 is the hardening patch behind v5: twenty-five places where the framework could go wrong *silently* — report a pass it hadn't earned, drop a value, hand out a duplicate number, quietly skip a safety check — now stop and tell you exactly what's wrong instead. Nothing about a correct project behaves differently; only the failure modes got louder. Four remaining wordy corners also received v5's slim treatment.

### 📈 Improved
- Every new refusal names its cause with a stable, greppable key (which column is missing, which id collided, which section didn't parse), so the fix is stated in the error instead of needing a debugging session.
- When a check can't run, the run now says so explicitly instead of skipping in silence — "this wasn't checked" is always distinguishable from "this passed".
- Four texts got the slim pass the rest of the framework received in v5: the code-review instructions (−44%), the CI gate's front door (−32%), the build instructions (−20%), and the ship-gate prose — with every table, step, and gate proven unchanged. Less to load and read, nothing removed but repetition.

### 🐛 Fixed
- The certification gate could report a plan as certified **past an open critical finding** if the findings table's header ever drifted — it now refuses loudly. The same silent-pass class was closed across the framework: branch protection no longer reports "protected" when zero checks are actually required (and it now finds your production branch even when it isn't named `main`), a release can no longer be numbered from zero over an already-live version, and test selection no longer picks the *smallest* test tier when the change couldn't be measured at all — it now picks the largest, as its own rules always said.
- Writers stopped being able to corrupt state quietly: a generated table can no longer overwrite real engineering work without an explicit override, duplicate PRD numbers and duplicate ledger rows are refused before they're written, a value you explicitly supplied can never again be silently dropped because a column was missing, and file writes are now crash-safe.
- Parsers stopped returning confident empty answers: a feature filter that matches nothing, a backlog tally that parses zero rows, or a section that exists but can't be read now say so instead of reporting "nothing found".
- Two bugs found during the work itself: a policy file the scanner couldn't parse could abort the entire project scan (planning tools then saw an empty project), and a stale globally-installed helper script could silently answer in place of the project's own copy — both fixed, the latter now announces itself whenever the fallback is taken.

## v5.0.0 — 2026-07-30

> v5 is the subtraction release: the pipeline does everything it did before with far less machinery, and far more of it is deterministic. Two skills have new names — `/plan-tune` is now `/plan-review` and `/post-merge` is now `/merge` — every build now ends with an independent adversarial code review by default, and roughly twenty-five pieces of judgment-by-prose became small scripts that give the same answer every run.

### ✨ New
- Every build now closes with an adversarial review from a separate reviewer agent: it hunts problems across the whole change, verifies each one before reporting it, and only genuine blockers or high-severity findings hold up your commit. This replaces the old per-ticket pair review, which looked at fragments instead of the change you actually ship.
- The framework now keeps an honest ledger of its own misbehaviour — failed scripts, tool errors, retries, missed writes — and `/msg --doctor` reads it to diagnose recurring problems and recommend fixes. It reports and recommends; it never repairs itself silently.
- Your project can declare its test-environment contract in one place, scaffolded at setup: what must be provisioned for the gate's checks to actually run. The gate reads the declaration instead of guessing, and an unprovisioned sandbox now degrades loudly instead of passing quietly.
- The gate now checks your change against its PRD by default, as advice rather than a blocker — drift between what was planned and what was built gets surfaced without stopping an otherwise-green run.
- Roughly twenty-five new deterministic helpers replace instruction prose: release locking and version identity, CI status reading, smoke-test running, policy reads and writes, PRD and plan shape validation, backlog row writes. Same inputs, same answer, every run.

### 📈 Improved
- The whole framework got substantially smaller. The four biggest skills' front doors shrank 24–44%, every repeated rule now lives in exactly one place, and step-counter ceremony is gone — you hear from a run when something real happens, not on every step.
- A gate run now loads only the policy text that applies to it (about a quarter less), and per-component configuration shrank from ~15 fields to 6 — shared defaults resolve at run time, so a defaults improvement reaches every project immediately, with no migration.
- First-time gate setup asks two questions up front instead of nine; everything else is seeded with sensible defaults and asked only when it first matters.
- Fix work is now sized by a fixed rubric that picks the right model tier mechanically — escalating to the heavier tier is allowed, silently downgrading is not.

### 🐛 Fixed
- The rework flushed out several latent bugs that had been shipping quietly: two PRD parsers misreading section tables, a roadmap fullness signal that could never fire, a shipped-feature move hardcoded to one folder lane, a filename collision waiting in the gate's check discovery, and a dashboard field that was silently dropped.
- Release history is repaired: v2.2.0's notes heading was restored (its notes had been rendering as part of v2.3.0's section), and the missing v3.0.0 tag and GitHub release were backfilled at the original release commit — additively, with nothing moved or rewritten.

### ⚠️ Breaking
- Two skills are renamed: `/plan-tune` → `/plan-review` and `/post-merge` → `/merge`. Use the new names — the old ones are retired, and reinstalling removes the old copies so they can't shadow the new. Everything you produced under the old names is still understood; nothing needs rewriting.
- The preview-deploy approval gate is gone. Its human judgment moved rather than vanished: in a staged flow, the staging sign-off is the human look at the running change; in a direct-to-production flow, you're now asked to test the change yourself before the merge happens — never after.
- PRDs slimmed from 11 sections to 8. The user-flow, key-interactions, and glossary sections are gone — glossary terms now live at the project level, where every pipeline stage sees them. Existing PRDs keep working; new ones are drafted in the new shape.
- Roadmap-driven build orchestration is removed: roadmaps are still written by hand and viewable on the board, but builds run per-PRD now, never from the roadmap surface.

## v4.0.0 — 2026-07-26

> The gate can now run only the tests your diff can actually break. Opt in, and small changes stop paying for the whole test suite on every single run — while the full suite still runs wherever you've told it to (CI, staging, or both), so nothing gets quietly weaker. It's a major release because it's a new decision surface across the whole gate contract, not a tweak: a new policy key, a new run mode, a new tagging workflow, and a new safety net that watches for the one failure mode that matters — a test being skipped that shouldn't have been.

### ✨ New
- You can now turn on **minified test selection** (opt-in, off by default) so `unit`, `integration`, and `regression` runs narrow to the tests your diff can break plus a critical floor, instead of the whole suite every time. How much narrowing happens is decided by a small/medium/large sizing rubric measured from your diff's actual blast radius — never from how big the PRD sounds — and it always falls back to the full suite the moment anything about the selection can't be resolved cleanly.
- A one-time **criticality tagging pass** (`/pre-merge --update-criticality`) reviews your test suite and proposes which tests are critical enough to always run, with evidence for each proposal — you approve, edit, or skip, and it never re-grades a tag you've already set by hand.
- Turning selection off is a **single run**: `/msg --update` flips it off completely, tells you exactly what's being left behind (harmlessly inert, ready to reuse if you turn it back on), and there's no second cleanup step.
- Every minified run says so, honestly — you'll see exactly how many tests ran out of the total, which tier it picked, and why, right in the pipeline output and the run report. A minified pass is never mistaken for a full one.
- A new safety net watches for the one thing that actually matters here: a test that got selected away, then broke somewhere it still runs in full (CI, or your staging test pass). When that happens twice, you're pointed straight at re-tagging the escapee or turning selection off — never left guessing why a supposedly-passing PR broke downstream.

### 📈 Improved
- Enabling test selection walks you through confirming the full suite actually still runs somewhere before it lets you turn selection on — no silent gap between "faster gate" and "nothing checks the rest."

## v3.1.0 — 2026-07-25

> GitHub Actions CI is now opt-in — decline it during setup or later and every gate steps around the missing checks without loosening anything else. And every skill run now closes with a plain-language pass/warning/fail summary and a concrete next step, so you always know where you stand.

### ✨ New
- You can turn off GitHub Actions CI checks entirely — during initial setup or anytime after — and the pipeline adapts cleanly instead of nagging you to add a workflow you don't want. Everything else it protects (branch rules, required reviews, the human sign-off gates) stays exactly as strict as before.
- Every run now ends with a clear 🟢/🟡/🔴 summary: what happened, in plain language, plus the exact next command to run — no more guessing what to do after a build, a plan, or a merge finishes.

### 📈 Improved
- The next-step guidance is now consistent everywhere — the same summary shape whether a run passed clean, needs your input, or hit a blocker.

## v3.0.0 — 2026-07-24

> Planning got a spine of small deterministic tools. The parts of `/plan-pm` and `/plan-em` that were really algorithms all along — who can build in parallel without colliding, which branch a build lands on, what order a roadmap's phases must run in, whether a plan is actually certified — are now computed by scripts and merely *executed* by the model. Same judgment where judgment belongs; no more dice where it doesn't.

### ✨ New
- Parallel builds are now collision-proof by construction: the work table is fed through a checker that computes which pieces share files, groups them into serial packets, and layers the packets into parallel waves — the orchestrator consumes that decomposition instead of eyeballing file lists. A piece with no files declared can no longer slip into a build unnoticed.
- Which git branch a build lands on — create, re-use, or cut fresh — is now decided by a resolver that reads the actual git state. Re-using an already-shipped branch (which would merge old work twice) is now structurally impossible, and the PRD folder moves to the in-progress lane at exactly the right moment.
- Rebuilding your roadmap now gives the same answer twice: phase ordering, dependency layering, and cycle detection run as a deterministic sequencer, and PRDs already on the roadmap stay put unless a real dependency forces a move — every move is tagged with its reason. You still name the phases.
- Whether a plan passed certification is now a mechanical verdict, not an interpretation — the gate reads the stamp and the findings ledger and answers certified or not, with the reason. An uncertified plan can no longer slide through on a generous reading.
- Every status stamp — a PRD moving through its lifecycle, a backlog row marked in-progress or completed — now goes through one shared writer that edits exactly the intended line and nothing else, replacing four skills' improvised file surgery.
- The execution table plan-em appends to a PRD is now rendered by a script from the model's decisions, so every row's wording and every todo link is exact — a typo'd anchor can no longer silently break the plan-to-ticket connection.

### 🐛 Fixed
- Planning skills could silently miss PRDs that had been sorted into the planned / in-progress / done lanes, because their file lookups predated the lanes feature. All prior-PRD scans now go through the lane-aware inventory, so overlap detection and dependency checks see your whole project again.
- The PRD lifecycle promised a "status: eng" stamp when engineering sections land, but nothing ever wrote it. It's now actually stamped, so downstream views of where a feature stands are no longer quietly stale.

## v2.5.0 — 2026-07-24

> `/plan-em` now builds a team by default: an orchestrator breaks each wave of work into independent pieces and runs a fleet of engineer agents on them in parallel, so planning and building a PRD finishes faster. Prefer the classic one-agent-per-area approach? Switch to solo mode anytime — and your choice sticks.

### ✨ New
- When you plan a PRD, `/plan-em` now assembles a team led by an orchestrator that splits each wave into non-overlapping pieces and hands them to engineer agents working in parallel — so a plan comes together as fast as the work allows, instead of one area at a time. It also picks the right power level for each piece automatically, spending the heavyweight model only where the work is genuinely load-bearing.
- Choose how `/plan-em` works with a simple switch: team mode (the new default) for maximum parallelism, or `--solo` for the familiar single-agent-per-area flow. Your choice is remembered per project, so you set it once and every later run follows it.

## v2.4.0 — 2026-07-24

> Your PRDs now organize themselves by stage — planned, in progress, and done each get their own lane, and work moves between them automatically as it flows through the pipeline. New projects get a guided, verify-checked setup path, and existing projects can pull in framework features added since they were first set up.

### ✨ New
- Your PRDs are now sorted into three lanes — planned, in progress, and done — and move between them on their own as a feature gets picked up and shipped, so at a glance you can always see where each piece of work stands. Existing projects have their PRDs sorted into the right lane automatically the first time.
- You can re-scan an already-set-up project for anything the framework has gained since you started it — new setup files, new lanes, PRDs that were never sorted — with a single command, instead of reconciling it by hand. It only adds what's missing and checks with you before sorting anything ambiguous.
- New projects get a guided setup path that walks you from a fresh machine to your first shipped feature, with a verify check at every step, so a half-finished setup fails loudly instead of surfacing as a confusing error later.

### 🐛 Fixed
- When a feature lists another PRD as a dependency, that link is no longer dropped from the plan's metadata. Dependencies you write down are now guaranteed to be tracked, so build ordering and cross-plan impact stay correct without needing a later audit to catch the gap.

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

## v2.2.0 — 2026-07-21

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

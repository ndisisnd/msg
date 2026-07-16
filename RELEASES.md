# Releases

What's new for you, release by release.

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

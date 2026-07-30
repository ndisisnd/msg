---
name: post-merge-deploy
description: Resolve and run the per-platform staging/production deploy pipeline from devkit/PLATFORMS.md. Empty command ⇒ ask or skip with a note; never invent a deploy command.
---

# Deploy — per-platform pipeline from `devkit/PLATFORMS.md`

Post-merge deploys using the commands declared per platform in
`devkit/PLATFORMS.md`, never a guessed one. `--staging` runs `staging_deploy_cmd`;
`--production` runs `production_deploy_cmd`. Each shipping platform gets its own
command (a multi-platform repo deploys each in turn).

## Resolve — one scripted parse, read by every consumer

**Never parse the table by hand.** `script-platforms-parse.py` is the one parser
— this ref, `refs/verify-deploy.md` and both protocols read its output, so a
shifted column can never mean a different command in one place than another:

```bash
S=.claude/scripts/script-platforms-parse.py; python3 "$S"     # devkit/PLATFORMS.md
```

It matches columns **by header name** (never by position) and emits one
`<platform>.<key>=value` line per cell plus a `WARN=` line per inference or
oddity (the script's header is the key list). Then:

1. `PLATFORMS` is the shipping set; take each platform's deploy column for this mode (`staging_deploy_cmd` / `production_deploy_cmd`).
2. **Cell markers arrive normalised**: blank, `—`, and `[USER: …]` are all the empty string — the "empty" path below. Post-merge never invents a command.
3. **Missing file** (exit 4) → `PLATFORM_COUNT=0` + a `WARN`; warn (`No devkit/PLATFORMS.md — run /msg --init`) and treat every command as empty — do not refuse the whole run, the merge/sign-off flow still has value. **Malformed table** (exit 3) → the script refuses loudly with an `ERROR` naming the row; surface it rather than deploying a mis-mapped command.
4. `release_model` arrives with its provenance — `release_model_source=declared` or `inferred` plus the matching `WARN`, never silently. The rule (including why **a macOS row declares its model**) is stated once in `SKILL.md` § *Release model* and `../shared/refs/policy-schema-post-merge.md` §4; surface every `WARN` in the run report.
5. **Per-platform resolution is independent.** A `web`+`ios` ship treats web as `deploy` (live) and ios as `submission` (submitted) in one pass. One platform's model never coerces another's.

## Run

For each platform's resolved command:

- **Non-empty, real command** → run it from the repo root, capture stdout/stderr to a log, and report the target (URL / build id / track) in the run report. A non-zero exit is a deploy failure → emit a `post-merge` finding (`refs/output-schema.md`, category `deploy`) and surface it; do not pretend it deployed. The **failed-ship loop** then runs (`SKILL.md`) — its first action is the **executable rollback / rollout-halt offer** (a configured `rollback_cmd` (`deploy`) / `rollout_halt_cmd` (`submission`, once a rollout exists), offered via `AskUserQuestion` before the fix loop, never auto; unconfigured → notes-only + gap). A **clean deploy exit is not the end of the story** — verification follows per `refs/verify-deploy.md` (a skipped deploy skips its verification too).

  **What exit 0 means depends on the platform's `release_model`:**
  - `deploy` (web, server, directly-distributed macOS) → the target is **live**. Report the live target (URL / build id); verification runs the platform's smoke — the **v2 contract** (bare `smoke_cmd` one-shot, or a declared `watch_window` / `poll`), and for **macOS** the config-gated notarization / signing / appcast checks (`refs/verify-deploy.md`). Notarization is no longer required to be folded inside this deploy cmd — declaring `notarize_status_cmd` makes it a distinct verifiable step.
  - `submission` (iOS, Android, Mac App Store macOS) → the artifact was **submitted to its store track**, not live. Report it as `submitted` (+ target track). The submitted-not-live rule and the backend-health smoke label are specified once in `refs/submission.md`.
- **Empty, or still a placeholder** (`[USER: …]`) → the user never filled it in. Do **not** invent one. Ask once via `AskUserQuestion`:
  > header **Deploy**, question "No `<mode>_deploy_cmd` for `<platform>` in PLATFORMS.md. How to proceed?"
  > - **Skip deploy** — merge/sign-off stand; note "deploy skipped — no command configured" in the report
  > - **I'll paste a command** — run exactly what the user provides (this run only; not written back to PLATFORMS.md)
  - Under an autonomy contract with no human present, default to **Skip deploy** with the note.

## Never

- Never invent, guess, or infer a deploy command from the stack.
- Never write to `devkit/PLATFORMS.md` — it is a read-only devkit file (`/msg --init` owns it).
- Never treat a skipped deploy as a failure — a merge with no configured deploy is a valid, noted outcome.

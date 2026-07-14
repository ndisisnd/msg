---
name: post-merge-deploy
description: Resolve and run the per-platform staging/production deploy pipeline from devkit/PLATFORMS.md. Empty command ⇒ ask or skip with a note; never invent a deploy command.
---

# Deploy — per-platform pipeline from `devkit/PLATFORMS.md`

Post-merge deploys using the commands declared per platform in
`devkit/PLATFORMS.md`, never a guessed one. `--staging` runs `staging_deploy_cmd`;
`--production` runs `production_deploy_cmd`. Each shipping platform gets its own
command (a multi-platform repo deploys each in turn).

## Resolve

1. Read `devkit/PLATFORMS.md`. Parse the pipe table; the relevant columns are
   `platform | … | staging_deploy_cmd | production_deploy_cmd | …`.
2. Missing file → warn (`No devkit/PLATFORMS.md — run /msg --init`) and treat every command as empty (Step "empty" below). Do not refuse the whole run over a missing deploy file; the merge/sign-off flow still has value.
3. For each shipping platform, pick the column for this mode.

## Run

For each platform's resolved command:

- **Non-empty, real command** → run it from the repo root, capture stdout/stderr to a log, and report the target (URL / build id) in the run report. A non-zero exit is a deploy failure → emit a `post-merge` finding (`refs/output-schema.md`, category `deploy`) and surface it; do not pretend it deployed. A **clean deploy exit is not the end of the story** — verification follows per `refs/verify-deploy.md` (a skipped deploy skips its verification too).
- **Empty, or still a placeholder** (`[USER: …]`) → the user never filled it in. Do **not** invent one. Ask once via `AskUserQuestion`:
  > header **Deploy**, question "No `<mode>_deploy_cmd` for `<platform>` in PLATFORMS.md. How to proceed?"
  > - **Skip deploy** — merge/sign-off stand; note "deploy skipped — no command configured" in the report
  > - **I'll paste a command** — run exactly what the user provides (this run only; not written back to PLATFORMS.md)
  - Under an autonomy contract with no human present, default to **Skip deploy** with the note.

## Never

- Never invent, guess, or infer a deploy command from the stack.
- Never write to `devkit/PLATFORMS.md` — it is a read-only devkit file (`/msg --init` owns it).
- Never treat a skipped deploy as a failure — a merge with no configured deploy is a valid, noted outcome.

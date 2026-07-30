---
name: msg-protocol-init-staging
description: >
  Protocol for /msg --init-staging — the only path in msg that creates a
  `staging` branch. Takes a direct-flow repo (ships straight to prod), cuts
  `staging` off the recorded prod branch, publishes it, offers branch
  protection, then flips devkit/policy.json's release flow to `staged` via
  script-policy-set. Offered by /post-merge --init when it detects a
  direct-flow repo, and directly invocable. Never merges, deploys, or opens
  PRs.
type: reference
---

# Protocol: --init-staging

## Usage

**Invoke**: `/msg --init-staging`

- Natural language: "add a staging branch", "set up staging", "switch to a staged release flow"
- Hand-off from `/post-merge --init` when it detects a direct-flow repo

**Preconditions.**
- A git repo with `devkit/policy.json` present. If it is **absent**, the repo was never
  bootstrapped — stop and direct the user to run `/msg --init` first (that seeds the policy this
  mode flips). Do not create the file here.
- Read `policies.release_flow.prod_branch` from `devkit/policy.json` (default `main`). This is the
  branch `staging` is cut from.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Branch topology | `key=value` lines from `script-branch-topology.sh` | Step 1 |
| Prod branch | `policies.release_flow.prod_branch` | `devkit/policy.json` |
| Branch-protection decision | bootstrap \| skip | Step 2 `AskUserQuestion`, gated on `HAS_GH_REMOTE` |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| `staging` branch | Local branch cut from the prod branch, pushed to `origin` | git |
| Branch protection | `post-merge-protection.sh --bootstrap` output lines | GitHub |
| Flow flip | `policies.release_flow.mode:"staged"` + `staging_branch:"staging"`, merged surgically by `script-policy-set.py` | `<cwd>/devkit/policy.json` |
| Summary + readiness handoff | Inline | Step 4 |

## Step-by-step protocol

**Step 1 — Create + push the `staging` branch (the only branch creation in msg).**

Resolve the topology once, with the shared resolver — never with an inline `git show-ref` block:

```bash
.claude/scripts/script-branch-topology.sh "<cwd>"
```

Read `HAS_STAGING` (local) and `HAS_REMOTE_STAGING` (published). **Idempotency first** — if either
is `true`, `staging` already exists: skip creation and go straight to Step 3. Also read
`PROD_BRANCH` as the fallback when `policy.json` carries no `prod_branch`, and `HAS_REMOTE` /
`HAS_GH_REMOTE` for Steps 1 and 2.

If neither is `true`, create it off the prod branch and publish it:

```bash
git branch staging "<prod_branch>"     # cut staging from the recorded prod branch
git push -u origin staging             # publish (skip when HAS_REMOTE=false — note it)
```

**Step 2 — Offer branch protection (gated).** Adding a staging stage means `/post-merge` will gate
on it, so offer to protect `staging` (and prod) now. One `AskUserQuestion`:

> header **Branch protection**, question "Apply branch protection to `staging` + prod now? (required for `/post-merge`)"
> - **Yes, bootstrap it** — run `bash .claude/scripts/post-merge-protection.sh --bootstrap` (resolve locally-first, else `$HOME/.claude/scripts/…`); it's idempotent. Print each `BOOTSTRAPPED`/`BOOTSTRAP_FAILED` line.
> - **Skip** — note `/post-merge` will refuse until protection is set; the user can re-run the script later.

Skip this offer silently when `HAS_GH_REMOTE=false` (no GitHub remote or no `gh` — nothing to
protect yet). Never a hard failure.

**Step 3 — Flip the release flow in `devkit/policy.json`.**

One call. `script-policy-set.py` is msg's only policy writer — it merges the named paths, preserves
every sibling (`version`, `init`, `prod_branch`, `policies.github_actions`, `components[]` …),
re-parses the result, and rolls back on a bad write:

```bash
.claude/scripts/script-policy-set.py --file devkit/policy.json \
  --stamp-by "msg --init-staging" \
  --set policies.release_flow.mode='"staged"' \
  --set policies.release_flow.staging_branch='"staging"'
```

`--stamp-by` refreshes `generated`/`generated_by` because this mode **is** a policy-file writer.
`init` is left untouched — this mode does not complete setup (that's `--init`'s job), and no
`--create` is passed, so an absent `policy.json` is a named failure rather than a silent seed
(the precondition above already refused it). After this, `policy.json` reads
`release_flow.mode:"staged"`, `staging_branch:"staging"` (AC-RF5). Schema authority:
[`shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) (writers table —
`/msg --init-staging` performs the "flow flip").

**Step 4 — Summary + readiness handoff.** Print what happened: branch created (or already present),
protection applied (or skipped), and the new `staged` flow. **Creating the branch does not make
staging ready** — each shipping platform still needs its staging environment declared (a
non-placeholder `staging_deploy_cmd` + target, any staging config file, and a named internal/
TestFlight track for store-submission platforms). Hand off: run **`/post-merge --init`**, which
verifies that per-platform readiness and flags every gap with its exact fix (fill the gap in
`devkit/PLATFORMS.md`, then re-run `--init`). Then `/pre-merge` opens PRs against `staging`. This
mode never merges, deploys, or opens PRs.

Close with the closing message per [`shared/refs/closing-message.md`](../../shared/refs/closing-message.md).

## References

- `.claude/scripts/script-branch-topology.sh` — Step 1 topology resolver (`HAS_STAGING`, `HAS_REMOTE_STAGING`, `PROD_BRANCH`, `HAS_GH_REMOTE`); the one place the branch-detection block lives
- `.claude/scripts/script-policy-set.py` — Step 3 flow flip; msg's only `devkit/policy.json` writer
- `.claude/scripts/post-merge-protection.sh` — Step 2 `--bootstrap`
- `../../shared/refs/policy-schema.md` — canonical policy schema; writers table
- `../../post-merge/refs/protocol-init.md` — the readiness verifier this mode hands off to

---
name: post-merge-protection
description: post-merge Step 1/2 — verify branch protection via post-merge-protection.sh before any merge, policy-conditional per branch_protection mode (enforced refuses / optional warns + proceeds / skip doesn't verify). The machine-enforced half of the v2 safety floor (D11 / C3).
---

# Step 1/2 — Branch protection is a policy-conditional precondition

Branch protection is what makes "green CI required" and "human review required on
main" machine-enforced rather than convention. Whether its **absence** blocks a
merge is now a policy decision (`../shared/refs/policy-schema.md` §2): under the
default `enforced` mode nothing merges without it (today's behavior); `optional`
warns and proceeds; `skip` doesn't verify at all. `NO_GH`/`NO_REMOTE` still refuse
**regardless of mode** — a PR can't be merged without them.

## Resolve the policy mode first

Per target branch `b` (`staging` for `--staging` Step 1, `main` for
`--production` Step 2):

```
mode_b = overrides[b] ?? branch_protection.mode ?? "enforced"
```

from `devkit/policy.json` (`../shared/refs/policy-schema.md` §2). **No file /
malformed → `enforced` everywhere (= today).** When `mode_b = skip`, do **not**
run `--verify` at all — record "protection check skipped by policy" and proceed
(`NO_GH`/`NO_REMOTE` still surface as merge-prerequisite refusals downstream).

## The check

When `mode_b` is `enforced` or `optional`, resolve the script locally-first, then
the global install:

```bash
S=.claude/scripts/post-merge-protection.sh
[ -f "$S" ] || S="$HOME/.claude/scripts/post-merge-protection.sh"
bash "$S" --verify <branch>       # <branch> = staging (--staging) or main (--production)
```

Interpret the machine output against the resolved `mode_b`:

| Output | Meaning | `enforced` | `optional` |
|---|---|---|---|
| `PROTECTED <branch>` (exit 0) | protection matches the baseline | proceed | proceed |
| `UNPROTECTED <branch> <missing>` (exit 1) | absent or incomplete | **refuse** (`refs/refusal-patterns.md` → `unprotected`), list `<missing>` | **warn + proceed**, list `<missing>`, emit **one `low` note** in the report |
| `NO_GH` (exit 2) | `gh` not installed | **refuse** (`unprotected`) — install `gh` + authenticate, then bootstrap | **refuse** (`unprotected`) — same, regardless of mode |
| `NO_REMOTE` (exit 2) | no git remote | **refuse** (`unprotected`) — post-merge needs a GitHub remote to merge PRs | **refuse** (`unprotected`) — same, regardless of mode |

`skip` short-circuits before this table (no `--verify` run). The protection mode
governs **only** the `UNPROTECTED` case; `NO_GH`/`NO_REMOTE` refuse in every mode.

`<missing>` is a comma list: `status-checks` (green-CI requirement absent),
`force-pushes` (force-push not blocked), `required-reviews` (main lacks the ≥1
approval rule — the D11 machine half).

## The bootstrap (setup instruction to surface on refusal)

Protection is set once via the same script's `--bootstrap` mode — offered by
`/msg --init` when a GitHub remote exists, or run by hand:

```bash
bash .claude/scripts/post-merge-protection.sh --bootstrap
```

It PUTs the baseline to `staging` and `main` (required status checks + no
force-pushes on both; ≥1 required review on `main`) and is idempotent. Surface
this exact command in the refusal so the human can self-serve.

Post-merge never sets protection itself — it only verifies. Bootstrapping is an
explicit, remote-mutating action owned by `--init` / the human.

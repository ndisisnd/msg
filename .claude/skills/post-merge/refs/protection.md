---
name: post-merge-protection
description: post-merge Step 1 — verify branch protection via post-merge-protection.sh before any merge. The machine-enforced half of the v2 safety floor (D11 / C3).
---

# Step 1 — Branch protection is a precondition

Nothing merges to `staging` or `main` without branch protection in place —
that's what makes "green CI required" and "human review required on main"
machine-enforced rather than convention. Post-merge verifies it before every
merge and refuses (with the setup instruction) when it's absent.

## The check

Resolve the script locally-first, then the global install:

```bash
S=.claude/scripts/post-merge-protection.sh
[ -f "$S" ] || S="$HOME/.claude/scripts/post-merge-protection.sh"
bash "$S" --verify <branch>       # <branch> = staging (--staging) or main (--production)
```

Interpret the machine output:

| Output | Meaning | Post-merge action |
|---|---|---|
| `PROTECTED <branch>` (exit 0) | protection matches the baseline | proceed |
| `UNPROTECTED <branch> <missing>` (exit 1) | absent or incomplete | **refuse** (`refs/refusal-patterns.md` → `unprotected`), list `<missing>` |
| `NO_GH` (exit 2) | `gh` not installed | **refuse** (`unprotected`) — install `gh` + authenticate, then bootstrap |
| `NO_REMOTE` (exit 2) | no git remote | **refuse** (`unprotected`) — post-merge needs a GitHub remote to merge PRs |

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

# Security policy

## Reporting a vulnerability

Please don't open a public issue for a security problem. Report it privately through
[GitHub's private vulnerability reporting](https://github.com/ndisisnd/msg/security/advisories/new)
— it goes straight to the maintainer and stays closed until there's a fix.

Include what you can: what the issue is, how to reproduce it, and what an attacker
could do with it. A rough report is more useful than no report.

You'll get an acknowledgment as soon as a maintainer sees it. Once a fix ships, you'll
be credited in the advisory unless you'd rather not be.

## Supported versions

msg is installed from `main` by `install.sh`, and that's the only distribution path.
Tags (`v5.0.1`, `v5.0.0`, …) mark what changed; they aren't maintained release branches.
Fixes land on `main`, so the fix for anything reported here is "re-run the installer".

| Version | Supported |
|---------|-----------|
| `main` (latest) | ✅ |
| Tagged releases | ❌ — no backports |

## Scope

msg is a set of Claude Code skills. Everything runs on your own machine, against your own
repository. There is no server, no hosted component, and msg stores no credentials of its
own. Three surfaces are worth a report:

- **The installer.** `install.sh` is meant to be piped into `bash`, and it clones this repo
  and copies files into `~/.claude/skills/` and `~/.claude/scripts/`. Anything that lets it
  write outside those paths, or that changes what it fetches, is in scope.
- **The scripts.** `~/.claude/scripts/script-*.sh` and `*.py` run with your shell's
  privileges and take repository content as input — branch names, PRD text, diffs, JSON
  policy files. Command injection or path traversal through any of those inputs is in
  scope.
- **The git and GitHub write powers.** msg's skills commit, push, open PRs, merge them, and
  tag releases through `git` and the `gh` CLI. Anything that lets a run reach a branch it
  shouldn't — most of all `main` — or that bypasses one of the human gates (staging
  sign-off, the production double-confirm, branch protection) is in scope, whether or not
  it looks like a classic vulnerability.

`/msg --gui` binds an HTTP server to `127.0.0.1` only, and it can read and write files in
your project. If you find a way to reach it from another host, or to make it write outside
the project directory, that's in scope too.

Out of scope: vulnerabilities in Claude Code itself (report those to Anthropic), and the
inherent risk of an agent writing code you didn't read. The human approval gates exist
because that risk is real, not because it's been eliminated.

## Disclosure

Report privately, and please hold off on publishing until a fix is out. Fixed issues are
published as a GitHub advisory with credit to the reporter.

#!/usr/bin/env python3
"""PreToolUse gate: keep CHANGELOG.md in lockstep with commits and pushes.

Fires on every Bash tool call but acts only on `git commit` / `git push`
(substring match, so the rtk-rewritten `rtk git commit` is covered too).

On `git commit`: if CHANGELOG.md is not among the staged files, block and tell
the agent to summarize the staged diff into CHANGELOG.md and stage it. The
staged-file check is what breaks the loop — once CHANGELOG.md is staged the
retry sails through.

On `git push`: if the unpushed commits don't touch CHANGELOG.md, block and tell
the agent to summarize them first. Skipped when no upstream is configured.

Fails open: any error -> allow the command. A bug here must never wedge commits.
"""
import json
import subprocess
import sys


def allow():
    sys.exit(0)


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True)


try:
    data = json.load(sys.stdin)
except Exception:
    allow()

cmd = data.get("tool_input", {}).get("command", "")

# If the command already touches CHANGELOG, let it through — this is the retry,
# or a compound like `git add CHANGELOG.md && git commit`.
if "CHANGELOG" in cmd:
    allow()

if "git commit" in cmd:
    res = git("diff", "--cached", "--name-only")
    staged = res.stdout.split()
    if res.returncode == 0 and not any(
        p == "CHANGELOG.md" or p.endswith("/CHANGELOG.md") for p in staged
    ):
        deny(
            "CHANGELOG gate: before this commit, read the staged diff "
            "(`rtk git diff --cached`), append a concise summary of these "
            "changes to CHANGELOG.md under the Unreleased section, then run "
            "`git add CHANGELOG.md` and re-run the commit. This check passes "
            "automatically once CHANGELOG.md is staged."
        )

elif "git push" in cmd:
    res = git("log", "@{u}..HEAD", "--name-only", "--pretty=format:")
    if res.returncode == 0:  # upstream is configured
        files = res.stdout.split()
        if files and not any(f.endswith("CHANGELOG.md") for f in files):
            deny(
                "CHANGELOG gate: the unpushed commits don't update "
                "CHANGELOG.md. Read their diff (`rtk git diff @{u}..HEAD`), "
                "summarize the changes into CHANGELOG.md under the Unreleased "
                "section, commit that, then re-run the push."
            )

allow()
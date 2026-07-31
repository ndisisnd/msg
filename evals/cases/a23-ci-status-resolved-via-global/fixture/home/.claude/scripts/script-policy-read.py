#!/usr/bin/env python3
# Stand-in for a STALE global install: it answers "CI disabled by policy", so
# which copy of the reader actually ran is observable in the verdict.
print("POLICY_FILE=stub")
print("POLICY_STATE=ok")
print("GITHUB_ACTIONS=false")
print("GITHUB_ACTIONS_REASON=stale GLOBAL install answered")
print("STEPS_CI=absent")

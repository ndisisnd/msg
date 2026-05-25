# Improvement Plan — 5-msg-insights

**Skill:** msg (insights sub-command)
**Change type:** New capability
**Depends on:** plan 3-msg-root-skill (root skill + menu must exist)

## Problem

Token savings and command usage patterns from rtk accumulate silently. Users have no way to see their productivity gains or understand which msg skills they use most — making it hard to prioritise improvements or justify the tooling.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Add insights to `/msg` menu | Extend the root skill menu to include "Insights — usage analytics and token savings". When selected, run the insights report inline. | The root menu is the only entry point. | Not ignorable — insights is inaccessible without menu integration. | P1 |
| 2 | Run `rtk gain --history` and parse output | Execute `rtk gain --history`, capture stdout, extract: top 5 commands by frequency, total tokens saved, and date range of history. | This is the primary data source for usage analytics. | Not ignorable — without it the feature has no data. | P1 |
| 3 | Emit formatted summary report | Present the extracted data as a short readable report: top commands table, total savings, date range. | Raw rtk output is dense; a formatted summary makes it actionable at a glance. | Could skip formatting and emit raw output, but degrades UX significantly. | P2 |
| 4 | Graceful degradation when rtk is absent | If `rtk` is not installed or `rtk gain --history` exits non-zero, emit `[WARN] rtk not available — insights unavailable` and return to menu. | Not all users will have rtk installed. | Not ignorable — a hard error here breaks the entire `/msg` session. | P1 |

---

## Design notes

- The report header should read: "Insights — [date range]"
- Top commands table columns: rank, command, count.
- Total savings should be expressed in tokens saved (not just percentage).
- If history is empty (rtk installed but no history), emit "No usage history recorded yet."

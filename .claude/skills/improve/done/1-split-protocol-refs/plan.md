# Improvement Plan — 1-split-protocol-refs

**Skill:** plan-em
**Change type:** Refactor

## Problem

All protocol refs (`protocol-eng-agent.md`, `template-eng-plan.md`, `protocol-exec.md`) live flat in `refs/`. When plan-em builds agent prompts for Step 4, it points agents at refs that cover both plan mode and build mode even though any single invocation only ever uses one mode. This forces agents to filter the relevant half themselves and couples two distinct execution paths into shared files, making it harder to evolve each mode independently.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Create `refs/plan/` subfolder and move plan-mode refs there | Move `template-eng-plan.md` → `refs/plan/template-eng-plan.md`. Extract Mode 1 section from `protocol-eng-agent.md` → `refs/plan/protocol-eng-agent.md` | Agents activated in plan mode should read only plan-mode instructions; flat layout requires them to filter | Not ignorable — agents reading both-mode protocol introduces ambiguity in output format | P1 |
| 2 | Create `refs/build/` subfolder and move build-mode refs there | Move `protocol-exec.md` → `refs/build/protocol-exec.md`. Extract Mode 2 section from `protocol-eng-agent.md` → `refs/build/protocol-eng-agent.md` | Agents activated in build mode should read only build-mode instructions | Not ignorable — build mode has different output contract (code commits vs markdown sections) | P1 |
| 3 | Delete the original `refs/protocol-eng-agent.md` after split | Remove the flat file once both `refs/plan/protocol-eng-agent.md` and `refs/build/protocol-eng-agent.md` exist | Avoids stale duplicate that contradicts the split files | Not ignorable once the split is live | P1 |
| 4 | Add mode detection to SKILL.md Step 4 | Before building agent prompts, detect mode: if the PRD has no existing `## Engineering —` sections → plan mode; if sections exist → build mode. Document as a named variable `$MODE`. Then reference `refs/$MODE/` for the agent protocol file | Skill must know which subfolder to pass to agents | Deferrable only if plan-em never activates build-mode agents — but protocol-eng-agent.md already specifies Mode 2 as a real path | P1 |
| 5 | Update Step 4 agent prompt instructions in SKILL.md | Replace hardcoded ref paths `refs/template-eng-plan.md` and `refs/protocol-exec.md` with `refs/plan/template-eng-plan.md` and `refs/build/protocol-exec.md` | Existing paths will 404 after the move | Not ignorable | P1 |
| 6 | Update the References section at the bottom of SKILL.md | Reflect new subfolder structure; annotate each ref with which mode uses it | Keeps the references section truthful; agents and readers use it to locate files | Ignorable after code changes are in place, but low-effort | P2 |

---

## Exemplar

**Skill:** plan-em
**Change type:** Refactor

### Problem

All protocol refs live flat in `refs/`. Step 4 agent prompts pass both plan-mode and build-mode ref paths to agents that only ever operate in one mode per activation, requiring them to filter the relevant half themselves.

### Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Move plan refs to `refs/plan/` | Move + extract as described above | Agents read only what they need | — | P1 |
| 2 | Move build refs to `refs/build/` | Move + extract as described above | Same reason | — | P1 |
| 3 | Delete flat protocol-eng-agent.md | Remove after split | Prevent stale duplicate | — | P1 |
| 4 | Add mode detection to SKILL.md | Detect via PRD section presence | Skill must route to correct subfolder | — | P1 |
| 5 | Update agent prompt ref paths | Rewrite two hardcoded paths | Paths will 404 post-move | — | P1 |
| 6 | Update References section | Annotate by mode | Keeps docs truthful | Low-effort | P2 |

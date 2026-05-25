# Improvement Plan — [n]-[feature-type]

**Skill:** <!-- skill name -->
**Change type:** <!-- bug fix / new capability / refactor / clarity -->

## Problem
<!-- One paragraph: what is broken, missing, or unclear -->

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | | | | | P? |

---

## Exemplar

**Skill:** plan-em
**Change type:** Bug in existing behavior

### Problem

Step 1 reads DESIGN-SYSTEM.md but never flags when an impacted component has no data-ingestion path defined. Step 4 agents then assume ingestion exists and produce invalid integration contracts, requiring mid-flight PRD revisions.

### Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Surface missing data-ingestion path as a preflight gap | After DESIGN-SYSTEM.md scan, check each impacted component for an ingestion definition; if absent, emit `[PREFLIGHT GAP]` in Step 2 | Agents silently assume ingestion exists and produce contracts that break in Step 4 | Only if the PRD explicitly marks the component as read-only | P1 |
| 2 | Add `ingestion-required` column to the execution table skeleton | Extend the Step 3 table with a boolean column populated from the DESIGN-SYSTEM.md scan | Missing column causes agents to produce inconsistent execution steps | Deferrable if no impacted components are found in the current run | P2 |

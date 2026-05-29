---
name: Task Filter
description: Heuristic for separating technical work (kept) from non-technical work (dropped) before tasks reach TODOs.json.
type: reference
---

# Task Filter

Apply to every derived task before preview. Items that fail the technical test are dropped and recorded in `dropped_items` with a reason. Todo only tracks technical work.

## Keep — technical

A task is technical when it requires one or more of:

- Writing, editing, or deleting code, config, or infrastructure
- Designing a system, schema, API, or data model
- Writing or updating technical documentation tied to code (API docs, migration guides, runbooks)
- Running a build, deploy, migration, or other engineering operation
- Investigating a bug, performance issue, or system behavior

## Drop — non-technical

A task is non-technical when it primarily involves:

- People logistics (offsites, hiring, 1:1s, performance reviews)
- Calendar or meeting coordination
- Procurement or vendor selection without integration work
- Personal errands or non-work items
- Pure strategy or product discovery without a code-changing outcome

## Decision table

| Item | Verdict | Reason |
|------|---------|--------|
| "Upgrade CI pipeline to Node 20" | keep | infrastructure change |
| "Write migration docs for v2 API breaking changes" | keep | technical documentation |
| "Organize team offsite next quarter" | drop | people logistics |
| "Interview three caching vendors" | drop | procurement without integration |
| "Add Redis cache for session store" | keep | code and infrastructure change |
| "Decide our Q3 roadmap" | drop | strategy without code outcome |
| "Investigate p99 latency regression on /search" | keep | bug investigation |
| "Schedule a kickoff meeting with design" | drop | meeting coordination |

## Edge cases

- **Documentation**: keep only when tied to code (READMEs, API docs, migration guides). Drop marketing copy, blog posts, internal announcements.
- **Research spikes**: keep when they produce a written technical artifact (RFC, design doc, prototype). Drop when the output is a verbal recommendation.
- **Hiring tasks**: always drop. "Write a job description" is non-technical even when the role is engineering.
- **Mixed items**: when one prose item bundles technical and non-technical work, split it. Keep the technical sub-item; drop the non-technical sub-item separately.

## Output format

For each dropped item, record:

```
{
  "item": "<original text>",
  "reason": "<one of: people-logistics, meeting-coordination, procurement, non-technical, exploratory-only, already-done>"
}
```

Display dropped items under the task preview table so the user sees what was removed and why.

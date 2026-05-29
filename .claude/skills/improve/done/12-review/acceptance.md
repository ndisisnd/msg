# Acceptance Criteria — 12-review

## Skill file
1. `.claude/skills/review/SKILL.md` exists and is non-empty.
2. SKILL.md defines the sub-skill interface contract: each `/cook --<flag>` sub-agent accepts `diff` and returns `{ verdict, findings[] }`.
3. SKILL.md documents the two flag tiers: global flags (always applied) and domain flags (codebase fingerprint driven).
4. SKILL.md lists all out-of-scope constraints: no source code modification, no doc checking, no secret scanning, one `AskUserQuestion` call only.

## Diff resolution (Step 1)
5. `/review` with no args resolves diff via `git diff HEAD`.
6. `/review <branch>` resolves diff via `git diff <branch>`.
7. `/review <PR#>` resolves diff via `gh pr diff <n>`.
8. If the resolved diff is empty, `/review` exits with a clear "nothing to review" message and does not proceed.
9. `/review` hard-refuses to run on `main` directly.

## Codebase fingerprint (Step 2)
10. Fingerprint runs once at startup before any other step.
11. Fingerprint detects Flutter/Dart (`pubspec.yaml`), React/Next.js/Node.js (`package.json` deps), TypeScript (`.ts`/`.tsx` files), GraphQL (`.graphql` files), Supabase/Database (`supabase/` dir or migration files).
12. `active_domains[]` is stored and reused by all subsequent steps — never re-derived mid-run.
13. Domains not detected in the repo produce no domain flags.

## PRD location and eval-set bootstrap (Step 3)
14. `/review` searches `features/prd-*/prd-*.md` ordered by recency.
15. If a PRD is found, `/review` scans it for sections named "Acceptance Criteria", "Test Cases", or "Assertions" and extracts them as `eval_set[]`.
16. If no eval-set sections are found in the PRD, `/review` generates `eval_set[]` from the diff + PRD requirements and presents it to the user for confirmation (add / remove / edit).
17. If no PRD is found, `/review` generates `eval_set[]` from the diff alone and presents it for user confirmation.
18. Eval-set size is emitted before proceeding to Step 4.
19. `eval_set[]` is included in the output JSON.

## Review surface derivation (Step 4)
20. Surface summary includes: `files_changed`, `prd_rows_covered`, `uncovered_changes[]`, and `modes[]` (each with its flags).
21. Global flags are always included for applicable modes regardless of domain.
22. Domain flags are filtered by `active_domains[]` and scoped to files in the diff that touch that domain.
23. Sub-ref flags (e.g. `--react:hooks`) are used when only part of a domain is touched.
24. Changed areas with no PRD coverage appear in `uncovered_changes[]`.

## Surface confirmation (Step 5)
25. `/review` calls `AskUserQuestion` exactly once, showing the surface summary and the full proposed execution plan.
26. The execution plan shows each mode with its flags and the files each `/cook` agent will receive (e.g. `Quality → /cook --api-design --architecture --react:component-patterns (auth.ts)`).
27. Options presented are: **Proceed**, **Adjust**, **Cancel**.
28. If the user selects **Adjust**, `/review` accepts the updated scope/flags before proceeding.
29. If the user selects **Cancel**, `/review` exits cleanly with no findings emitted.
30. No other `AskUserQuestion` calls are made at any point in the run.

## Mode execution (Step 6)
31. Modes run in order: Quality → Coverage → Functional → Security → Performance.
32. Within each mode, all `/cook --<flag>` sub-agents run in parallel.
33. If any mode returns `block`, the pipeline stops immediately — subsequent modes do not run.
34. Coverage invokes the test runner scoped to changed files and compares output against `eval_set[]`.
35. Functional runs assertions from `eval_set[]` against the diff.
36. Quality, Security, and Performance each receive the resolved diff and their respective flag set.

## Aggregation and output (Step 7)
37. All mode outputs are merged into a single JSON object with a `modes` key containing one entry per mode.
38. The top-level `verdict` is the worst across all modes (`block` > `warn` > `pass`).
39. Each finding includes a `source` field identifying which `/cook --<flag>` agent produced it.
40. JSON is emitted to stdout on every run.
41. When a PRD path is known, JSON is also written to `features/prd-[n]/review/review-<YYYYMMDD-HHmmss>.json`.
42. When no PRD path is available, no file is written — stdout only.
43. `"prd": null` is emitted in the JSON when no PRD was found.

## Verdict semantics
44. `block` verdict stops the pipeline after the blocking mode — no subsequent modes run.
45. `warn` verdict means no blocks; pipeline continues with warnings surfaced in PR summary.
46. `pass` verdict means all modes clean; pipeline continues silently.

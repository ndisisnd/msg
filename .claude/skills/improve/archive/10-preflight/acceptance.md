# Acceptance Criteria — 10-preflight

## Skill file
1. `.claude/skills/preflight/SKILL.md` exists and is non-empty.
2. SKILL.md defines the sub-skill interface contract: each sub-skill accepts `diff` and returns `{ verdict, findings[] }`.
3. SKILL.md lists all out-of-scope constraints: no source code modification, no CI replacement, no interactive prompts during run.

## Scope resolution (Step 1)
4. `/preflight` with no args resolves `branch` via `git branch --show-current` and `diff` via `git diff main...HEAD`.
5. If `git diff main...HEAD` is empty, preflight exits with a clear "nothing to check" message and does not proceed.
6. The one-line scope summary is emitted before any check runs: branch name, commit count, files changed.
7. Preflight hard-refuses to run on `main` directly.

## Secret scan (Step 2 — hard block)
8. If secret-scan returns `verdict: block`, preflight emits the finding (file, line, masked secret type) and exits non-zero.
9. No subsequent step runs after a secret-scan block.
10. Secret scan always runs first, before eng --review or any other check.

## eng --review gate (Step 3 — hard block)
11. If `prd_path` and `rows` are available, preflight invokes eng --review with those fields.
12. If `prd_path` is null, preflight invokes eng --review in diff-only mode.
13. If eng --review verdict is `fail`, preflight emits `blocker` and `critical_count`, exits non-zero.
14. No subsequent step runs after an eng --review block.

## Breaking change detection (Step 4 — hard block)
15. If breaking-change detects any finding, preflight emits the findings list (file, identifier, change_type, impact) and exits non-zero.
16. No subsequent step runs after a breaking-change block.

## Docu self-heal (Step 5 — soft warn)
17. Preflight invokes docu and attempts to auto-apply every finding via `Edit` without prompting the user.
18. Self-healed findings are recorded in the preflight artifact under `docu.self_healed[]`.
19. Remaining unfixed findings appear as soft warnings and do not block the pipeline.
20. Docu step never causes a non-zero exit on its own.

## PR hygiene (Step 6 — soft warn)
21. pr-prep findings (branch name, commit message, debug commits, PR template) appear as soft warnings.
22. PR hygiene findings never cause a non-zero exit on their own.

## Verdict and output
23. `BLOCK` verdict exits non-zero; `WARN` and `PASS` exit zero.
24. Terminal summary emits one line per step: status symbol (✓ / ⚠ / ✗), finding count, action taken.
25. Total terminal output fits in a single scrollable view for a typical run.
26. No `AskUserQuestion` calls are made at any point during the run.
27. On `BLOCK`: preflight does not proceed to `gh pr create`.
28. On `WARN` or `PASS`: pipeline continues; warnings are surfaced in the PR summary.

## Preflight artifact
29. When `prd_path` is known, artifact is written to `features/prd-[n]/preflight/preflight-<YYYYMMDD-HHmmss>.json`.
30. When `prd_path` is null, artifact is written to `.preflight-last.json` at repo root.
31. Artifact schema contains: `run_id`, `branch`, `timestamp`, `commit_count`, `files_changed`, `verdict`, and a `steps` object with one key per sub-skill.
32. Each step in the artifact contains at minimum `verdict` and `findings[]`.
33. Preflight artifact is never written if scope resolution fails (empty diff).

## Sub-skill independence
34. Each sub-skill (secret-scan, eng --review, breaking-change, docu, pr-prep) can be invoked independently outside of preflight and still produces a valid `{ verdict, findings[] }` response.
35. Preflight does not parse free-form text output from sub-skills — it reads structured objects only.

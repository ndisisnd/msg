# Acceptance Criteria — 14-mechanical-checks

## Change 1 — Fingerprint extension

1. `refs/FLAG-LIST.md` contains a new section titled "Mechanical runner detection" with at least four sub-tables: JS/TS, Python, Dart/Flutter, Secret scanners.
2. Each runner entry in the new section specifies four fields: `name`, `command` (with `<files>` placeholder), `expects_zero_exit`, `severity_on_fail` (`warn` for lint/format, `block` for typecheck/secrets).
3. `SKILL.md` Step 2 instructs the model to emit `mechanical_runners[]` and `secret_scanner` outputs in addition to the existing `active_domains[]`, `test_runner`, and `flag_inventory`.
4. The detection rules are runner-agnostic in structure: adding a new runner (e.g. Go's `golangci-lint`) requires only a new table row, no protocol edits.

## Change 2 — Quality mode mechanical gate

5. `refs/modes/quality.md` has a "Stage 0: Mechanical gate" section that runs *before* the existing `/cook` semantic stage.
6. Stage 0 executes every runner in `mechanical_runners[]` against the diff file list and captures exit code + stdout.
7. A lint or format runner returning non-zero produces a `warn` finding with `source` prefix `lint:` or `format:`.
8. A typecheck runner returning non-zero produces a `block` finding with `source` prefix `typecheck:`.
9. A runner configured in the repo but not executable produces a `block` finding with `source` prefix `env:` and a remediation note naming the runner.
10. If Stage 0 emits any `block` finding, Quality mode returns immediately with verdict `block` and skips the `/cook` semantic stage entirely (no Agent spawns).
11. If Stage 0 emits only `warn` or `pass`, Quality proceeds to the existing `/cook` fan-out and aggregates findings from both stages.

## Change 3 — Security mode secret scan

12. `refs/modes/security.md` has a "Stage 0: Secret scan" section that runs *before* the existing `/cook` flag stage.
13. If `secret_scanner` is `null`, Stage 0 emits a single `warn` finding with note containing the substring `"install gitleaks"` and continues to the `/cook` stage.
14. If `secret_scanner` is set, Stage 0 runs the scanner against the diff by default, parses findings, and emits one `block` finding per scanner hit with `source` prefix `secrets:` and populated `file` + `line`.
15. Stage 0 always proceeds to the existing `/cook` flag stage regardless of its own verdict (independent signals).

## Change 4 — SKILL.md refusal removed and descriptions broadened

16. The string `"does NOT run dedicated secret scanning"` is absent from `SKILL.md`.
17. The Step 6 mode-order summary in `SKILL.md` describes Quality as covering mechanical (lint/format/typecheck) checks before semantic.
18. The Step 6 mode-order summary describes Security as covering secret scanning before semantic flags.
19. The top-of-file description in `SKILL.md` mentions mechanical or local-tooling coverage so the trigger description matches the broadened scope.

## Change 5 — `--full-secret-scan` flag

20. `SKILL.md` Usage section documents `/review --full-secret-scan` and notes it is composable with branch and PR args.
21. When `--full-secret-scan` is present, Security mode Stage 0 invokes the scanner against the full working tree instead of the diff file list.
22. When `--full-secret-scan` is absent, Stage 0 invokes the scanner against the diff file list only.

## Change 6 — Schema typed

23. `refs/schema.md` documents `mechanical_runners[]` and `secret_scanner` as fingerprint fields with their structural shape.
24. `refs/schema.md` lists the five new `source` prefixes (`lint:`, `format:`, `typecheck:`, `secrets:`, `env:`) as valid values for finding sources.

## Cross-cutting

25. After all edits, running `/review` on a repo with no lint/format/typecheck/secret runners detected produces no new `block` verdicts attributable to this plan (mechanical gate degrades cleanly to `pass` when nothing is detected).
26. Coverage mode (`refs/modes/coverage.md`) is unchanged by this plan — no edits to that file.
27. No new `.husky/`, `.pre-commit-config.yaml`, or git-hook file is created anywhere in the repo.
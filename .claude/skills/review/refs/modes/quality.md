# review — Quality mode

**When it runs:** first in pipeline order.

**What it checks:** code complexity, naming conventions, maintainability, dead code, and API contract soundness. Structural issues here are hard-block candidates — a structurally unsound codebase should not proceed to behavioral checks.

## Flags

Global (always): `--api-design`, `--architecture`, `--error-handling`, `--debug`

Domain flags: all active domains from `active_domains[]` that are touched by the diff (see `refs/FLAG-LIST.md`). Use sub-ref flags when only part of a domain is in scope.

## Orchestrator rubric

Quality mode extends `/cook`'s flag coverage with five additional concerns that have no corresponding `/cook` flag:

| Concern | Category tag |
|---------|-------------|
| Dead code | `"dead-code"` |
| Duplicated logic / DRY violations | `"duplication"` |
| Unclear naming | `"naming"` |
| Excessive cyclomatic complexity | `"complexity"` |
| Readability / maintainability regressions | `"readability"` |

These checks are **Quality-mode only** — no other mode receives the rubric amendment below.

## Sub-agent prompt amendment

When Step 6 of `SKILL.md` spawns the Quality-mode subagent, the orchestrator appends the following clause verbatim to the agent's prompt:

> In addition to your flag's standard checks, also flag any:
> (a) dead code — unreachable, unused, or commented-out code blocks;
> (b) duplicated logic / DRY violations — repeated logic that could be extracted;
> (c) unclear naming — identifiers that obscure intent;
> (d) excessive cyclomatic complexity — functions with deeply nested or branching control flow;
> (e) readability / maintainability regressions — changes that make the code harder to reason about.
>
> Tag each such finding with a `category` field matching one of: `"dead-code"`, `"duplication"`, `"naming"`, `"complexity"`, `"readability"`.
>
> Additionally, for every entry in `uncovered_changes[]` provided as input, emit a `warn`-severity finding with:
> - `category: "scope-creep"`
> - `suggestion`: recommend either removing the change or extending the PRD to cover it.
>
> Every finding you emit **must** include a `category` field.

## Stage 0 — Mechanical gate

Runs **before** the `/cook` semantic stage. Operates on `mechanical_runners[]` from Step 2 of `SKILL.md`.

For each runner in `mechanical_runners[]`:

1. Substitute `<files>` in the runner's `command` with the space-separated list of diff files the runner can process (e.g. filter to `.ts`/`.tsx` for `eslint`, `.py` for `ruff`). If no diff file matches the runner's extension scope, skip that runner.
2. Execute the command via Bash. Capture exit code, stdout, and stderr.
3. Emit findings based on outcome:

| Outcome | Severity | `source` prefix | Notes |
|---------|----------|-----------------|-------|
| Exit zero | — | — | No finding emitted; runner passed. |
| Non-zero exit, runner is lint (`eslint`, `ruff`) | `warn` | `lint:<runner>` | One finding per reported issue; populate `file`/`line` from runner output where parseable, else attach to the file under check. |
| Non-zero exit, runner is format (`prettier`, `black`, `dart format`) | `warn` | `format:<runner>` | One finding per file flagged as unformatted. |
| Non-zero exit, runner is typecheck (`tsc`, `mypy`, `dart analyze`) | `block` | `typecheck:<runner>` | One finding per type error. |
| Configured but not executable (e.g. `command not found`, `cannot find module`) | `block` | `env:<runner>` | Message: `"<runner> configured but not executable — install dependencies."` |
| Secret-scan-only runner | — | — | Handled in Security mode Stage 0, not here. |

**Short-circuit rule:** if Stage 0 emits any `block` finding (typecheck failure or `env:` finding), Quality mode returns its mode verdict immediately as `block` with the Stage 0 findings as `findings[]`, and **skips the `/cook` semantic stage entirely** — no Agent spawns. Saves tokens on broken code.

**Proceed rule:** if Stage 0 emits only `warn` or no findings, Quality continues to the `/cook` semantic stage below and merges Stage 0 findings into the final mode output.

**Empty fingerprint:** if `mechanical_runners[]` is empty (no runners detected), Stage 0 is a no-op and Quality proceeds directly to the semantic stage.

## Execution (semantic stage)

Shared contract: `_common.md`. One subagent for the whole mode (not one per
flag), receiving the resolved diff, the changed files touching its domains, all
assembled Quality flags, and the compiled standards payload — **plus** the
Quality-only inputs: the rubric amendment (`#sub-agent-prompt-amendment`) and
`uncovered_changes[]` from Step 4. Mode verdict = worst of the subagent's verdict
AND Stage 0 findings.

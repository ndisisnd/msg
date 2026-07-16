---
name: mechanical
description: Gate Step 2 — deterministic, zero-LLM checks. Lint, format, typecheck, plain-English comment coverage, and per-commit small-commit-cap audit across the branch. Scripts only; any red short-circuits per severity.
---

# Step 2 — MECHANICAL

All checks here are scripts — **no LLM**. Run them on the post-sync branch diff.
Findings conform to `refs/finding-schema.md`; `source` uses the tool prefix.

## Lint / format / typecheck

Run each detected mechanical runner from the Step 1 tooling detection
(`detected.mechanical_runners[]`) in parallel:

```
for runner in detected.mechanical_runners:
  rtk <runner.command with the diff's files>
```

- Non-zero exit and `severity_on_fail == "block"` → `blocker` finding (`source: lint:` / `format:` / `typecheck:`), first error line quoted.
- `severity_on_fail == "warn"` → `medium` finding, continue.

## Comment coverage (A4)

Run the plain-English-comment scan on the branch diff:

```
S=.claude/scripts/eng-comment-scan.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/eng-comment-scan.sh"
bash "$S" origin/staging...HEAD
```

- `UNCOMMENTED <file>:<line> <symbol>` lines → one `low` finding each (`source: comment-scan`, `category: readability`, `rule: uncommented-symbol`), message names the symbol. Deterministic; the pair-programmer already checks this per ticket (A4) — this is the gate backstop.
- `COMMENT_SCAN clean` → no findings.

## Commit-cap audit (A5)

Re-apply the `eng-commit-cap.sh` logic **per commit across the branch** (`origin/staging..HEAD`). For each commit, compute changed LOC = additions + deletions from `git show --numstat <sha>`, excluding the script's lockfile/generated allowlist:

```
lockfiles/generated skipped: package-lock.json, yarn.lock, pnpm-lock.yaml,
  Cargo.lock, Podfile.lock, Gemfile.lock, go.sum, *.min.js, *.min.css, *.map,
  *.g.dart, *.freezed.dart, *.pb.go, dist/**, build/**, node_modules/**,
  vendor/**, */generated/**, */__generated__/**
```

Cap = **500** LOC, or **300** when the commit contains a breaking change. A commit
over its cap **without** an `Oversize-reason:` trailer in its body grades as a
`medium` finding (`source: commit-cap`, `category: scope-creep`, `rule: oversize-commit`),
message: `"commit <short-sha> changes <loc> LOC (cap <cap>) with no Oversize-reason: trailer"`.
A commit over cap **with** the trailer is recorded (not a finding) — the justification carries.

## Short-circuit

A `blocker` from lint/typecheck short-circuits the run per `refs/severity-rubric.md`
(a broken build/type error makes later stages moot) — skip Steps 3–8, write the
issues file, go to Step 9's fail path. Comment-scan and commit-cap findings never
short-circuit on their own (they are `low`/`medium`).

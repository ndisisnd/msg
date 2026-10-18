---
name: mechanical
description: The mechanical component — deterministic, zero-LLM checks. Lint, format, typecheck, plain-English comment coverage, and a small-commit-cap audit over the commits new since the last gate run. Scripts only; it is the critical class, so a red result aborts the run.
---

# `mechanical` — the deterministic floor

All checks here are scripts — **no LLM**. Run them on the post-sync branch diff.
Findings conform to `../finding-schema.md`; `source` uses the tool prefix.

## Lint / format / typecheck

Run each mechanical runner resolved for this component in `devkit/policy.json`
`components[]` (`detected.mechanical_runners[]`) in parallel:

```
for runner in detected.mechanical_runners:
  <runner.command with the diff's files>
```

- Non-zero exit and `severity_on_fail == "block"` → `blocker` finding (`source: lint:` / `format:` / `typecheck:`), first error line quoted.
- `severity_on_fail == "warn"` → `medium` finding, continue.

## Comment coverage (A4)

Run the plain-English-comment scan on the branch diff:

```
S=.claude/scripts/script-eng-comment-scan.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-eng-comment-scan.sh"
bash "$S" origin/<base>...HEAD   # <base> = the run's resolved base (../executor.md §0a)
```

- `UNCOMMENTED <file>:<line> <symbol>` lines → one `low` finding each (`source: comment-scan`, `category: readability`, `rule: uncommented-symbol`), message names the symbol. Deterministic; the pair-programmer already checks this per ticket (A4) — this is the gate backstop.
- `COMMENT_SCAN clean` → no findings.

## Commit-cap audit (A5) — new commits only

Re-apply the `script-eng-commit-cap.sh` logic **per commit**, over the commits that are
**new since the last gate run on this branch**. For each such commit, compute changed
LOC = additions + deletions from `git show --numstat <sha>`, excluding the script's
lockfile/generated allowlist:

```
lockfiles/generated skipped: package-lock.json, yarn.lock, pnpm-lock.yaml,
  Cargo.lock, Podfile.lock, Gemfile.lock, go.sum, *.min.js, *.min.css, *.map,
  *.g.dart, *.freezed.dart, *.pb.go, dist/**, build/**, node_modules/**,
  vendor/**, */generated/**, */__generated__/**
```

**Scope — why "new since the last run".** An oversize commit that is already pushed
cannot gain an `Oversize-reason:` trailer without rewriting history, so auditing the
whole branch every run re-flags the same unfixable commit forever — noise the author
cannot clear. The audit range is therefore `<last-checked>..HEAD`, where
`<last-checked>` is the commit the previous run on this branch checked — stored with
its verdict in `.pre-merge/last-check.json` (`../executor.md` §6) and copied into this
run's `plan.json` as `last_checked`:

```
L=.claude/scripts/script-premerge-last-check.sh; [ -f "$L" ] || L="$HOME/.claude/scripts/script-premerge-last-check.sh"
bash "$L" --read --branch "$(git branch --show-current)"   # → {"head": …, "verdict": …}
```

**No record** (exit 3 — the first gate run on this branch), or the recorded commit is
no longer an ancestor of `HEAD` (history was rewritten) → audit the full
`origin/<base>..HEAD` range once; every later run only sees what the author has added
since. The real control is eng-side prevention
(`script-eng-commit-cap.sh` at commit time), not repeated gate flagging.

Cap = **500** LOC, or **300** when the commit contains a breaking change. A commit
over its cap **without** an `Oversize-reason:` trailer in its body grades as a
`medium` finding (`source: commit-cap`, `category: scope-creep`, `rule: oversize-commit`),
message: `"commit <short-sha> changes <loc> LOC (cap <cap>) with no Oversize-reason: trailer"`.
A commit over cap **with** the trailer is recorded (not a finding) — the justification carries.

## Short-circuit

`mechanical` is in the **critical class**, so a `blocker` from lint/typecheck aborts
the remaining pipeline (a broken build or type error makes later components moot) —
write the issues file and take the fail path. The one statement of that rule is
`../severity-rubric.md` § *Fail-fast by component `criticality`*. Comment-scan and
commit-cap findings never abort on their own (they are `low`/`medium`).

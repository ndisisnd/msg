---
name: Sanctioned writes
description: The canonical, complete enumeration of everything merge is allowed to write — cited from elsewhere as this skill's hard-refusal enumeration
type: reference
---

# Sanctioned writes — the canonical, complete enumeration

Merge does not modify source code. `../../shared/refs/safety-floor.md`,
`release-identity.md` and `refusal-patterns.md` defer here; this is the
one copy:

1. the **two PR merges** (`--staging` feature→`stg`; `--production` `<head>`→`prod`);
2. the **`staging-signoff:` frontmatter stamp** — written by `--staging` on approval, re-stamped by `--production` Step 1 when an unpinned legacy stamp is confirmed;
3. the **`INTAKE.md` `status: completed` stamp** on each shipped PRD's mapped row (`--production`);
4. the **terminal `status` frontmatter stamp** on each shipped PRD (`--production`, on a successful ship) — the `wip → complete` transition, or `eng → done` on a PRD written before v5.4 (`../../shared/refs/prd-lifecycle.md`); the existing `reviewed:` / `staging-signoff:` stamps stay intact;
5. the **run report** (`report-prd-<N>-<K>.md`) and, on a failed ship, the colocated **issues file** (`report-prd-<N>-<K>.json`) that `eng --build report=` consumes;
6. the release **git tag** `v<x.y.z>+<build>` on prod at a successful `--production`;
7. the transient **release-lock tag** `release-lock-<prod>` around a `--production` ship;
8. the **move of a shipped PRD's folder** `features/wip/prd-<n>-<slug>/ → features/done/prd-<n>-<slug>/` — a whole-directory rename carrying the PRD plus its colocated `reports/`/`preflight.md`/`test/`.

Items 6–7 are **metadata on a commit** — they write no tracked file, so the
safety floor holds; the version source of truth is the tag, never a VERSION file
or bump commit. Item 8 renames a directory of docs/metadata and writes no source
code. Frontmatter stamps (2, 4) go through `.claude/scripts/script-prd-stamp.sh`, the
one proven writer — never a hand-rolled re-emit of the file.

**Script resolution (stated once — every ref uses this form):** a repo copy first,
the global install second — `S=.claude/scripts/<name>; [ -f "$S" ] || S="$HOME/.claude/scripts/<name>"`.

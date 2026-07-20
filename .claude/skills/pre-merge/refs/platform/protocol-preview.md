---
name: preview
description: Gate Step 8 — preview deploy (human gate). Fires on the D6 path heuristic, produces the platform profile's preview_kind (url / artifact / screenshots), and BLOCKS on human approval. No trigger match → skipped and noted. Also carries the former qa (visual capture) component's protocol, folded in by C20 (reference only this phase — see the file body).
---

# Step 8 — PREVIEW DEPLOY (human gate)

A safety-floor human gate: when the diff touches material UI or backend surface, the
human must see and approve a preview before the PR opens. Never removed in any
profile; in `strict` it **always** fires (Step 0 `preview_always`).

## Trigger (D6 path heuristic)

Fires when the diff touches either surface:

- **UI-surface** (adapted from `/review`'s a11y trigger): `.tsx`/`.jsx`/`.vue`/`.svelte` files; any path under `/components/`, `/pages/`, `/views/`, `/screens/`; `.css`/`.scss`; Flutter `.dart` files with a `Widget` build method.
- **API / schema / migration**: paths under `/routes/`, `/controllers/`, `/handlers/`, `/api/`, `/server/`, `/services/`; `*.proto` / OpenAPI specs; any migration path (the Step 6 migration trigger set); ORM schema/model files.

`strict` profile → fires regardless (always). No trigger match (and not strict) →
**skip** the step and record it in the verdict (`preview: { fired: false }`). In
`lenient`, fire only on UI-surface (visual) paths.

## Produce the profile's preview_kind (D10)

For each platform in the Step 0 `preview_map`, produce its `preview_kind`:

| `preview_kind` | What pre-merge produces | Presented to the human |
|---|---|---|
| `url` (web) | run `preview_deploy_cmd` → a deployed link | the URL to open |
| `artifact` (iOS/Android/macOS) | run `preview_deploy_cmd` → an installable build (TestFlight / simulator / `.apk` / `.app`) | the build location + **what-to-poke-at notes** (the flows this diff changed) |
| `screenshots` (explicit opt-down) | drive the changed flows and capture **before/after** | the before/after captures |

A multi-platform run produces one preview per platform (a strict mobile platform
still gets its artifact even alongside a lenient web URL).

## Visual capture (merged from qa)

> **C20 note:** the former standalone `qa` (visual) component (`[15]`, retired —
> see `shared/refs/component-catalog.md`) is folded into this file as of the C3
> reorganization. Its content is transcribed below **for reference only** — it
> is not yet wired into this step's active trigger/approval flow in this phase;
> that integration (the full merged human-review gate, R1–R4) lands in Phase 6
> (C20/C21). Today's gate sequence and Step 5/Step 8 behavior are unchanged.

Guard, error rule, envelope: `../_common.md`. Runner (`qa_runner`: Playwright visual /
Chromatic / Percy / BackstopJS / Loki) from the Step 1 fingerprint.

**Baseline check.** Verify baselines exist before running: Playwright `.png`
snapshots; BackstopJS `backstop_data/bitmaps_reference/`; Loki `.loki/reference/`;
Chromatic/Percy are remote (assume present if configured). No local baseline and
not Chromatic/Percy → `pass_with_warnings`, note `"No visual baselines found — run
once in update mode."`

**Run + parse.** Execute `qa_runner.command`.

- Exit 0, no diffs (or below threshold) → `pass`.
- Non-zero with visual diffs → each diff is one finding, `severity: high` (`medium` if attribution/threshold uncertain).
- Runner crash/auth error → `pass_with_warnings`, note `"QA runner failed to start — results unreliable."`.

Finding fields: `rule` = story/snapshot name; `file` = spec/story that produced the
diff; `evidence.file` = diff-image path or report URL; `message` = e.g. `"23.4% pixel
difference exceeds 0.1% threshold"`. Totals: `{ passed, failed, skipped }`.

## Block on approval

`AskUserQuestion`: present the preview(s) and ask **Approve** / **Reject**.

- **Approve** → record `preview: { fired: true, approved: true, kind, artifact }` and proceed to Step 9.
- **Reject** → terminate with `verdict: "skipped"`, `reason: "preview_rejected"`; the PR is not opened. Note the human's reason if given.

This is the sole `AskUserQuestion` on the happy path (Step 1's sync-conflict pause is
conditional). Pre-merge never opens the PR without an approved preview when the gate
fired.

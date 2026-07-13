---
name: preview
description: Gate Step 8 — preview deploy (human gate). Fires on the D6 path heuristic, produces the platform profile's preview_kind (url / artifact / screenshots), and BLOCKS on human approval. No trigger match → skipped and noted.
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

## Block on approval

`AskUserQuestion`: present the preview(s) and ask **Approve** / **Reject**.

- **Approve** → record `preview: { fired: true, approved: true, kind, artifact }` and proceed to Step 9.
- **Reject** → terminate with `verdict: "skipped"`, `reason: "preview_rejected"`; the PR is not opened. Note the human's reason if given.

This is the sole `AskUserQuestion` on the happy path (Step 1's sync-conflict pause is
conditional). Pre-merge never opens the PR without an approved preview when the gate
fired.

---
name: eng-build-flash
description: eng --build --flash — one build agent for all rows (no per-platform fan-out), spec from the build digest slice, one injected cook, impl+tests together, single commit gate. Loaded instead of refs/build/protocol.md when --flash is active.
---

# eng --build --flash

Obeys `../../../../shared/refs/flash-floor.md`. Loaded **instead of** `refs/build/protocol.md`. The win is **no per-platform fan-out** (≤1 build agent regardless of platform count) — the input side is already slim via the B2 build slice.

## Inputs — the build digest slice, not the full PRD

Read this feature's spec from the PRD-digest **build slice**, not the full PRD prose and not todo tickets:

```bash
G=.claude/scripts/scan-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/scan-prd-digest.py"; python3 "$G" "<prd-path>" --slice build --feature <F-ID>
```

The slice returns this feature's acceptance criteria (verbatim), its exec-table rows, and its integration contracts. Escape hatch: read a `prose_lines` range only when the slice is insufficient — never default to the whole PRD.

## Execution

1. **One cook compile, injected once.** Derive flags from eng's concern-keyword table (T1.3), compile `/cook` **once** (flag-based, cacheable, P0-guaranteed), inject the payload into the single build agent's prompt. **Not** per-row, **not** a `cook --flash` (which doesn't exist).
2. **≤1 build agent for all rows** — no per-platform fan-out. Orchestrators forwarding `mode: flash` respect this (they spawn one, not one-per-platform).
3. **Impl + tests written together**; run the **unit + integration** suite **once** before commit (skip the verify-red pre-step). Heavier buckets (e2e / visual / perf / a11y / coverage) are pre-merge's job, never run in the build loop.
4. **Single commit gate** — fires once at the end (`kermit`-style), not per-row.
5. **Debug capped at 2 cycles** — if the suite is still red after 2 fix attempts, stop and write the failure ticket rather than looping.

## Safety floor — unchanged

Branch contract (`feat/prd-<n>-*`), scope enforcement, AHA.md / OPEN-QUESTIONS.md logging, DB-touch + breaking-change pauses, no push/merge — all identical to comprehensive (`flash-floor.md`). The unit + integration suite runs at least once before the commit gate fires.

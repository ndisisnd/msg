---
name: mode-resolution
description: How every msg skill resolves its run mode (comprehensive vs flash) from the per-run flag and the pref file. Referenced by each skill's one-line Step 0 so the algorithm lives in one place.
---

# mode resolution

Every user-facing msg skill resolves its mode **once**, at Step 0, with this precedence:

```
per-run flag  >  forwarded mode (orchestrated)  >  local pref  >  global pref  >  comprehensive
```

## Precedence, in order

1. **Per-run flag** — an explicit `--flash` or `--comprehensive` on this invocation wins, always, and is **not persisted**.
2. **Forwarded mode** — when an orchestrator spawned this skill and passed `mode: flash|comprehensive` in the prompt, honor it. A leaf skill invoked by an orchestrator **never re-reads the pref file** — the mode arrives via the flag/forward, preventing local/global drift mid-pipeline (see `flash-floor.md`).
3. **Local pref** — `.claude/msg/pref.json` → `{"mode": "comprehensive" | "flash"}` in the project root.
4. **Global pref** — `~/.claude/msg/pref.json`, same shape.
5. **Default** — `comprehensive`.

## Pref file

```json
{ "mode": "comprehensive" | "flash" }
```

- Location: `.claude/msg/pref.json` (local) or `~/.claude/msg/pref.json` (global). It sits **beside** `cache/` and is **not** gitignored (only `.claude/msg/cache/` is) — the pref is user-created (see `/msg --set-mode`), never installed.
- **Missing, unreadable, unparseable, or an unknown `mode` value → silently resolve `comprehensive`.** Never a hard failure, never a prompt.

## Applying the resolved mode

Once resolved: `flash` → load the skill's `refs/flash.md` (or its documented flash path) instead of the comprehensive refs; `comprehensive` → the normal protocol. This is the same routing each skill's `--flash` handling already performs — mode resolution only decides *which* value feeds it.

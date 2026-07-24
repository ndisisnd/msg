---
name: Execution-mode preference
description: The persisted team/solo execution-mode preference for the planning pipeline — path resolution, schema, seeding by /msg --init/--update, and read + flag-override precedence (plan-em). Mirrors the wdym pref mechanism.
type: reference
---

# Execution-mode preference

The planning pipeline's **team vs solo** execution mode (see `plan-em`
`refs/protocol-team.md`) is persisted in a small JSON pref file so the choice survives
across runs instead of being re-decided every invocation. **`/msg --init` seeds** it at
project bootstrap (and `/msg --update` tops it up on repos bootstrapped before it existed);
`plan-em` **reads** it and lets an inline flag override + re-persist. This file is the
single source of truth for both — mirrors the `wdym` pref mechanism (`.claude/wdym/pref.json`).

## File location & precedence

Resolve in this order — **local overrides global**:

1. **Local (project):** `$CLAUDE_PROJECT_DIR/.claude/msg/pref.json` (fall back to
   `./.claude/msg/pref.json` when `$CLAUDE_PROJECT_DIR` is unset).
2. **Global (user):** `~/.claude/msg/pref.json`.

All writes target the **resolved** path: if a local file exists (or the project dir is
present), write local; otherwise write global. A local file always wins a read.

## Schema

```json
{ "exec_mode": "team" }
```

| Key | Values | Meaning |
|-----|--------|---------|
| `exec_mode` | `"team"` (default) / `"solo"` | The `plan-em` dispatch lane (`refs/protocol-em.md` Step 0). `team` = Opus orchestrator engineer fans out file-disjoint, model-tiered packets; `solo` = one leaf per roster stack. |

Unknown keys are ignored; a missing/unparseable file resolves as **absent** (see below).
Do not add other keys here without updating this ref — keep the store single-purpose.

## Initialisation (`/msg --init` and `/msg --update`)

The pref is a **first-class init component**, seeded exactly like `devkit/policy.json` and
the other scaffold files — no separate first-run hook in a planning skill:

- **`init-setup.sh`** lists `.claude/msg/pref.json` in `TARGETS`, so it counts toward
  `ALL_COMPLETE` and is reported as `MISSING` on a repo bootstrapped before it existed.
- **`init.sh`** writes it when absent (deterministic, no interview input) with the default
  `{"exec_mode": "team"}`, tracked in the manifest as `created`/`skipped (exists)`.
- **`/msg --init`** creates it at bootstrap; **`/msg --update`** tops it up on older repos
  via the same `MISSING` → `init.sh` path. Never overwritten — an existing pref is a no-op.

It is a silent default (`team`, the pipeline default) — never a prompt; the user flips it
anytime via `plan-em --solo`/`--team`, which re-persists. The `init.sh` write:

```bash
if [[ -e "$TARGET/.claude/msg/pref.json" ]]; then
  SKIPPED+=(".claude/msg/pref.json")
elif mkdir -p "$TARGET/.claude/msg" && printf '%s\n' '{"exec_mode": "team"}' > "$TARGET/.claude/msg/pref.json"; then
  CREATED+=(".claude/msg/pref.json|1")
fi
```

## Read + flag-override precedence (plan-em)

`plan-em` Step 0 resolves `$TEAM_MODE` in this order:

1. **Inline flag wins.** `--solo` / `--team` in the invocation → set `$TEAM_MODE` to it,
   **persist** `{"exec_mode": "<target>"}` to the resolved path (create the dir if needed),
   strip the flag, and emit `Execution mode: <target> (persisted).` (Both flags at once →
   hard failure `Pass at most one of --team / --solo.`)
2. **Else read the pref file** (local, then global) → `exec_mode` → `$TEAM_MODE`.
3. **Else default `team`.** Do **not** create the file here — only `/msg --init`/`--update`
   seeds it when absent (mirrors wdym, where only `--init` seeds the pref).

```bash
# plan-em Step 0: resolve $TEAM_MODE from pref (no inline flag branch shown)
PD="${CLAUDE_PROJECT_DIR:-.}"; L="$PD/.claude/msg/pref.json"; G="$HOME/.claude/msg/pref.json"
F="$L"; [ -f "$L" ] || F="$G"
TEAM_MODE=team
[ -f "$F" ] && TEAM_MODE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("exec_mode","team"))' "$F" 2>/dev/null || echo team)"
```

## Consumers

- `msg --init` / `--update` — `refs/init/init-setup.sh` (`TARGETS`) + `refs/init/init.sh`
  (write): seeds the pref as an init component (above).
- `plan-em` — `refs/protocol-em.md` Step 0: read + flag-override + persist (above); consumed
  at Step 4 as the dispatch lane.

---
name: env-contract
description: The contract for devkit/ENV.md — the human-authored env-setup doc holding one fenced machine-readable block (provision/seed/reset/teardown, optional stacks[] and scale_factor) that the gates read to stand up the ephemeral test-sandbox. Replaces policy.json's env_provision field.
type: reference
---

# `devkit/ENV.md` — the env-setup contract

One lightweight file answering **"how do I stand up a test environment for *this*
codebase"** — for `pre-merge`, for any agent, and for a human. It is **committed docs**,
not runtime state: it belongs in git next to `PLATFORMS.md`, and it is not gitignored.

**Two halves in one file:**

- **Prose** (the majority) — prerequisites, ports, where the seed fixture lives, known
  gotchas. Written for a human onboarding on a Monday. Nothing parses it.
- **One fenced `env` block** — the four verbs a gate runs, plus optional `stacks[]` and
  `scale_factor`. Machine-read, exactly once per file.

## Why it is not a `policy.json` field

`env_provision` used to live in `policy.json`. Two problems: the same commands ended up
duplicated wherever the team documented setup (a drift pair), and the JSON field had
nowhere to put the prose that makes setup actually reproducible — the ports, the "you must
run `docker login` first", the fixture's location.

`ENV.md` follows the **`PLATFORMS.md` precedent**: a human-curated devkit doc is the
authored source; the gates are **pure readers**. One source of truth, and the half a human
needs lives beside the half a machine needs.

## Writers and readers

| Actor | Does |
|---|---|
| `pre-merge --init` | **scaffolds** it — detects the provisioner and fills what it can; writes `[USER: …]` placeholders where detection failed |
| `pre-merge --update` | **re-detects and proposes deltas** (a compose file appeared, a seed script moved) under the normal approved-delta write |
| `pre-merge` gate run | **reads only** (executor §3b). Never writes — the Fork E pattern |
| `post-merge` | **reads only** — the same fenced block, same shape (schema shared, machinery not) |
| a human / `eng` debug session | reads the prose half, edits either half freely |

The file is **hand-editable and hand-edits win**: `--update` proposes, it never silently
overwrites a human's command.

## The fenced block

Exactly one fenced block labelled `env` per file. JSON inside the fence.

````markdown
```env
{
  "provisioner": "docker-compose",
  "provision": "docker compose -f docker-compose.test.yml up -d --wait",
  "seed": "npm run db:migrate && npm run db:seed",
  "reset": "npm run db:reset && npm run db:seed",
  "teardown": "docker compose -f docker-compose.test.yml down -v",
  "seed_script": "scripts/seed-test.ts",
  "scale_factor": null
}
```
````

| Field | Type | Notes |
|---|---|---|
| `provisioner` | enum `docker-compose`\|`testcontainers`\|`db-branch`\|`preview-deploy`\|`simulator`\|`none` | the detected/declared mechanism; `none` = no provisioner — env-needing components degrade **loudly** at gate time (AC-SBX6), never a silent pass |
| `provision` | string \| null | stand up the isolated stack (own DB/state/ports) |
| `seed` | string \| null | migrate-from-zero + apply the committed seed fixture (S-Q1: never a prod-like snapshot) |
| `reset` | string \| null | cheap data-only reset between fix-loop iterations (S-Q2: drop → remigrate → re-seed; stack stays warm) |
| `teardown` | string \| null | full teardown — run after **every** gate run, pass or fail (AC-SBX4) |
| `seed_script` | string \| null | the committed seed script; absent while a provisioner exists ⇒ loud D28-style note at gate time, never a silent empty-DB run |
| `scale_factor` | number \| null | optional generated-dataset multiplier for `perf`/`load` realism (S-Q1) — produced by the seed script, never a snapshot |
| `stacks[]` | object[] | optional — composite environments, below |

### Composite environments — `stacks[]`

A full-stack-mobile repo needs two provisioners at once (a `simulator` for the app **and**
a `docker-compose` backend it talks to). The block may therefore carry a `stacks[]` array;
each entry is one `{provisioner, provision, seed, reset, teardown, …}` object in the shape
above:

````markdown
```env
{
  "stacks": [
    { "provisioner": "docker-compose", "provision": "docker compose -f dc.test.yml up -d --wait", "seed": "…", "reset": "…", "teardown": "docker compose -f dc.test.yml down -v" },
    { "provisioner": "simulator", "provision": "xcrun simctl boot test-sbx && install <build>", "seed": null, "reset": "xcrun simctl erase test-sbx", "teardown": "xcrun simctl shutdown test-sbx" }
  ]
}
```
````

- The **flat shape stays valid** as the single-stack case — `stacks[]` is never required,
  and readers MUST treat a flat object as `stacks: [<that object>]`.
- The stacks are **one logical sandbox** (AC-SBX2/SBX5): the executor provisions all stacks
  together, runs the env wave against the composite, promotes the composite to preview, and
  tears **all** stacks down together — never partially.
- A verb null on one stack (a simulator has no `seed`) is valid; the loud seed-script rule
  applies per-stack only where a DB exists.

## Resolution — how a reader resolves the file

Fail-safe throughout; **absence is never a validation error, and never a silent pass.**

| File state | Resolves to | Gate behavior |
|---|---|---|
| present, block parses, verbs filled | the block | normal C23 sandbox lifecycle (`pre-merge/refs/executor.md` §3b) |
| present, **any consumed verb is a `[USER: …]` placeholder** | `provisioner: "none"` | the loud `sandbox-unprovisioned` degrade, naming the placeholder line to fill |
| present, `provisioner: "none"` | `none` | the loud degrade |
| present, **no `env` fence** or the fence is unparseable JSON | `none` | the loud degrade + one line naming the malformed file |
| **absent** | `none` | the loud degrade + a line naming `/pre-merge --init` |

The **loud degrade** is unchanged from the pre-`ENV.md` behaviour (AC-SBX6, the D28
safety-floor pattern), defined once in `pre-merge/refs/executor.md` §3b:

- **Non-destructive** env-needing checks run against the **ambient** environment, each
  carrying a `high` finding (`rule: sandbox-unprovisioned`, `source: pre-merge:executor`).
- **Destructive** checks (the migration up→down→up round-trip) are **skipped-with-note** —
  never run against shared state.
- A provisioner **without** a `seed_script` runs the sandbox but flags the same loud note
  for seed-dependent realism (`load`/`perf`/`integration` against an empty DB).

## Placeholders

`[USER: …]` is the same convention `PLATFORMS.md` uses: a scaffold writes it wherever
detection could not resolve a value, the text says exactly what to put there, and a
consumer treats it as **unresolved**, never as a literal command. A placeholder in a verb
the run does not consume (e.g. `reset` on a run with no fix loop) is inert.

## Companion stubs

`--init` may offer, under the usual per-item approval, the optional starter files in
`pre-merge/refs/stubs/`: `docker-compose.test.yml` and `seed-test.ts` / `seed-test.py`.
Accepting them fills the corresponding verbs in `ENV.md` so the pairing is runnable
immediately; declining leaves `[USER: …]` placeholders.

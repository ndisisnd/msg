---
name: ENV Template
description: Template for devkit/ENV.md — the env-setup contract. Human prose (prerequisites, ports, seed fixture, gotchas) around one fenced env block carrying the provision/seed/reset/teardown verbs both gates read. Committed, never gitignored.
type: reference
---

# ENV — how to stand up a test environment

How this codebase gets a working, isolated environment to test against. Written
for three readers: a human onboarding, an agent debugging, and `/pre-merge`,
which stands the sandbox up on every gate run and tears it down afterward.

**This file is committed.** It is documentation, and the gates read it — they
never write it. Edit it freely; `/pre-merge --update` proposes changes when the
codebase moves (a compose file appears, a seed script relocates) and never
silently overwrites a hand-written command. `[USER: …]` marks a value nobody has
resolved yet — a gate treats it as *unprovisioned* and says so loudly rather than
guessing. Contract: `shared/refs/env-contract.md`.

## Prerequisites

- [USER: what must be installed before any of this works — e.g. Docker Desktop
  running, Node 20+, a `pnpm install` already done]
- [USER: any credential or login step — e.g. `docker login ghcr.io`, a `.env.test`
  copied from your secret manager. Never commit the secret itself.]

## Ports

The sandbox deliberately avoids default ports so a gate run never collides with a
developer's local stack.

| Service | Port | Notes |
|---|---|---|
| [USER: db] | [USER: 55432] | [USER: postgres in the test compose stack] |

## Seed fixture

- **Where it lives:** [USER: e.g. `scripts/seed-test.ts`]
- **What it contains:** [USER: the handful of named fixtures tests assert on]
- **Rule:** migrate from zero, then seed. Never restore a production-like
  snapshot — it drags real data into a sandbox and rots the moment the schema
  moves.

## Gotchas

- [USER: the thing that wastes an hour the first time — a migration needing an
  extension installed, a simulator that must be booted once by hand, a flaky
  first-run timeout]

## The verbs

The fenced block below is the machine-readable half — the only part a gate parses.
Exactly one `env` block per file.

```env
{
  "provisioner": "none",
  "provision": null,
  "seed": null,
  "reset": null,
  "teardown": null,
  "seed_script": null,
  "scale_factor": null
}
```

| Verb | When it runs |
|---|---|
| `provision` | once per gate run, **only after** the static correctness checks are green |
| `seed` | immediately after `provision` — migrate from zero, then apply the fixture |
| `reset` | between fix-loop iterations — drop, remigrate, re-seed; the stack stays warm |
| `teardown` | after **every** run, pass or fail |

`provisioner: "none"` (the scaffolded default) is valid and honest: it means nobody
has declared how this project stands an environment up. Every environment-needing
check then runs against whatever is ambient and carries a loud
`sandbox-unprovisioned` finding — never a silent pass. Run `/pre-merge --init` to
detect and fill this in, or write the verbs by hand.

**Composite environments.** A repo needing two provisioners at once (a simulator
for the app *and* a compose backend it talks to) replaces the flat object with a
`stacks[]` array of the same shape. It is still **one** logical sandbox: all
stacks are provisioned together and torn down together, never partially.

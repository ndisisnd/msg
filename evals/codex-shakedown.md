# Codex shakedown — the part of v6 no Claude session can verify

Everything in `evals/cases/` runs anywhere. This file is the remainder: the claims
about msg's Codex leg that can only be settled by a real OpenAI Codex CLI session
driving a real binary.

**Why this file exists as a document rather than a case.** The v6 dual-harness work
was designed and built from Claude Code. The bindings in
`.claude/skills/shared/refs/harness-map.md` — `Agent` → `spawn_agent`, the role
TOMLs standing in for model tiers, `max_depth = 2` for nested gate dispatch — are
*specified*, and specification is not evidence. Shipping a release that claims a
working Codex leg without ever having run one would be the single dishonest thing
in this port, so the claims are written down here as tests instead of as prose.

**Who runs it.** An agent, inside a Codex CLI session, with this repo checked out.
Every item is written so the agent can execute it and decide PASS / FAIL / BLOCKED
from what it observes, without asking a human to interpret anything — except items
explicitly marked ⚑, which need a human at the keyboard because they test whether
the run *stops and waits for a human*.

---

## Before you start

**Read `.claude/skills/shared/refs/harness-map.md` first.** It is the dictionary for
everything below. If any binding in it turns out to be wrong, that is a result, not
an obstacle — record it.

### Safety rules, non-negotiable

1. **Never run `install.sh` against your real `$HOME`.** Every installer invocation
   in this plan uses a throwaway `HOME` under a scratch directory. An installer run
   against the real home rewrites the developer's live msg install.
2. **Never run the destructive items in this repo.** Items that commit, merge, or
   scaffold run in a sandbox project created by step 0. This repo is the thing being
   tested; it is not the test fixture.
3. **Do not "fix" a failure in place.** A failing item is the deliverable. Record it
   and move on — someone will decide whether it changes the design or the fallback.
4. **Never grant hook trust on the developer's behalf outside the sandbox.** Item 2
   is *about* the trust prompt; approving trust globally to make it pass destroys
   what it measures.

### Step 0 — sandbox setup

```bash
export SHAKEDOWN="${TMPDIR:-/tmp}/msg-codex-shakedown-$(date +%s)"
mkdir -p "$SHAKEDOWN/home" "$SHAKEDOWN/project"
export FAKE_HOME="$SHAKEDOWN/home"

# Install msg into the throwaway home, with the Codex lane.
HOME="$FAKE_HOME" bash /path/to/msg/install.sh --codex

HOME="$FAKE_HOME" ls -l "$FAKE_HOME/.agents/skills"   # expect nine symlinks
```

Record `SHAKEDOWN` in your results — every later item refers back to it.

### Recording results

Append to `update/codex-shakedown-results.md` (gitignored scratch; copy the parts
worth keeping into the plan doc afterwards). One block per item:

```
## <item id> — PASS | FAIL | BLOCKED
Observed: <what actually happened, in enough detail that someone who was not there
          can tell it apart from what was expected>
Evidence: <command output, verbatim, trimmed to the load-bearing lines>
Action:   <none | fallback engaged | design change needed — which>
```

`BLOCKED` is a legitimate outcome. An item you could not run is not an item that
passed, and reporting it as one is the only way this document can do real damage.

---

## Part A — Spikes (S1–S4)

These feed commit **C11**. Each one either confirms a default the design already
assumes, in which case C11 is skipped entirely, or forces a fallback that is already
written down. None of them should require inventing something new.

### S1 — Does Codex tolerate msg's frontmatter? *(feeds assertion A13)*

**The claim.** msg's `SKILL.md` files carry Claude-flavoured frontmatter keys
(`argument-hint`, `allowed_tools`, `model`) that the open agent-skills standard does
not define. The design assumes Codex ignores unknown keys rather than rejecting the
file. If it rejects them, every skill fails to load and the whole leg is dead — this
is the highest-consequence spike in the set.

**Run.**

```bash
HOME="$FAKE_HOME" codex          # start an interactive session
```

Then in-session: `/skills`, and invoke `$msg --version`.

**PASS if** all nine skills appear in `/skills`, and `$msg --version` prints the
version stamp. **FAIL if** any skill is missing, or the loader warns/errors on
frontmatter.

**Second half of S1: the `shared/` directory.** `shared/` holds refs and has no
`SKILL.md`. The installer's Codex lane already excludes it (design decision D2), so
this only settles whether that exclusion is *mandatory* or merely tidy. Create a
symlink for it by hand and restart the session:

```bash
ln -s "$FAKE_HOME/.claude/skills/shared" "$FAKE_HOME/.agents/skills/shared"
```

Record whether the scanner warns, errors, or silently skips. Then **remove the
symlink again** — it is not part of the shipped shape.

**On FAIL:** the frontmatter keys have to be stripped or moved into
`agents/openai.yaml`. That is a real design change and blocks the release; say so
loudly rather than working around it.

### S2 — Does depth-2 nesting work? *(feeds A14 and decision D6)*

**The claim.** msg's gate dispatch nests one level deeper than Codex allows out of
the box: a dispatcher spawns a gate run, which spawns a component wave. `/msg --init`
therefore emits `.codex/config.toml` carrying `[agents] max_depth = 2`.

**Run.** In the sandbox project (step 0), confirm the config is present, then drive
a nested spawn — the honest version is a real `$pre-merge` run, but a synthetic
two-level `spawn_agent` chain settles the mechanism just as well and is faster.

**PASS if** the grandchild spawn is permitted and returns its result to the parent.
**FAIL if** it is refused at depth 2.

**On FAIL, the fallback is already designed:** gates run inline on the Codex leg
instead of dispatching. What matters then is that the inline path produces
**identical verdict JSON** — compare it byte-for-byte against a Claude-side run of
the same gate. If the JSON matches, engage the fallback in `harness-map.md` (C11)
and the release proceeds. If it does not match, that is a blocking finding.

### S3 — Can a spawn target a role by name? *(feeds D6)*

**The claim.** msg's protocols say `model: opus` and `model: sonnet`. The map binds
those to the roles `msg-lead` and `msg-leaf` in `.codex/agents/`, because Codex's
per-spawn model override has been reported unreliable. This assumes a spawn can
*name* a role.

**The specific doubt.** Codex's own documentation says custom agents are delegated
explicitly and never auto-spawned. "Explicitly delegated" is probably exactly what
msg does — but "probably" is why this is a spike.

**Run.** From a Codex session in the sandbox project, spawn a child targeting
`msg-leaf`, and have the child report which role and reasoning-effort setting it is
running under.

**PASS if** the child confirms it is running as `msg-leaf`. **FAIL if** the role is
ignored, or naming it is an error.

**On FAIL:** the model-tier row in `harness-map.md` needs rewriting — the tiers would
have to be conveyed as prose instructions inside the packet rather than as a role
binding. Degraded but not fatal, since the roles set reasoning effort rather than
pinning a model.

### S4 — Does mid-run skill chaining work? *(feeds the `Skill(` row in D3)*

**The claim.** Where a protocol chains into another skill, the map says: open that
skill's `SKILL.md` and execute it inline, carrying current state. This assumes the
sandbox lets an agent read a sibling skill file mid-run and that the skill loader
does not interfere.

**Run.** In a Codex session, invoke `$plan-pm` (or any skill whose protocol chains),
and at the chain point have the agent read
`~/.agents/skills/plan-review/SKILL.md` and follow it inline.

**PASS if** the file reads cleanly and the run continues in the same session with
its state intact. **FAIL if** the sandbox denies the read, or the loader hijacks it
into a fresh skill invocation that loses state.

**On FAIL:** chaining becomes "tell the user to invoke `$next` themselves", which
breaks pipeline continuity and is worth a design conversation before release.

---

## Part B — Live shakedown (release-blocking)

Six items. All six must pass — or fail with an engaged, verified fallback — before
`/kermit --release` runs. This is gate **AC4.3**.

### B1 — Skills load and one runs end-to-end

`/skills` lists all nine. `$msg --version` reads the stamp. `$intake` captures and
grades a row from start to finish in the sandbox project.

**PASS if** the graded row lands in `INTAKE.md` with the same shape a Claude run
produces. This is the item that proves the leg exists at all; everything else
refines it.

### B2 — The commit gate is trusted, and then it bites

The single most important item in this file, because its failure mode is silent.

1. First Bash call in the sandbox project surfaces the changelog-gate trust prompt.
   **Record whether it appears at all** — if trust is never requested, the gate is
   silently off and a release can ship with no changelog entry.
2. Grant trust.
3. Confirm `CHANGELOG.md` is **not** staged: `git status --short`.
4. Attempt a commit with no changelog entry.

**PASS if** the commit is denied *and the denial states the reason* — the reason is
the mechanism, because it tells the agent how to unblock.

**The false negative that invalidates this item:** if `CHANGELOG.md` is already
staged, a live gate allows the commit too, and a dead gate is indistinguishable.
Step 3 is not optional. If you skipped it, the result is BLOCKED, not PASS.

5. Then edit `.codex/hooks.json` trivially and retry. Codex trust is per content
   hash, so trust should now be **revoked** and the gate silent again. Confirm that,
   because it is the behaviour that makes `/msg --init` refuse to overwrite an
   existing `hooks.json`.

### B3 ⚑ — Human gates still block *(needs a human at the keyboard)*

The map renders `AskUserQuestion` as numbered prose. The whole safety floor rests on
prose blocking exactly as hard as the tool does.

Drive `$plan-em` to a resume question.

**PASS if** the options appear numbered, in the same order and wording as the Claude
rendering, **and the run stops and waits.** Sit on your hands for a full minute.

**FAIL — and this is release-blocking with no fallback — if** the run answers its
own question, picks a default, or continues on silence. A human gate that does not
block is not a gate.

### B4 — The spike-backed orchestration actually orchestrates

Depends on S2 and S3. Run one real `$plan-em --team` wave through `spawn_agent` and
the role TOMLs, and one `$pre-merge` under depth-2 nesting.

**PASS if** the wave fans out, children return, and the parent synthesises — or, if
S2 failed, the inline fallback produces verdict JSON identical to the Claude-side
run.

### B5 — Implicit invocation stays off

Type a prompt that *describes* merging a branch — plain English, no `$`.

**PASS if** nothing fires. **FAIL if** `$merge` activates. This is the negative test
protecting the design's one deliberate safety-over-convenience choice, and the
failure is exactly the scenario it was chosen to prevent: a release deployed because
a sentence sounded like a description.

### B6 — The Claude leg is untouched

Not a Codex item, but it belongs to the same gate. In a normal Claude Code session,
run `/msg`, `/intake`, and one fused `plan-em` wave.

**PASS if** outputs match v5.6.5 expectations. The mechanical half of this is already
covered by the 140-case suite and the A8 diff allowlist; this item covers what a
diff cannot see — whether the thing still *feels* the same to use.

---

## Part C — Things known to be guesses

Not tests so much as flagged uncertainties. Confirm each while you have a live binary
in front of you, because each is currently an educated guess written into shipped code.

| Guess | Where it lives | How to check |
|---|---|---|
| `codex exec --full-auto {prompt}` is the right runner for a detached job that must write files | `msg/refs/gui/server.py`, behind `--runner-codex` | Run it. A bare `codex exec` defaults to a read-only sandbox, which would exit 0 and silently fail every edit — the worst failure shape. Confirm `--full-auto` is the actual flag spelling and that it permits writes. |
| `env \| grep -q '^CODEX_'` identifies a Codex session | `harness-map.md`, harness self-detection tie-break | `env \| grep '^CODEX_'` in a live session. Record the actual variable names. |
| `$name` is the durable invocation sigil | everywhere in the docs | Confirmed by B1 — but note whether `/skills` picker and `$name` behave identically. |
| Codex reads root `AGENTS.md` before every task | D9, the whole memory-file design | Put a distinctive instruction in the sandbox project's `AGENTS.md` and see whether a fresh task honours it without being pointed at the file. |

---

## Exit

The release gate (`AC4.3`) is: **A1–A12 green from the eval suite, S1–S4 recorded,
B1–B6 pass or fall back with the fallback verified.** A13 and A14 are the two
assertions that can only be discharged from here.

When all of that holds, `/kermit --release` runs from a **Claude** session — the
release path itself is not part of what this document tests.

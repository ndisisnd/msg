# Acceptance Criteria — 9-agent-creation-option

## Change 1 — "Create a new agent" option in Step 1

1. When `/improve` is invoked with no arguments, the `AskUserQuestion` options array contains exactly an option labelled "Create a new agent" (or equivalent wording) alongside the existing improvement-intent options.
2. Selecting "Create a new agent" does NOT proceed into the normal improvement clarification questions (gap / stakes / constraints) without first routing through the agent-routing sub-step.

## Change 2 — Agent-routing sub-step (Step 1b)

3. After "Create a new agent" is selected, a follow-up `AskUserQuestion` is called with two options: one that invokes `/agent-plan` and exits, and one that continues inline in `/improve`.
4. Selecting the `/agent-plan` option causes the skill to invoke the `agent-plan` skill and terminate the current `/improve` flow (no further /improve steps run).
5. Selecting the "lightweight" option continues into agent-specific clarifying questions without invoking any external skill.

## Change 3 — Lightweight inline agent-creation path

6. The lightweight path asks at least one clarifying question about agent name and purpose before writing any files.
7. The lightweight path asks no more than 5 clarifying questions total (same cap as the existing improve clarification flow).
8. The questions cover at minimum: name + purpose, trigger/invocation conditions, and required tools.
9. The output directory slug uses the pattern `create-<agent-name>` (e.g. `improve/9-create-my-agent/`).
10. The lightweight path produces a `plan.md` and an `acceptance.md` in the output directory using the same template as every other improve plan.
11. The lightweight plan.md is readable as a standalone brief that could be passed directly to `/agent-build`.

## Change 4 — Updated usage line in SKILL.md

12. The SKILL.md `## Usage` section documents all three no-arg intents: improve existing, create agent via /agent-plan, create agent lightweight.
13. The existing "Refuses without a description" language is preserved or updated — it must still be clear that a bare `/improve` with no args prompts the user rather than erroring silently.

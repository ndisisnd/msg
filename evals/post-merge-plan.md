# Post-Merge Plan — Issues and Decisions

**Date**: 2026-05-30
**Topic**: Should `msg` get a `post-merge` skill, and if so, what should it be?
**Method**: A product / design / engineering / QA / lifecycle team reviewed the idea. Five expert lenses read the real repo, then a "completeness critic" and a "skeptic" challenged them. This plan lists every issue they found, in plain English.

---

## The short version (read this first)

The idea behind `post-merge` is real: after code is merged into `main`, **nothing in `msg` checks that `main` actually still works**. `pre-merge` only ever looks at a branch compared to its base. It can never see the merged result, because that result does not exist until the merge happens. So there is a genuine hole.

**But the team says: do NOT build a brand-new skill for this.** Instead, add a **mode to `pre-merge`** called `--merge-delta`. Three reasons:

1. **The common case already works today.** If your team squashes PRs into one commit (the normal GitHub default), you can already run `pre-merge --base HEAD~1` right now, with zero new code, and it does the right thing. About 70% of the "gap" is just a missing default and a missing line of docs.
2. **The genuinely new part is small.** Only true merge commits (with two parents) and multi-commit merges need new diff logic. That is a small add-on to `pre-merge`, not a 14th top-level skill.
3. **Two of the headline features were imaginary.** "Carry the accepted risk from pre-merge" relies on data that does not exist. "Arm a monitoring watcher" cannot be built with the tools the skill is allowed to use. Both need to be cut or redesigned.

**Decision: fold it into `pre-merge` as a `--merge-delta` mode.**

---

## Why the idea is worth doing at all

- `pre-merge` only compares `branch` vs `base` and refuses to run on an empty diff (`pre-merge/SKILL.md:74-79`). It can never see the merged trunk.
- `pre-merge` refuses to merge, push, or deploy (`pre-merge/SKILL.md:35, :66`). So nothing owns the moment *after* merge.
- The happy path in `msg/SKILL.md:46-51` simply stops at `gh pr create`. There is no next step.
- **Important**: this repo has **no CI** (no `.github/workflows`, and `msg-init` does not create any). So you cannot say "CI on main already checks this." Nothing checks it. That is what makes the gap real here.

---

## The must-fix issues

These are the issues that, if ignored, make the feature wrong or harmful.

### 1. The diff range `HEAD~1..HEAD` is wrong for most real merges
- **What's wrong**: The original idea was to look at `HEAD~1..HEAD`. That is only correct for a squash (one commit) or a single-commit fast-forward. For a real merge commit (two parents), `HEAD~1` is only the first parent, so it **misses the conflict-resolution edits the merge itself made** — the exact thing you want to check. For a multi-commit merge it silently drops all but the last commit.
- **Why it matters**: You would check the wrong code and report "all good" on a trunk that is actually broken.
- **What to do**: Detect the merge type by counting parents (`git rev-list --parents -n1 HEAD`). Then pick the range: squash → `HEAD~1..HEAD`; multi-commit/rebase → `ORIG_HEAD..HEAD`; true merge → `git show -m` (combined diff so conflict edits are included). Print which strategy and range were chosen, so the result can be audited.
- **Where**: new logic; `pre-merge/scripts/resolve-diff.sh` cannot do this today (`:9, :15, :18`).

### 2. The test rules silently hide the exact failure this feature exists to catch
- **What's wrong**: `test/SKILL.md:156` says an unreachable target, missing service, or auth failure becomes `pass_with_warnings` — never `fail`. On a fresh trunk, "unreachable service / DB" is the **most common** real integration break (two PRs each set up their own fixtures, now they collide). So if the new mode reuses these rules, it reports a warning on a trunk that is genuinely broken.
- **Why it matters**: The whole point is to catch trunk breaks. This rule throws them away.
- **What to do**: Invert the rule for this mode. On trunk, an unreachable target during integration is a **blocker** or an `env_not_provisioned` refusal — not a warning. Add a setup step before the integration test that applies pending migrations and boots needed services (e.g. via a detected `docker-compose`).

### 3. The common case already works with no new code
- **What's wrong**: `pre-merge --base HEAD~1` already runs today (`pre-merge/SKILL.md:27, :43`; `resolve-diff.sh:9` accepts any ref). For a squashed merge it gives exactly the right delta. No other lens tested this before calling the gap "structural."
- **Why it matters**: Building a whole new skill for something that is mostly a one-line doc note is wasted effort and adds permanent maintenance.
- **What to do**: First, **run the experiment**: try `pre-merge --base HEAD~1` after a real merge. If your team squashes, a default tweak plus a doc note may be 70% of the fix. Build the new `--merge-delta` logic only for the merge-commit and multi-commit cases.

### 4. A red result after merge is a dead end with no way out
- **What's wrong**: `pre-merge`'s read-only stance is correct *before* merge ("you decide, then you push"). After merge, the code is already on `main`. If the check fails, the user gets "trunk is red" plus a skill that is forbidden to revert, push, or fix anything. The refusal text even says "use `gh pr create` yourself," which makes no sense after a merge.
- **Why it matters**: This is the single most important moment for this feature, and right now it hands the user a wall.
- **What to do**: Design a recovery step. When trunk is red, offer clear next actions (revert / hotfix branch / open an incident) via a single question, instead of inheriting `pre-merge`'s before-merge refusal text.

---

## The important issues

These won't break the core, but each one needs a decision or it leaks into user confusion.

### 5. "Carry the accepted risk from pre-merge" is based on data that does not exist
- **What's wrong**: The plan said the merge record would carry forward the risk a human accepted at the `pre-merge` gate. But `pre-merge` is stateless (`SKILL.md:18`) and there is **no `accepted_risk` field anywhere** in its output schema. The phrase only appears in persona prose (`SKILL.md:62`). Found by almost every lens.
- **What to do**: Pick one. Either (a) add an `accepted_risk` field to `pre-merge`'s output schema and fill it at the human gate, then read it later; or (b) **drop the claim** and make v1 honest. Dropping it is the fastest path to something shippable.

### 6. Re-running e2e / security / bundle just repeats pre-merge, slower
- **What's wrong**: `pre-merge` already runs integration, e2e, build, security, bundle (`SKILL.md:103`). Of these, only integration and build can flip from green to red purely because of a merge. Security and bundle depend on file content, which a merge does not change. Secret scanning already runs in `review` Stage 0 **and** `pre-merge` — re-running it would be the third time.
- **What to do**: Pin the default set to **integration + build + fast unit/typecheck only**. Make e2e opt-in. Explicitly exclude security, bundle, load, a11y, perf, visual, mobile — and write down *why*, so a reviewer doesn't "helpfully" add them back.

### 7. The merge can land another commit while the check is running
- **What's wrong**: The check reads `HEAD`, then spends 30–90 seconds running tests. On a busy trunk, another PR can merge during that window. Now `HEAD` is a different commit than the one being checked, and any marker or baseline points at the wrong commit. Attribution — knowing *which* merge caused a problem — is the whole value, and it breaks here.
- **What to do**: Capture the commit once at the start (`git rev-parse HEAD`), tie everything to that frozen commit, and re-check at the end that `HEAD` hasn't moved. If it moved, return an "inconclusive — trunk advanced" result instead of a confident pass.

### 8. False alarms are worse than misses here
- **What's wrong**: Every lens worried about *missing* a break. But for an after-merge check, a **false alarm is worse**. A false "trunk is red" on code that already shipped triggers needless rollback panic, and after two or three false alarms people just ignore the result — which quietly kills the feature.
- **What to do**: Make **precision** the goal, not coverage. Retry a failing test a few times before calling it a blocker. Treat flaky / network / transient failures as "inconclusive," not "fail." Write this into the skill as its main success measure.

### 9. There is no flaky-test handling to lean on
- **What's wrong**: `/test` has no flake handling at all. The only flake logic in the whole repo is in `pre-merge`'s e2e bucket (`bucket-runners.md:58`). Trunk, with shared infra and races between just-landed PRs, is the flakiest place to run.
- **What to do**: Add a retry-then-quarantine policy before this mode can grade anything. Reuse and extend the existing e2e flake marker.

### 10. It can't tell "newly broken" from "already broken"
- **What's wrong**: The unique value is attribution: did *this* merge break trunk, or was trunk already red from an earlier PR? But `/test` has no way to read a prior run (`test/refs/schema.md` has no prior-issues or regression field). Only `pre-merge` has it (`--prior-issues` → `regression_of`).
- **What to do**: Make the mode **require** the previous `pre-merge` (or previous trunk) result as input, and mark each finding as new-vs-existing. This is mandatory, not optional.

### 11. Migration and service setup is the #1 real cause and nobody handled it
- **What's wrong**: The plan listed three failure types (stale base, semantic conflict, squash reshaping) but missed the most common real one: **state**. Two PRs both add migration `0042`; each is fine alone, trunk has a clash. Or an integration test needs a seeded DB that nothing sets up. `pre-merge`'s integration bucket has no setup/migration/seed step (`bucket-runners.md:14-37`).
- **What to do**: Add a setup pre-flight (apply migrations, boot services) before the integration check. If it can't, return `env_not_provisioned` rather than a misleading pass.

### 12. The "arm a watcher" handoff has no real connection
- **What's wrong**: `/loop` and `/schedule` are **Claude Code built-ins, not `msg` skills** — they are not in this repo. Every other `msg` handoff is a real file contract (e.g. `review` writes `eval_set.json`, `test` reads it). "Arm a watcher" names two outside tools but says nothing about what gets written, what gets read, or how the user cancels it.
- **What to do**: If you keep the monitoring idea, write a real file contract: the mode writes a watch-spec (what to watch, the commit, the baseline, how to cancel) to a known path, and document which tool reads it. Otherwise, cut it from v1.

### 13. When the watcher fires hours later, nobody catches it
- **What's wrong**: Say the watcher does fire. Nothing in `msg` owns the event "a regression appeared in prod for commit X." There is no incident or rollback skill. The loop closes into nothing. This is dangerous because it is silent.
- **What to do**: Name the callback target before shipping. Either define a small incident/rollback skill, or have the watcher route the fired event somewhere concrete. Don't arm a watcher that calls into a void.

### 14. The merge record overlaps `todo` and `handoff`
- **What's wrong**: `todo` is the **only** thing allowed to write `TODOs.json` (with strict id order and an approval gate). `handoff` already auto-writes a "Next Steps" section. A merge record with its own "follow-up TODOs" would be the third thing claiming the same job, and three artifacts describing one merge confuses everyone.
- **What to do**: The mode must **delegate** follow-ups to `todo`, never write `TODOs.json` itself. Any merge record is a separate machine-readable file keyed by commit (e.g. `.post-merge/<sha>.json`), clearly different from `handoff/<n>.md`.

### 15. `resolve-diff.sh` actively fights this use case
- **What's wrong**: It runs `git fetch` and compares against `origin/main` (`resolve-diff.sh:12, :18`). Right after a merge-and-push, `origin/main` already contains the merge, so the diff is empty and the skill refuses with "no diff" — exactly when there is work to do. The refusal text then tells the user the wrong thing.
- **What to do**: New mode needs its own diff resolver (default to the merge delta), drop the `git fetch`, and base its refusal on "no merge detected / not on trunk," not "no diff vs origin/main."

### 16. Baseline / marker / arm-watcher can't be built with the allowed tools
- **What's wrong**: The skill is allowed only Bash, Read, Agent, AskUserQuestion — no network. So "snapshot production signals" has no source, "annotate the commit" means a local file or a git write, and "arm a watcher" reduces to printing a command, not actually arming anything.
- **What to do**: Be honest about scope. Baseline = a local snapshot file. Marker = a local file (or a git note only if the refusal rules are loosened). Arm-watcher = emit a ready-to-run command, or add the needed tools. Don't claim live monitoring.

### 17. No feedback loop from production back to planning
- **What's wrong**: The lifecycle is a straight line. The only learning store, `AHA.md`, is fed only by planning-time signals (`plan-pm/SKILL.md:154-170`). A prod regression has no path back into a spec.
- **What to do**: Add an edge: after-merge or incident findings append to `AHA.md`, and `plan-pm` gains a "a shipped feature regressed → open a PRD" option. This is what turns a one-way pipeline into a real lifecycle.

---

## The nice-to-have issues

Small things — worth noting, not blocking.

- **18. The name is misleading.** "post-merge" reads as a mirror of "pre-merge," but it's a verifier, not a gate. And nothing even owns *doing* the merge. Consider `--merge-delta` (a mode) or, if it ever owns the merge too, `land`.
- **19. There is no shared scripts folder.** Only `shared/refs/` exists. Reusing `detect-tooling.sh` means either fragile `../pre-merge/scripts/` paths or copying. Cleanest fix: promote `detect-tooling.sh` into `shared/scripts/`.
- **20. `rtk` may not exist where the watcher runs.** Every command is `rtk`-prefixed, but `rtk` is your private tool, not part of the project. A scheduled/remote run would fail with "rtk: command not found." Fall back to plain commands outside the interactive session.
- **21. Merge is not deploy.** A "marker" at merge time does not mean the commit ever served traffic. Don't let the wording imply merged = shipped. Leave real deploy/health checks to a future tier.
- **22. Coverage is measured three different ways and never on trunk.** `/test` runs the real coverage tool, `/review` only checks for sibling test files, `pre-merge` has a side-check. None measures the merged tree. Either measure it here or stop calling it a gate.
- **23. The whole post-PR arc is unowned.** Version bump, changelog, release notes, deploy, rollback, incident — no skill owns any of these. If you want `post-merge`/`--merge-delta` to not look like an orphan, frame it as the first member of a future "delivery / operate" tier.

---

## Open questions to answer before building

1. **What is your team's actual merge strategy?** If you squash (the common default), test `pre-merge --base HEAD~1` first — it may close most of the gap with near-zero code. Only true merge commits or multi-commit merges need the new range logic.
2. **Do you want the monitoring part at all?** It can't be built with the current tools and it mixes up "merged" with "deployed." If yes, it belongs in a separate future tier with the right tools — not v1.
3. **Keep or drop "carry accepted risk from pre-merge"?** Keeping it forces a schema change to `pre-merge`. Dropping it makes v1 honest and shippable now.
4. **One small capability, or a whole delivery tier?** The deeper unowned thing is the *merge action itself* and everything after it (release, deploy, rollback). Decide if you're shipping one check or opening a new category.
5. **What is your precision/speed budget?** A fourth "wait for tests" on near-identical code gets skipped by reflex. Confirm it runs fast, ungated-by-default, and treats flaky failures as inconclusive.

---

## Suggested build order (if you proceed)

1. **Experiment**: run `pre-merge --base HEAD~1` after a real merge. See how much it already covers.
2. **Decide** the five open questions above — especially merge strategy and whether to drop accepted-risk and monitoring.
3. **Add `--merge-delta` mode to `pre-merge`**: parent-count detection, correct range per strategy, commit-pinning, inverted "unreachable = blocker" rule, setup pre-flight, and `--prior-trunk` attribution.
4. **Add a new script** `resolve-merge-delta.sh` (don't reuse `resolve-diff.sh`); drop the `git fetch`; add `not_on_trunk` / `no_merge_detected` / `env_not_provisioned` refusals.
5. **Pin default buckets** to integration + build + fast unit/typecheck; document the exclusions.
6. **Wire routing**: extend the happy path past `gh pr create`, add a "just merged / verify trunk" route in `msg/SKILL.md`.
7. **Delegate follow-ups to `todo`**; write any merge record as a distinct `.post-merge/<sha>.json`.
8. **Only if wanted**: design the watcher file contract and name its callback owner. Otherwise leave monitoring out.

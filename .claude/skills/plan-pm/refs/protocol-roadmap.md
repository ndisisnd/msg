---
name: Roadmap Protocol
description: End-to-end six-step protocol for plan-pm --roadmap — inventory existing PRDs, analyse for bloat/overlap, gate reshaping, sequence into stable roadmap phases, render roadmap/roadmap.md, offer the GUI
type: reference
---

# Roadmap Protocol

The protocol `plan-pm --roadmap` follows end-to-end. Unlike the default six-step PRD flow, `--roadmap` runs **no interview** — it operates on the PRDs already in `features/`. It is read-mostly: it reshapes PRD files only on explicit per-op approval (Step 3), and its sole guaranteed artifact is `roadmap/roadmap.md`.

Emit progress as `Step X/6 — <title>` at the start of each step, per § Progress emission in SKILL.md.

**Terminology.** A **roadmap phase** is an ordered wave of whole PRDs (this protocol). It is distinct from an **eng phase** (a step inside one PRD's build — PRD §7 exec-table `Phase` column, eng plan §6). Always say "roadmap phase" on first use in output.

## Step 1/6 — Inventory

Enumerate every PRD via the scan helper (ships with this skill in the global scripts dir; resolve there when the project has no vendored copy):

```bash
S=.claude/scripts/plan-pm-roadmap-scan.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/plan-pm-roadmap-scan.sh"; bash "$S"
```

It prints one JSON object per PRD (top-level and nested sub-PRD) with: `id`, `feature`, `module`, `platform`, `status`, `product_tuned`, `eng_tuned`, `reviewed`, `completion` (derived bucket), `depends_on[]`, `affects[]`, `parent`, `created`, `path`.

If the output is empty → emit `No PRDs to arrange — run /plan-pm to create one first.` and terminate.

**Completion bucket.** The scan's `completion` is a cheap frontmatter-derived fallback (`product` / `eng` / `review` / `retired`). Where git is available, refine it with the same ladder the GUI server uses (most-authoritative first): frontmatter `completion:` override → merged PR → open PR → branch `feat/<id>` exists → `status: eng` → else `product`. Use `git branch --list` / `gh pr list` only if cheap; never block on network. `retired` PRDs (superseded by a split/merge) are excluded from sequencing but listed in Phase 0.

Hold the inventory in context as the working set.

## Step 2/6 — Validate completeness, then analyse for bloat and overlap

### Completeness gate — only full PRDs enter a roadmap

A roadmap is only as trustworthy as the PRDs in it, so **only full PRDs are accepted**. A PRD is **full** when all of these hold:

1. Frontmatter `complete` is `true` in the scan (i.e. `status: eng` **and** `product-tuned: yes` **and** `eng-tuned: yes` — the product→tune→eng-plan→tune pipeline finished), and it is not `retired`.
2. **§6 Features & acceptance criteria** is populated with real content — at least one concrete, testable acceptance criterion per in-scope feature (not the template placeholder, not empty).
3. **§7 Feature execution table** has real F-ID rows (not the `_To be populated by plan-em …_` placeholder).

For each non-retired PRD, read §6 and §7 and evaluate the three conditions. When a PRD **fails** any condition, do not silently include or skip it — **exit the analysis and ask the user** via `AskUserQuestion` (name the PRD and the missing piece):

> `<prd-id>` is not a full PRD — <missing: acceptance criteria in §6 / execution table in §7 / planning not finished (status/tune stamps)>. How should the roadmap handle it?
> - **Amend now (msg flow)** — complete it before roadmapping. Route to the right stage and run it in-session via `Skill`, then re-check: missing §6 / acceptance criteria or unfinished product spec → `plan-pm --sub <prd>` or `plan-tune --product`; missing §7 execution table → `plan-em <prd>` then `plan-tune --eng`. On completion the PRD's frontmatter stamps update, so re-run the scan and re-evaluate.
> - **Skip this PRD** — exclude it from the roadmap this run; record it under the tune log as `excluded — not full`. It is not sequenced and not written into any phase.
> - **Stop** — halt `--roadmap` with no file written.

Resolve every incomplete PRD (amend or skip) before proceeding. The rest of Step 2, and Steps 3–5, operate **only on full PRDs**. A skipped PRD never appears in `roadmap/roadmap.md` except as an `excluded` tune-log note.

### Analyse (full PRDs only)

For each **full** PRD, read its **§6 Features & acceptance criteria** (the F-ID list) from its `path`. Do not read whole PRDs blindly — the F-ID list plus frontmatter (`module`, `depends_on`, `affects`) is the signal.

Flag two conditions:

- **Bloat** — a single PRD carrying **≥2 unrelated feature clusters**. Heuristics (any):
  - Its F-IDs span ≥2 distinct modules/domains with no shared user goal.
  - >~6 features where a subset could ship independently as its own releasable feature.
  - Its §1 Product objective names two or more separable outcomes.
- **Overlap** — two PRDs that duplicate scope. Heuristics (any):
  - Overlapping feature intent (same user capability described in both).
  - Shared `module` **and** cross-referencing `affects`.
  - A small PRD that is wholly a dependency of another and adds no standalone user value → **foldable**.

Produce a **normalisation proposal** — a list of ops, each with a one-line rationale:

| Op | Form | Meaning |
|----|------|---------|
| `SPLIT` | `SPLIT prd-X → <cluster-a> / <cluster-b>` | Bloated PRD broken into unique-feature children |
| `MERGE` | `MERGE prd-Y ← prd-Z` | Two overlapping PRDs consolidated into one |
| `FOLD` | `FOLD prd-W into prd-V` | A dependency-only PRD absorbed by its consumer |
| `TRIM` | `TRIM prd-U (drop <cluster>)` | An out-of-scope cluster removed from an otherwise-unique PRD |

If nothing is flagged, emit `All PRDs are unique and unbloated — no reshaping proposed.` and proceed to Step 4 (skip Step 3). **Write no files in this step.**

## Step 3/6 — Approve and apply normalisation (gated)

Only runs when Step 2 produced a proposal. Present the proposal as a table, then gate **each op** (batch closely-related ops into one call) via `AskUserQuestion` — options: `Apply` / `Skip` / `Modify` / `Explain`.

Reshaping is destructive to PRD files, so it happens only on `Apply`. Never hard-delete a PRD — mark it `retired` with a pointer.

**On `Apply`:**

- **SPLIT** — for each child cluster: allocate a number via `scan-n.prd prd`, derive a kebab-case `feature_slug`, create `features/prd-<n>-<slug>/prd-<n>-<slug>.md` from `refs/template-prd.md`, and move the cluster's §6 features (and their §7 exec-table rows, if `plan-em` already ran) into it. Carry `module`/`platform` from the parent; recompute `depends_on`/`affects` for each child. Mark the original PRD `status: retired` and prepend a `## Retired` banner: `Split into prd-<a>-…, prd-<b>-… on <date>.` By default **carry the existing §6 clusters verbatim** into the children — a full re-interview is opt-in (offer it only if the user picks `Modify`).
- **MERGE / FOLD** — append the source PRD's §6 features into the target's §6, union `depends_on`/`affects`, and reconcile duplicate F-IDs (renumber source F-IDs to avoid collision). Mark the source `status: retired` with a banner pointing to the target.
- **TRIM** — move the out-of-scope cluster to the target PRD's **§2 Out-of-scope** with a note, or (user's choice) spin it out as its own PRD via the SPLIT path.

**On `Skip`:** leave the PRD untouched but record the flag so it resurfaces next run (written into the Step 5 tune log). **On `Modify`:** capture the user's adjustment (e.g. a different cluster boundary) and apply the modified op. **On `Explain`:** restate the evidence, then re-ask.

After applying, re-run Step 1's scan so the working set reflects the reshaped files before sequencing.

## Step 4/6 — Sequence into roadmap phases (stable)

Build a dependency DAG over the working set (**full, non-retired PRDs only** — incomplete PRDs were amended or excluded at the Step 2 completeness gate):

- **Hard edges** from `depends_on` — B must ship after A.
- **Soft edges** from `affects` — prefer ordering A before B, but not a hard constraint.

Layer PRDs into roadmap phases by topological order:

1. **Phase 0 — Shipped** anchors every PRD whose completion bucket is `shipped` (or `retired`, listed for provenance). It is informational — not executed.
2. Each subsequent phase contains PRDs whose **hard** dependencies are all satisfied by an earlier phase. Within a phase, order by soft edges, then by `created`.

**Stability rule (rerun).** If `roadmap/roadmap.md` already exists, read it first (Step 5 format) and **keep each surviving PRD in its current phase**. Move a PRD only when one of these triggers fires — and log the trigger:

- (a) it was `SPLIT`/`MERGE`/`FOLD`/`TRIM`/`retired` this run (children/targets placed fresh);
- (b) a newly-added **hard** dependency now forces it into a later phase than it currently sits;
- (c) it has huge overlap with a PRD in an earlier phase and consolidation moved it.

Newly-added PRDs (present in the scan, absent from the existing roadmap) drop into the **earliest** phase their hard deps allow. A PRD in the roadmap but absent from the scan (deleted/renamed) is pruned, noted in the tune log. Absent an existing roadmap, sequence purely by the DAG.

A dependency **cycle** is a hard failure of the PRD set, not this protocol — surface it (`Cycle detected: prd-A → prd-B → prd-A; resolve depends_on before sequencing.`), place the cycle members in the earliest safe phase, and note it in the tune log.

## Step 5/6 — Write `roadmap/roadmap.md`

Create `roadmap/` if absent. Write `roadmap/roadmap.md`:

```markdown
---
name: roadmap
generated: <YYYY-MM-DD>
prd_count: <N non-retired>
phase_count: <K excluding Phase 0>
---

# Roadmap

## Phase 0 — Shipped
Goal: Already delivered — informational, not executed.
- prd-<n>-<slug> — <feature> — shipped — <note>

## Phase 1 — <name>
Goal: <one line — the outcome this wave unlocks>
- prd-<n>-<slug> — <feature> — <completion bucket> — <one-line placement rationale>
- ...

## Phase 2 — <name>
Goal: <one line>
- ...

## Roadmap tune log
### [<YYYY-MM-DD>] <run summary>
- <normalisation op applied / skipped>
- <phase move + trigger (a/b/c)>
- <pruned/added PRD>
```

Preserve prior phase **names and order** on rerun; only append to the tune log (most recent entry first, like §9 Plan tune findings). Phase names are human-editable and must survive regeneration — key phases by their `## Phase <k>` heading, not by content.

## Step 6/6 — Summary, GUI offer, next steps

Emit a digest:

```
Roadmap generated: <K> phases, <N> PRDs (<S> shipped). Written to roadmap/roadmap.md.
```

List each phase with its PRD count on one line. Then `AskUserQuestion` (single-select):

> What would you like to do next?

- **View the roadmap GUI** — launch the board on the Roadmap tab. Run, as a background process from the project root:
  ```bash
  python3 .claude/skills/msg/refs/gui/server.py --root . --port 0 --view roadmap
  ```
  Print the `http://127.0.0.1:<port>/` URL it emits; open the browser if possible. Note the PID/URL so the user can stop it. (Static fallback and security model are identical to `/msg --gui` — see `msg/refs/protocol-gui.md`.)
- **Execute the roadmap** — hand off to the autonomous orchestrator: `Skill("eng", "--build roadmap=roadmap/roadmap.md")`. State plainly that this starts an autonomous product-ops run that emits a plan and asks once before executing.
- **Done** — terminate with no further action.

Do not auto-invoke execution — the orchestrator is the one sanctioned autonomous path and the user must choose it.

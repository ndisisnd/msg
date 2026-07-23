---
name: Sub-PRD Protocol
description: The --sub mode deltas for plan-pm — parent resolution, idea pre-seed, numbering/placement, and frontmatter, layered over the standard five-step autonomous protocol
type: reference
---

# Sub-PRD mode (`--sub`)

A sub-PRD is a numbered follow-up (`prd-<n>.<m>`) that captures additional changes or fixes to an existing parent PRD without opening a new top-level feature or cutting a new branch. It runs the **identical** five-step autonomous protocol in `refs/protocol-pm.md` — same autonomous drafting, same population, same tune/eng handoffs — with exactly four deltas, all resolved before Step 1 emits:

**D1 — Resolve the parent PRD (priority order).** Determine the parent before anything else. Try each in turn; stop at the first that resolves:
1. **Explicit** — a PRD path or number passed with `--sub` (e.g. `/plan-pm --sub 2` or `/plan-pm --sub features/planned/prd-2-habit-tracking/prd-2-habit-tracking.md`). Resolve it lane-agnostically to the matching PRD directory — search `features/{planned,wip,done}/prd-<parent-n>-*/` then the legacy flat `features/prd-<parent-n>-*/`, first hit wins. If an explicit value is given but matches no such directory in any lane → hard-refuse: `Hard failure: --sub parent '<value>' does not match any PRD under features/.` and stop.
2. **Infer from branch** — run `git branch --show-current`; if it matches `feat/prd-<n>-<slug>`, that PRD is the parent (the user is typically already on the parent's branch when asking for follow-up work). Confirm the PRD directory exists in some lane (`features/{planned,wip,done}/prd-<n>-<slug>/` or legacy flat `features/prd-<n>-<slug>/`).
3. **Pick from a list** — otherwise, `AskUserQuestion` listing open PRDs (glob all lanes `features/{planned,wip,done}/prd-*/prd-*.md` plus legacy flat `features/prd-*/prd-*.md`, deduped by id, and exclude any that are themselves sub-PRDs — i.e. whose id contains a `.`). The user selects the parent. If no top-level PRDs exist at all, hard-refuse: `Hard failure: no parent PRD found for --sub — run /plan-pm to create a top-level PRD first.` and stop.

Store the resolved parent as `parent_id` = `prd-<parent-n>-<parent-slug>` and `parent_dir` = its resolved directory (whatever lane — `planned/`, `wip/`, `done/`, or the legacy flat path — it currently sits in; the resolver locates it lane-agnostically), and read its frontmatter (`feature`, `module`, `platform`) — needed for D3/D4.

**D2 — Pre-seed the idea (Step 1).** Skip the intake-row resolution and the `/intake` bounce — the parent supplies the idea and goal. Pre-seed the working idea with `follow-up to prd-<parent-n>-<parent-slug>: <parent feature>` (parent `feature` from its frontmatter) and fold the user's stated follow-up changes into it, then drop straight into Step 2. A `--sub` follow-up **may** also be logged as an `INTAKE.md` `bug` row (one appended row, `type: bug`, `status: backlog`) to keep the ledger complete — offer it, don't force it; the sub-PRD itself does not need an intake ancestor.

**D3 — Number and place the sub-PRD (Step 3 Part 1 + 2).** Replace the top-level number resolver with the sub resolver:

```bash
S=.claude/scripts/scan-n.prd; [ -f "$S" ] || S="$HOME/.claude/scripts/scan-n.prd"; bash "$S" sub <parent-n>
```

Store the output as `m` (the minor). Derive `sub_slug` (kebab-case, ≤6 words) from the follow-up scope. Create the sub-PRD **nested inside the parent's existing folder — whatever lane (`planned/`, `wip/`, `done/`, or the legacy flat path) that folder currently occupies**. A sub-PRD gets **no lane slot of its own**: it rides the parent's lane and only ever relocates when the parent folder is moved. Use the full `refs/template-prd.md` structure (not a delta doc), writing `<parent_dir>` for the parent directory resolved in D1:

```
<parent_dir>/prd-<parent-n>.<m>-<sub_slug>/prd-<parent-n>.<m>-<sub_slug>.md
```

**D4 — Frontmatter (Step 3 Part 2).** Same fields as a top-level PRD, with:
- `name`: `prd-<parent-n>.<m>-<sub_slug>`
- `parent`: `prd-<parent-n>-<parent-slug>` — **new field, sub-PRD only.** This is the field `plan-em`/`eng --build` read to resolve the shared branch (a sub-PRD never gets its own branch).
- `module` / `platform`: **default to the parent's values** (read in D1). Overridable only if the autonomous draft reveals the sub-PRD's scope genuinely differs — otherwise inherit unchanged.
- `summary`: authored fresh for the sub-PRD's own follow-up scope (2–3 single-line sentences), exactly as a top-level PRD — do not inherit the parent's.
- All other fields (`status: product`, `product-tuned: no`, `eng-tuned: no`, `reviewed: no`, `created`, `affects`, `depends_on`) exactly as a top-level PRD.

**Lifecycle:** unchanged. A sub-PRD runs the full pipeline with no stage skipped — `plan-pm --sub` (Steps 1–5) → `plan-tune --product` → `plan-em` → `plan-tune --eng` → `eng --build`. Step 5 terminates recommending `plan-tune --product` exactly as for a top-level PRD, using the nested sub-PRD path. A sub-PRD has no intake ancestor by default, so Step 5's intake lifecycle stamp is skipped (unless a `bug` row was logged in D2 — then stamp that row).

Everywhere the steps in `refs/protocol-pm.md` write the drafted PRD's own path `features/planned/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md`, substitute the nested sub-PRD path from D3 when in `--sub` mode — it lands inside the parent's existing folder in whatever lane the parent occupies, not in `planned/`.

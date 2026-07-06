---
name: Sub-PRD Protocol
description: The --sub mode deltas for plan-pm — parent resolution, intake pre-seed, numbering/placement, and frontmatter, layered over the standard six-step protocol
type: reference
---

# Sub-PRD mode (`--sub`)

A sub-PRD is a numbered follow-up (`prd-<n>.<m>`) that captures additional changes or fixes to an existing parent PRD without opening a new top-level feature or cutting a new branch. It runs the **identical** six-step protocol in `refs/protocol-pm.md` — same interview, same population, same tune/eng handoffs — with exactly four deltas, all resolved before Step 1 emits:

**D1 — Resolve the parent PRD (priority order).** Determine the parent before anything else. Try each in turn; stop at the first that resolves:
1. **Explicit** — a PRD path or number passed with `--sub` (e.g. `/plan-pm --sub 2` or `/plan-pm --sub features/prd-2-habit-tracking/prd-2-habit-tracking.md`). Resolve it to the matching `features/prd-<parent-n>-*/` directory. If an explicit value is given but matches no such directory → hard-refuse: `Hard failure: --sub parent '<value>' does not match any features/prd-*/ PRD.` and stop.
2. **Infer from branch** — run `git branch --show-current`; if it matches `feat/prd-<n>-<slug>`, that PRD is the parent (the user is typically already on the parent's branch when asking for follow-up work). Confirm the `features/prd-<n>-<slug>/` directory exists.
3. **Pick from a list** — otherwise, `AskUserQuestion` listing open PRDs (glob `features/prd-*/prd-*.md`, exclude any that are themselves sub-PRDs — i.e. whose id contains a `.`). The user selects the parent. If no top-level PRDs exist at all, hard-refuse: `Hard failure: no parent PRD found for --sub — run /plan-pm to create a top-level PRD first.` and stop.

Store the resolved parent as `parent_id` = `prd-<parent-n>-<parent-slug>`, and read its frontmatter (`feature`, `module`, `platform`) — needed for D3/D4.

**D2 — Pre-seed intake (Step 1).** Skip the "target user or scope missing" clarifying question — the parent supplies both. Pre-seed the brief with `follow-up to prd-<parent-n>-<parent-slug>: <parent feature>` (parent `feature` from its frontmatter) and fold the user's stated follow-up changes into it. Epic detection still runs, but a sub-PRD is by definition a focused follow-up — it will almost never trip; do not force a split.

**D3 — Number and place the sub-PRD (Step 4 Part 1 + 2).** Replace the top-level number resolver with the sub resolver:

```bash
S=.claude/scripts/scan-n.prd; [ -f "$S" ] || S="$HOME/.claude/scripts/scan-n.prd"; bash "$S" sub <parent-n>
```

Store the output as `m` (the minor). Derive `sub_slug` (kebab-case, ≤6 words) from the follow-up scope. Create the sub-PRD **nested inside the parent's folder**, using the full `refs/template-prd.md` structure (not a delta doc):

```
features/prd-<parent-n>-<parent-slug>/prd-<parent-n>.<m>-<sub_slug>/prd-<parent-n>.<m>-<sub_slug>.md
```

**D4 — Frontmatter (Step 4 Part 2).** Same fields as a top-level PRD, with:
- `name`: `prd-<parent-n>.<m>-<sub_slug>`
- `parent`: `prd-<parent-n>-<parent-slug>` — **new field, sub-PRD only.** This is the field `plan-em`/`eng --build` read to resolve the shared branch (a sub-PRD never gets its own branch).
- `module` / `platform`: **default to the parent's values** (read in D1). Overridable only if the interview reveals the sub-PRD's scope genuinely differs — otherwise inherit unchanged.
- `summary`: authored fresh for the sub-PRD's own follow-up scope (2–3 single-line sentences), exactly as a top-level PRD — do not inherit the parent's.
- All other fields (`status: product`, `product-tuned: no`, `eng-tuned: no`, `reviewed: no`, `created`, `affects`, `depends_on`) exactly as a top-level PRD.

**Lifecycle:** unchanged. A sub-PRD runs the full pipeline with no stage skipped — `plan-pm --sub` (Steps 1–6) → `plan-tune --product` → `plan-em` → `plan-tune --eng` → `eng --build`. Step 6's next-step prompt hands off exactly as for a top-level PRD, using the nested sub-PRD path.

Everywhere the steps in `refs/protocol-pm.md` say `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md`, substitute the nested sub-PRD path from D3 when in `--sub` mode.

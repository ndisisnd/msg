---
name: Tune Product Checklist
description: Adversarial audit checklist for product tune — severity definitions, Dimensions 1–4, findings-table schema, and output structure
type: reference
---

# Tune Product Checklist

Apply every item below to the target PRD. **Input:** Dimensions 1–4 audit the **`product` digest slice** SKILL.md Step 1 reads (`scan-prd-digest.py --slice product` → frontmatter, summary, out_of_scope, features + acceptance criteria verbatim, error_cases, glossary, key_interactions), not full PRD prose. Audit that slice twice — once for completeness + consistency (D1–D2), once for agent-readability + scope integrity (D3–D4). If a check needs a detail the slice omits (User-flow narrative, Product-objective prose, or a heading under `unparsed_sections`), read only that section's `prose_lines` range — never default to the whole PRD (`../shared/refs/session-cache.md`: source is canonical, regenerate on stale).

**Every finding** is a row in the findings table (schema below), carrying a **severity tag** (rubric below) and a **concrete suggested fix**.

**Bind every check to a section title, not a number.** The PRD numbers sections (`## 1. Product objective` … `## 11. Todos`), but numbers shift on add/remove. Match by title so checks survive reorder.

## Canonical PRD sections

`plan-pm`'s `template-prd.md` emits these in order. The product tune audits **product-authored** sections (✓); tool-owned sections (Feature execution table, Plan tune findings, Todos) are populated later by other skills — **never flag them as missing** in a product tune.

| Section | Product-tune audits? |
|---------|----------------------|
| Product objective | ✓ |
| Out-of-scope | ✓ |
| User flow | ✓ |
| Key user interactions | ✓ |
| Error cases | ✓ |
| Features & acceptance criteria | ✓ |
| Feature execution table | — (eng tune / plan-em) |
| Open questions | ✓ |
| Plan tune findings | — (this skill writes it) |
| Glossary | ✓ |
| Todos | — (/todo) |

Platform is frontmatter metadata (`platform:`), not a body section. No "Target platform" section to audit.

## Severity tags

| Tag | Definition |
|-----|------------|
| **Critical** | An AI agent silently defaults to a wrong assumption, or the PRD self-contradicts in a way that blocks safe implementation. Engineering cannot start. |
| **Major** | Interpretable but high rework risk. A reasonable engineer builds the wrong thing without further conversation. |
| **Minor** | Clarity/completeness gap. Adds friction, does not block implementation. |

## Dimension 1 — Completeness

**Gate every check on "section present."** Fire only when the section exists and a row/field inside is missing/malformed. A whole absent product section = one Major "missing section" finding — do not cascade into per-row Criticals across other dimensions.

| Check | Fail condition | Severity |
|-------|----------------|----------|
| Product objective present | Absent, or present with no stated user/business goal | Major |
| Out-of-scope present | Absent, or zero items | Major |
| Features & acceptance criteria present | Section/table absent | Critical |
| Feature IDs | Features section present but a row missing an F-ID | Major |
| Feature acceptance criteria | Features present but a row with empty/placeholder Acceptance criterion cell | Critical |
| User flow present | Absent, or a confirmed feature has no flow diagram | Major |
| Key user interactions present | Absent | Minor |
| Error cases present | Absent | Major |
| Open questions present | Absent (empty table is OK — not every PRD has open questions) | Minor |
| Glossary | Glossary present but a domain term used in product sections has no entry | Minor |
| Glossary vs `devkit/GLOSSARY.md` | A term in both this Glossary and project `devkit/GLOSSARY.md` (Step 1, if file exists) with conflicting definition | Critical |

## Dimension 2 — Consistency

Read every section against every other; check for contradictions.

| Check | What to look for | Severity |
|-------|-----------------|----------|
| Feature ↔ Out-of-scope | A Features row claims behavior also listed in Out-of-scope | Critical |
| Feature ↔ Objective | A Features row pursues an outcome the objective doesn't cover, or contradicts it | Major |
| Dependencies ↔ IDs | A Dependencies cell names an F-ID absent from the table | Major |
| Glossary ↔ Usage | A Glossary term used inconsistently across product sections | Minor |
| Acceptance criterion ↔ Acceptance criterion | Two rows define overlapping behavior with conflicting acceptance criteria | Critical |
| Feature ↔ Flow | A Features row has no matching User flow, or a User flow covers a feature absent from the table | Major |

## Dimension 3 — Agent-readability

Read every requirement as if an AI coding agent executes it without asking the human anything.

**Vague verbs to flag (Critical when they appear in an acceptance criterion):**

| Forbidden verb | Why it fails | Replacement pattern |
|----------------|--------------|--------------------|
| supports | No observable behavior | "When X happens, Y appears within N seconds" |
| handles | No observable behavior | "On error E, the app displays message M and logs L" |
| integrates with | No contract specified | "Calls /foo/bar with payload {...}; expects 200 + JSON {...}" |
| works correctly | Untestable | List every observable state |
| feels fast / smooth | Untestable | "Renders within Nms p95" |
| looks good | Untestable | Reference a design spec or screenshot |
| ensure | No observable mechanism — who ensures, how verified? | "System validates X by checking Y; if Y fails, does Z" |
| manage | Which of create/edit/delete/archive? | Name exact operations: "users can create, edit, and delete X" |
| process | No input→output contract | "Receives X, transforms by Y, writes Z to destination D" |
| allow | No permission boundary | "Role R can perform action A; other roles see an error" |
| optimize | No metric/baseline/target | "Reduces P95 latency of endpoint E from Xms to Yms under Z load" |
| should | Implies optionality where `must` is intended | `must` for required, `may` for optional |
| may / can | Optional with undefined trigger/scope | State the condition: "when X, system may Y; otherwise Z" |

**Quantifier checks:**
- Every time-bound criterion names the bound ("within 1s", "before midnight local").
- Every count criterion names the count ("up to 100 entries", "max 3 retries").
- Every state-based criterion names the states ("from `pending` to `active`").

**Ambiguity checks:**
- Pronoun without clear referent ("it persists", "they notify") → Major.
- Conditional with no else branch ("if the user grants permission, X") → Major; specify otherwise.
- Timezone reference without explicit basis ("midnight", "today") → Critical; name device-local, server UTC, or user-profile tz.

## Dimension 4 — Scope integrity

Look for scope-creep invitations and misplaced engineering detail. Engineering detail (API shape, schema migration, rollback) belongs in the Feature execution table (Dimension 5 / eng tune), **not** in user-goal acceptance criteria. At product level check only: no scope creep, no happy path without an error path, no engineering detail smuggled into user-goal criteria.

| Check | Fail condition | Severity |
|-------|----------------|----------|
| Eng detail in acceptance criterion | A Features row names an API/endpoint/schema/component/file — belongs in the Feature execution table | Minor |
| Error states | A Features row / Key-user-interaction with a happy path but no matching Error cases entry | Major |
| Out-of-scope creep | A Features row that restates or contradicts an Out-of-scope item | Major |
| Persisted-data implication | A Features row implying new persisted user data whose criterion omits the observable persisted result | Minor |

## Findings table schema

Both the inline user summary and the PRD's **Plan tune findings** section use this one table. Columns, in order:

| Column | Meaning |
|--------|---------|
| `#` | Monotonic finding number, continued across runs — never reset to 1. |
| `Date` | Run date, `YYYY-MM-DD`. |
| `Auditor` | `P` (product tune) or `E` (eng tune). |
| `Severity` | Critical / Major / Minor. |
| `What is wrong` | Terse — cite section + problem. ≤100 chars, ≤2 lines. |
| `Suggested fix` | Terse concrete action, applyable without further interpretation. ≤100 chars. |
| `Why it matters` | Terse — the wrong default an agent would silently apply, or the consequence. ≤100 chars. |
| `Status` | `Open` (new/unfixed), `Fixed` (applied this run), `Still open` (carried forward unchanged), `Clean` (no-findings marker row). |

Markdown form written to the PRD:

```markdown
| # | Date | Auditor | Severity | What is wrong | Suggested fix | Why it matters | Status |
|---|------|---------|----------|---------------|---------------|----------------|--------|
| 1 | 2026-07-04 | P | Critical | Streak "local" timezone undefined (Features F2) | Define as user-profile tz, fallback device, fallback America/Los_Angeles | Backend defaults UTC, mobile defaults device — divergent streaks | Open |
```

The inline summary may omit `Date`, `Auditor`, `Status` (shows only this run's fresh findings); it keeps `#`, `Severity`, `What is wrong`, `Suggested fix`, `Why it matters`.

## Output structure

- Findings are written to the PRD's **Plan tune findings** section as rows in the table above — never as prose "Finding N —" blocks, never as a separate dated section. SKILL.md Step 2/4 owns the create-once / append-rows mechanics.
- Order rows by severity (Critical first), then by PRD section order within each severity.
- Footer: present the human gate defined in SKILL.md Step 4/4.

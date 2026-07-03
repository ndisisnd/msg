---
name: Tune Product Checklist
description: Adversarial audit checklist for product tune — severity definitions, Dimensions 1–4, findings-table schema, and output structure
type: reference
---

# Tune Product Checklist

Apply every item below to the target PRD. Read the document twice — once for completeness and consistency, once for agent-readability and scope integrity. Produce findings as rows in the findings table (schema below). Every finding carries a severity tag and a concrete suggested fix.

**Bind every check to a section title, not a number.** The PRD numbers its sections (`## 1. Product objective` … `## 11. Todos`), but numbers shift when sections are added or removed. Match sections by their title so these checks survive any reorder.

## Canonical PRD sections

`plan-pm`'s `template-prd.md` emits these sections in order. The product tune audits the **product-authored** sections (marked ✓); the tool-owned sections (Feature execution table, Plan tune findings, Todos) are populated later by other skills — never flag them as missing in a product tune.

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

Platform is metadata in the PRD frontmatter (`platform:`), not a body section. There is no "Target platform" section to audit.

## Severity tags

| Tag | Definition |
|-----|------------|
| **Critical** | An AI agent would default to a wrong assumption silently, or the PRD contradicts itself in a way that blocks safe implementation. Engineering cannot start. |
| **Major** | The PRD is interpretable but high risk of rework. A reasonable engineer would build the wrong thing without further conversation. |
| **Minor** | Clarity or completeness gap. Adds friction but does not block implementation. |

## Dimension 1 — Completeness

**Gate every check on "section present."** Only fire a finding when the section exists and a row/field inside it is missing or malformed. If a whole product section is absent, that is a single Major "missing section" finding — do not cascade it into per-row Criticals across the other dimensions.

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Product objective present | Section absent, or present with no stated user/business goal | Major |
| Out-of-scope present | Section absent, or present with zero items | Major |
| Features & acceptance criteria present | Section/table absent | Critical |
| Feature IDs | Features section present but any feature row missing an F-ID | Major |
| Feature acceptance criteria | Features section present but any feature row with an empty or placeholder Acceptance criterion cell | Critical |
| User flow present | Section absent, or a confirmed feature has no flow diagram | Major |
| Key user interactions present | Section absent | Minor |
| Error cases present | Section absent | Major |
| Open questions present | Section absent (an empty table is acceptable — not every PRD has open questions) | Minor |
| Glossary | Glossary present but any domain term used in the product sections has no glossary entry | Minor |
| Glossary vs `devkit/GLOSSARY.md` | A term appears in both this PRD's Glossary and the project's `devkit/GLOSSARY.md` (read in SKILL.md Step 1, if the file exists) with a conflicting definition | Critical |

## Dimension 2 — Consistency

Read every section against every other section. Check for contradictions.

| Check | What to look for | Severity if fails |
|-------|-----------------|-------------------|
| Feature ↔ Out-of-scope | A Features row claims behavior that is also listed in Out-of-scope | Critical |
| Feature ↔ Objective | A Features row pursues an outcome the Product objective does not cover, or contradicts it | Major |
| Dependencies ↔ IDs | A Features Dependencies cell names an F-ID that does not exist in the table | Major |
| Glossary ↔ Usage | A term defined in Glossary is used inconsistently across the product sections | Minor |
| Acceptance criterion ↔ Acceptance criterion | Two Features rows define overlapping behavior with conflicting acceptance criteria | Critical |
| Feature ↔ Flow | A Features row has no corresponding User flow, or a User flow covers a feature absent from the Features table | Major |

## Dimension 3 — Agent-readability

Read every requirement as if an AI coding agent will execute it without asking the human anything.

**Vague verbs to flag (Critical when they appear in an acceptance criterion):**

| Forbidden verb | Why it fails | Replacement pattern |
|----------------|--------------|--------------------|
| supports | No observable behavior | "When X happens, Y appears within N seconds" |
| handles | No observable behavior | "On error E, the app displays message M and logs L" |
| integrates with | No contract specified | "Calls endpoint /foo/bar with payload {...}; expects 200 + JSON {...}" |
| works correctly | Untestable | List every observable state |
| feels fast / smooth | Untestable | "Renders within Nms p95" |
| looks good | Untestable | Reference a design spec or screenshot |
| ensure | No observable mechanism — who ensures it? how is it verified? | "The system validates X by checking Y; if Y fails, the system does Z" |
| manage | Covers create/edit/delete/archive — which operations? | Name the exact operations: "users can create, edit, and delete X" |
| process | No defined input→output contract | "Receives X, transforms it by Y, writes Z to destination D" |
| allow | No permission boundary stated | "Users with role R can perform action A; all other roles see an error" |
| optimize | No metric, baseline, or target | "Reduces P95 latency of endpoint E from Xms to Yms under Z load" |
| should | Implies optionality where `must` is intended | Replace with `must` for required behavior; `may` for optional |
| may / can | Optional behavior with undefined trigger or scope | State the exact condition: "when X, the system may Y; otherwise Z" |

**Quantifier checks:**

- Every acceptance criterion with a time bound names the bound (e.g., "within 1s", "before midnight local").
- Every acceptance criterion with a count names the count (e.g., "up to 100 entries", "max 3 retries").
- Every state-based criterion names the states (e.g., "from `pending` to `active`").

**Ambiguity checks:**

- A pronoun without a clear referent ("it persists", "they notify") → Major.
- A conditional with no else branch ("if the user grants permission, X") → Major. Specify what happens otherwise.
- A timezone reference without an explicit basis ("midnight", "today") → Critical. Name device-local, server UTC, or user-profile timezone.

## Dimension 4 — Scope integrity

Look for invitations to scope creep and misplaced engineering detail.

A product-tune PRD keeps engineering detail out of the product sections — API shape, schema migration, rollback plans belong in the Feature execution table (a Dimension 5 / eng-tune concern), not in the user-goal acceptance criteria. At the product level, check only that the PRD does not invite scope creep, does not leave a happy path without an error path, and does not smuggle engineering detail into user-goal criteria.

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Eng detail in acceptance criterion | A Features & acceptance criteria row names an API/endpoint/schema/component/file — engineering detail that belongs in the Feature execution table | Minor |
| Error states | A Features row / Key-user-interaction with a happy path but no matching Error cases entry | Major |
| Out-of-scope creep | A Features row that restates or contradicts an Out-of-scope item | Major |
| Persisted-data implication | A Features row that implies new persisted user data but whose acceptance criterion does not state the observable persisted result | Minor |

## Findings table schema

Both the inline user summary and the PRD's **Plan tune findings** section use this one table. Columns, in order:

| Column | Meaning |
|--------|---------|
| `#` | Monotonic finding number, continued across runs — never reset to 1. |
| `Date` | Run date, `YYYY-MM-DD`. |
| `Auditor` | `P` (product tune) or `E` (eng tune). |
| `Severity` | Critical / Major / Minor. |
| `What is wrong` | Terse — cite the section and the problem. ≤100 chars, ≤2 lines. |
| `Suggested fix` | Terse concrete action, specific enough to apply without further interpretation. ≤100 chars. |
| `Why it matters` | Terse — the wrong default an agent would silently apply, or the consequence. ≤100 chars. |
| `Status` | `Open` (new/unfixed), `Fixed` (fix applied this run), `Still open` (carried forward unchanged), `Clean` (a no-findings marker row). |

Markdown form written to the PRD:

```markdown
| # | Date | Auditor | Severity | What is wrong | Suggested fix | Why it matters | Status |
|---|------|---------|----------|---------------|---------------|----------------|--------|
| 1 | 2026-07-04 | P | Critical | Streak "local" timezone undefined (Features F2) | Define as user-profile tz, fallback device, fallback America/Los_Angeles | Backend defaults UTC, mobile defaults device — divergent streaks | Open |
```

The inline summary shown to the user may omit `Date`, `Auditor`, and `Status` (it shows only this run's fresh findings); it keeps `#`, `Severity`, `What is wrong`, `Suggested fix`, `Why it matters`.

## Output structure

- Findings are written to the PRD's **Plan tune findings** section as rows in the table above — never as prose "Finding N —" blocks, and never as a separate dated section. SKILL.md Step 2/4 owns the create-once / append-rows mechanics.
- Order rows by severity (Critical first), then by PRD section order within each severity.
- Footer: present the human gate defined in SKILL.md Step 4/4.

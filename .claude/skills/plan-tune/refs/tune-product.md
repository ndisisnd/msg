---
name: Tune Product Checklist
description: Adversarial audit checklist for product tune — severity definitions, Dimensions 1–4, finding format, and output structure
type: reference
---

# Tune Product Checklist

Apply every item below to the target PRD. Read the document twice — once for completeness and consistency, once for agent-readability and scope integrity. Produce a numbered findings report. Every finding carries a severity tag and a concrete suggested fix.

## Severity tags

| Tag | Definition |
|-----|------------|
| **Critical** | An AI agent would default to a wrong assumption silently, or the PRD contradicts itself in a way that blocks safe implementation. Engineering cannot start. |
| **Major** | The PRD is interpretable but high risk of rework. A reasonable engineer would build the wrong thing without further conversation. |
| **Minor** | Clarity or completeness gap. Adds friction but does not block implementation. |

## Dimension 1 — Completeness

The target PRD follows `plan-pm`'s `template-prd.md` schema, which has exactly 8 sections: §1 Out-of-scope, §2 Target platform, §3 Features & acceptance criteria, §4 User flows, §5 Key user interactions, §6 Error cases, §7 Open questions, §8 Glossary.

**Gate every check on "section present."** Only fire a finding when the section exists and a row/field inside it is missing or malformed. If a whole section is absent, that is a single Major "missing section" finding — do not cascade it into per-row Criticals across the other dimensions.

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| §1 Out-of-scope present | Section absent, or present with zero items | Major |
| §2 Target platform present | Section absent, or Platform field left as the unfilled placeholder | Major |
| §3 Features & acceptance criteria present | Section/table absent | Critical |
| §3 Feature IDs | §3 present but any feature row missing an F-ID | Major |
| §3 Feature acceptance criteria | §3 present but any feature row with an empty or placeholder Acceptance criterion cell | Critical |
| §4 User flows present | Section absent, or a confirmed feature has no flow diagram | Major |
| §6 Error cases present | Section absent | Major |
| §7 Open questions present | Section absent (an empty list is acceptable — not every PRD has open questions) | Minor |
| §8 Glossary | §8 present but any domain term used in §1–§7 has no glossary entry | Minor |

## Dimension 2 — Consistency

Read every section against every other section. Check for contradictions.

| Check | What to look for | Severity if fails |
|-------|-----------------|-------------------|
| §3 Feature ↔ §1 Out-of-scope | A §3 feature row claims behavior that is also listed in §1 out-of-scope | Critical |
| §3 Feature ↔ §2 Platform | A §3 feature targets a platform that §2 excludes | Major |
| §3 Dependencies ↔ §3 IDs | A §3 Dependencies cell names an F-ID that does not exist in the table | Major |
| §8 Glossary ↔ Usage | A term defined in §8 is used inconsistently across §3–§6 | Minor |
| Acceptance criterion ↔ Acceptance criterion | Two §3 feature rows define overlapping behavior with conflicting acceptance criteria | Critical |
| §3 Feature ↔ §4 Flow | A §3 feature has no corresponding §4 user flow, or a §4 flow covers a feature absent from §3 | Major |

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

Look for invitations to scope creep and missing technical contracts.

A product-tune PRD has no engineering sections, so do not demand engineering-level contracts (API shape, schema migration, rollback plans) here — those are Dimension 5 (eng tune) concerns. At the product level, check only that the PRD does not invite scope creep or leave a happy path without an error path.

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Owner platform per feature | A §3 feature whose behavior differs across platforms but names no owning platform, when §2 lists more than one platform | Major |
| Error states | A §3 feature / §5 interaction with a happy path but no matching §6 error case | Major |
| Out-of-scope creep | A §3 feature row that restates or contradicts a §1 out-of-scope item | Major |
| Persisted-data implication | A §3 feature that implies new persisted user data but whose acceptance criterion does not state the observable persisted result | Minor |

## Worked example — finding format

Every finding must follow this structure:

```
Finding N — [Severity] — <one-line title>

What is wrong:
  <Cite the exact PRD section and sentence. Quote verbatim.>

Why it matters for agent-readability:
  <Name the wrong default an AI agent would silently apply.>

Suggested fix:
  <Concrete rewrite. Specific enough to drop into the PRD without further interpretation.>
```

**Worked example:**

```
Finding 3 — Critical — Streak timezone reference is undefined

What is wrong:
  PRD-1 §3 F2 acceptance criterion: "Streak +1 when log occurs in
  [00:00, 23:59] local". The word "local" is ambiguous — device timezone,
  server timezone, and user-profile timezone are three different values.

Why it matters for agent-readability:
  An AI agent will default to server UTC for backend logic, while a
  mobile-eng agent will default to device-local. The two will compute
  different streak values for the same user. This will not surface in
  unit tests; it will surface as a customer support escalation after
  travel or DST.

Suggested fix:
  Replace "local time" with "user-profile timezone, defaulting to device
  timezone if the user has not set a profile timezone, defaulting to
  America/Los_Angeles if neither is set." Add a glossary entry for
  "streak day boundary" pointing to this definition.
```

## Output structure

Top of report:

```markdown
# Tune audit — prd-[n]

Audited: features/prd-[n]-[slug]/prd-[n]-[slug].md
Auditor: product-plan-tune
Date: YYYY-MM-DD

Summary:
  Critical: <N>
  Major: <N>
  Minor: <N>
```

Body: numbered findings, ordered by severity (Critical first), then by PRD section order within each severity.

Footer: present the human gate defined in SKILL.md Step 5.

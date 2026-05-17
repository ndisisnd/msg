---
name: Tune Checklist
description: Adversarial audit checklist for product-plan-tune (completeness, consistency, agent-readability, scope integrity)
type: reference
---

# Tune Checklist

Apply every item below to the target PRD. Read the document twice — once for completeness and consistency, once for agent-readability and scope integrity. In an Eng tune (PRD contains `## Engineering —` sections), also apply Dimension 5 on a third read focused on the engineering sections. Produce a numbered findings report. Every finding carries a severity tag and a concrete suggested fix.

## Severity tags

| Tag | Definition |
|-----|------------|
| **Critical** | An AI agent would default to a wrong assumption silently, or the PRD contradicts itself in a way that blocks safe implementation. Engineering cannot start. |
| **Major** | The PRD is interpretable but high risk of rework. A reasonable engineer would build the wrong thing without further conversation. |
| **Minor** | Clarity or completeness gap. Adds friction but does not block implementation. |

## Dimension 1 — Completeness

Every item is a "missing → fail" check.

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Target user defined | No named in-scope user segment | Critical |
| Out-of-scope user named | No explicit out-of-scope user segment | Major |
| Out-of-scope features list | Section absent or fewer than 3 items | Major |
| Platform priorities table | Missing or any platform without a priority + reason | Major |
| Feature acceptance criteria | Any feature row without an acceptance criterion | Critical |
| Glossary | Any domain term used in §1–§7 with no glossary entry | Minor |
| Open questions ownership | Any open question without a named owner and deadline | Major |

## Dimension 2 — Consistency

Read every section against every other section. Check for contradictions.

| Check | What to look for | Severity if fails |
|-------|-----------------|-------------------|
| Feature ↔ Out-of-scope | A feature row claims behavior that is also listed as out-of-scope | Critical |
| Platform ↔ Feature | A feature lists a platform that the platform priorities table excludes | Major |
| Metric ↔ Feature | A success metric requires data from a feature that does not exist | Major |
| Glossary ↔ Usage | A term defined in glossary is used inconsistently in feature rows | Minor |
| Acceptance criterion ↔ Acceptance criterion | Two feature rows define overlapping behavior with conflicting criteria | Critical |
| Target user ↔ Feature | A feature serves a user segment named as out-of-scope | Major |

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

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Owner platform per feature | Any feature without a named owner platform when behavior differs across platforms | Major |
| API contract details | Any client-server feature without endpoint shape or payload contract | Major |
| Backwards compatibility | Schema or behavior change without a stated migration path | Critical |
| Auth model | Any user-data feature without a stated auth requirement | Critical |
| Error states | Any happy-path requirement with no error-state spec | Major |
| Rollback plan | Any new persisted entity without a rollback or feature-flag plan | Major |

## Dimension 5 — Eng Plan Integrity (Eng tune only)

Apply only when running an Eng tune (PRD contains `## Engineering — <Agent Name>` sections). Read each engineering section against the PRD requirements and against the quality gates in `refs/template-eng-plan.md`. One finding per issue.

### 5a — Feature coverage

Every feature ID in the PRD must appear in at least one engineering section's scope mapping table (§5 of the eng plan template).

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Full feature coverage | Any PRD feature ID absent from all `## Engineering —` scope mapping tables | Critical |
| No phantom features | An engineering section covers a feature ID not present in the PRD | Major |
| Agent ownership | Any PRD feature with no named owning agent across all engineering sections | Major |

### 5b — PRD ↔ Eng consistency

Read every engineering design decision against PRD constraints, acceptance criteria, and platform priorities.

| Check | What to look for | Severity if fails |
|-------|-----------------|-------------------|
| Design decision ↔ PRD constraint | An engineering design decision contradicts or ignores a stated PRD constraint | Critical |
| Eng scope ↔ Out-of-scope | An engineering section implements behavior listed as out-of-scope in the PRD | Critical |
| Platform match | An engineering section targets a platform not listed in the PRD platform priorities table | Major |
| Acceptance criterion ↔ Eng plan | A PRD acceptance criterion has no corresponding implementation detail in any engineering section | Major |

### 5c — Integration contract completeness

Read each engineering section's integration contracts (§7 of the eng plan template).

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| API contracts | Any client-server feature in an engineering section with no API contract row (method, path, request, response) | Critical |
| Schema changes | Any schema change listed without stating whether it is `ADDITIVE` or `MIGRATION REQUIRED` | Major |
| Auth pattern | Any user-data feature in an engineering section without a stated authentication mechanism | Critical |
| Webhook/hook coverage | Any webhook or hook referenced in prose but absent from the contracts table | Major |

### 5d — Migration and breaking change coverage

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Breaking change acknowledgement | An engineering section introduces a schema or API breaking change with no stated rollback plan | Critical |
| Migration path | A `MIGRATION REQUIRED` schema change has no named migration script or upgrade path | Critical |
| Backward-compat shim | A breaking change marks no backward-compat period or deprecation window | Major |

### 5e — Open question ownership

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| OPEN decision owner | Any design decision marked `OPEN` in an engineering section has no named owner or stated resolution path | Major |
| Duplicate open questions | The same open question appears in multiple engineering sections without a cross-reference to avoid duplicate work | Minor |
| Phase blocked by OPEN decision | A phase exit criterion depends on an OPEN design decision with no resolution timeline | Critical |

### 5f — Eng plan completeness (quality gate audit)

Check each engineering section against the quality gates in `refs/template-eng-plan.md` (Summary, Alternatives considered, Design decisions, PRD coverage, Phases, Integration contracts, Developer experience, Migration, Risks, Timeline, Open questions).

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Summary present | §1 absent or does not name the target platform and shipping shape | Major |
| Alternatives considered | §3 absent or writes `None.` without a sentence explaining why one approach is obviously correct | Minor |
| At least three risks | §11 has fewer than three rows | Minor |
| Timeline estimate | §13 absent or has no engineer-day estimate | Minor |

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
  PRD-1 §5 F2 acceptance criterion: "Streak +1 when log occurs in
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

Audited: features/prd-[n]/prd-[n].md
Auditor: product-plan-tune
Date: YYYY-MM-DD

Summary:
  Critical: <N>
  Major: <N>
  Minor: <N>
```

Body: numbered findings, ordered by severity (Critical first), then by PRD section order within each severity.

Footer: present the human gate defined in SKILL.md Step 5.

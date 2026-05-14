---
name: Substitution Rules
description: Placeholder substitution rules applied to every template before writing to disk
type: reference
---

# Substitution Rules

Apply every rule in this file before writing a template's body to disk. Substitutions are exact string replacements on the template body, not on the frontmatter or the surrounding template ref.

## Placeholder table

| Placeholder | Source | Fallback if source missing |
|-------------|--------|---------------------------|
| `{{project_name}}` | Q1 answer — project name | Working directory basename |
| `{{project_description}}` | Q1 answer — one-line description | `Project bootstrapped with msg-init.` |
| `{{platform}}` | Q2 answer or detected stack | `Not specified — fill in later.` |
| `{{team_type}}` | Q3 answer | `Solo` |
| `{{conventions}}` | Q4 answer | `None recorded yet. Add house conventions as they emerge.` |

## Application rules

1. **Exact match only**: Replace `{{placeholder}}` (with the braces) — never substitute bare words like `platform` outside the braces.
2. **Body only**: Apply substitutions to the content inside the `## Template body` fenced code block. Do not modify the template ref's frontmatter, instructions, or examples.
3. **Strip the fences**: When writing the substituted body to disk, remove the outer triple-backtick fence that wraps the template body block.
4. **Preserve `[USER: …]` markers**: Do not substitute or remove `[USER: fill in …]` markers. They are deliberate gaps the user fills in later.
5. **Trim whitespace**: Remove trailing whitespace on every line; ensure the file ends with a single newline.

## Worked example

**Template body in `refs/template-README.md`:**

```markdown
# {{project_name}}

{{project_description}}
```

**Q1 answer:** `name = "Lumen"`, `description = "A focus timer for solo builders."`

**Output written to `README.md`:**

```markdown
# Lumen

A focus timer for solo builders.
```

## Edge cases

| Case | Handling |
|------|----------|
| User typed "Other" with custom platform string | Use the custom string verbatim for `{{platform}}` |
| User skipped Q4 or chose "None yet" | Use the fallback string for `{{conventions}}` |
| Project name contains markdown special characters (`*`, `_`, `#`) | Substitute literally; user can fix in the README afterwards |
| Project description spans multiple lines | Collapse to one line at substitution time |

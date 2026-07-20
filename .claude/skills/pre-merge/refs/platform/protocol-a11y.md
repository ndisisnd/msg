---
name: a11y
description: Pre-merge accessibility component — WCAG audit across pages/components via the detected runner. Parse violations to canonical findings.
---

# a11y component

Guard, error rule, envelope: `../_common.md`. Runner (`a11y_runner`: axe-core CLI /
axe-playwright / jest-axe / pa11y / Lighthouse) from the fingerprint.

## Targets

Resolve what to audit: runner config (`.pa11yci`, `lighthouserc.*`, axe config) →
else `sitemap.xml` / routes / `baseURL` (up to 20 pages, starting `/`) → else
Storybook build (jest-axe/axe-playwright). None resolvable → `pass_with_warnings`,
note `"No audit targets found."`

## Parse

Map runner-native severity: critical/serious → `high`; moderate → `medium`;
minor/best-practice → `medium`. Verdict `fail` on any critical/serious; else
`pass_with_warnings` for moderate/minor only; `pass` at zero.

Finding fields: `rule` = `"WCAG <criterion> — <rule-id>"` (e.g. `"WCAG 1.1.1 — image-alt"`);
`file` = page URL / component; `line` = selector or `null`; `evidence.file` = page
screenshot or `null`; `suggestion` = runner-provided fix. Dedup a rule firing on many
pages into one finding (`"<rule> — N pages affected (/, /about, …)"`); keep distinct
selectors on the same page separate. Unreachable targets/timeouts → `../_common.md` error
rule; attach `errors[]` and use partial results.

Component fields: `runner`, `command`, `targets_audited`, `errors[]`, `totals` (critical/serious/moderate/minor).

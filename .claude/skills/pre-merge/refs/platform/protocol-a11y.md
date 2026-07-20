---
name: a11y
description: Pre-merge accessibility component (C13) — WCAG audit at the interactive UI states the e2e flows reach (dialog/error/menu), not just static page loads; native a11y on iOS/macOS (performAccessibilityAudit) + Android (accessibility-test-framework) when targeted; findings lead with user impact + flow, WCAG id secondary. Default enablement/criticality is a project-level --init decision. Low-priority tier.
---

# a11y component

Guard, error rule, envelope: `../_common.md`. Runner (`a11y_runner`: web — axe-core CLI /
axe-playwright / jest-axe / pa11y / Lighthouse; **native** — iOS/macOS
`XCUIApplication.performAccessibilityAudit()` + Android accessibility-test-framework) from
the fingerprint. **Priority: low** — a11y fixes are a low-priority build tier; sequence
them after the higher-impact components (AC-A11Y5).

Whether a11y runs blocking, advisory, or off is a **project-level `--init` decision**
(`../protocol-init.md`, AC-A11Y4): public-facing product → default-on/blocking;
internal tool / backend → default-off/advisory. The catalog's default `blocking` is the
public-facing default, not an unconditional one.

## Targets — interactive states, not just static pages (AC-A11Y1)

Audit a11y at each **meaningful interactive UI state the e2e flows reach** — dialog open,
validation error shown, menu expanded, drawer/toast visible — via the `axe-playwright`
pattern, **not only static page loads**. This catches dynamic-state bugs invisible to a
static crawl: an unlabeled dialog close button, a broken focus-trap, an error announced to
no one.

- **`e2e` owns the flows (D29).** a11y **consumes** the canonical flow set + critical tags
  from `protocol-e2e.md` (the same set `perf`/`preview`/`smoke` consume); it drives each
  flow to its meaningful states and runs the audit **at each state**, not just the entry page.
- **Fallback resolution** when no flow set applies: runner config (`.pa11yci`,
  `lighthouserc.*`, axe config) → else `sitemap.xml` / routes / `baseURL` (up to 20 pages,
  starting `/`) → else Storybook build (jest-axe/axe-playwright). None resolvable →
  `pass_with_warnings`, note `"No audit targets found."`

## Native a11y — real coverage when targeted (AC-A11Y2)

When a **client platform is targeted and a native runner is present**, run native a11y —
turning C12's a11y coverage-gap from a *flag* into real coverage:

- **iOS / macOS** — `XCUIApplication.performAccessibilityAudit()` (Xcode 15+): VoiceOver
  labels, contrast, 44pt hit-targets, dynamic-type / clipped-text, element traits.
- **Android** — accessibility-test-framework (Espresso `AccessibilityChecks`): content
  labels, touch-target size, contrast, duplicate descriptions.

A running native a11y runner **satisfies** C12's native-a11y gap for that platform. When
the platform is targeted but **no native runner is available**, that stays a
`platform-coverage-gap` (C12) — a loud gap, not a silent pass.

## Parse

Map runner-native severity: critical/serious → `high`; moderate → `medium`;
minor/best-practice → `medium`. Verdict `fail` on any critical/serious (when the project
enabled a11y as blocking); else `pass_with_warnings` for moderate/minor only; `pass` at
zero. (An `--init` advisory/off project never blocks — its findings are recorded context.)

## Findings — lead with user impact + flow (AC-A11Y3)

Frame every finding per `../../../shared/refs/name-the-user-impact.md`: the **barrier a
user hits in a real interactive state comes first, the WCAG id is secondary**. *"Screen-
reader users can't tell todos apart — the priority button has no label, in the todo-list
flow (WCAG 4.1.2 — button-name)."* — not `"aria-command-name at node …"`.

Finding fields: `message` = the user-facing barrier + the flow/state it bites (reuse the
e2e-flow/state context already reached — D29); `rule` = `"WCAG <criterion> — <rule-id>"`
(e.g. `"WCAG 1.1.1 — image-alt"`, the dedup/regression key, kept but not first);
`file` = page URL / component / native screen; `line` = selector / element or `null`;
`evidence.file` = state screenshot or `null`; `suggestion` = runner-provided fix. Dedup a
rule firing on many pages/states into one finding (`"<rule> — N states affected (todo-list,
dialog-open, …)"`); keep distinct selectors on the same state separate. Degrade honestly:
with no flow/state context, state the impact you can support (component + platform) —
never invent a user story. Unreachable targets/timeouts → `../_common.md` error rule;
attach `errors[]` and use partial results.

Component fields: `runner`, `command`, `targets_audited` (states/pages/native screens),
`native_run` (bool), `errors[]`, `totals` (critical/serious/moderate/minor).

## References

- `platform/protocol-e2e.md` — the canonical flows + critical tags a11y consumes (D29 —
  audit the interactive states these reach)
- `../../../shared/refs/name-the-user-impact.md` — the finding-framing (impact + flow
  first, WCAG id secondary)
- `../protocol-init.md` — the `--init` a11y-relevance decision (enablement/criticality per
  project type, AC-A11Y4)
- `../_common.md` — guard / error rule / output envelope

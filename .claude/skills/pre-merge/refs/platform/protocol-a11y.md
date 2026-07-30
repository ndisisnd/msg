---
name: a11y
description: Pre-merge accessibility component (C13) — WCAG audit over the resolved target set (runner config, else sitemap/routes, else Storybook stories); native a11y on iOS/macOS (performAccessibilityAudit) + Android (accessibility-test-framework) when targeted; findings lead with user impact, WCAG id secondary. Default enablement/criticality is a project-level decision. Low-priority tier.
---

# a11y component

Guard, error rule, envelope: `../_common.md`. Runner (`a11y_runner`: web — axe-core CLI /
axe-playwright / jest-axe / pa11y / Lighthouse; **native** — iOS/macOS
`XCUIApplication.performAccessibilityAudit()` + Android accessibility-test-framework) from
the component's resolved tooling. **Priority: low** — a11y fixes are a low-priority build
tier; sequence them after the higher-impact components.

Whether a11y runs blocking, advisory, or off is a **project-level decision** recorded on
the component (`../protocol-init.md`): public-facing product → default-on/blocking;
internal tool / backend → default-off/advisory. The catalog's default `blocking` is the
public-facing default, not an unconditional one.

## Targets — the resolved target set

Audit whatever the project's own configuration points the runner at, in this order:

1. **Runner config** — `.pa11yci`, `lighthouserc.*`, an axe config: the declared URL /
   page / story list. This is where a project that wants specific interactive states
   (dialog open, validation error shown, menu expanded) declares them — a project
   using `axe-playwright` inside its own specs gets state-level auditing for free,
   because its specs drive the states.
2. **Route discovery** — `sitemap.xml` / the router's routes / `baseURL` (up to 20
   pages, starting `/`).
3. **Storybook build** — jest-axe / axe-playwright over the stories.

**None resolvable** → `pass_with_warnings`, note `"No audit targets found."` The audit
runs where the project points it; `a11y` maintains no page or flow list of its own.

## Native a11y — real coverage when targeted

When a **client platform is targeted and a native runner is present**, run native a11y —
turning the a11y coverage-gap from a *flag* into real coverage:

- **iOS / macOS** — `XCUIApplication.performAccessibilityAudit()` (Xcode 15+): VoiceOver
  labels, contrast, 44pt hit-targets, dynamic-type / clipped-text, element traits.
- **Android** — accessibility-test-framework (Espresso `AccessibilityChecks`): content
  labels, touch-target size, contrast, duplicate descriptions.

A running native a11y runner **satisfies** C12's native-a11y gap for that platform. When
the platform is targeted but **no native runner is available**, that stays a
`platform-coverage-gap` (C12) — a loud gap, not a silent pass.

## Parse

Map runner-native severity: critical/serious → `high`; moderate → `medium`;
minor/best-practice → `low`. Verdict `fail` on any critical/serious (when the project
enabled a11y as blocking); else `pass_with_warnings` for moderate/minor only; `pass` at
zero. (An advisory/off project never blocks — its findings are recorded context.)

## Findings — lead with user impact

Frame every finding per `../../../shared/refs/name-the-user-impact.md`: the **barrier a
user hits comes first, the WCAG id is secondary**. *"Screen-reader users can't tell
todos apart — the priority button has no label (WCAG 4.1.2 — button-name)."* — not
`"aria-command-name at node …"`.

Finding fields: `message` = the user-facing barrier + the page/state it was found on;
`rule` = `"WCAG <criterion> — <rule-id>"` (e.g. `"WCAG 1.1.1 — image-alt"`, the
dedup/regression key, kept but not first); `file` = page URL / component / native
screen; `line` = selector / element or `null`; `evidence.file` = screenshot or `null`;
`suggestion` = runner-provided fix. Dedup a rule firing on many pages into one finding
(`"<rule> — N pages affected (todo-list, settings, …)"`); keep distinct selectors on
the same page separate. Degrade honestly: state the impact you can support (component
+ platform) — never invent a user story. Unreachable targets/timeouts → `../_common.md`
error rule; attach `errors[]` and use partial results.

Component fields: `runner`, `command`, `targets_audited` (pages/stories/native screens),
`native_run` (bool), `errors[]`, `totals` (critical/serious/moderate/minor).

## References

- `../../../shared/refs/name-the-user-impact.md` — the finding-framing (impact first,
  WCAG id secondary)
- `../protocol-init.md` — the a11y-relevance decision (enablement/criticality per
  project type)
- `../_common.md` — guard / error rule / output envelope

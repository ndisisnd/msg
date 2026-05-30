---
name: Creativity Levels
description: Maps the --creativity flag to concrete design parameters, hard rules, and the style/DS precedence order
type: reference
---

# Creativity levels

Maps the `--creativity` flag to concrete, repeatable design parameters. Default: `medium`. The flag is a behavioral instruction, not LLM sampling temperature — a skill cannot set temperature, so these anchors are what make the three levels actually differ.

## Parameter table

| Parameter | low | medium | high |
|---|---|---|---|
| Design-system deviation | none — DS components used as-is | minor recomposition of DS components | novel composition of DS parts |
| Net-new / custom components | never | never | never (arrangement only) |
| Layout variants explored internally | 1 | 1 | 2 — pick the strongest, present 1 |
| Whitespace scale latitude | base scale only | base ±1 step | base ±2 steps |
| Typographic hierarchy | DS type scale only | DS scale, may shift weight | DS scale, may shift weight + size emphasis |
| Pattern selection | most-proven pattern only | proven patterns, conventional | proven patterns arranged unconventionally |
| Color/emphasis | DS roles, conservative | DS roles, standard emphasis | DS roles, bold emphasis within roles |

## Hard rules (apply at every level)

1. **No custom elements, ever.** Creativity changes the *arrangement and composition* of existing design-system components — it never introduces components outside the DS. This holds even at `high`. (Enforces the persona anti-pattern.)
2. **UX laws are constraints, not styling.** Higher creativity never relaxes a UX law, accessibility baseline, or platform convention. It only widens latitude *within* those constraints.
3. **One direction per screen.** Even at `high`, where 2 variants are explored internally, only one is presented. The agent does not offer the user a menu of options.

## Precedence with style and DS

When inputs conflict, resolve in this order (highest wins):

1. **UX laws + accessibility baselines** — never overridden.
2. **Design system** — components, tokens, patterns. Creativity recomposes these; it never replaces them.
3. **Style preference** (from `refs/ux-style-cache.md`) — sets the *aesthetic vocabulary* (e.g. Minimal vs Bold). Defines *what* the screen feels like.
4. **Creativity level** — sets the *deviation latitude* within that vocabulary. Defines *how far* from convention to push.

Example: style `Corporate` + `--creativity:high` → a corporate aesthetic (restrained palette, dense information, conventional vocabulary) explored with high latitude in *layout composition and whitespace*, not loud color or playful type. Style wins the look; creativity wins the structural boldness.

## Flag parsing

Accept all of: `--creativity:high`, `--creativity=high`, `--creativity high`. Values: `high` | `medium` | `low`. Anything else → default to `medium` and note the fallback to the user.

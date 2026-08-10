# Phase 0 — freeze and classify

Branch: `v6-msg-codex`  
Canonical base commit: `c87ffb8ac4aef369c385997802bdc2d5e0044d57`  
Status: audited; blocked at the deviation/canonical-ambiguity decision gate

## Frozen baseline

`evals/codex/baselines/claude-tree.sha256` records 203 tracked runtime-source files:

- 133 files under `.claude/skills/`.
- 67 deterministic helpers under `.claude/scripts/`.
- `.claude/settings.json`.
- `install.sh`.
- `package.json`.

No canonical Claude skill or helper was edited while creating the baseline.

## Skill-tree inventory

| Scope | Canonical files | Compatibility map | Mapping status |
|---|---:|---|---|
| msg | 29 | `.agents/skills/msg/refs/compatibility-map.md` | audited; decision-blocked |
| intake | 5 | `.agents/skills/intake/refs/compatibility-map.md` | audited; decision-blocked |
| plan-pm | 5 | `.agents/skills/plan-pm/refs/compatibility-map.md` | audited; decision-blocked |
| plan-review | 3 | `.agents/skills/plan-review/refs/compatibility-map.md` | audited; decision-blocked |
| plan-em | 4 | `.agents/skills/plan-em/refs/compatibility-map.md` | audited; decision-blocked |
| eng | 11 | `.agents/skills/eng/refs/compatibility-map.md` | audited; decision-blocked |
| pre-merge | 39 | `.agents/skills/pre-merge/refs/compatibility-map.md` | audited; decision-blocked |
| merge | 12 | `.agents/skills/merge/refs/compatibility-map.md` | audited; decision-blocked |
| emulate | 3 | `.agents/skills/emulate/refs/compatibility-map.md` | audited; decision-blocked |
| shared | 22 | `.agents/skills/shared/refs/compatibility-map.md` | audited; decision-blocked |
| **Total** | **133** | **10 maps** | **10 validated maps** |

Every canonical skill-tree file has an exact inventory row and SHA-256 digest. Every
map now includes consumer/load conditions, Codex disposition, destination, proposed
translation, proof ownership, full dependency closure, assertions and concrete eval
designs. This is mapping completeness, not runtime parity proof.

## Existing `.agents` classification

- 20 shared references are byte-identical candidate mirrors.
- 2 shared references contain a Codex preamble and require deviation review.
- 1 Codex-only `harness-map.md` contains unapproved runtime translations.
- No pre-existing file was deleted or overwritten.

## Current gates

- Skill-tree discovery: 133/133 inventoried.
- Skill maps: 9/9 structurally and semantically inventoried.
- Shared map: 1/1 structurally and semantically inventoried.
- Helper-to-skill dependency assignment: 67/67 (`1.0000`).
- Reference mapping: `1.0000` per map.
- Behavior mapping: `1.0000` per map; 146 unique assertions.
- Eval-specification mapping: `1.0000` per map; 120 concrete eval designs cover all
  assertions.
- Runtime proof: `not-run`; adapters are intentionally not implemented.
- Pending deviations: 16.
- Pending canonical ambiguities: 7.

All five Phase 0 mapping ratios are exactly `1.0000`. Phase 1 is blocked until the user
decides every deviation and canonical ambiguity in `codex/deviations.md`.

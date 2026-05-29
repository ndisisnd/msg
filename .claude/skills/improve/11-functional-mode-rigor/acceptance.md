# Acceptance Criteria — 11-functional-mode-rigor

## Change 1 — Executable vs intent split with auto-run

1. `refs/modes/functional.md` defines two assertion classes: `executable` (concrete inputs + observable outcomes) and `intent` (reasoning-only), with at least one example of each.
2. Protocol includes a classification step that runs before any verdict is assigned.
3. For an `executable` assertion, the mode generates an ephemeral script under `/tmp/review-functional-<runid>/` and runs it; the script's exit code maps to the per-assertion verdict.
4. Sandbox constraints are stated explicitly: no writes outside `/tmp`, no network calls unless the assertion concerns a network behavior, no DB writes.
5. When no runnable surface exists (e.g. pure type refactor), the mode reclassifies all `executable` candidates as `intent` and annotates the output with the reason.

## Change 2 — Full file reads

6. The protocol replaces "look in the diff" with an explicit instruction to read each changed file in full via `Read`.
7. The protocol names a widening rule (read direct callers/callees) when an assertion spans a file boundary.

## Change 3 — Verdict rubric

8. `refs/modes/functional.md` contains a "Verdict rubric" subsection.
9. The rubric defines `pass`, `warn`, `block`, and `n/a` with one short example each.
10. `warn` enumerates at least three concrete sub-cases (happy-path-only, intent-unclear, harness-failure).

## Change 4 — Mandatory evidence

11. The protocol states that every `pass` and `block` finding MUST populate `file` and `line`.
12. `refs/schema.md` is updated to document the mandatory-evidence rule for Functional findings.
13. The protocol includes a self-check: any `pass` lacking `file:line` is downgraded to `warn` with reason "no evidence located".
14. `null` for `file`/`line` is only permitted on `n/a` entries.

## Change 5 — Tautology detection

15. `SKILL.md` Step 3 is updated to emit `eval_set_source` with value `"prd"`, `"diff"`, or `"mixed"` in the top-level output JSON.
16. `refs/schema.md` documents the `eval_set_source` field at the top level.
17. `refs/modes/functional.md` reads `eval_set_source`; when value is `"diff"`, the mode prepends a `warning` field to its output and caps its mode verdict at `warn`.

## Change 6 — Negative assertions

18. The protocol defines a `negative` assertion class (assertions of removal/absence) and gives at least one example.
19. The verification rule for negatives is inverted and documented: presence of the prohibited pattern in the diff → `block`; presence in post-change file → `warn`; absence → `pass`.
20. Evidence for negative `pass` is documented as "absence verified" with the file(s) searched listed.

## Change 7 — N/A accounting

21. Functional's output JSON gains top-level `evaluated` and `n_a` integer fields.
22. Each finding gains an `applicable` boolean field.
23. `refs/schema.md` documents the new `evaluated`, `n_a`, and `applicable` fields.
24. The protocol defines "applicable" as "the assertion concerns code touched by the diff or its direct dependencies".

## Cross-cutting

25. No edits to mode files other than `functional.md` (Quality, Coverage, Security, Performance untouched).
26. `SKILL.md` edits are limited to Step 3 emitting `eval_set_source`; no other steps modified.
27. `refs/schema.md` edits are limited to: `eval_set_source` top-level field, mandatory-evidence rule, and `evaluated`/`n_a`/`applicable` documentation.
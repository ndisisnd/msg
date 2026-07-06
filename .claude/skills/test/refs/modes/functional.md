# test — Functional bucket

**When it runs:** third bucket — after Unit/Integration and E2E.

**What it checks:** executable assertions from `eval_set` — the assertions that `/review` Functional mode deferred with `n/a`.

## Execution

Bucket-error rule and output envelope: see `_common.md`. (This bucket has no detected runner — it drives `eval_set`, so it has no Step 1 runner guard.)

Reads `eval_set` (list of `executable`-classed assertion objects) resolved in SKILL.md Step 2. If `eval_set` is empty, this bucket is skipped.

Each assertion is verified by generating an ephemeral script, running it, and recording evidence.

### Step 1 — Read full file context

For every assertion in `eval_set`:

1. Identify the files plausibly related to the assertion (source files, handlers, validators).
2. **Read each such file in full** via `Read` — do not rely on diff hunks alone. Guards, validators, and conditionals frequently sit outside the hunk window.
3. **Widening rule:** when an assertion spans a file boundary (e.g. "the controller rejects empty emails" but validation lives in a sibling validator module), read direct callers and callees of the changed symbols in full.

### Step 2 — Generate and run scripts

For each assertion:

1. Generate an ephemeral script under `/tmp/test-functional-<runid>/assertion-<n>.<ext>` that exercises the assertion. The script must:
   - Write nothing outside `/tmp/test-functional-<runid>/`.
   - Make no network calls unless the assertion explicitly concerns a network behavior.
   - Make no database writes; if state is needed, stand up an in-memory or temp-file fixture.
2. Run the script. Capture exit code, stdout, stderr.
3. Interpret the result:
   - Exit 0 → candidate `pass`.
   - Non-zero, failure attributes to the code under review → `fail`.
   - Non-zero, failure attributes to the test harness (missing dependency, fixture setup error, env issue) → `warn` with note `"harness failure — recheck environment"`.

### Step 3 — Locate evidence

For every `pass` or `fail` result, locate the satisfying or violating code in the file(s) read in Step 1 and record `file` + `line`.

**Mandatory evidence rule:** every failing assertion MUST populate `file` and `line`. A passing assertion is NOT a finding — it is counted in `evaluated`/`passed`, never emitted in `findings[]`. After all assertions are processed, sweep findings:
- Any failure with `file: null` or `line: null` → downgrade from `high` to `medium` with reason `"no evidence located"`.

## Output

Envelope + finding shape per `_common.md` (`../../../shared/refs/finding-schema.md`): category/source `functional`, assertion text in the required `rule` field, `evidence.tool` = `"functional-harness"`. This bucket replaces `runner`/`totals` with `evaluated` (assertions attempted) and `passed` (assertions that passed with evidence).

A failing assertion that attributes to the code under review is `high` (reachable, diff-adjacent); an evidence-less or harness-degraded failure is `medium`. `fail` (run verdict) if any assertion fails and the failure attributes to the code under review. `pass_with_warnings` if any harness errors occur. `pass` if all assertions pass with evidence.
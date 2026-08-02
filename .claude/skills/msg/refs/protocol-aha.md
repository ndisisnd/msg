---
name: msg-protocol-aha
description: >
  Protocol for /msg --aha — sweeps devkit/AHA.md (the institutional-knowledge
  ledger), triages every entry (keep / merge / prune / promote), reports the
  triage as an inline table, and — after a single gate — rewrites AHA.md in the
  terse 2–3-line form. Promotions (msg-workflow change, repo memory, code fix)
  are recommendations only; the mode's sole write is AHA.md itself.
type: reference
---

# Protocol: --aha

## Usage

**Invoke**: `/msg --aha`

- Natural language: "prune the learnings", "sweep AHA", "trim the aha log",
  "triage the learnings ledger"
- On demand only — no hook, no schedule, no auto-run at the end of another
  skill. Writers append freely between sweeps; this mode is the periodic
  compaction pass that keeps the read cost low.

**Preconditions.** `devkit/AHA.md` must exist. If absent, stop: the repo was
bootstrapped before the ledger existed (or never bootstrapped). Direct the user
to `/msg --update`, which tops it up. Do not create the file here.

## Hard boundary — aha rewrites the ledger, nothing else

- The **only** file this mode writes is `devkit/AHA.md` (Step 4, after the
  gate).
- **Never** edit a skill, protocol, ref, script, CLAUDE.md, or project code —
  a `promote` verdict names the destination and the change; the fix happens in
  a separate session the human invokes, with the recommendation as its brief.
- **No "while I'm here."** A learning that exposes a two-line skill fix is
  still a recommendation.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| `<cwd>/devkit/AHA.md` | `### [date] [tag] summary` entries + `**Why**`/`**Note**` lines | writers via `script-aha.sh` (legacy entries may be untagged) |
| Sweep lines | `AHA_ENTRY=<date>\|<tag>\|<recurrence>\|<summary>` + `AHA_ENTRIES=<n>` | `script-aha.sh --list` |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Triage table | One row per entry, inline | Step 3 |
| Rewritten ledger | Kept + merged entries, terse form, most-recent-first | `<cwd>/devkit/AHA.md` |
| Promotion briefs | 1–3 lines each, inline (never written to files) | Step 3 |

## Step-by-step protocol

**Step 1/4 — Sweep**

```bash
A=.claude/scripts/script-aha.sh; [ -f "$A" ] || A="$HOME/.claude/scripts/script-aha.sh"
bash "$A" devkit/AHA.md --list
```

Exit 3 → stop per the precondition above. **The script owns the decidable
part** — entry parsing, tag extraction, recurrence counts; never re-count by
hand. `AHA_ENTRIES=0` ends the run: report a clean ledger and stop.

Then read `devkit/AHA.md` once in full for the `**Why**`/`**Note**` bodies the
sweep lines point at. This is the run's one full read of the ledger.

**Step 2/4 — Triage every entry**

For each `AHA_ENTRY`, in order, assign exactly one verdict:

- **prune** — no-op ("nothing to do differently"), redundant with a kept entry,
  stale (the protocol/script/code it warns about no longer exists — verify
  before claiming staleness), or narrative that encodes no future action.
- **merge** — same tag (or same underlying lesson) as another entry: collapse
  into the strongest single entry, note `×<n>` in its summary.
- **promote** — the lesson recurs (recurrence ≥3 is the default signal) or is
  permanent by nature, so the ledger is the wrong home. Route to exactly one of:
  - `workflow` — a named msg skill/protocol/script change,
  - `memory` — project `CLAUDE.md` or a devkit doc,
  - `code` — a real bug or fix in the project codebase.
  A promoted entry is also pruned from the rewrite — its recommendation is the
  surviving artifact.
- **keep** — still earns its lines; rewrite to the terse form (each field one
  clause ≤140 chars) if it doesn't already comply.

Anti-fabrication: triage the entries in front of you. If an entry's context
can't support a verdict, `keep` it as-is — a wrong prune destroys knowledge; a
wrong keep costs three lines.

**Step 3/4 — Report**

One inline table, before the gate:

| # | Date | Tag | ×n | Verdict | Route | Recommendation |
|---|------|-----|----|---------|-------|----------------|
| 1 | `<date>` | `<tag>` | `<recurrence>` | keep / merge / prune / promote | `workflow` / `memory` / `code` / — | `<one line>` |

Follow it with one prose line of totals (kept / merged / pruned / promoted, and
the before → after line count of the ledger).

**Step 4/4 — Gate, then rewrite**

Call `AskUserQuestion` once — `Apply the rewrite to devkit/AHA.md?`:
- **Apply** → rewrite `devkit/AHA.md`: header and `## Entries` scaffold
  preserved, kept + merged entries only, terse 2–3-line form, most-recent-first.
  Write via a full-file Write of the new content; change nothing above
  `## Entries`.
- **Report only** → write nothing; the table stands as the deliverable.

Promotions are re-stated after the gate as briefs the user can hand to a new
session (`/plan-pm` for code, a direct edit session for workflow/memory). This
mode never applies them.

**Closing message** per
[`../../shared/refs/closing-message.md`](../../shared/refs/closing-message.md),
the last chat output. 🟢 when the sweep ran and any approved rewrite landed;
🟡 when the ledger had unparseable entries that were kept verbatim.

## References

- `.claude/scripts/script-aha.sh` — the ledger's one writer; `--list` sweep,
  `--count` recurrence, 140-char terse cap on appends
- `refs/init/templates/template-AHA.md` — the scaffold and the terse entry contract
- `../../shared/refs/doctor-logging.md` — harness-incident logging (this mode
  logs script failures like the other harness modes)
- `../../shared/refs/closing-message.md` — closing message when the run ends

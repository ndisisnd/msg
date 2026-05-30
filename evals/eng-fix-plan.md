# Eng Skill — Fix Plan

**Date**: 2026-05-30
**Topic**: Bugs found in the `eng` skill, and how to fix them.

---

## The short version

The `eng` skill is well-built but has a few breaks where it talks to its caller (`plan-em`) and its helper (`cook`). On a real run, three of these would actually misfire. Fix R1, R2, R3 first — they are cheap and high-impact.

---

## Must-fix

### ✅ R1 — Row names don't match — DONE
- **Plain English**: `eng` is told to find its work by matching `Streaks:Schema-migration`, but the real table row is named `F2: Track streak — Schema migration`. They don't match. `eng` has to guess.
- **Fix applied**: Both sides now use the exact Feature-cell text, semicolon-separated (the row text has spaces, so spaces can't separate rows). `eng` selects rows by exact Feature-column match; a no-match row is now a hard failure.
- **Where**: `eng/SKILL.md:49,67`; `eng/refs/plan/protocol.md:15`; `eng/refs/build/protocol.md:19`; `plan-em/SKILL.md:201,210`.

### ✅ R2 — Wrong heading breaks the handoff — DONE
- **Plain English**: Plan mode writes `## Engineering`, but build mode and `plan-em` look for `## Engineering — <Agent Name>`. So build mode never starts.
- **Fix applied**: Plan mode now writes `## Engineering — <Agent Name>`, with a note that the suffix is what `plan-em` detects.
- **Where**: `eng/refs/plan/protocol.md:53`.

### ✅ R3 — Notes saved to the wrong file — DONE
- **Plain English**: Build saves lessons to `AHA.md` in the root, but everything else reads `devkit/AHA.md`. The notes are never seen again.
- **Fix applied**: Build now writes to `devkit/AHA.md`.
- **Where**: `eng/refs/build/protocol.md:96,113`.

---

## Should-fix

### ✅ R4 — Parallel builds clash — DONE
- **Plain English**: Many build agents run at once. Each tries to create the branch and write the same file. They collide.
- **Fix applied**: `plan-em` now creates the feature branch once before launching agents. Build agents no longer create it — they hard-fail if it's missing.
- **Where**: `eng/refs/build/protocol.md:40`; `plan-em/SKILL.md:206`.

### ✅ R5 — Eng doesn't know its own name — DONE
- **Plain English**: The rules say "do rows where your agent name appears," but `eng` is never told its name.
- **Fix applied**: Added an `agent` input field. `plan-em` passes it in both modes. Eng now checks each row's Agent column matches and names the `## Engineering — <agent>` heading from it.
- **Where**: `eng/SKILL.md:43-50,68`; `plan-em/SKILL.md:202,213`.

### ✅ R6 — Ships code with no tests, no warning — DONE
- **Plain English**: If the plan forgot a Tests row, build skips tests silently.
- **Fix applied**: Build now emits a visible warning, logs it to the summary and `devkit/AHA.md`, when a group has implementation but no Tests row.
- **Where**: `eng/refs/build/protocol.md:53`.

### ✅ R7 — No full check before the PR — DONE
- **Plain English**: Build only runs the tests it wrote, then opens a PR. It can break other tests.
- **Fix applied**: Added a full test + lint/typecheck gate before commit; new failures go to Debug first.
- **Where**: `eng/refs/build/protocol.md:61`.

---

## Coverage gaps

### ✅ C1 — Native mobile mislabeled — DONE
- **Plain English**: Mobile work was tagged `flutter` regardless. That's fine here — these projects use Flutter/Dart for mobile, not native Swift/Kotlin, and `cook` already covers Flutter/Dart.
- **Fix applied**: Eng sends `cook` the real stack from `CLAUDE.md`/PRD §3 (mobile → `Flutter/Dart`). The general "no-coverage → flag and fall back" rule stays as a safety net. No native standards to author. (Reverted the `ios/swift/android/kotlin` keywords I had added to `cook`.)
- **Where**: `eng/SKILL.md:135-147`.

### ✅ C2 — `web` tag unknown to cook — DONE
- **Plain English**: `eng` sends `web`; `cook` only knows `frontend`/`react`/`nextjs`.
- **Fix applied**: Eng no longer sends a bare `web` token — it sends the real stack phrase (e.g. `React/Next.js web`), which `cook` matches. Added `web` keyword too.
- **Where**: `eng/SKILL.md:135-147`.

### ✅ C3 — Eng tells cook too little — DONE
- **Plain English**: `eng` sends one word. `cook` works better with concern words like `migration`, `auth`, `api`.
- **Fix applied**: Eng now sends `cook` a task summary = stack + concern keywords from the assigned rows.
- **Where**: `eng/SKILL.md:135-147`.

### ✅ C4 — Dead `--review` link — DONE
- **Plain English**: Docs point to a review mode that doesn't exist.
- **Fix applied**: Removed the dead reference.
- **Where**: `eng/SKILL.md` References.

---

## Polish

### ✅ Q1 — Debug rule too tight — DONE
- **Plain English**: Debug can only read 2 files. The real cause is often a third (a shared helper).
- **Fix applied**: Debug may now read shared helpers/fixtures/modules the failure directly points at.
- **Where**: `eng/refs/build/protocol.md:75`.

### ✅ Q2 — Asks once, then runs free — DONE
- **Plain English**: One yes at the start, then it commits and opens a PR alone.
- **Fix applied**: Added a confirm-before-commit gate — eng asks before committing and opening the PR.
- **Where**: `eng/refs/build/protocol.md:62`.

### ✅ Q3 — Fake estimates — DONE
- **Plain English**: It invents engineer-days and a ship date.
- **Fix applied**: Dropped the Cost and timeline section entirely. Old §14 (Open questions) renumbered to §13; removed the Timeline quality gate in the template and in `plan-tune`; fixed a stale §15 reference.
- **Where**: `eng/refs/plan/template-eng-plan.md`; `plan-tune/refs/tune-eng.md`; `eng/SKILL.md:171`.

---

## Order to do them

1. ✅ R1, R2, R3 — cheap, stops real breakage. **Done.**
2. ✅ R4, R5, R6, R7 — safer builds. **Done.**
3. ✅ C1, C2, C3, C4 — better coverage. **Done.**
4. ✅ Q1, Q2, Q3 — polish. **Done.**

## Left to author (not a doc fix)
- None. (Mobile is Flutter/Dart, already covered by `cook` — no native iOS/Android standards needed.)

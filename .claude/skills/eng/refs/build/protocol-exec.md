---
name: Execution Steps Guide
description: How eng agents write the Execution steps column in the PRD's Execution Table — format, granularity, dependency notation, and worked examples per concern type
type: reference
---

# Execution Steps Guide

You are filling in the **Execution steps** column for every row in the Execution Table where the **Agent** column matches your agent name. Read this guide before writing a single step.

## Step format

Each execution step is one imperative sentence. Write steps as a numbered list inside the table cell.

```
1. Verb the thing — optional file/table/component reference
2. Verb the next thing
3. ...
```

**Rules:**
- Start with an imperative verb: *Define*, *Add*, *Create*, *Extend*, *Migrate*, *Implement*, *Wire*, *Write*, *Remove*, *Update*.
- Name the specific file, table, endpoint, component, or class where the work lands — do not write vague steps like "update the backend" or "add tests."
- One step = one discrete deliverable a reviewer can verify in isolation. Too coarse: "implement the feature." Too granular: "add a closing brace." Right: "Add `user_id` (FK) column to `streaks` table in migration `0042_add_streaks`."
- Keep each step to one line. If a step needs a qualifier, append it with an em dash: `1. Define POST /goals — request body: { userId, date, targetCount }`.

## Concern-specific patterns

Use these as starting points. Adapt to what the codebase scan revealed in Step 4.

### API contract

```
1. Define <METHOD> <path> — request: <shape>, response: <shape>
2. Add OpenAPI / GraphQL schema entry for <operation>
3. Wire route to <ControllerClass>.<method>()
4. Add input validation for <field constraints>
```

### Schema migration

```
1. Create migration <migration-id> — add table/column: <name>, type, constraints
2. Add ORM model / entity definition for <ModelName>
3. Add index on <column(s)> — reason: <query pattern>
4. Write rollback script to drop <table/column>
```

### Authentication

```
1. Extend <middleware/guard> to validate <token type> for <route group>
2. Add <claim/scope> to token payload — issued at <point in auth flow>
3. Wire refresh logic for <expiry scenario>
4. Update auth integration test fixtures
```

### Webhook / hook

```
1. Emit <event-name> from <service/handler> — payload: <shape>
2. Register <hook-name> at <extension point> in <framework/platform>
3. Add idempotency key to prevent duplicate delivery
4. Write consumer stub / test handler for <event-name>
```

### Client implementation

```
1. Implement <ScreenName / ComponentName> — state: <what it holds>, actions: <what it triggers>
2. Bind to <ViewModel / store selector> for <data slice>
3. Handle <loading | error | empty> states with <UI pattern>
4. Add <navigation route / deep link> for <entry point>
```

### Tests

```
1. Unit test <function/class> — cover: <happy path>, <edge case>, <error case>
2. Integration test <endpoint or flow> — seed: <fixture>, assert: <response shape and status>
3. E2E test <user journey> on <platform / environment>
4. Add fixture / factory for <model> used across test suite
```

## Cross-agent dependencies

When one of your steps requires output from another agent's row, note it explicitly:

```
1. Define POST /goals — blocked by: eng-backend F1 API contract
```

Use `blocked by: <agent-name> <Feature — Concern>` as the notation. Do not leave an implicit dependency — if your client implementation step needs an API endpoint that a different agent owns, say so.

## Worked example

PRD feature F2: Track streak. The following rows are assigned to `eng-backend`:

| Feature | Execution steps | Agent |
|---------|----------------|-------|
| F2: Track streak — Schema migration | 1. Create migration `0043_add_streaks` — add `streaks` table: `id UUID PK`, `user_id FK`, `date DATE`, `count INT`<br>2. Add `Streak` ORM model with `user` relation<br>3. Add composite index on `(user_id, date)` — supports per-user daily lookup<br>4. Write rollback to drop `streaks` table | eng-backend |

(The same shape repeats per concern — one imperative, file-anchored step per numbered line; API-contract, Tests, etc. follow the concern patterns above.)

## Quality gate

Every row where your agent name appears in the **Agent** column must have its **Execution steps** filled in before you return your output. A row with a blank Execution steps cell is a hard failure.

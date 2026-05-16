# msg-commit — Protocol

## Subject rules

Compose `type(scope?): description` applying all rules:

- Imperative mood (`add`, `fix`, `remove` — not `added`, `fixes`, `removing`)
- Lowercase first word of description
- No trailing period
- Prefer ≤50 chars total; hard cap 72
- No emoji, no AI attribution, no co-author lines

## Examples

### Standard commits

```
feat(auth): add OAuth2 login support
fix(api): handle null response from /users endpoint
chore: update dependencies
refactor(db): extract query builder to separate module
perf(cache): replace Redis with in-memory LRU
docs: add API authentication guide
test(auth): add unit tests for token refresh logic
build: upgrade webpack to v5
ci: add lint step to GitHub Actions
style(nav): fix button alignment
revert: "feat(auth): add OAuth2 login support"
```

### Breaking change

```
refactor(api): rename user_id to userId

BREAKING CHANGE: user_id field renamed to userId across all endpoints
```

### Scope omitted (cross-cutting change)

```
chore: update all npm dependencies
refactor: migrate string utils to shared module
```

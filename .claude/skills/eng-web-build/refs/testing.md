# Testing Strategies — eng-web-build

## Stack defaults

| Layer | Tool | Config |
|-------|------|--------|
| Unit / integration | Jest + React Testing Library | `jest.config.ts`, `src/setupTests.ts` |
| E2E | Playwright | `playwright.config.ts` |
| Visual regression | Chromatic (Storybook) | `.storybook/`, `chromatic.yml` |

If the project uses a different stack, defer to what is already configured — do not introduce a new test runner without raising it as a P1.

---

## Unit testing

**What to unit test**: pure functions, custom hooks, utility modules, isolated components with no external dependencies.

**What not to unit test**: Next.js routing, `fetch` calls (mock at the boundary instead), third-party library internals.

```ts
// Good: testing a pure utility
test('formatCurrency formats to two decimal places', () => {
  expect(formatCurrency(1234.5)).toBe('$1,234.50');
});
```

**React Testing Library rules**:
- Query by role, label, or text — not by CSS class or test ID unless there is no semantic alternative.
- Do not test implementation details (internal state, private methods).
- Prefer `userEvent` over `fireEvent` for interactions.

**Coverage**: aim for 100% on pure utilities and custom hooks. Do not chase coverage on component render paths — test behaviour, not lines.

---

## Integration testing

**What to integration test**: component trees that coordinate multiple sub-components, form submission flows, data-fetching components with mocked API responses.

**API mocking**: use `msw` (Mock Service Worker) to intercept fetch at the network layer — not `jest.mock` on fetch modules. This catches mismatches between the mock and the real contract.

```ts
// msw handler
rest.get('/api/users', (req, res, ctx) => res(ctx.json(mockUsers)));
```

**When to write**: for every user-facing flow that crosses more than one component boundary. Prioritise flows that are risky to break silently (auth, checkout, form validation).

**Avoid**: testing the same behaviour at both unit and integration level. If covered by integration, delete the unit test.

---

## E2E testing

**What to E2E test**: critical happy paths and the most common failure paths. Not exhaustive coverage — E2E is expensive.

**Scope per feature**:
1. The primary success flow (user completes the action end-to-end).
2. The primary failure case (invalid input, API error).
3. Any cross-page or cross-tab interaction the feature introduces.

```ts
// Playwright example
test('user can submit the contact form', async ({ page }) => {
  await page.goto('/contact');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByRole('button', { name: 'Submit' }).click();
  await expect(page.getByText('Message sent')).toBeVisible();
});
```

**Selectors**: prefer `getByRole`, `getByLabel`, `getByText`. Use `data-testid` only for elements with no accessible name. Never select by CSS class.

**Fixtures and state**: use Playwright's `storageState` to persist auth tokens between tests. Seed test data via the API, not by manipulating the database directly.

---

## Regression testing

**Visual regression**: run Chromatic on every PR if Storybook is set up. A visual diff that cannot be explained by the feature change is a regression — do not auto-accept without review.

**Snapshot testing**: avoid Jest snapshots for component trees — they break on any markup change and rarely catch real regressions. Use snapshots only for serialised data (API response shapes, config objects).

**Before marking a step complete**: confirm that existing tests still pass after the step's changes. Do not advance to the next step with a failing test suite unless the user explicitly accepts the failure as a known gap.

**Regression gate rule**: if a step breaks an existing test:
- P0 if the broken test covers the same feature or a dependency of the current step.
- P1 if the broken test covers an unrelated feature.
- In both cases, surface the failure and present options before continuing.

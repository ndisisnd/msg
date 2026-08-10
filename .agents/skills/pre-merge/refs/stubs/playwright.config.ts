// Minimal Playwright config — scaffolded by `/pre-merge --init`.
// Just enough for the e2e component to run: one project, a tests dir, list reporter.
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  reporter: "list",
  use: { trace: "on-first-retry" },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});

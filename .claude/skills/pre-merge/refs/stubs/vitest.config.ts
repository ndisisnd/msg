// Minimal Vitest config — scaffolded by `/pre-merge --doctor`.
// Emits a json-summary so the coverage bucket can read totals.
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    coverage: { reporter: ["text", "json-summary"], reportsDirectory: "coverage" },
  },
});

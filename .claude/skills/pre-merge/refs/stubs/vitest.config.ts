// Minimal Vitest config — scaffolded by pre-merge setup.
// Emits a json-summary so the coverage component can read totals.
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    coverage: { reporter: ["text", "json-summary"], reportsDirectory: "coverage" },
  },
});

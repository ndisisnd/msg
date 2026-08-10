// Minimal ESLint flat config — scaffolded by `/pre-merge --init` for the
// config-missing gap flavor. Recommended ruleset only; tune to taste.
// Requires: eslint >= 9 and @eslint/js (installed alongside this stub).
import js from "@eslint/js";

export default [
  js.configs.recommended,
  { ignores: ["dist/", "build/", "coverage/", "node_modules/"] },
];

import playwright from "eslint-plugin-playwright"
import js from "@eslint/js"

import sharedRules from "./eslint.rules.mjs"

export default [{
  ...js.configs.recommended,
  ...playwright.configs["flat/recommended"],
  ignores: ["test/e2e/test-results/**"],
  files: ["*.js", "*.mjs", "test/e2e/**"],

  rules: {
    ...playwright.configs["flat/recommended"].rules,
    ...sharedRules
  },
}]

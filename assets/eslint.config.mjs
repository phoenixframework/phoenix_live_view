import jest from "eslint-plugin-jest"
import globals from "globals"
import js from "@eslint/js"

import sharedRules from "../eslint.rules.mjs"

export default [{
  ...js.configs.recommended,

  plugins: {
    jest,
  },

  files: ["js/**/*.js", "test/**/*.js"],
  ignores: ["coverage/**"],

  languageOptions: {
    globals: {
      ...globals.browser,
      ...jest.environments.globals.globals,
      global: "writable",
    },

    ecmaVersion: 12,
    sourceType: "module",
  },

  rules: {
    ...sharedRules
  },
}]

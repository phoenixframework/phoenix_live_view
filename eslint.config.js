import playwright from "eslint-plugin-playwright"
import jest from "eslint-plugin-jest"
import globals from "globals"
import js from "@eslint/js"
import tseslint from "typescript-eslint"

const sharedRules = {
  "@typescript-eslint/no-unused-vars": ["error", {
    argsIgnorePattern: "^_",
    varsIgnorePattern: "^_",
  }],

  "@typescript-eslint/no-unused-expressions": "off",
  "@typescript-eslint/no-explicit-any": "off",

  "no-useless-escape": "off",
  "no-cond-assign": "off",
  "no-case-declarations": "off",
  "prefer-const": "off"
}

export default tseslint.config([
  {
    ignores: [
      "assets/js/types/",
      "test/e2e/test-results/",
      "coverage/",
      "cover/",
      "priv/",
      "deps/",
      "doc/"
    ]
  },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    files: ["*.js", "*.ts", "test/e2e/**"],
    ignores: ["assets/**"],
    
    plugins: {
      ...playwright.configs["flat/recommended"].plugins,
    },

    rules: {
      ...playwright.configs["flat/recommended"].rules,
      ...sharedRules
    },
  },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    files: ["assets/**/*.{js,ts}"],
    ignores: ["test/e2e/**"],

    plugins: {
      jest,
    },

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
      ...sharedRules,
    },
  }])

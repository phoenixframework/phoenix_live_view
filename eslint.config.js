import playwright from "eslint-plugin-playwright"
import jest from "eslint-plugin-jest"
import globals from "globals"
import js from "@eslint/js"
import stylistic from "@stylistic/eslint-plugin"
import tseslint from "typescript-eslint"

const sharedRules = {
  "@stylistic/indent": ["error", 2, {
    SwitchCase: 1,
  }],
    
  "@stylistic/linebreak-style": ["error", "unix"],
  "@stylistic/quotes": ["error", "double"],
  "@stylistic/semi": ["error", "never"],
    
  "@stylistic/object-curly-spacing": ["error", "never", {
    objectsInObjects: false,
    arraysInObjects: false,
  }],
    
  "@stylistic/array-bracket-spacing": ["error", "never"],
    
  "@stylistic/comma-spacing": ["error", {
    before: false,
    after: true,
  }],
    
  "@stylistic/computed-property-spacing": ["error", "never"],
    
  "@stylistic/space-before-blocks": ["error", {
    functions: "never",
    keywords: "never",
    classes: "always",
  }],
    
  "@stylistic/keyword-spacing": ["error", {
    overrides: {
      if: {
        after: false,
      },
    
      for: {
        after: false,
      },
    
      while: {
        after: false,
      },
    
      switch: {
        after: false,
      },
    },
  }],
    
  "@stylistic/eol-last": ["error", "always"],

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
      "@stylistic": stylistic,
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
      "@stylistic": stylistic,
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

import playwright from "eslint-plugin-playwright"
import jest from "eslint-plugin-jest"
import globals from "globals"
import js from "@eslint/js"
import stylisticJs from "@stylistic/eslint-plugin"
import tseslint from "typescript-eslint"

const sharedRules = {
  "@stylistic/js/indent": ["error", 2, {
    SwitchCase: 1,
  }],
    
  "@stylistic/js/linebreak-style": ["error", "unix"],
  "@stylistic/js/quotes": ["error", "double"],
  "@stylistic/js/semi": ["error", "never"],
    
  "@stylistic/js/object-curly-spacing": ["error", "never", {
    objectsInObjects: false,
    arraysInObjects: false,
  }],
    
  "@stylistic/js/array-bracket-spacing": ["error", "never"],
    
  "@stylistic/js/comma-spacing": ["error", {
    before: false,
    after: true,
  }],
    
  "@stylistic/js/computed-property-spacing": ["error", "never"],
    
  "@stylistic/js/space-before-blocks": ["error", {
    functions: "never",
    keywords: "never",
    classes: "always",
  }],
    
  "@stylistic/js/keyword-spacing": ["error", {
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
    
  "@stylistic/js/eol-last": ["error", "always"],

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
      "assets/js/dist/",
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
    files: ["*.js", "*.mjs", "test/e2e/**"],
    ignores: ["assets/**"],
    
    plugins: {
      ...playwright.configs["flat/recommended"].plugins,
      "@stylistic/js": stylisticJs,
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
      "@stylistic/js": stylisticJs,
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

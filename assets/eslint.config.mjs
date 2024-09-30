import jest from "eslint-plugin-jest"
import globals from "globals"
import path from "node:path"
import {fileURLToPath} from "node:url"
import js from "@eslint/js"
import {FlatCompat} from "@eslint/eslintrc"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const compat = new FlatCompat({
  baseDirectory: __dirname,
  recommendedConfig: js.configs.recommended,
  allConfig: js.configs.all
})

export default [...compat.extends("eslint:recommended"), {
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
    indent: ["error", 2, {
      SwitchCase: 1,
    }],

    "linebreak-style": ["error", "unix"],
    quotes: ["error", "double"],
    semi: ["error", "never"],

    "object-curly-spacing": ["error", "never", {
      objectsInObjects: false,
      arraysInObjects: false,
    }],

    "array-bracket-spacing": ["error", "never"],

    "comma-spacing": ["error", {
      before: false,
      after: true,
    }],

    "computed-property-spacing": ["error", "never"],

    "space-before-blocks": ["error", {
      functions: "never",
      keywords: "never",
      classes: "always",
    }],

    "keyword-spacing": ["error", {
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

    "eol-last": ["error", "always"],

    "no-unused-vars": ["error", {
      argsIgnorePattern: "^_",
      varsIgnorePattern: "^_",
    }],

    "no-useless-escape": "off",
    "no-cond-assign": "off",
    "no-case-declarations": "off",
  },
}]

// playwright.config.js
// @ts-check
import {devices} from "@playwright/test"
import {dirname, resolve} from "node:path"
import {fileURLToPath} from "node:url"

const __dirname = dirname(fileURLToPath(import.meta.url))

/** @type {import("@playwright/test").ReporterDescription} */
const monocartReporter = ["monocart-reporter", {
  name: "Phoenix LiveView",
  outputFile: "./test-results/report.html",
  coverage: {
    reports: [
      ["raw", {outputDir: "./raw"}],
      ["v8"],
    ],
    entryFilter: (entry) => entry.url.indexOf("phoenix_live_view.esm.js") !== -1,
  }
}]

/** @type {import("@playwright/test").PlaywrightTestConfig} */
const config = {
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? [["github"], ["html"], ["dot"], monocartReporter] : [["list"], monocartReporter],
  use: {
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    baseURL: "http://localhost:4004/",
    ignoreHTTPSErrors: true,
  },
  webServer: {
    command: "npm run e2e:server",
    url: "http://127.0.0.1:4004/health",
    reuseExistingServer: !process.env.CI,
    stdout: "pipe",
    stderr: "pipe",
  },
  projects: [
    {
      name: "chromium",
      use: {...devices["Desktop Chrome"]},
    },
    {
      name: "firefox",
      use: {...devices["Desktop Firefox"]},
    },
    {
      name: "webkit",
      use: {...devices["Desktop Safari"]},
    }
  ],
  outputDir: "test-results",
  globalTeardown: resolve(__dirname, "./teardown.js")
}

export default config

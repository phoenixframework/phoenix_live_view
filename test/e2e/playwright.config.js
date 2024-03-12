// playwright.config.js
// @ts-check
const { devices } = require("@playwright/test");

/** @type {import("@playwright/test").PlaywrightTestConfig} */
const config = {
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? [["github"], ["html"]] : "list",
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
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "firefox",
      use: { ...devices["Desktop Firefox"] },
    },
    {
      name: "webkit",
      use: { ...devices["Desktop Safari"] },
    }
  ],
  outputDir: "test-results"
};

module.exports = config;

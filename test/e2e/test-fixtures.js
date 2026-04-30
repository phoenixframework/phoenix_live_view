// see https://github.com/cenfun/monocart-reporter?tab=readme-ov-file#global-coverage-report
import { test as testBase, expect } from "@playwright/test";
import { addCoverageReport } from "monocart-reporter";

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const liveViewSourceMap = JSON.parse(
  fs
    .readFileSync(
      path.resolve(
        __dirname + "../../../priv/static/phoenix_live_view.esm.js.map",
      ),
    )
    .toString("utf-8"),
);

const pageChecks = async (page, ignoreJSErrors) => {
  // this can be used to check for any console messages that are not expected;
  // in a LV app, I'd add a unique ID warning check here
  // const consoleMessages: Array<string> = [];
  // page.on("console", async (msg) => { consoleMessages.push(msg.text()) });
  const unhandledErrors = [];
  page.on("pageerror", (exception) => {
    unhandledErrors.push(exception);
  });

  const cleanup = async () => {
    if (!ignoreJSErrors) {
      testBase
        .expect(unhandledErrors, "Detected an unhandled JavaScript Error!")
        .toEqual([]);
    }

    await expect(page.locator("[data-phx-skip]")).toHaveCount(0);
  };

  return { cleanup };
};

const test = testBase.extend({
  ignoreJSErrors: [false, { option: true }],

  page: async ({ page, ignoreJSErrors }, use) => {
    const { cleanup } = await pageChecks(page, ignoreJSErrors);
    await use(page);
    await cleanup();
  },

  autoTestFixture: [
    async ({ page, browserName }, use) => {
      // NOTE: it depends on your project name
      const isChromium = browserName === "chromium";

      // console.log("autoTestFixture setup...");
      // coverage API is chromium only
      if (isChromium) {
        await Promise.all([
          page.coverage.startJSCoverage({
            resetOnNavigation: false,
          }),
          page.coverage.startCSSCoverage({
            resetOnNavigation: false,
          }),
        ]);
      }

      await use("autoTestFixture");

      // console.log("autoTestFixture teardown...");
      if (isChromium) {
        const [jsCoverage, cssCoverage] = await Promise.all([
          page.coverage.stopJSCoverage(),
          page.coverage.stopCSSCoverage(),
        ]);
        jsCoverage.forEach((entry) => {
          // read sourcemap for the phoenix_live_view.esm.js manually
          if (entry.url.endsWith("phoenix_live_view.esm.js")) {
            entry.sourceMap = liveViewSourceMap;
          }
        });
        const coverageList = [...jsCoverage, ...cssCoverage];
        // console.log(coverageList.map((item) => item.url));
        await addCoverageReport(coverageList, test.info());
      }
    },
    {
      scope: "test",
      auto: true,
    },
  ],
});
export { test, expect };

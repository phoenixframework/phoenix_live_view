// see https://github.com/cenfun/monocart-reporter?tab=readme-ov-file#global-coverage-report
import {test as testBase, expect} from "@playwright/test"
import {addCoverageReport} from "monocart-reporter"

import fs from "node:fs"
import path from "node:path"

const liveViewSourceMap = JSON.parse(fs.readFileSync(path.resolve(__dirname + "../../../priv/static/phoenix_live_view.esm.js.map")).toString("utf-8"))

const test = testBase.extend({
  autoTestFixture: [async ({page, browserName}, use) => {

    // NOTE: it depends on your project name
    const isChromium = browserName === "chromium"

    // console.log("autoTestFixture setup...");
    // coverage API is chromium only
    if(isChromium){
      await Promise.all([
        page.coverage.startJSCoverage({
          resetOnNavigation: false
        }),
        page.coverage.startCSSCoverage({
          resetOnNavigation: false
        })
      ])
    }

    await use("autoTestFixture")

    // console.log("autoTestFixture teardown...");
    if(isChromium){
      const [jsCoverage, cssCoverage] = await Promise.all([
        page.coverage.stopJSCoverage(),
        page.coverage.stopCSSCoverage()
      ])
      jsCoverage.forEach((entry) => {
        // read sourcemap for the phoenix_live_view.esm.js manually
        if(entry.url.endsWith("phoenix_live_view.esm.js")){
          entry.sourceMap = liveViewSourceMap
        }
      })
      const coverageList = [...jsCoverage, ...cssCoverage]
      // console.log(coverageList.map((item) => item.url));
      await addCoverageReport(coverageList, test.info())
    }

  }, {
    scope: "test",
    auto: true
  }]
})
export {test, expect}

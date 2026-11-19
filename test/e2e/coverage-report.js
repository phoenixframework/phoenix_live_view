// The global coverage report that monocart-reporter built from test-fixtures.js
// (see https://github.com/cenfun/monocart-reporter?tab=readme-ov-file#global-coverage-report):
// the Chromium tests dump their JS and CSS coverage (Phoenix.LiveViewTest.E2E.Case), and this
// adds the dumps to a report with the same options, in test-results/coverage.
import { CoverageReport } from "monocart-coverage-reports";

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dumpDir = path.resolve(__dirname, "test-results/coverage-dumps");
const liveViewSourceMap = JSON.parse(
  fs
    .readFileSync(
      path.resolve(__dirname, "../../priv/static/phoenix_live_view.esm.js.map"),
    )
    .toString("utf-8"),
);

const coverageReport = new CoverageReport({
  name: "Phoenix LiveView",
  outputDir: path.resolve(__dirname, "test-results/coverage"),
  reports: [["raw", { outputDir: "./raw" }], ["v8"]],
  entryFilter: (entry) => entry.url.indexOf("phoenix_live_view.esm.js") !== -1,
});

if (!fs.existsSync(dumpDir)) {
  console.log("No e2e coverage: run the e2e tests on Chromium first.");
  process.exit(0);
}

for (const file of fs.readdirSync(dumpDir)) {
  const coverageList = JSON.parse(
    fs.readFileSync(path.resolve(dumpDir, file)).toString("utf-8"),
  );
  coverageList.forEach((entry) => {
    // read sourcemap for the phoenix_live_view.esm.js manually
    if (entry.url.endsWith("phoenix_live_view.esm.js")) {
      entry.sourceMap = liveViewSourceMap;
    }
  });
  if (coverageList.length > 0) {
    await coverageReport.add(coverageList);
  }
}
await coverageReport.generate();
// the dumps are in the report now
fs.rmSync(dumpDir, { recursive: true });

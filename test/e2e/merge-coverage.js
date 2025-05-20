import { CoverageReport } from "monocart-coverage-reports";

const coverageOptions = {
  name: "Phoenix LiveView JS Coverage",
  inputDir: ["./coverage/raw", "./test/e2e/test-results/coverage/raw"],
  outputDir: "./cover/merged-js",
  reports: [["v8"], ["console-summary"]],
  sourcePath: (filePath) => {
    if (!filePath.startsWith("assets")) {
      return "assets/js/phoenix_live_view/" + filePath;
    } else {
      return filePath;
    }
  },
};
await new CoverageReport(coverageOptions).generate();

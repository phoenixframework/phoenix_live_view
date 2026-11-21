# End-to-end tests

This directory contains end-to-end tests that drive real browsers (Chromium, Firefox, WebKit)
against a LiveView server, with [playwright_ex](https://hex.pm/packages/playwright_ex), an Elixir
port of the Playwright client, on ExUnit.

- `test_helper.exs` defines and starts the server on port 4004 (`Phoenix.LiveViewTest.E2E.Endpoint`).
- `support/` holds the LiveViews under test, `Phoenix.LiveViewTest.E2E.Case` (`Playwright.Case`
  with the projects, the page checks, `request` and coverage) and `Phoenix.LiveViewTest.E2E.Utils`.
- `tests/` holds the tests.

## Running the tests

```bash
$ MIX_ENV=e2e mix deps.get
$ MIX_ENV=e2e mix playwright.install # the driver and the browsers
$ npm ci && mix assets.build            # the JS under test
$ MIX_ENV=e2e mix test                  # Chromium, Firefox and WebKit
$ PW_BROWSER=firefox MIX_ENV=e2e mix test
$ PW_BROWSER=webkit MIX_ENV=e2e mix test test/e2e/tests/streams.spec.exs:9
```

Each module runs once per browser (`parameterize:`), with `browser_name` in the context;
`PW_BROWSER` runs one. With all three, half the schedulers' modules run at once, and each browser
keeps that many warm (`config/e2e.exs`, `test_helper.exs`). Rerun the failures with
`mix test --failed` (CI does, twice). On Linux, `MIX_ENV=e2e mix playwright.install webkit
--with-deps` also installs the browser's system dependencies.

## Debugging

Failed tests keep a trace and a screenshot in `test-results/`. The failure prints how to open the
trace:

```bash
$ MIX_ENV=e2e mix playwright.cli show-trace test/e2e/test-results/<test>/trace.zip
```

To watch a test run, give the run headed, slowed-down browsers (merged over `config/e2e.exs`),
and the test no timeout if you `Page.pause/1` in it:

```elixir
# config/e2e.exs
config :playwright, :test, headless: false, launch_options: [slow_mo: 500]
```

```bash
$ MIX_ENV=e2e mix test test/e2e/tests/streams.spec.exs:9 --trace
```

## Coverage

On Chromium, each test dumps its JS and CSS coverage to `test-results/coverage-dumps`
(`PW_NO_COVERAGE=1` turns this off). `npm run e2e:coverage` adds the dumps up to the report in
`test-results/coverage`, whose raw data `npm run cover:merge` merges with the JS unit tests'.
`mix test --cover` exports the Elixir coverage.

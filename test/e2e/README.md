# End-to-end tests

This directory contains end-to-end tests that use the [Playwright](https://playwright.dev/)
test framework.
These tests use all three web engines (Chromium, Firefox, Webkit) and test the interaction
with an actual LiveView server.

## Running the tests

To run the tests, ensure that the npm dependencies are installed by running `npm install`, followed by `npx playwright install` in
the root of the repository. Then, run `npm run e2e:test` to run the tests.

This will execute the `npx playwright test` command in the `test/e2e` directory. Playwright
will start a LiveView server using the `MIX_ENV=e2e mix run test/e2e/test_helper.exs` command.

Playwright supports an [interactive UI mode](https://playwright.dev/docs/test-ui-mode) that
can be used to debug the tests. To run the tests in this mode, run `npm run e2e:test -- --ui`.

Tests can also be run in headed mode by passing the `--headed` flag. This is especially useful
in combination with running only specific tests, for example:

```bash
npm run e2e:test -- tests/streams.spec.js:9 --project chromium --headed
```

To step through a single test, pass `--debug`, which will automatically run the test in headed
mode:

```bash
npm run e2e:test -- tests/streams.spec.js:9 --project chromium --debug
```

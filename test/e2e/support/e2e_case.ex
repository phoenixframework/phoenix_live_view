defmodule Phoenix.LiveViewTest.E2E.Case do
  @moduledoc """
  The case of the e2e tests: `Playwright.Case` (the module's `browser` and `browser_name`, a
  `context` and a `page` per test), run once per project (`projects/0`: `chromium`, `firefox`
  and `webkit`, each with its desktop device; `PW_BROWSER=firefox` runs one), plus:

    * the page's checks after each test: no unhandled page errors (unless the test, its describe
      or its module is tagged `ignore_js_errors: true`) and no `[data-phx-skip]` left;
    * `request`, an API request context with the config's options, for the tests tagged
      `@tag :request`;
    * on Chromium, each test's JS and CSS coverage, dumped to `test/e2e/test-results/coverage-dumps`
      unless `PW_NO_COVERAGE` is set (`test/e2e/coverage-report.js` turns the dumps into a report).
  """

  import Playwright.Test.Assertions

  alias Playwright.{APIRequest, Coverage, Expect, Page, Promise}
  alias Playwright.Test.BrowserPool

  @projects [chromium: "Desktop Chrome", firefox: "Desktop Firefox", webkit: "Desktop Safari"]

  @doc "The config's `projects`: all browsers, or `PW_BROWSER`'s."
  def projects do
    name = System.get_env("PW_BROWSER", "")
    projects = for {project, _device} = p <- @projects, name in ["", "#{project}"], do: p

    if projects == [] do
      available = Enum.map_join(@projects, ", ", fn {project, _} -> ~s("#{project}") end)
      raise ArgumentError, ~s[Project(s) "#{name}" not found. Available projects: #{available}]
    end

    for {project, device} <- projects,
        do: Playwright.Test.parameters([name: "#{project}"] ++ Playwright.device(device))
  end

  defmacro __using__(opts) do
    quote do
      use Playwright.Case,
          Keyword.merge(
            [async: true, parameterize: Phoenix.LiveViewTest.E2E.Case.projects()],
            unquote(opts)
          )

      import Phoenix.LiveViewTest.E2E.Utils

      alias Playwright.{
        APIRequestContext,
        APIResponse,
        ConsoleMessage,
        Dialog,
        Download,
        Promise,
        Request,
        Route,
        WebSocketRoute
      }

      setup ctx do
        Phoenix.LiveViewTest.E2E.Case.page_fixture(ctx)
      end
    end
  end

  @doc false
  def page_fixture(%{browser: browser, page: page} = ctx) do
    # the errors outlive the test process, for the checks in on_exit
    {:ok, errors} = Agent.start(fn -> [] end)
    Page.on(page, :page_error, fn error -> Agent.update(errors, &(&1 ++ [error])) end)
    ignore_js_errors = Map.get(ctx, :ignore_js_errors, false)

    ExUnit.Callbacks.on_exit(fn ->
      unhandled_errors = Agent.get(errors, & &1)
      Agent.stop(errors)

      if not ignore_js_errors do
        assert(
          unhandled_errors == [],
          "Detected an unhandled JavaScript Error!"
        )
      end

      page |> Page.locator("[data-phx-skip]") |> Expect.to_have_count!(0)
    end)

    if ctx.browser_name == :chromium and !System.get_env("PW_NO_COVERAGE") do
      coverage_fixture(page)
    end

    # for the tests that take it (`@tag :request`), disposed at the end of the test
    if ctx[:request] == true do
      request =
        browser |> BrowserPool.playwright() |> Playwright.request() |> APIRequest.new_context!()

      %{request: request}
    else
      %{}
    end
  end

  @coverage_dir "test/e2e/test-results/coverage-dumps"

  # the coverage API is Chromium only
  defp coverage_fixture(page) do
    coverage = Page.coverage(page)

    Promise.all([
      Promise.async(fn -> Coverage.start_js_coverage!(coverage, reset_on_navigation: false) end),
      Promise.async(fn -> Coverage.start_css_coverage!(coverage, reset_on_navigation: false) end)
    ])
    |> Promise.await!()

    # registered after the page's checks, so it runs before them
    ExUnit.Callbacks.on_exit(fn ->
      [js_coverage, css_coverage] =
        Promise.all([
          Promise.async(fn -> Coverage.stop_js_coverage!(coverage) end),
          Promise.async(fn -> Coverage.stop_css_coverage!(coverage) end)
        ])
        |> Promise.await!()

      # coverage-report.js adds the source map of phoenix_live_view.esm.js and the report
      File.mkdir_p!(@coverage_dir)

      path =
        Path.join(@coverage_dir, "#{System.pid()}-#{System.unique_integer([:positive])}.json")

      File.write!(path, JSON.encode!(js_coverage ++ css_coverage))
    end)
  end
end

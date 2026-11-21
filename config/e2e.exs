import Config

config :logger, :level, :error

config :phoenix_live_view, :root_tag_attribute, "phx-r"

# the browser context options and the output dir (the projects: `E2E.Case.projects/0`)
config :playwright, :test,
  base_url: "http://localhost:4004/",
  ignore_https_errors: true,
  trace: :retain_on_failure,
  screenshot: :only_on_failure,
  output_dir: "test/e2e/test-results"

# All browsers in one run: test_helper.exs runs half the schedulers' modules at once, and each
# browser keeps that many workers warm, so a module never restarts another browser's.
if System.get_env("PW_BROWSER", "") == "" do
  config :playwright, :test, workers: 3 * max(div(System.schedulers_online(), 2), 1)
end

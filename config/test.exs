import Config

config :logger, :level, :debug
config :logger, :default_handler, false

config :phoenix_live_view, enable_expensive_runtime_checks: true

config :phoenix_live_view, :test_warnings, missing_form_id: :ignore

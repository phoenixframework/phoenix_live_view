import Config

config :logger, :level, :debug
config :logger, :default_handler, false

config :phoenix_live_view, enable_expensive_runtime_checks: true

config :phoenix_live_view, Phoenix.LiveViewTest, missing_form_id_as_error: false

import Config

config :logger, :level, :debug
config :logger, :default_handler, false

config :phoenix_live_view, enable_expensive_runtime_checks: true

# Disable applying the data-phx-css attribute so that tests that check
# against rendered output that are completely irrelevant to the data-phx-css
# attribute are not polluted by it.
config :phoenix_live_view, apply_css_scope_attribute: false

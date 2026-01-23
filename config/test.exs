import Config

config :logger, :level, :debug
config :logger, :default_handler, false

config :phoenix_live_view, enable_expensive_runtime_checks: true

# Disable :root_tag_attribute so the majority of the tests
# are not polluted by it. It will be explicitly re-enabled for
# tests related to :root_tag_attribute functionality.
config :phoenix_live_view, :root_tag_attribute, nil

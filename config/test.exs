import Config

config :logger, :level, :debug
config :logger, :default_handler, false

# we still support 1.14, silence logs in tests
if Version.match?(System.version(), "< 1.15.0") do
  config :logger, :backends, []
end

config :phoenix_live_view, enable_expensive_runtime_checks: true

use Mix.Config

config :phoenix, :json_library, Jason
config :phoenix, :trim_on_html_eex_engine, false
config :logger, :level, :debug
config :logger, :backends, []
config :esbuild,
  version: "0.12.15",
  default: [
    args: ~w(./js/phoenix_live_view --bundle --sourcemap --format=esm --outfile=../priv/static/phoenix_live_view.js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

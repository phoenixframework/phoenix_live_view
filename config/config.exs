use Mix.Config

config :phoenix, :json_library, Jason
config :phoenix, :trim_on_html_eex_engine, false
config :logger, :level, :debug
config :logger, :backends, []


esbuild_base =  [
  cd: Path.expand("../assets", __DIR__),
  env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
]

config :esbuild,
  version: "0.12.15",
  module: esbuild_base ++ [args: ~w(./js/phoenix_live_view --bundle --format=esm --sourcemap --outfile=../priv/static/phoenix_live_view.esm.js)],
  cdn: esbuild_base ++ [args: ~w(./js/phoenix_live_view --bundle --format=iife --global-name=Phoenix --outfile=../priv/static/phoenix_live_view.js)],
  cdn_min: esbuild_base ++ [args: ~w(./js/phoenix_live_view --bundle --format=iife --global-name=Phoenix --minify --outfile=../priv/static/phoenix_live_view.min.js)]

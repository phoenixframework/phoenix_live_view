use Mix.Config

config :phoenix,
  json_library: Jason,
  template_engines: [leex: Phoenix.LiveView.Engine]

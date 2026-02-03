import Config

config :phoenix_live_view, Phoenix.LiveView.HTMLFormatter,
  macro_component_handler: {Phoenix.LiveView.Prettier, :format, []}

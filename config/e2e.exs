import Config

config :logger, :level, :error

config :phoenix_live_view, :root_tag_attribute, "phx-r"

config :phoenix_live_view, Phoenix.LiveView.ColocatedCSS,
  scoper: Phoenix.LiveViewTest.Support.CSSScoper

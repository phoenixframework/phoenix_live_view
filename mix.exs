defmodule Phoenix.LiveView.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_live_view,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Phoenix.LiveView.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, github: "phoenixframework/phoenix", override: true},
      {:phoenix_html, github: "phoenixframework/phoenix_html", override: true},
      {:live_eex, github: "josevalim/live_eex"},
      {:jason, "~> 1.0", optional: true}
    ]
  end
end

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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.4-rc"},
      {:phoenix_html, "~> 2.11"},
    ]
  end
end

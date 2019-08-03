defmodule Phoenix.LiveView.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_live_view,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      # {:phoenix, "~> 1.4.3"},
      {:phoenix, "~> 1.4.8"},
      {:phoenix_html, "~> 2.13.2"},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.20.1", only: :docs},
    ]
  end
end

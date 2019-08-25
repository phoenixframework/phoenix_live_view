defmodule Phoenix.LiveView.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_live_view,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env),
      package: package(),
      deps: deps(),
      source_url: "https://github.com/phoenixframework/phoenix_live_view",
      homepage_url: "http://www.phoenixframework.org",
      description: """
      Rich, real-time user experiences with server-rendered HTML
      """
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
      {:phoenix, "~> 1.4.9"},
      {:phoenix_html, "~> 2.13.2"},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.20.1", only: :docs},
    ]
  end

  defp package do
    [
      maintainers: [
        "Chris McCord", "José Valim", "Gary Rennie", "Alex Garibay", "Scott Newcomer"
      ],
      licenses: ["MIT"],
      links: %{github: "https://github.com/phoenixframework/phoenix_live_view"},
      files: ~w(assets lib priv) ++
        ~w(CHANGELOG.md LICENSE.md mix.exs package.json README.md)
    ]
  end
end

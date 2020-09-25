defmodule Phoenix.LiveView.MixProject do
  use Mix.Project

  @version "0.14.7"

  def project do
    [
      app: :phoenix_live_view,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: compilers(Mix.env()),
      package: package(),
      xref: [exclude: [Floki]],
      deps: deps(),
      docs: docs(),
      name: "Phoenix LiveView",
      homepage_url: "http://www.phoenixframework.org",
      description: """
      Rich, real-time user experiences with server-rendered HTML
      """
    ]
  end

  defp compilers(:test), do: [:phoenix] ++ Mix.compilers()
  defp compilers(_), do: Mix.compilers()

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {Phoenix.LiveView.Application, []}
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.5.3"},
      {:phoenix_html, "~> 2.14"},
      {:telemetry, "~> 0.4.2 or ~> 0.5"},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.22", only: :docs},
      {:floki, "~> 0.27.0", only: :test},
      {:html_entities, ">= 0.0.0", only: :test}
    ]
  end

  defp docs do
    [
      main: "Phoenix.LiveView",
      source_ref: "v#{@version}",
      source_url: "https://github.com/phoenixframework/phoenix_live_view",
      extra_section: "GUIDES",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules()
    ]
  end

  defp extras do
    [
      "guides/introduction/installation.md",
      "guides/client/bindings.md",
      "guides/client/form-bindings.md",
      "guides/client/dom-patching.md",
      "guides/client/js-interop.md",
      "guides/server/assigns-eex.md",
      "guides/server/error-handling.md",
      "guides/server/live-layouts.md",
      "guides/server/live-navigation.md",
      "guides/server/security-model.md",
      "guides/server/telemetry.md",
      "guides/server/using-gettext.md"
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      "Server-side features": ~r/guides\/server\/.?/,
      "Client-side integration": ~r/guides\/client\/.?/
    ]
  end

  defp groups_for_modules do
    [
      "Live EEx Engine": [
        Phoenix.LiveView.Engine,
        Phoenix.LiveView.Component,
        Phoenix.LiveView.Rendered,
        Phoenix.LiveView.Comprehension
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Chris McCord", "José Valim", "Gary Rennie", "Alex Garibay", "Scott Newcomer"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/phoenixframework/phoenix_live_view"},
      files:
        ~w(assets/js lib priv) ++
          ~w(CHANGELOG.md LICENSE.md mix.exs package.json README.md)
    ]
  end
end

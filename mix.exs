defmodule Phoenix.LiveView.MixProject do
  use Mix.Project

  @version "0.18.18"

  def project do
    [
      app: :phoenix_live_view,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_options: [docs: true],
      package: package(),
      xref: [exclude: [Floki]],
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      name: "Phoenix LiveView",
      homepage_url: "http://www.phoenixframework.org",
      description: """
      Rich, real-time user experiences with server-rendered HTML
      """
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Phoenix.LiveView.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.6.15 or ~> 1.7.0"},
      {:phoenix_view, "~> 2.0", optional: true},
      {:phoenix_template, "~> 1.0"},
      {:phoenix_html, "~> 3.3"},
      {:esbuild, "~> 0.2", only: :dev},
      {:telemetry, "~> 0.4.2 or ~> 1.0"},
      {:jason, "~> 1.0", optional: true},
      {:floki, "~> 0.30.0", only: :test},
      {:ex_doc, "~> 0.29", only: :docs},
      {:makeup_eex, ">= 0.1.1", only: :docs},
      {:html_entities, ">= 0.0.0", only: :test},
      {:phoenix_live_reload, "~> 1.4.1", only: :test}
    ]
  end

  defp docs do
    [
      main: "Phoenix.Component",
      source_ref: "v#{@version}",
      source_url: "https://github.com/phoenixframework/phoenix_live_view",
      extra_section: "GUIDES",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules(),
      groups_for_functions: [
        Components: &(&1[:type] == :component),
        Macros: &(&1[:type] == :macro)
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10.0.2/dist/mermaid.esm.min.mjs';
    mermaid.initialize({
      securityLevel: 'loose',
      theme: 'base'
    });
    </script>
    <style>
    code.mermaid text.flowchartTitleText {
      fill: var(--textBody) !important;
    }
    code.mermaid g.cluster > rect {
      fill: var(--background) !important;
      stroke: var(--neutralBackground) !important;
    }
    code.mermaid g.cluster[id$="__transparent"] > rect {
      fill-opacity: 0 !important;
      stroke: none !important;
    }
    code.mermaid g.nodes span.nodeLabel > em {
      font-style: normal;
      background-color: white;
      opacity: 0.5;
      padding: 1px 2px;
      border-radius: 5px;
    }
    code.mermaid g.edgePaths > path {
      stroke: var(--textBody) !important;
    }
    code.mermaid g.edgeLabels span.edgeLabel:not(:empty) {
      background-color: var(--textBody) !important;
      padding: 3px 5px !important;
      border-radius:25%;
      color: var(--background) !important;
    }
    code.mermaid .marker {
      fill: var(--textBody) !important;
      stroke: var(--textBody) !important;
    }
    </style>
    """
  end

  defp before_closing_body_tag(_), do: ""

  defp extras do
    [
      "CHANGELOG.md",
      "guides/introduction/installation.md",
      "guides/client/bindings.md",
      "guides/client/form-bindings.md",
      "guides/client/dom-patching.md",
      "guides/client/js-interop.md",
      "guides/client/uploads-external.md",
      "guides/server/assigns-eex.md",
      "guides/server/error-handling.md",
      "guides/server/live-layouts.md",
      "guides/server/live-navigation.md",
      "guides/server/security-model.md",
      "guides/server/telemetry.md",
      "guides/server/uploads.md",
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
    # Ungrouped Modules:
    #
    # Phoenix.Component
    # Phoenix.LiveComponent
    # Phoenix.LiveView
    # Phoenix.LiveView.Controller
    # Phoenix.LiveView.JS
    # Phoenix.LiveView.Router
    # Phoenix.LiveViewTest

    [
      Configuration: [
        Phoenix.LiveView.HTMLFormatter,
        Phoenix.LiveView.Logger,
        Phoenix.LiveView.Socket
      ],
      "Testing structures": [
        Phoenix.LiveViewTest.Element,
        Phoenix.LiveViewTest.Upload,
        Phoenix.LiveViewTest.View
      ],
      "Upload structures": [
        Phoenix.LiveView.UploadConfig,
        Phoenix.LiveView.UploadEntry
      ],
      "Plugin API": [
        Phoenix.LiveComponent.CID,
        Phoenix.LiveView.Engine,
        Phoenix.LiveView.TagEngine,
        Phoenix.LiveView.HTMLEngine,
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
      links: %{
        Changelog: "https://hexdocs.pm/phoenix_live_view/changelog.html",
        GitHub: "https://github.com/phoenixframework/phoenix_live_view"
      },
      files:
        ~w(assets/js lib priv) ++
          ~w(CHANGELOG.md LICENSE.md mix.exs package.json README.md .formatter.exs)
    ]
  end

  defp aliases do
    [
      "assets.build": ["esbuild module", "esbuild cdn", "esbuild cdn_min", "esbuild main"],
      "assets.watch": ["esbuild module --watch"]
    ]
  end
end

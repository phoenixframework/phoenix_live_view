defmodule Phoenix.LiveView.MixProject do
  use Mix.Project

  @version "1.1.0-dev"

  def project do
    [
      app: :phoenix_live_view,
      version: @version,
      elixir: "~> 1.14.1 or ~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_options: [docs: true],
      test_coverage: [summary: [threshold: 85], ignore_modules: coverage_ignore_modules()],
      xref: [exclude: [LazyHTML, LazyHTML.Tree]],
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: &docs/0,
      name: "Phoenix LiveView",
      homepage_url: "http://www.phoenixframework.org",
      description: """
      Rich, real-time user experiences with server-rendered HTML
      """,
      # ignore misnamed test file warnings for e2e support files
      test_ignore_filters: [&String.starts_with?(&1, "test/e2e/support")]
    ]
  end

  def cli do
    [preferred_envs: [docs: :docs]]
  end

  defp elixirc_paths(:e2e), do: ["lib", "test/support", "test/e2e/support"]
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
      {:plug, "~> 1.15"},
      {:phoenix_template, "~> 1.0"},
      {:phoenix_html, "~> 3.3 or ~> 4.0 or ~> 4.1"},
      {:telemetry, "~> 0.4.2 or ~> 1.0"},
      {:esbuild, "~> 0.2", only: :dev},
      {:phoenix_view, "~> 2.0", optional: true},
      {:jason, "~> 1.0", optional: true},
      {:lazy_html, "~> 0.1.0", optional: true},
      {:ex_doc, "~> 0.29", only: :docs},
      {:makeup_elixir, "~> 1.0.1 or ~> 1.1", only: :docs},
      {:makeup_eex, "~> 2.0", only: :docs},
      {:makeup_syntect, "~> 0.1.0", only: :docs},
      {:html_entities, ">= 0.0.0", only: :test},
      {:phoenix_live_reload, "~> 1.4", only: :test},
      {:phoenix_html_helpers, "~> 1.0", only: :test},
      {:bandit, "~> 1.5", only: :e2e},
      {:ecto, "~> 3.11", only: :e2e},
      {:phoenix_ecto, "~> 4.5", only: :e2e}
    ]
  end

  defp docs do
    [
      main: "welcome",
      source_ref: "v#{@version}",
      source_url: "https://github.com/phoenixframework/phoenix_live_view",
      extra_section: "GUIDES",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules(),
      groups_for_docs: [
        Components: &(&1[:type] == :component),
        Macros: &(&1[:type] == :macro)
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@11.6.0/dist/mermaid.min.js"></script>
    <script>
      let initialized = false;

      window.addEventListener("exdoc:loaded", () => {
        if (!initialized) {
          mermaid.initialize({
            startOnLoad: false,
            theme: document.body.className.includes("dark") ? "dark" : "default"
          });
          initialized = true;
        }

        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const graphDefinition = codeEl.textContent;
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            codeEl.innerHTML = svg;
            bindFunctions?.(codeEl);
          });
        }
      });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""

  defp extras do
    ["CHANGELOG.md"] ++
      Path.wildcard("guides/*/*.md") ++
      Path.wildcard("guides/cheatsheets/*.cheatmd")
  end

  defp groups_for_extras do
    [
      Introduction: ~r"guides/introduction/",
      "Server-side features": ~r"guides/server/",
      "Client-side integration": ~r"guides/client/",
      Cheatsheets: ~r"guides/cheatsheets/"
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
        Phoenix.LiveView.UploadEntry,
        Phoenix.LiveView.UploadWriter
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

  defp coverage_ignore_modules do
    [
      ~r/Phoenix\.LiveViewTest\.Support\..*/,
      ~r/Phoenix\.LiveViewTest\.E2E\..*/,
      ~r/Inspect\..*/
    ]
  end
end

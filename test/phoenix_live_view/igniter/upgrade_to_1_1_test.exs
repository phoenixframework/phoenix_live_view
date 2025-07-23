defmodule Phoenix.LiveView.Igniter.UpgradeTo1_1Test do
  use ExUnit.Case, async: false
  import Igniter.Test

  test "is idempotent" do
    full_project()
    |> run_upgrade(input: ["y\n", "y\n"])
    |> apply_igniter!()
    |> run_upgrade(input: ["y\n", "y\n"])
    |> assert_unchanged()
  end

  describe "dependency updates" do
    test "adds both dependencies" do
      test_project()
      |> run_upgrade()
      |> assert_has_patch("mix.exs", """
      + |      {:lazy_html, ">= 0.0.0", only: :test}
      """)
    end

    test "updates existing phoenix_live_view dependency" do
      test_project(
        files: %{
          "mix.exs" => """
          defmodule Test.MixProject do
            use Mix.Project

            def project do
              [
                app: :test,
                version: "0.1.0",
                elixir: "~> 1.14",
                deps: deps()
              ]
            end

            defp deps do
              [
                {:phoenix_live_view, "~> 0.20.0"}
              ]
            end
          end
          """
        }
      )
      |> run_upgrade(input: ["y\n", "n\n"])
      |> assert_has_patch("mix.exs", """
         16 + |      {:lazy_html, ">= 0.0.0", only: :test},
      """)
    end
  end

  describe "compiler configuration" do
    test "adds :phoenix_live_view compiler when compilers is not configured" do
      test_project()
      |> run_upgrade()
      |> assert_has_patch("mix.exs", """
      - |      deps: deps()
      + |      deps: deps(),
      + |      compilers: [:phoenix_live_view] ++ Mix.compilers()
      """)
    end

    test "does nothing when already configured" do
      test_project(
        files: %{
          "mix.exs" => """
          defmodule Test.MixProject do
            use Mix.Project

            def project do
              [
                app: :test,
                version: "0.1.0",
                elixir: "~> 1.14",
                compilers: [:phoenix_live_view] ++ Mix.compilers(),
                deps: deps()
              ]
            end

            defp deps do
              [
                {:lazy_html, ">= 0.0.0", only: :test}
              ]
            end
          end
          """
        }
      )
      |> run_upgrade()
      |> refute_has_warning()
      |> assert_unchanged()
    end

    test "warns when compiler configuration is complex" do
      test_project(
        files: %{
          "mix.exs" => """
          defmodule Test.MixProject do
            use Mix.Project

            def project do
              [
                app: :test,
                version: "0.1.0",
                elixir: "~> 1.14",
                compilers: custom_compilers(),
                deps: deps()
              ]
            end

            defp custom_compilers do
              [:gettext] ++ Mix.compilers()
            end

            defp deps do
              []
            end
          end
          """
        }
      )
      |> run_upgrade()
      |> assert_has_warning(&(&1 =~ "Failed to automatically configure compilers"))
    end
  end

  describe "reloadable compilers configuration" do
    test "updates reloadable_compilers in dev.exs when configured" do
      test_project(
        app_name: :my_app,
        files: %{
          "lib/my_app_web.ex" => """
          defmodule MyAppWeb do
          end
          """,
          "config/dev.exs" => """
          import Config

          config :my_app, MyAppWeb.Endpoint,
            http: [port: 4000],
            reloadable_compilers: [:elixir, :app]
          """
        }
      )
      |> run_upgrade()
      |> assert_has_patch("config/dev.exs", """
      - |  reloadable_compilers: [:elixir, :app]
      + |  reloadable_compilers: [:phoenix_live_view, :elixir, :app]
      """)
    end

    test "moves :phoenix_live_view to first position if already present" do
      test_project(
        app_name: :my_app,
        files: %{
          "lib/my_app_web.ex" => """
          defmodule MyAppWeb do
          end
          """,
          "config/dev.exs" => """
          import Config

          config :my_app, MyAppWeb.Endpoint,
            http: [port: 4000],
            reloadable_compilers: [:elixir, :phoenix_live_view, :app]
          """
        }
      )
      |> run_upgrade()
      |> assert_has_patch("config/dev.exs", """
      - |  reloadable_compilers: [:elixir, :phoenix_live_view, :app]
      + |  reloadable_compilers: [:phoenix_live_view, :elixir, :app]
      """)
    end

    test "doesn't update when :phoenix_live_view is already first" do
      test_project(
        app_name: :my_app,
        files: %{
          "lib/my_app_web.ex" => """
          defmodule MyAppWeb do
          end
          """,
          "config/dev.exs" => """
          import Config

          config :my_app, MyAppWeb.Endpoint,
            http: [port: 4000],
            reloadable_compilers: [:phoenix_live_view, :elixir, :app]
          """
        }
      )
      |> run_upgrade()
      |> assert_unchanged("config/dev.exs")
    end

    test "warns when reloadable_compilers is not a list" do
      test_project(
        app_name: :my_app,
        files: %{
          "lib/my_app_web.ex" => """
          defmodule MyAppWeb do
          end
          """,
          "config/dev.exs" => """
          import Config

          config :my_app, MyAppWeb.Endpoint,
            http: [port: 4000],
            reloadable_compilers: Application.get_env(:my_app, :compilers)
          """
        }
      )
      |> run_upgrade()
      |> assert_has_warning(
        &(&1 =~ "Ensure that `:phoenix_live_view` is set in there as the first entry!")
      )
    end

    test "does nothing when reloadable_compilers is not configured" do
      test_project(
        app_name: :my_app,
        files: %{
          "lib/my_app_web.ex" => """
          defmodule MyAppWeb do
          end
          """,
          "config/dev.exs" => """
          import Config

          config :my_app, MyAppWeb.Endpoint,
            http: [port: 4000]
          """
        }
      )
      |> run_upgrade()
      |> assert_unchanged("config/dev.exs")
    end
  end

  describe "esbuild configuration" do
    test "doesn't update esbuild when user says no" do
      test_project(
        app_name: :my_app,
        files: %{
          "config/config.exs" => """
          import Config

          config :esbuild,
            my_app: [
              args: ~w(js/app.js --bundle --outdir=../priv/static/assets),
              cd: Path.expand("../assets", __DIR__),
              env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
            ]
          """
        }
      )
      |> run_upgrade()
      |> assert_unchanged("config/config.exs")
      |> refute_has_notice()
    end

    test "updates esbuild args and env when user confirms" do
      test_project(
        app_name: :my_app,
        files: %{
          "config/config.exs" => """
          import Config

          config :esbuild,
            my_app: [
              args: ~w(js/app.js --bundle --outdir=../priv/static/assets),
              cd: Path.expand("../assets", __DIR__),
              env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
            ]
          """
        }
      )
      # yes to esbuild
      |> run_upgrade(input: "y\n")
      |> assert_has_patch("config/config.exs", """
      - |    args: ~w(js/app.js --bundle --outdir=../priv/static/assets),
      + |    args: ~w(js/app.js --bundle --outdir=../priv/static/assets --alias:@=.),
        |    cd: Path.expand("../assets", __DIR__),
      - |    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
      + |    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
      """)
      |> assert_has_notice(fn notice -> notice =~ "Final step for colocated hooks" end)
    end

    test "updates esbuild args list when user confirms" do
      test_project(
        app_name: :my_app,
        files: %{
          "config/config.exs" => """
          import Config

          config :esbuild,
            my_app: [
              args: ["js/app.js", "--bundle", "--outdir=../priv/static/assets"],
              cd: Path.expand("../assets", __DIR__),
              env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
            ]
          """
        }
      )
      # yes to esbuild (no deps prompt since no existing deps)
      |> run_upgrade(input: "y\n")
      |> assert_has_patch("config/config.exs", """
      - |    args: ["js/app.js", "--bundle", "--outdir=../priv/static/assets"],
      + |    args: ["js/app.js", "--bundle", "--outdir=../priv/static/assets", "--alias:@=."],
      """)
      |> assert_has_notice(&(&1 =~ "Final step for colocated hooks"))
    end

    test "updates esbuild env, keeping previous value" do
      test_project(
        app_name: :my_app,
        files: %{
          "config/config.exs" => """
          import Config

          config :esbuild,
            my_app: [
              args: ~w(js/app.js --bundle --outdir=../priv/static/assets),
              cd: Path.expand("../assets", __DIR__),
              env: %{"NODE_PATH" => "something_custom"}
            ]
          """
        }
      )
      # yes to esbuild
      |> run_upgrade(input: "y\n")
      |> assert_has_patch("config/config.exs", """
      - |    args: ~w(js/app.js --bundle --outdir=../priv/static/assets),
      + |    args: ~w(js/app.js --bundle --outdir=../priv/static/assets --alias:@=.),
        |    cd: Path.expand("../assets", __DIR__),
      - |    env: %{"NODE_PATH" => "something_custom"}
      + |    env: %{"NODE_PATH" => ["something_custom", Mix.Project.build_path()]}
      """)
      |> assert_has_notice(fn notice -> notice =~ "Final step for colocated hooks" end)
    end

    test "warns when esbuild config doesn't have expected structure" do
      test_project(
        app_name: :my_app,
        files: %{
          "config/config.exs" => """
          import Config

          config :esbuild,
            my_app: [
              args: :other,
              cd: Path.expand("../assets", __DIR__),
              env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
            ]
          """
        }
      )
      # yes to esbuild (no deps prompt since no existing deps)
      |> run_upgrade(input: "y\n")
      |> assert_has_warning(&(&1 =~ "Failed to update esbuild configuration for colocated hooks"))
      |> refute_has_notice()
    end

    test "warns when esbuild config is missing args or env" do
      test_project(
        app_name: :my_app,
        files: %{
          "config/config.exs" => """
          import Config

          config :esbuild,
            my_app: [
              cd: Path.expand("../assets", __DIR__)
            ]
          """
        }
      )
      # no to deps prompt, yes to esbuild
      |> run_upgrade(input: "y\n")
      |> assert_has_warning(&(&1 =~ "Failed to update esbuild configuration for colocated hooks"))
      |> refute_has_notice()
    end

    test "skips esbuild update when no esbuild config exists" do
      test_project(app_name: :my_app)
      # yes to esbuild but no config exists (no deps prompt since no existing deps)
      |> run_upgrade(input: "y\n")
      |> refute_has_notice()
    end
  end

  describe "debug_attributes" do
    test "adds debug_attributes when debug_heex_annotations is already set" do
      test_project(
        app_name: :my_app,
        files: %{
          "config/dev.exs" => """
          import Config

          config :phoenix_live_view,
            enable_expensive_runtime_checks: true,
            debug_heex_annotations: true
          """
        }
      )
      |> run_upgrade()
      |> assert_has_patch("config/dev.exs", """
      - |    debug_heex_annotations: true
      + |    debug_heex_annotations: true,
      + |    debug_attributes: true
      """)
    end

    test "does not add debug_attributes when debug_heex_annotations is not set" do
      test_project(
        app_name: :my_app,
        files: %{
          "config/dev.exs" => """
          import Config

          config :phoenix_live_view,
            enable_expensive_runtime_checks: true
          """
        }
      )
      |> run_upgrade()
      |> assert_unchanged("config/dev.exs")
    end
  end

  describe "full upgrade scenario" do
    test "performs complete upgrade for a Phoenix project" do
      full_project()
      |> run_upgrade(input: ["y\n", "y\n"])
      |> assert_has_patch("mix.exs", """
      - |      deps: deps()
      + |      deps: deps(),
      + |      compilers: [:phoenix_live_view] ++ Mix.compilers()
      """)
      |> assert_has_patch("mix.exs", """
      + |      {:lazy_html, ">= 0.0.0", only: :test},
      """)
      |> assert_has_patch("config/dev.exs", """
      - |  reloadable_compilers: [:elixir, :app]
      + |  reloadable_compilers: [:phoenix_live_view, :elixir, :app]
      """)
      |> assert_has_patch("config/dev.exs", """
      - |    debug_heex_annotations: true
      + |    debug_heex_annotations: true,
      + |    debug_attributes: true
      """)
      |> assert_has_patch("config/config.exs", """
      - |    args: ~w(js/app.js --bundle --outdir=../priv/static/assets),
      + |    args: ~w(js/app.js --bundle --outdir=../priv/static/assets --alias:@=.),
        |    cd: Path.expand("../assets", __DIR__),
      - |    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
      + |    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
      """)
    end
  end

  defp full_project do
    test_project(
      app_name: :my_app,
      files: %{
        "mix.exs" => """
        defmodule MyApp.MixProject do
          use Mix.Project

          def project do
            [
              app: :my_app,
              version: "0.1.0",
              elixir: "~> 1.14",
              deps: deps()
            ]
          end

          defp deps do
            [
              {:phoenix, "~> 1.7.0"},
              {:phoenix_live_view, "~> 0.20.0"}
            ]
          end
        end
        """,
        "lib/my_app_web.ex" => """
        defmodule MyAppWeb do
        end
        """,
        "config/config.exs" => """
        import Config

        config :esbuild,
          my_app: [
            args: ~w(js/app.js --bundle --outdir=../priv/static/assets),
            cd: Path.expand("../assets", __DIR__),
            env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
          ]
        """,
        "config/dev.exs" => """
        import Config

        config :my_app, MyAppWeb.Endpoint,
          http: [port: 4000],
          reloadable_compilers: [:elixir, :app]

        config :phoenix_live_view,
          enable_expensive_runtime_checks: true,
          debug_heex_annotations: true
        """
      }
    )
  end

  defp run_upgrade(igniter, opts \\ []) do
    # Default to no for esbuild prompt
    input = Keyword.get(opts, :input, "n\n")

    shell = Mix.shell()

    try do
      Mix.shell(Mix.Shell.Process)

      input
      |> List.wrap()
      |> Enum.each(&send(self(), {:mix_shell_input, :prompt, &1}))

      Igniter.compose_task(igniter, "phoenix_live_view.upgrade", ["1.0.0", "1.1.1"])
    after
      Mix.shell(shell)
    end
  end

  defp refute_has_notice(igniter) do
    assert igniter.notices == []
    igniter
  end

  defp refute_has_warning(igniter) do
    assert igniter.warnings == []
    igniter
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Phoenix.LiveView.Igniter.UpgradeTo1_1 do
    @moduledoc false

    def run(igniter, _opts) do
      igniter
      |> Igniter.Project.Deps.add_dep({:lazy_html, ">= 0.0.0", only: :test}, on_exists: :skip)
      |> Igniter.Project.MixProject.update(:project, [:compilers], fn
        nil ->
          {:ok, {:code, "[:phoenix_live_view] ++ Mix.compilers()"}}

        zipper ->
          cond do
            Igniter.Code.List.list?(zipper) and
                !Igniter.Code.List.find_list_item_index(zipper, &(&1 == :phoenix_live_view)) ->
              Igniter.Code.List.prepend_to_list(zipper, :phoenix_live_view)

            expected_compilers?(zipper) ->
              {:ok, zipper}

            true ->
              {:warning,
               """
               Failed to automatically configure compilers. Please add the following code to the project section of your mix.exs:

                  compilers: [:phoenix_live_view] ++ Mix.compilers()
               """}
          end
      end)
      |> maybe_update_reloadable_compilers()
      |> maybe_update_esbuild_config()
      |> maybe_update_debug_config()
    end

    defp maybe_update_reloadable_compilers(igniter) do
      endpoint_mod = Igniter.Libs.Phoenix.web_module(igniter) |> Module.concat(Endpoint)
      app_name = Igniter.Project.Application.app_name(igniter)

      warning = """
      You have `:reloadable_compilers` configured on your dev endpoint in config/dev.exs.

      Ensure that `:phoenix_live_view` is set in there as the first entry!

          config :#{app_name}, #{inspect(endpoint_mod)},
            reloadable_compilers: [:phoenix_live_view, :elixir, :app]
      """

      if Igniter.Project.Config.configures_key?(igniter, "dev.exs", app_name, [
           endpoint_mod,
           :reloadable_compilers
         ]) do
        Igniter.Project.Config.configure(
          igniter,
          "dev.exs",
          app_name,
          [endpoint_mod, :reloadable_compilers],
          nil,
          updater: fn zipper ->
            if Igniter.Code.List.list?(zipper) do
              index =
                Igniter.Code.List.find_list_item_index(zipper, fn zipper ->
                  case Igniter.Code.Common.expand_literal(zipper) do
                    {:ok, :phoenix_live_view} -> true
                    _ -> false
                  end
                end)

              cond do
                index == nil ->
                  Igniter.Code.List.prepend_to_list(zipper, :phoenix_live_view)

                index == 0 ->
                  {:ok, zipper}

                index > 0 ->
                  zipper
                  |> Igniter.Code.List.remove_index(index)
                  |> case do
                    {:ok, zipper} ->
                      Igniter.Code.List.prepend_to_list(zipper, :phoenix_live_view)

                    :error ->
                      {:warning, warning}
                  end
              end
            else
              {:warning, warning}
            end
          end
        )
      else
        igniter
      end
    end

    defp expected_compilers?(zipper) do
      Igniter.Code.Function.function_call?(zipper, {Kernel, :++}) &&
        Igniter.Code.Function.argument_equals?(zipper, 0, [:phoenix_live_view]) &&
        Igniter.Code.Function.argument_matches_predicate?(zipper, 1, fn zipper ->
          Igniter.Code.Function.function_call?(zipper, {Mix, :compilers})
        end)
    end

    defp maybe_update_esbuild_config(igniter) do
      if igniter.args.options[:yes] ||
           Igniter.Util.IO.yes?(
             "Do you want to update your esbuild configuration for colocated hooks?"
           ) do
        app_name = Igniter.Project.Application.app_name(igniter)

        warning =
          """
          Failed to update esbuild configuration for colocated hooks. Please manually:

          1. append `--alias:@=.` to the `args` list
          2. configure `NODE_PATH` to be a list including `Mix.Project.build_path()`:

              config :esbuild,
                #{app_name}: [
                  args:
                    ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
                  cd: "...",
                  env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
                ]
          """

        if Igniter.Project.Config.configures_key?(igniter, "config.exs", :esbuild, app_name) do
          config_exs_vsn = Rewrite.Source.version(igniter.rewrite.sources["config/config.exs"])

          igniter =
            igniter
            |> Igniter.Project.Deps.add_dep({:esbuild, "~> 0.10"}, on_exists: :overwrite)
            |> Igniter.Project.Deps.set_dep_option(
              :esbuild,
              :runtime,
              quote(do: Mix.env() == :dev)
            )
            |> Igniter.Project.Config.configure(
              "config.exs",
              :esbuild,
              app_name,
              nil,
              updater: fn zipper ->
                if Igniter.Code.Keyword.keyword_has_path?(zipper, [:args]) and
                     Igniter.Code.Keyword.keyword_has_path?(zipper, [:env]) do
                  with {:ok, zipper} <- update_esbuild_args(zipper, warning),
                       {:ok, zipper} <- update_esbuild_env(zipper) do
                    {:ok, zipper}
                  end
                else
                  {:warning, warning}
                end
              end
            )

          if config_exs_vsn ==
               Rewrite.Source.version(igniter.rewrite.sources["config/config.exs"]) do
            igniter
          else
            igniter
            |> Igniter.add_notice("""
            Final step for colocated hooks:

            Add an import to your `app.js` and configure the hooks option of the LiveSocket:

              ...
                import {LiveSocket} from "phoenix_live_view"
              + import {hooks as colocatedHooks} from "phoenix-colocated/#{app_name}"
                import topbar from "../vendor/topbar"
              ...
                const liveSocket = new LiveSocket("/live", Socket, {
                  longPollFallbackMs: 2500,
                  params: {_csrf_token: csrfToken},
              +   hooks: {...colocatedHooks}
                })

            """)
          end
        else
          igniter
        end
      else
        igniter
      end
    end

    defp update_esbuild_args(zipper, warning) do
      Igniter.Code.Keyword.put_in_keyword(zipper, [:args], nil, fn zipper ->
        if Igniter.Code.List.list?(zipper) do
          Igniter.Code.List.append_new_to_list(zipper, "--alias:@=.")
        else
          # ~w()
          case zipper.node do
            {:sigil_w, _meta, [{:<<>>, _str_meta, [str]}, []]} ->
              if str =~ "--alias:@=." do
                {:ok, zipper}
              else
                {:ok,
                 Igniter.Code.Common.replace_code(
                   zipper,
                   ~s[~w(#{str <> " --alias:@=."})]
                 )}
              end

            _ ->
              {:warning, warning}
          end
        end
      end)
    end

    defp update_esbuild_env(zipper) do
      Igniter.Code.Keyword.put_in_keyword(
        zipper,
        [:env],
        # we already checked that env is configured
        nil,
        fn zipper ->
          Igniter.Code.Map.put_in_map(
            zipper,
            ["NODE_PATH"],
            ~s<"[Path.expand("../deps", __DIR__), Mix.Project.build_path()])>,
            fn zipper ->
              if Igniter.Code.List.list?(zipper) do
                index =
                  Igniter.Code.List.find_list_item_index(zipper, fn zipper ->
                    if Igniter.Code.Function.function_call?(
                         zipper,
                         {Mix.Project, :build_path},
                         0
                       ) do
                      true
                    end
                  end)

                if index do
                  {:ok, zipper}
                else
                  Igniter.Code.List.append_to_list(zipper, {:code, "Mix.Project.build_path()"})
                end
              else
                # If NODE_PATH is not a list, convert it to a list with the original value and Mix.Project.build_path()
                zipper
                |> Igniter.Code.Common.replace_code("[Mix.Project.build_path()]")
                |> Igniter.Code.List.prepend_to_list(zipper.node)
              end
            end
          )
        end
      )
    end

    defp maybe_update_debug_config(igniter) do
      if Igniter.Project.Config.configures_key?(
           igniter,
           "dev.exs",
           :phoenix_live_view,
           :debug_heex_annotations
         ) do
        if Igniter.Project.Config.configures_key?(
             igniter,
             "dev.exs",
             :phoenix_live_view,
             :debug_attributes
           ) do
          igniter
        else
          Igniter.Project.Config.configure(
            igniter,
            "dev.exs",
            :phoenix_live_view,
            :debug_attributes,
            true
          )
        end
      else
        igniter
      end
    end
  end
end

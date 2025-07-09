defmodule Phoenix.LiveView.Igniter.UpgradeTo1_1 do
  @moduledoc false

  def run(igniter, _opts) do
    igniter
    |> Igniter.Project.Deps.add_dep({:phoenix_live_view, "~> 1.1"})
    |> Igniter.Project.Deps.add_dep({:lazy_html, ">= 0.0.0", only: :test})
    |> Igniter.Project.MixProject.update(:project, [:compilers], fn
      nil ->
        {:ok, {:code, "[:phoenix_live_view] ++ Mix.compilers()"}}

      zipper ->
        cond do
          Igniter.Code.List.list?(zipper) and
              !Igniter.Code.List.find_list_item_index(zipper, &(&1 == :phoenix_live_view)) ->
            Igniter.Code.List.prepend_to_list(zipper, :phoenix_live_view)

          # already good; for whatever reason, this does not work
          # Igniter.Code.Common.nodes_equal?(zipper, quote do
          #   [:phoenix_live_view] ++ Mix.compilers()
          # end)
          Igniter.Util.Debug.code_at_node(zipper) == "[:phoenix_live_view] ++ Mix.compilers()" ->
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
  end

  defp maybe_update_reloadable_compilers(igniter) do
    endpoint_mod = Igniter.Libs.Phoenix.web_module(igniter) |> Module.concat(Endpoint)
    app_name = Igniter.Project.Application.app_name(igniter)

    if Igniter.Project.Config.configures_key?(igniter, "dev.exs", app_name, [
         endpoint_mod,
         :reloadable_compilers
       ]) do
      try do
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
                      throw(:failed)
                  end
              end
            else
              throw(:failed)
            end
          end
        )
      catch
        :failed ->
          Igniter.Util.Warning.warn_with_code_sample(
            igniter,
            """
            You have `:reloadable_compilers` configured on your dev endpoint in config/dev.exs.

            Ensure that `:phoenix_live_view` is set in there as the first entry!
            """,
            """
            config :#{app_name}, #{inspect(endpoint_mod)},
              reloadable_compilers: [:phoenix_live_view, :elixir, :app]
            """
          )
      end
    else
      igniter
    end
  end

  defp maybe_update_esbuild_config(igniter) do
    if Igniter.Util.IO.yes?(
         "Do you want to update your esbuild configuration for colocated hooks?"
       ) do
      app_name = Igniter.Project.Application.app_name(igniter)

      warn = fn ->
        Igniter.Util.Warning.warn_with_code_sample(
          igniter,
          """
          Failed to update esbuild configuration for colocated hooks. Please manually:

          1. append `--alias:@=.` to the `args` list
          2. configure `NODE_PATH` to be a list including `Mix.Project.build_path()`:
          """,
          """
          config :esbuild,
            #{app_name}: [
              args:
                ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
              cd: "...",
              env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]},
            ]
          """
        )
      end

      if Igniter.Project.Config.configures_key?(igniter, "config.exs", :esbuild, app_name) do
        try do
          Igniter.Project.Config.configure(
            igniter,
            "config.exs",
            :esbuild,
            app_name,
            nil,
            updater: fn zipper ->
              if Igniter.Code.Keyword.keyword_has_path?(zipper, [:args]) and
                   Igniter.Code.Keyword.keyword_has_path?(zipper, [:env]) do
                with {:ok, zipper} <- update_esbuild_args(zipper),
                     {:ok, zipper} <- update_esbuild_env(zipper) do
                  {:ok, zipper}
                end
              else
                # https://github.com/ash-project/igniter/issues/314
                throw(:failed)
              end
            end
          )
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
        catch
          :failed ->
            warn.()
        end
      else
        warn.()
      end
    else
      igniter
    end
  end

  defp update_esbuild_args(zipper) do
    Igniter.Code.Keyword.put_in_keyword(zipper, [:args], nil, fn zipper ->
      if Igniter.Code.List.list?(zipper) do
        Igniter.Code.List.append_to_list(zipper, "--alias:@=.")
      else
        # ~w()
        case zipper.node do
          {:sigil_w, _meta, [{:<<>>, _str_meta, [str]}, []]} ->
            {:ok,
             Igniter.Code.Common.replace_code(
               zipper,
               ~s[~w(#{str <> " --alias:@="})]
             )}

          _ ->
            # https://github.com/ash-project/igniter/issues/314
            throw(:failed)
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
            original_zipper = zipper

            {:ok, zipper} =
              Igniter.Code.Common.replace_code(zipper, "[Mix.Project.build_path()]")
              |> Igniter.Code.List.prepend_to_list(
                Code.string_to_quoted!(Igniter.Util.Debug.code_at_node(zipper))
              )

            # when we just return the ok tuple from above, things break in a very weird way
            {:ok,
             Igniter.Code.Common.replace_code(
               original_zipper,
               Igniter.Util.Debug.code_at_node(zipper)
             )}
          end
        )
      end
    )
  end
end

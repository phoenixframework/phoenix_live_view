defmodule Phoenix.LiveView.Router do
  @moduledoc """
  Provides LiveView routing for Phoenix routers.
  """

  @doc """
  Defines a LiveView route.

  ## Layout

  When a layout isn't explicitly set, a default layout is inferred similar to
  controller actions. For example, the layout for the router `MyAppWeb.Router`
  would be inferred as `MyAppWeb.LayoutView` and would use the `:app` template.

  ## Options

    * `:session` - the optional list of keys to pull out of the Plug
      connection session and into the LiveView session.
      The `:path_params` keys may also be provided to copy the
      plug path params into the session. Defaults to `[:path_params]`.
      For example, the following would copy the path params and
      Plug session current user ID into the LiveView session:

          [:path_params, :user_id, :remember_me]

    * `:layout` - the optional tuple for specifying a layout to render the
      LiveView. Defaults to `{LayoutView, :app}` where LayoutView is relative to
      your application's namespace.
    * `:container` - the optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`
    * `:as` - optionally configures the named helper. Defaults to `:live`.

  ## Examples

      defmodule MyApp.Router
        use Phoenix.Router
        import Phoenix.LiveView.Router

        scope "/", MyApp do
          pipe_through [:browser]

          live "/thermostat", ThermostatLive
          live "/clock", ClockLive, session: [:path_params, :user_id]
          live "/dashboard", DashboardLive, layout: {MyApp.AlternativeView, "app.html"}
        end
      end

      iex> MyApp.Router.Helpers.live_path(MyApp.Endpoint, MyApp.ThermostatLive)
      "/thermostat"

  """
  defmacro live(path, live_view, opts \\ []) do
    quote bind_quoted: binding() do
      Phoenix.Router.get(
        path,
        Phoenix.LiveView.Plug,
        Phoenix.Router.scoped_alias(__MODULE__, live_view),
        private: %{
          phoenix_live_view:
            Keyword.put_new(
              opts,
              :layout,
              Phoenix.LiveView.Router.__layout_from_router_module__(__MODULE__)
            )
        },
        as: opts[:as] || :live,
        alias: false
      )
    end
  end

  @doc false
  def __layout_from_router_module__(module) do
    view =
      module
      |> Atom.to_string()
      |> String.split(".")
      |> Enum.drop(-1)
      |> Enum.take(2)
      |> Kernel.++(["LayoutView"])
      |> Module.concat()

    {view, :app}
  end
end

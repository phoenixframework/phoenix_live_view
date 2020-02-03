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

    * `:session` - a map of strings keys and values to be merged into the session

    * `:layout` - the optional tuple for specifying a layout to render the
      LiveView. Defaults to `{LayoutView, :app}` where LayoutView is relative to
      your application's namespace.

    * `:container` - the optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`.
      See `Phoenix.LiveView.live_render/3` for more information on examples.

    * `:as` - optionally configures the named helper. Defaults to `:live`.

  ## Examples

      defmodule MyApp.Router
        use Phoenix.Router
        import Phoenix.LiveView.Router

        scope "/", MyApp do
          pipe_through [:browser]

          live "/thermostat", ThermostatLive
          live "/clock", ClockLive
          live "/dashboard", DashboardLive, layout: {MyApp.AlternativeView, "app.html"}
        end
      end

      iex> MyApp.Router.Helpers.live_path(MyApp.Endpoint, MyApp.ThermostatLive)
      "/thermostat"

  """
  defmacro live(path, live_view, opts \\ []) do
    quote bind_quoted: binding() do
      {action, router_options} = Phoenix.LiveView.Router.__live__(__MODULE__, live_view, opts)
      Phoenix.Router.get(path, Phoenix.LiveView.Plug, action, router_options)
    end
  end

  @doc false
  def __live__(router, live_view, opts) do
    live_view = Phoenix.Router.scoped_alias(router, live_view)

    opts =
      opts
      |> Keyword.put(:router, router)
      |> Keyword.put_new_lazy(:layout, fn ->
        layout_view =
          router
          |> Atom.to_string()
          |> String.split(".")
          |> Enum.drop(-1)
          |> Kernel.++(["LayoutView"])
          |> Module.concat()

        {layout_view, :app}
      end)

    {live_view,
     as: opts[:as] || :live, private: %{phoenix_live_view: {live_view, nil, opts}}, alias: false}
  end
end

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
        end
      end

      iex> MyApp.Router.Helpers.live_path(MyApp.Endpoint, MyApp.ThermostatLive)
      "/thermostat"

  """
  defmacro live(path, live_view, opts \\ []) do
    quote do
      Phoenix.Router.get(
        unquote(path),
        Phoenix.LiveView.Controller,
        Phoenix.Router.scoped_alias(__MODULE__, unquote(live_view)),
        private: %{
          phoenix_live_view: unquote(opts),
          phoenix_live_view_default_layout: Phoenix.LiveView.Router.__layout_from_router_module__(__MODULE__)
        },
        as: unquote(opts)[:as] || :live,
        alias: false
      )
    end
  end

  @doc false
  def __layout_from_router_module__(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> Enum.drop(-1)
    |> Enum.take(2)
    |> Kernel.++(["LayoutView"])
    |> Module.concat()
  end
end

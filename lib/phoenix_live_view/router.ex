defmodule Phoenix.LiveView.Router do
  @moduledoc """
  Provides LiveView routing for Phoenix routers.
  """

  @doc """
  Defines a LiveView route.

  ## Options

    * `:session` - the optional list of keys to pull out of the Plug
      connection session and into the LiveView session.
      The `:path_params` keys may also be provided to copy the
      plug path params into the session. Defaults to `[:path_params]`.
      For example, the following would copy the path params and
      Plug session current user ID into the LiveView session:

          [:path_params, :user_id, :remember_me]

    * `:attrs` - the optional list of DOM attributes to be added to
      the LiveView container.
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
        private: %{phoenix_live_view: unquote(opts)},
        as: unquote(opts)[:as] || :live,
        alias: false
      )
    end
  end
end

defmodule Phoenix.LiveView.Router do
  @moduledoc """
  Provides LiveView routing for Phoenix routers.
  """

  @cookie_key "__phoenix_flash__"

  @doc """
  Defines a LiveView route.

  A LiveView can be routed to by using the `live` macro with a path and
  the name of the LiveView:

      live "/thermostat", ThermostatLive

  By default, you can generate a route to this LiveView by using the `live_path` helper:

      live_path(@socket, ThermostatLive)

  ## Actions and live navigation

  It is common for a LiveView to have multiple states and multiple URLs.
  For example, you can have a single LiveView that lists all articles on
  your web app. For each article there is an "Edit" button which, when
  pressed, opens up a modal on the same page to edit the article. It is a
  best practice to use live navigation in those cases, so when you click
  edit, the URL changes to "/articles/1/edit", even though you are still
  within the same LiveView. Similarly, you may also want to show a "New"
  button, which opens up the modal to create new entries, and you want
  this to be reflected in the URL as "/articles/new".

  In order to make it easier to recognize the current "action" your
  LiveView is on, you can pass the action option when defining LiveViews
  too:

      live "/articles", ArticleLive.Index, :index
      live "/articles/new", ArticleLive.Index, :new
      live "/articles/:id/edit", ArticleLive.Index, :edit

  When an action is given, the generated route helpers are named after
  the LiveView itself (in the same way as for a controller). For the example
  above, we will have:

      article_index_path(@socket, :index)
      article_index_path(@socket, :new)
      article_index_path(@socket, :edit, 123)

  The current action will always be available inside the LiveView as
  the `@live_action` assign, that can be used to render a LiveComponent:

      <%= if @live_action == :new do %>
        <%= live_component MyAppWeb.ArticleLive.FormComponent %>
      <% end %>

  Or can be used to show or hide parts of the template:

      <%= if @live_action == :edit do %>
        <%= render("form.html", user: @user) %>
      <% end %>

  Note that `@live_action` will be `nil` if no action is given on the route definition.

  ## Options

    * `:session` - a map to be merged into the session, for example: `%{"my_key" => 123}`.
      The map keys must be strings.

      Can also be a "MFA" (module, function, arguments) tuple. That function will receive
      the connection and should return a map (with string keys) to be merged into the session.
      For example, `{MyModule, :my_function, []}` means `MyModule.my_function(conn)` is called.

    * `:layout` - an optional tuple to specify the rendering layout for the LiveView.
      If set, this option will replace the current root layout.

    * `:container` - an optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`.
      See `Phoenix.LiveView.Helpers.live_render/3` for more information and examples.

    * `:as` - optionally configures the named helper. Defaults to `:live` when
      using a LiveView without actions or defaults to the LiveView name when using
      actions.

    * `:metadata` - a map to optional feed metadata used on telemetry events and route info,
      for example: `%{route_name: :foo, access: :user}`.

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
  defmacro live(path, live_view, action \\ nil, opts \\ []) do
    quote bind_quoted: binding() do
      {action, router_options} =
        Phoenix.LiveView.Router.__live__(__MODULE__, live_view, action, opts)

      Phoenix.Router.get(path, Phoenix.LiveView.Plug, action, router_options)
    end
  end

  @doc """
  Fetches the LiveView and merges with the controller flash.

  Replaces the default `:fetch_flash` plug used by `Phoenix.Router`.

  ## Examples

      defmodule AppWeb.Router do
        use LiveGenWeb, :router
        import Phoenix.LiveView.Router

        pipeline :browser do
          ...
          plug :fetch_live_flash
        end
        ...
      end
  """
  def fetch_live_flash(%Plug.Conn{} = conn, _) do
    case cookie_flash(conn) do
      {conn, nil} ->
        Phoenix.Controller.fetch_flash(conn, [])

      {conn, flash} ->
        conn
        |> Phoenix.Controller.fetch_flash([])
        |> Phoenix.Controller.merge_flash(flash)
    end
  end

  @doc false
  def __live__(router, live_view, action, opts) when is_list(action) and is_list(opts) do
    __live__(router, live_view, nil, Keyword.merge(action, opts))
  end

  def __live__(router, live_view, action, opts) when is_atom(action) and is_list(opts) do
    live_view = Phoenix.Router.scoped_alias(router, live_view)

    {private, opts} = Keyword.pop(opts, :private, %{})
    {metadata, opts} = Keyword.pop(opts, :metadata, %{})

    opts =
      opts
      |> Keyword.put(:router, router)
      |> Keyword.put(:action, action)

    {as_helper, as_action} = inferred_as(live_view, opts[:as], action)

    {as_action,
     alias: false,
     as: as_helper,
     private: Map.put(private, :phoenix_live_view, {live_view, opts}),
     metadata: Map.put(metadata, :phoenix_live_view, {live_view, action})}
  end

  defp inferred_as(live_view, as, nil), do: {as || :live, live_view}

  defp inferred_as(live_view, nil, action) do
    live_view
    |> Module.split()
    |> Enum.drop_while(&(not String.ends_with?(&1, "Live")))
    |> Enum.map(&(&1 |> String.replace_suffix("Live", "") |> Macro.underscore()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("_")
    |> case do
      "" ->
        raise ArgumentError,
              "could not infer :as option because a live action was given and the LiveView " <>
                "does not have a \"Live\" suffix. Please pass :as explicitly or make sure your " <>
                "LiveView is named like \"FooLive\" or \"FooLive.Index\""

      as ->
        {String.to_atom(as), action}
    end
  end

  defp inferred_as(_live_view, as, action), do: {as, action}

  defp cookie_flash(%Plug.Conn{cookies: %{@cookie_key => token}} = conn) do
    endpoint = Phoenix.Controller.endpoint_module(conn)

    flash =
      case Phoenix.LiveView.Utils.verify_flash(endpoint, token) do
        %{} = flash when flash != %{} -> flash
        %{} -> nil
      end

    {Plug.Conn.delete_resp_cookie(conn, @cookie_key), flash}
  end

  defp cookie_flash(%Plug.Conn{} = conn), do: {conn, nil}
end

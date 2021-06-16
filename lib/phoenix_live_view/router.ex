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
          live "/dashboard", DashboardLive, container: {:main, class: "row"}
        end
      end

      iex> MyApp.Router.Helpers.live_path(MyApp.Endpoint, MyApp.ThermostatLive)
      "/thermostat"

  """
  defmacro live(path, live_view, action \\ nil, opts \\ []) do
    vsn = session_vsn(__CALLER__.module)
    quote bind_quoted: binding() do
      default = {:default, %{session: %{}}, vsn}
      live_session = Module.get_attribute(__MODULE__, :phoenix_live_session_current, default)

      {action, router_options} =
        Phoenix.LiveView.Router.__live__(__MODULE__, live_view, action, live_session, opts)

      Phoenix.Router.get(path, Phoenix.LiveView.Plug, action, router_options)
    end
  end

  @doc """
  TODO
  """
  defmacro live_session(name, do: block) do
    quote do
      live_session(unquote(name), [], do: unquote(block))
    end
  end

  defmacro live_session(name, opts, do: block) do
    quote do
      Module.register_attribute(__MODULE__, :phoenix_live_sessions, accumulate: true)

      {name, extra, vsn} =
        unquote(__MODULE__).__live_session__(__MODULE__, unquote(opts), unquote(name))

      @phoenix_live_session_current {name, extra, vsn}
      @phoenix_live_sessions {name, extra, vsn}
      unquote(block)
      Module.delete_attribute(__MODULE__, :phoenix_live_session_current)
    end
  end

  @doc false
  def __live_session__(module, opts, name) do
    vsn = session_vsn(module)
    unless is_atom(name) do
      raise ArgumentError, """
      expected live_session name to be an atom, got: #{inspect(name)}
      """
    end

    extra = validate_live_session_opts(opts, name)

    if nested = Module.get_attribute(module, :phoenix_live_session_current) do
      raise """
      attempting to define live_session #{inspect(name)} inside #{inspect(elem(nested, 0))}.
      live_session definitions cannot be nested.
      """
    end

    live_sessions = Module.get_attribute(module, :phoenix_live_sessions)
    existing = Enum.find(live_sessions, fn {existing_name, _, _} -> name == existing_name end)

    if existing do
      raise """
      attempting to redefine live_session #{inspect(name)}.
      live_session routes must be declared in a single named block.
      """
    end

    {name, extra, vsn}
  end

  @live_session_opts [:root_layout, :session]
  defp validate_live_session_opts(opts, _name) when is_list(opts) do
    opts
    |> Keyword.put_new(:session, %{})
    |> Enum.reduce(%{}, fn
      {:session, val}, acc when is_map(val) or (is_tuple(val) and tuple_size(val) == 3) ->
        Map.put(acc, :session, val)

      {:session, bad_session}, _acc ->
        raise ArgumentError, """
        invalid live_session :session

        expected a map with string keys or an MFA tuple, got #{inspect(bad_session)}
        """

      {:root_layout, {mod, template}}, acc when is_atom(mod) and is_binary(template) ->
        Map.put(acc, :root_layout, {mod, template})

      {:root_layout, {mod, template}}, acc when is_atom(mod) and is_atom(template) ->
        Map.put(acc, :root_layout, {mod, "#{template}.html"})

      {:root_layout, false}, acc ->
        Map.put(acc, :root_layout, false)

      {:root_layout, bad_layout}, _acc ->
        raise ArgumentError, """
        invalid live_session :root_layout

        expected a tuple with the view module and template string or atom name, got #{inspect(bad_layout)}
        """

      {key, _val}, _acc ->
        raise ArgumentError, """
        unknown live_session option "#{inspect(key)}"

        Supported options include: #{inspect(@live_session_opts)}
        """
    end)
  end

  defp validate_live_session_opts(invalid, name) do
    raise ArgumentError, """
    expected second argument to live_session to be a list of options, got:

        live_session #{inspect(name)}, #{inspect(invalid)}
    """
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
  def __live__(router, live_view, action, live_session, opts)
      when is_list(action) and is_list(opts) do
    __live__(router, live_view, nil, live_session, Keyword.merge(action, opts))
  end

  def __live__(router, live_view, action, live_session, opts)
      when is_atom(action) and is_list(opts) do
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
     private: Map.put(private, :phoenix_live_view, {live_view, opts, live_session}),
     metadata: Map.put(metadata, :phoenix_live_view, {live_view, action, opts, live_session})}
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

  defp session_vsn(module) do
    if vsn = Module.get_attribute(module, :phoenix_session_vsn) do
      vsn
    else
      vsn = System.system_time()
      Module.put_attribute(module, :phoenix_session_vsn, vsn)
      vsn
    end
  end
end

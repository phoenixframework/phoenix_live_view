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
        <.live_component module={MyAppWeb.ArticleLive.FormComponent} id="form" />
      <% end %>

  Or can be used to show or hide parts of the template:

      <%= if @live_action == :edit do %>
        <%= render("form.html", user: @user) %>
      <% end %>

  Note that `@live_action` will be `nil` if no action is given on the route definition.

  ## Options

    * `:container` - an optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`.
      See `Phoenix.LiveView.Helpers.live_render/3` for more information and examples.

    * `:as` - optionally configures the named helper. Defaults to `:live` when
      using a LiveView without actions or defaults to the LiveView name when using
      actions.

    * `:metadata` - a map to optional feed metadata used on telemetry events and route info,
      for example: `%{route_name: :foo, access: :user}`.

    * `:private` - an optional map of private data to put in the plug connection.
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
    quote bind_quoted: binding() do
      {action, router_options} =
        Phoenix.LiveView.Router.__live__(__MODULE__, live_view, action, opts)

      Phoenix.Router.get(path, Phoenix.LiveView.Plug, action, router_options)
    end
  end

  @doc """
  Defines a live session for live redirects within a group of live routes.

  `live_session/3` allow routes defined with `live/4` to support
  `live_redirect` from the client with navigation purely over the existing
  websocket connection. This allows live routes defined in the router to
  mount a new root LiveView without additional HTTP requests to the server.

  ## Security Considerations

  You must always perform authentication and authorization in your LiveViews.
  If your application handle both regular HTTP requests and LiveViews, then
  you must perform authentication and authorization on both. This is important
  because `live_redirect`s *do not go through the plug pipeline*.

  `live_session` can be used to draw boundaries between groups of LiveViews.
  Redirecting between `live_session`s will always force a full page reload
  and establish a brand new LiveView connection. This is useful when LiveViews
  require different authentication strategies or simply when they use different
  root layouts (as the root layout is not updated between live redirects).

  Please [read our guide on the security model](security-model.md) for a
  detailed description and general tips on authentication, authorization,
  and more.

  ## Options

    * `:session` - The optional extra session map or MFA tuple to be merged with
      the LiveView session. For example, `%{"admin" => true}`, `{MyMod, :session, []}`.
      For MFA, the function is invoked, passing the `Plug.Conn` struct is prepended
      to the arguments list.

    * `:root_layout` - The optional root layout tuple for the initial HTTP render to
      override any existing root layout set in the router.

    * `:on_mount` - The optional list of hooks to attach to the mount lifecycle _of
      each LiveView in the session_. See `Phoenix.LiveView.on_mount/1`. Passing a
      single value is also accepted.

  ## Examples

      scope "/", MyAppWeb do
        pipe_through :browser

        live_session :default do
          live "/feed", FeedLive, :index
          live "/status", StatusLive, :index
          live "/status/:id", StatusLive, :show
        end

        live_session :admin, on_mount: MyAppWeb.AdminLiveAuth do
          live "/admin", AdminDashboardLive, :index
          live "/admin/posts", AdminPostLive, :index
        end
      end

  In the example above, we have two live sessions. Live navigation between live views
  in the different sessions is not possible and will always require a full page reload.
  This is important in the example above because the `:admin` live session has authentication
  requirements, defined by `on_mount: MyAppWeb.AdminLiveAuth`, that the other LiveViews
  do not have.

  If you have both regular HTTP routes (via get, post, etc) and `live` routes, then
  you need to perform the same authentication and authorization rules in both.
  For example, if you were to add a `get "/admin/health"` entry point inside the
  `:admin` live session above, then you must create your own plug that performs the
  same authentication and authorization rules as `MyAppWeb.AdminLiveAuth`, and then
  pipe through it:

      live_session :admin, on_mount: MyAppWeb.AdminLiveAuth do
        # Regular routes
        pipe_through [MyAppWeb.AdminPlugAuth]
        get "/admin/health"

        # Live routes
        live "/admin", AdminDashboardLive, :index
        live "/admin/posts", AdminPostLive, :index
      end

  The opposite is also true, if you have regular http routes and you want to
  add your own `live` routes, the same authentication and authorization checks
  executed by the plugs listed in `pipe_through` must be ported to LiveViews
  and be executed via `on_mount` hooks.
  """
  defmacro live_session(name, opts \\ [], do: block) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote do
      unquote(__MODULE__).__live_session__(__MODULE__, unquote(opts), unquote(name))
      unquote(block)
      Module.delete_attribute(__MODULE__, :phoenix_live_session_current)
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:mount, 3}})

  defp expand_alias(other, _env), do: other

  @doc false
  def __live_session__(module, opts, name) do
    Module.register_attribute(module, :phoenix_live_sessions, accumulate: true)
    vsn = session_vsn(module)

    unless is_atom(name) do
      raise ArgumentError, """
      expected live_session name to be an atom, got: #{inspect(name)}
      """
    end

    extra = validate_live_session_opts(opts, module, name)

    if nested = Module.get_attribute(module, :phoenix_live_session_current) do
      raise """
      attempting to define live_session #{inspect(name)} inside #{inspect(nested.name)}.
      live_session definitions cannot be nested.
      """
    end

    live_sessions = Module.get_attribute(module, :phoenix_live_sessions)
    existing = Enum.find(live_sessions, fn %{name: existing_name} -> name == existing_name end)

    if existing do
      raise """
      attempting to redefine live_session #{inspect(name)}.
      live_session routes must be declared in a single named block.
      """
    end

    Module.put_attribute(module, :phoenix_live_session_current, %{name: name, extra: extra, vsn: vsn})
    Module.put_attribute(module, :phoenix_live_sessions, %{name: name, extra: extra, vsn: vsn})
  end

  @live_session_opts [:on_mount, :root_layout, :session]
  defp validate_live_session_opts(opts, module, _name) when is_list(opts) do
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

      {:on_mount, on_mount}, acc ->
        hooks = Enum.map(List.wrap(on_mount), &Phoenix.LiveView.Lifecycle.on_mount(module, &1))
        Map.put(acc, :on_mount, hooks)

      {key, _val}, _acc ->
        raise ArgumentError, """
        unknown live_session option "#{inspect(key)}"

        Supported options include: #{inspect(@live_session_opts)}
        """
    end)
  end

  defp validate_live_session_opts(invalid, _module, name) do
    raise ArgumentError, """
    expected second argument to live_session to be a list of options, got:

        live_session #{inspect(name)}, #{inspect(invalid)}
    """
  end

  @doc """
  Fetches the LiveView and merges with the controller flash.

  Replaces the default `:fetch_flash` plug used by `Phoenix.Router`.

  ## Examples

      defmodule MyAppWeb.Router do
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
  def __live__(router, live_view, action, opts)
      when is_list(action) and is_list(opts) do
    __live__(router, live_view, nil, Keyword.merge(action, opts))
  end

  def __live__(router, live_view, action, opts)
      when is_atom(action) and is_list(opts) do
    live_session =
      Module.get_attribute(router, :phoenix_live_session_current) ||
        %{name: :default, extra: %{session: %{}}, vsn: session_vsn(router)}

    live_view = Phoenix.Router.scoped_alias(router, live_view)
    {private, metadata, opts} = validate_live_opts!(opts)

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

  defp validate_live_opts!(opts) do
    {private, opts} = Keyword.pop(opts, :private, %{})
    {metadata, opts} = Keyword.pop(opts, :metadata, %{})

    Enum.each(opts, fn
      {:container, {tag, attrs}} when is_atom(tag) and is_list(attrs) ->
        :ok

      {:container, val} ->
        raise ArgumentError, """
        expected live :container to be a tuple matching {atom, attrs :: list}, got: #{inspect(val)}
        """

      {:as, as} when is_atom(as) ->
        :ok

      {:as, bad_val} ->
        raise ArgumentError, """
        expected live :as to be an atom, got: #{inspect(bad_val)}
        """

      {key, %{} = meta} when key in [:metadata, :private] and is_map(meta) ->
        :ok

      {key, bad_val} when key in [:metadata, :private] ->
        raise ArgumentError, """
        expected live :#{key} to be a map, got: #{inspect(bad_val)}
        """

      {key, val} ->
        raise ArgumentError, """
        unknown live option :#{key}.

        Supported options include: :container, :as, :metadata, :private.

        Got: #{inspect([{key, val}])}
        """
    end)

    {private, metadata, opts}
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

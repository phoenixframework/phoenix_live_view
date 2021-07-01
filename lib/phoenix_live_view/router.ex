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

  A `live_redirect` from the client will *not go through the plug pipeline*
  as a hard-refresh or initial HTTP render would. This means authentication,
  authorization, etc that may be done in the `Plug.Conn` pipeline must always
  be performed within the LiveView mount lifecycle. Live sessions allow you
  to support a shared security model by allowing `live_redirect`s to only be
  issued between routes defined under the same live session name. If a client
  attempts to live redirect to a different live session, it will be refused
  and a graceful client-side redirect will trigger a regular HTTP request to
  the attempted URL.

  *Note*: the live_session is tied to the LiveView and not the browser/cookie
  session. Logging out does not expire the live_session, therefore, one should
  avoid storing credential/authentication values, such as `current_user_id`, in
  the live_session and use the browser/cookie session instead.

  ## Options

  * `:session` - The optional extra session map or MFA tuple to be merged with
    the LiveView session. For example, `%{"admin" => true}`, `{MyMod, :session, []}`.
    For MFA, the function is invoked, passing the `%Plug.Conn{}` prepended to
    the arguments list.

  * `:root_layout` - The optional root layout tuple for the intial HTTP render to
    override any existing root layout set in the router.

  * `:on_mount` - The optional list of hooks to attach to the mount lifecycle _of
    each LiveView in the session_. Passing a single value is also accepted.

  ## Examples

      scope "/", MyAppWeb do
        pipe_through :browser

        live_session :default do
          live "/feed", FeedLive, :index
          live "/status", StatusLive, :index
          live "/status/:id", StatusLive, :show
        end

        live_session :admin, session: %{"admin" => true}, on_mount: MyAppWeb.LiveAdmin do
          live "/admin", AdminDashboardLive, :index
          live "/admin/posts", AdminPostLive, :index
        end
      end

  To avoid a false security of plug pipeline enforcement, avoid defining
  live session routes under different scopes and pipelines. For example, the following
  routes would share a live session, but go through different authenticate pipelines
  on first mount. This would work and be secure only if you were also enforcing
  the admin authentication in your mount, but could be confusing and error prone
  later if you are using only pipelines to gauge security. Instead of the following
  routes:

      live_session :default do
        scope "/" do
          pipe_through [:authenticate_user]
          live ...
        end

        scope "/admin" do
          pipe_through [:authenticate_user, :require_admin]
          live ...
        end
      end

  Prefer different live sessions to enforce a separation and guarantee
  live redirects may only happen between admin to admin routes, and
  default to default routes:

      live_session :default do
        scope "/" do
          pipe_through [:authenticate_user]
          live ...
        end
      end

      live_session :admin do
        scope "/admin" do
          pipe_through [:authenticate_user, :require_admin]
          live ...
        end
      end
  """
  defmacro live_session(name, do: block) do
    quote do
      live_session(unquote(name), [], do: unquote(block))
    end
  end

  defmacro live_session(name, opts, do: block) do
    quote do
      unquote(__MODULE__).__live_session__(__MODULE__, unquote(opts), unquote(name))
      unquote(block)
      Module.delete_attribute(__MODULE__, :phoenix_live_session_current)
    end
  end

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

    Module.put_attribute(module, :phoenix_live_session_current, {name, extra, vsn})
    Module.put_attribute(module, :phoenix_live_sessions, {name, extra, vsn})
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

      {:on_mount, mod}, acc when is_atom(mod) ->
        Map.put(acc, :on_mount, [Phoenix.LiveView.Lifecycle.on_mount(module, mod)])

      {:on_mount, {mod, fun} = id}, acc when is_atom(mod) and is_atom(fun) ->
        Map.put(acc, :on_mount, [Phoenix.LiveView.Lifecycle.on_mount(module, id)])

      {:on_mount, on_mount}, acc when is_list(on_mount) ->
        hooks = Enum.map(on_mount, &Phoenix.LiveView.Lifecycle.on_mount(module, &1))
        Map.put(acc, :on_mount, hooks)

      {:on_mount, bad_on_mount}, _acc ->
        raise ArgumentError, """
        invalid live_session :on_mount

        expected a list (or single value) of Module or {Module, Function}, got #{inspect(bad_on_mount)}
        """

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
  def __live__(router, live_view, action, opts)
      when is_list(action) and is_list(opts) do
    __live__(router, live_view, nil, Keyword.merge(action, opts))
  end

  def __live__(router, live_view, action, opts)
      when is_atom(action) and is_list(opts) do
    live_session =
      Module.get_attribute(router, :phoenix_live_session_current) ||
        {:default, %{session: %{}}, session_vsn(router)}

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

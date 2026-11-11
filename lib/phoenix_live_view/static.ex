defmodule Phoenix.LiveView.ReloadError do
  defexception [:message, :plug_status]
end

defmodule Phoenix.LiveView.Static do
  # Holds the logic for static rendering.
  @moduledoc false

  alias Phoenix.LiveView.{Socket, Utils, Diff, Route, Lifecycle}

  require Logger

  # Token version. Should be changed whenever new data is stored.
  @token_vsn 6
  @phoenix_reload_status "__phoenix_reload_status__"

  def token_vsn, do: @token_vsn

  # Max session age in seconds. Equivalent to 2 weeks.
  @max_session_age 1_209_600

  @doc """
  Acts as a view via put_view to maintain the
  controller render + instrumentation stack.
  """
  def render(_, %{content: content}) do
    content
  end

  @doc """
  Verifies a LiveView token.
  """
  def verify_token(endpoint, token) do
    case Phoenix.Token.verify(endpoint, Utils.salt!(endpoint), token, max_age: @max_session_age) do
      {:ok, {@token_vsn, term}} -> {:ok, term}
      {:ok, _} -> {:error, :outdated}
      {:error, :missing} -> {:error, :invalid}
      {:error, reason} when reason in [:expired, :invalid] -> {:error, reason}
    end
  end

  defp live_session(%Plug.Conn{} = conn) do
    case conn.private[:phoenix_live_view] do
      {_view, _opts, %{name: _name, extra: _extra} = lv_session} -> lv_session
      nil -> nil
    end
  end

  defp load_session(conn_or_socket_session, opts) do
    user_session = Keyword.get(opts, :session, %{})
    validate_session(user_session)
    {user_session, Map.merge(conn_or_socket_session, user_session)}
  end

  defp validate_session(session) do
    if is_map(session) and Enum.all?(session, fn {k, _} -> is_binary(k) end) do
      :ok
    else
      raise ArgumentError,
            "LiveView :session must be a map with string keys, got: #{inspect(session)}"
    end
  end

  defp maybe_get_session(conn) do
    Plug.Conn.get_session(conn)
  rescue
    _ -> %{}
  end

  defp maybe_put_live_layout(private, %{extra: %{layout: layout}}) do
    Map.put(private, :live_layout, layout)
  end

  defp maybe_put_live_layout(private, _live_session) do
    private
  end

  @doc """
  Renders a live view without spawning a LiveView server, unless the
  LiveView is adoptable.

  Returns `{:ok, content, assigns}`, or `{:stop, socket}` on redirects.

    * `conn` - the Plug.Conn struct form the HTTP request
    * `view` - the LiveView module

  ## Options

    * `:router` - the router the live view was built at
    * `:action` - the router action
    * `:session` - the required map of session data
    * `:container` - the optional tuple for the HTML tag and DOM attributes
  """
  def render(%Plug.Conn{} = conn, view, opts) do
    endpoint = Phoenix.Controller.endpoint_module(conn)

    case conn.req_cookies do
      %Plug.Conn.Unfetched{} ->
        do_render(conn, endpoint, view, opts)

      %{@phoenix_reload_status => status_token} ->
        conn = Plug.Conn.delete_resp_cookie(conn, @phoenix_reload_status)

        {status, exception, errored_view, stack} =
          case verify_token(endpoint, status_token) do
            {:ok, %{status: status, exception: exception, view: errored_view, stack: stack}}
            when is_integer(status) ->
              {status, exception, errored_view, stack}

            {:error, _reason} ->
              {500, nil, nil, []}
          end

        message = """
        #{errored_view} raised #{exception} during connected mount sending a #{status} response
        """

        raise Plug.Conn.WrapperError,
          conn: conn,
          kind: :error,
          reason: %Phoenix.LiveView.ReloadError{message: message, plug_status: status},
          stack: stack

      %{} ->
        do_render(conn, endpoint, view, opts)
    end
  end

  defp do_render(%Plug.Conn{} = conn, endpoint, view, opts) do
    conn_session = maybe_get_session(conn)
    {to_sign_session, mount_session} = load_session(conn_session, opts)
    live_session = live_session(conn)
    config = load_live!(view, :view)
    lifecycle = lifecycle(config, live_session)
    {tag, extended_attrs} = container(config, opts)
    router = Keyword.get(opts, :router)
    action = Keyword.get(opts, :action)
    flash = Map.get(conn.assigns, :flash) || Map.get(conn.private, :phoenix_flash, %{})
    request_url = Plug.Conn.request_url(conn)
    host_uri = URI.parse(request_url)

    socket =
      Utils.configure_socket(
        %Socket{endpoint: endpoint, view: view, router: router},
        %{
          assign_new: {conn.assigns, []},
          connect_params: %{},
          connect_info: conn,
          conn_session: conn_session,
          lifecycle: lifecycle,
          root_view: view,
          live_temp: %{}
        }
        |> maybe_put_live_layout(live_session),
        action,
        flash,
        host_uri
      )

    render = %{
      view: view,
      router: router,
      to_sign_session: to_sign_session,
      mount_session: mount_session,
      live_session: live_session,
      tag: tag,
      extended_attrs: extended_attrs,
      flash: flash,
      request_url: request_url
    }

    with %{} = adopt <- adopt_config(conn, endpoint, config),
         {:ok, _content, _assigns} = ok <- adopt_render(conn, adopt, socket, render) do
      ok
    else
      {:stop, %Socket{}} = stop -> stop
      :fallback -> dead_render(conn, socket, render)
      nil -> dead_render(conn, socket, render)
    end
  end

  defp dead_render(conn, socket, render) do
    %{view: view, router: router, request_url: request_url} = render

    case call_mount_and_handle_params!(
           socket,
           view,
           render.mount_session,
           conn.params,
           request_url
         ) do
      {:ok, socket} ->
        session_token =
          sign_root_session(socket, router, view, render.to_sign_session, render.live_session)

        data_attrs = [phx_session: session_token, phx_static: sign_static_token(socket)]
        data_attrs = if router, do: [phx_main: true] ++ data_attrs, else: data_attrs
        attrs = [{:id, socket.id}, {:data, data_attrs} | render.extended_attrs]

        try do
          {:ok, to_rendered_content_tag(socket, render.tag, view, attrs), socket.assigns}
        catch
          :throw, {:phoenix, :child_redirect, redirected, flash} ->
            {:stop, Utils.replace_flash(%{socket | redirected: redirected}, flash)}
        end

      {:stop, socket} ->
        {:stop, socket}
    end
  end

  ## Adoption

  # The process dictionary key that holds the detached session of the request, so the
  # LiveViews of a page join the same session, or :unavailable when it could not start.
  # LiveViews rendered in templates cannot return a conn to share it, see adopt_session/3.
  # Tests set it as private key of the conn to adopt LiveViews, see adopt_config/3.
  @adopt_key :phoenix_live_view_adopt

  defp adopt_config(conn, endpoint, %{adoptable: true}) do
    cond do
      # LiveViewTest renders in the test process, for example to share its database
      # sandbox, so we only adopt in tests that ask for it with this key
      match?({Plug.Adapters.Test.Conn, _}, conn.adapter) and conn.private[@adopt_key] != :test ->
        nil

      config = endpoint.config(:live_view)[:adopt] ->
        path =
          Keyword.get(config, :socket) ||
            raise ArgumentError, """
            the :adopt configuration of #{inspect(endpoint)} requires the :socket \
            the client connects to, for example:

                config :my_app, #{inspect(endpoint)},
                  live_view: [adopt: [socket: "/live"]]
            """

        if adopt_enabled?(Keyword.get(config, :enabled, true), conn) do
          %{
            path: path,
            max_pending: Keyword.get(config, :max_pending, 10_000),
            window_ms: Keyword.get(config, :window_ms)
          }
        end

      true ->
        raise ArgumentError, """
        LiveViews with adoptable: true require the :adopt configuration in your endpoint, \
        with the path of the socket the client connects to:

            config :my_app, #{inspect(endpoint)},
              live_view: [adopt: [socket: "/live"]]

        See "Adoptable LiveViews" in Phoenix.LiveView.Socket.
        """
    end
  end

  defp adopt_config(_conn, _endpoint, _config), do: nil

  defp adopt_enabled?(enabled, _conn) when is_boolean(enabled), do: enabled

  defp adopt_enabled?({module, function, args}, conn) do
    case apply(module, function, [conn | args]) do
      enabled when is_boolean(enabled) ->
        enabled

      other ->
        raise ArgumentError,
              "#{inspect(module)}.#{function}/#{length(args) + 1}, given as :enabled in " <>
                "the :adopt configuration, must return a boolean, got: #{inspect(other)}"
    end
  end

  defp adopt_enabled?(other, _conn) do
    raise ArgumentError,
          ":enabled in the :adopt configuration expects a boolean or MFA tuple, " <>
            "got: #{inspect(other)}"
  end

  # Mounts the LiveView in connected mode in a detached socket session, which the client
  # attaches to. The LiveView sends us its HTML, see Phoenix.LiveView.Channel.
  defp adopt_render(conn, adopt, %Socket{} = socket, render) do
    %{view: view, router: router} = render

    with {:ok, session, token} <- adopt_session(conn, socket.endpoint, adopt) do
      ref = make_ref()

      payload = %{
        "session" =>
          sign_root_session(socket, router, view, render.to_sign_session, render.live_session),
        "params" => %{"_mounts" => 0},
        # the payload is not serialized, so clients cannot send this key
        "adopt" => %{
          pid: self(),
          ref: ref,
          assigns: conn.assigns,
          flash: render.flash,
          # The LiveView renders forms with the CSRF token of this request,
          # which stores it in the session of its response.
          csrf_state: Plug.CSRFProtection.dump_state()
        }
      }

      payload = if router, do: Map.put(payload, "url", render.request_url), else: payload

      case Phoenix.Socket.join_detached(session, "lv:" <> socket.id, payload) do
        {:ok, join_ref} ->
          receive do
            {^ref, :rendered, content, assigns, static_token} ->
              data_attrs = [
                phx_session: payload["session"],
                phx_static: static_token,
                phx_adopt: token,
                phx_adopt_ref: join_ref,
                # the path the client connects to, which includes the path of the endpoint
                phx_adopt_socket: socket.endpoint.path(adopt.path)
              ]

              data_attrs = if router, do: [phx_main: true] ++ data_attrs, else: data_attrs
              attrs = [{:id, socket.id}, {:data, data_attrs} | render.extended_attrs]
              {:ok, content_tag(render.tag, attrs, content), assigns}
          after
            # the LiveView sends the HTML before it replies to the join
            5_000 -> :fallback
          end

        {:error, reply} ->
          receive do
            {^ref, :stop, %Socket{} = socket} ->
              stop_adopt_session(conn, session)
              {:stop, socket}

            {^ref, :exception, kind, reason, stacktrace} ->
              stop_adopt_session(conn, session)
              :erlang.raise(kind, reason, stacktrace)
          after
            # for example when the LiveView crashed, we render it again to raise
            0 ->
              Logger.debug(
                "Rendering #{inspect(view)} without adoption, as joining it failed: #{inspect(reply)}"
              )

              :fallback
          end
      end
    end
  end

  # The LiveViews of a request, including the ones that templates render, join the same
  # session, as the client attaches to one. We keep it in the process dictionary, as
  # adapters run each request in its own process or clear the process dictionary between
  # requests, like Bandit does for keep-alive connections. Phoenix.ConnTest dispatches all
  # requests of a test in the test process, so we tell them apart by the ref of the conn.
  defp adopt_session(conn, endpoint, adopt) do
    request = request_ref(conn)

    case Process.get(@adopt_key) do
      {^request, session, token} ->
        {:ok, session, token}

      {^request, :unavailable} ->
        :fallback

      _ ->
        opts = [max_pending: adopt.max_pending]
        opts = if adopt.window_ms, do: [window_ms: adopt.window_ms] ++ opts, else: opts

        case start_detached(conn, adopt.path, opts) do
          {:ok, session, token} ->
            Process.put(@adopt_key, {request, session, token})
            {:ok, session, token}

          {:error, reason} when reason in [:no_socket, :not_resumable, :not_a_phoenix_socket] ->
            raise ArgumentError, """
            LiveViews with adoptable: true require a resumable Phoenix.Socket at #{inspect(adopt.path)}, \
            the :socket in the :adopt configuration of #{inspect(endpoint)}, got: #{inspect(reason)}.

            Make sure the endpoint defines the socket with the :resumable WebSocket option:

                socket #{inspect(adopt.path)}, Phoenix.LiveView.Socket,
                  websocket: [resumable: true, connect_info: [session: @session_options]],
                  longpoll: [connect_info: [session: @session_options]]
            """

          # the limit of sessions without client, or the socket did not accept the request
          {:error, reason} ->
            Logger.debug("Rendering LiveViews without adoption: #{inspect(reason)}")
            Process.put(@adopt_key, {request, :unavailable})
            :fallback
        end
    end
  end

  # the page is not rendered, so other LiveViews of the request render without adoption
  defp stop_adopt_session(conn, session) do
    Phoenix.Socket.stop_detached(session)
    Process.put(@adopt_key, {request_ref(conn), :unavailable})
  end

  defp request_ref(%Plug.Conn{adapter: {Plug.Adapters.Test.Conn, %{ref: ref}}}), do: ref
  defp request_ref(%Plug.Conn{}), do: nil

  # TODO: Remove when we require Phoenix 1.9
  defp start_detached(conn, path, opts) do
    if function_exported?(Phoenix.Socket, :start_detached, 3) do
      Phoenix.Socket.start_detached(conn, path, opts)
    else
      raise ArgumentError, "LiveViews with adoptable: true require Phoenix 1.9 or later"
    end
  end

  @doc """
  Renders a nested live view without spawning a server.

    * `parent` - the parent `%Phoenix.LiveView.Socket{}`
    * `view` - the child LiveView module

  Accepts the same options as `render/3`.
  """
  def nested_render(
        %Socket{endpoint: endpoint, transport_pid: transport_pid} = parent,
        view,
        opts
      ) do
    config = load_live!(view, :view)
    container = container(config, opts)
    sticky? = Keyword.get(opts, :sticky, false)

    child_id =
      opts[:id] ||
        raise ArgumentError,
              "an :id is required when rendering child LiveView. " <>
                "The :id must uniquely identify the child."

    socket =
      Utils.configure_socket(
        %Socket{
          id: to_string(child_id),
          view: view,
          endpoint: endpoint,
          root_pid: if(sticky?, do: nil, else: parent.root_pid),
          parent_pid: if(sticky?, do: nil, else: self()),
          sticky?: sticky?,
          router: parent.router
        },
        %{
          assign_new: {parent.assigns.__assigns__, []},
          lifecycle: config.lifecycle,
          live_layout: false,
          root_view: if(sticky?, do: view, else: parent.private.root_view),
          live_temp: %{}
        },
        nil,
        %{},
        parent.host_uri
      )

    if transport_pid do
      connected_nested_render(parent, socket, view, container, opts, sticky?)
    else
      disconnected_nested_render(parent, socket, view, container, opts, sticky?)
    end
  end

  defp disconnected_nested_render(parent, socket, view, container, opts, sticky?) do
    conn_session = parent.private.conn_session
    {to_sign_session, mount_session} = load_session(conn_session, opts)
    {tag, extended_attrs} = container

    socket = put_in(socket.private[:conn_session], conn_session)

    socket =
      Utils.maybe_call_live_view_mount!(socket, view, :not_mounted_at_router, mount_session)

    session_token =
      if sticky?, do: sign_nested_session(parent, socket, view, to_sign_session, sticky?)

    if redir = socket.redirected do
      throw({:phoenix, :child_redirect, redir, Utils.get_flash(socket)})
    end

    if Lifecycle.stage_info(socket, view, :handle_params, 3).any? do
      raise ArgumentError, "handle_params/3 is not allowed on child LiveViews, only at the root"
    end

    attrs = [
      {:id, socket.id},
      {:data,
       [
         phx_session: session_token || "",
         phx_static: sign_static_token(socket)
       ] ++ if(sticky?, do: [phx_sticky: true], else: [phx_parent_id: parent.id])}
      | extended_attrs
    ]

    to_rendered_content_tag(socket, tag, view, attrs)
  end

  defp connected_nested_render(parent, socket, view, container, opts, sticky?) do
    {to_sign_session, _} = load_session(%{}, opts)
    {tag, extended_attrs} = container
    session_token = sign_nested_session(parent, socket, view, to_sign_session, sticky?)

    attrs = [
      {:id, socket.id},
      {:data,
       [
         phx_session: session_token,
         phx_static: ""
       ] ++ if(sticky?, do: [phx_sticky: true], else: [phx_parent_id: parent.id])}
      | extended_attrs
    ]

    content_tag(tag, attrs, "")
  end

  defp to_rendered_content_tag(socket, tag, view, attrs) do
    rendered = Phoenix.LiveView.Renderer.to_rendered(socket, view)

    {diff, _, _} =
      Diff.render(socket, rendered, Diff.new_fingerprints(), Diff.new_components())

    content_tag(tag, attrs, Diff.to_iodata(diff))
  end

  defp content_tag(tag, attrs, content) do
    tag = to_string(tag)
    {:safe, attrs} = Phoenix.HTML.attributes_escape(attrs)
    {:safe, [?<, tag, attrs, ?>, content, ?<, ?/, tag, ?>]}
  end

  defp load_live!(view_or_component, kind) do
    case view_or_component.__live__() do
      %{kind: ^kind} = config ->
        config

      %{kind: other} ->
        raise "expected #{inspect(view_or_component)} to be a #{kind}, but it is a #{other}"
    end
  end

  defp lifecycle(%{lifecycle: lifecycle}, %{extra: %{on_mount: on_mount}}) do
    %{lifecycle | mount: on_mount ++ lifecycle.mount}
  end

  defp lifecycle(%{lifecycle: lifecycle}, _) do
    lifecycle
  end

  defp call_mount_and_handle_params!(socket, view, session, params, uri) do
    mount_params = if socket.router, do: params, else: :not_mounted_at_router

    socket
    |> Utils.maybe_call_live_view_mount!(view, mount_params, session, uri)
    |> mount_handle_params(view, params, uri)
    |> case do
      {:noreply, %Socket{redirected: {:live, _, _}} = socket} ->
        {:stop, socket}

      {:noreply, %Socket{redirected: {:redirect, _opts}} = new_socket} ->
        {:stop, new_socket}

      {:noreply, %Socket{redirected: nil} = new_socket} ->
        {:ok, new_socket}
    end
  end

  defp mount_handle_params(%Socket{redirected: mount_redir} = socket, view, params, uri) do
    lifecycle = Lifecycle.stage_info(socket, view, :handle_params, 3)

    cond do
      mount_redir ->
        {:noreply, socket}

      not lifecycle.any? ->
        {:noreply, socket}

      is_nil(socket.router) ->
        # Let the callback fail for the usual reasons
        Route.invalid_handle_params!(view)

      true ->
        Utils.call_handle_params!(socket, view, lifecycle.exported?, params, uri)
    end
  end

  defp sign_root_session(%Socket{} = socket, router, view, session, live_session) do
    live_session_name =
      case live_session do
        %{name: name} -> name
        nil -> nil
      end

    # IMPORTANT: If you change the second argument, @token_vsn has to be bumped.
    sign_token(socket.endpoint, %{
      id: socket.id,
      view: view,
      root_view: view,
      router: router,
      live_session_name: live_session_name,
      parent_pid: nil,
      root_pid: nil,
      session: session
    })
  end

  defp sign_nested_session(%Socket{} = parent, %Socket{} = child, view, session, sticky?) do
    # IMPORTANT: If you change the second argument, @token_vsn has to be bumped.
    sign_token(parent.endpoint, %{
      id: child.id,
      view: view,
      root_view: if(sticky?, do: view, else: parent.private.root_view),
      router: parent.router,
      parent_pid: if(sticky?, do: nil, else: self()),
      root_pid: if(sticky?, do: nil, else: parent.root_pid),
      session: session
    })
  end

  # The static token is computed only on disconnected render and it keeps
  # the information that is only available during disconnected renders,
  # such as assign_new.
  @doc false
  def sign_static_token(%Socket{id: id, endpoint: endpoint} = socket) do
    # IMPORTANT: If you change the second argument, @token_vsn has to be bumped.
    sign_token(endpoint, %{
      id: id,
      flash: socket.assigns.flash,
      assign_new: assign_new_keys(socket)
    })
  end

  @doc """
  Signs a LiveView token.
  """
  def sign_token(endpoint, data, opts \\ []) do
    Phoenix.Token.sign(endpoint, Utils.salt!(endpoint), {@token_vsn, data}, opts)
  end

  defp container(%{container: {tag, attrs}}, opts) do
    case opts[:container] do
      {tag, extra} -> {tag, Keyword.merge(attrs, extra)}
      nil -> {tag, attrs}
    end
  end

  defp assign_new_keys(socket) do
    {_, keys} = socket.private.assign_new
    keys
  end
end

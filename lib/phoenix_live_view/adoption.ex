defmodule Phoenix.LiveView.Adoption do
  # Adoptable LiveViews, see "Adoptable LiveViews" in Phoenix.LiveView.Socket.
  #
  # The request mounts an adoptable LiveView in connected mode, in a detached session of
  # the LiveView socket, see Phoenix.Socket.start_detached/3. The client attaches to the
  # session and adopts the LiveView. This module holds both sides of the mount:
  #
  #   * the request joins the LiveView with mount/5, which Phoenix.LiveView.Static uses
  #     to render the page
  #
  #   * the channel finds the data of the request with fetch/1 and sends the outcome of
  #     the mount to the request with the reply functions, see Phoenix.LiveView.Channel
  #
  # The channel replies to the request before it replies to the join, so the request
  # has the outcome when the join returns. The reply the session keeps for the client
  # only contains what the client receives on any join.
  @moduledoc false

  alias Phoenix.LiveView.Socket

  require Logger

  # The process dictionary key that holds the detached session of the request, so the
  # LiveViews of a page join the same session, see session/2. Tests set it as private key
  # of the conn to adopt LiveViews, see config/3.
  @key :phoenix_live_view_adopt

  # The conn private key that identifies the request, see request_ref/1.
  @request_key :phoenix_live_view_adopt_request

  ## Request

  @doc """
  Returns the adoption config of the request, or nil when it renders the LiveView without
  adoption.
  """
  def config(conn, endpoint, %{adoptable: true}) do
    cond do
      # LiveViewTest renders in the test process, for example to share its database
      # sandbox, so we only adopt in tests that ask for it with this key
      match?({Plug.Adapters.Test.Conn, _}, conn.adapter) and conn.private[@key] != :test ->
        nil

      config = endpoint.config(:live_view)[:adopt] ->
        path =
          Keyword.get(config, :socket) ||
            raise ArgumentError, """
            Set :socket in the :adopt configuration of #{inspect(endpoint)} \
            to the socket path used by the client, for example:

                config :my_app, #{inspect(endpoint)},
                  live_view: [adopt: [socket: "/live"]]
            """

        if enabled?(Keyword.get(config, :enabled, true), conn) do
          %{
            endpoint: endpoint,
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

  def config(_conn, _endpoint, _live_config), do: nil

  defp enabled?(enabled, _conn) when is_boolean(enabled), do: enabled

  defp enabled?({module, function, args}, conn) do
    case apply(module, function, [conn | args]) do
      enabled when is_boolean(enabled) ->
        enabled

      other ->
        raise ArgumentError,
              "#{inspect(module)}.#{function}/#{length(args) + 1}, given as :enabled in " <>
                "the :adopt configuration, must return a boolean, got: #{inspect(other)}"
    end
  end

  defp enabled?(other, _conn) do
    raise ArgumentError,
          ":enabled in the :adopt configuration expects a boolean or MFA tuple, " <>
            "got: #{inspect(other)}"
  end

  @doc """
  Mounts the LiveView of `topic` in the session of the request, with the join `payload`
  that a client would send.

  Returns one of:

    * `{:ok, rendered}` - the LiveView mounted, with its `:content`, `:assigns`, its
      `:static_token`, and the data `:attrs` the client attaches with

    * `{:stop, socket}` - the LiveView redirected, so the request redirects

    * `:unavailable` - the LiveView did not mount, for example because the node reached
      the `:max_pending` limit, so the request renders it without adoption

  Raises the exceptions of the mount, as a disconnected mount does.
  """
  def mount(conn, config, topic, payload, flash) do
    with {:ok, session, token} <- session(conn, config) do
      ref = make_ref()

      # what only the request knows, which clients cannot set
      data = %{
        pid: self(),
        ref: ref,
        assigns: conn.assigns,
        flash: flash,
        # The LiveView renders forms with the CSRF token of this request,
        # which stores it in the session of its response.
        csrf_state: Plug.CSRFProtection.dump_state()
      }

      join_opts = [assigns: %{@key => data}]

      case Phoenix.Socket.join_detached(session, topic, payload, join_opts) do
        {:ok, join_ref} ->
          receive do
            {^ref, :rendered, content, assigns, static_token} ->
              attrs = [
                phx_adopt: token,
                phx_adopt_ref: join_ref,
                # the path the client connects to, which includes the path of the endpoint
                phx_adopt_socket: config.endpoint.path(config.path)
              ]

              {:ok,
               %{content: content, assigns: assigns, static_token: static_token, attrs: attrs}}
          after
            0 ->
              stop(conn, session)
              raise "#{inspect(topic)} joined without sending its content to the request"
          end

        {:error, reply} ->
          receive do
            {^ref, :stop, %Socket{} = socket} ->
              stop(conn, session)
              {:stop, socket}

            {^ref, :exception, kind, reason, stacktrace} ->
              stop(conn, session)
              :erlang.raise(kind, reason, stacktrace)
          after
            # the join failed before the mount, for example with a stale session token
            0 ->
              Logger.debug(
                "Rendering #{topic} without adoption, as its join failed: #{inspect(reply)}"
              )

              :unavailable
          end
      end
    end
  end

  # The LiveViews of a request, including the ones that templates render, join the same
  # session, as the client attaches to one. We keep it in the process dictionary, as
  # templates cannot return a conn, and key it by the request, see request_ref/1.
  defp session(conn, config) do
    request = request_ref(conn)

    case Process.get(@key) do
      {^request, session, token} ->
        {:ok, session, token}

      {^request, :unavailable} ->
        :unavailable

      _ ->
        opts = [max_pending: config.max_pending]
        opts = if config.window_ms, do: [window_ms: config.window_ms] ++ opts, else: opts

        case start_detached(conn, config.path, opts) do
          {:ok, session, token} ->
            Process.put(@key, {request, session, token})
            {:ok, session, token}

          {:error, reason} when reason in [:no_socket, :not_resumable, :not_a_phoenix_socket] ->
            raise ArgumentError, """
            Cannot adopt LiveViews through socket #{inspect(config.path)} \
            on #{inspect(config.endpoint)}: #{inspect(reason)}.

            Configure :adopt[:socket] to point to a Phoenix socket with resumption enabled:

                socket #{inspect(config.path)}, Phoenix.LiveView.Socket,
                  websocket: [resumable: true, connect_info: [session: @session_options]],
                  longpoll: [connect_info: [session: @session_options]]
            """

          # the limit of sessions without client, or the socket did not accept the request
          {:error, reason} ->
            Logger.debug("Rendering LiveViews without adoption: #{inspect(reason)}")
            Process.put(@key, {request, :unavailable})
            :unavailable
        end
    end
  end

  # the page is not rendered, so other LiveViews of the request render without adoption
  defp stop(conn, session) do
    Phoenix.Socket.stop_detached(session)
    Process.put(@key, {request_ref(conn), :unavailable})
  end

  @doc """
  Marks the conn of a request that `Phoenix.LiveView.Controller.live_render/3` renders,
  so its LiveViews, including the ones of its layout, join the session of this request.
  """
  def put_request_ref(conn) do
    Plug.Conn.put_private(conn, @request_key, make_ref())
  end

  # LiveViews that controller templates render with live_render/3 have no ref. For them,
  # we rely on the web server to run each request in its own process or to clear the
  # process dictionary between requests, as Cowboy and Bandit do. Phoenix.ConnTest
  # dispatches all requests of a test in the test process, so there we tell them apart
  # by the ref of the test adapter.
  defp request_ref(%Plug.Conn{private: %{@request_key => ref}}), do: ref
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

  ## Channel

  @doc """
  Returns the data of the request that mounts the LiveView, or nil when a client joined.
  """
  def fetch(%Phoenix.Socket{assigns: %{@key => data}}), do: data
  def fetch(%Phoenix.Socket{}), do: nil

  @doc """
  Loads the CSRF state of the request into the LiveView.
  """
  def load_csrf_state(endpoint, data) do
    Plug.CSRFProtection.load_state(endpoint.config(:secret_key_base), data.csrf_state)
  end

  @doc """
  Prepares the private data of the mount. `assign_new/3` uses the assigns of the request,
  as in a disconnected mount. The client did not join, so there are no connect params,
  see `Phoenix.LiveView.get_connect_params/1`.
  """
  def put_mount_private(%{assign_new: {_assigns, keys}} = mount_priv, data) do
    %{mount_priv | assign_new: {data.assigns, keys}, connect_params: %{}}
    |> Map.put(:adopted_mount, true)
  end

  @doc """
  Sends the HTML, assigns and static token of the mounted LiveView to the request.
  """
  def reply_rendered(data, content, assigns, static_token) do
    send(data.pid, {data.ref, :rendered, content, assigns, static_token})
  end

  @doc """
  Sends the socket of a LiveView that redirected on mount to the request.
  """
  def reply_stop(data, %Socket{} = socket) do
    send(data.pid, {data.ref, :stop, socket})
  end

  @doc """
  Sends an error, exit or throw of the mount to the request, which raises it.
  """
  def reply_exception(data, kind, reason, stacktrace) do
    send(data.pid, {data.ref, :exception, kind, reason, stacktrace})
  end
end

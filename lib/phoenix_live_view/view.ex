defmodule Phoenix.LiveView.View do
  @moduledoc false

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  # Token version. Should be changed whenever new data is stored.
  @token_vsn 1

  # Max session age in seconds. Equivalent to 2 weeks.
  @max_session_age 1_209_600

  # Total length of 8 bytes when 64 encoded
  @rand_bytes 6

  # All available mount options
  @mount_opts [:temporary_assigns]

  @doc """
  Strips socket of redundant assign data for rendering.
  """
  def strip_for_render(%Socket{} = socket) do
    if connected?(socket) do
      %Socket{socket | assigns: %{}}
    else
      socket
    end
  end

  @doc """
  Clears the changes from the socket assigns.
  """
  def clear_changed(%Socket{} = socket) do
    %Socket{socket | changed: %{}, assigns: Map.merge(socket.assigns, socket.temporary)}
  end

  @doc """
  Checks if the socket changed.
  """
  def changed?(%Socket{changed: changed}), do: changed != %{}

  @doc """
  Returns the socket's flash messages.
  """
  def get_flash(%Socket{private: private}) do
    private[:flash]
  end

  @doc """
  Puts the root fingerprint.
  """
  def put_prints(%Socket{} = socket, fingerprints) do
    %Socket{socket | fingerprints: fingerprints}
  end

  @doc """
  Returns the browser's DOM id for the nested socket.
  """
  def child_id(%Socket{id: parent_id}, child_view, child_id) do
    parent_id <> inspect(child_view) <> to_string(child_id)
  end

  @doc """
  Returns true if the socket is connected.
  """
  def connected?(%Socket{connected?: true}), do: true
  def connected?(%Socket{connected?: false}), do: false

  @doc """
  Returns the connect params.
  """
  def get_connect_params(%Socket{} = socket) do
    cond do
      child?(socket) ->
        raise RuntimeError, """
        attempted to read connect_params from a nested child LiveView #{inspect(socket.view)}.

        Only the root LiveView has access to connect params.
        """

      connect_params = socket.private[:connect_params] ->
        if connected?(socket), do: connect_params, else: nil

      true ->
        raise RuntimeError, """
        attempted to read connect_params outside of #{inspect(socket.view)}.mount/2.

        connect_params only exist while mounting. If you require access to this information
        after mount, store the state in socket assigns.
        """
    end
  end

  @doc """
  Configures the socket for use.
  """
  def configure_socket(%{id: nil} = socket, private) do
    configure_socket(%{socket | id: random_id()}, private)
  end

  def configure_socket(socket, private) do
    private =
      private
      |> Map.put_new(:assigned_new, {%{}, []})
      |> Map.put_new(:connect_params, %{})

    %{socket | private: private}
  end

  @doc """
  Prunes any data no longer needed after mount.
  """
  def post_mount_prune(%Socket{} = socket) do
    socket
    |> clear_changed()
    |> drop_private([:connect_params])
  end

  @doc """
  Prunes the assigned_new information from the socket.
  """
  def prune_assigned_new(%Socket{} = socket) do
    drop_private(socket, [:assigned_new])
  end

  @doc """
  Annotates the socket for redirect.
  """
  def put_redirect(%Socket{redirected: nil} = socket, :redirect, %{to: _} = opts) do
    %Socket{socket | redirected: {:redirect, opts}}
  end

  def put_redirect(%Socket{redirected: nil} = socket, :live, %{to: _, kind: kind} = opts)
      when kind in [:push, :replace] do
    if child?(socket) do
      raise ArgumentError, """
      attempted to live_redirect from a nested child socket.

      Only the root parent LiveView can issue live redirects.
      """
    else
      %Socket{socket | redirected: {:live, opts}}
    end
  end

  def put_redirect(%Socket{redirected: to} = _socket, _kind, _opts) do
    raise ArgumentError, "socket already prepared to redirect with #{inspect(to)}"
  end

  def drop_redirect(%Socket{} = socket) do
    %Socket{socket | redirected: nil}
  end

  @doc """
  Renders the view into a `%Phoenix.LiveView.Rendered{}` struct.
  """
  def render(%Socket{} = socket, view) do
    assigns = Map.put(socket.assigns, :socket, strip_for_render(socket))

    case view.render(assigns) do
      %Phoenix.LiveView.Rendered{} = rendered ->
        rendered

      other ->
        raise RuntimeError, """
        expected #{inspect(view)}.render/1 to return a %Phoenix.LiveView.Rendered{} struct

        Ensure your render function uses ~L, or your eex template uses the .leex extension.

        Got:

            #{inspect(other)}

        """
    end
  end

  @doc """
  Verifies the session token.

  Returns the decoded map of session data or an error.

  ## Examples

      iex> verify_session(AppWeb.Endpoint, encoded_token, static_token)
      {:ok, %{} = decoded_session}

      iex> verify_session(AppWeb.Endpoint, "bad token", "bac static")
      {:error, :invalid}

      iex> verify_session(AppWeb.Endpoint, "expired", "expired static")
      {:error, :expired}
  """
  def verify_session(endpoint, session_token, static_token) do
    with {:ok, session} <- verify_token(endpoint, session_token),
         {:ok, static} <- verify_static_token(endpoint, static_token) do
      {:ok, Map.merge(session, static)}
    end
  end

  defp verify_static_token(_endpoint, nil), do: {:ok, %{assigned_new: []}}
  defp verify_static_token(endpoint, token), do: verify_token(endpoint, token)

  defp verify_token(endpoint, token) do
    case Phoenix.Token.verify(endpoint, salt!(endpoint), token, max_age: @max_session_age) do
      {:ok, {@token_vsn, term}} -> {:ok, term}
      {:ok, _} -> {:error, :outdated}
      {:error, _} = error -> error
    end
  end

  @doc """
  Signs the socket's flash into a token if it has been set.
  """
  def sign_flash(%Socket{}, nil), do: nil

  def sign_flash(%Socket{endpoint: endpoint}, %{} = flash) do
    LiveView.Flash.sign_token(endpoint, salt!(endpoint), flash)
  end

  @doc """
  Returns the configured signing salt for the endpoint.
  """
  def salt!(endpoint) when is_atom(endpoint) do
    endpoint.config(:live_view)[:signing_salt] ||
      raise ArgumentError, """
      no signing salt found for #{inspect(endpoint)}.

      Add the following LiveView configuration to your config/config.exs:

          config :my_app, MyAppWeb.Endpoint,
              ...,
              live_view: [signing_salt: "#{random_encoded_bytes()}"]

      """
  end

  @doc """
  Returns the internal or external matched LiveView route info for the given uri
  """
  def live_link_info!(router, view, uri) do
    %URI{host: host, path: path, query: query} = URI.parse(uri)
    query_params = if query, do: Plug.Conn.Query.decode(query), else: %{}

    case Phoenix.Router.route_info(router, "GET", path, host) do
      %{plug: Phoenix.LiveView.Plug, plug_opts: ^view, path_params: path_params} ->
        {:internal, Map.merge(query_params, path_params)}

      %{} ->
        :external

      :error ->
        raise ArgumentError,
              "cannot invoke handle_params nor live_redirect/live_link to #{inspect(uri)} " <>
                "because it isn't defined in #{inspect(router)}"
    end
  end

  @doc """
  Raises error message for invalid view mount.
  """
  def raise_invalid_mount(other, view) do
    raise ArgumentError, """
    invalid result returned from #{inspect(view)}.mount/2.

    Expected {:ok, socket} | {:ok, socket, opts}, got: #{inspect(other)}
    """
  end

  @doc """
  Raises error message for bad live redirect.
  """
  def raise_bad_stop_and_live_redirect!() do
    raise RuntimeError, """
    attempted to live redirect while stopping.

    a LiveView cannot be stopped while issuing a live redirect to the client. \
    Use redirect/2 instead if you wish to stop and redirect.
    """
  end

  @doc """
  Renders a live view without spawning a LiveView server.

  * `conn` - the Plug.Conn struct form the HTTP request
  * `view` - the LiveView module

  ## Options

    * `:session` - the required map of session data
    * `:container` - the optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`
  """
  def static_render(%Plug.Conn{} = conn, view, opts) do
    session = Keyword.get(opts, :session, %{})
    config = load_live!(view)
    {tag, extended_attrs} = container(config, opts)
    router = Phoenix.Controller.router_module(conn)
    endpoint = Phoenix.Controller.endpoint_module(conn)

    socket =
      configure_socket(
        %Socket{
          endpoint: endpoint,
          router: router,
          view: view,
        },
        %{
          assigned_new: {conn.assigns, []},
          phoenix_live_disconnected: {conn.params, Plug.Conn.request_url(conn)}
        }
      )

    case call_mount_and_handle_params!(socket, view, session) do
      {:ok, socket} ->
        attrs = [
          {:data,
           phx_id: socket.id,
           phx_view: inspect(view),
           phx_session: sign_root_session(socket, view, session)}
          | extended_attrs
        ]

        html = Phoenix.HTML.Tag.content_tag(tag, render(socket, view), attrs)
        {:ok, html}

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  @doc """
  Renders only the static container of the Liveview.

  Accepts same options as `static_render/3`.

  This is called by external live links.
  """
  def static_render_container(%Plug.Conn{} = conn, view, opts) do
    session = Keyword.get(opts, :session, %{})
    config = load_live!(view)
    {tag, extended_attrs} = container(config, opts)
    router = Phoenix.Controller.router_module(conn)
    endpoint = Phoenix.Controller.endpoint_module(conn)

    socket =
      configure_socket(
        %Socket{
          endpoint: endpoint,
          router: router,
          view: view
        },
        %{assigned_new: {conn.assigns, []}}
      )

    session_token = sign_root_session(socket, view, session)

    attrs = [
      {:data,
       phx_id: socket.id,
       phx_view: inspect(view),
       phx_session: session_token}
      | extended_attrs
    ]

    tag
    |> Phoenix.HTML.Tag.content_tag(attrs, do: nil)
    |> Phoenix.HTML.safe_to_string()
  end

  @doc """
  Renders a nested live view without spawning a server.

  * `parent` - the parent `%Phoenix.LiveView.Socket{}`
  * `view` - the child LiveView module

  Accepts the same options as `static_render/3`.
  """
  def nested_static_render(%Socket{endpoint: endpoint, router: router} = parent, view, opts) do
    session = Keyword.get(opts, :session, %{})
    config = load_live!(view)
    container = container(config, opts)

    child_id =
      opts[:child_id] ||
        raise ArgumentError,
              "a :child_id is required when rendering child LiveView. The :child_id " <>
                "must uniquely identify a children. Note the :child_is id NOT the DOM id."

    socket =
      %Socket{
        id: child_id(parent, view, child_id),
        endpoint: endpoint,
        router: router,
        parent_pid: self()
      }

    if connected?(parent) do
      connected_nested_static_render(parent, socket, view, session, container)
    else
      disconnected_nested_static_render(parent, socket, view, session, container)
    end
  end

  defp disconnected_nested_static_render(parent, socket, view, session, container) do
    {tag, extended_attrs} = container

    socket =
      configure_socket(socket, %{
        assigned_new: {parent.assigns, []},
        phoenix_live_disconnected: parent.private.phoenix_live_disconnected
      })

    # We don't have to worry about redirects because we cannot redirect from child.
    {:ok, socket} = call_mount_and_handle_params!(socket, view, session)

    attrs = [
      {:data,
       phx_id: socket.id,
       phx_view: inspect(view),
       phx_session: "",
       phx_static: sign_static_token(socket),
       phx_parent_id: parent.id}
      | extended_attrs
    ]

    Phoenix.HTML.Tag.content_tag(tag, render(socket, view), attrs)
  end

  defp connected_nested_static_render(parent, socket, view, session, container) do
    socket = configure_socket(socket, %{assigned_new: {parent.assigns, []}})
    {tag, extended_attrs} = container
    session_token = sign_nested_session(socket, view, session)

    attrs = [
      {:data,
       phx_id: socket.id,
       phx_parent_id: parent.id,
       phx_view: inspect(view),
       phx_session: session_token,
       phx_static: ""}
      | extended_attrs
    ]

    Phoenix.HTML.Tag.content_tag(tag, "", attrs)
  end

  defp call_mount_and_handle_params!(socket, view, session) do
    %{private: %{phoenix_live_disconnected: {params, uri}}} = socket

    socket
    |> call_mount!(view, session)
    |> mount_handle_params(view, params, uri)
    |> case do
      {:noreply, %Socket{redirected: nil} = new_socket} ->
        {:ok, new_socket}

      {:noreply, %Socket{redirected: redirected}} ->
        {:stop, redirected}

      {:stop, %Socket{redirected: {:live, _}}} ->
        raise_bad_stop_and_live_redirect!()

      {:stop, %Socket{redirected: redirected}} ->
        {:stop, redirected}
    end
  end

  defp mount_handle_params(socket, view, params, uri) do
    if function_exported?(view, :handle_params, 3) do
      view.handle_params(params, uri, socket)
    else
      {:noreply, socket}
    end
  end

  @doc """
  Calls the view's `mount/2` callback while handling possible options.
  """
  def call_mount!(%Socket{} = socket, view, session) do
    socket =
      case view.mount(session, socket) do
        {:ok, %Socket{} = socket, opts} when is_list(opts) ->
          Enum.reduce(opts, socket, fn {key, val}, acc -> mount_opt(acc, key, val) end)

        {:ok, %Socket{} = socket} ->
          socket

        other ->
          raise_invalid_mount(other, view)
      end

    if socket.redirected do
      raise "cannot redirect socket on mount/2"
    end

    socket
  end

  defp sign_root_session(%Socket{id: id, router: router, endpoint: endpoint}, view, session) do
    # IMPORTANT: If you change the third argument, @token_vsn has to be bumped.
    sign_token(endpoint, salt!(endpoint), %{
      id: id,
      view: view,
      router: router,
      parent_pid: nil,
      session: session
    })
  end

  defp sign_nested_session(%Socket{id: id, router: router, endpoint: endpoint}, view, session) do
    # IMPORTANT: If you change the third argument, @token_vsn has to be bumped.
    sign_token(endpoint, salt!(endpoint), %{
      id: id,
      view: view,
      router: router,
      parent_pid: self(),
      session: session
    })
  end

  defp sign_static_token(%Socket{id: id, endpoint: endpoint} = socket) do
    # IMPORTANT: If you change the third argument, @token_vsn has to be bumped.
    sign_token(endpoint, salt!(endpoint), %{
      id: id,
      assigned_new: assigned_new_keys(socket)
    })
  end

  defp random_encoded_bytes do
    @rand_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
  end

  defp random_id, do: "phx-" <> random_encoded_bytes()

  defp sign_token(endpoint_mod, salt, data) do
    Phoenix.Token.sign(endpoint_mod, salt, {@token_vsn, data})
  end

  defp assigned_new_keys(socket) do
    {_, keys} = socket.private.assigned_new
    keys
  end

  defp child?(%Socket{parent_pid: pid}), do: is_pid(pid)

  defp load_live!(view) do
    view.__live__()
  end

  defp container(%{container: {tag, attrs}}, opts) do
    case opts[:container] do
      {tag, extra} -> {tag, Keyword.merge(attrs, extra)}
      nil -> {tag, attrs}
    end
  end

  defp mount_opt(%Socket{} = socket, key, val) when key in @mount_opts do
    do_mount_opt(socket, key, val)
  end

  defp mount_opt(%Socket{view: view}, key, val) do
    raise ArgumentError, """
    invalid option returned from #{inspect(view)}.mount/2.

    Expected keys to be one of #{inspect(@mount_opts)}
    got: #{inspect(key)}: #{inspect(val)}
    """
  end

  defp do_mount_opt(socket, :temporary_assigns, keys) when is_list(keys) do
    temp_assigns = for(key <- keys, into: %{}, do: {key, nil})
    %Socket{socket | assigns: Map.merge(temp_assigns, socket.assigns), temporary: temp_assigns}
  end

  defp drop_private(%Socket{private: private} = socket, keys) do
    %Socket{socket | private: Map.drop(private, keys)}
  end
end

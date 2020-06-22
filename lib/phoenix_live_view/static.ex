defmodule Phoenix.LiveView.Static do
  # Holds the logic for static rendering.
  @moduledoc false

  alias Phoenix.LiveView.{Socket, Utils, Diff}

  # Token version. Should be changed whenever new data is stored.
  @token_vsn 4

  def token_vsn, do: @token_vsn

  # Max session age in seconds. Equivalent to 2 weeks.
  @max_session_age 1_209_600

  @doc """
  Acts as a view via put_view to maintain the
  controller render + instrumentation stack.
  """
  def render("template.html", %{content: content}) do
    content
  end

  def render(_other, _assigns), do: nil

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
    with {:ok, %{id: id} = session} <- verify_token(endpoint, session_token),
         {:ok, static} <- verify_static_token(endpoint, id, static_token) do
      {:ok, Map.merge(session, static)}
    end
  end

  defp verify_static_token(_endpoint, _id, nil), do: {:ok, %{assign_new: []}}

  defp verify_static_token(endpoint, id, token) do
    case verify_token(endpoint, token) do
      {:ok, %{id: ^id}} = ok -> ok
      {:ok, _} -> {:error, :invalid}
      {:error, _} = error -> error
    end
  end

  defp verify_token(endpoint, token) do
    case Phoenix.Token.verify(endpoint, Utils.salt!(endpoint), token, max_age: @max_session_age) do
      {:ok, {@token_vsn, term}} -> {:ok, term}
      {:ok, _} -> {:error, :outdated}
      {:error, _} = error -> error
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

  @doc """
  Renders a live view without spawning a LiveView server.

    * `conn` - the Plug.Conn struct form the HTTP request
    * `view` - the LiveView module

  ## Options

    * `:router` - the router the live view was built at
    * `:action` - the router action
    * `:session` - the required map of session data
    * `:container` - the optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`
  """
  def render(%Plug.Conn{} = conn, view, opts) do
    conn_session = maybe_get_session(conn)
    {to_sign_session, mount_session} = load_session(conn_session, opts)
    config = load_live!(view, :view)
    {tag, extended_attrs} = container(config, opts)
    router = Keyword.get(opts, :router)
    action = Keyword.get(opts, :action)
    endpoint = Phoenix.Controller.endpoint_module(conn)
    flash = Map.get(conn.private, :phoenix_flash, %{})
    request_url = Plug.Conn.request_url(conn)
    host_uri = URI.parse(request_url)

    socket =
      Utils.configure_socket(
        %Socket{endpoint: endpoint, view: view, root_view: view, router: router},
        %{
          assign_new: {conn.assigns, []},
          connect_params: %{},
          connect_info: %{},
          conn_session: conn_session
        },
        action,
        flash,
        host_uri
      )

    case call_mount_and_handle_params!(socket, view, mount_session, conn.params, request_url) do
      {:ok, socket} ->
        data_attrs = [
          phx_view: config.name,
          phx_session: sign_root_session(socket, router, view, to_sign_session),
          phx_static: sign_static_token(socket)
        ]

        data_attrs = if(router, do: [phx_main: true], else: []) ++ data_attrs

        attrs = [
          {:id, socket.id},
          {:data, data_attrs}
          | extended_attrs
        ]

        try do
          {:ok, to_rendered_content_tag(socket, tag, view, attrs), socket.assigns}
        catch
          :throw, {:phoenix, :child_redirect, redirected, flash} ->
            {:stop, Utils.replace_flash(%{socket | redirected: redirected}, flash)}
        end

      {:stop, socket} ->
        {:stop, socket}
    end
  end

  @doc """
  Renders only the static container of the LiveView.

  Accepts same options as `render/3`.

  This is called by external live links.
  """
  def container_render(%Plug.Conn{} = conn, view, opts) do
    {to_sign_session, _mount_session} = load_session(maybe_get_session(conn), opts)
    config = load_live!(view, :view)
    {tag, extended_attrs} = container(config, opts)
    router = Keyword.get(opts, :router)
    action = Keyword.get(opts, :action)
    endpoint = Phoenix.Controller.endpoint_module(conn)
    flash = Map.get(conn.private, :phoenix_flash, %{})
    host_uri = conn |> Plug.Conn.request_url() |> URI.parse()

    socket =
      Utils.configure_socket(
        %Socket{endpoint: endpoint, view: view, root_view: view},
        %{assign_new: {conn.assigns, []}, connect_params: %{}, connect_info: %{}},
        action,
        flash,
        host_uri
      )

    session_token = sign_root_session(socket, router, view, to_sign_session)

    attrs = [
      {:id, socket.id},
      {:data, phx_view: config.name, phx_session: session_token}
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

  Accepts the same options as `render/3`.
  """
  def nested_render(%Socket{endpoint: endpoint, connected?: connected?} = parent, view, opts) do
    config = load_live!(view, :view)
    container = container(config, opts)

    child_id =
      opts[:id] ||
        raise ArgumentError,
              "an :id is required when rendering child LiveView. " <>
                "The :id must uniquely identify the child."

    socket =
      Utils.configure_socket(
        %Socket{
          id: to_string(child_id),
          root_view: parent.root_view,
          view: view,
          endpoint: endpoint,
          root_pid: parent.root_pid,
          parent_pid: self(),
          router: parent.router
        },
        %{assign_new: {parent.assigns.__assigns__, []}, phoenix_live_layout: false},
        nil,
        %{},
        parent.host_uri
      )

    if connected? do
      connected_nested_render(parent, config, socket, view, container, opts)
    else
      disconnected_nested_render(parent, config, socket, view, container, opts)
    end
  end

  defp disconnected_nested_render(parent, config, socket, view, container, opts) do
    conn_session = parent.private.conn_session
    {_, mount_session} = load_session(conn_session, opts)
    {tag, extended_attrs} = container

    socket = put_in(socket.private[:conn_session], conn_session)

    socket =
      Utils.maybe_call_live_view_mount!(socket, view, :not_mounted_at_router, mount_session)

    if redir = socket.redirected do
      throw({:phoenix, :child_redirect, redir, Utils.get_flash(socket)})
    end

    if exports_handle_params?(view) do
      raise ArgumentError, "handle_params/3 is not allowed on child LiveViews, only at the root"
    end

    attrs = [
      {:id, socket.id},
      {:data,
       phx_view: config.name,
       phx_session: "",
       phx_static: sign_static_token(socket),
       phx_parent_id: parent.id}
      | extended_attrs
    ]

    to_rendered_content_tag(socket, tag, view, attrs)
  end

  defp connected_nested_render(parent, config, socket, view, container, opts) do
    {to_sign_session, _} = load_session(%{}, opts)
    {tag, extended_attrs} = container
    session_token = sign_nested_session(parent, socket, view, to_sign_session)

    attrs = [
      {:id, socket.id},
      {:data,
       phx_parent_id: parent.id, phx_view: config.name, phx_session: session_token, phx_static: ""}
      | extended_attrs
    ]

    Phoenix.HTML.Tag.content_tag(tag, "", attrs)
  end

  defp to_rendered_content_tag(socket, tag, view, attrs) do
    rendered = Utils.to_rendered(socket, view)
    {_, diff, _} = Diff.render(socket, rendered, Diff.new_components())
    Phoenix.HTML.Tag.content_tag(tag, {:safe, Diff.to_iodata(diff)}, attrs)
  end

  defp load_live!(view_or_component, kind) do
    case view_or_component.__live__() do
      %{kind: ^kind} = config ->
        config

      %{kind: other} ->
        raise "expected #{inspect(view_or_component)} to be a #{kind}, but it is a #{other}"
    end
  end

  defp call_mount_and_handle_params!(socket, view, session, params, uri) do
    mount_params = if socket.router, do: params, else: :not_mounted_at_router

    socket
    |> Utils.maybe_call_live_view_mount!(view, mount_params, session)
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
    cond do
      mount_redir ->
        {:noreply, socket}

      not exports_handle_params?(view) ->
        {:noreply, socket}

      is_nil(socket.router) ->
        # Let the callback fail for the usual reasons
        Utils.live_link_info!(socket, view, uri)

      true ->
        Utils.call_handle_params!(socket, view, params, uri)
    end
  end

  defp exports_handle_params?(view), do: function_exported?(view, :handle_params, 3)

  defp sign_root_session(%Socket{id: id, endpoint: endpoint}, router, view, session) do
    # IMPORTANT: If you change the third argument, @token_vsn has to be bumped.
    sign_token(endpoint, %{
      id: id,
      view: view,
      root_view: view,
      router: router,
      parent_pid: nil,
      root_pid: nil,
      session: session
    })
  end

  defp sign_nested_session(%Socket{} = parent, %Socket{} = child, view, session) do
    # IMPORTANT: If you change the third argument, @token_vsn has to be bumped.
    sign_token(parent.endpoint, %{
      id: child.id,
      view: view,
      root_view: parent.root_view,
      router: parent.router,
      parent_pid: self(),
      root_pid: parent.root_pid,
      session: session
    })
  end

  # THe static token is computed only on disconnected render and it keeps
  # the information that is only available during disconnected renders,
  # such as assign_new.
  defp sign_static_token(%Socket{id: id, endpoint: endpoint} = socket) do
    # IMPORTANT: If you change the third argument, @token_vsn has to be bumped.
    sign_token(endpoint, %{
      id: id,
      flash: socket.assigns.flash,
      assign_new: assign_new_keys(socket)
    })
  end

  defp sign_token(endpoint, data) do
    Phoenix.Token.sign(endpoint, Utils.salt!(endpoint), {@token_vsn, data})
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

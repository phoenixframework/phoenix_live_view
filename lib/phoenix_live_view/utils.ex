defmodule Phoenix.LiveView.Utils do
  # Shared helpers used mostly by Channel and Diff,
  # but also Static, and LiveViewTest.
  @moduledoc false

  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  # All available mount options
  @mount_opts [:temporary_assigns, :layout]

  @max_flash_age :timer.seconds(60)

  @doc """
  Assigns a value if it changed change.
  """
  def assign(%Socket{} = socket, key, value) do
    case socket do
      %{assigns: %{^key => ^value}} -> socket
      %{} -> force_assign(socket, key, value)
    end
  end

  @doc """
  Forces an assign.
  """
  def force_assign(%Socket{assigns: assigns, changed: changed} = socket, key, val) do
    new_changed = Map.put(changed, key, true)
    new_assigns = Map.put(assigns, key, val)
    %{socket | assigns: new_assigns, changed: new_changed}
  end

  @doc """
  Clears the changes from the socket assigns.
  """
  def clear_changed(%Socket{private: private, assigns: assigns} = socket) do
    temporary = Map.get(private, :temporary_assigns, %{})
    %Socket{socket | changed: %{}, assigns: Map.merge(assigns, temporary)}
  end

  @doc """
  Checks if the socket changed.
  """
  def changed?(%Socket{changed: changed}), do: changed != %{}

  def changed?(%Socket{changed: %{} = changed}, assign), do: Map.has_key?(changed, assign)
  def changed?(%Socket{}, _), do: false

  @doc """
  Configures the socket for use.
  """
  def configure_socket(%{id: nil, assigns: assigns, view: view} = socket, private, action, flash) do
    %{
      socket
      | id: random_id(),
        private: private,
        assigns: configure_assigns(assigns, view, action, flash)
    }
  end

  def configure_socket(%{assigns: assigns, view: view} = socket, private, action, flash) do
    %{socket | private: private, assigns: configure_assigns(assigns, view, action, flash)}
  end

  defp configure_assigns(assigns, view, action, flash) do
    Map.merge(assigns, %{live_module: view, live_action: action, flash: flash})
  end

  @doc """
  Returns a random ID with valid DOM tokens
  """
  def random_id do
    "phx-"
    |> Kernel.<>(random_encoded_bytes())
    |> String.replace(["/", "+"], "-")
  end

  @doc """
  Prunes any data no longer needed after mount.
  """
  def post_mount_prune(%Socket{} = socket) do
    socket
    |> clear_changed()
    |> drop_private([:connect_params, :assign_new])
  end

  @doc """
  Renders the view with socket into a rendered struct.
  """
  def to_rendered(socket, view) do
    inner_content =
      render_assigns(socket)
      |> view.render()
      |> check_rendered!(view)

    case layout(socket, view) do
      {layout_mod, layout_template} ->
        socket = assign(socket, :inner_content, inner_content)

        layout_template
        |> layout_mod.render(render_assigns(socket))
        |> check_rendered!(layout_mod)

      false ->
        inner_content
    end
  end

  defp check_rendered!(%Rendered{} = rendered, _view), do: rendered

  defp check_rendered!(other, view) do
    raise RuntimeError, """
    expected #{inspect(view)} to return a %Phoenix.LiveView.Rendered{} struct

    Ensure your render function uses ~L, or your eex template uses the .leex extension.

    Got:

        #{inspect(other)}

    """
  end

  @doc """
  Returns the socket's flash messages.
  """
  def get_flash(%Socket{assigns: assigns}), do: assigns.flash
  def get_flash(%{} = flash, key), do: flash[key]

  @doc """
  Puts a new flash with the socket's flash messages.
  """
  def replace_flash(%Socket{} = socket, %{} = new_flash) do
    assign(socket, :flash, new_flash)
  end

  @doc """
  Clears the flash.
  """
  def clear_flash(%Socket{} = socket), do: assign(socket, :flash, %{})

  @doc """
  Clears the key from the flash.
  """
  def clear_flash(%Socket{} = socket, key) do
    key = flash_key(key)
    new_flash = Map.delete(socket.assigns.flash, key)
    assign(socket, :flash, new_flash)
  end

  @doc """
  Puts a flash message in the socket.
  """
  def put_flash(%Socket{assigns: assigns} = socket, kind, msg) do
    kind = flash_key(kind)
    new_flash = Map.put(assigns.flash, kind, msg)
    assign(socket, :flash, new_flash)
  end

  defp flash_key(binary) when is_binary(binary), do: binary
  defp flash_key(atom) when is_atom(atom), do: Atom.to_string(atom)

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
  def live_link_info!(nil, view, _uri) do
    raise ArgumentError,
          "cannot invoke handle_params/3 on #{inspect(view)} " <>
            "because it is not mounted nor accessed through the router live/3 macro"
  end

  def live_link_info!(router, view, uri) do
    %URI{host: host, path: path, query: query} = parsed_uri = URI.parse(uri)
    query_params = if query, do: Plug.Conn.Query.decode(query), else: %{}

    case Phoenix.Router.route_info(router, "GET", URI.decode(path || ""), host) do
      %{plug: Phoenix.LiveView.Plug, phoenix_live_view: {^view, action}, path_params: path_params} ->
        {:internal, Map.merge(query_params, path_params), action, parsed_uri}

      %{} ->
        :external

      :error ->
        raise ArgumentError,
              "cannot invoke handle_params nor live_redirect/live_link to #{inspect(uri)} " <>
                "because it isn't defined in #{inspect(router)}"
    end
  end

  @doc """
  Raises error message for bad live patch on mount.
  """
  def raise_bad_mount_and_live_patch!() do
    raise RuntimeError, """
    attempted to live patch while mounting.

    a LiveView cannot be mounted while issuing a live patch to the client. \
    Use push_redirect/2 or redirect/2 instead if you wish to mount and redirect.
    """
  end

  @doc """
  Calls the optional `mount/N` callback, otherwise returns the socket as is.
  """
  def maybe_call_mount!(socket, view, args) do
    arity = length(args)

    if function_exported?(view, :mount, arity) do
      case apply(view, :mount, args) do
        {:ok, %Socket{} = socket, opts} when is_list(opts) ->
          validate_mount_redirect!(socket.redirected)
          Enum.reduce(opts, socket, fn {key, val}, acc -> mount_opt(acc, key, val, arity) end)

        {:ok, %Socket{} = socket} ->
          validate_mount_redirect!(socket.redirected)
          socket

        other ->
          raise ArgumentError, """
          invalid result returned from #{inspect(view)}.mount/#{length(args)}.

          Expected {:ok, socket} | {:ok, socket, opts}, got: #{inspect(other)}
          """
      end
    else
      socket
    end
  end

  defp validate_mount_redirect!({:live, {_, _}, _}), do: raise_bad_mount_and_live_patch!()
  defp validate_mount_redirect!(_), do: :ok

  @doc """
  Calls the optional `update/2` callback, otherwise update the socket directly.
  """
  def maybe_call_update!(socket, component, assigns) do
    if function_exported?(component, :update, 2) do
      socket =
        case component.update(assigns, socket) do
          {:ok, %Socket{} = socket} ->
            socket

          other ->
            raise ArgumentError, """
            invalid result returned from #{inspect(component)}.update/2.

            Expected {:ok, socket}, got: #{inspect(other)}
            """
        end

      if socket.redirected do
        raise "cannot redirect socket on update/2"
      end

      socket
    else
      Enum.reduce(assigns, socket, fn {k, v}, acc -> assign(acc, k, v) end)
    end
  end

  @doc """
  Signs the socket's flash into a token if it has been set.
  """
  def sign_flash(endpoint_mod, %{} = flash) do
    Phoenix.Token.sign(endpoint_mod, flash_salt(endpoint_mod), flash)
  end

  @doc """
  Verifies the socket's flash token.
  """
  def verify_flash(endpoint_mod, flash_token) do
    salt = flash_salt(endpoint_mod)

    case Phoenix.Token.verify(endpoint_mod, salt, flash_token, max_age: @max_flash_age) do
      {:ok, flash} -> flash
      {:error, _reason} -> %{}
    end
  end

  defp random_encoded_bytes do
    binary = <<
      System.system_time(:nanosecond)::64,
      :erlang.phash2({node(), self()})::16,
      :erlang.unique_integer()::16
    >>

    Base.url_encode64(binary)
  end

  defp mount_opt(%Socket{} = socket, key, val, _arity) when key in @mount_opts do
    do_mount_opt(socket, key, val)
  end

  defp mount_opt(%Socket{view: view}, key, val, arity) do
    raise ArgumentError, """
    invalid option returned from #{inspect(view)}.mount/#{arity}.

    Expected keys to be one of #{inspect(@mount_opts)}
    got: #{inspect(key)}: #{inspect(val)}
    """
  end

  defp do_mount_opt(socket, :layout, {mod, template}) when is_atom(mod) and is_binary(template) do
    %Socket{socket | private: Map.put(socket.private, :phoenix_live_layout, {mod, template})}
  end

  defp do_mount_opt(socket, :layout, false) do
    %Socket{socket | private: Map.put(socket.private, :phoenix_live_layout, false)}
  end

  defp do_mount_opt(_socket, :layout, bad_layout) do
    raise ArgumentError,
          "the :layout mount option expects a tuple of the form {MyLayoutView, \"my_template.html\"}, " <>
            "got: #{inspect(bad_layout)}"
  end

  defp do_mount_opt(socket, :temporary_assigns, temp_assigns) do
    unless Keyword.keyword?(temp_assigns) do
      raise "the :temporary_assigns mount option must be keyword list"
    end

    temp_assigns = Map.new(temp_assigns)

    %Socket{
      socket
      | assigns: Map.merge(temp_assigns, socket.assigns),
        private: Map.put(socket.private, :temporary_assigns, temp_assigns)
    }
  end

  defp drop_private(%Socket{private: private} = socket, keys) do
    %Socket{socket | private: Map.drop(private, keys)}
  end

  defp render_assigns(socket) do
    Map.put(socket.assigns, :socket, %Socket{socket | assigns: %Socket.AssignsNotInSocket{}})
  end

  defp layout(socket, view) do
    case socket.private do
      %{phoenix_live_layout: layout} -> layout
      %{} -> view.__live__()[:layout] || false
    end
  end

  defp flash_salt(endpoint_mod) when is_atom(endpoint_mod) do
    "flash:" <> salt!(endpoint_mod)
  end
end

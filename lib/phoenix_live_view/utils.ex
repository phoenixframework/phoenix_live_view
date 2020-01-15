defmodule Phoenix.LiveView.Utils do
  # Shared helpers used mostly by Channel and Diff,
  # but also Static, Flash, and LiveViewTest.
  @moduledoc false

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  # All available mount options
  @mount_opts [:temporary_assigns, :layout]

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
  Returns the socket's flash messages.
  """
  def get_flash(%Socket{private: private}) do
    private[:flash]
  end

  @doc """
  Configures the socket for use.
  """
  def configure_socket(%{id: nil} = socket, private) do
    %{socket | id: random_id(), private: private}
  end

  def configure_socket(socket, private) do
    %{socket | private: private}
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
    |> drop_private([:connect_params, :assigned_new])
  end

  @doc """
  Renders the view with socket into a rendered struct.
  """
  def to_rendered(socket, view) do
    assigns = Map.merge(socket.assigns, %{socket: socket, live_view_module: view})

    case render_view(socket, view, assigns) do
      %LiveView.Rendered{} = rendered ->
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
  def live_link_info!(nil, view, _uri) do
    raise ArgumentError,
          "cannot invoke handle_params/3 on #{inspect(view)} " <>
            "because it is not mounted nor accessed through the router live/3 macro"
  end

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
  Raises error message for bad stop with no redirect.
  """
  def raise_bad_stop_and_no_redirect!() do
    raise RuntimeError, """
    attempted to stop socket without redirecting.

    you must always redirect when stopping a socket, see redirect/2.
    """
  end

  @doc """
  Calls the optional `mount/N` callback, otherwise returns the socket as is.
  """
  def maybe_call_mount!(socket, view, args) do
    if function_exported?(view, :mount, length(args)) do
      socket =
        case apply(view, :mount, args) do
          {:ok, %Socket{} = socket, opts} when is_list(opts) ->
            Enum.reduce(opts, socket, fn {key, val}, acc -> mount_opt(acc, key, val) end)

          {:ok, %Socket{} = socket} ->
            socket

          other ->
            raise ArgumentError, """
            invalid result returned from #{inspect(view)}.mount/#{length(args)}.

            Expected {:ok, socket} | {:ok, socket, opts}, got: #{inspect(other)}
            """
        end

      if socket.redirected do
        raise "cannot redirect socket on mount/#{length(args)}"
      end

      socket
    else
      socket
    end
  end

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
      LiveView.assign(socket, assigns)
    end
  end

  defp random_encoded_bytes do
    binary = <<
      System.system_time(:nanosecond)::32,
      :erlang.phash2({node(), self()}, 16_777_216)::16,
      :erlang.unique_integer()::16
    >>

    Base.encode64(binary, padding: false)
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

  defp do_mount_opt(socket, :layout, {mod, template}) when is_atom(mod) and is_binary(template) do
    %Socket{socket | private: Map.put(socket.private, :layout, {mod, template})}
  end

  defp do_mount_opt(_socket, :layout, bad_layout) do
    raise ArgumentError,
          ":layout expects a tuple of the form {MyLayoutView, \"my_template.html\"}, " <>
            "got: #{inspect(bad_layout)}"
  end

  defp do_mount_opt(socket, :temporary_assigns, temp_assigns) do
    unless Keyword.keyword?(temp_assigns) do
      raise ":temporary_assigns must be keyword list"
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

  defp render_view(socket, view, assigns) do
    case layout(socket) do
      {layout_mod, layout_template} -> layout_mod.render(layout_template, assigns)
      nil -> view.render(assigns)
    end
  end

  defp layout(socket), do: socket.private[:layout]
end

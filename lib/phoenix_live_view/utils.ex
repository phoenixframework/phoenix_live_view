defmodule Phoenix.LiveView.Utils do
  # Shared helpers used mostly by Channel and Diff,
  # but also Static, and LiveViewTest.
  @moduledoc false

  alias Phoenix.LiveView.{Rendered, Socket, Lifecycle}

  # All available mount options
  @mount_opts [:temporary_assigns, :layout]

  @max_flash_age :timer.seconds(60)

  @valid_uri_schemes [
    "http:",
    "https:",
    "ftp:",
    "ftps:",
    "mailto:",
    "news:",
    "irc:",
    "gopher:",
    "nntp:",
    "feed:",
    "telnet:",
    "mms:",
    "rtsp:",
    "svn:",
    "tel:",
    "fax:",
    "xmpp:"
  ]

  @doc """
  Assigns a value if it changed.
  """
  def assign(%Socket{} = socket, key, value) do
    case socket do
      %{assigns: %{^key => ^value}} -> socket
      %{} -> force_assign(socket, key, value)
    end
  end

  @doc """
  Assigns the given `key` with value from `fun` into `socket_or_assigns` if one does not yet exist.
  """
  def assign_new(%Socket{} = socket, key, fun) when is_function(fun, 1) do
    case socket do
      %{assigns: %{^key => _}} ->
        socket

      %{private: %{assign_new: {assigns, keys}}} ->
        # It is important to store the keys even if they are not in assigns
        # because maybe the controller doesn't have it but the view does.
        socket = put_in(socket.private.assign_new, {assigns, [key | keys]})

        Phoenix.LiveView.Utils.force_assign(
          socket,
          key,
          case assigns do
            %{^key => value} -> value
            %{} -> fun.(socket.assigns)
          end
        )

      %{assigns: assigns} ->
        Phoenix.LiveView.Utils.force_assign(socket, key, fun.(assigns))
    end
  end

  def assign_new(%Socket{} = socket, key, fun) when is_function(fun, 0) do
    case socket do
      %{assigns: %{^key => _}} ->
        socket

      %{private: %{assign_new: {assigns, keys}}} ->
        # It is important to store the keys even if they are not in assigns
        # because maybe the controller doesn't have it but the view does.
        socket = put_in(socket.private.assign_new, {assigns, [key | keys]})
        Phoenix.LiveView.Utils.force_assign(socket, key, Map.get_lazy(assigns, key, fun))

      %{} ->
        Phoenix.LiveView.Utils.force_assign(socket, key, fun.())
    end
  end

  @doc """
  Forces an assign on a socket.
  """
  def force_assign(%Socket{assigns: assigns} = socket, key, val) do
    %{socket | assigns: force_assign(assigns, assigns.__changed__, key, val)}
  end

  @doc """
  Forces an assign with the given changed map.
  """
  def force_assign(assigns, nil, key, val), do: Map.put(assigns, key, val)

  def force_assign(assigns, changed, key, val) do
    # If the current value is a map, we store it in changed so
    # we can perform nested change tracking. Also note the use
    # of put_new is important. We want to keep the original value
    # from assigns and not any intermediate ones that may appear.
    current_val = Map.get(assigns, key)
    changed_val = if is_map(current_val), do: current_val, else: true
    changed = Map.put_new(changed, key, changed_val)
    Map.put(%{assigns | __changed__: changed}, key, val)
  end

  @doc """
  Clears the changes from the socket assigns.
  """
  def clear_changed(%Socket{private: private, assigns: assigns} = socket) do
    temporary = Map.get(private, :temporary_assigns, %{})

    %Socket{
      socket
      | assigns: assigns |> Map.merge(temporary) |> Map.put(:__changed__, %{}),
        private: Map.put(private, :__changed__, %{})
    }
  end

  @doc """
  Checks if the socket changed.
  """
  def changed?(%Socket{assigns: %{__changed__: changed}}), do: changed != %{}

  @doc """
  Checks if the given assign changed.
  """
  def changed?(%Socket{} = socket, assign), do: changed?(socket.assigns, assign)
  def changed?(%{__changed__: nil}, _assign), do: true
  def changed?(%{__changed__: changed}, assign), do: Map.has_key?(changed, assign)

  @doc """
  Returns the CID of the given socket.
  """
  def cid(%Socket{assigns: %{myself: %Phoenix.LiveComponent.CID{} = cid}}), do: cid
  def cid(%Socket{}), do: nil

  @doc """
  Configures the socket for use.
  """
  def configure_socket(%Socket{id: nil} = socket, private, action, flash, host_uri) do
    %{
      socket
      | id: random_id(),
        private: private,
        assigns: configure_assigns(socket.assigns, action, flash),
        host_uri: prune_uri(host_uri)
    }
  end

  def configure_socket(%Socket{} = socket, private, action, flash, host_uri) do
    assigns = configure_assigns(socket.assigns, action, flash)
    %{socket | host_uri: prune_uri(host_uri), private: private, assigns: assigns}
  end

  defp configure_assigns(assigns, action, flash) do
    Map.merge(assigns, %{live_action: action, flash: flash})
  end

  defp prune_uri(:not_mounted_at_router), do: :not_mounted_at_router

  defp prune_uri(url) do
    %URI{host: host, port: port, scheme: scheme} = url

    if host == nil do
      raise "client did not send full URL, missing host in #{url}"
    end

    %URI{host: host, port: port, scheme: scheme}
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
    |> drop_private([:connect_info, :connect_params, :assign_new])
  end

  @doc """
  Validate and normalizes the layout.
  """
  def normalize_layout(false, _warn_ctx), do: false

  def normalize_layout({mod, layout}, _warn_ctx) when is_atom(mod) and is_atom(layout) do
    {mod, Atom.to_string(layout)}
  end

  def normalize_layout({mod, layout}, warn_ctx) when is_atom(mod) and is_binary(layout) do
    root_template = Path.rootname(layout)

    IO.warn(
      "passing a string as a layout template in #{warn_ctx} is deprecated, please pass " <>
        "{#{inspect(mod)}, :#{root_template}} instead of {#{inspect(mod)}, \"#{root_template}.html\"}"
    )

    {mod, root_template}
  end

  def normalize_layout(other, _warn_ctx) do
    raise ArgumentError,
          ":layout expects a tuple of the form {MyLayoutView, :my_template} or false, " <>
            "got: #{inspect(other)}"
  end

  @doc """
  Renders the view with socket into a rendered struct.
  """
  def to_rendered(socket, view) do
    assigns = render_assigns(socket)

    inner_content =
      assigns
      |> view.render()
      |> check_rendered!(view)

    case layout(socket, view) do
      {layout_mod, layout_template} ->
        assigns = put_in(assigns[:inner_content], inner_content)
        assigns = put_in(assigns.__changed__[:inner_content], true)

        layout_mod
        |> Phoenix.Template.render(to_string(layout_template), "html", assigns)
        |> check_rendered!(layout_mod)

      false ->
        inner_content
    end
  end

  defp check_rendered!(%Rendered{} = rendered, _view), do: rendered

  defp check_rendered!(other, view) do
    raise RuntimeError, """
    expected #{inspect(view)} to return a %Phoenix.LiveView.Rendered{} struct

    Ensure your render function uses ~H, or your template uses the .heex extension.

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
  def clear_flash(%Socket{} = socket) do
    assign(socket, :flash, %{})
  end

  @doc """
  Clears the key from the flash.
  """
  def clear_flash(%Socket{} = socket, key) do
    key = flash_key(key)
    new_flash = Map.delete(socket.assigns.flash, key)

    socket = assign(socket, :flash, new_flash)
    update_in(socket.private.__changed__[:flash], &Map.delete(&1 || %{}, key))
  end

  @doc """
  Puts a flash message in the socket.
  """
  def put_flash(%Socket{assigns: assigns} = socket, key, msg) do
    key = flash_key(key)
    new_flash = Map.put(assigns.flash, key, msg)

    socket = assign(socket, :flash, new_flash)
    update_in(socket.private.__changed__[:flash], &Map.put(&1 || %{}, key, msg))
  end

  @doc """
  Returns a map of the flash messages which have changed.
  """
  def changed_flash(%Socket{} = socket) do
    socket.private.__changed__[:flash] || %{}
  end

  defp flash_key(binary) when is_binary(binary), do: binary
  defp flash_key(atom) when is_atom(atom), do: Atom.to_string(atom)

  @doc """
  Annotates the changes with the event to be pushed.

  Events are dispatched on the JavaScript side only after
  the current patch is invoked. Therefore, if the LiveView
  redirects, the events won't be invoked.
  """
  def push_event(%Socket{} = socket, event, %{} = payload) do
    update_in(socket.private.__changed__[:push_events], &[[event, payload] | &1 || []])
  end

  @doc """
  Annotates the reply in the socket changes.
  """
  def put_reply(%Socket{} = socket, %{} = payload) do
    put_in(socket.private.__changed__[:push_reply], payload)
  end

  @doc """
  Returns the push events in the socket.
  """
  def get_push_events(%Socket{} = socket) do
    Enum.reverse(socket.private.__changed__[:push_events] || [])
  end

  @doc """
  Returns the reply in the socket.
  """
  def get_reply(%Socket{} = socket) do
    socket.private.__changed__[:push_reply]
  end

  @doc """
  Returns the configured signing salt for the endpoint.
  """
  def salt!(endpoint) when is_atom(endpoint) do
    salt = endpoint.config(:live_view)[:signing_salt]

    if is_binary(salt) and byte_size(salt) >= 8 do
      salt
    else
      raise ArgumentError, """
      the signing salt for #{inspect(endpoint)} is missing or too short.

      Add the following LiveView configuration to your config/runtime.exs
      or config/config.exs:

          config :my_app, MyAppWeb.Endpoint,
              ...,
              live_view: [signing_salt: "#{random_encoded_bytes()}"]

      """
    end
  end

  @doc """
  Raises error message for bad live patch on mount.
  """
  def raise_bad_mount_and_live_patch!() do
    raise RuntimeError, """
    attempted to live patch while mounting.

    a LiveView cannot be mounted while issuing a live patch to the client. \
    Use push_navigate/2 or redirect/2 instead if you wish to mount and redirect.
    """
  end

  @doc """
  Calls the `c:Phoenix.LiveView.mount/3` callback, otherwise returns the socket as is.
  """
  def maybe_call_live_view_mount!(%Socket{} = socket, view, params, session, uri \\ nil) do
    %{any?: any?, exported?: exported?} = Lifecycle.stage_info(socket, view, :mount, 3)

    if any? do
      :telemetry.span(
        [:phoenix, :live_view, :mount],
        %{socket: socket, params: params, session: session, uri: uri},
        fn ->
          socket =
            case Lifecycle.mount(params, session, socket) do
              {:cont, %Socket{} = socket} when exported? ->
                view.mount(params, session, socket)

              {_, %Socket{} = socket} ->
                {:ok, socket}
            end
            |> handle_mount_result!({:mount, 3, view})

          {socket, %{socket: socket, params: params, session: session, uri: uri}}
        end
      )
    else
      socket
    end
  end

  @doc """
  Calls the `c:Phoenix.LiveComponent.mount/1` callback, otherwise returns the socket as is.
  """
  def maybe_call_live_component_mount!(%Socket{} = socket, component) do
    if Code.ensure_loaded?(component) and function_exported?(component, :mount, 1) do
      socket
      |> component.mount()
      |> handle_mount_result!({:mount, 1, component})
    else
      socket
    end
  end

  defp handle_mount_result!({:ok, %Socket{} = socket, opts}, {:mount, arity, _view})
       when is_list(opts) do
    validate_mount_redirect!(socket.redirected)

    Enum.reduce(opts, socket, fn {key, val}, acc -> mount_opt(acc, key, val, arity) end)
  end

  defp handle_mount_result!({:ok, %Socket{} = socket}, {:mount, _arity, _view}) do
    validate_mount_redirect!(socket.redirected)

    socket
  end

  defp handle_mount_result!(response, {:mount, arity, view}) do
    raise ArgumentError, """
    invalid result returned from #{inspect(view)}.mount/#{arity}.

    Expected {:ok, socket} | {:ok, socket, opts}, got: #{inspect(response)}
    """
  end

  defp validate_mount_redirect!({:live, :patch, _}), do: raise_bad_mount_and_live_patch!()
  defp validate_mount_redirect!(_), do: :ok

  @doc """
  Calls the `handle_params/3` callback, and returns the result.

  This function expects the calling code has checked to see if this function has
  been exported, otherwise it assumes the function has been exported.

  Raises an `ArgumentError` on unexpected return types.
  """
  def call_handle_params!(%Socket{} = socket, view, exported? \\ true, params, uri)
      when is_boolean(exported?) do
    :telemetry.span(
      [:phoenix, :live_view, :handle_params],
      %{socket: socket, params: params, uri: uri},
      fn ->
        case Lifecycle.handle_params(params, uri, socket) do
          {:cont, %Socket{} = socket} when exported? ->
            case view.handle_params(params, uri, socket) do
              {:noreply, %Socket{} = socket} ->
                {{:noreply, socket}, %{socket: socket, params: params, uri: uri}}

              other ->
                raise ArgumentError, """
                invalid result returned from #{inspect(view)}.handle_params/3.

                Expected {:noreply, socket}, got: #{inspect(other)}
                """
            end

          {_, %Socket{} = socket} ->
            {{:noreply, socket}, %{socket: socket, params: params, uri: uri}}
        end
      end
    )
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
        raise "cannot redirect socket on update. Redirect before `update/2` is called" <>
                " or use `send/2` and redirect in the `handle_info/2` response"
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

  defp do_mount_opt(socket, :layout, layout) do
    put_in(socket.private[:live_layout], normalize_layout(layout, "mount options"))
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

  defp render_assigns(%{assigns: assigns} = socket) do
    socket = %Socket{socket | assigns: %Socket.AssignsNotInSocket{__assigns__: assigns}}
    Map.put(assigns, :socket, socket)
  end

  defp layout(socket, view) do
    case socket.private do
      %{live_layout: layout} -> layout
      %{} -> view.__live__()[:layout]
    end
  end

  defp flash_salt(endpoint_mod) when is_atom(endpoint_mod) do
    "flash:" <> salt!(endpoint_mod)
  end

  def valid_destination!(%URI{} = uri, context) do
    valid_destination!(URI.to_string(uri), context)
  end

  def valid_destination!({:safe, to}, context) do
    {:safe, valid_string_destination!(IO.iodata_to_binary(to), context)}
  end

  def valid_destination!({other, to}, _context) when is_atom(other) do
    [Atom.to_string(other), ?:, to]
  end

  def valid_destination!(to, context) do
    valid_string_destination!(IO.iodata_to_binary(to), context)
  end

  for scheme <- @valid_uri_schemes do
    def valid_string_destination!(unquote(scheme) <> _ = string, _context), do: string
  end

  def valid_string_destination!(to, context) do
    if not match?("/" <> _, to) and String.contains?(to, ":") do
      raise ArgumentError, """
      unsupported scheme given to #{context}. In case you want to link to an
      unknown or unsafe scheme, such as javascript, use a tuple: {:javascript, rest}
      """
    else
      to
    end
  end
end

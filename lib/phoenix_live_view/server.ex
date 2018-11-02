defmodule Phoenix.LiveView.Server do
  @moduledoc false
  use GenServer

  alias Phoenix.Socket
  alias Phoenix.LiveView

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def sign_token(endpoint_mod, salt, data) do
    encoded_data = data |> :erlang.term_to_binary() |> Base.encode64()
    Phoenix.Token.sign(endpoint_mod, salt, encoded_data)
  end

  def verify_token(endpoint_mod, salt, encoded_pid, opts) do
    case Phoenix.Token.verify(endpoint_mod, salt, encoded_pid, opts) do
      {:ok, encoded_pid} ->
        pid = encoded_pid |> Base.decode64!() |> :erlang.binary_to_term()
        {:ok, pid}

      {:error, _} = error -> error
    end
  end

  def static_render(endpoint, view, assigns) do
    import Phoenix.HTML, only: [sigil_E: 2]

    {:ok, id, new_assigns, signed_params, signed_session} = encode_static_render(endpoint, view, assigns)
    ~E"""
      <div id="<%= id %>" data-phx-view="<%= inspect(view) %>" data-session="<%= signed_session %>" data-params="<%= signed_params %>">
        <%= view.render(new_assigns) %>
      </div>
      <div class="phx-loader"></div>
    """
  end

  defp encode_static_render(endpoint, view, assigns) do
    # TODO handle non ok upgrade
    id = random_id()
    {:ok, trusted_params, session} = upgrade(view, assigns)

    socket =
      LiveView.Socket.build_socket(endpoint, %{
        state: :disconnected,
        id: id,
        view: view,
        signed_params: trusted_params,
      })

    trusted_params
    |> view.authorize(session, socket)
    |> authorize_ok(view)
    |> case do
      {:ok, %Socket{} = new_socket} ->
        signed_params = sign_params(socket)
        signed_session = sign_session(socket, session)
        {:ok, id, new_socket.assigns, signed_params, signed_session}
    end
  end

  defp upgrade(view, %{conn: conn} = _assigns) do
    # todo handle non-ok
    conn
    |> view.upgrade(conn.params)
    |> case do
      {:ok, trusted_params, session} -> {:ok, trusted_params, session}
    end
  end

  @doc """
  TODO
  """
  def spawn_render(socket, params, session) do
    {:ok, pid, ref} = start_view(self(), socket, params, session)

    receive do
      {^ref, rendered_view} -> {:ok, pid, rendered_view}
    end
  end
  defp start_view(channel_pid, socket, params, session) do
    ref = make_ref()

    case start_dynamic_child(ref, channel_pid, socket, params, session) do
      {:ok, pid} -> {:ok, pid, ref}
      {:error, {%_{} = exception, [_|_] = stack}} -> reraise(exception, stack)
    end
  end
  defp start_dynamic_child(ref, channel_pid, socket, params, session) do
    args = {{ref, self()}, channel_pid, socket, params, session}
    DynamicSupervisor.start_child(
      DemoWeb.DynamicSupervisor,
      Supervisor.child_spec({Phoenix.LiveView.Server, args}, restart: :temporary)
    )
  end

  def init({{ref, client_pid}, channel_pid, socket, params, session}) do
    %{id: id, view: view, params: signed_params} = params
    %{id: ^id, view: ^view, session: signed_session} = session

    socket =
      LiveView.Socket.build_socket(socket, %{
        state: :connected,
        id: id,
        view: view,
        signed_params: signed_params,
      })


    with {:ok, %Socket{} = socket} <- view.authorize(signed_params, signed_session, socket),
         {:ok, %Socket{} = socket, opts} <- wrap_init(view.init(socket)) do

      configure_init(socket, channel_pid, view, opts, {ref, client_pid})
    else
      {:error, reason} -> {:error, reason}
      other -> init_ok(other, view)
    end
  end
  defp wrap_init({:ok, %Socket{} = socket}), do: {:ok, socket, []}
  defp wrap_init({:ok, %Socket{} = socket, opts}), do: {:ok, socket, opts}
  defp wrap_init(other), do: other

  defp configure_init(%Socket{} = socket, channel_pid, view, opts, {ref, client_pid}) do
    _ref = Process.monitor(channel_pid)
    state = %{
      view_module: view,
      socket: socket,
      channel_pid: channel_pid,
      sync_assigns: opts[:sync_assigns] || []
    }
    send(client_pid, {ref, rerender(state)})

    {:ok, state}
  end

  defp authorize_ok({:ok, %Socket{} = socket}, _view), do: {:ok, socket}
  defp authorize_ok(other, view) do
    raise ArgumentError, """
    invalid result returned from #{inspect(view)}.authorize.

    Expected {:ok, socket}, got: #{inspect(other)}
    """
  end

  defp init_ok({:ok, %Socket{} = socket}, _view), do: {:ok, socket}
  defp init_ok(other, view) do
    raise ArgumentError, """
    invalid result returned from #{inspect(view)}.init.

    Expected {:ok, socket}, got: #{inspect(other)}
    """
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{channel_pid: pid} = state) do
    {:stop, :normal, state}
  end

  def handle_info(msg, %{socket: socket} = state) do
    noreply(state, :handle_info, socket, state.view_module.handle_info(msg, socket))
  end

  def handle_call({:channel_event, event, dom_id, value}, _, %{socket: socket} = state) do
    event
    |> state.view_module.handle_event(dom_id, value, socket)
    |> handle_event_result(socket, state)
  end
  defp handle_event_result({:noreply, %Socket{} = unchanged_socket}, %Socket{} = unchanged_socket, state) do
    {:reply, :noop, state}
  end
  defp handle_event_result({:noreply, %Socket{} = new_socket}, %Socket{} = socket_before, state) do
    new_state = sync_assigns(state, new_socket)
    push_params(new_state, socket_before, new_state.socket)
    {:reply, {:render, rerender(new_state)}, new_state}
  end
  defp handle_event_result({:stop, {:redirect, opts}, %Socket{} = socket}, %Socket{} = _original_socket, state) do
    {:stop, :normal, {:redirect, opts}, %{state | socket: socket}}
  end

  def terminate(reason, %{socket: socket} = state) do
    {:ok, %Socket{} = new_socket} = state.view_module.terminate(reason, socket)
    {:ok, %{state | socket: new_socket}}
  end

  defp noreply(state, _kind, %Socket{} = socket, {:noreply, %Socket{} = socket}) do
    {:noreply, state}
  end
  defp noreply(state, _kind, socket_before, {:noreply, %Socket{} = new_socket}) do
    new_state = sync_assigns(state, new_socket)
    push_params(new_state, socket_before, new_state.socket)
    send_channel(state, {:render, rerender(new_state)})

    {:noreply, new_state}
  end
  defp noreply(state, _kind, _socket, {:stop, {:redirect, opts}, %Socket{} = new_socket}) do
    send_channel(state, {:redirect, opts})
    {:stop, :normal, %{state | socket: new_socket}}
  end
  defp noreply(_state, kind, _original_socket, result) do
    raise ArgumentError, """
    invalid noreply from #{kind} callback.

    Excepted {:noreply, %Socket{}} | {:stop, reason, %Socket{}}. got: #{inspect(result)}
    """
  end

  defp sync_assigns(state, %Socket{} = socket) do
    new_params = for key <- state.sync_assigns, into: LiveView.Socket.signed_params(socket),
      do: {to_string(key), socket.assigns[key]}

    new_socket = LiveView.Socket.update_private(socket, :signed_params, fn _ -> new_params end)
    %{state | socket: new_socket}
  end

  defp push_params(state, %Socket{} = socket_before, %Socket{} = new_socket) do
    case {LiveView.Socket.signed_params(socket_before), LiveView.Socket.signed_params(new_socket)} do
      {unchanged, unchanged} -> :noop
      {_old, _new} -> send_channel(state, {:push_params, sign_params(new_socket)})
    end
  end

  defp rerender(%{view_module: view, socket: socket}) do
    rerender(view, socket)
  end
  defp rerender(view, %Socket{} = socket) do
    Phoenix.View.render_to_iodata(__MODULE__, "template.html", %{assigns: socket.assigns, view: view})
  end
  def render("template.html", %{assigns: assigns, view: view}) do
    view.render(assigns)
  end

  defp random_id, do: "phx-" <> Base.encode64(:crypto.strong_rand_bytes(8))

  defp send_channel(%{channel_pid: pid}, message) do
    send(pid, message)
  end

  defp sign_session(%Socket{} = socket, session) do
    sign_token(socket.endpoint, salt(socket), %{
      id: LiveView.Socket.dom_id(socket),
      view: LiveView.Socket.view(socket),
      session: session,
    })
  end

  defp sign_params(%Socket{} = socket) do
    trusted_params = LiveView.Socket.signed_params(socket)

    sign_token(socket.endpoint, salt(socket), %{
      id: LiveView.Socket.dom_id(socket),
      view: LiveView.Socket.view(socket),
      params: trusted_params,
    })
  end

  defp salt(socket), do: LiveView.Socket.signing_salt(socket)
end

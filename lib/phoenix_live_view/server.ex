defmodule Phoenix.LiveView.Server do
  @moduledoc false
  use GenServer

  alias Phoenix.LiveView.Socket

  @token_salt "liveview server"

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def sign_token(endpoint_mod, data) do
    encoded_data = data |> :erlang.term_to_binary() |> Base.encode64()
    Phoenix.Token.sign(endpoint_mod, @token_salt, encoded_data)
  end

  def verify_token(endpoint_module, encoded_pid, opts) do
    case Phoenix.Token.verify(endpoint_module, @token_salt, encoded_pid, opts) do
      {:ok, encoded_pid} ->
        pid = encoded_pid |> Base.decode64!() |> :erlang.binary_to_term()
        {:ok, pid}

      {:error, _} = error -> error
    end
  end

  def static_render(view, assigns) do
    import Phoenix.HTML, only: [sigil_E: 2]

    {:ok, id, new_assigns, signed_params} = encode_static_render(view, assigns)
    ~E"""
      <div id="<%= id %>" data-phx-view="<%= inspect(view) %>" data-params="<%= signed_params %>">
        <%= view.render(new_assigns) %>
      </div>
    """
  end

  defp encode_static_render(view, %{conn: conn} = assigns) do
    # TODO handle non ok
    endpoint = Phoenix.Controller.endpoint_module(conn)
    id = random_id()
    {:ok, trusted_params} = before_init(view, assigns)

    socket = %Socket{
      id: id,
      view: view,
      endpoint: endpoint,
      state: :disconnected,
      signed_params: trusted_params
    }

    trusted_params
    |> view.init(socket)
    |> init_ok(view)
    |> case do
      {:ok, %Socket{} = new_socket, _} ->
        signed_params = sign_params(socket)
        {:ok, id, new_socket.assigns, signed_params}
    end
  end

  defp before_init(view, %{conn: conn} = _assigns) do
    # todo handle non-ok
    conn
    |> view.before_init(conn.params)
    |> case do
      {:ok, trusted_params} -> {:ok, trusted_params}
    end
  end

  @doc """
  TODO
  """
  def spawn_render(channel_pid, endpoint, view_data) do
    {:ok, pid, ref} = start_view(channel_pid, endpoint, view_data)

    receive do
      {^ref, rendered_view} -> {:ok, pid, rendered_view}
    end
  end
  defp start_view(channel_pid, endpoint, view_data) do
    # TODO kill csrf
    csrf = Plug.CSRFProtection.get_csrf_token()
    ref = make_ref()

    case start_dynamic_child(ref, channel_pid, endpoint, view_data, csrf) do
      {:ok, pid} -> {:ok, pid, ref}
      {:error, {%_{} = exception, [_|_] = stack}} -> reraise(exception, stack)
    end
  end
  defp start_dynamic_child(ref, channel_pid, endpoint, view_data, csrf) do
    args = {{ref, self()}, channel_pid, endpoint, view_data, csrf}
    DynamicSupervisor.start_child(
      DemoWeb.DynamicSupervisor,
      Supervisor.child_spec({Phoenix.LiveView.Server, args}, restart: :temporary)
    )
  end

  def init({{ref, client_pid}, channel_pid, endpoint, view_data, csrf}) do
    %{id: id, view: view, params: signed_params} = view_data
    Process.put(:plug_masked_csrf_token, csrf)
    socket = %Socket{endpoint: endpoint, id: id, view: view, state: :connected}

    signed_params
    |> view.init(socket)
    |> init_ok(view)
    |> configure_init(channel_pid, view, {ref, client_pid})
  end
  defp configure_init({:ok, %Socket{} = socket, continue}, channel_pid, view, {ref, client_pid}) do
    _ref = Process.monitor(channel_pid)
    state = %{
      view_module: view,
      socket: socket,
      channel_pid: channel_pid,
    }
    send(client_pid, {ref, rerender(state)})

    init_continue(state, continue)
  end
  defp configure_init(other, _channel_pid, view, {_ref, _client_pid}) do
    raise ArgumentError, """
    invalid init returned from #{inspect(view)}.init.

    Expected {:ok, socket} | {:ok, socket, {:continue, continue}}, got: #{inspect(other)}
    """
  end
  defp init_continue(state, nil), do: {:ok, state}
  defp init_continue(state, {:continue, continue}) do
    case handle_continue(continue, state) do
      {:noreply, new_state} -> {:ok, new_state}
      other -> other
    end
  end

  defp init_ok({:ok, %Socket{} = socket, {:continue, _} = continue}, _view), do: {:ok, socket, continue}
  defp init_ok({:ok, %Socket{} = socket}, _view), do: {:ok, socket, nil}
  defp init_ok(other, view) do
    raise ArgumentError, """
    invalid result returned from #{inspect(view)}.init.

    Expected {:ok, socket} | {:ok, socket, {:continue, continue}}, got: #{inspect(other)}
    """
  end

  def handle_continue(continue, %{socket: socket} = state) do
    noreply(state, :continue, socket, state.view_module.handle_continue(continue, socket))
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
    new_state = %{state | socket: new_socket}
    push_params(new_state, socket_before, new_socket)
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
    new_state = %{state | socket: new_socket}
    push_params(new_state, socket_before, new_socket)
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

  defp push_params(_state, %Socket{signed_params: unchanged}, %Socket{signed_params: unchanged}) do
    :noop
  end
  defp push_params(state, %Socket{signed_params: _}, %Socket{signed_params: _new} = socket) do
    send_channel(state, {:push_params, sign_params(socket)})
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

  defp send_channel(%{channel_pid: pid}, message) do
    send(pid, message)
  end

  defp random_id, do: "phx-" <> Base.encode64(:crypto.strong_rand_bytes(8))

  defp sign_params(%Socket{signed_params: trusted_params} = socket) do
    sign_token(socket.endpoint, %{
      id: socket.id,
      view: socket.view,
      params: trusted_params,
    })
  end
end

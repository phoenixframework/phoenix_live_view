defmodule Phoenix.LiveView.Server do
  @moduledoc false
  use GenServer

  alias Phoenix.LiveView.Socket

  @token_salt "liveview server"
  @timeout 10_000

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def attach(pid) do
    try do
      GenServer.call(pid, {:attach, self()})
    catch :exit, reason -> {:error, reason}
    end
  end

  def sign_token(endpoint_mod, server_pid) when is_pid(server_pid) do
    encoded_pid = server_pid |> :erlang.term_to_binary() |> Base.encode64()
    Phoenix.Token.sign(endpoint_mod, @token_salt, encoded_pid)
  end

  def verify_token(endpoint_module, encoded_pid, opts) do
    case Phoenix.Token.verify(endpoint_module, @token_salt, encoded_pid, opts) do
      {:ok, encoded_pid} ->
        pid = encoded_pid |> Base.decode64!() |> :erlang.binary_to_term()
        {:ok, pid}

      {:error, _} = error -> error
    end
  end

  @doc """
  TODO
  """
  def spawn_render(view, %{conn: conn} = assigns) do
    import Phoenix.HTML, only: [sigil_E: 2]

    {:ok, pid, ref} = start_view(view, assigns)

    receive do
      {^ref, rendered_view} ->
        signed_pid = sign_token(Phoenix.Controller.endpoint_module(conn), pid)

        ~E(
          <script>window.viewPid = "<%= signed_pid %>"</script>
          <div id="<%= signed_pid %>">
            <%= {:safe, rendered_view} %>
          </div>
        )
    end
  end
  defp start_view(view, assigns) do
    csrf = Plug.CSRFProtection.get_csrf_token()
    ref = make_ref()

    case start_dynamic_child(ref, view, csrf, assigns) do
      {:ok, pid} -> {:ok, pid, ref}
      {:error, {%_{} = exception, [_|_] = stack}} -> reraise(exception, stack)
    end
  end
  defp start_dynamic_child(ref, view, csrf, assigns) do
    args = {{ref, self()}, view, csrf, assigns}
    DynamicSupervisor.start_child(
      DemoWeb.DynamicSupervisor,
      Supervisor.child_spec({Phoenix.LiveView.Server, args}, restart: :temporary)
    )
  end

  def init({{ref, request_pid}, view, csrf, assigns}) do
    Process.put(:plug_masked_csrf_token, csrf)
    socket = build_socket(assigns)

    assigns.conn.params
    |> view.init(socket)
    |> configure_init(view, {ref, request_pid})
  end
  defp build_socket(%{} = assigns) do
    %Socket{assigns: assigns}
  end
  defp configure_init({:ok, %Socket{} = new_socket}, view, {ref, request_pid}) do
    configure_init({:ok, new_socket, []}, view, {ref, request_pid})
  end
  defp configure_init({:ok, %Socket{} = new_socket, opts}, view, {ref, request_pid}) do
    shutdown_timer = Process.send_after(self(), :attach_timeout, @timeout)
    state = %{
      view_module: view,
      socket: new_socket,
      channel_pid: nil,
      shutdown_timer: shutdown_timer,
      timeout: opts[:timeout] || @timeout,
    }
    send(request_pid, {ref, rerender(state)})

    {:ok, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{channel_pid: pid} = state) do
    {:stop, :normal, state}
  end

  def handle_info(:attach_timeout, state) do
    {:stop, :normal, state}
  end

  def handle_info(msg, %{socket: socket} = state) do
    case state.view_module.handle_info(msg, socket) do
      {:ok, ^socket} -> {:noreply, state}
      {:ok, %Socket{} = new_socket} ->
        new_state = %{state | socket: new_socket}
        send_channel(state, {:render, rerender(new_state)})
        {:noreply, new_state}

      {:stop, {:redirect, opts}, %Socket{} = new_socket} ->
        send_channel(state, {:redirect, opts})
        {:stop, :normal, %{state | socket: new_socket}}
     end
  end

  def handle_call({:attach, channel_pid}, _, state) do
    if state.shutdown_timer, do: Process.cancel_timer(state.shutdown_timer)
    Process.monitor(channel_pid)
    {:reply, :ok, %{state | channel_pid: channel_pid, shutdown_timer: nil}}
  end

  def handle_call({:channel_event, event, dom_id, value}, _, %{socket: socket} = state) do
    event
    |> state.view_module.handle_event(dom_id, value, socket)
    |> handle_event_result(socket, state)
  end
  defp handle_event_result({:ok, %Socket{} = unchanged_socket}, %Socket{} = unchanged_socket, state) do
    {:reply, :noop, state}
  end
  defp handle_event_result({:ok, %Socket{} = new_socket}, %Socket{} = _original_socket, state) do
    new_state = %{state | socket: new_socket}
    {:reply, {:render, rerender(new_state)}, new_state}
  end
  defp handle_event_result({:stop, {:redirect, opts}, %Socket{} = socket}, %Socket{} = _original_socket, state) do
    {:stop, :normal, {:redirect, opts}, %{state | socket: socket}}
  end

  def terminate(reason, %{socket: socket} = state) do
    {:ok, %Socket{} = new_socket} = state.view_module.terminate(reason, socket)
    {:ok, %{state | socket: new_socket}}
  end

  defp rerender(%{view_module: view, socket: socket}) do
    Phoenix.View.render_to_iodata(__MODULE__, "template.html", %{assigns: socket.assigns, view: view})
  end
  def render("template.html", %{assigns: assigns, view: view}) do
    view.render(assigns)
  end

  defp send_channel(%{channel_pid: nil}, _message), do: :noop
  defp send_channel(%{channel_pid: pid}, message) do
    send(pid, message)
  end
end

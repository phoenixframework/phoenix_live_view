defmodule Phoenix.LiveView.Server do
  @moduledoc false
  use GenServer
  import Phoenix.HTML, only: [sigil_E: 2]

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  def start_link({{_ref, _pid}, _channel_pid, _socket, session} = args) do
    GenServer.start_link(__MODULE__, args, name: name(session.id))
  end

  defp name(id), do: {:via, Registry, {LiveView.Registry, id}}

  def sign_token(endpoint_mod, salt, data) do
    encoded_data = data |> :erlang.term_to_binary() |> Base.encode64()
    Phoenix.Token.sign(endpoint_mod, salt, encoded_data)
  end

  def verify_token(endpoint_mod, salt, token, opts) do
    case Phoenix.Token.verify(endpoint_mod, salt, token, opts) do
      {:ok, encoded_term} ->
        term = encoded_term |> Base.decode64!() |> :erlang.binary_to_term()
        {:ok, term}

      {:error, _} = error -> error
    end
  end

  @doc """
  TODO
  """
  def static_render(endpoint, view, opts) do
    session = Keyword.fetch!(opts, :session)
    {:ok, socket, prepared_assigns, signed_session} = static_mount(endpoint, view, session)

    ~E"""
    <div id="<%= LiveView.Socket.dom_id(socket) %>"
         data-phx-view="<%= inspect(view) %>"
         data-session="<%= signed_session %>">
      <%= view.render(prepared_assigns) %>
    </div>
    <div class="phx-loader"></div>
    """
  end

  @doc """
  TODO
  """
  def nested_static_render(%Socket{} = parent, view, opts) do
    session = Keyword.fetch!(opts, :session)

    if Socket.connected?(parent) do
      {child_id, signed_session} = sign_child_session(parent, view, session)
      ~E"""
      <div id="<%= child_id %>"
           data-phx-parent-id="<%= LiveView.Socket.dom_id(parent) %>"
           data-phx-view="<%= inspect(view) %>"
           data-session="<%= signed_session %>">

      </div>
      <div class="phx-loader"></div>
      """
     else
       {:ok, socket, prepared_assigns, signed_session} = static_mount(parent, view, session)

       ~E"""
       <div id="<%= LiveView.Socket.dom_id(socket) %>"
            data-phx-parent-id="<%= LiveView.Socket.dom_id(parent) %>"
            data-phx-view="<%= inspect(view) %>"
            data-session="<%= signed_session %>">

         <%= view.render(prepared_assigns) %>
       </div>
       <div class="phx-loader"></div>
       """
    end
  end

  defp static_mount(%Socket{} = parent, view, session) do
    parent
    |> LiveView.Socket.build_nested_socket(%{view: view})
    |> do_static_mount(view, session)
  end
  defp static_mount(endpoint, view, session) do
    endpoint
    |> LiveView.Socket.build_socket(%{view: view})
    |> do_static_mount(view, session)
  end
  defp do_static_mount(socket, view, session) do
    session
    |> view.mount(socket)
    |> mount_ok(view)
    |> case do
      {:ok, %Socket{} = new_socket} ->
        signed_session = sign_session(socket, session)

        {:ok, new_socket, prep_assigns_for_render(new_socket, session), signed_session}
    end
  end

  defp prep_assigns_for_render(%Socket{assigns: assigns} = socket, session) do
    Map.merge(assigns, %{session: session, socket: socket})
  end

  @doc """
  TODO
  """
  def spawn_render(endpoint, session) do
    {:ok, pid, ref} = start_view(self(), endpoint, session)

    receive do
      {^ref, rendered_view} -> {:ok, pid, rendered_view}
    end
  end
  defp start_view(channel_pid, endpoint, session) do
    ref = make_ref()

    case start_dynamic_child(ref, channel_pid, endpoint, session) do
      {:ok, pid} -> {:ok, pid, ref}
      {:error, {%_{} = exception, [_|_] = stack}} -> reraise(exception, stack)
    end
  end
  defp start_dynamic_child(ref, channel_pid, endpoint, session) do
    args = {{ref, self()}, channel_pid, endpoint, session}
    DynamicSupervisor.start_child(
      DemoWeb.DynamicSupervisor,
      Supervisor.child_spec({Phoenix.LiveView.Server, args}, restart: :temporary)
    )
  end

  def init({{ref, client_pid}, channel_pid, endpoint, session}) do
    %{id: id, view: view, session: user_session} = session

    socket =
      LiveView.Socket.build_socket(endpoint, %{
        connected?: true,
        id: id,
        view: view,
      })

    with {:ok, %Socket{} = socket, opts} <- wrap_mount(view.mount(user_session, socket)) do
      configure_init(socket, user_session, channel_pid, view, opts, {ref, client_pid})
    else
      {:error, reason} -> {:error, reason}
      other -> mount_ok(other, view)
    end
  end
  defp wrap_mount({:ok, %Socket{} = socket}), do: {:ok, socket, []}
  defp wrap_mount({:ok, %Socket{} = socket, opts}), do: {:ok, socket, opts}
  defp wrap_mount(other), do: other

  defp configure_init(%Socket{} = socket, user_session, channel_pid, view, _opts, {ref, client_pid}) do
    _ref = Process.monitor(channel_pid)
    state = %{
      view_module: view,
      socket: socket,
      channel_pid: channel_pid,
      session: user_session,
    }
    send(client_pid, {ref, rerender(state)})

    {:ok, state}
  end

  defp mount_ok({:ok, %Socket{} = socket}, _view), do: {:ok, socket}
  defp mount_ok(other, view) do
    raise ArgumentError, """
    invalid result returned from #{inspect(view)}.mount/2.

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
  defp handle_event_result({:noreply, %Socket{} = unchanged}, %Socket{} = unchanged, state) do
    {:reply, :noop, state}
  end
  defp handle_event_result({:noreply, %Socket{} = new_socket}, %Socket{} = _before, state) do
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

  defp noreply(state, _kind, %Socket{} = socket, {:noreply, %Socket{} = socket}) do
    {:noreply, state}
  end
  defp noreply(state, _kind, %Socket{} = _before, {:noreply, %Socket{} = new_socket}) do
    new_state = %{state | socket: new_socket}
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

  defp rerender(%{view_module: view, socket: socket, session: session}) do
    assigns = prep_assigns_for_render(socket, session)
    Phoenix.View.render_to_iodata(__MODULE__, "template.html", %{assigns: assigns, view: view})
  end
  def render("template.html", %{assigns: assigns, view: view}) do
    view.render(assigns)
  end

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

  defp sign_child_session(%Socket{} = parent, child_view, session) do
    id = LiveView.Socket.child_dom_id(parent, child_view)
    token =
      sign_token(parent.endpoint, salt(parent), %{
        id: id,
        parent_id: LiveView.Socket.dom_id(parent),
        view: child_view,
        session: session,
      })

    {id, token}
  end

  defp salt(%Socket{endpoint: endpoint}) do
    LiveView.Socket.configured_signing_salt!(endpoint)
  end
end

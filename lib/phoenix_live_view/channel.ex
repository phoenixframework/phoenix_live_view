defmodule Phoenix.LiveView.Channel do
  @moduledoc false

  require Logger

  alias Phoenix.LiveView
  alias Phoenix.LiveView.{Socket, View, Diff}

  alias Phoenix.Socket.Message

  def start_link({auth_payload, from, socket}) do
    GenServer.start_link(__MODULE__, {auth_payload, from, socket})
  end

  def init({%{"session" => session_token}, from, socket}) do
    case View.verify_session(socket.endpoint, session_token) do
      {:ok, %{id: id, view: view, session: user_session}} ->
        verified_init(view, id, user_session, from, socket)

      {:error, reason} ->
        log_mount(socket, fn ->
          "Mounting #{socket.topic} failed while verifying session with: #{inspect(reason)}"
        end)

        GenServer.reply(from, %{reason: "badsession"})
        :ignore
    end
  end

  def init({%{}, from, socket}) do
    log_mount(socket, fn -> "Mounting #{socket.topic} failed because no session was provided" end)
    GenServer.reply(from, %{reason: "nosession"})
    :ignore
  end

  defp verified_init(view, id, user_session, from, %Phoenix.Socket{} = phx_socket) do
    Process.monitor(phx_socket.transport_pid)

    lv_socket =
      Socket.build_socket(phx_socket.endpoint, %{
        connected?: true,
        view: view,
        id: id
      })

    case wrap_mount(view.mount(user_session, lv_socket)) do
      {:ok, %Socket{} = lv_socket, _user_opts} ->
        {state, rendered} =
          lv_socket
          |> build_state(phx_socket, user_session)
          |> rerender()

        {new_state, rendered_diff} = render_diff(state, rendered)

        GenServer.reply(from, %{rendered: rendered_diff})
        {:ok, new_state}

      {:error, reason} = err ->
        log_mount(phx_socket, fn -> "Mounting #{inspect(view)} #{id} failed: #{inspect(err)}" end)

        GenServer.reply(from, reason)
        :ignore

      other ->
        View.raise_invalid_mount(other, view)
    end
  end

  defp build_state(%Socket{} = lv_socket, %Phoenix.Socket{} = phx_socket, session) do
    %{
      socket: lv_socket,
      session: session,
      fingerprints: nil,
      serializer: phx_socket.serializer,
      topic: phx_socket.topic,
      transport_pid: phx_socket.transport_pid,
      join_ref: phx_socket.join_ref
    }
  end

  def handle_info({:DOWN, _, _, transport_pid, reason}, %{transport_pid: transport_pid} = socket) do
    reason = if reason == :normal, do: {:shutdown, :closed}, else: reason
    {:stop, reason, socket}
  end

  def handle_info(%Message{topic: topic, event: "phx_leave"} = msg, %{topic: topic} = state) do
    reply(state, msg.ref, :ok, %{})

    {:stop, {:shutdown, :left}, state}
  end

  def handle_info(%Message{topic: topic, event: "event"} = msg, %{topic: topic} = state) do
    %{"value" => raw_val, "event" => event, "type" => type} = msg.payload
    val = decode(type, raw_val)
    result = view_module(state).handle_event(event, val, state.socket)
    handle_result(state, :event, state.socket, result)
  end

  def handle_info(msg, %{socket: socket} = state) do
    handle_result(state, :handle_info, socket, view_module(state).handle_info(msg, socket))
  end

  @doc false
  def terminate(reason, %{socket: socket} = state) do
    view = view_module(state)

    if function_exported?(view, :terminate, 2) do
      view.terminate(reason, socket)
    else
      :ok
    end
  end

  @doc false
  def code_change(old, %{socket: socket} = state, extra) do
    view = view_module(state)

    if function_exported?(view, :code_change, 3) do
      view.code_change(old, socket, extra)
    else
      {:ok, state}
    end
  end

  defp handle_result(state, _kind, %Socket{} = socket, {:noreply, %Socket{} = socket}) do
    {:noreply, state}
  end

  defp handle_result(state, _kind, %Socket{} = _before, {:noreply, %Socket{} = new_socket}) do
    {new_state, rendered} = rerender(%{state | socket: new_socket})
    {:noreply, push_render(new_state, rendered)}
  end

  defp handle_result(state, _kind, _socket, {:stop, {:redirect, opts}, %Socket{} = new_socket}) do
    {:stop, {:shutdown, :redirect}, push_redirect(%{state | socket: new_socket}, opts)}
  end

  defp handle_result(state, kind, _original_socket, result) do
    raise ArgumentError, """
    invalid noreply from #{inspect(view_module(state))}.#{kind} callback.

    Expected {:noreply, %Socket{}} | {:stop, reason, %Socket{}}. got: #{inspect(result)}
    """
  end

  defp view_module(%{socket: socket}), do: Socket.view(socket)

  defp decode("form", url_encoded) do
    Plug.Conn.Query.decode(url_encoded)
  end

  defp decode(_, value), do: value

  defp push_render(state, %LiveView.Rendered{} = rendered) do
    {new_state, diff} = render_diff(state, rendered)
    push(new_state, "render", diff)
    new_state
  end

  defp push_redirect(state, opts) do
    push(state, "redirect", %{
      to: Keyword.fetch!(opts, :to),
      flash: View.sign_flash(state.socket, opts[:flash])
    })

    state
  end

  defp render_diff(%{fingerprints: prints} = state, %LiveView.Rendered{} = rendered) do
    {diff, new_prints} = Diff.render(rendered, prints)
    {%{state | fingerprints: new_prints}, diff}
  end

  defp rerender(%{socket: socket, session: session} = state) do
    rendered = View.render(socket, session)
    {reset_changed(state, rendered.fingerprint), rendered}
  end

  defp reset_changed(%{socket: socket} = state, root_print) do
    new_socket =
      socket
      |> Socket.clear_changed()
      |> Socket.put_root(root_print)

    %{state | socket: new_socket}
  end

  defp log_mount(%Phoenix.Socket{private: %{log_join: false}}, _), do: :noop
  defp log_mount(%Phoenix.Socket{private: %{log_join: level}}, func), do: Logger.log(level, func)

  defp wrap_mount({:ok, %Socket{} = socket}), do: {:ok, socket, []}
  defp wrap_mount({:ok, %Socket{} = socket, opts}), do: {:ok, socket, opts}
  defp wrap_mount(other), do: other

  defp reply(state, ref, status, payload) do
    reply_ref = {state.transport_pid, state.serializer, state.topic, ref, state.join_ref}
    Phoenix.Channel.reply(reply_ref, {status, payload})
  end

  defp push(state, event, payload) do
    message = %Message{topic: state.topic, event: event, payload: payload}
    send(state.transport_pid, state.serializer.encode!(message))
    :ok
  end
end

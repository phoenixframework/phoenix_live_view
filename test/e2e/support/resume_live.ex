defmodule Phoenix.LiveViewTest.E2E.Resume do
  # Shared by the resumable and the plain LiveView of the resume tests (resume.spec.js).
  #
  # The LiveView registers under the name given in the URL, so the tests can send it
  # messages with evalPlug while the client is disconnected.
  use Phoenix.Component

  alias Phoenix.LiveView.ColocatedHook, as: Hook

  def mount(params, socket, kind) do
    socket =
      assign(socket,
        kind: kind,
        mount_id: Base.encode16(:crypto.strong_rand_bytes(4)),
        ticks: 0,
        clicks: 0
      )

    if Phoenix.LiveView.connected?(socket) and params["name"] do
      Process.register(self(), name(params["name"]))
    end

    {:ok, socket}
  end

  def name(name), do: String.to_atom("resume:" <> name)

  @doc """
  Closes the connection of the named LiveView from the server, as if it dropped.
  The client reconnects right away.
  """
  def drop(name) do
    name |> name() |> send(:drop)
    :ok
  end

  def handle_event("click", _params, socket) do
    {:noreply, update(socket, :clicks, &(&1 + 1))}
  end

  # the connection drops before the client receives the reply
  def handle_event("click_and_drop", _params, socket) do
    drop_connection(socket)
    {:noreply, update(socket, :clicks, &(&1 + 1))}
  end

  def handle_info(:tick, socket), do: {:noreply, update(socket, :ticks, &(&1 + 1))}

  def handle_info({:navigate, to}, socket),
    do: {:noreply, Phoenix.LiveView.push_navigate(socket, to: to)}

  def handle_info(:drop, socket) do
    drop_connection(socket)
    {:noreply, socket}
  end

  # the transport of a resumable LiveView is its resume session, whose pipe is the connection
  defp drop_connection(socket) do
    transport = socket.transport_pid

    pipe =
      case Process.info(transport, :dictionary) do
        {:dictionary, dict} ->
          case dict[:"$process_label"] do
            {Phoenix.Socket.ResumeSession, _, _} -> :sys.get_state(transport).pipe
            _ -> transport
          end

        nil ->
          transport
      end

    pipe && send(pipe, :socket_drain)
  end

  def render(assigns) do
    ~H"""
    <h1>{@kind}</h1>
    <dl>
      <dt>mount id</dt>
      <dd id="mount-id">{@mount_id}</dd>
      <dt>ticks</dt>
      <dd id="ticks">{@ticks}</dd>
      <dt>clicks</dt>
      <dd id="clicks">{@clicks}</dd>
    </dl>
    <button id="click" phx-click="click">click</button>
    <button id="click-and-drop" phx-click="click_and_drop">click and drop</button>
    <ul id="hook-log" phx-hook=".HookLog" phx-update="ignore"></ul>
    <script :type={Hook} name=".HookLog">
      export default {
        mounted() {
          this.log("mounted");
        },
        disconnected() {
          this.log("disconnected");
        },
        reconnected() {
          this.log("reconnected");
        },
        log(event) {
          const li = document.createElement("li");
          li.textContent = event;
          this.el.append(li);
        },
      };
    </script>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.ResumeLive do
  use Phoenix.LiveView, resumable: true

  alias Phoenix.LiveViewTest.E2E.Resume

  def mount(params, _session, socket), do: Resume.mount(params, socket, "resumable")
  defdelegate handle_event(event, params, socket), to: Resume
  defdelegate handle_info(message, socket), to: Resume
  defdelegate render(assigns), to: Resume
end

defmodule Phoenix.LiveViewTest.E2E.ResumeLive.Plain do
  use Phoenix.LiveView

  alias Phoenix.LiveViewTest.E2E.Resume

  def mount(params, _session, socket), do: Resume.mount(params, socket, "plain")
  defdelegate handle_event(event, params, socket), to: Resume
  defdelegate handle_info(message, socket), to: Resume
  defdelegate render(assigns), to: Resume
end

defmodule Phoenix.LiveViewTest.E2E.ResumeLive.Other do
  use Phoenix.LiveView

  def mount(_params, _session, socket), do: {:ok, socket}

  def render(assigns) do
    ~H"""
    <h1 id="other">other</h1>
    """
  end
end

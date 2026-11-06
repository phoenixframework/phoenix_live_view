defmodule Phoenix.LiveViewTest.E2E.ResumeLive do
  # A LiveView for resuming its socket over a new connection, see resume.spec.js.
  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveView
  def mount(%{"name" => name}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Phoenix.LiveViewTest.E2E.PubSub, "resume:#{name}")
    end

    session = if connected?(socket), do: get_connect_info(socket, :session), else: %{}

    {:ok,
     assign(socket,
       mount_id: if(connected?(socket), do: System.unique_integer([:positive]), else: "dead"),
       live_socket_id: session["live_socket_id"],
       clicks: 0,
       ticks: 0
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("click", _params, socket) do
    {:noreply, update(socket, :clicks, &(&1 + 1))}
  end

  @impl Phoenix.LiveView
  def handle_info(:tick, socket) do
    {:noreply, update(socket, :ticks, &(&1 + 1))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <p>mount: <span id="mount-id">{@mount_id}</span></p>
    <p>live_socket_id: <span id="live-socket-id">{@live_socket_id}</span></p>
    <p>clicks: <span id="clicks">{@clicks}</span></p>
    <p>ticks: <span id="ticks">{@ticks}</span></p>
    <button id="click" phx-click="click">click</button>
    <p id="status" style="display: none" phx-disconnected={JS.show()} phx-connected={JS.hide()}>
      disconnected
    </p>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.ResumeSessionController do
  use Phoenix.Controller, formats: [:html]

  # sets the live_socket_id in the session, as logging in a user would
  def update(conn, %{"live_socket_id" => id}) do
    conn
    |> put_session(:live_socket_id, id)
    |> send_resp(200, "")
  end
end

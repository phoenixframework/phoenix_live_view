defmodule Phoenix.LiveViewTest.E2E.Issue3681Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3681

  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render("live.html", assigns) do
    ~H"""
    {apply(Phoenix.LiveViewTest.E2E.Layout, :render, [
      "live.html",
      Map.put(assigns, :inner_content, [])
    ])}

    {live_render(
      @socket,
      Phoenix.LiveViewTest.E2E.Issue3681.StickyLive,
      id: "sticky",
      sticky: true
    )}

    <hr />
    {@inner_content}
    <hr />
    """
  end

  def render(assigns) do
    ~H"""
    <h3>A LiveView that does nothing but render it's layout.</h3>
    <.link navigate="/issues/3681/away">Go to a different LV with a (funcky) stream</.link>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3681.AwayLive do
  use Phoenix.LiveView, layout: {Phoenix.LiveViewTest.E2E.Issue3681Live, :live}

  def mount(_params, _session, socket) do
    socket =
      socket
      |> stream(:messages, [])
      # <--- This is the root cause
      |> stream(:messages, [msg(4)], reset: true)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h3>A liveview with a stream configured twice</h3>
    <h4>This causes the nested liveview in the layout above to be reset by the client.</h4>

    <.link navigate="/issues/3681">Go back to (the now borked) LV without a stream</.link>
    <h1>Normal Stream</h1>
    <div id="msgs-normal" phx-update="stream">
      <div :for={{dom_id, msg} <- @streams.messages} id={dom_id}>
        <div>{msg.msg}</div>
      </div>
    </div>
    """
  end

  defp msg(num) do
    %{id: num, msg: num}
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3681.StickyLive do
  use Phoenix.LiveView, layout: false

  def mount(_params, _session, socket) do
    {:ok, stream(socket, :messages, [msg(1), msg(2), msg(3)])}
  end

  def render(assigns) do
    ~H"""
    <div id="msgs-sticky" phx-update="stream">
      <div :for={{dom_id, msg} <- @streams.messages} id={dom_id}>
        <div>{msg.msg}</div>
      </div>
    </div>
    """
  end

  defp msg(num) do
    %{id: num, msg: num}
  end
end

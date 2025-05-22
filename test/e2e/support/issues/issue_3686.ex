defmodule Phoenix.LiveViewTest.E2E.Issue3686.ALive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <h1>A</h1>
    <button phx-click="go">To B</button>

    <div id="flash">
      {inspect(@flash)}
    </div>
    """
  end

  def handle_event("go", _unsigned_params, socket) do
    {:noreply, socket |> put_flash(:info, "Flash from A") |> push_navigate(to: "/issues/3686/b")}
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3686.BLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <h1>B</h1>
    <button phx-click="go">To C</button>

    <div id="flash">
      {inspect(@flash)}
    </div>
    """
  end

  def handle_event("go", _unsigned_params, socket) do
    {:noreply, socket |> put_flash(:info, "Flash from B") |> redirect(to: "/issues/3686/c")}
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3686.CLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <h1>C</h1>
    <button phx-click="go">To A</button>

    <div id="flash">
      {inspect(@flash)}
    </div>
    """
  end

  def handle_event("go", _unsigned_params, socket) do
    {:noreply, socket |> put_flash(:info, "Flash from C") |> push_navigate(to: "/issues/3686/a")}
  end
end

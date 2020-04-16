defmodule Phoenix.LiveViewTest.Controller do
  use Phoenix.Controller
  import Phoenix.LiveView.Controller

  plug :put_layout, false

  def widget(conn, _) do
    conn
    |> put_view(Phoenix.LiveViewTest.LayoutView)
    |> render("widget.html")
  end

  def incoming(conn, %{"type" => "live-render-2"}) do
    live_render(conn, Phoenix.LiveViewTest.DashboardLive)
  end

  def incoming(conn, %{"type" => "live-render-3"}) do
    live_render(conn, Phoenix.LiveViewTest.DashboardLive, session: %{"custom" => :session})
  end

  def incoming(conn, %{"type" => "live-render-4"}) do
    conn
    |> put_layout({Phoenix.LiveViewTest.AssignsLayoutView, :app})
    |> live_render(Phoenix.LiveViewTest.DashboardLive)
  end

  def not_found(conn, _) do
    conn
    |> put_status(:not_found)
    |> text("404")
  end
end

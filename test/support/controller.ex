defmodule Phoenix.LiveViewTest.Support.Controller do
  use Phoenix.Controller, formats: [:html]
  import Phoenix.LiveView.Controller

  plug :put_layout, false

  def widget(conn, _) do
    conn
    |> put_view(Phoenix.LiveViewTest.Support.LayoutView)
    |> render("widget.html")
  end

  def incoming(conn, %{"type" => "live-render-2"}) do
    live_render(conn, Phoenix.LiveViewTest.Support.DashboardLive)
  end

  def incoming(conn, %{"type" => "live-render-3"}) do
    live_render(conn, Phoenix.LiveViewTest.Support.DashboardLive,
      session: %{"custom" => :session}
    )
  end

  def incoming(conn, %{"type" => "live-render-4"}) do
    conn
    |> put_layout({Phoenix.LiveViewTest.Support.AssignsLayoutView, :app})
    |> live_render(Phoenix.LiveViewTest.Support.DashboardLive)
  end

  def incoming(conn, %{"type" => "render-with-function-component"}) do
    conn
    |> put_view(Phoenix.LiveViewTest.Support.LayoutView)
    |> render("with-function-component.html")
  end

  def incoming(conn, %{"type" => "render-layout-with-function-component"}) do
    conn
    |> put_view(Phoenix.LiveViewTest.Support.LayoutView)
    |> put_root_layout(
      {Phoenix.LiveViewTest.Support.LayoutView, "layout-with-function-component.html"}
    )
    |> render("hello.html")
  end

  def not_found(conn, _) do
    conn
    |> put_status(:not_found)
    |> text("404")
  end
end

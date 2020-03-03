defmodule Phoenix.LiveView.Plug do
  @moduledoc false

  alias Phoenix.LiveView.Controller

  @behaviour Plug

  @link_header "x-requested-with"
  def link_header, do: @link_header

  @impl Plug
  def init(view) when is_atom(view), do: view

  @impl Plug
  def call(%{private: %{phoenix_live_view: {view, opts}}} = conn, _) do
    if live_link?(conn) do
      html = Phoenix.LiveView.Static.container_render(conn, view, opts)

      conn
      |> put_cache_headers()
      |> Plug.Conn.put_resp_header(@link_header, "live-link")
      |> Phoenix.Controller.html(html)
    else
      conn
      |> put_new_layout_from_router(opts)
      |> Controller.live_render(view, opts)
    end
  end

  @doc false
  def put_cache_headers(conn) do
    conn
    |> Plug.Conn.put_resp_header("vary", @link_header)
    |> Plug.Conn.put_resp_header(
      "cache-control",
      "max-age=0, no-cache, no-store, must-revalidate, post-check=0, pre-check=0"
    )
  end

  defp put_new_layout_from_router(conn, opts) do
    cond do
      live_link?(conn) -> Phoenix.Controller.put_layout(conn, false)
      layout = opts[:layout] -> Phoenix.Controller.put_layout(conn, layout)
      layout = conn.private[:phoenix_root_layout] -> Phoenix.Controller.put_layout(conn, layout)
      layout = opts[:inferred_layout] -> Phoenix.Controller.put_new_layout(conn, layout)
      true -> conn
    end
  end

  defp live_link?(%Plug.Conn{} = conn) do
    Plug.Conn.get_req_header(conn, @link_header) == ["live-link"]
  end
end

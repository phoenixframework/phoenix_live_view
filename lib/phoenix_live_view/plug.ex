defmodule Phoenix.LiveView.Plug do
  @moduledoc false

  alias Phoenix.LiveView.Controller
  alias Plug.Conn

  @behaviour Plug

  @link_header "x-requested-with"
  def link_header, do: @link_header

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{private: %{phoenix_live_view: opts}} = conn, view) do
    session_opts = Keyword.get(opts, :session, [:path_params])
    render_opts =
      opts
      |> Keyword.take([:container])
      |> Keyword.put(:session, session(conn, session_opts))

    if live_link?(conn) do
      html = Phoenix.LiveView.View.static_render_container(conn, view, render_opts)

      conn
      |> put_cache_headers()
      |> Plug.Conn.put_resp_header(@link_header, "live-link")
      |> Phoenix.Controller.html(html)
    else
      conn
      |> put_new_layout_from_router(opts)
      |> Controller.live_render(view, render_opts)
    end
  end

  @doc false
  def put_cache_headers(conn) do
    conn
    |> Plug.Conn.put_resp_header("vary", @link_header)
    |> Plug.Conn.put_resp_header("cache-control", "max-age=0, no-cache, no-store, must-revalidate, post-check=0, pre-check=0")
  end

  defp session(conn, session_opts) do
    Enum.reduce(session_opts, %{}, fn
      :path_params, acc -> Map.put(acc, :path_params, conn.path_params)
      key, acc -> Map.put(acc, key, Conn.get_session(conn, key))
    end)
  end

  defp put_new_layout_from_router(conn, opts) do
    cond do
      live_link?(conn) -> Phoenix.Controller.put_layout(conn, false)
      layout = opts[:layout] -> Phoenix.Controller.put_new_layout(conn, layout)
      true -> conn
    end
  end

  defp live_link?(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, @link_header) do
      ["live-link"] -> true
      [_] -> false
      [] -> false
    end
  end
end

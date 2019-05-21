defmodule Phoenix.LiveView.Plug do
  @moduledoc false

  alias Phoenix.LiveView.Controller
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{private: %{phoenix_live_view: opts}} = conn, view) do
    session_opts = Keyword.get(opts, :session, [:path_params])

    render_opts =
      opts
      |> Keyword.take([:container])
      |> Keyword.put(:session, session(conn, session_opts))

    conn
    |> put_new_layout_from_router(opts)
    |> Controller.live_render(view, render_opts)
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
    case Plug.Conn.get_req_header(conn, "x-liveview-link") do
      [_] -> true
      [] -> false
    end
  end
end

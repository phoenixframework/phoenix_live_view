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
    if layout = opts[:layout] do
      Phoenix.Controller.put_new_layout(conn, layout)
    else
      conn
    end
  end
end

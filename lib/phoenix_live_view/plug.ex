defmodule Phoenix.LiveView.Plug do
  @moduledoc false

  alias Phoenix.LiveView.Controller
  alias Plug.Conn

  @behaviour Plug

  @link_header "x-requested-with"
  def link_header, do: @link_header

  @impl Plug
  def init({view, opts}) do
    router = Keyword.fetch!(opts, :router)

    new_opts =
      opts
      |> Keyword.put_new_lazy(:layout, fn ->
        view =
          router
          |> Atom.to_string()
          |> String.split(".")
          |> Enum.drop(-1)
          |> Kernel.++(["LayoutView"])
          |> Module.concat()

        {view, :app}
      end)

    {view, new_opts}
  end


  @impl Plug
  def call(conn, {view, opts}) do
    # TODO: Deprecate atom entries in :session
    session_keys = Keyword.get(opts, :session, [])

    render_opts =
      opts
      |> Keyword.take([:container, :router])
      |> Keyword.put(:session, session(conn, session_keys))

    if live_link?(conn) do
      html = Phoenix.LiveView.Static.container_render(conn, view, render_opts)

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
    |> Plug.Conn.put_resp_header(
      "cache-control",
      "max-age=0, no-cache, no-store, must-revalidate, post-check=0, pre-check=0"
    )
  end

  defp session(conn, session_keys) do
    for key_or_pair <- session_keys, into: %{} do
      case key_or_pair do
        key when is_atom(key) -> {key, Conn.get_session(conn, key)}
        key when is_binary(key) -> {key, Conn.get_session(conn, key)}
        {key, value} -> {key, value}
      end
    end
  end

  defp put_new_layout_from_router(conn, opts) do
    cond do
      live_link?(conn) -> Phoenix.Controller.put_layout(conn, false)
      layout = opts[:layout] -> Phoenix.Controller.put_new_layout(conn, layout)
      true -> conn
    end
  end

  defp live_link?(%Plug.Conn{} = conn) do
    Plug.Conn.get_req_header(conn, @link_header) == ["live-link"]
  end
end

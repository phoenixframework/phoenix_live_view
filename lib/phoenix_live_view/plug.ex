defmodule Phoenix.LiveView.Plug do
  @moduledoc false

  @behaviour Plug

  @link_header "x-requested-with"
  @response_url_header "x-response-url"

  def link_header, do: @link_header

  @impl Plug
  def init(view) when is_atom(view), do: view

  @impl Plug
  def call(%{private: %{phoenix_live_view: {view, opts}}} = conn, _) do
    opts = maybe_dispatch_session(conn, opts)

    if live_link?(conn) do
      html = Phoenix.LiveView.Static.container_render(conn, view, opts)

      conn
      |> put_cache_headers()
      |> Plug.Conn.put_resp_header(@link_header, "live-link")
      |> Plug.Conn.put_resp_header(@response_url_header, Phoenix.Controller.current_url(conn))
      |> Phoenix.Controller.html(html)
    else
      conn
      |> Phoenix.Controller.put_layout(false)
      |> put_root_layout_from_router(opts)
      |> Phoenix.LiveView.Controller.live_render(view, opts)
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

  defp maybe_dispatch_session(conn, opts) do
    case opts[:session] do
      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        Keyword.put(opts, :session, apply(mod, fun, [conn | args]))

      _ ->
        opts
    end
  end

  defp put_root_layout_from_router(conn, opts) do
    case Keyword.fetch(opts, :layout) do
      {:ok, layout} -> Phoenix.Controller.put_root_layout(conn, layout)
      :error -> conn
    end
  end

  defp live_link?(%Plug.Conn{} = conn) do
    Plug.Conn.get_req_header(conn, @link_header) == ["live-link"]
  end
end

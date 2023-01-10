defmodule Phoenix.LiveView.Plug do
  @moduledoc false

  @behaviour Plug

  @impl Plug
  def init(view) when is_atom(view), do: view

  @impl Plug
  def call(%Plug.Conn{private: %{phoenix_live_view: {view, opts, live_session}}} = conn, _) do
    %{extra: live_session_extra} = live_session
    session = live_session(live_session_extra, conn)
    opts = Keyword.put(opts, :session, session)

    conn
    |> Phoenix.Controller.put_layout(false)
    |> put_root_layout_from_router(live_session_extra)
    |> Phoenix.LiveView.Controller.live_render(view, opts)
  end

  defp live_session(opts, conn) do
    case opts[:session] do
      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        apply(mod, fun, [conn | args])

      %{} = session ->
        session

      nil ->
        %{}
    end
  end

  defp put_root_layout_from_router(conn, extra) do
    case Map.fetch(extra, :root_layout) do
      {:ok, layout} -> Phoenix.Controller.put_root_layout(conn, layout)
      :error -> conn
    end
  end
end

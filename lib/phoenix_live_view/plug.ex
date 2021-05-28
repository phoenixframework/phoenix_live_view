defmodule Phoenix.LiveView.Plug do
  @moduledoc false

  @behaviour Plug

  @impl Plug
  def init(view) when is_atom(view), do: view

  @impl Plug
  def call(%{private: %{phoenix_live_view: {view, opts, _live_session}}} = conn, _) do
    opts = maybe_dispatch_session(conn, opts)

    conn
    |> Phoenix.Controller.put_layout(false)
    |> put_root_layout_from_router(opts)
    |> Phoenix.LiveView.Controller.live_render(view, opts)
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
end

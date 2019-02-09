defmodule Phoenix.LiveViewTest do
  @moduledoc """
  TODO
  """

  alias Phoenix.LiveViewTest.{View, ClientProxy, DOM}

  @doc false
  def instrument(:phoenix_controller_render, _, _, func), do: func.()

  @doc false
  def config(:live_view), do: [signing_salt: "11234567821234567831234567841234"]
  def config(:secret_key_base), do: "5678567899556789656789756789856789956789"

  @doc false
  def encode!(msg), do: msg

  def mount_disconnected(view_module, opts) do
    endpoint = __MODULE__
    live_opts = [
      session: opts[:session] || %{}
    ]

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_private(:phoenix_endpoint, endpoint)
      |> Phoenix.LiveView.live_render(view_module, live_opts)

    case conn.status do
      200 ->
        html =
          conn
          |> Phoenix.ConnTest.html_response(200)
          |> IO.iodata_to_binary()

        case DOM.find_sessions(html) do
          [token | _] ->
            {:ok, View.build(token: token, module: view_module, endpoint: endpoint), html}

          [] ->
            {:error, :nosession}
        end

      302 ->
        {:error, %{redirect: hd(Plug.Conn.get_resp_header(conn, "location"))}}
    end
  end

  def mount(view, opts \\ [])

  def mount(view_module, opts) when is_atom(view_module) do
    with {:ok, view, _html} <- mount_disconnected(view_module, opts) do
      mount(view, opts)
    end
  end

  def mount(%View{ref: ref, topic: topic} = view, opts) do
    if View.connected?(view), do: raise ArgumentError, "view is already connected"
    timeout = opts[:timeout] || 5000

    case ClientProxy.start_link(caller: {ref, self()}, view: view, timeout: timeout) do
      {:ok, proxy_pid} ->
        receive do
          {^ref, {:mounted, view_pid, html}} ->
            receive do
              {^ref, {:redirect, _topic, to}} ->
                ensure_down!(view_pid)
                {:error, %{redirect: to}}

            after 0 ->
              view = %View{view | pid: view_pid, proxy: proxy_pid, topic: topic}
              {:ok, view, html}
            end
        end

      :ignore ->
        receive do
          {^ref, reason} -> {:error, reason}
        end
    end
  end

  def render_click(view, event, value \\ %{}) do
    render_event(view, :click, event, value)
  end
  def render_event(view, type, event, value) do
    case GenServer.call(view.proxy, {:render_event, view, type, event, value}) do
      {:ok, html} -> html
      {:error, reason} -> {:error, reason}
    end
  end

  def children(%View{} = parent) do
    GenServer.call(parent.proxy, {:children, parent})
  end

  def render(%View{} = view) do
    {:ok, html} = GenServer.call(view.proxy, {:render_tree, view})
    html
  end

  defmacro assert_redirect(view, to, func) do
    quote do
      %View{ref: ref, proxy: proxy_pid, topic: topic} = unquote(view)
      Process.unlink(proxy_pid)
      unquote(func).()
      assert_receive {^ref, {:redirect, ^topic, unquote(to)}}
    end
  end

  defmacro assert_remove(view, reason, timeout \\ 100) do
    quote do
      %Phoenix.LiveViewTest.View{ref: ref, topic: topic} = unquote(view)
      assert_receive {^ref, {:removed, ^topic, unquote(reason)}}, unquote(timeout)
    end
  end

  def stop(%View{} = view) do
    GenServer.call(view.proxy, {:stop, view})
  end

  defp ensure_down!(pid, timeout \\ 100) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> {:ok, reason}
    after timeout -> {:error, :timeout}
    end
  end
end

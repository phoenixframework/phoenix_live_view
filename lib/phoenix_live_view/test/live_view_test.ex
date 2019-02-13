defmodule Phoenix.LiveViewTest do
  @moduledoc """
  Conveniences for testing Phoenix live views.

  In live view tests, we interact with views via process
  communication in substitution of a browser. Like a browser,
  our test process receives messages about the rendered updates
  from the view, as well as assertions to test the life-cycle of
  live views and their children.


  ## LiveView Testing


  """

  alias Phoenix.LiveViewTest.{View, ClientProxy, DOM}

  @doc """
  Mounts a static live view without connecting to a live process.

  Useful for simulating the rendered result that is sent with
  the intial HTTP request. On successful mount, the view and
  rendered string of HTML are returned in a ok 3-tuple.
  After disconnected mount, `mount/1` or `mount/2`
  may be called with the view, which performs a connected mount
  and spawns the LiveView process.

  For mount failures, an `{:error, reason}` returned.

  ## Examples

      {:ok, view, html} = mount_disconnected(MyEndpoint, MyView, session: %{})

      assert html =~ "<h1>My Disconnected View</h1>"

      {:ok, view, html} = mount(view)
      assert html =~ "<h1>My Connected View</h1>"

      assert {:error, %{redirect: "/somewhere"}} =
             mount_disconnected(MyEndpoint, MyView, session: %{})
  """
  def mount_disconnected(endpoint, view_module, opts) do
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

  @doc """
  Mounts a connected LiveView process.

  Accepts either a previously rendered `%LiveViewTest.View{}` or
  an endpoint and your LiveView module. The latter case is a conveience
  to perform the `mount_disconnected/2` and connected mount in a single
  step.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, MyView, session: %{val: 3})
      assert html =~ "the count is 3"

      assert {:error, %{redirect: "/somewhere"}} =
             mount(MyEndpoint, MyView, session: %{})
  """
  def mount(%View{} = view), do: mount(view, [])
  def mount(endpoint, view_module) when is_atom(endpoint) do
    mount(endpoint, view_module, [])
  end
  def mount(%View{ref: ref, topic: topic} = view, opts) when is_list(opts) do
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
  def mount(endpoint, view_module, opts) when is_atom(endpoint) and is_atom(view_module) and is_list(opts) do
    with {:ok, view, _html} <- mount_disconnected(endpoint, view_module, opts) do
      mount(view, opts)
    end
  end

  @doc """
  Sends a click event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatView, session: %{deg: 30})
      assert html =~ "The temperature is: 30℉"
      assert render_click(view, :inc) =~ "The temperature is: 31℉"
  """
  def render_click(view, event, value \\ %{}) do
    render_event(view, :click, event, value)
  end

  @doc """
  Sends a form submit event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatView, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_submit(view, :refresh, %{deg: 32}) =~ "The temp is: 32℉"
  """
  def render_submit(view, event, value \\ %{}) do
    encoded_form = Plug.Conn.Query.encode(value)
    render_event(view, :form, event, encoded_form)
  end

  @doc """
  Sends a form change event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatView, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_change(view, :validate, %{deg: 123}) =~ "123 exceeds limits"
  """
  def render_change(view, event, value \\ %{}) do
    encoded_form = Plug.Conn.Query.encode(value)
    render_event(view, :form, event, encoded_form)
  end

  @doc """
  Sends a keypress event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatView, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_keypress(view, :inc, :ArrowUp) =~ "The temp is: 32℉"
  """
  def render_keypress(view, event, key_code) do
    render_event(view, :keypress, event, key_code)
  end

  @doc """
  Sends a keyup event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatView, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_keyup(view, :inc, :ArrowUp) =~ "The temp is: 32℉"
  """
  def render_keyup(view, event, key_code) do
    render_event(view, :keypress, event, key_code)
  end

  @doc """
  Sends a keydown event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatView, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_keyup(view, :inc, :ArrowUp) =~ "The temp is: 32℉"
  """
  def render_keydown(view, event, key_code) do
    render_event(view, :keydown, event, key_code)
  end

  defp render_event(view, type, event, value) do
    case GenServer.call(view.proxy, {:render_event, view, type, event, value}) do
      {:ok, html} -> html
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the list of children of the parent live view.

  Children are return in the order they appear in the rendered HTML.

  ## Examples

      {:ok, view, _html} = mount(MyEndpoint, ThermostatView, session: %{deg: 30})
      assert [clock_view] = children(view)
      assert render(clock_view) =~ "current time:"
  """
  def children(%View{} = parent) do
    GenServer.call(parent.proxy, {:children, parent})
  end

  @doc """
  TODO
  """
  def render(%View{} = view) do
    {:ok, html} = GenServer.call(view.proxy, {:render_tree, view})
    html
  end

  @doc """
  TODO
  """
  defmacro assert_redirect(view, to, func) do
    quote do
      %View{ref: ref, proxy: proxy_pid, topic: topic} = unquote(view)
      Process.unlink(proxy_pid)
      unquote(func).()
      assert_receive {^ref, {:redirect, ^topic, unquote(to)}}
    end
  end

  @doc """
  TODO
  """
  defmacro assert_remove(view, reason, timeout \\ 100) do
    quote do
      %Phoenix.LiveViewTest.View{ref: ref, topic: topic} = unquote(view)
      assert_receive {^ref, {:removed, ^topic, unquote(reason)}}, unquote(timeout)
    end
  end

  @doc """
  TODO
  """
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

  @doc false
  def encode!(msg), do: msg
end

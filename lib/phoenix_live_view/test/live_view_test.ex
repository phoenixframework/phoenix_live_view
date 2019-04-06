defmodule Phoenix.LiveViewTest do
  @moduledoc """
  Conveniences for testing Phoenix live views.

  In LiveView tests, we interact with views via process
  communication in substitution of a browser. Like a browser,
  our test process receives messages about the rendered updates
  from the view which can be asserted against to test the
  life-cycle and behavior of live views and their children.

  ## LiveView Testing

  The life-cycle of a live view as outlined in the `Phoenix.LiveView`
  docs details how a view starts as a stateless HTML render in a disconnected
  socket state. Once the browser receives the HTML, it connects to the
  server and a new LiveView process is started, remounted in a connected
  socket state, and the view continues statefully. The LiveView test functions
  support testing both disconnected and connected mounts separately, for example:

      {:ok, view, html} = mount_disconnected(MyEndpoint, MyView, session: %{})

      assert html =~ "<h1>My Disconnected View</h1>"

      {:ok, view, html} = mount(view)
      assert html =~ "<h1>My Connected View</h1>"

      assert {:error, %{redirect: "/somewhere"}} =
             mount_disconnected(MyEndpoint, MyView, session: %{})

  Here, we call `mount_disconnected/3` and assert on the stateless
  rendered HTML that is received by the browser's HTTP request. Next, `mount/2`
  is called to mount the stateless view in a connected state which starts our
  stateful LiveView process.

  In general, it's often more convenient to test the mounting of a view
  in a single step, provided you don't need the result of the stateless HTTP
  render. This is done with a single call to `mount/3`, which performs the
  `mount_disconnected` step for us:

      {:ok, view, html} = mount(MyEndpoint, MyView, session: %{})
      assert html =~ "<h1>My Connected View</h1>"

  ## Testing Events

  The browser can send a variety of events to a live view via `phx-` bindings,
  which are sent to the `handle_event/3` callback. To test events sent by the
  browser and assert on the rendered side-effect of the event, use the
  `render_*` functions:

    * `render_click/3` - sends a phx-click event and value and
      returns the rendered result of the `handle_event/3` callback.

    * `render_submit/3` - sends a form phx-submit event and value and
      returns the rendered result of the `handle_event/3` callback.

    * `render_change/3` - sends a form phx-change event and value and
      returns the rendered result of the `handle_event/3` callback.

    * `render_keydown/3` - sends a form phx-keydown event and value and
      returns the rendered result of the `handle_event/3` callback.

    * `render_keyup/3` - sends a form phx-keyup event and value and
      returns the rendered result of the `handle_event/3` callback.

  For example:

      {:ok, view, _html} = mount(MyEndpoint, ThermostatLive, session: %{deg: 30})

      assert render_click(view, :inc) =~ "The temperature is: 31℉"

      assert render_click(view, :set_temp, 35) =~ "The temperature is: 35℉"

      assert render_submit(view, :save, %{deg: 30}) =~ "The temperature is: 30℉"

      assert render_change(view, :validate, %{deg: -30}) =~ "invalid temperature"

      assert render_keydown(view, :key, :ArrowUp) =~ "The temperature is: 31℉"

      assert render_keydown(view, :key, :ArrowDown) =~ "The temperature is: 30℉"

  ## Testing regular messages

  Live views are `GenServer`'s under the hood, and can send and receive messages
  just like any other server. To test the side effects of sending or receiving
  messages, simply message the view and use the `render` function to test the
  result:

      send(view.pid, {:set_temp: 50})
      assert render(view) =~ "The temperature is: 50℉"

  ## Testing shutdowns and stopping views

  Like all processes, views can shutdown normally or abnormally, and this
  can be tested with `assert_removed/3`. For example:

      send(view.pid, :boom)
      assert_remove view, {:shutdown, %RuntimeError{}}

      stop(view)
      assert_remove view, {:shutdown, :stop}

  Nested views can be removed by a parent at any time based on conditional
  rendering. In these cases, the removal of the view is detected by the
  browser, or our test client, and the child is shutdown gracefully. This
  can be tested in the same way as above:

      assert render(parent) =~ "some content in child"

      [child] = children(parent)
      send(parent.pid, :msg_that_removes_child)

      assert_remove child, _
      refute render(parent) =~ "some content in child"
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

  ## Options

    * `:session` - The optional map of session data for the LiveView
    * `:assigns` - The optional map of `Plug.Conn` assigns

  ## Examples

      {:ok, view, html} = mount_disconnected(MyEndpoint, MyView, session: %{})

      assert html =~ "<h1>My Disconnected View</h1>"

      {:ok, view, html} = mount(view)
      assert html =~ "<h1>My Connected View</h1>"

      assert {:error, %{redirect: "/somewhere"}} =
             mount_disconnected(MyEndpoint, MyView, session: %{})
  """
  def mount_disconnected(endpoint, view_module, opts) do
    live_opts = Keyword.put_new(opts, :session, %{})
    assigns = opts[:assigns] || %{}

    conn =
      assigns
      |> Enum.reduce(Phoenix.ConnTest.build_conn(), fn {key, val}, acc ->
        Plug.Conn.assign(acc, key, val)
      end)
      |> Plug.Conn.put_private(:phoenix_endpoint, endpoint)
      |> Phoenix.LiveView.Controller.live_render(view_module, live_opts)

    case conn.status do
      200 ->
        html =
          conn
          |> Phoenix.ConnTest.html_response(200)
          |> IO.iodata_to_binary()

        child_statics = DOM.find_static_views(html)

        case DOM.find_sessions(html) do
          [{session_token, nil, id} | _] ->
            {:ok,
             View.build(
               dom_id: id,
               session_token: session_token,
               module: view_module,
               endpoint: endpoint,
               child_statics: child_statics
             ), html}

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

  ## Options

    * `:session` - The optional map of session data for the LiveView
    * `:assigns` - The optional map of `Plug.Conn` assigns

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
    if View.connected?(view), do: raise(ArgumentError, "view is already connected")
    timeout = opts[:timeout] || 5000

    case ClientProxy.start_link(caller: {ref, self()}, view: view, timeout: timeout) do
      {:ok, proxy_pid} ->
        receive do
          {^ref, {:mounted, view_pid, html}} ->
            receive do
              {^ref, {:redirect, _topic, to}} ->
                ensure_down!(view_pid)
                {:error, %{redirect: to}}
            after
              0 ->
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

  def mount(endpoint, view_module, opts)
      when is_atom(endpoint) and is_atom(view_module) and is_list(opts) do
    with {:ok, view, _html} <- mount_disconnected(endpoint, view_module, opts) do
      mount(view, opts)
    end
  end

  @doc """
  Sends a click event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatLive, session: %{deg: 30})
      assert html =~ "The temperature is: 30℉"
      assert render_click(view, :inc) =~ "The temperature is: 31℉"
  """
  def render_click(view, event, value \\ %{}) do
    render_event(view, :click, event, value)
  end

  @doc """
  Sends a form submit event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatLive, session: %{deg: 30})
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

      {:ok, view, html} = mount(MyEndpoint, ThermostatLive, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_change(view, :validate, %{deg: 123}) =~ "123 exceeds limits"
  """
  def render_change(view, event, value \\ %{}) do
    encoded_form = Plug.Conn.Query.encode(value)
    render_event(view, :form, event, encoded_form)
  end

  @doc """
  Sends a keyup event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatLive, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_keyup(view, :inc, :ArrowUp) =~ "The temp is: 32℉"
  """
  def render_keyup(view, event, key_code) do
    render_event(view, :keyup, event, key_code)
  end

  @doc """
  Sends a keydown event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatLive, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_keyup(view, :inc, :ArrowUp) =~ "The temp is: 32℉"
  """
  def render_keydown(view, event, key_code) do
    render_event(view, :keydown, event, key_code)
  end

  @doc """
  Sends a blur event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatLive, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_blur(view, :inactive) =~ "Tap to wake"
  """
  def render_blur(view, event, value \\ %{}) do
    render_event(view, :blur, event, value)
  end

  @doc """
  Sends a focus event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = mount(MyEndpoint, ThermostatLive, session: %{deg: 30})
      assert html =~ "The temp is: 30℉"
      assert render_blur(view, :inactive) =~ "Tap to wake"
      assert render_focus(view, :active) =~ "Waking up..."
  """
  def render_focus(view, event, value \\ %{}) do
    render_event(view, :focus, event, value)
  end

  defp render_event(view, type, event, value) do
    case GenServer.call(view.proxy, {:render_event, view, type, event, value}) do
      {:ok, html} -> html
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the current list of children of the parent live view.

  Children are return in the order they appear in the rendered HTML.

  ## Examples

      {:ok, view, _html} = mount(MyEndpoint, ThermostatLive, session: %{deg: 30})
      assert [clock_view] = children(view)
      assert render_click(clock_view, :snooze) =~ "snoozing"
  """
  def children(%View{} = parent) do
    GenServer.call(parent.proxy, {:children, parent})
  end

  @doc """
  Returns the string of HTML of the rendered view.
  """
  def render(%View{} = view) do
    {:ok, html} = GenServer.call(view.proxy, {:render_tree, view})
    html
  end

  @doc """
  Asserts a redirect was peformed after execution of the provied function.

  ## Examples

      assert_redirect view, "/path", fn ->
        assert render_click(view, :event_that_triggers_redirect)
      end
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
  Asserts a view was removed by a parent or shutdown itself.

  ## Examples

      [child1, child2] = children(parent_view)
      send(parent_view.pid, :msg_that_removes_child)

      assert_remove child1, _
      assert_remove child2, {:shutdown, :removed}
  """
  defmacro assert_remove(view, reason, timeout \\ 100) do
    quote do
      %Phoenix.LiveViewTest.View{ref: ref, topic: topic} = unquote(view)
      assert_receive {^ref, {:removed, ^topic, unquote(reason)}}, unquote(timeout)
    end
  end

  @doc """
  Stops a LiveView process.

  ## Examples

      stop(view)
      assert_remove view, {:shutdown, :stop}
  """
  def stop(%View{} = view) do
    GenServer.call(view.proxy, {:stop, view})
  end

  defp ensure_down!(pid, timeout \\ 100) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> {:ok, reason}
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc false
  def encode!(msg), do: msg
end

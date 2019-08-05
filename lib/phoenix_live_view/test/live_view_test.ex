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

      use Phoenix.ConnTest
      import Phoenix.LiveViewTest
      @endpoint MyEndpoint

      test "disconnected and connected mount", %{conn: conn} do
        conn = get(conn, "/my-path")
        assert html_response(conn, 200) =~ "<h1>My Disconnected View</h1>"

        {:ok, view, html} = live(conn)
      end

      test "redirected mount", %{conn: conn} do
        assert {:error, %{redirect: %{to: "/somewhere"}}} = live(conn, "my-path")
      end

  Here, we start by using the familiar `Phoenix.ConnTest` function, `get/2` to
  test the regular HTTP get request which invokes mount with a disconnect socket.
  Next, `live/1` is called with our sent connection to mount the view in a connected
  state, which starts our stateful LiveView process.

  In general, it's often more convenient to test the mounting of a view
  in a single step, provided you don't need the result of the stateless HTTP
  render. This is done with a single call to `live/2`, which performs the
  `get` step for us:

      test "connected mount", %{conn: conn} do
        {:ok, view, html} = live(conn, "/my-path")
        assert html =~ "<h1>My Connected View</h1>"
      end

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

      {:ok, view, _html} = live(conn, "/thermo")

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
  can be tested with `assert_remove/3`. For example:

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
  Spawns a connected LiveView process.

  Accepts either a previously rendered `%Plug.Conn{}` or
  an unsent `%Plug.Conn{}`. The latter case is a conveience
  to perform the `get/2` and connected mount in a single
  step.

  ## Options

    * `:connect_params` - the map of params available in connected mount

  ## Examples

      {:ok, view, html} = live(conn, "/path")

      assert view.module = MyLive

      assert html =~ "the count is 3"

      assert {:error, %{redirect: %{to: "/somewhere"}}} = live(conn, "/path")

      {:ok, view, html} =
        conn
        |> get("/path")
        |> live()
  """
  defmacro live(conn, path_or_opts \\ []) do
    quote bind_quoted: binding(), unquote: true, generated: true do
      case path_or_opts do
        opts when is_list(opts) ->
          unquote(__MODULE__).__live__(conn, conn.request_path, opts, :noop)

        path when is_binary(path) ->
          unquote(__MODULE__).__live__(conn, path, [], fn conn, path -> get(conn, path) end)
      end
    end
  end

  defmacro live(conn, path, opts) do
    quote bind_quoted: binding(), unquote: true do
      unquote(__MODULE__).__live__(conn, path, opts, fn conn, path -> get(conn, path) end)
    end
  end

  @doc false
  def __live__(%Plug.Conn{state: state, status: status} = conn, path, opts, get_func) do
    case {state, status, get_func} do
      {:sent, 200, _} ->
        connect_from_static_token(conn, path, opts)

      {:sent, 302, _} ->
        {:error, %{redirect: %{to: hd(Plug.Conn.get_resp_header(conn, "location"))}}}

      {_, _, get} when is_function(get) ->
        connect_from_static_token(get.(conn, path), path, opts)

      {_, _, :noop} ->
        raise ArgumentError, """
          a request has not yet been sent.

          live/1 must use a connection with a sent response. Either call get/2
          prior to live/1, or use live/2 while providing a path to have a get
          request issues for you. For example issuing a get yourself:

              {:ok, view, _html} =
                conn
                |> get("#{path}")
                |> live()

          or performing the GET and live connect in a single step:

              {:ok, view, _html} = live(conn, "#{path}")
        """
    end
  end

  defp connect_from_static_token(%Plug.Conn{status: redir} = conn, _path, _opts) when redir in [301, 302] do
    {:error, %{redirect: %{to: hd(Plug.Conn.get_resp_header(conn, "location"))}}}
  end
  defp connect_from_static_token(%Plug.Conn{status: 200} = conn, path, opts) do
    html =
      conn
      |> Phoenix.ConnTest.html_response(200)
      |> IO.iodata_to_binary()

    case DOM.find_sessions(html) do
      [{session_token, nil, id} | _] -> do_connect(conn, path, html, session_token, id, opts)
      [] -> {:error, :nosession}
    end
  end

  defp do_connect(%Plug.Conn{} = conn, path, html, session_token, id, opts) do
    live_path = live_path(conn, path)

    child_statics = DOM.find_static_views(html)
    timeout = opts[:timeout] || 5000

    %View{ref: ref, topic: topic} =
      view =
      View.build(
        dom_id: id,
        mount_path: live_path,
        connect_params: opts[:connect_params] || %{},
        session_token: session_token,
        module: conn.assigns.live_view_module,
        router: Phoenix.Controller.router_module(conn),
        endpoint: Phoenix.Controller.endpoint_module(conn),
        child_statics: child_statics
      )

    case ClientProxy.start_link(caller: {ref, self()}, view: view, timeout: timeout) do
      {:ok, proxy_pid} ->
        receive do
          {^ref, {:mounted, view_pid, html}} ->
            receive do
              {^ref, {:redirect, _topic, opts}} ->
                %{to: to} = opts
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
          {^ref, {%_{} = exception, [_|_] = stack}} -> reraise(exception, stack)
          {^ref, %{external_live_redirect: opts}} -> {:error, %{redirect: opts}}
          {^ref, reason} -> {:error, reason}
        end
    end
  end

  defp live_path(%Plug.Conn{} = conn, path) do
    if conn.body_params != %{} or conn.query_string != "" do
      query_params = Plug.Conn.Query.decode(conn.query_string, conn.body_params)

      path <> "?" <> Plug.Conn.Query.encode(query_params)
    else
      path
    end
  end


  @doc """
  Sends a click event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temperature is: 30℉"
      assert render_click(view, :inc) =~ "The temperature is: 31℉"
  """
  def render_click(view, event, value \\ %{}) do
    render_event(view, :click, event, value)
  end

  @doc """
  Sends a form submit event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
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

      {:ok, view, html} = live(conn, "/thermo")
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

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_keyup(view, :inc, :ArrowUp) =~ "The temp is: 32℉"
  """
  def render_keyup(view, event, key_code) do
    render_event(view, :keyup, event, key_code)
  end

  @doc """
  Sends a keydown event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_keyup(view, :inc, :ArrowUp) =~ "The temp is: 32℉"
  """
  def render_keydown(view, event, key_code) do
    render_event(view, :keydown, event, key_code)
  end

  @doc """
  Sends a blur event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_blur(view, :inactive) =~ "Tap to wake"
  """
  def render_blur(view, event, value \\ %{}) do
    render_event(view, :blur, event, value)
  end

  @doc """
  Sends a focus event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
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
  Simulates a live_link click to the view and returns the rendered result.
  """
  def render_live_link(view, path) do
    case GenServer.call(view.proxy, {:render_live_link, view, path}) do
      {:ok, html} -> html
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the current list of children of the parent live view.

  Children are return in the order they appear in the rendered HTML.

  ## Examples

      {:ok, view, _html} = live(conn, "/thermo")
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
  Asserts a redirect was peformed after execution of the provided
  function.

  ## Examples

      assert_redirect view, "/path", fn ->
        assert render_click(view, :event_that_triggers_redirect)
      end
  """
  defmacro assert_redirect(view, to, func) do
    quote do
      %View{ref: ref, proxy: proxy_pid, topic: topic} = unquote(view)
      unquote(func).()
      assert_receive {^ref, {:redirect, ^topic, %{to: unquote(to)}}}
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

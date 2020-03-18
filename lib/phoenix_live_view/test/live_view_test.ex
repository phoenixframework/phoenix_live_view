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
  test the regular HTTP GET request which invokes mount with a disconnected socket.
  Next, `live/1` is called with our sent connection to mount the view in a connected
  state, which starts our stateful LiveView process.

  In general, it's often more convenient to test the mounting of a view
  in a single step, provided you don't need the result of the stateless HTTP
  render. This is done with a single call to `live/2`, which performs the
  `get` step for us:

      test "connected mount", %{conn: conn} do
        {:ok, _view, html} = live(conn, "/my-path")
        assert html =~ "<h1>My Connected View</h1>"
      end

  ## Testing Events

  The browser can send a variety of events to a live view via `phx-` bindings,
  which are sent to the `handle_event/3` callback. To test events sent by the
  browser and assert on the rendered side effect of the event, use the
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

      assert child = find_child(parent, "child-dom-id")
      send(parent.pid, :msg_that_removes_child)

      assert_remove child, _
      refute render(parent) =~ "some content in child"

  ## Testing components

  There are two main mechanisms for testing components. To test stateless
  components or just a regular rendering of a component, one can use
  `render_component/2`:

      assert render_component(MyComponent, id: 123, user: %User{}) =~
               "some markup in component"

  If you want to test how components are mounted by a LiveView and
  interact with DOM events, you can use the regular `live/2` macro
  to build the LiveView with the component and then scope events by
  passing the view and the component **DOM ID** in a list:

      {:ok, view, html} = live(conn, "/users")
      html = render_click([view, "user-13"], "delete", %{})
      refute html =~ "user-13"
      assert_remove_component(view, "user-13")

  """

  require Phoenix.ConnTest

  alias Phoenix.LiveView.{Diff, Socket}
  alias Phoenix.LiveViewTest.{View, ClientProxy, DOM}

  @doc """
  Spawns a connected LiveView process.

  Accepts either a previously rendered `%Plug.Conn{}` or
  an unsent `%Plug.Conn{}`. The latter case is a convenience
  to perform the `get/2` and connected mount in a single
  step.

  ## Options

    * `:connect_params` - the map of params available in the socket-connected
      mount. See `Phoenix.LiveView.get_connect_params/1` for more information.

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
          unquote(__MODULE__).__live__(conn, opts)

        path when is_binary(path) ->
          unquote(__MODULE__).__live__(get(conn, path), path, [])
      end
    end
  end

  @doc "See `live/2`."
  defmacro live(conn, path, opts) do
    quote bind_quoted: binding(), unquote: true do
      unquote(__MODULE__).__live__(get(conn, path), path, opts)
    end
  end

  @doc """
  Spawns a connected LiveView process mounted in isolation as the sole rendered element.

  Useful for testing LiveViews that are not directly routable, such as those
  built as small components to be re-used in multiple parents. Testing routable
  LiveViews is still recommended whenever possible since features such as
  live navigation require routable LiveViews.

  ## Options

    * `:connect_params` - the map of params available in connected mount.
      See `Phoenix.LiveView.get_connect_params/1` for more information.
    * `:session` - the session to be given to the LiveView

  All other options are forwarded to the live view for rendering. Refer to
  `Phoenix.LiveView.Helpers.live_render/3` for a list of supported render
  options.

  ## Examples

      {:ok, view, html} =
        live_isolated(conn, AppWeb.ClockLive, session: %{"tz" => "EST"})
  """
  defmacro live_isolated(conn, live_view, opts \\ []) do
    quote bind_quoted: binding(), unquote: true do
      unquote(__MODULE__).__isolated__(conn, @endpoint, live_view, opts)
    end
  end

  @doc false
  def __isolated__(conn, endpoint, live_view, opts) do
    {mount_opts, lv_opts} = Keyword.split(opts, [:connect_params])

    put_in(conn.private[:phoenix_endpoint], endpoint || raise("no @endpoint set in test case"))
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.LiveView.Router.fetch_live_flash([])
    |> Phoenix.LiveView.Controller.live_render(live_view, lv_opts)
    |> connect_from_static_token(nil, mount_opts)
  end

  @doc false
  def __live__(%Plug.Conn{state: state, status: status} = conn, opts) do
    path = rebuild_path(conn)

    case {state, status} do
      {:sent, 200} ->
        connect_from_static_token(conn, path, opts)

      {:sent, 302} ->
        {:error, %{redirect: %{to: hd(Plug.Conn.get_resp_header(conn, "location"))}}}

      {_, _} ->
        raise ArgumentError, """
        a request has not yet been sent.

        live/1 must use a connection with a sent response. Either call get/2
        prior to live/1, or use live/2 while providing a path to have a get
        request issued for you. For example issuing a get yourself:

            {:ok, view, _html} =
              conn
              |> get("#{path}")
              |> live()

        or performing the GET and live connect in a single step:

            {:ok, view, _html} = live(conn, "#{path}")
        """
    end
  end

  def __live__(conn, path, opts) do
    connect_from_static_token(conn, path, opts)
  end

  defp connect_from_static_token(%Plug.Conn{status: redir} = conn, _path, _opts)
       when redir in [301, 302] do
    {:error, %{redirect: %{to: hd(Plug.Conn.get_resp_header(conn, "location"))}}}
  end

  defp connect_from_static_token(%Plug.Conn{status: 200} = conn, path, opts) do
    html =
      conn
      |> Phoenix.ConnTest.html_response(200)
      |> IO.iodata_to_binary()
      |> DOM.parse()

    unless Code.ensure_loaded?(Floki) do
      raise """
      Phoenix LiveView requires Floki as a test dependency.
      Please add to your mix.exs:

      {:floki, ">= 0.0.0", only: :test}
      """
    end

    case DOM.find_live_views(html) do
      [{id, session_token, static_token} | _] ->
        do_connect(conn, path, html, session_token, static_token, id, opts)

      [] ->
        {:error, :nosession}
    end
  end

  defp do_connect(%Plug.Conn{} = conn, path, html, session_token, static_token, id, opts) do
    child_statics = Map.delete(DOM.find_static_views(html), id)
    timeout = opts[:timeout] || 5000
    endpoint = Phoenix.Controller.endpoint_module(conn)

    %ClientProxy{ref: ref} =
      view =
      ClientProxy.build(
        id: id,
        connect_params: opts[:connect_params] || %{},
        session_token: session_token,
        static_token: static_token,
        module: conn.assigns.live_module,
        endpoint: endpoint,
        child_statics: child_statics
      )

    opts = [
      caller: {self(), ref},
      html: html,
      view: view,
      timeout: timeout,
      session: Plug.Conn.get_session(conn),
      url: mount_url(endpoint, path)
    ]

    case ClientProxy.start_link(opts) do
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
                {:ok, build_test_view(view, view_pid, proxy_pid), html}
            end
        end

      {:error, reason} ->
        {:error, reason}

      :ignore ->
        receive do
          {^ref, {%_{} = exception, [_ | _] = stack}} -> reraise(exception, stack)
          {^ref, reason} -> {:error, reason}
        end
    end
  end

  defp mount_url(_endpoint, nil), do: nil
  defp mount_url(endpoint, "/"), do: endpoint.url()
  defp mount_url(endpoint, path), do: Path.join(endpoint.url(), path)

  defp build_test_view(%ClientProxy{id: id, ref: ref} = view, view_pid, proxy_pid) do
    %View{id: id, pid: view_pid, proxy: {ref, view.topic, proxy_pid}, module: view.module}
  end

  defp rebuild_path(%Plug.Conn{request_path: request_path, query_string: ""}),
    do: request_path

  defp rebuild_path(%Plug.Conn{request_path: request_path, query_string: query_string}),
    do: request_path <> "?" <> query_string

  @doc """
  Mounts, updates and renders a component.

  ## Examples

      assert render_component(MyComponent, id: 123, user: %User{}) =~
               "some markup in component"

  """
  defmacro render_component(component, assigns) do
    endpoint =
      Module.get_attribute(__CALLER__.module, :endpoint) ||
        raise ArgumentError,
              "the module attribute @endpoint is not set for #{inspect(__MODULE__)}"

    quote do
      Phoenix.LiveViewTest.__render_component__(
        unquote(endpoint),
        unquote(component),
        unquote(assigns)
      )
    end
  end

  @doc false
  def __render_component__(endpoint, component, assigns) do
    socket = %Socket{endpoint: endpoint}
    rendered = Diff.component_to_rendered(socket, component, Map.new(assigns))
    {_, diff, _} = Diff.render(socket, rendered, Diff.new_components())
    diff |> Diff.to_iodata() |> IO.iodata_to_binary()
  end

  @doc """
  Sends a click event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temperature is: 30℉"
      assert render_click(view, :inc) =~ "The temperature is: 31℉"
      assert render_click([view, "clock"], :set, %{time: "1:00"}) =~ "time: 1:00 PM"
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
      assert render_keyup([view, "child-id"], :inc, :ArrowDown) =~ "The temp is: 31℉"
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
      assert render_keyup([view, "child-id"], :inc, :ArrowDown) =~ "The temp is: 31℉"
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
      assert render_blur([view, "child-id"], :inactive) =~ "Tap to wake"
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
      assert render_focus([view, "child-id"], :active) =~ "Waking up..."
  """
  def render_focus(view, event, value \\ %{}) do
    render_event(view, :focus, event, value)
  end

  @doc """
  Sends a hook event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_hook(view, :refresh, %{deg: 32}) =~ "The temp is: 32℉"
  """
  def render_hook(view, event, value \\ %{}) do
    render_event(view, :hook, event, value)
  end

  defp render_event([%View{} = view | path], type, event, value) do
    case GenServer.call(
           proxy_pid(view),
           {:render_event, proxy_topic(view), type, path, event, stringify(value)}
         ) do
      {:ok, html} -> html
      {:error, reason} -> {:error, reason}
    end
  end

  defp render_event(%View{} = view, type, event, value) do
    render_event([view], type, event, value)
  end

  @doc """
  Simulates a `live_patch` to the given `path` and returns the rendered result.
  """
  def render_patch(view, path) do
    case GenServer.call(proxy_pid(view), {:render_patch, proxy_topic(view), path}) do
      {:ok, html} -> html
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the current list of children of the parent live view.

  Children are returned in the order they appear in the rendered HTML.

  ## Examples

      {:ok, view, _html} = live(conn, "/thermo")
      assert [clock_view] = children(view)
      assert render_click(clock_view, :snooze) =~ "snoozing"
  """
  def children(%View{} = parent) do
    parent
    |> proxy_pid()
    |> GenServer.call({:children, proxy_topic(parent)})
    |> Enum.map(fn %ClientProxy{} = proxy_view ->
      build_test_view(proxy_view, proxy_view.pid, proxy_view.proxy)
    end)
  end

  @doc """
  Finds the nested LiveView child given a parent.

  ## Examples

      {:ok, view, _html} = live(conn, "/thermo")
      assert clock_view = find_child(view, "clock")
      assert render_click(clock_view, :snooze) =~ "snoozing"
  """
  def find_child(%View{} = parent, child_id) do
    parent
    |> children()
    |> Enum.find(fn %View{id: id} -> id == child_id end)
  end

  @doc """
  Returns the string of HTML of the rendered view or component.

  If a view is provided, the entire LiveView is rendered. A list
  may be passed containing view and the component **DOM ID's**:

  ## Examples

      {:ok, view, _html} = live(conn, "/thermo")
      assert render(view) =~ "cooling"
      assert render([view, "clock"]) =~ "12:00 PM"
      assert render([view, "clock", "alarm"]) =~ "Snooze"
  """
  def render(%View{} = view), do: render([view])

  def render([%View{} = view | path]) do
    {:ok, html} = GenServer.call(proxy_pid(view), {:render_tree, proxy_topic(view), path})
    html
  end

  def render(other) do
    raise ArgumentError,
          "expected to render a %View{} or view ID selector. Got: #{inspect(other)}"
  end

  @doc """
  Asserts a redirect was performed.

  ## Examples

      render_click(view, :event_that_triggers_redirect)
      assert_redirect view, "/path"

  """
  defmacro assert_redirect(view, to) do
    quote do
      %View{proxy: {ref, topic, _proxy_pid}} = unquote(view)
      assert_receive {^ref, {:redirect, ^topic, %{to: unquote(to)} = opts}}
    end
  end

  @doc """
  Asserts a redirect was performed flash.

  *Note*: the flash will contain string keys.

  ## Examples

      assert_redirect view, "/path", %{"info" => "it worked!"}

  """
  defmacro assert_redirect(view, to, flash) do
    quote do
      %View{proxy: {ref, topic, _proxy_pid}} = unquote(view)
      assert_receive {^ref, {:redirect, ^topic, %{to: unquote(to)} = opts}}
      assert unquote(flash) = Phoenix.LiveView.Utils.verify_flash(@endpoint, opts[:flash])
    end
  end

  @doc """
  Asserts a view was removed by a parent or shutdown itself.

  ## Examples

      [child1, child2] = children(parent_view)
      send(parent_view.pid, :msg_that_removes_children)

      assert_remove child1, _
      assert_remove child2, {:shutdown, :removed}
  """
  defmacro assert_remove(view, reason, timeout \\ 100) do
    quote do
      %View{proxy: {ref, topic, _proxy_pid}} = unquote(view)
      assert_receive {^ref, {:removed, ^topic, unquote(reason)}}, unquote(timeout)
    end
  end

  @doc false
  defmacro assert_remove_component(view, id, timeout \\ 100) do
    quote bind_quoted: binding() do
      %View{proxy: {ref, topic, _proxy_pid}} = view
      assert_receive {^ref, {:removed_component, ^topic, ^id}}, timeout
    end
  end

  @doc """
  Stops a LiveView process.

  ## Examples

      stop(view)
      assert_remove view, {:shutdown, :stop}
  """
  def stop(%View{} = view) do
    GenServer.call(proxy_pid(view), {:stop, proxy_topic(view)})
  end

  defp ensure_down!(pid, timeout \\ 100) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> {:ok, reason}
    after
      timeout -> {:error, :timeout}
    end
  end

  defp stringify(%{__struct__: _} = struct),
    do: struct

  defp stringify(%{} = params),
    do: Enum.into(params, %{}, &stringify_kv/1)

  defp stringify(other),
    do: other

  defp stringify_kv({k, v}),
    do: {to_string(k), stringify(v)}

  defp proxy_pid(%View{proxy: {_ref, _topic, pid}}), do: pid
  defp proxy_topic(%View{proxy: {_ref, topic, _pid}}), do: topic
end

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

    * `render_focus/3` - sends a phx-focus event and value and
      returns the rendered result of the `handle_event/3` callback.

    * `render_blur/3` - sends a phx-focus event and value and
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
      reason = assert_remove view
      assert {:shutdown, %RuntimeError{}} = reason

      stop(view)
      reason = assert_remove view
      assert {:shutdown, :stop} = reason

  Nested views can be removed by a parent at any time based on conditional
  rendering. In these cases, the removal of the view is detected by the
  browser, or our test client, and the child is shutdown gracefully. This
  can be tested in the same way as above:

      assert render(parent) =~ "some content in child"

      assert child = find_live_child(parent, "child-dom-id")
      send(parent.pid, :msg_that_removes_child)

      assert_remove child
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
  passing the view and a **DOM selector** in a list:

      {:ok, view, html} = live(conn, "/users")
      html = view |> element("#user-13 a", "Delete") |> render_click()
      refute html =~ "user-13"
      refute view |> element("#user-13") |> has_element?()

  In the example above, LiveView will lookup for an element with
  ID=user-13 and retrieve its `phx-target`. If `phx-target` points
  to a component, that will be the component used, otherwise it will
  fallback to the view.
  """

  require Phoenix.ConnTest

  alias Phoenix.LiveView.{Diff, Socket}
  alias Phoenix.LiveViewTest.{ClientProxy, DOM, Element, View}

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
    quote bind_quoted: binding(), generated: true do
      case path_or_opts do
        opts when is_list(opts) ->
          Phoenix.LiveViewTest.__live__(conn, opts)

        path when is_binary(path) ->
          Phoenix.LiveViewTest.__live__(get(conn, path), path, [])
      end
    end
  end

  @doc "See `live/2`."
  defmacro live(conn, path, opts) do
    quote bind_quoted: binding() do
      Phoenix.LiveViewTest.__live__(get(conn, path), path, opts)
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
    DOM.ensure_loaded!()

    html =
      conn
      |> Phoenix.ConnTest.html_response(200)
      |> IO.iodata_to_binary()
      |> DOM.parse()

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
      proxy =
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
      proxy: proxy,
      timeout: timeout,
      session: Plug.Conn.get_session(conn),
      url: mount_url(endpoint, path)
    ]

    case ClientProxy.start_link(opts) do
      {:ok, _} ->
        receive do
          {^ref, {:ok, view, html}} -> {:ok, view, html}
        end

      {:error, reason} ->
        {:error, reason}

      :ignore ->
        receive do
          {^ref, {:error, {%_{} = exception, [_ | _] = stack}}} -> reraise(exception, stack)
          {^ref, {:error, reason}} -> {:error, reason}
        end
    end
  end

  defp mount_url(_endpoint, nil), do: nil
  defp mount_url(endpoint, "/"), do: endpoint.url()
  defp mount_url(endpoint, path), do: Path.join(endpoint.url(), path)

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
  Sends a click event given by `element` and returns the rendered result.

  The `element` is created with `element/3` and must point to a single
  element on the page with a `phx-click` attribute in it. The event name
  given set on `phx-click` is then sent to the appropriate live view
  (or component if `phx-target` is set accordingly). All `phx-value-*`
  entries in the element are sent as values. Extra values can be given
  with the `value` argument.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")

      assert view
             |> element("buttons", "Increment")
             |> render_click() =~ "The temperature is: 30℉"
  """
  def render_click(element, value \\ %{})
  def render_click(%Element{} = element, %{} = value), do: render_event(element, :click, value)
  def render_click(view, event), do: render_click(view, event, %{})

  @doc """
  Sends a click `event` to the `view` with `value` and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temperature is: 30℉"
      assert render_click(view, :inc) =~ "The temperature is: 31℉"

  """
  def render_click(view, event, value) do
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
    render_event(view, :form, event, value)
  end

  @doc """
  Sends a form change event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_change(view, :validate, %{deg: 123}) =~ "123 exceeds limits"
  """
  def render_change(view, event, value \\ %{}) do
    render_event(view, :form, event, value)
  end

  @doc """
  Sends a keyup event to the view and returns the rendered result.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_keyup(view, :inc, :ArrowUp) =~ "The temp is: 32℉"
      assert render_keyup([view, "#child-id"], :inc, :ArrowDown) =~ "The temp is: 31℉"
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
      assert render_keyup([view, "#child-id"], :inc, :ArrowDown) =~ "The temp is: 31℉"
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
      assert render_blur([view, "#child-id"], :inactive) =~ "Tap to wake"
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
      assert render_focus([view, "#child-id"], :active) =~ "Waking up..."
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
  def render_hook(view_or_element, event, value \\ %{})

  def render_hook(%Element{} = element, event, value) do
    render_event(%{element | event: to_string(event)}, :hook, value)
  end

  def render_hook(view, event, value) do
    render_event(view, :hook, event, value)
  end

  defp render_event(%Element{} = element, type, value) when is_map(value) do
    call(element, {:render_event, element, type, value})
  end

  defp render_event(%View{} = view, type, event, value) do
    call(view, {:render_event, {proxy_topic(view), to_string(event)}, type, value})
  end

  # TODO: Deprecate me
  defp render_event([%View{} = view | path], type, event, value) when is_map(value) do
    element = %{element(view, Enum.join(path, " ")) | event: to_string(event)}
    call(view, {:render_event, element, type, value})
  end

  @doc """
  Simulates a `live_patch` to the given `path` and returns the rendered result.
  """
  def render_patch(%View{} = view, path) when is_binary(path) do
    call(view, {:render_patch, proxy_topic(view), path})
  end

  @doc """
  Returns the current list of live view children for the `parent` LiveView.

  Children are returned in the order they appear in the rendered HTML.

  ## Examples

      {:ok, view, _html} = live(conn, "/thermo")
      assert [clock_view] = live_children(view)
      assert render_click(clock_view, :snooze) =~ "snoozing"
  """
  def live_children(%View{} = parent) do
    call(parent, {:live_children, proxy_topic(parent)})
  end

  @doc """
  Gets the nested LiveView child by `child_id` from the `parent` LiveView.

  ## Examples

      {:ok, view, _html} = live(conn, "/thermo")
      assert clock_view = find_live_child(view, "#clock")
      assert render_click(clock_view, :snooze) =~ "snoozing"
  """
  def find_live_child(%View{} = parent, child_id) do
    parent
    |> live_children()
    |> Enum.find(fn %View{id: id} -> id == child_id end)
  end

  @doc """
  Checks if the given element exists on the page.

  ## Examples

      assert view |> element("#some-element") |> has_element?()

  """
  def has_element?(%Element{} = element) do
    call(element, {:render, :has_element?, element})
  end

  @doc """
  Returns the string of HTML of the rendered view or component.

  If a view is provided, the entire LiveView is rendered. If an
  element is provided, only that element is rendered.

  ## Examples

      {:ok, view, _html} = live(conn, "/thermo")
      assert render(view) =~ "cooling"

      assert view
             |> element("#clock #alarm")
             |> render() =~ "Snooze"
  """
  def render(%View{} = view) do
    render(view, proxy_topic(view))
  end

  def render(%Element{} = element) do
    render(element, element)
  end

  def render([%View{} = view | path]) do
    IO.warn("invoking render/1 with a path is deprecated, pass a live_view or an element instead")
    render(view, element(view, Path.join(path, " ")))
  end

  defp render(view_or_element, topic_or_element) do
    call(view_or_element, {:render, :find_element, topic_or_element}) |> DOM.to_html()
  end

  defp call(view_or_element, tuple) do
    try do
      GenServer.call(proxy_pid(view_or_element), tuple, 30_000)
    catch
      :exit, {{:shutdown, {kind, opts}}, _} when kind in [:redirect, :live_redirect] ->
        {:error, {kind, opts}}
    else
      :ok -> :ok
      {:ok, result} -> result
      {:error, _} = err -> err
      {:raise, exception} -> raise exception
    end
  end

  @doc """
  Returns an element to scope a function to.

  It expects the current LiveView, a query selector, and a text filter.

  An optional text filter may be given to filter the results by the query
  selector. If the text filter is a string or a regex, it will match any
  element that contains the string or matches the regex. After the text
  filter is applied, only one element must remain, otherwise an error is
  raised.

  If no text filter is given, then the query selector itself must return
  a single element.

      assert view
            |> element("#term a:first-child()", "Increment")
            |> render() =~ "Increment</a>"

  """
  def element(%View{proxy: proxy}, selector, text_filter \\ nil) when is_binary(selector) do
    %Element{proxy: proxy, selector: selector, text_filter: text_filter}
  end

  @doc """
  Asserts a live patch will happen within `timeout`.

  It always returns `:ok`. To assert on the flash message,
  you can assert on the result of the rendered LiveView.

  ## Examples

      render_click(view, :event_that_triggers_patch)
      assert_patch view, "/path"

  """
  def assert_patch(%View{} = view, to, timeout \\ 100)
      when is_binary(to) and is_integer(timeout) do
    assert_navigation(view, :patch, to, timeout)
    :ok
  end

  @doc """
  Asserts a live patch was performed.

  It always returns `:ok`. To assert on the flash message,
  you can assert on the result of the rendered LiveView.

  ## Examples

      render_click(view, :event_that_triggers_redirect)
      assert_patched view, "/path"

  """
  def assert_patched(view, to) do
    assert_patch(view, to, 0)
  end

  @doc """
  Asserts a redirect will happen within `timeout`.

  It returns the flash messages from said redirect, if any.
  Note the flash will contain string keys.

  ## Examples

      render_click(view, :event_that_triggers_redirect)
      flash = assert_redirect view, "/path"
      assert flash["info"] == "Welcome"

  """
  def assert_redirect(%View{} = view, to, timeout \\ 100)
      when is_binary(to) and is_integer(timeout) do
    assert_navigation(view, :redirect, to, timeout)
  end

  @doc """
  Asserts a redirect was performed.

  It returns the flash messages from said redirect, if any.
  Note the flash will contain string keys.

  ## Examples

      render_click(view, :event_that_triggers_redirect)
      flash = assert_redirected view, "/path"
      assert flash["info"] == "Welcome"

  """
  def assert_redirected(view, to) do
    assert_redirect(view, to, 0)
  end

  defp assert_navigation(view, kind, to, timeout) do
    %{proxy: {ref, topic, _}, endpoint: endpoint} = view

    receive do
      {^ref, {^kind, ^topic, %{to: ^to} = opts}} ->
        Phoenix.LiveView.Utils.verify_flash(endpoint, opts[:flash])
    after
      timeout ->
        message = "expected #{inspect(view.module)} to #{kind} to #{inspect(to)}, "

        case flush_navigation(ref, topic, nil) do
          nil -> raise ArgumentError, message <> "but got none"
          {kind, to} -> raise ArgumentError, message <> "but got a #{kind} to #{inspect(to)}"
        end
    end
  end

  defp flush_navigation(ref, topic, last) do
    receive do
      {^ref, {kind, ^topic, %{to: to}}} when kind in [:patch, :redirect] ->
        flush_navigation(ref, topic, {kind, to})
    after
      0 -> last
    end
  end

  @doc """
  Follows the redirect from a `render_*` action.

  Imagine you have a LiveView that redirects on a `render_click`
  event. You can make it sure it immediately redirects after the
  `render_click` action by calling `follow_redirect/3`:

      live_view
      |> render_click("redirect")
      |> follow_redirect(conn)

  Note `follow_redirect/3` expects a connection as second argument.
  This is the connection that will be used to perform the underlying
  request.

  If the LiveView redirects with a live redirect, this macro returns
  `{:ok, live_view, disconnected_html}` with the content of the new
  live view, the same as the `live/3` macro. If the LiveView redirects
  with a regular redirect, this macro returns `{:ok, conn}` with the
  rendered redirected page. In any other case, this macro raises.

  Finally, note that you can optionally assert on the path you are
  being redirected to by passing a third argument:

      live_view
      |> render_click("redirect")
      |> follow_redirect(conn, "/redirected/page")

  """
  defmacro follow_redirect(reason, conn, to \\ nil) do
    quote bind_quoted: binding() do
      case reason do
        {:error, {:live_redirect, opts}} ->
          {conn, to} = Phoenix.LiveViewTest.__follow_redirect__(conn, to, opts)
          live(conn, to)

        {:error, {:redirect, opts}} ->
          {conn, to} = Phoenix.LiveViewTest.__follow_redirect__(conn, to, opts)
          {:ok, get(conn, to)}

        _ ->
          raise "LiveView did not redirect"
      end
    end
  end

  @doc false
  def __follow_redirect__(conn, expected_to, %{to: to} = opts) do
    if expected_to && expected_to != to do
      raise ArgumentError,
            "expected LiveView to redirect to #{inspect(expected_to)}, but got #{inspect(to)}"
    end

    conn = Phoenix.ConnTest.ensure_recycled(conn)

    if flash = opts[:flash] do
      {Phoenix.ConnTest.put_req_cookie(conn, "__phoenix_flash__", flash), to}
    else
      {conn, to}
    end
  end

  defp proxy_pid(%{proxy: {_ref, _topic, pid}}), do: pid
  defp proxy_topic(%{proxy: {_ref, topic, _pid}}), do: topic
end

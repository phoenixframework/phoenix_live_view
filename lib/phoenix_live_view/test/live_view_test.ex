defmodule Phoenix.LiveViewTest do
  @moduledoc ~S'''
  Conveniences for testing Phoenix LiveViews.

  In LiveView tests, we interact with views via process
  communication in substitution of a browser. Like a browser,
  our test process receives messages about the rendered updates
  from the view which can be asserted against to test the
  life-cycle and behavior of LiveViews and their children.

  ## LiveView Testing

  The life-cycle of a LiveView as outlined in the `Phoenix.LiveView`
  docs details how a view starts as a stateless HTML render in a disconnected
  socket state. Once the browser receives the HTML, it connects to the
  server and a new LiveView process is started, remounted in a connected
  socket state, and the view continues statefully. The LiveView test functions
  support testing both disconnected and connected mounts separately, for example:

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      @endpoint MyEndpoint

      test "disconnected and connected mount", %{conn: conn} do
        conn = get(conn, "/my-path")
        assert html_response(conn, 200) =~ "<h1>My Disconnected View</h1>"

        {:ok, view, html} = live(conn)
      end

      test "redirected mount", %{conn: conn} do
        assert {:error, {:redirect, %{to: "/somewhere"}}} = live(conn, "my-path")
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

  ### Testing Events

  The browser can send a variety of events to a LiveView via `phx-` bindings,
  which are sent to the `handle_event/3` callback. To test events sent by the
  browser and assert on the rendered side effect of the event, use the
  `render_*` functions:

    * `render_click/1` - sends a phx-click event and value, returning
      the rendered result of the `handle_event/3` callback.

    * `render_focus/2` - sends a phx-focus event and value, returning
      the rendered result of the `handle_event/3` callback.

    * `render_blur/1` - sends a phx-blur event and value, returning
      the rendered result of the `handle_event/3` callback.

    * `render_submit/1` - sends a form phx-submit event and value, returning
      the rendered result of the `handle_event/3` callback.

    * `render_change/1` - sends a form phx-change event and value, returning
      the rendered result of the `handle_event/3` callback.

    * `render_keydown/1` - sends a form phx-keydown event and value, returning
      the rendered result of the `handle_event/3` callback.

    * `render_keyup/1` - sends a form phx-keyup event and value, returning
      the rendered result of the `handle_event/3` callback.

    * `render_hook/3` - sends a hook event and value, returning
      the rendered result of the `handle_event/3` callback.

  For example:

      {:ok, view, _html} = live(conn, "/thermo")

      assert view
             |> element("button#inc")
             |> render_click() =~ "The temperature is: 31℉"

  In the example above, we are looking for a particular element on the page
  and triggering its phx-click event. LiveView takes care of making sure the
  element has a phx-click and automatically sends its values to the server.

  You can also bypass the element lookup and directly trigger the LiveView
  event in most functions:

      assert render_click(view, :inc, %{}) =~ "The temperature is: 31℉"

  The `element` style is preferred as much as possible, as it helps LiveView
  perform validations and ensure the events in the HTML actually matches the
  event names on the server.

  ### Testing regular messages

  LiveViews are `GenServer`'s under the hood, and can send and receive messages
  just like any other server. To test the side effects of sending or receiving
  messages, simply message the view and use the `render` function to test the
  result:

      send(view.pid, {:set_temp, 50})
      assert render(view) =~ "The temperature is: 50℉"

  ## Testing function components

  There are two mechanisms for testing function components. Imagine the
  following component:

      def greet(assigns) do
        ~H"""
        <div>Hello, <%= @name %>!</div>
        """
      end

  You can test it by using `render_component/3`, passing the function
  reference to the component as first argument:

      import Phoenix.LiveViewTest

      test "greets" do
        assert render_component(&MyComponents.greet/1, name: "Mary") ==
                 "<div>Hello, Mary!</div>"
      end

  However, for complex components, often the simplest way to test them
  is by using the `~H` sigil itself:

      import Phoenix.LiveView.Helpers
      import Phoenix.LiveViewTest

      test "greets" do
        assert rendered_to_string(~H"""
               <MyComponents.greet name="Mary" />
               """) ==
                 "<div>Hello, Mary!</div>"
      end

  The difference is that we use `rendered_to_string` to convert the rendered
  template to a string for testing.

  ## Testing stateful components

  There are two main mechanisms for testing stateful components. You can
  use `render_component/2` to test how a component is mounted and rendered
  once:

      assert render_component(MyComponent, id: 123, user: %User{}) =~
               "some markup in component"

  However, if you want to test how components are mounted by a LiveView
  and interact with DOM events, you must use the regular `live/2` macro
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
  '''

  @flash_cookie "__phoenix_flash__"

  require Phoenix.ConnTest
  require Phoenix.ChannelTest

  alias Phoenix.LiveView.{Diff, Socket}
  alias Phoenix.LiveViewTest.{ClientProxy, DOM, Element, View, Upload, UploadClient}

  @doc """
  Puts connect params to be used on LiveView connections.

  See `Phoenix.LiveView.get_connect_params/1`.
  """
  def put_connect_params(conn, params) when is_map(params) do
    Plug.Conn.put_private(conn, :live_view_connect_params, params)
  end

  @doc """
  Puts connect info to be used on LiveView connections.

  See `Phoenix.LiveView.get_connect_info/1`.
  """
  def put_connect_info(conn, params) when is_map(params) do
    Plug.Conn.put_private(conn, :live_view_connect_info, params)
  end

  @doc """
  Spawns a connected LiveView process.

  If a `path` is given, then a regular `get(conn, path)`
  is done and the page is upgraded to a `LiveView`. If
  no path is given, it assumes a previously rendered
  `%Plug.Conn{}` is given, which will be converted to
  a `LiveView` immediately.

  ## Examples

      {:ok, view, html} = live(conn, "/path")
      assert view.module = MyLive
      assert html =~ "the count is 3"

      assert {:error, {:redirect, %{to: "/somewhere"}}} = live(conn, "/path")

  """
  defmacro live(conn, path \\ nil) do
    quote bind_quoted: binding(), generated: true do
      cond do
        is_binary(path) ->
          Phoenix.LiveViewTest.__live__(get(conn, path), path)

        is_nil(path) ->
          Phoenix.LiveViewTest.__live__(conn)

        true ->
          raise RuntimeError, "path must be nil or a binary, got: #{inspect(path)}"
      end
    end
  end

  @doc """
  Spawns a connected LiveView process mounted in isolation as the sole rendered element.

  Useful for testing LiveViews that are not directly routable, such as those
  built as small components to be re-used in multiple parents. Testing routable
  LiveViews is still recommended whenever possible since features such as
  live navigation require routable LiveViews.

  ## Options

    * `:session` - the session to be given to the LiveView

  All other options are forwarded to the LiveView for rendering. Refer to
  `Phoenix.LiveView.Helpers.live_render/3` for a list of supported render
  options.

  ## Examples

      {:ok, view, html} =
        live_isolated(conn, MyAppWeb.ClockLive, session: %{"tz" => "EST"})

  Use `put_connect_params/2` to put connect params for a call to
  `Phoenix.LiveView.get_connect_params/1` in `c:Phoenix.LiveView.mount/3`:

      {:ok, view, html} =
        conn
        |> put_connect_params(%{"param" => "value"})
        |> live_isolated(AppWeb.ClockLive, session: %{"tz" => "EST"})


  """
  defmacro live_isolated(conn, live_view, opts \\ []) do
    endpoint = Module.get_attribute(__CALLER__.module, :endpoint)

    quote bind_quoted: binding(), unquote: true do
      unquote(__MODULE__).__isolated__(conn, endpoint, live_view, opts)
    end
  end

  @doc false
  def __isolated__(conn, endpoint, live_view, opts) do
    put_in(conn.private[:phoenix_endpoint], endpoint || raise("no @endpoint set in test module"))
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.LiveView.Router.fetch_live_flash([])
    |> Phoenix.LiveView.Controller.live_render(live_view, opts)
    |> connect_from_static_token(nil)
  end

  @doc false
  def __live__(%Plug.Conn{state: state, status: status} = conn) do
    path = rebuild_path(conn)

    case {state, status} do
      {:sent, 200} ->
        connect_from_static_token(conn, path)

      {:sent, 302} ->
        error_redirect_conn(conn)

      {:sent, _} ->
        raise ArgumentError,
              "request to #{conn.request_path} received unexpected #{status} response"

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

  @doc false
  def __live__(conn, path) do
    connect_from_static_token(conn, path)
  end

  defp connect_from_static_token(
         %Plug.Conn{status: 200, assigns: %{live_module: live_module}} = conn,
         path
       ) do
    DOM.ensure_loaded!()

    router =
      try do
        Phoenix.Controller.router_module(conn)
      rescue
        KeyError -> nil
      end

    start_proxy(path, %{
      html: Phoenix.ConnTest.html_response(conn, 200),
      connect_params: conn.private[:live_view_connect_params] || %{},
      connect_info: conn.private[:live_view_connect_info] || %{},
      live_module: live_module,
      router: router,
      endpoint: Phoenix.Controller.endpoint_module(conn),
      session: maybe_get_session(conn),
      url: Plug.Conn.request_url(conn)
    })
  end

  defp connect_from_static_token(%Plug.Conn{status: 200}, _path) do
    {:error, :nosession}
  end

  defp connect_from_static_token(%Plug.Conn{status: redir} = conn, _path)
       when redir in [301, 302] do
    error_redirect_conn(conn)
  end

  defp error_redirect_conn(conn) do
    to = hd(Plug.Conn.get_resp_header(conn, "location"))

    opts =
      if flash = conn.private[:phoenix_flash] do
        endpoint = Phoenix.Controller.endpoint_module(conn)
        %{to: to, flash: Phoenix.LiveView.Utils.sign_flash(endpoint, flash)}
      else
        %{to: to}
      end

    {:error, {error_redirect_key(conn), opts}}
  end

  defp error_redirect_key(%{private: %{phoenix_live_redirect: true}}), do: :live_redirect
  defp error_redirect_key(_), do: :redirect

  defp start_proxy(path, %{} = opts) do
    ref = make_ref()

    opts =
      Map.merge(opts, %{
        caller: {self(), ref},
        html: opts.html,
        connect_params: opts.connect_params,
        connect_info: opts.connect_info,
        live_module: opts.live_module,
        endpoint: opts.endpoint,
        session: opts.session,
        url: opts.url,
        test_supervisor: fetch_test_supervisor!()
      })

    case ClientProxy.start_link(opts) do
      {:ok, _} ->
        receive do
          {^ref, {:ok, view, html}} -> {:ok, view, html}
        end

      {:error, reason} ->
        exit({reason, {__MODULE__, :live, [path]}})

      :ignore ->
        receive do
          {^ref, {:error, reason}} -> {:error, reason}
        end
    end
  end

  # TODO: replace with ExUnit.Case.fetch_test_supervisor!() when we require Elixir v1.11.
  defp fetch_test_supervisor!() do
    case ExUnit.OnExitHandler.get_supervisor(self()) do
      {:ok, nil} ->
        opts = [strategy: :one_for_one, max_restarts: 1_000_000, max_seconds: 1]
        {:ok, sup} = Supervisor.start_link([], opts)
        ExUnit.OnExitHandler.put_supervisor(self(), sup)
        sup

      {:ok, sup} ->
        sup

      :error ->
        raise ArgumentError, "fetch_test_supervisor!/0 can only be invoked from the test process"
    end
  end

  defp maybe_get_session(%Plug.Conn{} = conn) do
    try do
      Plug.Conn.get_session(conn)
    rescue
      _ -> %{}
    end
  end

  defp rebuild_path(%Plug.Conn{request_path: request_path, query_string: ""}),
    do: request_path

  defp rebuild_path(%Plug.Conn{request_path: request_path, query_string: query_string}),
    do: request_path <> "?" <> query_string

  @doc """
  Renders a component.

  The first argument may either be a function component, as an
  anonymous function:

      assert render_component(&Weather.city/1, name: "Kraków") =~
               "some markup in component"

  Or a stateful component as a module. In this case, this function
  will mount, update, and render the component. The `:id` option is
  a required argument:

      assert render_component(MyComponent, id: 123, user: %User{}) =~
               "some markup in component"

  If your component is using the router, you can pass it as argument:

      assert render_component(MyComponent, %{id: 123, user: %User{}}, router: SomeRouter) =~
               "some markup in component"

  """
  defmacro render_component(component, assigns, opts \\ []) do
    endpoint = Module.get_attribute(__CALLER__.module, :endpoint)

    quote do
      component = unquote(component)

      Phoenix.LiveViewTest.__render_component__(
        unquote(endpoint),
        if(is_atom(component), do: component.__live__(), else: component),
        unquote(assigns),
        unquote(opts)
      )
    end
  end

  @doc false
  def __render_component__(endpoint, %{module: component}, assigns, opts) do
    socket = %Socket{endpoint: endpoint, router: opts[:router]}
    assigns = Map.new(assigns)

    # TODO: Make the ID required once we support only stateful module components as live_component
    mount_assigns = if assigns[:id], do: %{myself: %Phoenix.LiveComponent.CID{cid: -1}}, else: %{}

    socket
    |> Diff.component_to_rendered(component, assigns, mount_assigns)
    |> rendered_to_diff_string(socket)
  end

  def __render_component__(endpoint, function, assigns, opts) when is_function(function, 1) do
    socket = %Socket{endpoint: endpoint, router: opts[:router]}

    assigns
    |> Map.new()
    |> function.()
    |> rendered_to_diff_string(socket)
  end

  defp rendered_to_diff_string(rendered, socket) do
    {_, diff, _} = Diff.render(socket, rendered, Diff.new_components())
    diff |> Diff.to_iodata() |> IO.iodata_to_binary()
  end

  @doc ~S'''
  Converts a rendered template to a string.

  ## Examples

      iex> ~H"""
      ...> <div>example</div>
      ...> """
      ...> |> rendered_string()
      "<div>example</div>"

  '''
  def rendered_to_string(rendered) do
    rendered
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  @doc """
  Sends a click event given by `element` and returns the rendered result.

  The `element` is created with `element/3` and must point to a single
  element on the page with a `phx-click` attribute in it. The event name
  given set on `phx-click` is then sent to the appropriate LiveView
  (or component if `phx-target` is set accordingly). All `phx-value-*`
  entries in the element are sent as values. Extra values can be given
  with the `value` argument.

  If the element is does not have a `phx-click` attribute but it is
  a link (the `<a>` tag), the link will be followed accordingly:

    * if the link is a `live_patch`, the current view will be patched
    * if the link is a `live_redirect`, this function will return
      `{:error, {:live_redirect, %{to: url}}}`, which can be followed
      with `follow_redirect/2`
    * if the link is a regular link, this function will return
      `{:error, {:redirect, %{to: url}}}`, which can be followed
      with `follow_redirect/2`

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")

      assert view
             |> element("buttons", "Increment")
             |> render_click() =~ "The temperature is: 30℉"
  """
  def render_click(element, value \\ %{})
  def render_click(%Element{} = element, value), do: render_event(element, :click, value)
  def render_click(view, event), do: render_click(view, event, %{})

  @doc """
  Sends a click `event` to the `view` with `value` and returns the rendered result.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temperature is: 30℉"
      assert render_click(view, :inc) =~ "The temperature is: 31℉"

  """
  def render_click(view, event, value) do
    render_event(view, :click, event, value)
  end

  @doc """
  Sends a form submit event given by `element` and returns the rendered result.

  The `element` is created with `element/3` and must point to a single
  element on the page with a `phx-submit` attribute in it. The event name
  given set on `phx-submit` is then sent to the appropriate LiveView
  (or component if `phx-target` is set accordingly). All `phx-value-*`
  entries in the element are sent as values. Extra values, including hidden
  input fields, can be given with the `value` argument.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")

      assert view
             |> element("form")
             |> render_submit(%{deg: 123, avatar: upload}) =~ "123 exceeds limits"

  To submit a form along with some with hidden input values:

      assert view
            |> form("#term", user: %{name: "hello"})
            |> render_submit(%{user: %{"hidden_field" => "example"}}) =~ "Name updated"

  """
  def render_submit(element, value \\ %{})
  def render_submit(%Element{} = element, value), do: render_event(element, :submit, value)
  def render_submit(view, event), do: render_submit(view, event, %{})

  @doc """
  Sends a form submit event to the view and returns the rendered result.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_submit(view, :refresh, %{deg: 32}) =~ "The temp is: 32℉"
  """
  def render_submit(view, event, value) do
    render_event(view, :submit, event, value)
  end

  @doc """
  Sends a form change event given by `element` and returns the rendered result.

  The `element` is created with `element/3` and must point to a single
  element on the page with a `phx-change` attribute in it. The event name
  given set on `phx-change` is then sent to the appropriate LiveView
  (or component if `phx-target` is set accordingly). All `phx-value-*`
  entries in the element are sent as values.

  If you need to pass any extra values or metadata, such as the "_target"
  parameter, you can do so by giving a map under the `value` argument.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")

      assert view
             |> element("form")
             |> render_change(%{deg: 123}) =~ "123 exceeds limits"

      # Passing metadata
      {:ok, view, html} = live(conn, "/thermo")

      assert view
             |> element("form")
             |> render_change(%{_target: ["deg"], deg: 123}) =~ "123 exceeds limits"

  As with `render_submit/2`, hidden input field values can be provided like so:

      refute view
            |> form("#term", user: %{name: "hello"})
            |> render_change(%{user: %{"hidden_field" => "example"}}) =~ "can't be blank"

  """
  def render_change(element, value \\ %{})
  def render_change(%Element{} = element, value), do: render_event(element, :change, value)
  def render_change(view, event), do: render_change(view, event, %{})

  @doc """
  Sends a form change event to the view and returns the rendered result.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_change(view, :validate, %{deg: 123}) =~ "123 exceeds limits"
  """
  def render_change(view, event, value) do
    render_event(view, :change, event, value)
  end

  @doc """
  Sends a keydown event given by `element` and returns the rendered result.

  The `element` is created with `element/3` and must point to a single element
  on the page with a `phx-keydown` or `phx-window-keydown` attribute in it.
  The event name given set on `phx-keydown` is then sent to the appropriate
  LiveView (or component if `phx-target` is set accordingly). All `phx-value-*`
  entries in the element are sent as values. Extra values can be given with
  the `value` argument.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert view |> element("#inc") |> render_keydown() =~ "The temp is: 31℉"

  """
  def render_keydown(element, value \\ %{})

  def render_keydown(%Element{} = element, value),
    do: render_event(element, :keydown, value)

  def render_keydown(view, event), do: render_keydown(view, event, %{})

  @doc """
  Sends a keydown event to the view and returns the rendered result.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_keydown(view, :inc) =~ "The temp is: 31℉"

  """
  def render_keydown(view, event, value) do
    render_event(view, :keydown, event, value)
  end

  @doc """
  Sends a keyup event given by `element` and returns the rendered result.

  The `element` is created with `element/3` and must point to a single
  element on the page with a `phx-keyup` or `phx-window-keyup` attribute
  in it. The event name given set on `phx-keyup` is then sent to the
  appropriate LiveView (or component if `phx-target` is set accordingly).
  All `phx-value-*` entries in the element are sent as values. Extra values
  can be given with the `value` argument.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert view |> element("#inc") |> render_keyup() =~ "The temp is: 31℉"

  """
  def render_keyup(element, value \\ %{})
  def render_keyup(%Element{} = element, value), do: render_event(element, :keyup, value)
  def render_keyup(view, event), do: render_keyup(view, event, %{})

  @doc """
  Sends a keyup event to the view and returns the rendered result.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_keyup(view, :inc) =~ "The temp is: 31℉"

  """
  def render_keyup(view, event, value) do
    render_event(view, :keyup, event, value)
  end

  @doc """
  Sends a blur event given by `element` and returns the rendered result.

  The `element` is created with `element/3` and must point to a single
  element on the page with a `phx-blur` attribute in it. The event name
  given set on `phx-blur` is then sent to the appropriate LiveView
  (or component if `phx-target` is set accordingly). All `phx-value-*`
  entries in the element are sent as values. Extra values can be given
  with the `value` argument.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")

      assert view
             |> element("#inactive")
             |> render_blur() =~ "Tap to wake"
  """
  def render_blur(element, value \\ %{})
  def render_blur(%Element{} = element, value), do: render_event(element, :blur, value)
  def render_blur(view, event), do: render_blur(view, event, %{})

  @doc """
  Sends a blur event to the view and returns the rendered result.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_blur(view, :inactive) =~ "Tap to wake"

  """
  def render_blur(view, event, value) do
    render_event(view, :blur, event, value)
  end

  @doc """
  Sends a focus event given by `element` and returns the rendered result.

  The `element` is created with `element/3` and must point to a single
  element on the page with a `phx-focus` attribute in it. The event name
  given set on `phx-focus` is then sent to the appropriate LiveView
  (or component if `phx-target` is set accordingly). All `phx-value-*`
  entries in the element are sent as values. Extra values can be given
  with the `value` argument.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")

      assert view
             |> element("#inactive")
             |> render_focus() =~ "Tap to wake"
  """
  def render_focus(element, value \\ %{})
  def render_focus(%Element{} = element, value), do: render_event(element, :focus, value)
  def render_focus(view, event), do: render_focus(view, event, %{})

  @doc """
  Sends a focus event to the view and returns the rendered result.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_focus(view, :inactive) =~ "Tap to wake"

  """
  def render_focus(view, event, value) do
    render_event(view, :focus, event, value)
  end

  @doc """
  Sends a hook event to the view or an element and returns the rendered result.

  It returns the contents of the whole LiveView or an `{:error, redirect}`
  tuple.

  ## Examples

      {:ok, view, html} = live(conn, "/thermo")
      assert html =~ "The temp is: 30℉"
      assert render_hook(view, :refresh, %{deg: 32}) =~ "The temp is: 32℉"

  If you are pushing events from a hook to a component, then you must pass
  an `element`, created with `element/3`, as first argument and it must point
  to a single element on the page with a `phx-target` attribute in it:

      {:ok, view, _html} = live(conn, "/thermo")
      assert view
             |> element("#thermo-component")
             |> render_hook(:refresh, %{deg: 32}) =~ "The temp is: 32℉"

  """
  def render_hook(view_or_element, event, value \\ %{})

  def render_hook(%Element{} = element, event, value) do
    render_event(%{element | event: to_string(event)}, :hook, value)
  end

  def render_hook(view, event, value) do
    render_event(view, :hook, event, value)
  end

  defp render_event(%Element{} = element, type, value) when is_map(value) or is_list(value) do
    call(element, {:render_event, element, type, value})
  end

  defp render_event(%View{} = view, type, event, value) when is_map(value) or is_list(value) do
    call(view, {:render_event, {proxy_topic(view), to_string(event), view.target}, type, value})
  end

  @doc """
  Simulates a `live_patch` to the given `path` and returns the rendered result.
  """
  def render_patch(%View{} = view, path) when is_binary(path) do
    call(view, {:render_patch, proxy_topic(view), path})
  end

  @doc """
  Returns the current list of LiveView children for the `parent` LiveView.

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
      assert clock_view = find_live_child(view, "clock")
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
    call(element, {:render_element, :has_element?, element})
  end

  @doc """
  Checks if the given `selector` with `text_filter` is on `view`.

  See `element/3` for more information.

  ## Examples

      assert has_element?(view, "#some-element")

  """
  def has_element?(%View{} = view, selector, text_filter \\ nil) do
    has_element?(element(view, selector, text_filter))
  end

  @doc """
  Returns the HTML string of the rendered view or element.

  If a view is provided, the entire LiveView is rendered.
  If a view after calling `with_target/2` or an element
  are given, only that particular context is returned.

  ## Examples

      {:ok, view, _html} = live(conn, "/thermo")
      assert render(view) =~ ~s|<button id="alarm">Snooze</div>|

      assert view
             |> element("#alarm")
             |> render() == "Snooze"
  """
  def render(view_or_element) do
    view_or_element
    |> render_tree()
    |> DOM.to_html()
  end

  @doc """
  Sets the target of the view for events.

  This emulates `phx-target` directly in tests, without
  having to dispatch the event to a specific element.
  This can be useful for invoking events to one or
  multiple components at the same time:

      view
      |> with_target("#user-1,#user-2")
      |> render_click("Hide", %{})

  """
  def with_target(%View{} = view, target) do
    %{view | target: target}
  end

  defp render_tree(%View{} = view) do
    render_tree(view, {proxy_topic(view), "render", view.target})
  end

  defp render_tree(%Element{} = element) do
    render_tree(element, element)
  end

  defp render_tree(view_or_element, topic_or_element) do
    call(view_or_element, {:render_element, :find_element, topic_or_element})
  end

  defp call(view_or_element, tuple) do
    try do
      GenServer.call(proxy_pid(view_or_element), tuple, 30_000)
    catch
      :exit, {{:shutdown, {kind, opts}}, _} when kind in [:redirect, :live_redirect] ->
        {:error, {kind, opts}}

      :exit, {{exception, stack}, _} ->
        exit({{exception, stack}, {__MODULE__, :call, [view_or_element]}})
    else
      :ok -> :ok
      {:ok, result} -> result
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

  Attribute selectors are also supported, and may be used on special cases
  like ids which contain periods:

      assert view
             |> element(~s{[href="/foo"][id="foo.bar.baz"]})
             |> render() =~ "Increment</a>"
  """
  def element(%View{proxy: proxy}, selector, text_filter \\ nil) when is_binary(selector) do
    %Element{proxy: proxy, selector: selector, text_filter: text_filter}
  end

  @doc """
  Returns a form element to scope a function to.

  It expects the current LiveView, a query selector, and the form data.
  The query selector must return a single element.

  The form data will be validated directly against the form markup and
  make sure the data you are changing/submitting actually exists, failing
  otherwise.

  ## Examples

      assert view
            |> form("#term", user: %{name: "hello"})
            |> render_submit() =~ "Name updated"

  This function is meant to mimic what the user can actually do, so you cannot
   set hidden input values. However, hidden values can be given when calling
   `render_submit/2` or `render_change/2`, see their docs for examples.
  """
  def form(%View{proxy: proxy}, selector, form_data \\ %{}) when is_binary(selector) do
    %Element{proxy: proxy, selector: selector, form_data: form_data}
  end

  @doc """
  Builds a file input for testing uploads within a form.

  Given the form DOM selector, the upload name, and a list of maps of client metadata
  for the upload, the returned file input can be passed to `render_upload/2`.

  Client metadata takes the following form:

    * `:last_modified` - the last modified timestamp
    * `:name` - the name of the file
    * `:content` - the binary content of the file
    * `:size` - the byte size of the content
    * `:type` - the MIME type of the file

  ## Examples

      avatar = file_input(lv, "#my-form-id", :avatar, [%{
        last_modified: 1_594_171_879_000,
        name: "myfile.jpeg",
        content: File.read!("myfile.jpg"),
        size: 1_396_009,
        type: "image/jpeg"
      }])

      assert render_upload(avatar, "myfile.jpeg") =~ "100%"
  """
  defmacro file_input(view, form_selector, name, entries) do
    quote bind_quoted: [view: view, selector: form_selector, name: name, entries: entries] do
      require Phoenix.ChannelTest
      builder = fn -> Phoenix.ChannelTest.connect(Phoenix.LiveView.Socket, %{}, %{}) end
      Phoenix.LiveViewTest.__file_input__(view, selector, name, entries, builder)
    end
  end

  @doc false
  def __file_input__(view, selector, name, entries, builder) do
    cid = find_cid!(view, selector)

    case Phoenix.LiveView.Channel.fetch_upload_config(view.pid, name, cid) do
      {:ok, %{external: false}} ->
        start_upload_client(builder, view, selector, name, entries, cid)

      {:ok, %{external: func}} when is_function(func) ->
        start_external_upload_client(view, selector, name, entries, cid)

      :error ->
        raise "no uploads allowed for #{name}"
    end
  end

  defp find_cid!(view, selector) do
    html_tree = view |> render() |> DOM.parse()

    with {:ok, form} <- DOM.maybe_one(html_tree, selector) do
      [cid | _] = DOM.targets_from_node(html_tree, form)
      cid
    else
      {:error, _reason, msg} -> raise ArgumentError, msg
    end
  end

  defp start_upload_client(socket_builder, view, form_selector, name, entries, cid) do
    spec = %{
      id: make_ref(),
      start: {UploadClient, :start_link, [[socket_builder: socket_builder, cid: cid]]},
      restart: :temporary
    }

    {:ok, pid} = Supervisor.start_child(fetch_test_supervisor!(), spec)
    Upload.new(pid, view, form_selector, name, entries, cid)
  end

  defp start_external_upload_client(view, form_selector, name, entries, cid) do
    spec = %{
      id: make_ref(),
      start: {UploadClient, :start_link, [[cid: cid]]},
      restart: :temporary
    }

    {:ok, pid} = Supervisor.start_child(fetch_test_supervisor!(), spec)
    Upload.new(pid, view, form_selector, name, entries, cid)
  end

  @doc """
  Returns the most recent title that was updated via a `page_title` assign.

  ## Examples

      render_click(view, :event_that_triggers_page_title_update)
      assert page_title(view) =~ "my title"

  """
  def page_title(view) do
    call(view, :page_title)
  end

  @doc """
  Asserts a live patch will happen within `timeout` milliseconds. The default
  `timeout` is 100.

  It returns the new path.

  To assert on the flash message, you can assert on the result of the
  rendered LiveView.

  ## Examples

      render_click(view, :event_that_triggers_patch)
      assert_patch view

      render_click(view, :event_that_triggers_patch)
      assert_patch view, 30

      render_click(view, :event_that_triggers_patch)
      path = assert_patch view
      assert path =~ ~r/path/\d+/
  """
  def assert_patch(view, timeout \\ 100)

  def assert_patch(view, timeout) when is_integer(timeout) do
    {path, _flash} = assert_navigation(view, :patch, nil, timeout)
    path
  end

  def assert_patch(view, to) when is_binary(to), do: assert_patch(view, to, 100)

  @doc """
  Asserts a live patch will to a given path within `timeout` milliseconds. The
  default `timeout` is 100.

  It always returns `:ok`.

  To assert on the flash message, you can assert on the result of the
  rendered LiveView.

  ## Examples
      render_click(view, :event_that_triggers_patch)
      assert_patch view, "/path"

      render_click(view, :event_that_triggers_patch)
      assert_patch view, "/path", 30

  """
  def assert_patch(view, to, timeout)
      when is_binary(to) and is_integer(timeout) do
    assert_navigation(view, :patch, to, timeout)
    :ok
  end

  @doc """
  Asserts a live patch was performed, and returns the new path.

  To assert on the flash message, you can assert on the result of
  the rendered LiveView.

  ## Examples

      render_click(view, :event_that_triggers_redirect)
      assert_patched view, "/path"

  """
  def assert_patched(view, to) do
    assert_patch(view, to, 0)
  end

  @doc ~S"""
  Asserts a redirect will happen within `timeout` milliseconds.
  The default `timeout` is 100.

  It returns a tuple containing the new path and the flash messages from said
  redirect, if any. Note the flash will contain string keys.

  ## Examples

      render_click(view, :event_that_triggers_redirect)
      {path, flash} = assert_redirect view
      assert flash["info"] == "Welcome"
      assert path =~ ~r/path\/\d+/

      render_click(view, :event_that_triggers_redirect)
      assert_redirect view, 30
  """
  def assert_redirect(view, timeout \\ 100)

  def assert_redirect(view, timeout) when is_integer(timeout) do
    assert_navigation(view, :redirect, nil, timeout)
  end

  def assert_redirect(view, to) when is_binary(to), do: assert_redirect(view, to, 100)

  @doc """
  Asserts a redirect will happen to a given path within `timeout` milliseconds.
  The default `timeout` is 100.

  It returns the flash messages from said redirect, if any.
  Note the flash will contain string keys.

  ## Examples

      render_click(view, :event_that_triggers_redirect)
      flash = assert_redirect view, "/path"
      assert flash["info"] == "Welcome"

      render_click(view, :event_that_triggers_redirect)
      assert_redirect view, "/path", 30
  """
  def assert_redirect(view, to, timeout)
      when is_binary(to) and is_integer(timeout) do
    {_path, flash} = assert_navigation(view, :redirect, to, timeout)
    flash
  end

  @doc """
  Asserts a redirect was performed.

  It returns a tuple containing the new path and the flash messages
  from said redirect, if any. Note the flash will contain string keys.

  ## Examples

      render_click(view, :event_that_triggers_redirect)
      {_path, flash} = assert_redirected view, "/path"
      assert flash["info"] == "Welcome"

  """
  def assert_redirected(view, to) do
    assert_redirect(view, to, 0)
  end

  defp assert_navigation(view, kind, to, timeout) do
    %{proxy: {ref, topic, _}, endpoint: endpoint} = view

    receive do
      {^ref, {^kind, ^topic, %{to: new_to} = opts}} when new_to == to or to == nil ->
        {new_to, Phoenix.LiveView.Utils.verify_flash(endpoint, opts[:flash])}
    after
      timeout ->
        message =
          if to do
            "expected #{inspect(view.module)} to #{kind} to #{inspect(to)}, "
          else
            "expected #{inspect(view.module)} to #{kind}, "
          end

        case flush_navigation(ref, topic, nil) do
          nil -> raise ArgumentError, message <> "but got none"
          {kind, to} -> raise ArgumentError, message <> "but got a #{kind} to #{inspect(to)}"
        end
    end
  end

  @doc """
  Refutes a redirect to a given path was performed.

  It returns :ok if the specified redirect isn't already in the mailbox.

  ## Examples

      render_click(view, :event_that_triggers_redirect_to_path)
      :ok = refute_redirect view, "/wrong_path"
  """
  def refute_redirected(view, to) when is_binary(to) do
    refute_navigation(view, :redirect, to)
  end

  defp refute_navigation(view = %{proxy: {ref, topic, _}}, kind, to) do
    receive do
      {^ref, {^kind, ^topic, %{to: new_to}}} when new_to == to or to == nil ->
        message =
          if to do
            "expected #{inspect(view.module)} not to #{kind} to #{inspect(to)}, "
          else
            "expected #{inspect(view.module)} not to #{kind}, "
          end

        raise ArgumentError, message <> "but got a #{kind} to #{inspect(to)}"
    after
      0 -> :ok
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
  Open the default browser to display current HTML of `view_or_element`.

  ## Examples

      view
      |> element("#term a:first-child()", "Increment")
      |> open_browser()

      assert view
             |> form("#term", user: %{name: "hello"})
             |> open_browser()
             |> render_submit() =~ "Name updated"

  """
  def open_browser(view_or_element, open_fun \\ &open_with_system_cmd/1)

  def open_browser(view_or_element, open_fun) when is_function(open_fun, 1) do
    html = render_tree(view_or_element)

    view_or_element
    |> maybe_wrap_html(html)
    |> write_tmp_html_file()
    |> open_fun.()

    view_or_element
  end

  defp maybe_wrap_html(view_or_element, content) do
    {html, static_path} = call(view_or_element, :html)

    head =
      case DOM.maybe_one(html, "head") do
        {:ok, head} -> head
        _ -> {"head", [], []}
      end

    case Floki.attribute(content, "data-phx-main") do
      ["true" | _] ->
        # If we are rendering the main LiveView,
        # we return the full page html.
        html

      _ ->
        # Otherwise we build a basic html structure around the
        # view_or_element content.
        [
          {"html", [],
           [
             head,
             {"body", [],
              [
                content
              ]}
           ]}
        ]
    end
    |> Floki.traverse_and_update(fn
      {"script", _, _} -> nil
      {"a", _, _} = link -> link
      {el, attrs, children} -> {el, maybe_prefix_static_path(attrs, static_path), children}
      el -> el
    end)
  end

  defp maybe_prefix_static_path(attrs, nil), do: attrs

  defp maybe_prefix_static_path(attrs, static_path) do
    Enum.map(attrs, fn
      {"src", path} -> {"src", prefix_static_path(path, static_path)}
      {"href", path} -> {"href", prefix_static_path(path, static_path)}
      attr -> attr
    end)
  end

  defp prefix_static_path(<<"//" <> _::binary>> = url, _prefix), do: url

  defp prefix_static_path(<<"/" <> _::binary>> = path, prefix),
    do: "file://#{Path.join([prefix, path])}"

  defp prefix_static_path(url, _), do: url

  defp write_tmp_html_file(html) do
    html = Floki.raw_html(html)
    path = Path.join([System.tmp_dir!(), "#{Phoenix.LiveView.Utils.random_id()}.html"])
    File.write!(path, html)
    path
  end

  defp open_with_system_cmd(path) do
    cmd =
      case :os.type() do
        {:unix, :darwin} -> "open"
        {:unix, _} -> "xdg-open"
        {:win32, _} -> "start"
      end

    System.cmd(cmd, [path])
  end

  @doc """
  Asserts an event will be pushed within `timeout`.

  ## Examples

      assert_push_event view, "scores", %{points: 100, user: "josé"}
  """
  defmacro assert_push_event(view, event, payload, timeout \\ 100) do
    quote do
      %{proxy: {ref, _topic, _}} = unquote(view)

      assert_receive {^ref, {:push_event, unquote(event), unquote(payload)}}, unquote(timeout)
    end
  end

  @doc """
  Asserts a hook reply was returned from a `handle_event` callback.

  ## Examples

      assert_reply view, %{result: "ok", transaction_id: _}
  """
  defmacro assert_reply(view, payload, timeout \\ 100) do
    quote do
      %{proxy: {ref, _topic, _}} = unquote(view)

      assert_receive {^ref, {:reply, unquote(payload)}}, unquote(timeout)
    end
  end

  @doc """
  Follows the redirect from a `render_*` action or an `{:error, redirect}`
  tuple.

  Imagine you have a LiveView that redirects on a `render_click`
  event. You can make it sure it immediately redirects after the
  `render_click` action by calling `follow_redirect/3`:

      live_view
      |> render_click("redirect")
      |> follow_redirect(conn)

  Or in the case of an error tuple:

      assert {:error, {:redirect, %{to: "/somewhere"}}} = result = live(conn, "my-path")
      {:ok, view, html} = follow_redirect(result, conn)

  `follow_redirect/3` expects a connection as second argument.
  This is the connection that will be used to perform the underlying
  request.

  If the LiveView redirects with a live redirect, this macro returns
  `{:ok, live_view, disconnected_html}` with the content of the new
  LiveView, the same as the `live/3` macro. If the LiveView redirects
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
      {Phoenix.ConnTest.put_req_cookie(conn, @flash_cookie, flash), to}
    else
      {conn, to}
    end
  end

  @doc """
  Performs a live redirect from one LiveView to another.

  When redirecting between two LiveViews of the same `live_session`,
  mounts the new LiveView and shutsdown the previous one, which
  mimics general browser live navigation behaviour.

  When attempting to navigate from a LiveView of a different
  `live_session`, an error redirect condition is returned indicating
  a failed `live_redirect` from the client.

  ## Examples

      assert {:ok, page_live, _html} = live(conn, "/page/1")
      assert {:ok, page2_live, _html} = live(conn, "/page/2")

      assert {:error, {:redirect, _}} = live_redirect(page2_live, to: "/admin")
  """
  def live_redirect(view, opts) do
    __live_redirect__(view, opts)
  end

  @doc false
  def __live_redirect__(%View{} = view, opts, token_func \\ & &1) do
    {session, %ClientProxy{} = root} = ClientProxy.root_view(proxy_pid(view))

    url =
      case Keyword.fetch!(opts, :to) do
        "/" <> path -> URI.merge(root.uri, path)
        url -> url
      end

    live_module =
      case Phoenix.LiveView.Route.live_link_info(root.endpoint, root.router, url) do
        {:internal, route} ->
          route.view

        _ ->
          raise ArgumentError, """
          attempted to live_redirect to a non-live route at #{inspect(url)}
          """
      end

    html = render(view)
    ClientProxy.stop(proxy_pid(view), {:shutdown, :duplicate_topic})
    root_token = token_func.(root.session_token)
    static_token = token_func.(root.static_token)

    start_proxy(url, %{
      html: html,
      live_redirect: {root.id, root_token, static_token},
      connect_params: root.connect_params,
      connect_info: root.connect_info,
      live_module: live_module,
      endpoint: root.endpoint,
      router: root.router,
      session: session,
      url: url
    })
  end

  @doc """
  Receives a `form_element` and asserts that `phx-trigger-action` has been
  set to true, following up on that request.

  Imagine you have a LiveView that sends an HTTP form submission. Say that it
  sets the `phx-trigger-action` to true, as a response to a submit event.
  You can follow the trigger action like this:

      form = form(live_view, selector, %{"form" => "data"})

      # First we submit the form. Optionally verify that phx-trigger-action
      # is now part of the form.
      assert render_submit(form) =~ ~r/phx-trigger-action/

      # Now follow the request made by the form
      conn = follow_trigger_action(form, conn)
      assert conn.method == "POST"
      assert conn.params == %{"form" => "data"}

  """
  defmacro follow_trigger_action(form, conn) do
    quote bind_quoted: binding() do
      {method, path, form_data} = Phoenix.LiveViewTest.__render_trigger_event__(form)
      dispatch(conn, @endpoint, method, path, form_data)
    end
  end

  def __render_trigger_event__(%Element{} = form) do
    case render_tree(form) do
      {"form", attrs, _child_nodes} ->
        unless List.keymember?(attrs, "phx-trigger-action", 0) do
          raise ArgumentError,
                "could not follow trigger action because form #{inspect(form.selector)} " <>
                  "does not have phx-trigger-action attribute, got: #{inspect(attrs)}"
        end

        {"action", path} = List.keyfind(attrs, "action", 0) || {"action", call(form, :url)}
        {"method", method} = List.keyfind(attrs, "method", 0) || {"method", "get"}
        {method, path, form.form_data || %{}}

      {tag, _, _} ->
        raise ArgumentError,
              "could not follow trigger action because given element did not return a form, " <>
                "got #{inspect(tag)} instead"
    end
  end

  defp proxy_pid(%{proxy: {_ref, _topic, pid}}), do: pid

  defp proxy_topic(%{proxy: {_ref, topic, _pid}}), do: topic

  @doc """
  Performs an upload of a file input and renders the result.

  See `file_input/4` for details on building a file input.

  ## Examples

  Given the following LiveView template:

      <%= for entry <- @uploads.avatar.entries do %>
          <%= entry.name %>: <%= entry.progress %>%
      <% end %>

  Your test case can assert the uploaded content:

      avatar = file_input(lv, "#my-form-id", :avatar, [
        %{
          last_modified: 1_594_171_879_000,
          name: "myfile.jpeg",
          content: File.read!("myfile.jpg"),
          size: 1_396_009,
          type: "image/jpeg"
        }
      ])

      assert render_upload(avatar, "myfile.jpeg") =~ "100%"

  By default, the entire file is chunked to the server, but an optional
  percentage to chunk can be passed to test chunk-by-chunk uploads:

      assert render_upload(avatar, "myfile.jpeg", 49) =~ "49%"
      assert render_upload(avatar, "myfile.jpeg", 51) =~ "100%"
  """
  def render_upload(%Upload{} = upload, entry_name, percent \\ 100) do
    if UploadClient.allow_acknowledged?(upload) do
      render_chunk(upload, entry_name, percent)
    else
      case preflight_upload(upload) do
        {:ok, %{ref: ref, config: config, entries: entries_resp}} ->
          case UploadClient.allowed_ack(upload, ref, config, entries_resp) do
            :ok -> render_chunk(upload, entry_name, percent)
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Performs a preflight upload request.

  Useful for testing external uploaders to retrieve the `:external` entry metadata.

  ## Examples

      avatar = file_input(lv, "#my-form-id", :avatar, [%{name: ..., ...}, ...])
      assert {:ok, %{ref: _ref, config: %{chunk_size: _}}} = preflight_upload(avatar)
  """
  def preflight_upload(%Upload{} = upload) do
    # LiveView channel returns error conditions as error key in payload, ie `%{error: reason}`
    case call(
           upload.element,
           {:render_event, upload.element, :allow_upload, {upload.entries, upload.cid}}
         ) do
      %{error: reason} -> {:error, reason}
      %{ref: _ref} = resp -> {:ok, resp}
    end
  end

  defp render_chunk(upload, entry_name, percent) do
    {:ok, _} = UploadClient.chunk(upload, entry_name, percent, proxy_pid(upload.view))
    render(upload.view)
  end
end

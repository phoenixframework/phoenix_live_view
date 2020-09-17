defmodule Phoenix.LiveViewTest do
  @moduledoc """
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

  ## Testing Events

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

      assert render_click(view, :inc) =~ "The temperature is: 31℉"

      assert render_click(view, :set_temp, 35) =~ "The temperature is: 35℉"

      assert render_submit(view, :save, %{deg: 30}) =~ "The temperature is: 30℉"

      assert render_change(view, :validate, %{deg: -30}) =~ "invalid temperature"

      assert render_keydown(view, :key, :ArrowUp) =~ "The temperature is: 31℉"

      assert render_keydown(view, :key, :ArrowDown) =~ "The temperature is: 30℉"

  ## Testing regular messages

  LiveViews are `GenServer`'s under the hood, and can send and receive messages
  just like any other server. To test the side effects of sending or receiving
  messages, simply message the view and use the `render` function to test the
  result:

      send(view.pid, {:set_temp, 50})
      assert render(view) =~ "The temperature is: 50℉"

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

  @flash_cookie "__phoenix_flash__"
  require Phoenix.ConnTest

  alias Phoenix.LiveView.{Diff, Socket}
  alias Phoenix.LiveViewTest.{ClientProxy, DOM, Element, View}

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

    * `:connect_params` - the map of params available in connected mount.
      See `Phoenix.LiveView.get_connect_params/1` for more information.
    * `:session` - the session to be given to the LiveView

  All other options are forwarded to the LiveView for rendering. Refer to
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
    put_in(conn.private[:phoenix_endpoint], endpoint || raise("no @endpoint set in test case"))
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
    html = Phoenix.ConnTest.html_response(conn, 200)
    endpoint = Phoenix.Controller.endpoint_module(conn)
    ref = make_ref()

    opts = %{
      caller: {self(), ref},
      html: html,
      connect_params: conn.private[:live_view_connect_params] || %{},
      connect_info: conn.private[:live_view_connect_info] || %{},
      live_module: live_module,
      endpoint: endpoint,
      session: maybe_get_session(conn),
      url: mount_url(endpoint, path),
      test_supervisor: fetch_test_supervisor!()
    }

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

  defp mount_url(_endpoint, nil), do: nil
  defp mount_url(endpoint, "/"), do: endpoint.url()
  defp mount_url(endpoint, path), do: Path.join(endpoint.url(), path)

  defp rebuild_path(%Plug.Conn{request_path: request_path, query_string: ""}),
    do: request_path

  defp rebuild_path(%Plug.Conn{request_path: request_path, query_string: query_string}),
    do: request_path <> "?" <> query_string

  @doc """
  Mounts, updates and renders a component.

  If the component uses the `@myself` assigns, then an `id` must
  be given to it is marked as stateful.

  ## Examples

      assert render_component(MyComponent, id: 123, user: %User{}) =~
               "some markup in component"

      assert render_component(MyComponent, %{id: 123, user: %User{}}, router: SomeRouter) =~
               "some markup in component"

  """
  defmacro render_component(component, assigns, opts \\ []) do
    endpoint =
      Module.get_attribute(__CALLER__.module, :endpoint) ||
        raise ArgumentError,
              "the module attribute @endpoint is not set for #{inspect(__MODULE__)}"

    quote do
      Phoenix.LiveViewTest.__render_component__(
        unquote(endpoint),
        unquote(component),
        unquote(assigns),
        unquote(opts)
      )
    end
  end

  @doc false
  def __render_component__(endpoint, component, assigns, opts) do
    socket = %Socket{endpoint: endpoint, router: opts[:router]}
    assigns = Map.new(assigns)
    mount_assigns = if assigns[:id], do: %{myself: %Phoenix.LiveComponent.CID{cid: -1}}, else: %{}
    rendered = Diff.component_to_rendered(socket, component, assigns, mount_assigns)
    {_, diff, _} = Diff.render(socket, rendered, Diff.new_components())
    diff |> Diff.to_iodata() |> IO.iodata_to_binary()
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
             |> render_submit(%{deg: 123}) =~ "123 exceeds limits"

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
    call(view, {:render_event, {proxy_topic(view), to_string(event)}, type, value})
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

  If a view is provided, the entire LiveView is rendered. If an
  element is provided, only that element is rendered.

  ## Examples

      {:ok, view, _html} = live(conn, "/thermo")
      assert render(view) =~ ~s|<button id="alarm">Snooze</div>|

      assert view
             |> element("#alarm")
             |> render() == "Snooze"
  """
  def render(%View{} = view) do
    render(view, {proxy_topic(view), "render"})
  end

  def render(%Element{} = element) do
    render(element, element)
  end

  defp render(view_or_element, topic_or_element) do
    call(view_or_element, {:render_element, :find_element, topic_or_element}) |> DOM.to_html()
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
  Returns the most recent title that was updated via a `page_title` assign.

  ## Examples

      render_click(view, :event_that_triggers_page_title_update)
      assert page_title(view) =~ "my title"

  """
  def page_title(view) do
    call(view, :page_title)
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
  Follows the redirect from a `render_*` action.

  Imagine you have a LiveView that redirects on a `render_click`
  event. You can make it sure it immediately redirects after the
  `render_click` action by calling `follow_redirect/3`:

      live_view
      |> render_click("redirect")
      |> follow_redirect(conn)

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

  defp proxy_pid(%{proxy: {_ref, _topic, pid}}), do: pid
  defp proxy_topic(%{proxy: {_ref, topic, _pid}}), do: topic
end

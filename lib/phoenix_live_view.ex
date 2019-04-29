defmodule Phoenix.LiveView do
  @moduledoc """
  LiveView provides rich, real-time user experiences with
  server-rendered HTML.

  LiveView programming model is declarative: instead of
  saying "once event X happens, change Y on the page",
  events in LiveView are regular messages which may cause
  changes to its state. Once the state changes, LiveView will
  re-render the relevant parts of its HTML template and push it
  to the browser, which updates itself in the most efficient
  manner. This means developers write LiveView templates as
  any other server-rendered HTML and LiveView does the hard
  work of tracking changes and sending the relevant diffs to
  the browser.

  At the end of the day, a LiveView is nothing more than a
  process, that receives events as messages and updates its
  state. The state itself is nothing more than functional
  and immutable Elixir data structures. The events are either
  internal application messages (usually emitted by `Phoenix.PubSub`)
  or sent by the client/browser.

  LiveView provides many features that make it excellent
  to build rich, real-time user experiences:

    * By building on top of Elixir processes and
      `Phoenix.Channels`, LiveView scales well vertically
      (from small to large instances) and horizontally
      (by adding more instances);

    * LiveView is first rendered statically as part of
      regular HTTP requests, which provides quick times
      for "First Meaningful Paint" and also help search
      and indexing engines;

    * LiveView performs diff tracking. If the LiveView
      state changes, it won't re-render the whole template,
      but only the parts affected by the changed state.
      This reduces latency and the amount of data sent over
      the wire;

    * LiveView tracks static and dynamic contents. Any
      server-rendered HTML is made of static parts (i.e.
      that never change) and dynamic ones. On the first
      render, LiveView sends the static contents and in
      future updates only the modified dynamic contents
      are resent;

    * (Coming soon) LiveView uses the Erlang Term Format
      to send messages to the client. This binary-based
      format is quite efficient on the server and uses
      less data over the wire;

    * (Coming soon) LiveView includes a latency simulator,
      which allows you to simulate how your application
      behaves on increased latency and guides you to provide
      meaningful feedback to users while they wait for events
      to be processed;

  Furthermore, by keeping a persistent connection between client
  and server, LiveView applications can react faster to user events
  as there is less work to be done and less data to be sent compared
  to stateless requests that have to authenticate, decode, load,
  and encode data on every request. The flipside is that LiveView
  uses more memory on the server compared to stateless requests.

  ## Use cases

  There are many use cases where LiveView is an excellent
  fit right now:

    * Handling of user interaction and inputs, buttons, and
      forms - such as input validation, dynamic forms,
      autocomplete, etc;

    * Events and updates pushed by server - such as
      notifications, dashboards, etc;

  There are other cases that have limited support but
  will become first-class as we further develop LiveView:

    * Page and data navigation - such as navigating between
      pages, pagination, etc can be built with LiveView
      but currently you will lose the back/forward button,
      and the ability to link to pages as you navigate.
      Support for `pushState` is on the roadmap;

    * Cumulative and always growing data - chat
      applications, logs, and similar can be built with
      LiveView but currently you have to keep in the
      server a copy of all messages shown in the client
      as there is no append/prepend operation. Support
      for append/prepend is on the roadmap;

    * Transitions and loading states - the LiveView
      programming model provides a good foundation for
      transitions and loading states since any UI change
      done after a user action is undone once the server
      sends the update for said action. For example, it is
      relatively straight-forward to click a button that
      changes itself in a way that is automatically undone
      when the update arrives. This is especially important
      as user feedback when latency is involved. A complete
      feature set for modelling those states is coming in
      future versions;

  There are also use cases which are a bad fit for LiveView:

    * Animations - animations, menus, and general events
      that do not need the server in the first place are a
      bad fit for LiveView, as they can be achieved purely
      with CSS and/or CSS transitions;

    * Optimistic UIs - once we add transitions and loading
      states, many of the building blocks necessary for
      building optimistic UIs will be part of LiveView, but
      since optimistic UIs are about doing work on the client
      while the server is unavailable, complete support for
      Optimistic UIs cannot be achieved without also writing
      JavaScript for the cases the server is not available;

  ## Life-cycle

  A LiveView begins as a regular HTTP request and HTML response,
  and then upgrades to a stateful view on client connect,
  guaranteeing a regular HTML page even if JavaScript is disabled.
  Any time a stateful view changes or updates its socket assigns, it is
  automatically re-rendered and the updates are pushed to the client.

  You begin by rendering a LiveView from your router or controller
  while providing *session* data to the view, which represents request info
  necessary for the view, such as params, cookie session info, etc.
  The session is signed and stored on the client, then provided back
  to the server when the client connects, or reconnects to the stateful
  view. When a view is rendered from the controller, the `mount/2` callback
  is invoked with the provided session data and the LiveView socket.
  The `mount/2` callback wires up socket assigns necessary for rendering
  the view. After mounting, `render/1` is invoked and the HTML is sent
  as a regular HTML response to the client.

  After rendering the static page with a signed session, LiveView
  connects from the client where stateful views are spawned
  to push rendered updates to the browser, and receive client events
  via phx bindings. Just like the controller flow, `mount/2` is invoked
  with the signed session, and socket state, where mount assigns
  values for rendering. However, in the connected client case, a
  LiveView process is spawned on the server, pushes the result of
  `render/1` to the client and continues on for the duration of the
  connection. If at any point during the stateful life-cycle a
  crash is encountered, or the client connection drops, the client
  gracefully reconnects to the server, passing its signed session
  back to `mount/2`.

  ## Example

  First, a LiveView requires two callbacks: `mount/2` and `render/1`:

      defmodule AppWeb.ThermostatLive do
        use Phoenix.LiveView

        def render(assigns) do
          ~L\"""
          Current temperature: <%= @temperature %>
          \"""
        end

        def mount(%{id: id, current_user_id: user_id}, socket) do
          case Thermostat.get_user_reading(user_id, id) do
            {:ok, temperature} ->
              {:ok, assign(socket, :temperature, temperature)}

            {:error, reason} ->
              {:error, reason}
          end
        end
      end

  The `render/1` callback receives the `socket.assigns` and is responsible
  for returning rendered content. You can use `Phoenix.LiveView.sigil_L/2`
  to inline LiveView templates. If you want to use `Phoenix.HTML` helpers,
  remember to `use Phoenix.HTML` at the top of your `LiveView`.

  A separate `.leex` HTML template can also be rendered within
  your `render/1` callback by delegating to an existing `Phoenix.View`
  module in your application. For example:

      defmodule AppWeb.ThermostatLive do
        use Phoenix.LiveView

        def render(assigns) do
          AppWeb.PageView.render("page.html", assigns)
        end
      end

  With a LiveView defined, you first define the `socket` path in your endpoint,
  and point it to `Phoenix.LiveView.Socket`:

      defmodule AppWeb.Endpoint do
        use Phoenix.Endpoint

        socket "/live", Phoenix.LiveView.Socket
        ...
      end

  And configure its signing salt in the endpoint:

      config :my_app, AppWeb.Endpoint,
        ...,
        live_view: [signing_salt: ...]

  You can generate a secure, random signing salt with the
  `mix phx.gen.secret 32` task.

  Next, you can serve the LiveView directly from your router:

      defmodule AppWeb.Router do
        use Phoenix.Router
        import Phoenix.LiveView.Router

        scope "/", AppWeb do
          live "/thermostat", ThermostatLive
        end
      end

  Or you can `live_render` your view from any controller:

      defmodule AppWeb.ThermostatController do
        ...
        import Phoenix.LiveView.Controller

        def show(conn, %{"id" => id}) do
          live_render(conn, AppWeb.ThermostatLive, session: %{
            id: id,
            current_user_id: get_session(conn, :user_id),
          })
        end
      end

  As we saw in the life-cycle section, you pass `:session` data about the
  request to the view, such as the current user's id in the cookie session,
  and parameters from the request. A regular HTML response is sent with a
  signed token embedded in the DOM containing your LiveView session data.

  Next, your client code connects to the server:

      import LiveSocket from "phoenix_live_view"

      let liveSocket = new LiveSocket("/live")
      liveSocket.connect()

  After the client connects, `mount/2` will be invoked inside a spawned
  LiveView process. At this point, you can use `connected?/1` to
  conditionally perform stateful work, such as subscribing to pubsub topics,
  sending messages, etc. For example, you can periodically update a LiveView
  with a timer:

      defmodule DemoWeb.ThermostatLive do
        use Phoenix.LiveView
        ...

        def mount(%{id: id, current_user_id: user_id}, socket) do
          if connected?(socket), do: :timer.send_interval(30000, self(), :update)

          case Thermostat.get_user_reading(user_id, id) do
            {:ok, temperature} ->
              {:ok, assign(socket, temperature: temperature, id: id)}

            {:error, reason} ->
              {:error, reason}
          end
        end

        def handle_info(:update, socket) do
          {:ok, temperature} = Thermostat.get_reading(socket.assigns.id)
          {:noreply, assign(socket, :temperature, temperature)}
        end
      end

  We used `connected?(socket)` on mount to send our view a message every 30s if
  the socket is in a connected state. We receive `:update` in a
  `handle_info` just like a GenServer, and update our socket assigns. Whenever
  a socket's assigns change, `render/1` is automatically invoked, and the
  updates are sent to the client.

  ## LiveEEx Templates

  `Phoenix.LiveView`'s built-in templates provided by the `.leex`
  extension or `~L` sigil, stands for Live EEx. They are similar
  to regular `.eex` templates except they are designed to minimize
  the amount of data sent over the wire by splitting static from
  dynamic parts and also tracking changes.

  When you first render a `.leex` template, it will send all of the
  static and dynamic parts of the template to the client. After that,
  any change you do on the server will now send only the dynamic parts,
  and only if those parts have changed.

  The tracking of changes is done via assigns. Imagine this template:

      <div id="user_<%= @user.id %>">
        <%= @user.name %>
      </div>

  If the `@user` assign changes, then LiveView will re-render only
  the `@user.id` and `@user.name` and sent it to the browser. That's
  why it is important to keep most of the markup in the template itself.
  If you write the div above to something like:

      <%= username_div(@user) %>

  Then if the `@user` changes, the whole div will be sent (but only
  if the `@user` assign changes).

  The assign tracking feature also implies that you MUST pass all of
  the data to your templates explicitly and avoid performing direct
  operations on the template as much as possible. For example, if you
  perform this operation in your template:

      <%= for user <- Repo.all(User) do %>
        <%= user.name %>
      <% end %>

  Then Phoenix will never re-render the section above, even if the amount of
  users in the database changes. Instead, you need to store the users as
  assigns in your LiveView before it renders the template:

      assign(socket, :users, Repo.all(User))

  Generally speaking, **data loading should never happen inside the template**,
  regardless if you are using LiveView or not. The difference is that LiveView
  enforces those as best practices.

  ## Bindings

  Phoenix supports DOM element bindings for client-server interaction. For
  example, to react to a click on a button, you would render the element:

      <button phx-click="inc_temperature">+</button>

  Then on the server, all LiveView bindings are handled with the `handle_event`
  callback, for example:

      def handle_event("inc_temperature", _value, socket) do
        {:ok, new_temp} = Thermostat.inc_temperature(socket.assigns.id)
        {:noreply, assign(socket, :temperature, new_temp)}
      end

  ### Click Events

  The `phx-click` binding is used to send click events to the server. The
  `value` passed to `handle_event` is chosen on the client with the following
  priority:

    * An optional `"phx-value"` binding on the clicked element
    * The clicked element's `value` property
    * An empty string

  ### Focus and Blur Events

  Focus and blur events may be bound to DOM elements that emit
  such events, using the `phx-blur`, and `phx-focus` bindings, for example:

      <input name="email" phx-focus="myfocus" phx-blur="myblur"/>

  To detect when the page itself has receive focus or blur,
  `phx-target` may be specified as `"window"`. Like other
  bindings, a `phx-value` can be provided on the bound element,
  otherwise the input's value will be used. For example:

      <div class="container"
          phx-focus="page-active"
          phx-blur="page-inactive"
          phx-target="window">
        ...
      </div>

  ### Form Events

  To handle form changes and submissions, use the `phx-change` and `phx-submit`
  events. In general, it is preferred to handle input changes at the form level,
  where all form fields are passed to the LiveView's callback given any
  single input change. For example, to handle real-time form validation and
  saving, your template would use both `phx_change` and `phx_submit` bindings:

      <%= form_for @changeset, "#", [phx_change: :validate, phx_submit: :save], fn f -> %>
        <%= label f, :username %>
        <%= text_input f, :username %>
        <%= error_tag f, :username %>

        <%= label f, :email %>
        <%= text_input f, :email %>
        <%= error_tag f, :email %>

        <%= submit "Save" %>
      <% end %>

  Next, your LiveView picks up the events in `handle_event` callbacks:

      def render(assigns) ...

      def mount(_session, socket) do
        {:ok, assign(socket, %{changeset: Accounts.change_user(%User{})})}
      end

      def handle_event("validate", %{"user" => params}, socket) do
        changeset =
          %User{}
          |> Accounts.change_user(params)
          |> Map.put(:action, :insert)

        {:noreply, assign(socket, changeset: changeset)}
      end

      def handle_event("save", %{"user" => user_params}, socket) do
        case Accounts.create_user(user_params) do
          {:ok, user} ->
            {:stop,
             socket
             |> put_flash(:info, "user created")
             |> redirect(to: Routes.user_path(AppWeb.Endpoint, AppWeb.User.ShowView, user))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, changeset: changeset)}
        end
      end

  The validate callback simply updates the changeset based on all form input
  values, then assigns the new changeset to the socket. If the changeset
  changes, such as generating new errors, `render/1` is invoked and
  the form is re-rendered.

  Likewise for `phx-submit` bindings, the save callback is invoked and
  persistence is attempted. On success, a `:stop` tuple is returned and the
  socket is annotated for redirect with `Phoenix.LiveView.redirect/2`,
  otherwise the socket assigns are updated with the errored changeset to be
  re-rerendered for the client.

  *Note*: For proper form error tag updates, the error tag must specify which
  input it belongs to. This is accomplished with the `data-phx-error-for` attribute.
  For example, your `AppWeb.ErrorHelpers` may use this function:

      def error_tag(form, field) do
        Enum.map(Keyword.get_values(form.errors, field), fn error ->
          content_tag(:span, translate_error(error),
            class: "help-block",
            data: [phx_error_for: input_id(form, field)]
          )
        end)
      end

  ### Key Events

  The onkeydown, and onkeyup events are supported via
  the `phx-keydown`, and `phx-keyup` bindings. When
  pushed, the value sent to the server will be the event's `key`.
  By default, the bound element will be the event listener, but an
  optional `phx-target` may be provided which may be `"document"`,
  `"window"`, or the DOM id of a target element, for example:

      @up_key 38
      @down_key 40

      def render(assigns) do
        ~L\"""
        <div id="thermostat" phx-keyup="update_temp" phx-target="document">
          Current temperature: <%= @temperature %>
        </div>
        \"""
      end

      def handle_event("update_temp", @up_key, socket) do
        {:ok, new_temp} = Thermostat.inc_temperature(socket.assigns.id)
        {:noreply, assign(socket, :temperature, new_temp)}
      end

      def handle_event("update_temp", @down_key, socket) do
        {:ok, new_temp} = Thermostat.dec_temperature(socket.assigns.id)
        {:noreply, assign(socket, :temperature, new_temp)}
      end

      def handle_event("update_temp", _key, socket) do
        {:noreply, socket}
      end

  """

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @type unsigned_params :: map
  @type from :: binary

  @callback mount(session :: map, Socket.t()) ::
              {:ok, Socket.t()} | {:stop, Socket.t()}

  @callback render(Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @callback terminate(reason, Socket.t()) :: term
            when reason: :normal | :shutdown | {:shutdown, :left | :closed | term}

  @callback handle_event(event :: binary, unsigned_params, Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @callback handle_call(msg :: term, {pid, reference}, Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, term, Socket.t()} | {:stop, Socket.t()}

  @callback handle_info(msg :: term, Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, term, Socket.t()} | {:stop, Socket.t()}

  @optional_callbacks terminate: 2, handle_event: 3, handle_call: 3, handle_info: 2

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def mount(_session, socket), do: {:ok, socket}

      defoverridable mount: 2
    end
  end

  @doc """
  Renders a LiveView within an originating plug request or
  within a parent LiveView.

  ## Options

    * `:session` - the map of session data to sign and send
      to the client. When connecting from the client, the LiveView
      will receive the signed session from the client and verify
      the contents before proceeding with `mount/2`.
    * `:container` - the optional tuple for the HTML tag and DOM attributes to
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`
    * `:child_id` - the ID to uniquely identify a child LiveView when
      live rendering children of the same type.

  ## Examples

      # within eex template
      <%= live_render(@conn, MyApp.ThermostatLive) %>

      # within leex template
      <%= live_render(@socket, MyApp.ThermostatLive) %>

  """
  def live_render(conn_or_socket, view, opts \\ []) do
    opts = Keyword.put_new(opts, :session, %{})
    do_live_render(conn_or_socket, view, opts)
  end

  defp do_live_render(%Plug.Conn{} = conn, view, opts) do
    case LiveView.View.static_render(conn, view, opts) do
      {:ok, content} ->
        content

      {:stop, {:redirect, _opts}} ->
        raise RuntimeError, """
        attempted to redirect from #{inspect(view)} while rendering Plug request.
        Redirects from live renders inside a Plug request are not supported.
        """
    end
  end

  defp do_live_render(%Socket{} = parent, view, opts) do
    case LiveView.View.nested_static_render(parent, view, opts) do
      {:ok, content} -> content
      {:stop, reason} -> throw({:stop, reason})
    end
  end

  @doc """
  Returns true if the socket is connected.

  Useful for checking the connectivity status when mounting the view.
  For example, on initial page render, the view is mounted statically,
  rendered, and the HTML is sent to the client. Once the client
  connects to the server, a LiveView is then spawned and mounted
  statefully within a process. Use `connected?/1` to conditionally
  perform stateful work, such as subscribing to pubsub topics,
  sending messages, etc.

  ## Examples

      defmodule DemoWeb.ClockLive do
        use Phoenix.LiveView
        ...
        def mount(_session, socket) do
          if connected?(socket), do: :timer.send_interval(1000, self(), :tick)

          {:ok, assign(socket, date: :calendar.local_time())}
        end

        def handle_info(:tick, socket) do
          {:noreply, assign(socket, date: :calendar.local_time())}
        end
      end
  """
  def connected?(%Socket{} = socket) do
    LiveView.View.connected?(socket)
  end

  @doc """
  Assigns a value into the socket only if it does not exist.

  Useful for lazily assigning values and referencing parent assigns.

  ## Referencing parent assigns

  When a LiveView is mounted in a disconnected state, the Plug.Conn assigns
  will be available for reference via `assign_new/3`, allowing assigns to
  be shared for the initial HTTP request. On connected mount, the `assign_new/3`
  would be invoked, and the LiveView would use its session to rebuild the
  originally shared assign. Likewise, nested LiveView children have access
  to their parent's assigns on mount using `assign_new`, which allows
  assigns to be shared down the nested LiveView tree.

  ## Examples

      # controller
      conn
      |> assign(:current_user, user)
      |> LiveView.Controller.live_render(MyLive, sesssion: %{user_id: user.id})

      # LiveView mount
      def mount(%{user_id: user_id}, socket) do
        {:ok, assign_new(:current_user, fn -> Accounts.get_user!(user_id) end)}
      end

  """
  def assign_new(%Socket{} = socket, key, func) when is_function(func, 0) do
    case socket do
      %{assigns: %{^key => _}} ->
        socket

      %{private: %{assigned_new: {assigns, keys}} = private} ->
        # It is important to store the keys even if they are not in assigns
        # because maybe the controller doesn't have it but the view does.
        private = put_in(private.assigned_new, {assigns, [key | keys]})
        do_assign(%{socket | private: private}, key, Map.get_lazy(assigns, key, func))

      %{} ->
        do_assign(socket, key, func.())
    end
  end

  @doc """
  Adds key value pairs to socket assigns.

  A single key value pair may be passed, or a keyword list
  of assigns may be provided to be merged into existing
  socket assigns.

  ## Examples

      iex> assign(socket, :name, "Elixir")
      iex> assign(socket, name: "Elixir", logo: "💧")
  """
  def assign(%Socket{} = socket, key, value) do
    assign(socket, [{key, value}])
  end

  def assign(%Socket{} = socket, attrs)
      when is_map(attrs) or is_list(attrs) do
    Enum.reduce(attrs, socket, fn {key, val}, acc ->
      case Map.fetch(acc.assigns, key) do
        {:ok, ^val} -> acc
        {:ok, _old_val} -> do_assign(acc, key, val)
        :error -> do_assign(acc, key, val)
      end
    end)
  end

  defp do_assign(%Socket{assigns: assigns, changed: changed} = acc, key, val) do
    new_changed = Map.put(changed, key, true)
    new_assigns = Map.put(assigns, key, val)
    %Socket{acc | assigns: new_assigns, changed: new_changed}
  end

  @doc """
  Updates an existing key in the socket assigns.

  The update function receives the current key's value and
  returns the updated value. Raises if the key does not exist.

  ## Examples

      iex> update(socket, :count, fn count -> count + 1 end)
      iex> update(socket, :count, &(&1 + 1))
  """
  def update(%Socket{assigns: assigns} = socket, key, func) do
    case Map.fetch(assigns, key) do
      {:ok, val} -> assign(socket, key, func.(val))
      :error -> raise KeyError, key: key, term: assigns
    end
  end

  @doc """
  Adds a flash message to the socket to be displayed on redirect.

  *Note*: the `Phoenix.LiveView.Flash` plug must be plugged in
  your browser's pipeline for flash to be supported, for example:

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug Phoenix.LiveView.Flash
        ...
      end

  ## Examples

      iex> put_flash(socket, :info, "It worked!")
      iex> put_flash(socket, :error, "You can't access that page")
  """
  def put_flash(%Socket{private: private} = socket, kind, msg) do
    new_private = Map.update(private, :flash, %{kind => msg}, &Map.put(&1, kind, msg))
    %Socket{socket | private: new_private}
  end

  @doc """
  Annotates the socket for redirect to a destination path.

  *Note*: LiveView redirects rely on instructing client
  to perform a `window.location` update on the provided
  redirect location.

  TODO support `:external` and validation `:to` is a local path

  ## Options

    * `:to` - the path to redirect to
  """
  def redirect(%Socket{} = socket, opts) do
    LiveView.View.put_redirect(socket, Keyword.fetch!(opts, :to))
  end

  @doc """
  Provides `~L` sigil with HTML safe Live EEx syntax inside source files.

      iex> ~L"\""
      ...> Hello <%= "world" %>
      ...> "\""
      {:safe, ["Hello ", "world", "\\n"]}

  """
  defmacro sigil_L({:<<>>, _, [expr]}, []) do
    EEx.compile_string(expr, engine: Phoenix.LiveView.Engine, line: __CALLER__.line + 1)
  end
end

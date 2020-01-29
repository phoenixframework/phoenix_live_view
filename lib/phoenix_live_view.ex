defmodule Phoenix.LiveView do
  @moduledoc ~S'''
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
  process that receives events as messages and updates its
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
      for "First Meaningful Paint", in addition to helping
      search and indexing engines;

    * LiveView performs diff tracking. If the LiveView
      state changes, it will only re-render those changes.
      This reduces latency and the amount of data sent over
      the wire;

    * LiveView tracks static and dynamic content. Any
      server-rendered HTML is made of static parts (i.e.
      that never change) and dynamic ones. On the first
      render, LiveView sends the static content and in
      future updates only the modified dynamic content
      is resent;

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

    * Page and data navigation - such as navigating between
      pages, pagination, etc can be built with LiveView
      but currently you will lose the back/forward button,
      and the ability to link to pages as you navigate.
      Support for `pushState` is on the roadmap;

  There are other cases that have limited support but
  will become first-class as we further develop LiveView:

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

    * Optimistic UIs - once we add transitions and loading
      states, many of the building blocks necessary for
      building optimistic UIs will be part of LiveView, but
      since optimistic UIs are about doing work on the client
      while the server is unavailable, complete support for
      Optimistic UIs cannot be achieved without also writing
      JavaScript for the cases the server is not available.
      See  "JS Interop and client-controlled DOM" on how to
      integrate JS hooks;

  There are also use cases which are a bad fit for LiveView:

    * Animations - animations, menus, and general events
      that do not need the server in the first place are a
      bad fit for LiveView, as they can be achieved purely
      with CSS and/or CSS transitions;

  ## Life-cycle

  A LiveView begins as a regular HTTP request and HTML response,
  and then upgrades to a stateful view on client connect,
  guaranteeing a regular HTML page even if JavaScript is disabled.
  Any time a stateful view changes or updates its socket assigns, it is
  automatically re-rendered and the updates are pushed to the client.

  You begin by rendering a LiveView from your router, controller, or
  view. When a view is first rendered, the `mount/3` callback is invoked
  with the current params, the current session and the LiveView socket.
  As in a regular request, `params` contains public data that can be
  modified by the user. The `session` always contains private data set
  by the application itself. The `mount/3` callback wires up socket
  assigns necessary for rendering the view. After mounting, `render/1`
  is invoked and the HTML is sent as a regular HTML response to the
  client.

  After rendering the static page, LiveView connects from the client
  where stateful views are spawned to push rendered updates to the
  browser, and receive client events via phx bindings. Just like
  the first rendering, `mount/3` is invoked  with params, session,
  and socket state, where mount assigns values for rendering. However
  in the connected client case, a LiveView process is spawned on
  the server, pushes the result of `render/1` to the client and
  continues on for the duration of the connection. If at any point
  during the stateful life-cycle a crash is encountered, or the client
  connection drops, the client gracefully reconnects to the server,
  calling `mount/3` once again.

  ## Example

  First, a LiveView requires two callbacks: `mount/3` and `render/1`:

      defmodule AppWeb.ThermostatLive do
        use Phoenix.LiveView

        def render(assigns) do
          ~L"""
          Current temperature: <%= @temperature %>
          """
        end

        def mount(_params, %{"current_user_id" => user_id}, socket) do
          temperature = Thermostat.get_user_reading(user_id)
          {:ok, assign(socket, :temperature, temperature)}
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
          Phoenix.View.render(AppWeb.PageView, "page.html", assigns)
        end
      end

  With a LiveView defined, you first define the `socket` path in your endpoint,
  and point it to `Phoenix.LiveView.Socket`:

      defmodule AppWeb.Endpoint do
        use Phoenix.Endpoint

        socket "/live", Phoenix.LiveView.Socket,
          websocket: [connect_info: [session: @session_options]]

        ...
      end

  Where `@session_options` are the options given to `plug Plug.Session` extracted
  to a module attribute.

  And configure its signing salt in the endpoint:

      config :my_app, AppWeb.Endpoint,
        ...,
        live_view: [signing_salt: ...]

  You can generate a secure, random signing salt with the `mix phx.gen.secret 32` task.

  Next, decide where you want to use your LiveView.

  You can serve the LiveView directly from your router (recommended):

      defmodule AppWeb.Router do
        use Phoenix.Router
        import Phoenix.LiveView.Router

        scope "/", AppWeb do
          live "/thermostat", ThermostatLive
        end
      end

  You can also `live_render` from any template:

      <h1>Temperature Control</h1>
      <%= live_render(@conn, AppWeb.ThermostatLive) %>

  Or you can `live_render` your view from any controller:

      defmodule AppWeb.ThermostatController do
        ...
        import Phoenix.LiveView.Controller

        def show(conn, %{"id" => id}) do
          live_render(conn, AppWeb.ThermostatLive)
        end
      end

  When a LiveView is rendered, all of the data currently stored in the
  connection session (see `Plug.Conn.get_session/1`) will be given to
  the LiveView.

  It is also possible to pass additional session information to the LiveView
  through a session parameter:

      # In the router
      live "/thermostat", ThermostatLive, session: %{"extra_token" => "foo"}

      # In a view
      <%= live_render(@conn, AppWeb.ThermostatLive, session: %{"extra_token" => "foo"}) %>

  Notice the `:session` uses string keys as a reminder that session data
  is serialized and sent to the client. So you should always keep the data
  in the session to a minimum. I.e. instead of storing a User struct, you
  should store the "user_id" and load the User when the LiveView mounts.

  Once the LiveView is rendered, a regular HTML response is sent. Next, your
  client code connects to the server:

      import {Socket} from "phoenix"
      import LiveSocket from "phoenix_live_view"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", {params: {_csrf_token: csrfToken}});
      liveSocket.connect()

  *Note*: Comprehensive JavaScript client usage is covered in a later section.

  After the client connects, `mount/3` will be invoked inside a spawned
  LiveView process. At this point, you can use `connected?/1` to
  conditionally perform stateful work, such as subscribing to pubsub topics,
  sending messages, etc. For example, you can periodically update a LiveView
  with a timer:

      defmodule DemoWeb.ThermostatLive do
        use Phoenix.LiveView
        ...

        def mount(_params, %{"current_user_id" => user_id}, socket) do
          if connected?(socket), do: :timer.send_interval(30000, self(), :update)

          case Thermostat.get_user_reading(user_id) do
            {:ok, temperature} ->
              {:ok, assign(socket, temperature: temperature, user_id: user_id)}

            {:error, reason} ->
              {:error, reason}
          end
        end

        def handle_info(:update, socket) do
          {:ok, temperature} = Thermostat.get_reading(socket.assigns.user_id)
          {:noreply, assign(socket, :temperature, temperature)}
        end
      end

  We used `connected?(socket)` on mount to send our view a message every 30s if
  the socket is in a connected state. We receive `:update` in a
  `handle_info` just like a GenServer, and update our socket assigns. Whenever
  a socket's assigns change, `render/1` is automatically invoked, and the
  updates are sent to the client.

  ## Assigns and LiveEEx Templates

  All of the data in a LiveView is stored in the socket as assigns.
  The `assign/2` and `assign/3` functions help store those values.
  Those values can be accessed in the LiveView as `socket.assigns.name`
  but they are most commonly accessed inside LiveView templates as
  `@name`.

  `Phoenix.LiveView`'s built-in templates are identified by the `.leex`
  extension (Live EEx) or `~L` sigil. They are similar to regular `.eex`
  templates except they are designed to minimize the amount of data sent
  over the wire by splitting static and dynamic parts and tracking changes.

  When you first render a `.leex` template, it will send all of the
  static and dynamic parts of the template to the client. After that,
  any change you do on the server will now send only the dynamic parts,
  and only if those parts have changed.

  The tracking of changes is done via assigns. Imagine this template:

      <div id="user_<%= @user.id %>">
        <%= @user.name %>
      </div>

  If the `@user` assign changes, then LiveView will re-render only
  the `@user.id` and `@user.name` and send them to the browser.

  The change tracking also works when rendering other templates, as
  long as they are also `.leex` templates and as long as all assigns
  are passed to the child/inner template:

      <%= render "child_template.html", assigns %>

  The assign tracking feature also implies that you MUST avoid performing
  direct operations in the template. For example, if you perform a database
  query in your template:

      <%= for user <- Repo.all(User) do %>
        <%= user.name %>
      <% end %>

  Then Phoenix will never re-render the section above, even if the number of
  users in the database changes. Instead, you need to store the users as
  assigns in your LiveView before it renders the template:

      assign(socket, :users, Repo.all(User))

  Generally speaking, **data loading should never happen inside the template**,
  regardless if you are using LiveView or not. The difference is that LiveView
  enforces this best practice.

  ### Change tracking pitfalls

  Although change tracking can considerably reduce the amount of data sent
  over the wire, there are some pitfalls users should be aware of.

  First of all, change tracking can only track assigns directly. So for example,
  if you do something such as:

      <%= @post.the_whole_content %>

  If any of other field besides `the_whole_content` in `@post` change for any
  reason, the `the_whole_content` will be sent downstream. Although this is not
  generally a problem, if you have large fields that you don't want to resend
  or if you have one field in particular that changes all the time while others
  do not, you may want to track them as their own assign.

  Another limitation of changing tracking is that it does not work across regular
  function calls. For example, imagine the following template that renders a `div`:

      <%= content_tag :div, id: "user_#{@id}" do %>
        <%= @name %>
        <%= @description %>
      <% end %>

  LiveView knows nothing about `content_tag`, which means the whole `div` will be
  sent whenever any of the assigns change. This can be easily fixed by writing the
  HTML directly:

      <div id="user_<%= @id %>">
        <%= @name %>
        <%= @description %>
      </div>

  Note though this concern does not apply to Elixir's constructs, such as `if`,
  `case`, `for`, and friends. LiveView always knows how to optimize across those.

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

  | Binding                | Attributes |
  |------------------------|------------|
  | [Params](#module-click-events) | `phx-value-*` |
  | [Click Events](#module-click-events) | `phx-click`, `phx-target` |
  | [Focus/Blur Events](#module-focus-and-blur-events) | `phx-blur`, `phx-focus`, `phx-target` |
  | [Form Events](#module-form-events) | `phx-change`, `phx-submit`, `phx-target`, `data-phx-error-for`, `phx-disable-with` |
  | [Key Events](#module-key-events) | `phx-keydown`, `phx-keyup`, `phx-target` |
  | [Rate Limiting](#module-rate-limiting-events-with-debounce-and-throttle) | `phx-debounce`, `phx-throttle` |
  | [Custom DOM Patching](#module-custom-dom-patching) | `phx-update` |
  | [JS Interop](#module-js-interop-and-client--controlled-dom) | `phx-hook` |

  ### Click Events

  The `phx-click` binding is used to send click events to the server.
  When any client event, such as a `phx-click` click is pushed, the value
  sent to the server will be chosen with the following priority:

    * Any number of optional `phx-value-` prefixed attributes, such as:

          <div phx-click="inc" phx-value-myvar1="val1" phx-value-myvar2="val2">

      will send the following map of params to the server:

          def handle_event("inc", %{"myvar1" => "val1", "myvar2" => "val2"}, socket) do

      If the `phx-value-` prefix is used, the server payload will also contain a `"value"`
      if the element's value attribute exists.

    * When receiving a map on the server, the payload will also contain metadata of the
      client event, containing all literal keys of the event object, such as a click event's
      `clientX`, a keydown event's `keyCode`, etc.

  ### Focus and Blur Events

  Focus and blur events may be bound to DOM elements that emit
  such events, using the `phx-blur`, and `phx-focus` bindings, for example:

      <input name="email" phx-focus="myfocus" phx-blur="myblur"/>

  To detect when the page itself has received focus or blur,
  `phx-window-focus` and `phx-window-blur` may be specified. These window
  level events may also be necessary if the element in consideration
  (most often a `div` with no tabindex) cannot receive focus. Like other
  bindings, `phx-value-*` can be provided on the bound element, and those
  values will be sent as part of the payload. For example:

      <div class="container"
          phx-window-focus="page-active"
          phx-window-blur="page-inactive"
          phx-value-page="123">
        ...
      </div>

  The following window level bindings are supported:

    * `phx-window-focus`
    * `phx-window-blur`
    * `phx-window-keydown`
    * `phx-window-keyup`

  ### Form Events

  To handle form changes and submissions, use the `phx-change` and `phx-submit`
  events. In general, it is preferred to handle input changes at the form level,
  where all form fields are passed to the LiveView's callback given any
  single input change. For example, to handle real-time form validation and
  saving, your template would use both `phx_change` and `phx_submit` bindings:

      <%= f = form_for @changeset, "#", [phx_change: :validate, phx_submit: :save] %>
        <%= label f, :username %>
        <%= text_input f, :username %>
        <%= error_tag f, :username %>

        <%= label f, :email %>
        <%= text_input f, :email %>
        <%= error_tag f, :email %>

        <%= submit "Save" %>
      </form>

  Next, your LiveView picks up the events in `handle_event` callbacks:

      def render(assigns) ...

      def mount(_params, _session, socket) do
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

  Likewise for `phx-submit` bindings, the same callback is invoked and
  persistence is attempted. On success, a `:stop` tuple is returned and the
  socket is annotated for redirect with `Phoenix.LiveView.redirect/2` to
  the new user page, otherwise the socket assigns are updated with the errored
  changeset to be re-rendered for the client.

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

  ### Number inputs

  Number inputs are a special case in LiveView forms. On programmatic updates,
  some browsers will clear invalid inputs. So LiveView will not send change events
  from the client when an input is invalid, instead allowing the browser's native
  validation UI to drive user interaction. Once the input becomes valid, change and
  submit events will be sent as normal.

  ### Password inputs

  Password inputs are also special cased in `Phoenix.HTML`. For security reasons,
  password field values are not reused when rendering a password input tag. This
  requires explicitly setting the `:value` in your markup, for example:

      <%= password_input f, :password, value: input_value(f, :password) %>
      <%= password_input f, :password_confirmation, value: input_value(f, :password_confirmation) %>
      <%= error_tag f, :password %>
      <%= error_tag f, :password_confirmation %>

  ### Key Events

  The `onkeydown`, and `onkeyup` events are supported via
  the `phx-keydown`, and `phx-keyup` bindings. When
  pushed, the value sent to the server will contain all the client event
  object's metadata. For example, pressing the Escape key looks like this:

      %{
        "altKey" => false, "charCode" => 0, "code" => "Escape",
        "ctrlKey" => false, "key" => "Escape", "keyCode" => 27,
        "location" => 0, "metaKey" => false, "repeat" => false,
        "shiftKey" => false, "which" => 27
      }

  By default, the bound element will be the event listener, but a
  window-level binding may be provided via `phx-window-keydown`,
  for example:

      def render(assigns) do
        ~L"""
        <div id="thermostat" phx-window-keyup="update_temp">
          Current temperature: <%= @temperature %>
        </div>
        """
      end

      def handle_event("update_temp", %{"code" => "ArrowUp"}, socket) do
        {:ok, new_temp} = Thermostat.inc_temperature(socket.assigns.id)
        {:noreply, assign(socket, :temperature, new_temp)}
      end

      def handle_event("update_temp", %{"code" => "ArrowDown"}, socket) do
        {:ok, new_temp} = Thermostat.dec_temperature(socket.assigns.id)
        {:noreply, assign(socket, :temperature, new_temp)}
      end

      def handle_event("update_temp", _key, socket) do
        {:noreply, socket}
      end

  ## Compartmentalizing markup and events with `render`, `live_render`, and `live_component`

  We can render another template directly from a LiveView template by simply
  calling `render`:

      render "child_template", assigns
      render SomeOtherView, "child_template", assigns

  If the other template has the `.leex` extension, LiveView change tracking
  will also work across templates.

  When rendering a child template, any of the events bound in the child
  template will be sent to the parent LiveView. In other words, similar to
  regular Phoenix templates, a regular `render` call does not start another
  LiveView. This means `render` is useful to sharing markup between views.

  One option to address this problem is to render a child LiveView inside a
  parent LiveView by calling `live_render/3` instead of `render/3` from the
  LiveView template. This child LiveView runs in a completely separate process
  than the parent, with its own `mount` and `handle_event` callbacks. If a
  child LiveView crashes, it won't affect the parent. If the parent crashes,
  all children are terminated.

  When rendering a child LiveView, the `:id` option is required to uniquely
  identify the child. A child LiveView will only ever be rendered and mounted
  a single time, provided its ID remains unchanged. Updates to a child session
  will be merged on the client, but not passed back up until either a crash and
  re-mount or a connection drop and recovery. To force a child to re-mount with
  new session data, a new ID must be provided.

  Given a LiveView runs on its own process, it is an excellent tool for creating
  completely isolated UI elements, but it is a slightly expensive abstraction if
  all you want is to compartmentalize markup and events. For example, if you are
  showing a table with all users in the system, and you want to compartmentalize
  this logic, using a separate `LiveView`, each with its own process, would likely
  be too expensive. For these cases, LiveView provides `Phoenix.LiveComponent`,
  which are rendered using `live_component/3`:

      <%= live_component(@socket, UserComponent, id: user.id, user: user) %>

  Components have their own `mount` and `handle_event` callbacks, as well as their
  own state with change tracking support. Components are also lightweight as they
  "run" in the same process as the parent `LiveView`. However, this means an error
  in a component would cause the whole view to fail to render. See
  `Phoenix.LiveComponent` for a complete rundown on components.

  To sum it up:

    * `render` - compartmentalizes markup
    * `live_component` - compartmentalizes state, markup, and events
    * `live_render` - compartmentalizes state, markup, events, and error isolation

  ## Live Layouts

  Your LiveView will be rendered within the layout specified in your Plug pipeline,
  such as the default app layout. Assigns defined during `mount` of the root LiveView
  are accessible in the layout, but the app layout is never updated after the initial
  render. For a live layout, you must specify an additional layout to use with your
  LiveView. For example, your regular `app.html` template may display a `@new_message_count`
  notification, like this:

      <!DOCTYPE html>
      <html lang="en">
        <head>
          <title><%= @page_title %></title>
        </head>
        <body>
          <div>
            <nav>
              ...
              Messages (<%= @new_message_count %>)
            </nav>
            <%= render @view_module, @view_template, assigns %>
          </div>
        </body>
      </html>

  To allow the `@new_message_count` to be be updated by your LiveView, you can
  move the dynamic content inside a sub-layout, such as `app_web/templates/layout/live.html.leex`.

  First, you would update your `app.html` layout to keep only the barebones HTML
  structure:

      <!DOCTYPE html>
      <html lang="en">
        <head>
          <title>...</title>
          <script>...</script>
        </head>
        <body>
          <%= render @view_module, @view_template, assigns %>
        </body>
      </html>

  Next, define a new `live.html.leex` layout with the dynamic content,
  followed by a render of the inner `@live_view_module`:

      <nav>
        ...
        Messages (<%= @new_message_count %>)
      </nav>
      <%= @live_view_module.render(assigns) %>

  Finally, update your LiveView to pass the `:layout` option to `use Phoenix.LiveView`:

      use Phoenix.LiveView, layout: {AppWeb.LayoutView, "live.html"}

  Or alternatively, you can provide the `:layout` dynamically as an option in mount:

        def mount(_params, _session, socket) do
          socket = assign(socket, new_message_count: 0)
          {:ok, socket, layout: {AppWeb.LayoutView, "live.html"}}
        end

        def handle_info({:new_messages, count}, socket) do
          {:noreply, assign(socket, new_message_count: count)}
        end
      end

  *Note*: The layout will be wrapped by the LiveView's `:container` tag.

  ### Updating the HTML document title

  Because the main layout from the Plug pipeline is rendered outside of LiveView,
  the contents cannot be dynamically changed. The one exception is the `<title>`
  of the HTML document. Phoenix LiveView special cases the `@page_title` assign
  to allow dynamically updating the title of the page, which is useful when
  using live navigation, or annotating the browser tab with a notification.
  For example, to update the user's notification count in the browser's title bar,
  first set the `page_title` assign on mount:

        def mount(_params, _session, socket) do
          socket = assign(socket, page_title: "Latest Posts")
          {:ok, socket}
        end

  Then access `@page_title` in the app layout:

      <title><%= @page_title %></title>

  Now, although the app layout is not updated by LiveView, by simply assigning
  to `page_title`, LiveView knows you want the title to be updated:

      def handle_info({:new_messages, count}, socket) do
        {:noreply, assign(socket, page_title: "Latest Posts (#{count} new)")}
      end

  *Note*: If you find yourself needing to dynamically patch other parts of the
  base layout, such as injecting new scripts or styles into the `<head>` during
  live navigation, *a true page navigation should be used instead*. Assigning
  the `@page_title` updates the `document.title` directly, and therefore cannot
  be used to update any other part of the base layout, even if the base layout
  references the assign.

  ## Rate limiting events with Debounce and Throttle

  All events can be rate-limited on the client by using the
  `phx-debounce` and `phx-throttle` bindings, with the following behavior:

    * `phx-debounce` - Accepts either a string integer timeout value, or `"blur"`.
      When an int is provided, delays emitting the event by provided milliseconds.
      When `"blur"` is provided, delays emitting an input's change event until the
      field is blurred by the user.
    * `phx-throttle` - Accepts an integer timeout value to throttle the event in milliseconds.
      Unlike debounce, throttle will immediately emit the event, then rate limit the
      event at one event per provided timeout.

  For example, to avoid validating an email until the field is blurred, while validating
  the username at most every 2 seconds after a user changes the field:

      <form phx-change="validate" phx-submit="save">
        <input type="text" name="user[email]" phx-debounce="blur"/>
        <input type="text" name="user[username]" phx-debounce="2000"/>
      </form>

  And to rate limit a button click to once every second:

      <button phx-click="search" phx-throttle="1000">Search</button>

  Likewise, you may throttle held-down keydown:

      <div phx-window-keydown="keydown" phx-throttle="500">
        ...
      </div>

  Unless held-down keys are required, a better approach is generally to use
  `phx-keyup` bindings which only trigger on key up, thereby being self-limiting.
  However, `phx-keydown` is useful for games and other usecases where a constant
  press on a key is desired. In such cases, throttle should always be used.

  ### Debounce and Throttle special behavior

  The following specialized behavior is performed for forms and keydown bindings:

    * When a `phx-submit`, or a `phx-change` for a different
      input is triggered, any current debounce or throttle timers are reset for
      existing inputs.
    * A `phx-keydown` binding is only throttled for key repeats. Unique keypresses
      back-to-back will dispatch the pressed key events.

  ## DOM patching and temporary assigns

  A container can be marked with `phx-update`, allowing the DOM patch
  operations to avoid updating or removing portions of the LiveView, or to append
  or prepend the updates rather than replacing the existing contents. This
  is useful for client-side interop with existing libraries that do their
  own DOM operations. The following `phx-update` values are supported:

    * `replace` - the default operation. Replaces the element with the contents
    * `ignore` - ignores updates to the DOM regardless of new content changes
    * `append` - append the new DOM contents instead of replacing
    * `prepend` - prepend the new DOM contents instead of replacing

  When using `phx-update`, a unique DOM ID must always be set in the
  container. If using "append" or "prepend", a DOM ID must also be set
  for each child. When appending or prepending elements containing an
  ID already present in the container, LiveView will replace the existing
  element with the new content instead appending or prepending a new
  element.

  The "ignore" behaviour is frequently used when you need to integrate
  with another JS library. The "append" and "prepend" feature is often
  used with "Temporary assigns" to work with large amounts of data. Let's
  learn more.

  ### Temporary assigns

  By default, all LiveView assigns are stateful, which enables change
  tracking and stateful interactions. In some cases, it's useful to mark
  assigns as temporary, meaning they will be reset to a default value after
  each update, allowing otherwise large, but infrequently updated values
  to be discarded after the client has been patched.

  Imagine you want to implement a chat application with LiveView. You
  could render each message like this:

      <%= for message <- @messages do %>
        <p><span><%= message.username %>:</span> <%= message.text %></p>
      <% end %>

  Every time there is a new message, you would append it to the `@messages`
  assign and re-render all messages.

  As you may suspect, keeping the whole chat conversation in memory
  and resending it on every update would be too expensive, even with
  LiveView smart change tracking. By using temporary assigns and phx-update,
  we don't need to keep any message in memory and send messages to be
  appended to the UI only when there are new messages.

  To do so, the first step is to mark which assigns are temporary and
  what are the value they should be reset to on mount:

      def mount(_params, _session, socket) do
        socket = assign(socket, :messages, load_last_20_messages())
        {:ok, socket, temporary_assigns: [messages: []]}
      end

  On mount we also load the initial amount of messages we want to
  send. After the initial render, the initial batch of messages will
  be reset back to an empty list.

  Now, whenever there are one or more new messages, we will assign
  only the new messages to `@messages`:

      socket = assign(socket, :messages, new_messages)

  In the template, we want to wrap all of the messages in a container
  and tag this content with phx-update. Remember must also add an ID
  to the container as well as to each child:

      <div id="chat-messages" phx-update="append">
        <%= for message <- @messages do %>
          <p id="<%= message.id %>">
            <span><%= message.username %>:</span> <%= message.text %>
          </p>
        <% end %>
      </div>

  And now, once the client receives new messages, it knows it shouldn't
  replace the old content, but rather append to it.

  ## Live navigation

  The `live_link/2` and `live_redirect/2` functions allow page navigation
  using the [browser's pushState API](https://developer.mozilla.org/en-US/docs/Web/API/History_API).
  With live navigation, the page is updated without a full page reload.

  To use live navigation, simply replace your existing `Phoenix.HTML.link/3`
  and `Phoenix.LiveView.redirect/2` calls with their `live` counterparts.

  For example, in a template you may write:

      <%= live_link "next", to: Routes.live_path(@socket, MyLive, @page + 1) %>

  or in a LiveView:

      {:noreply, live_redirect(socket, to: Routes.live_path(socket, MyLive, page + 1))}

  When a live link is clicked, the following control flow occurs:

    * if the route belongs to the existing root LiveView and the LiveView is
      defined in your application's router, the `c:handle_params/3` callback
      is invoked without mounting a new LiveView. See the next section.

    * if the route belongs to a different LiveView than the currently running
      root, then the existing root LiveView is shut down, and an Ajax request is
      made to request the necessary information about the new LiveView, without
      performing a full static render (which reduces latency and improves
      performance). Once information is retrieved, the new LiveView is mounted.

  `live_link/3` and `live_redirect/2` are by default only available in LiveViews
  defined at the router with the `live/3` macro.

  ### `handle_params/3`

  The `c:handle_params/3` callback is invoked after `c:mount/3`. It receives the
  request parameters as first argument, the url as second, and the socket as third.

  The parameters given to `c:handle_params/3` are the same as the one given to
  `c:mount/3`. So how do you decide which callback to use to load data? Generally
  speaking, data should always be loaded on `c:mount/3`. Only the params that
  can be changed via `live_link/3` or `live_redirect/2` must be loaded on
  `c:handle_params/3`. As any other `handle_*` callback, changes to
  the state inside `c:handle_params/3` will trigger a server render.

  To avoid building a new LiveView whenever a live link is clicked or whenever
  a live redirect happens, LiveView also invokes `c:handle_params/3` on an
  existing LiveView when performing live navigation as long as:

    1. you are navigating to the same root live view you are currently on
    2. said LiveView is defined in your router

  For example, imagine you have a `UserTable` LiveView to show all users in
  the system and you define it in the router as:

      live "/users", UserTable

  Now to add live sorting, you could do:

      <%= live_link "Sort by name", to: Routes.live_path(@socket, UserTable, %{sort_by: "name"}) %>

  When clicked, since we are navigating to the current LiveView, `c:handle_params/3`
  will be invoked. Remember you should never trust received params, so we can use
  the callback to validate the user input and change the state accordingly:

      def handle_params(params, _uri, socket) do
        case params["sort_by"] do
          sort_by when sort_by in ~w(name company) ->
            {:noreply, socket |> assign(:sort_by, sort) |> recompute_users()}
          _ ->
            {:noreply, socket}
        end
      end

  ### Replace page address

  LiveView also allows the current browser URL to be replaced. This is useful when you
  want certain events to change the URL but without polluting the browser's history.
  For example, imagine there is a form that changes some page state when submitted.
  If those changes are not persisted in a database or similar, as soon as the user
  refreshes the page, navigates away, or shares the URL with someone else, said changes
  will be lost.

  To address this, users can invoke `live_redirect/2`. The idea is, once the form
  data is received, we do not change the state, instead we perform a live redirect to
  ourselves with the new URL. Since we are navigating to ourselves, `c:handle_params/3`
  will be called with the new parameters, which we can then use to compute state and
  re-render the page.

  For example, let's change the "sort by" example from the previous page to perform
  sorting through a form. In other words, instead of sorting by clicking a "Sort by
  name" button, we will have a form with 2 radio buttons, that allows you to choose
  between sorting by name or company.

  Once the form is submitted, we can compute the new URL:

      def handle_event("sorting", params, socket) do
        {:noreply, live_redirect(socket, to: Routes.live_path(socket, __MODULE__, params))}
      end

  Now with a `c:handle_params/3` implementation similar to the one in the previous
  section, we will recompute the users based on the new `params` and perform a server
  render if there are any changes.

  Both `live_link/2` and `live_redirect/2` support the `replace: true` option. This
  option can be used when you want to change the current url without polluting the
  browser's history:

      def handle_event("sorting", params, socket) do
        {:noreply, live_redirect(socket, to: Routes.live_path(socket, __MODULE__, params), replace: true)}
      end

  ## Disconnecting all instances of a given live user

  It is possible to identify all LiveView sockets by setting a "live_socket_id"
  in the session. For example, when signing in a user, you could do:

      conn
      |> put_session(:current_user_id, user.id)
      |> put_session(:live_socket_id, "users_sockets:#{user.id}")

  Now all LiveView sockets will be identified and listening to the given
  `live_socket_id`. You can disconnect all live users identified by said
  ID by broadcasting on the topic:

      MyApp.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})

  It is the same mechanism provided by `Phoenix.Socket`, so you can use the
  same approach to disconnect live users and regular channels.

  ## JavaScript Client Specific

  As seen earlier, you start by instantiating a single LiveSocket instance to
  enable LiveView client/server interaction, for example:

      import {Socket} from "phoenix"
      import LiveSocket from "phoenix_live_view"

      let liveSocket = new LiveSocket("/live", Socket)
      liveSocket.connect()

  All options are passed directly to the `Phoenix.Socket` constructor,
  except for the following LiveView specific options:

    * `bindingPrefix` - the prefix to use for phoenix bindings. Defaults `"phx-"`
    * `params` - the `connect_params` to pass to the view's mount callback. May be
      a literal object or closure returning an object. When a closure is provided,
      the function receives the view's phx-view name.
    * `hooks` – a reference to a user-defined hooks namespace, containing client
      callbacks for server/client interop. See the interop section below for details.

  ### Forms and input handling

  The JavaScript client is always the source of truth for current
  input values. For any given input with focus, LiveView will never
  overwrite the input's current value, even if it deviates from
  the server's rendered updates. This works well for updates where
  major side effects are not expected, such as form validation errors,
  or additive UX around the user's input values as they fill out a form.
  For these use cases, the `phx-change` input does not concern itself
  with disabling input editing while an event to the server is inflight.
  When a `phx-change` event is sent to the server, a `"_target"` param
  will be in the root payload containing the keyspace of the input name
  which triggered the change event. For example, if the following input
  triggered a change event:

      <input name="user[username]"/>

  The server's `handle_event/3` would receive a payload:

      %{"_target" => ["user", "username"], "user" => %{"name" => "Name"}}

  The `phx-submit` event is used for form submissions where major side effects
  typically happen, such as rendering new containers, calling an external
  service, or redirecting to a new page.

  On submission of a form bound with a `phx-submit` event:

    1. The form's inputs are set to `readonly`
    2. Any submit button on the form is disabled
    3. The form receives the `"phx-loading"` class

  On completion of server processing of the `phx-submit` event:

    1. The submitted form is reactivated and loses the `"phx-loading"` class
    2. The last input with focus is restored (unless another input has received focus)
    3. Updates are patched to the DOM as usual

  To handle latent form submissions, any HTML tag can be annotated with
  `phx-disable-with`, which swaps the element's `innerText` with the provided
  value during form submission. For example, the following code would change
  the "Save" button to "Saving...", and restore it to "Save" on acknowledgment:

      <button type="submit" phx-disable-with="Saving...">Save</button>

  ### Loading state and errors

  By default, the following classes are applied to the LiveView's parent
  container:

    - `"phx-connected"` - applied when the view has connected to the server
    - `"phx-disconnected"` - applied when the view is not connected to the server
    - `"phx-error"` - applied when an error occurs on the server. Note, this
      class will be applied in conjunction with `"phx-disconnected"` if connection
      to the server is lost.

  ### JS Interop and client-controlled DOM

  To handle custom client-side javascript when an element is added, updated,
  or removed by the server, a hook object may be provided with the following
  life-cycle callbacks:

    * `mounted` - the element has been added to the DOM and its server
      LiveView has finished mounting
    * `beforeUpdate` - the element is about to be updated in the DOM.
      *Note*: any call here must be synchronous as the operation cannot
      be deferred or cancelled.
    * `updated` - the element has been updated in the DOM by the server
    * `beforeDestroy` - the element is about to be removed from the DOM.
      *Note*: any call here must be synchronous as the operation cannot
      be deferred or cancelled.
    * `destroyed` - the element has been removed from the page, either
      by a parent update, or by the parent being removed entirely
    * `disconnected` - the element's parent LiveView has disconnected from the server
    * `reconnected` - the element's parent LiveView has reconnected to the server

  The above life-cycle callbacks have in-scope access to the following attributes:

    * `el` - attribute referencing the bound DOM node,
    * `viewName` - attribute matching the dom node's phx-view value
    * `pushEvent(event, payload)` - method to push an event from the client to the LiveView server
    * `pushEventTo(selector, event, payload)` - method to push targeted events from the client
      to LiveViews and LiveComponents.

  For example, the markup for a controlled input for phone-number formatting could be written
  like this:

      <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook="PhoneNumber" />

  Then a hook callback object could be defined and passed to the socket:

      let Hooks = {}
      Hooks.PhoneNumber = {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }

      let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks})
      ...

  *Note*: when using `phx-hook`, a unique DOM ID must always be set.

  ## Endpoint configuration

  LiveView accepts the following configuration in your endpoint under
  the `:live_view` key:

    * `:signing_salt` (required) - the salt used to sign data sent
      to the client

    * `:hibernate_after` (optional) - the idle time in milliseconds allowed in
    the LiveView before compressing its own memory and state.
    Defaults to 15000ms (15 seconds)
  '''

  alias Phoenix.LiveView.Socket

  @doc """
  The LiveView entry-point.

  For each LiveView in the root of a template, `c:mount/3` is invoked twice:
  once to do the initial page load and again to establish the live socket.

  It expects three parameters:

    * `params` - a map of string keys which contain public information that
      can be set by the user. The map contains the query params as well as any
      router path parameter. If the LiveView was not mounted at the router,
      this argument is the atom `:not_mounted_at_router`
    * `session` - the connection session
    * `socket` - the LiveView socket

  It must return either `{:ok, socket}` or `{:ok, socket, options}`, where
  `options` is one of:

    * `:temporary_assigns` - a keyword list of assigns that are temporary
      and must be reset to their value after every render

    * `:layout` - the optional layout to be used by the LiveView

  """
  @callback mount(Socket.unsigned_params() | :not_mounted_at_router, session :: map, socket :: Socket.t()) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @callback terminate(reason, socket :: Socket.t()) :: term
            when reason: :normal | :shutdown | {:shutdown, :left | :closed | term}

  @callback handle_params(Socket.unsigned_params(), uri :: String.t(), socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @callback handle_event(event :: binary, Socket.unsigned_params(), socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @callback handle_call(msg :: term, {pid, reference}, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, term, Socket.t()} | {:stop, Socket.t()}

  @callback handle_info(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @optional_callbacks mount: 3,
                      terminate: 2,
                      handle_params: 3,
                      handle_event: 3,
                      handle_call: 3,
                      handle_info: 2

  @doc """
  Uses LiveView in the current module to mark it a LiveView.

      use Phoenix.LiveView,
        namespace: MyAppWeb,
        container: {:tr, class: "colorized"},
        layout: {MyAppWeb.LayoutView, "live.html"}

  ## Options

    * `:namespace` - configures the namespace the `LiveView` is in
    * `:container` - configures the container the `LiveView` will be wrapped in
    * `:layout` - configures the layout the `LiveView` will be rendered in

  """
  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)
      import Phoenix.LiveView
      import Phoenix.LiveView.Helpers
      @behaviour Phoenix.LiveView
      @before_compile Phoenix.LiveView

      @doc false
      @__live__ Phoenix.LiveView.__live__(__MODULE__, opts)
      def __live__, do: @__live__
    end
  end

  # TODO: Remove once the deprecation period is over
  @doc false
  defmacro __before_compile__(env) do
    if Module.defines?(env.module, {:mount, 3}) or not Module.defines?(env.module, {:mount, 2}) do
      :ok
    else
      IO.warn(
        "mount(session, socket) is deprecated, please define mount(params, session, socket) instead",
        Macro.Env.stacktrace(env)
      )

      quote do
        def mount(_params, session, socket), do: mount(session, socket)
      end
    end
  end

  @doc false
  def __live__(module, opts) do
    container = opts[:container] || {:div, []}
    namespace = opts[:namespace] || module |> Module.split() |> Enum.take(1) |> Module.concat()
    name = module |> Atom.to_string() |> String.replace_prefix("#{namespace}.", "")

    layout =
      case opts[:layout] do
        {mod, template} when is_atom(mod) and is_binary(template) ->
          {mod, template}

        nil ->
          nil

        other ->
          raise ArgumentError,
                ":layout expects a tuple of the form {MyLayoutView, \"my_template.html\"}, " <>
                  "got: #{inspect(other)}"
      end

    %{container: container, name: name, kind: :view, module: module, layout: layout}
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
        def mount(_params, _session, socket) do
          if connected?(socket), do: :timer.send_interval(1000, self(), :tick)

          {:ok, assign(socket, date: :calendar.local_time())}
        end

        def handle_info(:tick, socket) do
          {:noreply, assign(socket, date: :calendar.local_time())}
        end
      end
  """
  def connected?(%Socket{connected?: connected?}), do: connected?

  @doc """
  Assigns a value into the socket only if it does not exist.

  Useful for lazily assigning values and referencing parent assigns.

  ## Referencing parent assigns

  When a LiveView is mounted in a disconnected state, the Plug.Conn assigns
  will be available for reference via `assign_new/3`, allowing assigns to
  be shared for the initial HTTP request. On connected mount, `assign_new/3`
  will be invoked, and the LiveView will use its session to rebuild the
  originally shared assign. Likewise, nested LiveView children have access
  to their parent's assigns on mount using `assign_new`, which allows
  assigns to be shared down the nested LiveView tree.

  ## Examples

      # controller
      conn
      |> assign(:current_user, user)
      |> LiveView.Controller.live_render(MyLive, session: %{"user_id" => user.id})

      # LiveView mount
      def mount(_params, %{"user_id" => user_id}, socket) do
        {:ok, assign_new(socket, :current_user, fn -> Accounts.get_user!(user_id) end)}
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
        assign_each(%{socket | private: private}, key, Map.get_lazy(assigns, key, func))

      %{} ->
        assign_each(socket, key, func.())
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

  @doc """
  See `assign/3`.
  """
  def assign(%Socket{} = socket, attrs) when is_map(attrs) or is_list(attrs) do
    Enum.reduce(attrs, socket, fn {key, val}, acc ->
      case Map.fetch(acc.assigns, key) do
        {:ok, ^val} -> acc
        {:ok, _old_val} -> assign_each(acc, key, val)
        :error -> assign_each(acc, key, val)
      end
    end)
  end

  defp assign_each(%Socket{assigns: assigns, changed: changed} = acc, key, val) do
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
      {:ok, val} -> assign(socket, [{key, func.(val)}])
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
  defdelegate put_flash(socket, kind, msg), to: Phoenix.LiveView.Utils

  @doc """
  Annotates the socket for redirect to a destination path.

  *Note*: LiveView redirects rely on instructing client
  to perform a `window.location` update on the provided
  redirect location.

  ## Options

    * `:to` - the path to redirect to. It must always be a local path
    * `:external` - an external path to redirect to
  """
  def redirect(%Socket{} = socket, opts) do
    assert_root_live_view!(socket, "redirect/2")

    url =
      cond do
        to = opts[:to] -> validate_local_url!(to, "redirect/2")
        external = opts[:external] -> external
        true -> raise ArgumentError, "expected :to or :external option in redirect/2"
      end

    put_redirect(socket, :redirect, %{to: url})
  end

  @doc """
  Annotates the socket for navigation without a page refresh.

  When navigating to a path which routes to your existing LiveView,
  the `handle_params/3` callback is immediately invoked in your existing
  LiveView process to handle the change of URL state. For live redirects
  to external LiveViews, the existing LiveView is shut down.

  ## Options

    * `:to` - the required path to link to. It must always be a local path
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  ## Examples

      {:noreply, live_redirect(socket, to: "/")}
      {:noreply, live_redirect(socket, to: "/", replace: true)}
  """
  def live_redirect(%Socket{} = socket, opts) do
    assert_root_live_view!(socket, "live_redirect/2")
    kind = if opts[:replace], do: :replace, else: :push
    to = Keyword.fetch!(opts, :to)
    validate_local_url!(to, "live_redirect/2")
    put_redirect(socket, :live, %{to: to, kind: kind})
  end

  defp put_redirect(%Socket{redirected: nil} = socket, :redirect, %{to: _} = opts) do
    %Socket{socket | redirected: {:redirect, opts}}
  end

  defp put_redirect(%Socket{redirected: nil} = socket, :live, %{to: _, kind: kind} = opts)
       when kind in [:push, :replace] do
    if child?(socket) do
      raise ArgumentError, """
      attempted to live_redirect from a nested child socket.

      Only the root parent LiveView can issue live redirects.
      """
    else
      %Socket{socket | redirected: {:live, opts}}
    end
  end

  defp put_redirect(%Socket{redirected: to} = _socket, _kind, _opts) do
    raise ArgumentError, "socket already prepared to redirect with #{inspect(to)}"
  end

  defp child?(%Socket{parent_pid: pid}), do: is_pid(pid)

  @invalid_local_url_chars ["\\"]

  defp validate_local_url!("//" <> _ = to, where) do
    raise_invalid_local_url!(to, where)
  end

  defp validate_local_url!("/" <> _ = to, where) do
    if String.contains?(to, @invalid_local_url_chars) do
      raise ArgumentError, "unsafe characters detected for #{where} in URL #{inspect(to)}"
    else
      to
    end
  end

  defp validate_local_url!(to, where) do
    raise_invalid_local_url!(to, where)
  end

  defp raise_invalid_local_url!(to, where) do
    raise ArgumentError, "the :to option in #{where} expects a path but was #{inspect(to)}"
  end

  @doc """
  Accesses the connect params sent by the client for use on connected mount.

  Connect params are only sent when the client connects to the server and
  only remain available during mount. `nil` is returned when called in a
  disconnected state and a `RuntimeError` is raised if called after mount.

  ## Examples

      def mount(_params, _session, socket) do
        {:ok, assign(socket, width: get_connect_params(socket)["width"] || @width)}
      end
  """
  def get_connect_params(%Socket{private: private} = socket) do
    cond do
      connect_params = private[:connect_params] ->
        if connected?(socket), do: connect_params, else: nil

      child?(socket) ->
        raise RuntimeError, """
        attempted to read connect_params from a nested child LiveView #{inspect(socket.view)}.

        Only the root LiveView has access to connect params.
        """

      true ->
        raise RuntimeError, """
        attempted to read connect_params outside of #{inspect(socket.view)}.mount/3.

        connect_params only exist while mounting. If you require access to this information
        after mount, store the state in socket assigns.
        """
    end
  end

  @doc """
  Asynchronously updates a component with new assigns.

  Requires a stateful component with a matching `:id` to send
  the update to. Following the optional `preload/1` callback being invoked,
  the updated values are merged with the component's assigns and `update/2`
  is called for the updated component(s).

  While a component may always be updated from the parent by updating some
  parent assigns which will re-render the child, thus invoking `update/2` on
  the child component, `send_update/2` is useful for updating a component
  that entirely manages its own state, as well as messaging between components.

  ## Examples

      def handle_event("cancel-order", _, socket) do
        ...
        send_update(Cart, id: "cart", status: "cancelled")
        {:noreply, socket}
      end
  """
  def send_update(module, assigns) do
    assigns = Enum.into(assigns, %{})

    id =
      assigns[:id] ||
        raise ArgumentError, "missing required :id in send_update. Got: #{inspect(assigns)}"

    Phoenix.LiveView.Channel.send_update(module, id, assigns)
  end

  defp assert_root_live_view!(%{parent_pid: nil}, _context),
    do: :ok

  defp assert_root_live_view!(_, context),
    do: raise(ArgumentError, "cannot invoke #{context} from a child LiveView")
end

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

  LiveView is first rendered statically as part of regular
  HTTP requests, which provides quick times for "First Meaningful
  Paint", in addition to helping search and indexing engines.
  Then a persistent connection is established between client and
  server. This allows LiveView applications to react faster to user
  events as there is less work to be done and less data to be sent
  compared to stateless requests that have to authenticate, decode, load,
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
      using the excellent live navigation feature set.
      This reduces the amount of data sent over the wire,
      gives developers full control over the LiveView
      life-cycle, while controlling how the browser
      tracks those changes in state;

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

  You begin by rendering a LiveView typically from your router.
  When LiveView is first rendered, the `mount/3` callback is invoked
  with the current params, the current session and the LiveView socket.
  As in a regular request, `params` contains public data that can be
  modified by the user. The `session` always contains private data set
  by the application itself. The `mount/3` callback wires up socket
  assigns necessary for rendering the view. After mounting, `render/1`
  is invoked and the HTML is sent as a regular HTML response to the
  client.

  After rendering the static page, LiveView connects from the client to the server
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

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
      let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
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

  ## Collocating templates

  In the examples above, we have placed the template directly inside the
  LiveView:

      defmodule AppWeb.ThermostatLive do
        use Phoenix.LiveView

        def render(assigns) do
          ~L"""
          Current temperature: <%= @temperature %>
          """
        end

  For larger templates, you can place them in a file in the same directory
  and same name as the LiveView. For example, if the file above is placed
  at `lib/my_app_web/live/thermostat_live.ex`, you can also remove the
  `render/1` definition above and instead put the template code at
  `lib/my_app_web/live/thermostat_live.html.leex`.

  Alternatively, you can keep the `render/1` callback but delegate to an
  existing `Phoenix.View` module in your application. For example:

      defmodule AppWeb.ThermostatLive do
        use Phoenix.LiveView

        def render(assigns) do
          Phoenix.View.render(AppWeb.PageView, "page.html", assigns)
        end
      end

  In all cases, each assign in the template will be accessible as `@assign`.

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

  First of all, change tracking can only track assigns. So for example,
  if you do something such as:

      <%= @post.the_whole_content %>

  If any other field besides `the_whole_content` in `@post` changes for any
  reason, `the_whole_content` will be sent downstream. Although this is not
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
  | [Click Events](#module-click-events) | `phx-click`, `phx-capture-click` |
  | [Focus/Blur Events](#module-focus-and-blur-events) | `phx-blur`, `phx-focus` |
  | [Form Events](#module-form-events) | `phx-change`, `phx-submit`, `data-phx-error-for`, `phx-disable-with` |
  | [Key Events](#module-key-events) | `phx-window-keydown`, `phx-window-keyup` |
  | [Rate Limiting](#module-rate-limiting-events-with-debounce-and-throttle) | `phx-debounce`, `phx-throttle` |
  | [DOM Patching](#module-dom-patching-and-temporary-assigns) | `phx-update` |
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

  The `phx-capture-click` event is just like `phx-click`, but instead of the click event
  being dispatched to the closest `phx-click` element as it bubbles up through the DOM, the event
  is dispatched as it propagates from the top of the DOM tree down to the target element. This is
  useful when wanting to bind click events without receiving bubbled events from child UI elements.
  Since capturing happens before bubbling, this can also be important for preparing or preventing
  behaviour that will be applied during the bubbling phase.

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

  The following window-level bindings are supported:

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
            {:noreply,
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
  persistence is attempted. On success, a `:noreply` tuple is returned and the
  socket is annotated for redirect with `Phoenix.LiveView.redirect/2` to
  the new user page, otherwise the socket assigns are updated with the errored
  changeset to be re-rendered for the client.

  *Note*: For proper form error tag updates, the error tag must specify which
  input it belongs to. This is accomplished with the `data-phx-error-for` attribute.
  Failing to add the `data-phx-error-for` attribute will result in displaying error
  messages for form fields that the user has not changed yet (e.g. required
  fields further down on the page.)

  For example, your `AppWeb.ErrorHelpers` may use this function:

      def error_tag(form, field) do
        form.errors
        |> Keyword.get_values(field)
        |> Enum.map(fn error ->
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
  submit events will be sent normally.

    <input type="number">

  This is known to have a plethora of problems including accessibility, large numbers
  are converted to exponential notation and scrolling can accidentally increase or
  decrease the number.

  As of early 2020, the following avoids these pitfalls and will likely serve your
  application's needs and users much better. According to https://caniuse.com/#search=inputmode,
  the following is supported by 90% of the global mobile market with Firefox yet to implement.

    <input type="text" inputmode="numeric" pattern="[0-9]*">


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
        "altKey" => false, "code" => "Escape", "ctrlKey" => false, "key" => "Escape",
        "location" => 0, "metaKey" => false, "repeat" => false, "shiftKey" => false
      }

  To determine which key has been pressed you should use `key` value. The
  available options can be found on
  [MDN](https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key/Key_Values)
  or via the [Key Event Viewer](https://w3c.github.io/uievents/tools/key-event-viewer.html).

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

  ### LiveView Specific Events

  The `lv:` event prefix supports LiveView specific features that are handled
  by LiveView without calling the user's `handle_event/3` callbacks. Today,
  the following events are supported:

    - `lv:clear-flash` – clears the flash when sent to the server. If a
    `phx-value-key` is provided, the specific key will be removed from the flash.

  For example:

      <p class="alert" phx-click="lv:clear-flash" phx-value-key="info">
        <%= live_flash(@flash, :info) %>
      </p>

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

  Given that a LiveView runs on its own process, it is an excellent tool for creating
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
  each update. This allows otherwise large but infrequently updated values
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
  we don't need to keep any messages in memory, and send messages to be
  appended to the UI only when there are new ones.

  To do so, the first step is to mark which assigns are temporary and
  what values they should be reset to on mount:

      def mount(_params, _session, socket) do
        socket = assign(socket, :messages, load_last_20_messages())
        {:ok, socket, temporary_assigns: [messages: []]}
      end

  On mount we also load the initial number of messages we want to
  send. After the initial render, the initial batch of messages will
  be reset back to an empty list.

  Now, whenever there are one or more new messages, we will assign
  only the new messages to `@messages`:

      socket = assign(socket, :messages, new_messages)

  In the template, we want to wrap all of the messages in a container
  and tag this content with phx-update. Remember, we must add an ID
  to the container as well as to each child:

      <div id="chat-messages" phx-update="append">
        <%= for message <- @messages do %>
          <p id="<%= message.id %>">
            <span><%= message.username %>:</span> <%= message.text %>
          </p>
        <% end %>
      </div>

  When the client receives new messages, it now knows to append to the
  old content rather than replace it.

  ## Live navigation

  LiveView provides functionality to allow page navigation using the
  [browser's pushState API](https://developer.mozilla.org/en-US/docs/Web/API/History_API).
  With live navigation, the page is updated without a full page reload.

  You can trigger live navigation in two ways:

    * From the client - this is done by replacing `Phoenix.HTML.link/2`
      by `Phoenix.LiveView.Helpers.live_patch/2` or
      `Phoenix.LiveView.Helpers.live_redirect/2`

    * From the server - this is done by replacing `redirect/2` calls
      by `push_patch/2` or `push_redirect/2`.

  For example, in a template you may write:

      <%= live_patch "next", to: Routes.live_path(@socket, MyLive, @page + 1) %>

  or in a LiveView:

      {:noreply, push_redirect(socket, to: Routes.live_path(socket, MyLive, page + 1))}

  The "patch" operations must be used when you want to navigate to the
  current LiveView, simply updating the URL and the current parameters,
  without mounting a new LiveView. When patch is used, the `c:handle_params/3`
  callback is invoked. See the next section for more information.

  The "redirect" operations must be used when you want to dismount the
  current LiveView and mount a new one. In those cases, the existing root
  LiveView is shutdown, and an Ajax request is made to request the necessary
  information about the new LiveView without performing a full static render
  (which reduces latency and improves performance). Once information is
  retrieved, the new LiveView is mounted. While redirecting, a `phx-disconnected`
  class is added to the root LiveView, which can be used to indicate to the
  user a new page is being loaded.

  `live_patch/2`, `live_redirect/2`, `push_redirect/2`, and `push_patch/2`
  only work for LiveViews defined at the router with the `live/3` macro.
  Once live navigation is triggered, the flash is automatically cleared.

  ### `handle_params/3`

  The `c:handle_params/3` callback is invoked after `c:mount/3`. It receives the
  request parameters as first argument, the url as second, and the socket as third.

  For example, imagine you have a `UserTable` LiveView to show all users in
  the system and you define it in the router as:

      live "/users", UserTable

  Now to add live sorting, you could do:

      <%= live_patch "Sort by name", to: Routes.live_path(@socket, UserTable, %{sort_by: "name"}) %>

  When clicked, since we are navigating to the current LiveView, `c:handle_params/3`
  will be invoked. Remember you should never trust the received params, so you must
  use the callback to validate the user input and change the state accordingly:

      def handle_params(params, _uri, socket) do
        socket =
          case params["sort_by"] do
            sort_by when sort_by in ~w(name company) -> assign(socket, sort_by: sort)
            _ -> socket
          end

        {:noreply, load_users(socket)}
      end

  As with other `handle_*` callback, changes to the state inside `c:handle_params/3`
  will trigger a server render.

  Note the parameters given to `c:handle_params/3` are the same as the ones given
  to `c:mount/3`. So how do you decide which callback to use to load data?
  Generally speaking, data should always be loaded on `c:mount/3`, since `c:mount/3`
  is invoked once per LiveView life-cycle. Only the params you expect to be changed
  via `live_patch/2` or `push_patch/2` must be loaded on `c:handle_params/3`.

  Furthermore, it is very important to not access the same parameters on both
  `c:mount/3` and `c:handle_params/3`. For example, do NOT do this:

      def mount(%{"organization_id" => org_id}, session, socket) do
        # do something with org_id
      end

      def handle_params(%{"organization_id" => org_id, "sort_by" => sort_by}, url, socket) do
        # do something with org_id and sort_by
      end

  If you do that, because `c:mount/3` is called once and `c:handle_params/3` multiple
  times, your state can get out of sync. So once a parameter is read on mount, it
  should not be read elsewhere. Instead, do this:

      def mount(%{"organization_id" => org_id}, session, socket) do
        # do something with org_id
      end

      def handle_params(%{"sort_by" => sort_by}, url, socket) do
        # do something with sort_by
      end

  ### Replace page address

  LiveView also allows the current browser URL to be replaced. This is useful when you
  want certain events to change the URL but without polluting the browser's history.
  This can be done by passing the `replace: true` option to any of the navigation helpers.

  ## Live Layouts

  When working with LiveViews, there is usually three layouts to be
  considered:

    * the root layout - this is a layout used by both LiveView and
      regular views

    * the app layout - this is the default application layout which
      is not included or used by LiveViews;

    * the live layout - this is the layout which wraps a LiveView and
      is rendered as part of the LiveView life-cycle

  Overall, those layouts are found in `templates/layouts` with the
  following names:

      * root.html.eex
      * app.html.eex
      * live.html.leex

  The "root" layout is shared by both "app" and "live" layout. The
  root layout must be defined in your router:

      plug :put_root_layout, {MyApp.LayoutView, :root}

  Alternatively, the layout can be passed to the `live` call:

      live "/dashboard", MyApp.Dashboard, layout: {MyApp.LayoutView, :root}

  If you want the "root" layout to only apply to LiveView, you can
  define it in a specific pipeline that is only used by LiveView
  routes.

  The "app" and "live" layout are often small and similar, but the
  "app" layout uses the `@conn`, as part of the regular request
  life-cycle, and the "live" layout is part of the LiveView and
  therefore has direct access to the `@socket`.

  For example, you can define a new `live.html.leex` layout with
  dynamic content. You must use `@inner_content` where the output
  of the actual template will be placed at:

      <p><%= live_flash(@flash, :notice) %></p>
      <p><%= live_flash(@flash, :error) %></p>
      <%= @inner_content %>

  To use the live layout, update your LiveView to pass the `:layout`
  option to `use Phoenix.LiveView`:

      use Phoenix.LiveView, layout: {AppWeb.LayoutView, "live.html"}

  The `:layout` option does not apply for LiveViews rendered within
  other LiveViews. If you are rendering child live views or if you
  want to opt-in to a layout only in certain occasions, use the
  `:layout` as an option in mount:

        def mount(_params, _session, socket) do
          socket = assign(socket, new_message_count: 0)
          {:ok, socket, layout: {AppWeb.LayoutView, "live.html"}}
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

  You can also use `Phoenix.LiveView.Helpers.live_title_tag/2` to support
  adding automatic prefix and suffix to the page title when rendered and
  on subsequent updates:

      <%= live_title_tag @page_title, prefix: "MyApp – " %>

  Now, although the app layout is not updated by LiveView, by simply assigning
  to `page_title`, LiveView knows you want the title to be updated:

      def handle_info({:new_messages, count}, socket) do
        {:noreply, assign(socket, page_title: "Latest Posts (#{count} new)")}
      end

  *Note*: If you find yourself needing to dynamically patch other parts of the
  base layout, such as injecting new scripts or styles into the `<head>` during
  live navigation, *then a regular, non-live, page navigation should be used
  instead*. Assigning the `@page_title` updates the `document.title` directly,
  and therefore cannot be used to update any other part of the base layout.

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

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
      let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
      liveSocket.connect()

  All options are passed directly to the `Phoenix.Socket` constructor,
  except for the following LiveView specific options:

    * `bindingPrefix` - the prefix to use for phoenix bindings. Defaults `"phx-"`
    * `params` - the `connect_params` to pass to the view's mount callback. May be
      a literal object or closure returning an object. When a closure is provided,
      the function receives the view's phx-view name.
    * `hooks` – a reference to a user-defined hooks namespace, containing client
      callbacks for server/client interop. See the interop section below for details.

  ### Debugging Client Events

  To aid debugging on the client when troubleshooting issues, the `enableDebug()`
  and `disableDebug()` functions are exposed on the `LiveSocket` JavaScript instance.
  Calling `enableDebug()` turns on debug logging which includes LiveView life-cycle and
  payload events as they come and go from client to server. In practice, you can expose
  your instance on `window` for quick access in the browser's web console, for example:

      // app.js
      let liveSocket = new LiveSocket(...)
      liveSocket.connect()
      window.liveSocket = liveSocket

      // in the browser's web console
      >> liveSocket.enableDebug()

  The debug state uses the browser's built-in `sessionStorage`, so it will remain in effect
  for as long as your browser session lasts.

  ### Simulating Latency

  Proper handling of latency is critical for good UX. LiveView's CSS loading states allow
  the client to provide user feedback while awaiting a server response. In development,
  near zero latency on localhost does not allow latency to be easily represented or tested,
  so LiveView includes a latency simulator with the JavaScript client to ensure your
  application provides a pleasant experience. Like the `enableDebug()` function above,
  the `LiveSocket` instance includes `enableLatencySim(milliseconds)` and `disableLatencySim()`
  functions which apply throughout the current browser sesssion. The `enableLatencySim` function
  accepts an integer in milliseconds for the round-trip-time to the server. For example:

      // app.js
      let liveSocket = new LiveSocket(...)
      liveSocket.connect()
      window.liveSocket = liveSocket

      // in the browser's web console
      >> liveSocket.enableLatencySim(1000)
      [Log] latency simulator enabled for the duration of this browser session.
            Call disableLatencySim() to disable

  ### Forms and input handling

  The JavaScript client is always the source of truth for current
  input values. For any given input with focus, LiveView will never
  overwrite the input's current value, even if it deviates from
  the server's rendered updates. This works well for updates where
  major side effects are not expected, such as form validation errors,
  or additive UX around the user's input values as they fill out a form.
  For these use cases, the `phx-change` input does not concern itself
  with disabling input editing while an event to the server is in flight.
  When a `phx-change` event is sent to the server the input tag and parent
  form tag receive the `phx-change-loading` css class, then the payload is
  pushed to the server with a `"_target"` param in the root payload
  containing the keyspace of the input name which triggered the change event.
  For example, if the following input triggered a change event:

      <input name="user[username]"/>

  The server's `handle_event/3` would receive a payload:

      %{"_target" => ["user", "username"], "user" => %{"username" => "Name"}}

  The `phx-submit` event is used for form submissions where major side effects
  typically happen, such as rendering new containers, calling an external
  service, or redirecting to a new page.

  On submission of a form bound with a `phx-submit` event:

    1. The form's inputs are set to `readonly`
    2. Any submit button on the form is disabled
    3. The form receives the `"phx-submit-loading"` class

  On completion of server processing of the `phx-submit` event:

    1. The submitted form is reactivated and loses the `"phx-submit-loading"` class
    2. The last input with focus is restored (unless another input has received focus)
    3. Updates are patched to the DOM as usual

  To handle latent form submissions, any HTML tag can be annotated with
  `phx-disable-with`, which swaps the element's `innerText` with the provided
  value during form submission. For example, the following code would change
  the "Save" button to "Saving...", and restore it to "Save" on acknowledgment:

      <button type="submit" phx-disable-with="Saving...">Save</button>

  ### Form Recovery following crashes or disconnects

  By default, all forms marked with `phx-change` will recover input values
  automatically after the user has reconnected or the LiveView has remounted
  after a crash. This is achieved by the client triggering the same `phx-change`
  to the server as soon as the mount has been completed. For most use cases,
  this is all you need and form recovery will happen without consideration. In some cases,
  where forms are built step-by-step in a stateful fashion, it may require extra recovery
  handling on the server outside of your existing `phx-change` callback code. To enable
  specialized recovery, provide a `phx-auto-recover` binding on the form to
  specify a different event to trigger for recovery, which will receive the form params
  as usual. For example, imagine a LiveView wizard form where the form is stateful and
  built based on what step the user is on and by prior selections:

      <form phx-change="validate_wizard_step" phx-auto-recover="recover_wizard">

  On the server, the `"validate_wizard_step"` event is only concerned with the current client
  form data, but the server maintains the entire state of the wizard. To recover in this
  scenario, you can specify a recovery event, such as `"recover_wizard"` above, which
  would wire up to the following server callbacks in your LiveView:

      def handle_event("validate_wizard_step", params, socket) do
        # regular validations for current step
        {:noreply, socket}
      end

      def handle_event("recover_wizard", params, socket) do
        # rebuild state based on client input data up to the current step
        {:noreply, socket}
      end

  To forgo automatic form recovery, set `phx-auto-recover="ignore"`.

  ### Loading state and errors

  By default, the following classes are applied to the LiveView's parent
  container:

    - `"phx-connected"` - applied when the view has connected to the server
    - `"phx-disconnected"` - applied when the view is not connected to the server
    - `"phx-error"` - applied when an error occurs on the server. Note, this
      class will be applied in conjunction with `"phx-disconnected"` if connection
      to the server is lost.

  All `phx-` event bindings apply their own css classes when pushed. For example
  the following markup:

      <button phx-click="clicked" phx-window-keydown="key">...</button>

  On click, would receive the `phx-click-loading` class, and on keydown would receive
  the `phx-keydown-loading` class. The css loading classes are maintained until an
  acknowledgement is received on the client for the pushed event.

  In the case of forms, when a `phx-change` is sent to the server, the input element
  which emitted the change receives the `phx-change-loading` class, along with the
  parent form tag. The following events receive css loading classes:

    - `phx-click` - `phx-click-loading`
    - `phx-change` - `phx-change-loading`
    - `phx-submit` - `phx-submit-loading`
    - `phx-focus` - `phx-focus-loading`
    - `phx-blur` - `phx-blur-loading`
    - `phx-window-keydown` - `phx-keydown-loading`
    - `phx-window-keyup` - `phx-keyup-loading`

  For live page navigation via `live_redirect` and `live_patch`, as well as form
  submits via `phx-submit`, the JavaScript events `"phx:page-loading-start"` and
  `"phx:page-loading-stop"` are dispatched on window. Additionally, any `phx-`
  event may dispatch page loading events by annotating the DOM element with
  `phx-page-loading`. This is useful for showing main page loading status, for example:

      // app.js
      import NProgress from "nprogress"
      window.addEventListener("phx:page-loading-start", info => NProgress.start())
      window.addEventListener("phx:page-loading-stop", info => NProgress.done())

  The `info` object will contain a `kind` key, with values one of:

    - `"redirect"` - the event was triggered by a redirect
    - `"patch"` - the event was triggered by a patch
    - `"initial"` - the event was triggered by initial page load
    - `"element"` - the event was triggered by a `phx-` bound element, such as `phx-click`

  For all kinds of page loading events, all but `"element"` will receive an additional `to`
  key in the info metadata pointing to the href associated with the page load.

  In the case of an `"element"` page loading, the info will contain a `"target"` key containing
  the DOM element which triggered the page loading state.

  ### JS Interop and client-controlled DOM

  To handle custom client-side JavaScript when an element is added, updated,
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

      let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, ...})
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
  @callback mount(
              Socket.unsigned_params() | :not_mounted_at_router,
              session :: map,
              socket :: Socket.t()
            ) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @callback terminate(reason, socket :: Socket.t()) :: term
            when reason: :normal | :shutdown | {:shutdown, :left | :closed | term}

  @callback handle_params(Socket.unsigned_params(), uri :: String.t(), socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @callback handle_event(event :: binary, Socket.unsigned_params(), socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @callback handle_call(msg :: term, {pid, reference}, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, term, Socket.t()}

  @callback handle_info(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}

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
    quote bind_quoted: [opts: opts] do
      import Phoenix.LiveView
      import Phoenix.LiveView.Helpers
      @behaviour Phoenix.LiveView
      @before_compile Phoenix.LiveView.Renderer

      @doc false
      def __live__, do: unquote(Macro.escape(Phoenix.LiveView.__live__(__MODULE__, opts)))
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
    validate_assign_key!(key)

    case socket do
      %{assigns: %{^key => _}} ->
        socket

      %{private: %{assign_new: {assigns, keys}}} ->
        # It is important to store the keys even if they are not in assigns
        # because maybe the controller doesn't have it but the view does.
        socket = put_in(socket.private.assign_new, {assigns, [key | keys]})
        Phoenix.LiveView.Utils.force_assign(socket, key, Map.get_lazy(assigns, key, func))

      %{} ->
        Phoenix.LiveView.Utils.force_assign(socket, key, func.())
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
    validate_assign_key!(key)
    Phoenix.LiveView.Utils.assign(socket, key, value)
  end

  @doc """
  See `assign/3`.
  """
  def assign(%Socket{} = socket, attrs) when is_map(attrs) or is_list(attrs) do
    Enum.reduce(attrs, socket, fn {key, value}, acc ->
      validate_assign_key!(key)
      Phoenix.LiveView.Utils.assign(acc, key, value)
    end)
  end

  defp validate_assign_key!(:flash) do
    raise ArgumentError,
          ":flash is a reserved assign by LiveView and it cannot be set directly. " <>
            "Use the appropriate flash functions instead."
  end

  defp validate_assign_key!(_key), do: :ok

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

  *Note*: the `Phoenix.Router.fetch_live_flash` plug must be plugged in
  your browser's pipeline in place of `fetch_flash` to be supported,
  for example:

      import Phoenix.LiveView.Router

      pipeline :browser do
        ...
        plug :fetch_live_flash
      end

  ## Examples

      iex> put_flash(socket, :info, "It worked!")
      iex> put_flash(socket, :error, "You can't access that page")
  """
  defdelegate put_flash(socket, kind, msg), to: Phoenix.LiveView.Utils

  @doc """
  Clears the flash.

  ## Examples

      iex> clear_flash(socket)
  """
  defdelegate clear_flash(socket), to: Phoenix.LiveView.Utils

  @doc """
  Clears a key from the flash.

  ## Examples

      iex> clear_flash(socket, :info)
  """
  defdelegate clear_flash(socket, key), to: Phoenix.LiveView.Utils

  @doc """
  Annotates the socket for redirect to a destination path.

  *Note*: LiveView redirects rely on instructing client
  to perform a `window.location` update on the provided
  redirect location. The whole page will be reloaded and
  all state will be discarded.

  ## Options

    * `:to` - the path to redirect to. It must always be a local path
    * `:external` - an external path to redirect to
  """
  def redirect(%Socket{} = socket, opts) do
    url =
      cond do
        to = opts[:to] -> validate_local_url!(to, "redirect/2")
        external = opts[:external] -> external
        true -> raise ArgumentError, "expected :to or :external option in redirect/2"
      end

    put_redirect(socket, {:redirect, %{to: url}})
  end

  @doc """
  Annotates the socket for navigation within the current LiveView.

  When navigating to the current LiveView, `c:handle_params/3` is
  immediately invoked to handle the change of params and URL state.
  Then the new state is pushed to the client, without reloading the
  whole page. For live redirects to another LiveView, use
  `push_redirect/2`.

  ## Options

    * `:to` - the required path to link to. It must always be a local path
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  ## Examples

      {:noreply, push_patch(socket, to: "/")}
      {:noreply, push_patch(socket, to: "/", replace: true)}

  """
  def push_patch(%Socket{} = socket, opts) do
    %{to: to} = opts = push_opts!(opts, "push_patch/2")

    case Phoenix.LiveView.Utils.live_link_info!(socket.router, socket.root_view, to) do
      {:internal, params, action, _parsed_uri} ->
        put_redirect(socket, {:live, {params, action}, opts})

      :external ->
        raise ArgumentError,
              "cannot push_patch/2 to #{inspect(to)} because the given path " <>
                "does not point to the current root view #{inspect(socket.root_view)}"
    end
  end

  @doc """
  Annotates the socket for navigation to another LiveView.

  The current LiveView will be shutdown and a new one will be mounted
  in its place LiveView, without reloading the whole page. This can
  also be use to remount the same LiveView, in case you want to start
  fresh. If you want to navigate to the same LiveView without remounting
  it, use `push_patch/2` instead.

  ## Options

    * `:to` - the required path to link to. It must always be a local path
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  ## Examples

      {:noreply, push_redirect(socket, to: "/")}
      {:noreply, push_redirect(socket, to: "/", replace: true)}

  """
  def push_redirect(%Socket{} = socket, opts) do
    opts = push_opts!(opts, "push_redirect/2")
    put_redirect(socket, {:live, :redirect, opts})
  end

  defp push_opts!(opts, context) do
    to = Keyword.fetch!(opts, :to)
    validate_local_url!(to, context)
    kind = if opts[:replace], do: :replace, else: :push
    %{to: to, kind: kind}
  end

  defp put_redirect(%Socket{redirected: nil} = socket, command) do
    %Socket{socket | redirected: command}
  end

  defp put_redirect(%Socket{redirected: to} = _socket, _command) do
    raise ArgumentError, "socket already prepared to redirect with #{inspect(to)}"
  end

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

  @doc """
  Returns the transport pid of the socket.

  Raises `ArgumentError` if the socket is not connected.

  ## Examples

      iex> transport_pid(socket)
      #PID<0.107.0>
  """
  def transport_pid(%Socket{}) do
    case Process.get(:"$callers") do
      [transport_pid | _] -> transport_pid
      _ -> raise ArgumentError, "transport_pid/1 may only be called when the socket is connected."
    end
  end

  defp child?(%Socket{parent_pid: pid}), do: is_pid(pid)
end

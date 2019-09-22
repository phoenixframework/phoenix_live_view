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
          Phoenix.View.render(AppWeb.PageView, "page.html", assigns)
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

  Next, decide where you want to use your LiveView.

  You can serve the LiveView directly from your router, passing along
  `:session` values if needed (see `Phoenix.LiveView.Router` for more
  options):

      defmodule AppWeb.Router do
        use Phoenix.Router
        import Phoenix.LiveView.Router

        scope "/", AppWeb do
          live "/thermostat", ThermostatLive, session: [:user_id]
        end
      end

  You can also `live_render` from any template:

      <h1>Temperature Control</h1>
      <%= Phoenix.LiveView.live_render(@conn, AppWeb.ThermostatLive, session: %{user_id: @user.id}) %>

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

      import {Socket} from "phoenix"
      import LiveSocket from "phoenix_live_view"

      let liveSocket = new LiveSocket("/live", Socket)
      liveSocket.connect()

  *Note*: Comprehensive JavaScript client usage is covered in detail below.

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

  ## Assigns and LiveEEx Templates

  All of the data in a LiveView is stored in the socket as assigns.
  The `assign/2` and `assign/3` functions help store those values.
  Those values can be accessed in the LiveView as `socket.assigns.name`
  but they are most commonly accessed inside LiveView templates as
  `@name`.

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

  Then Phoenix will never re-render the section above, even if the amount of
  users in the database changes. Instead, you need to store the users as
  assigns in your LiveView before it renders the template:

      assign(socket, :users, Repo.all(User))

  Generally speaking, **data loading should never happen inside the template**,
  regardless if you are using LiveView or not. The difference is that LiveView
  enforces those as best practices.

  ### Temporary assigns

  By default, all LiveView assigns are stateful, which enables change tracking
  and stateful interactions. In some cases, it's useful to mark assigns as temporary,
  meaning they will be set to nil after each update, allowing otherwise large, but
  infrequently updated values to be discarded after the client has been patched.

  *Note*: this requires refetching/recomputing the temporary assigns should they
  need accessed in future callbacks.

  To mark assigns as temporary, pass the `:temporary_assigns` option in mount:

      def mount(_session, socket) do
        desc = fetch_large_description()
        {:ok, assign(socket, description: desc), temporary_assigns: [:description]}
      end

  ## Containers

  When a `LiveView` is rendered, its contents are wrapped in a container.
  By default, said container is a `div` tag with a handful of `LiveView`
  specific attributes.

  The container can be customized in different ways:

    * You can change the default `container` on `use Phoenix.LiveView`:

          use Phoenix.LiveView, container: {:tr, id: "foo-bar"}

    * You can override the container tag and pass extra attributes when
      calling `live_render` (as well as on your `live` call in your router):

          live_render socket, MyLiveView, container: {:tr, class: "highlight"}

  ## Nested LiveViews

  LiveViews can be nested inside a parent LiveView by calling `live_render/3`.
  When rendering a child LiveView, the `:id` option is required to uniquely
  identify the child. A child will only ever be rendered and mounted a single
  time, provided its ID remains unchanged. Updates to a child session will be
  merged on the client, but not passed back up until either a crash and re-mount or
  a connetion drop and recovery. To force a child to re-mount with new session
  data, a new ID must be provided.

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
  | [Click Events](#module-click-events) | `phx-click` |
  | [Focus/Blur Events](#module-focus-and-blur-events) | `phx-blur`, `phx-focus`, `phx-target` |
  | [Form Events](#module-form-events) | `phx-change`, `phx-submit`, `data-phx-error-for`, `phx-disable-with` |
  | [Key Events](#module-key-events) | `phx-keydown`, `phx-keyup`, `phx-target` |
  | [Rate Limiting](#module-rate-limiting-events-with-debounce-and-throttle) | `phx-debounce`, `phx-throttle` |
  | [Custom DOM Patching](#module-custom-dom-patching) | `phx-update` |
  | [JS Interop](#module-js-interop-and-client-controlled-dom) | `phx-hook` |

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
  `phx-target` may be specified as `"window"`. Like other
  bindings, `phx-value-*` can be provided on the bound element,
  and those values will be sent as part of the payload. For example:

      <div class="container"
          phx-focus="page-active"
          phx-blur="page-inactive"
          phx-value-page="123"
          phx-target="window">
        ...
      </div>

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

  Number inputs are a special case in LiveView forms. On programatic updates,
  Some browsers will clear invalid inputs so LiveView will not send change events
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

  The onkeydown, and onkeyup events are supported via
  the `phx-keydown`, and `phx-keyup` bindings. When
  pushed, the value sent to the server will contain all the client event
  object's metadata. For example, pressing the Escape key looks like this:

      %{
        "altKey" => false, "charCode" => 0, "code" => "Escape",
        "ctrlKey" => false, "key" => "Escape", "keyCode" => 27,
        "location" => 0, "metaKey" => false, "repeat" => false,
        "shiftKey" => false, "which" => 27
      }

  By default, the bound element will be the event listener, but an
  optional `phx-target` may be provided which may be `"document"`,
  `"window"`, or the DOM id of a target element, for example:

      def render(assigns) do
        ~L\"""
        <div id="thermostat" phx-keyup="update_temp" phx-target="document">
          Current temperature: <%= @temperature %>
        </div>
        \"""
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

  ## Rate limiting events with debounce and throttle

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

      <div phx-keydown="keydown" phx-target="window" phx-throttle="500">
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
      back-to-back with dispatch the pressed key events.

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
      root, then the existing root LiveView is shutdown, and an Ajax request is
      made to request the necessary information about the new LiveView, without
      performing a full static render (which reduces latency and improves
      performance). Once information is retrieved, the new LiveView is mounted.

  ### `handle_params/3`

  The `c:handle_params/3` callback is invoked after `c:mount/2`. It receives the
  request path parameters and the query parameters as first argument, the url as
  second, and the socket as third. As any other `handle_*` callback, changes to
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

  The `phx-submit` event is used for form submissions where major side-effects
  typically happen, such as rendering new containers, calling an external
  service, or redirecting to a new page. For these use-cases, the form inputs
  are set to `readonly` on submit, and any submit button is disabled until
  the client gets an acknowledgment that the server has processed the
  `phx-submit` event. Following an acknowledgment, any updates are patched
  to the DOM as normal, and the last input with focus is restored if the
  user has not otherwise focused on a new input during submission.

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

  When a form bound with `phx-submit` is submitted, the `"phx-loading"` class
  is applied to the form, which is removed on update.

  ### Custom DOM patching

  A container can be marked with `phx-update`, allowing the DOM patch
  operations to avoid updating or removing portions of the LiveView, or to append
  or prepend the updates rather than replacing the existing contents. This
  is useful for client-side interop with existing libraries that do their
  own DOM operations. The following `phx-update` values are supported:

    * `replace` - the default operation. Replaces the element with the contents
    * `ignore` - ignores updates the DOM regardless of new content changes
    * `append` - append the new DOM contents instead of replacing
    * `prepend` - prepend the new DOM contents instead of replacing

  When appending or prepending elements containing an ID already present
  in the container, LiveView will replace the existing element with the
  new content instead appending or prepending a new element.

  *Note*: when using `phx-update`, a unique DOM ID must always be set.

  ### JS Interop and client controlled DOM

  To handle custom client-side javascript when an element is added, updated,
  or removed by the server, a hook object may be provided with the following
  life-cycle callbacks:

    * `mounted` - the element has been added to the DOM and its server
      LiveView has finished mounting
    * `updated` - the element has been updated in the DOM by the server
    * `destroyed` - the element has been removed from the page, either
      by a parent update, or the parent being removed entirely
    * `disconnected` - the element's parent LiveView has disconnected from the server
    * `reconnected` - the element's parent LiveView has reconnected to the server

  In addition to the callbacks, the callbacks contain the following attributes in scope:

    * `el` - attribute referencing the bound DOM node,
    * `viewName` - attribute matching the dom node's phx-view value
    * `pushEvent(event, payload)` - method to push an event from the client to the LiveView server

  For example, a controlled input for phone-number formatting would annotate their
  markup:

      <input type="text" name="user[phone_number]" phx-hook="PhoneNumber" />

  Then a hook callback object can be defined and passed to the socket:

      let Hooks = {}
      Hooks.PhoneNumber = {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\\D/g, "").match(/^(\\d{3})(\\d{3})(\\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }

      let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks})
      ...
  """

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @type unsigned_params :: map
  @type from :: {pid, reference}

  @callback mount(session :: map, socket :: Socket.t()) ::
              {:ok, Socket.t()}

  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @callback terminate(reason, socket :: Socket.t()) :: term
            when reason: :normal | :shutdown | {:shutdown, :left | :closed | term}

  @callback handle_params(unsigned_params, uri :: String.t(), socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @callback handle_event(event :: binary, unsigned_params, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @callback handle_call(msg :: term, from, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, term, Socket.t()} | {:stop, Socket.t()}

  @callback handle_info(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @optional_callbacks terminate: 2,
                      handle_params: 3,
                      handle_event: 3,
                      handle_call: 3,
                      handle_info: 2

  @doc """
  Uses LiveView in the current module to mark it a LiveView.

      use Phoenix.LiveView,
        namespace: MyAppWeb,
        container: {:tr, class: "colorized"}

  ## Options

    * `:namespace` - configures the namespace the `LiveView` is in
    * `:container` - configures the container the `LiveView` will be wrapped in

  """
  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)
      @__live__ Phoenix.LiveView.View.live_definition(__MODULE__, :view, opts)

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def mount(_session, socket), do: {:ok, socket}

      @doc false
      def __live__, do: @__live__

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
      be used for the LiveView container. For example: `{:li, style: "color: blue;"}`.
    * `:id` - both the DOM ID and the ID to uniquely identify a child LiveView when
      live rendering children of the same type.

  ## Examples

      # within eex template
      <%= live_render(@conn, MyApp.ThermostatLive) %>

      # within leex template
      <%= live_render(@socket, MyApp.ThermostatLive, id: "thermostat") %>

  """
  def live_render(conn_or_socket, view, opts \\ [])

  def live_render(%Plug.Conn{} = conn, view, opts) do
    case LiveView.View.static_render(conn, view, opts) do
      {:ok, content} ->
        content

      {:stop, _} ->
        raise RuntimeError, "cannot redirect from a child LiveView"
    end
  end

  def live_render(%Socket{} = parent, view, opts) do
    LiveView.View.nested_static_render(parent, view, opts)
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
      |> LiveView.Controller.live_render(MyLive, session: %{user_id: user.id})

      # LiveView mount
      def mount(%{user_id: user_id}, socket) do
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

  ## Options

    * `:to` - the path to redirect to
  """
  # TODO support `:external` and validation `:to` is a local path
  def redirect(%Socket{} = socket, opts) do
    assert_root_live_view!(socket, "redirect/2")
    LiveView.View.put_redirect(socket, :redirect, %{to: Keyword.fetch!(opts, :to)})
  end

  @doc """
  Annotates the socket for navigation without a page refresh.

  When navigating to a path which routes to your existing LiveView,
  the `handle_params/3` callback is immediately invoked in your existing
  LiveView process to handle the change of URL state. For live redirects
  to external LiveViews, the existing LiveView is shutdown.

  ## Options

    * `:to` - the required path to link to.
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  ## Examples

      {:noreply, live_redirect(socket, to: "/")}
      {:noreply, live_redirect(socket, to: "/", replace: true)}
  """
  def live_redirect(%Socket{} = socket, opts) do
    assert_root_live_view!(socket, "live_redirect/2")
    kind = if opts[:replace], do: :replace, else: :push
    LiveView.View.put_redirect(socket, :live, %{to: Keyword.fetch!(opts, :to), kind: kind})
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

  @doc """
  Generates a live link for HTML5 pushState based navigation without page reloads.

  ## Options

    * `:to` - the required path to link to.
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  All other options are forwarded to the anchor tag.

  ## Examples

      <%= live_link "next", to: Routes.live_path(@socket, MyLive, @page + 1) %>
      <%= live_link to: Routes.live_path(@socket, MyLive, dir: :asc), replace: false do %>
        Sort By Price
      <% end %>

  """
  def live_link(opts) when is_list(opts), do: live_link(opts, do: Keyword.fetch!(opts, :do))
  def live_link(opts, do: block) when is_list(opts) do
    uri = Keyword.fetch!(opts, :to)
    replace = Keyword.get(opts, :replace, false)
    kind = if replace, do: "replace", else: "push"

    opts = opts
    |> Keyword.update(:data, [phx_live_link: kind], &Keyword.merge(&1, [phx_live_link: kind]))
    |> Keyword.put(:href, uri)

    Phoenix.HTML.Tag.content_tag(:a, opts, do: block)
  end
  def live_link(text, opts) when is_list(opts) do
    live_link(opts, do: text)
  end

  @doc """
  Accesses the connect params sent by the client for use on connected mount.

  Connect params are only sent when the client connects to the server and
  only remain available during mount. `nil` is returned when called in a
  disconnected state and a `RuntimeError` is raised if called after mount.

  ## Examples

      def mount(_session, socket) do
        {:ok, assign(socket, width: get_connect_params(socket)["width"] || @width)}
      end
  """
  def get_connect_params(%Socket{} = socket) do
    LiveView.View.get_connect_params(socket)
  end

  defp assert_root_live_view!(%{parent_pid: nil}, _context),
    do: :ok

  defp assert_root_live_view!(_, context),
    do: raise ArgumentError, "cannot invoke #{context} from a child LiveView"
end

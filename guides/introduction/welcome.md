# Welcome

Welcome to Phoenix LiveView documentation. Phoenix LiveView enables
rich, real-time user experiences with server-rendered HTML. A general
overview of LiveView and its benefits is [available in our README](https://github.com/phoenixframework/phoenix_live_view).

## What is a LiveView?

LiveViews are processes that receives events, updates its state,
and render updates to a page as diffs.

The LiveView programming model is declarative: instead of saying
"once event X happens, change Y on the page", events in LiveView
are regular messages which may cause changes to its state. Once
the state changes, LiveView will re-render the relevant parts of
its HTML template and push it to the browser, which updates itself
in the most efficient manner.

LiveView state is nothing more than functional and immutable
Elixir data structures. The events are either internal application messages
(usually emitted by `Phoenix.PubSub`) or sent by the client/browser.

LiveView is first rendered statically as part of regular
HTTP requests, which provides quick times for "First Meaningful
Paint", in addition to helping search and indexing engines.
Then a persistent connection is established between client and
server. This allows LiveView applications to react faster to user
events as there is less work to be done and less data to be sent
compared to stateless requests that have to authenticate, decode, load,
and encode data on every request.

## Example

LiveView is included by default in Phoenix applications.
Therefore, to use LiveView, you must have already installed Phoenix
and created your first application. If you haven't done so,
check [Phoenix' installation guide](https://hexdocs.pm/phoenix/installation.html)
to get started.

The behaviour of a LiveView is outlined by a module which implements
a series of functions as callbacks. Let's see an example. Write the
file below to `lib/my_app_web/live/thermostat_live.ex`:

```elixir
defmodule MyAppWeb.ThermostatLive do
  # In Phoenix v1.6+ apps, the line is typically: use MyAppWeb, :live_view
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    Current temperature: <%= @temperature %>°F
    <button phx-click="inc_temperature">+</button>
    """
  end

  def mount(_params, _session, socket) do
    temperature = 70 # Let's assume a fixed temperature for now
    {:ok, assign(socket, :temperature, temperature)}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:ok, update(socket, :temperature, &(&1 + 1))}
  end
end
```

The module above defines three functions (they are callbacks
required by LiveView). The first one is `render/1`,
which receives the socket `assigns` and is responsible for returning
the content to be rendered on the page. We use the `~H` sigil to define
a HEEx template, which stands for HTML+EEx. They are an extension of
Elixir's builtin EEx templates, with support for HTML validation, syntax-based
components, smart change tracking, and more. You can learn more about
the template syntax in `Phoenix.Component.sigil_H/2` (note
`Phoenix.Component` is automatically imported when you use `Phoenix.LiveView`).

The data used on rendering comes from the `mount` callback. The
`mount` callback is invoked when the LiveView starts. In it, you
can access the request parameters, read information stored in the
session (typically information which identifies who is the current
user), and a socket. The socket is where we keep all state, including
assigns. `mount` proceeds to read the thermostat temperature for the
user and store its value in the assigns. After `mount`, LiveView will
render the page with the values from `assigns`.

If you look at the HTML rendered, you will notice there is a button
with a `phx-click` attribute. When the button is clicked, a
"inc_temperature" event is sent to the server, which is matched and
handled by the `handle_event` callback. The callback updates the state
which causes the page to be updated. LiveView then computes diffs and
sends them to client.

Now we are ready to render our LiveView. You can serve the LiveView
directly from your router:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  scope "/", MyAppWeb do
    live "/thermostat", ThermostatLive
  end
end
```

Once the LiveView is rendered, a regular HTML response is sent. In your
app.js file, you should find the following:

```javascript
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
liveSocket.connect()
```

Now the JavaScript client will connect over WebSockets and `mount/3` will be invoked
inside a spawned LiveView process.

## Parameters and session

The mount callback receives three arguments: the request parameters, the session, and the socket.

The parameters can be used to read information from the URL. For example, assuming you have a `Thermostat` module defined somewhere that can read this information based on the house name, you could write this:

```elixir
  def mount(%{"house" => house}, _session, socket) do
    temperature = Thermostat.get_house_reading(house)
    {:ok, assign(socket, :temperature, temperature)}
  end
```

And then in your router:

```elixir
  live "/thermostat/:house", ThermostatLive
```

The session retrieves information from a signed (or encrypted) cookie. This is where you can store authentication information, such as `current_user_id`:

```elixir
  def mount(_params, %{"current_user_id" => user_id}, socket) do
    temperature = Thermostat.get_user_reading(user_id)
    {:ok, assign(socket, :temperature, temperature)}
  end
```

> Phoenix comes with built-in authentication generators. See `mix phx.gen.auth`.

Most times, in practice, you will use both:

```elixir
  def mount(%{"house" => house}, %{"current_user_id" => user_id}, socket) do
    temperature = Thermostat.get_house_reading(user_id, house)
    {:ok, assign(socket, :temperature, temperature)}
  end
```

In other words, you want to read the information about a given house, as long as the user has access to it.

## Bindings

Phoenix supports DOM element bindings for client-server interaction. For
example, to react to a click on a button, you would render the element:

    <button phx-click="inc_temperature">+</button>

Then on the server, all LiveView bindings are handled with the `handle_event/3`
callback, for example:

    def handle_event("inc_temperature", _value, socket) do
      {:ok, update(socket, :temperature, &(&1 + 1))}
    end

To update UI state, for example, to open and close dropdowns, switch tabs,
etc, LiveView also supports JS commands (`Phoenix.LiveView.JS`), which
execute directly on the client without reaching the server. To learn more,
see [our bindings page](bindings.md) for a complete list of all LiveView
bindings as well as our [JavaScript interoperability guide](js-interop.md).

LiveView has built-in support for forms, including uploads and association
management. See `Phoenix.Component.form/1` as a starting point and
`Phoenix.Component.inputs_for/1` for working with associations.
The [Uploads](uploads.md) and [Form bindings](form-bindings.md) guides provide
more information about advanced features.

## Navigation

LiveView provides functionality to allow page navigation using the
[browser's pushState API](https://developer.mozilla.org/en-US/docs/Web/API/History_API).
With live navigation, the page is updated without a full page reload.

You can either *patch* the current LiveView, updating its URL, or
*navigate* to a new LiveView. You can learn more about them in the
[Live Navigation](live-navigation.md) guide.

## Generators

Phoenix v1.6 and later includes code generators for LiveView. If you want to see
an example of how to structure your application, from the database all the way up
to LiveViews, run the following:

    mix phx.gen.live Blog Post posts title:string body:text

For more information, run `mix help phx.gen.live`.

For authentication, with built-in LiveView support, run `mix phx.gen.auth Account User users`.

## Compartmentalize state, markup, and events in LiveView

LiveView supports two extension mechanisms: function components, provided by
`HEEx` templates, and stateful components.

Function components are any function that receives an assigns map, similar
to `render(assigns)` in our LiveView, and returns a `~H` template. For example:

    def weather_greeting(assigns) do
      ~H"""
      <div title="My div" class={@class}>
        <p>Hello <%= @name %></p>
        <MyApp.Weather.city name="Kraków"/>
      </div>
      """
    end

You can learn more about function components in the `Phoenix.Component`
module. At the end of the day, they are a useful mechanism to reuse markup
in your LiveViews.

However, sometimes you need to compartmentalize or reuse more than markup.
Perhaps you want to move part of the state or part of the events in your
LiveView to a separate module. For these cases, LiveView provides
`Phoenix.LiveComponent`, which are rendered using
[`live_component/1`](`Phoenix.Component.live_component/1`):

    <.live_component module={UserComponent} id={user.id} user={user} />

Components have their own `mount/3` and `handle_event/3` callbacks, as
well as their own state with change tracking support. Components are also
lightweight as they "run" in the same process as the parent `LiveView`.
However, this means an error in a component would cause the whole view to
fail to render. See `Phoenix.LiveComponent` for a complete rundown on components.

Finally, if you want complete isolation between parts of a LiveView, you can
always render a LiveView inside another LiveView by calling
[`live_render/3`](`Phoenix.Component.live_render/3`). This child LiveView
runs in a separate process than the parent, with its own callbacks. If a child
LiveView crashes, it won't affect the parent. If the parent crashes, all children
are terminated.

When rendering a child LiveView, the `:id` option is required to uniquely
identify the child. A child LiveView will only ever be rendered and mounted
a single time, provided its ID remains unchanged. To force a child to re-mount
with new session data, a new ID must be provided.

Given that a LiveView runs on its own process, it is an excellent tool for creating
completely isolated UI elements, but it is a slightly expensive abstraction if
all you want is to compartmentalize markup or events (or both).

To sum it up:

  * use `Phoenix.Component` to compartmentalize/reuse markup
  * use `Phoenix.LiveComponent` to compartmentalize state, markup, and events
  * use nested `Phoenix.LiveView` to compartmentalize state, markup, events, and error isolation

## Guides

This documentation is split into two categories. We have the API
reference for all LiveView modules, that's where you will learn
more about `Phoenix.Component`, `Phoenix.LiveView`, and so on.

LiveView also has many guides to help you on your journey,
split on server-side and client-side:

### Server-side

These guides focus on server-side functionality:

* [Assigns and HEEx templates](assigns-eex.md)
* [Error and exception handling](error-handling.md)
* [Live Layouts](live-layouts.md)
* [Live Navigation](live-navigation.md)
* [Security considerations of the LiveView model](security-model.md)
* [Telemetry](telemetry.md)
* [Uploads](uploads.md)
* [Using Gettext for internationalization](using-gettext.md)

### Client-side

These guides focus on LiveView bindings and client-side integration:

* [Bindings](bindings.md)
* [Form bindings](form-bindings.md)
* [DOM patching and temporary assigns](dom-patching.md)
* [JavaScript interoperability](js-interop.md)
* [Uploads (External)](uploads-external.md)

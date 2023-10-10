# Welcome

Welcome to Phoenix LiveView documentation. Phoenix LiveView enables
rich, real-time user experiences with server-rendered HTML. A general
overview of LiveView and its benefits is [available in our README](https://github.com/phoenixframework/phoenix_live_view).

This page is a brief introduction into the main abstractions in LiveView
and our documentation.

## Building blocks

There are three main building blocks in Phoenix LiveView: `Phoenix.Component`,
`Phoenix.LiveView`, and `Phoenix.LiveComponent`.

### Phoenix.Component

A `Phoenix.Component` is a function that receives `assigns` and returns a
rendered template. Let's see an example:

```elixir
defmodule MyFirstComponent do
  use Phoenix.Component

  def greet(assigns) do
    ~H"""
    <p>Hello, <%= @name %>!</p>
    """
  end
end
```

`greet` is a function that receives one argument: the `assigns` map.
`assigns` is a key-value data structure with all attributes available
to the function component.

This function uses the `~H` sigil to return a rendered template.
`~H` stands for HEEx (HTML + EEx). HEEx is a template language for
writing HTML mixed with Elixir interpolation. We can write Elixir
code inside HEEx using `<%= ... %>` tags and we use `@name` to access
the key `name` defined inside `assigns`.

Once you define a component, you can invoke it from other HEEx templates
like this:

```elixir
~H"""
<MyFirstComponent.greet name="Mary" />
"""
```

Which will then return:

```html
<p>Hello, Mary!</p>
```

If you are invoking the component in the same module it is defined,
you can skip the module prefix when invoking it:

```elixir
~H"""
<.greet name="Mary" />
"""
```

Although components are part of LiveView, they are also used outside
of LiveView to build high-level composable abstrations within our web
applications.

You can learn more about components, HEEx templates, and their features
in the `Phoenix.Component` module documentation.

### Phoenix.LiveView

LiveViews are processes that receives events, updates its state,
and render updates to a page as diffs.

The LiveView programming model is declarative: instead of saying
"once event X happens, change Y on the page", events in LiveView
are regular messages which may cause changes to its state. Once
the state changes, LiveView will re-render the relevant parts of
its HTML template and push it to the browser, which updates itself
in the most efficient manner.

The behaviour of a LiveView is outlined by a module which implements
a series of functions as callbacks. Let's see an example:

```elixir
defmodule MyAppWeb.ThermostatLive do
  # In Phoenix v1.6+ apps, the line is typically: use MyAppWeb, :live_view
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    Current temperature: <%= @temperature %>
    <button phx-click="inc_temperature">+</button>
    """
  end

  def mount(_params, %{"current_user_id" => user_id}, socket) do
    temperature = Thermostat.get_user_reading(user_id)
    {:ok, assign(socket, :temperature, temperature)}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:ok, update(socket, :temperature, &(&1 + 1))}
  end
end
```

The module above defines three functions (they are callbacks
required by LiveView). The first one is `render/1`, which works
precisely as a function component: it receives data as `assigns`
and returns a template. This is the template that will be rendered
on the page.

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

In order to render your LiveView to users, you will first need to plug
it in your router. We explain the required steps and detail other LiveView
features and callbacks in the `Phoenix.LiveView` module documentation.

### Phoenix.LiveComponent

`Phoenix.LiveComponent` are modules that play a role between
`Phoenix.LiveView` and `Phoenix.Component`.

Components allow us to encapsulate markup logic. LiveView are
processes that encapsulate logic, state, and events. Sometimes,
however, we want encapsulate some logic, state, and events
(not only markup) between LiveViews, without creating a whole
LiveView itself. That's exactly the goal of LiveComponents.

To learn more, check out `Phoenix.LiveComponent` documentation.

## Guides

This documentation is split into two categories. We have the API
reference for all LiveView modules, that's where you will learn
more about `Phoenix.Component`, `Phoenix.LiveView`, and so on.

We also provide a series of guides around specific topics. The
guides are divided in two categories: if they are server-centric
or client-centric. You can explore them in the sidebar.

Happy learning!

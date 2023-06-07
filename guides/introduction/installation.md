# Installation

## New projects

Phoenix v1.5+ comes with built-in support for LiveView apps. Just create
your application with `mix phx.new my_app --live`. The `--live` flag has
become the default on Phoenix v1.6.

Once you've created a LiveView project, refer to [LiveView documentation](`Phoenix.LiveView`)
for further information on how to use it.

## Existing projects

If you are using a Phoenix version earlier than v1.5 or your app already exists, continue
with the following steps.

The instructions below will serve if you are installing the latest stable version
from Hex. To start using LiveView, add one of the following dependencies to your `mix.exs`
and run `mix deps.get`.

If installing from Hex, use the latest version from there:

```elixir
def deps do
  [
    {:phoenix_live_view, "~> 0.18"},
    {:floki, ">= 0.30.0", only: :test}
  ]
end
```

If you want the latest features, install from GitHub:

```elixir
def deps do
  [
    {:phoenix_live_view, github: "phoenixframework/phoenix_live_view"},
    {:floki, ">= 0.30.0", only: :test}
  ]
```

Once installed, update your endpoint's configuration to include a signing salt.
You can generate a signing salt by running `mix phx.gen.secret 32`:

```elixir
# config/config.exs

config :my_app, MyAppWeb.Endpoint,
   live_view: [signing_salt: "SECRET_SALT"]
```

Next, add the following imports to your web file in `lib/my_app_web.ex`:

```elixir
# lib/my_app_web.ex

def view do
  quote do
    # ...
    import Phoenix.Component
  end
end

def router do
  quote do
    # ...
    import Phoenix.LiveView.Router
  end
end
```

In that same file, update your live_view layout configuration:

```diff
# lib/my_app_web.ex

def live_view do
  use Phoenix.LiveView,
-    layout: {MyAppWeb.LayoutView, "live.html"}
+    layout: {MyAppWeb.LayoutView, :live}

  unquote(view_helpers())
end
```

Then add the `Phoenix.LiveView.Router.fetch_live_flash/2` plug to your browser pipeline, in place of `:fetch_flash`:

```diff
# lib/my_app_web/router.ex

pipeline :browser do
  # ...
  plug :fetch_session
- plug :fetch_flash
+ plug :fetch_live_flash
end
```

Next, expose a new socket for LiveView updates in your app's endpoint module.

```elixir
# lib/my_app_web/endpoint.ex

defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint

  # ...

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  # ...
end
```

Where `@session_options` are the options given to `plug Plug.Session` by using a module attribute. If you don't have a `@session_options` in your endpoint yet, here is how to create one:

1. Find plug Plug.Session in your endpoint.ex

```elixir
  plug Plug.Session
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "somesigningsalt"
```

2. Move the options to a module attribute at the top of your file:

```elixir
  @session_options [
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "somesigningsalt"
  ]
```

3. Change the plug Plug.Session to use that attribute:

```elixir
  plug Plug.Session, @session_options
```

Finally, ensure you have placed a CSRF meta tag inside the `<head>` tag in your layout (`lib/my_app_web/templates/layout/app.html.*`) before `app.js` is included, like so:

```heex
<meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
<script defer type="text/javascript" src="<%= Routes.static_path(@conn, "/js/app.js") %>"></script>
```

and enable connecting to a LiveView socket in your `app.js` file.

```js
// assets/js/app.js
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
// The latency simulator is enabled for the duration of the browser session.
// Call disableLatencySim() to disable:
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
```

The JavaScript above expects `phoenix_live_view` to be available as a JavaScript dependency. Let's do that.

## npm dependencies

If using `npm`, you need to add LiveView to your `assets/package.json`. For a regular project, do:

```json
{
  "dependencies": {
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view"
  }
}
```

However, if you're adding `phoenix_live_view` to an umbrella project, the dependency paths should be modified appropriately:

```json
{
  "dependencies": {
    "phoenix": "file:../../../deps/phoenix",
    "phoenix_html": "file:../../../deps/phoenix_html",
    "phoenix_live_view": "file:../../../deps/phoenix_live_view"
  }
}
```

Now run the next commands from the root of your web app project:

```bash
npm install --prefix assets
```

If you had previously installed `phoenix_live_view` and want to get the
latest javascript, then force an install with:

```bash
npm install --force phoenix_live_view --prefix assets
```

## Layouts

LiveView does not use the default app layout. Instead, you typically call `put_root_layout` in your router to specify a layout that is used by both "regular" views and live views. In your router, do:

```elixir
# lib/my_app_web/router.ex

pipeline :browser do
  # ...
  plug :put_root_layout, html: {MyAppWeb.LayoutView, :root}
  # ...
end
```

The layout given to `put_root_layout` is typically very barebones, with mostly `<head>` and `<body>` tags. For example:

```heex
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <Phoenix.Component.live_title><%= assigns[:page_title] || "MyApp" %></Phoenix.Component.live_title>
    <link rel="stylesheet" href="<%= Routes.static_path(@conn, "/css/app.css") %>"/>
    <script defer type="text/javascript" src="<%= Routes.static_path(@conn, "/js/app.js") %>"></script>
  </head>
  <body>
    <%= @inner_content %>
  </body>
</html>
```

Once you have specified a root layout, `app.html.heex` will be rendered within your root layout for all non-LiveViews. You may also optionally define a `live.html.heex` layout to be used across all LiveViews, as we will describe in the next section.

Optionally, you can add a [`phx-track-static`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#static_changed?/1) to all `script` and `link` elements in your layout that use `src` and `href`. This way you can detect when new assets have been deployed by calling `static_changed?`.

```elixir
<link phx-track-static rel="stylesheet" href={Routes.static_path(@conn, "/css/app.css")} />
<script phx-track-static defer type="text/javascript" src={Routes.static_path(@conn, "/js/app.js")}></script>
```

## Progress animation

If you want to show a progress bar as users perform live actions, we recommend using [`topbar`](https://github.com/buunguyen/topbar).

You can either add a copy of `topbar` to `assets/vendor/topbar.js` or add it as a npm dependency by calling:

```shell
$ npm install --prefix assets --save topbar
```

Then customize LiveView to use it in your `assets/js/app.js`, right before the `liveSocket.connect()` call:

```js
// Show progress bar on live navigation and form submits
import topbar from "topbar"
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())
```

Alternatively, you can also delay showing the `topbar` and wait if the results do not appear within 200ms:

```js
// Show progress bar on live navigation and form submits
import topbar from "topbar"
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})

window.addEventListener("phx:page-loading-start", () => {
  topbar.show(200)
})

window.addEventListener("phx:page-loading-stop", () => {
  topbar.hide()
})
```

## Location for LiveView modules

By convention your LiveView modules and `heex` templates should be placed in `lib/my_app_web/live/` directory.

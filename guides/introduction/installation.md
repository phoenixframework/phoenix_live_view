# Installation

While Phoenix LiveView is under heavy development, the installation instructions
are likely to change rapidly as well. The instructions below will serve if you
are installing the latest stable version from Hex. If you are installing from
GitHub to get the latest features, follow the instructions in [the README
there](https://github.com/phoenixframework/phoenix_live_view/blob/master/README.md#installation)
instead.

To start using LiveView, add to your `mix.exs` and run `mix deps.get`. If
installing from Hex, use the latest version from there:

```elixir
def deps do
  [
    {:phoenix_live_view, "~> 0.10.0"},
    {:floki, ">= 0.0.0", only: :test}
  ]
end
```

If you want the latest features, install from GitHub:

```elixir
def deps do
  [
    {:phoenix_live_view, github: "phoenixframework/phoenix_live_view"},
    {:floki, ">= 0.0.0", only: :test}
  ]
```

Once installed, update your endpoint's configuration to include a signing salt.
You can generate a signing salt by running `mix phx.gen.secret 32`.

```elixir
# config/config.exs

config :my_app, MyAppWeb.Endpoint,
   live_view: [
     signing_salt: "SECRET_SALT"
   ]
```

Next, add the following imports to your web file in `lib/my_app_web.ex`:

```elixir
# lib/my_app_web.ex

def controller do
  quote do
    ...
    import Phoenix.LiveView.Controller
  end
end

def view do
  quote do
    ...
    import Phoenix.LiveView.Helpers
  end
end

def router do
  quote do
    ...
    import Phoenix.LiveView.Router
  end
end
```

Then add the `Phoenix.LiveView.Router.fetch_live_flash` plug to your browser pipeline, in place of `:fetch_flash`:

```diff
# lib/my_app_web/router.ex

pipeline :browser do
  ...
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

Where `@session_options` are the options given to `plug Plug.Session` extracted to a module attribute. If you don't have a `@session_options` in your endpoint yet, here is how to extract it out:

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

3. Change the plug Plug.Session to use the attribute:

```elixir
  plug Plug.Session, @session_options
```

Add LiveView NPM dependencies in your `assets/package.json`. For a regular project, do:

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

Then install the new npm dependency.

```bash
npm install --prefix assets

# or `cd assets && npm install` for Windows users if --prefix doesn't work
```

If you had previously installed `phoenix_live_view` and want to get the
latest javascript, then force an install.

```bash
(cd assets && npm install --force phoenix_live_view)
```

Ensure you have placed a CSRF meta tag inside the `<head>` tag in your layout (`lib/my_app_web/templates/layout/app.html.eex`), before `app.js` is included like so:

```html
<%= csrf_meta_tag() %>
<script type="text/javascript" src="<%= Routes.static_path(@conn, "/js/app.js") %>"></script>
```

LiveView no longer uses the default app layout. Instead, use `put_root_layout`. Note, however, that the layout given to `put_root_layout` must use `@inner_content` instead of `<%= render(@view_module, @view_template, assigns) %>` and that the root layout will also be used by regular views. Therefore, we recommend setting `put_root_layout` in a pipeline that is exclusive to LiveViews. Check the [Live Layouts](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-live-layouts) section of the docs.

Enable connecting to a LiveView socket in your `app.js` file.

```javascript
// assets/js/app.js
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});
liveSocket.connect()
```

You can also optionally import the style for the default CSS classes in your `app.css` file. For a regular project:

```css
/* assets/css/app.css */
@import "../../deps/phoenix_live_view/assets/css/live_view.css";
```

However, if you're adding `phoenix_live_view` to an umbrella project, the import link should be modified appropriately:

```css
/* assets/css/app.css */
@import "../../../../deps/phoenix_live_view/assets/css/live_view.css";

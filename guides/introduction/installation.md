# Installation

While Phoenix LiveView is under heavy development, the installation instructions
are likely to change rapidly as well. The instructions below will serve if you
are installing the latest stable version from Hex. If you are installing from
GitHub to get the latest features, follow the instructions in [the README
there](https://github.com/phoenixframework/phoenix_live_view/blob/master/README.md#installation)
instead.

To start using LiveView, add to your `mix.exs` and run `mix deps.get`:

```elixir
def deps do
  [
    {:phoenix_live_view, "~> 0.3.0"},
    {:floki, ">= 0.0.0", only: :test}
  ]
end
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

Next, add the LiveView flash plug to your browser pipeline, after `:fetch_flash`:

```elixir
# lib/my_app_web/router.ex

pipeline :browser do
  ...
  plug :fetch_flash
  plug Phoenix.LiveView.Flash
end
```

Then add the following imports to your web file in `lib/my_app_web.ex`:

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
    import Phoenix.LiveView,
      only: [live_render: 2, live_render: 3, live_link: 1, live_link: 2]
  end
end

def router do
  quote do
    ...
    import Phoenix.LiveView.Router
  end
end
```

Next, expose a new socket for LiveView updates in your app's endpoint module.

```elixir
# lib/my_app_web/endpoint.ex

defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint

  socket "/live", Phoenix.LiveView.Socket

  # ...
end
```

Add LiveView NPM dependencies in your `assets/package.json`.

```json
{
  "dependencies": {
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view"
  }
}
```

Then install the new npm dependency.

```bash
npm install --prefix assets
```

If you had previously installed phoenix_live_view and want to get the
latest javascript, then force an install.

```bash
(cd assets && npm install --force phoenix_live_view)
```

Enable connecting to a LiveView socket in your `app.js` file.

```javascript
// assets/js/app.js
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"

let liveSocket = new LiveSocket("/live", Socket)
liveSocket.connect()
```

You can also optionally import the style for the default CSS classes in your `app.css` file.

```css
/* assets/css/app.css */
@import "../../deps/phoenix_live_view/assets/css/live_view.css";
```

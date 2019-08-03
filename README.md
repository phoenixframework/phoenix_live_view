# Phoenix LiveView

[![Build Status](https://travis-ci.org/phoenixframework/phoenix_live_view.svg?branch=master)](https://travis-ci.org/phoenixframework/phoenix_live_view)

Phoenix LiveView enables rich, real-time user experiences with server-rendered HTML. For more information, [see the initial announcement](https://dockyard.com/blog/2018/12/12/phoenix-liveview-interactive-real-time-apps-no-need-to-write-javascript).

**Note**: Currently LiveView is under active development and we are focused on getting a stable and solid initial version out. For this reason, we will be accepting only bug reports in the issues tracker for now. We will open the issues tracker for features after the current milestone is ironed out.

## Learning

As official guides are being developed, see our existing
comprehensive docs and examples to get up to speed:

  * [Phoenix.LiveView docs for general usage](https://github.com/phoenixframework/phoenix_live_view/blob/master/lib/phoenix_live_view.ex)
  * [phoenix_live_view.js docs](https://github.com/phoenixframework/phoenix_live_view/blob/master/assets/js/phoenix_live_view.js)
  * [Phoenix.LiveViewTest for testing docs](https://github.com/phoenixframework/phoenix_live_view/blob/master/lib/phoenix_live_view/test/live_view_test.ex)
  * [LiveView example repo](https://github.com/chrismccord/phoenix_live_view_example) with a handful of examples from Weather widgets, autocomplete search, and games like Snake or Pacman

## Installation

Currently LiveView is only available from GitHub. To use it, add to your `mix.exs` and run `mix deps.get`:

```elixir
def deps do
  [
    {:phoenix_live_view, github: "phoenixframework/phoenix_live_view"}
  ]
end
```

Once installed, update your endpoint's configuration to include a signing salt. You can generate a signing salt by running `mix phx.gen.secret 32`.

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
    import Phoenix.LiveView.Controller, only: [live_render: 3]
  end
end

def view do
  quote do
    ...
    import Phoenix.LiveView, only: [live_render: 2, live_render: 3, live_link: 1, live_link: 2]
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
import LiveSocket from "phoenix_live_view"

let liveSocket = new LiveSocket("/live")
liveSocket.connect()
```

Finally, by convention live views are saved in a `lib/my_app_web/live/`
directory. For live page reload support, add the following pattern to
your `config/dev.exs`:

```elixir
# config/dev.exs
config :demo, MyAppWeb.Endpoint,
  live_reload: [
    patterns: [
      ...,
      ~r{lib/my_app_web/live/.*(ex)$}
    ]
  ]
```

You can also optionally import the style for the default CSS classes in your `app.css` file.

```css
/* assets/css/app.css */
@import "../../deps/phoenix_live_view/assets/css/live_view.css";
```

## Browser Support

All current Chrome, Safari, Firefox, and MS Edge are supported.
IE11 support is available with the following polyfills:

```console
$ npm install --save --prefix assets mdn-polyfills url-search-params-polyfill formdata-polyfill child-replace-with-polyfill classlist-polyfill
```

```javascript
// assets/js/app.js
import "mdn-polyfills/NodeList.prototype.forEach"
import "mdn-polyfills/Element.prototype.closest"
import "mdn-polyfills/Element.prototype.matches"
import "child-replace-with-polyfill"
import "url-search-params-polyfill"
import "formdata-polyfill"
import "classlist-polyfill"

import LiveSocket from "phoenix_live_view"
...
```

# Phoenix Live View

[![Build Status](https://travis-ci.com/phoenixframework/phoenix_live_view.svg?token=Dc4VoVYF33Y2H4Gy8pGi&branch=master)](https://travis-ci.com/phoenixframework/phoenix_live_view)

Phoenix LiveView enables rich, real-time user experiences with server-rendered HTML. For more information, [see the initial announcement](https://dockyard.com/blog/2018/12/12/phoenix-liveview-interactive-real-time-apps-no-need-to-write-javascript).

**Note**: Currently Live View is under active development and we are focused on getting a stable and solid initial version out. For this reason, we will be accepting only bug reports in the issues tracker for now. We will open the issues tracker for features after the current milestone is ironed out.

## Learning

As official guides are being developed, see our existing 
comprehensive docs and examples to get up to speed:

  * [Phoenix.LiveView docs for general usage](https://github.com/phoenixframework/phoenix_live_view/blob/master/lib/phoenix_live_view.ex)
  * [phoenix_live_view.js docs](https://github.com/phoenixframework/phoenix_live_view/blob/master/assets/js/phoenix_live_view.js)
  * [Phoenix.LiveViewTest for testing docs](https://github.com/phoenixframework/phoenix_live_view/blob/master/lib/phoenix_live_view/test/live_view_test.ex)
  * [LiveView example repo](https://github.com/chrismccord/phoenix_live_view_example) with a handful of examples from Weather widgets, autocomplete search, and games like Snake or Pacman

## Installation

Currently Live View is only available from GitHub. To use it, add to your `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_live_view, github: "phoenixframework/phoenix_live_view"}
  ]
end
```

Once installed, update your endpoint's configuration to include a signing salt. You can generate a signing salt by running `mix phx.gen.secret 32`.

```elixir
config :my_app, MyAppWeb.Endpoint,
   live_view: [
     signing_salt: "SECRET_SALT"
   ]
```

Update your configuration to enable writing LiveView templates with the `.leex` extension.

```elixir
config :phoenix,
  template_engines: [leex: Phoenix.LiveView.Engine]
```

Next, add the Live View flash plug to your browser pipeline, after `:fetch_flash`:

```elixir
pipeline :browser do
  ...
  plug :fetch_flash
  plug Phoenix.LiveView.Flash
end
```

Then add the following imports to your web file in `lib/app_web.ex`:

```elixir
def view do
  quote do
    ...
    import Phoenix.LiveView, only: [live_render: 2, live_render: 3]
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
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint

  socket "/live", Phoenix.LiveView.Socket

  # ...
end
```

Add LiveView NPM dependencies in your package.json.

```json
{
  "dependencies": {
    "phoenix": "../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view"
  }
}
```

Enable connecting to a LiveView socket in your app.js file.

```javascript
import LiveSocket from "phoenix_live_view"

let liveSocket = new LiveSocket("/live")
liveSocket.connect()
```

Finally, by convention live views are saved in a `lib/app_web/live/`
directory. For live page reload support, add the following pattern to
your `config/dev.exs`:

```elixir
config :demo, DemoWeb.Endpoint,
  live_reload: [
    patterns: [
      ...,
      ~r{lib/demo_web/live/.*(ex)$}
    ]
  ]
```

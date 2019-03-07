# PhoenixLiveView

[![Build Status](https://travis-ci.com/chrismccord/phoenix_live_view.svg?token=Dc4VoVYF33Y2H4Gy8pGi&branch=master)](https://travis-ci.com/chrismccord/phoenix_live_view)

Phoenix LiveView enables rich, real-time user experiences with server-rendered HTML.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `phoenix_live_view` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_live_view, "~> 0.1.0"}
  ]
end
```

Once installed, update your endpoint's configuration to include a signing
salt. You can generate a signing salt by running `mix phx.gen.secret 32`.

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

Expose a new socket for LiveView updates in your app's endpoint module.

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
import LiveSocket from "phoenix_live_view";

let liveSocket = new LiveSocket("/live");
liveSocket.connect();
```

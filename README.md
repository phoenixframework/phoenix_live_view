# Phoenix LiveView

[![Actions Status](https://github.com/phoenixframework/phoenix_live_view/workflows/CI/badge.svg)](https://github.com/phoenixframework/phoenix_live_view/actions?query=workflow%3ACI)

Phoenix LiveView enables rich, real-time user experiences
with server-rendered HTML.

After you [install Elixir](https://elixir-lang.org/install.html)
in your machine, you can create your first LiveView app in two
steps:

    $ mix archive.install hex phx_new
    $ mix phx.new demo --live

## Features

  * Use a declarative model to render HTML on the server
    over WebSockets with optional LongPolling fallback

  * A rich templating language, called HEEx, with support
    for function components, slots, HTML validation, and more

  * Smart change tracking - after connected, LiveView sends
    only what changed to the client, skipping the template
    markup and reducing the payload. This makes LiveView
    payloads much smaller than server-rendered HTML and on
    par with fine-tuned SPA applications

  * Live form validation with file upload support

  * A rich integration API with the client with `phx-click`,
    `phx-focus`, `phx-blur`, `phx-submit`, etc. `phx-hook` is
    included for the cases where you have to write JavaScript

  * Perform optimistic updates and transitions via JavaScript
    commands (`Phoenix.LiveView.JS`)

  * Code reuse via stateful components, which break templates,
    state, and event handling into reusable bits, which is essential
    in large applications

  * Live navigation to enrich links and redirects to only load the
    minimum amount of content as users navigate between pages

  * A latency simulator so you can emulate how slow clients will
    interact with your application

  * Testing tools that allow you to write a confident test suite
    without the complexity of running a whole browser alongside
    your tests

## Official announcements

News from the Phoenix team on LiveView:

  * [Build a real-time Twitter clone with LiveView](https://www.phoenixframework.org/blog/build-a-real-time-twitter-clone-in-15-minutes-with-live-view-and-phoenix-1-5)

  * [Initial announcement](https://dockyard.com/blog/2018/12/12/phoenix-liveview-interactive-real-time-apps-no-need-to-write-javascript)

## Learning

See our existing comprehensive [docs](https://hexdocs.pm/phoenix_live_view) and [guides](https://hexdocs.pm/phoenix_live_view/api-reference.html) for more information.

## Installation

There are currently two methods for installing LiveView. For projects that
require more stability, it is recommended that you install using the
[installation guide on HexDocs](https://hexdocs.pm/phoenix_live_view/installation.html).
If you want to use the latest features, you should follow the instructions
given in the markdown file [here](guides/introduction/installation.md).

## What makes LiveView unique?

LiveView is server centric. You no longer have to worry about managing
both client and server to keep things in sync. LiveView automatically
updates the client as changes happen on the server.

LiveView is first rendered statically as part of regular HTTP requests,
which provides quick times for "First Meaningful Paint", in addition to
helping search and indexing engines.

Then LiveView uses a persistent connection between client and server.
This allows LiveView applications to react faster to user events as
there is less work to be done and less data to be sent compared to
stateless requests that have to authenticate, decode, load, and encode
data on every request.

When LiveView was first announced, many developers from different
backgrounds got inspired about the potential unlocked by LiveView to
build rich, real-time user experiences. We believe LiveView is built
on top of a solid foundation that makes LiveView hard to replicate
anywhere else:

  * LiveView is built on top of the Elixir programming language and
    functional programming, which provides a great model for reasoning
    about your code and how your LiveView changes over time.

  * By building on top of a [scalable platform](https://dockyard.com/blog/2016/08/09/phoenix-channels-vs-rails-action-cable),
    LiveView scales well vertically (from small to large instances)
    and horizontally (by adding more instances). This allows you to
    continue shipping features when more and more users join your
    application, instead of dealing with performance issues.

  * LiveView applications are *distributed and real-time*. A LiveView
    app can push events to users as those events happen anywhere in
    the system. Do you want to notify a user that their best friend
    just connected? This is easily done without a single-line of
    custom JavaScript and with no extra external dependencies
    (no extra databases, no extra message queues, etc).

  * LiveView performs change tracking: whenever you change a value on
    the server, LiveView will send to the client only the values that
    changed, drastically reducing the latency and the amount of data
    sent over the wire. This is achievable thanks to Elixir's
    immutability and its ability to treat code as data.

## Browser Support

All current Chrome, Safari, Firefox, and MS Edge are supported.
IE11 support is available with the following polyfills:

```shell
$ npm install --save --prefix assets mdn-polyfills url-search-params-polyfill formdata-polyfill child-replace-with-polyfill classlist-polyfill new-event-polyfill @webcomponents/template shim-keyboard-event-key core-js
```

Note: The `shim-keyboard-event-key` polyfill is also required for [MS Edge 12-18](https://caniuse.com/#feat=keyboardevent-key).

```javascript
// assets/js/app.js
import "mdn-polyfills/Object.assign"
import "mdn-polyfills/CustomEvent"
import "mdn-polyfills/String.prototype.startsWith"
import "mdn-polyfills/Array.from"
import "mdn-polyfills/Array.prototype.find"
import "mdn-polyfills/Array.prototype.some"
import "mdn-polyfills/NodeList.prototype.forEach"
import "mdn-polyfills/Element.prototype.closest"
import "mdn-polyfills/Element.prototype.matches"
import "mdn-polyfills/Node.prototype.remove"
import "child-replace-with-polyfill"
import "url-search-params-polyfill"
import "formdata-polyfill"
import "classlist-polyfill"
import "new-event-polyfill"
import "@webcomponents/template"
import "shim-keyboard-event-key"
import "core-js/features/set"
import "core-js/features/url"

import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"
...
```

## Contributing

We appreciate any contribution to LiveView.

Please see the Phoenix [Code of Conduct](https://github.com/phoenixframework/phoenix/blob/master/CODE_OF_CONDUCT.md) and [Contributing](https://github.com/phoenixframework/phoenix/blob/master/CONTRIBUTING.md) guides.

Running the Elixir tests:

```bash
$ mix deps.get
$ mix test
```

Running the Javascript tests:
```bash
$ cd assets
$ npm run test
# to automatically run tests for files that have been changed
$ npm run test.watch
```

JS contributions are very welcome, but please do not include an updated `priv/static/phoenix_live_view.js` in pull requests. The maintainers will update it as part of the release process.

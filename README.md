# Phoenix LiveView

[![Actions Status](https://github.com/phoenixframework/phoenix_live_view/workflows/CI/badge.svg)](https://github.com/phoenixframework/phoenix_live_view/actions?query=workflow%3ACI) [![Hex.pm](https://img.shields.io/hexpm/v/phoenix_live_view.svg)](https://hex.pm/packages/phoenix_live_view) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/phoenix_live_view)

Phoenix LiveView enables rich, real-time user experiences with server-rendered HTML.

Visit the [https://livebeats.fly.dev](https://livebeats.fly.dev/) demo to see
the kinds of applications you can build, or see a sneak peek below:

https://user-images.githubusercontent.com/576796/162234098-31b580fe-e424-47e6-b01d-cd2cfcf823a9.mp4

<br />

After you [install Elixir](https://elixir-lang.org/install.html)
on your machine, you can create your first LiveView app in two
steps:

    $ mix archive.install hex phx_new
    $ mix phx.new demo

## Feature highlights

LiveView brings a unified experience to building web applications. You no longer
have to split work between client and server, across different toolings, layers, and
abstractions. Instead, LiveView enriches the server with a declarative and powerful
model while keeping your code closer to your data (and ultimately your source of truth):

  * **Declarative rendering:** Render HTML on the server over WebSockets with a declarative model, including an optional LongPolling fallback.

  * **Rich templating language:** Enjoy HEEx: a templating language that supports function components, slots, HTML validation, verified routes, and more.

  * **Diffs over the wire:** Instead of sending "HTML over the wire", LiveView knows exactly which parts of your templates change, sending minimal diffs over the wire after the initial render, reducing latency and bandwidth usage. The client leverages this information and optimizes the browser with 5-10x faster updates, compared to solutions that replace whole HTML fragments.

  * **Live form validation:** LiveView supports real-time form validation out of the box. Create rich user interfaces with features like uploads, nested inputs, and [specialized recovery](https://hexdocs.pm/phoenix_live_view/form-bindings.html#recovery-following-crashes-or-disconnects).

  * **File uploads:** Real-time file uploads with progress indicators and image previews. Process your uploads on the fly or submit them to your desired cloud service.

  * **Rich integration API:** Use the rich integration API to interact with the client, with `phx-click`, `phx-focus`, `phx-blur`, `phx-submit`, and `phx-hook` included for cases where you have to write JavaScript.

  * **Optimistic updates and transitions:** Perform optimistic updates and transitions with JavaScript commands via `Phoenix.LiveView.JS`.

  * **Loose coupling:** Reuse more code via stateful components with loosely-coupled templates, state, and event handling — a must for enterprise application development.

  * **Live navigation:** Enriched links and redirects are just more ways LiveView keeps your app light and performant. Clients load the minimum amount of content needed as users navigate around your app without any compromise in user experience.

  * **Latency simulator:** Emulate how slow clients will interact with your application with the latency simulator.

  * **Robust test suite:** Write tests with confidence alongside Phoenix LiveView built-in testing tools. No more running a whole browser alongside your tests.

## Learning

Check our [comprehensive docs](https://hexdocs.pm/phoenix_live_view) to get started.

The Phoenix framework documentation also keeps a list of [community resources](https://hexdocs.pm/phoenix/community.html), including books, videos, and other materials, and some include LiveView too.

Also follow these announcements from the Phoenix team on LiveView for more examples and rationale:

  * [LiveBeats: Building a Social Music App With Phoenix LiveView](https://fly.io/blog/livebeats/)

  * [Build a real-time Twitter clone with LiveView](https://www.phoenixframework.org/blog/build-a-real-time-twitter-clone-in-15-minutes-with-live-view-and-phoenix-1-5)

  * [Initial announcement](https://dockyard.com/blog/2018/12/12/phoenix-liveview-interactive-real-time-apps-no-need-to-write-javascript)

## Installation

LiveView is included by default in all new Phoenix v1.6+ applications and
later. If you have an older existing Phoenix app and you wish to add
LiveView, see [the previous installation guide](https://github.com/phoenixframework/phoenix_live_view/blob/v0.20.1/guides/introduction/installation.md).

## What makes LiveView unique?

LiveView is server-centric. You no longer have to worry about managing
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
backgrounds got inspired by the potential unlocked by LiveView to
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
    just connected? This is easily done without a single line of
    custom JavaScript and with no extra external dependencies
    (no extra databases, no Redis, no extra message queues, etc.).

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

Note: The `event-submitter-polyfill` package is also required for [MS Edge 12-80 &amp; Safari &lt; 15.4](https://caniuse.com/mdn-api_submitevent_submitter).

```
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
import "event-submitter-polyfill"
import "core-js/features/set"
import "core-js/features/url"

import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
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

Running all JavaScript tests:
```bash
$ npm run test
```

Running the JavaScript unit tests:

```bash
$ cd assets
$ npm install
$ npm run test
# to automatically run tests for files that have been changed
$ npm run test.watch
```

or simply:

```bash
$ npm run js:test
```

Running the JavaScript end-to-end tests:

```bash
$ npm run e2e:test
```

Checking test coverage:

```bash
$ npm run cover
$ npm run cover:report
```

JS contributions are very welcome, but please do not include an updated `priv/static/phoenix_live_view.js` in pull requests. The maintainers will update it as part of the release process.

# Phoenix LiveView

![Actions Status](https://github.com/phoenixframework/phoenix_live_view/workflows/CI/badge.svg)

Phoenix LiveView enables rich, real-time user experiences with server-rendered HTML. For more information, [see the initial announcement](https://dockyard.com/blog/2018/12/12/phoenix-liveview-interactive-real-time-apps-no-need-to-write-javascript).

**Note**: Currently LiveView is under active development and we are focused on getting a stable and solid initial version out. For this reason, we will be accepting only bug reports in the issues tracker for now. We will open the issues tracker for features after the current milestone is ironed out.

## Learning

As official guides are being developed, see our existing
comprehensive docs and examples to get up to speed:

  * [Phoenix.LiveView docs for Elixir and JavaScript usage](https://hexdocs.pm/phoenix_live_view)
  * [Phoenix.LiveViewTest for testing docs](https://github.com/phoenixframework/phoenix_live_view/blob/master/lib/phoenix_live_view/test/live_view_test.ex)
  * [LiveView example repo](https://github.com/chrismccord/phoenix_live_view_example) with a handful of examples from Weather widgets, autocomplete search, and games like Snake or Pacman

## Installation

There are currently two methods for installing LiveView. For projects that
require more stability, it is recommended that you install using the
[installation guide on HexDocs](https://hexdocs.pm/phoenix_live_view/installation.html).
If you want to use the latest features, you should follow the instructions
given in the markdown file [here](guides/introduction/installation.md).

## Browser Support

All current Chrome, Safari, Firefox, and MS Edge are supported.
IE11 support is available with the following polyfills:

```console
$ npm install --save --prefix assets mdn-polyfills url-search-params-polyfill formdata-polyfill child-replace-with-polyfill classlist-polyfill
```

```javascript
// assets/js/app.js
import "mdn-polyfills/CustomEvent"
import "mdn-polyfills/String.prototype.startsWith"
import "mdn-polyfills/Array.from"
import "mdn-polyfills/NodeList.prototype.forEach"
import "mdn-polyfills/Element.prototype.closest"
import "mdn-polyfills/Element.prototype.matches"
import "child-replace-with-polyfill"
import "url-search-params-polyfill"
import "formdata-polyfill"
import "classlist-polyfill"

import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"
...
```

# Changelog for v1.1

## Quick update guide

Here is a quick summary of the changes necessary to upgrade to LiveView v1.1:

1. In your `mix.exs`, update `phoenix_live_view` to latest and add `lazy_html` as a dependency:

    ```elixir
    {:phoenix_live_view, "~> 1.1"},
    {:lazy_html, ">= 0.0.0", only: :test},
    ```

   Note you may remove `floki` as a dependency if you don't use it anywhere.

2. In your `config/dev.exs`, find `debug_heex_annotations`, and also add `debug_tags_location`:

    ```elixir
    config :phoenix_live_view,
      debug_heex_annotations: true,
      debug_tags_location: true,
      enable_expensive_runtime_checks: true
    ```

## Types for public interfaces

LiveView 1.1 adds official types to the JavaScript client. This allows IntelliSense to work in editors that support it and is a massive improvement to the user experience when writing JavaScript hooks.

If you're not using TypeScript, you can also add the necessary JSDoc hints to your hook definitions, assuming your editor supports them.

Example when defining a hook object that is meant to be passed to the `LiveSocket` constructor:

```javascript
/**
 * @type {import("phoenix_live_view").HooksOptions}
 */
let Hooks = {}
Hooks.PhoneNumber = {
  mounted() {
    this.el.addEventListener("input", e => {
      let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
      if(match) {
        this.el.value = `${match[1]}-${match[2]}-${match[3]}`
      }
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, ...})
...
```

Example when defining a hook on its own:

```javascript
/**
 * @type {import("phoenix_live_view").Hook}
 */
Hooks.InfiniteScroll = {
  page() { return this.el.dataset.page },
  mounted(){
    this.pending = this.page()
    window.addEventListener("scroll", e => {
      if(this.pending == this.page() && scrollAt() > 90){
        this.pending = this.page() + 1
        this.pushEvent("load-more", {})
      }
    })
  },
  updated(){ this.pending = this.page() }
}
```

Also, hooks can now be defined as a subclass of `ViewHook`, if you prefer [native classes](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/class):

```javascript
import { LiveSocket, ViewHook } from "phoenix_live_view"

class MyHook extends ViewHook {
  mounted() {
    ...
  }
}

let liveSocket = new LiveSocket(..., {
  hooks: {
    MyHook
  }
})
```

Using [`@types/phoenix_live_view`](https://www.npmjs.com/package/@types/phoenix_live_view) (not maintained by the Phoenix team) is not necessary any more.

## JS.ignore_attributes

Sometimes it is useful to prevent some attributes from being patched by LiveView. One example where this frequently came up is when using a native `<dialog>` or `<details>` element that is controlled by the `open` attribute, which is special in that it is actually set (and removed) by the browser. Previously, LiveView would remove those attributes on update and required additional patching, now you can simply call `JS.ignore_attributes` in a `phx-mounted` binding:

```heex
<details phx-mounted={JS.ignore_attributes(["open"])}>
  <summary>...</summary>
  ...
</details>
```

## Moving from Floki to LazyHTML

LiveView 1.1 moves to [LazyHTML](https://hexdocs.pm/lazy_html/) as the HTML engine used by `LiveViewTest`. LazyHTML is based on [lexbor](https://github.com/lexbor/lexbor) and allows the use of modern CSS selector features, like `:is()`, `:has()`, etc. to target elements. Lexbor's stated goal is to create output that "should match that of modern browsers, meeting industry specifications".

This is a mostly backwards compatible change. The only way in which this affects LiveView projects is when using Floki specific selectors (`fl-contains`, `fl-icontains`), which will not work any more in selectors passed to LiveViewTest's [`element/3`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#element/3) function. In most cases, the `text_filter` option of [`element/3`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#element/3) should be a sufficient replacement, which has been a feature since LiveView v0.12.0.

Note that in Phoenix versions prior to v1.8, the `phx.gen.auth` generator used the Floki specific `fl-contains` selector in its generated tests in two instances, so if you used the `phx.gen.auth` generator to scaffold your authentication solution, those tests will need to be adjusted when updating to LiveView v1.1. In both cases, changing to use the `text_filter` option is enough to get you going again:

```diff
 {:ok, _login_live, login_html} =
   lv
-  |> element(~s|main a:fl-contains("Sign up")|)
+  |> element("main a", "Sign up")
   |> render_click()
   |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/register")
```

If you're using Floki itself in your tests through its API (`Floki.parse_document`, `Floki.find`, etc.), you are not required to rewrite them when you update to LiveView v1.1.

## Slot and line annotations

When `:debug_heex_annotations` is enabled, LiveView will now annotate the beginning and end of each slot. A new `:debug_tags_location` has also been added, which adds the starting line of each tag. The goal is to provide more precise information to tools.

To enable this, a new callback called `annotate_slot/4` was added. Custom implementations of `Phoenix.LiveView.TagEngine` must implement it accordingly.

## v1.1.0

### Enhancements

* Add type annotations to all public JavaScript APIs ([#3789](https://github.com/phoenixframework/phoenix_live_view/pull/3789))
* Normalize whitespace in LiveViewTest's text filters ([#3621](https://github.com/phoenixframework/phoenix_live_view/pull/3621))
* Raise by default when LiveViewTest detects duplicate DOM or LiveComponent IDs. This can be changed by passing `on_error` to `Phoenix.LiveViewTest.live/3` / `Phoenix.LiveViewTest.live_isolated/3`
* Use [`LazyHTML`](https://hexdocs.pm/lazy_html/) instead of [Floki](https://hexdocs.pm/floki) internally for LiveViewTest
* Add `Phoenix.LiveView.JS.ignore_attributes/1` to allow marking specific attributes to be ignored when LiveView patches an element ([#3765](https://github.com/phoenixframework/phoenix_live_view/pull/3765))
* Raise an exception when trying to bind a single DOM element to multiple views (this could happen when accidentally loading your app.js twice) ([#3805](https://github.com/phoenixframework/phoenix_live_view/pull/3805))
* Add `Phoenix.LiveView.Debug` module with functions for inspecting LiveViews at runtime ([#3776](https://github.com/phoenixframework/phoenix_live_view/pull/3776))
* Ensure promise rejections include stack traces ([#3738](https://github.com/phoenixframework/phoenix_live_view/pull/3738))

## v1.0

The CHANGELOG for v1.0 and earlier releases can be found in the [v1.0 branch](https://github.com/phoenixframework/phoenix_live_view/blob/v1.0/CHANGELOG.md).

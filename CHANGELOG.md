# Changelog for v1.1

## Quick update guide

Here is a quick summary of the changes necessary to upgrade to LiveView v1.1:

1. In your `mix.exs`, update `phoenix_live_view` to latest and add `lazy_html` as a dependency:

    ```elixir
    {:phoenix_live_view, "~> 1.1"},
    {:lazy_html, ">= 0.0.0", only: :test},
    ```

   Note you may remove `floki` as a dependency if you don't use it anywhere.

2. Still in your `mix.exs`, prepend `:phoenix_live_view` to your list of compilers inside `def project`, such as:

    ```elixir
    compilers: [:gettext, :phoenix_live_view] ++ Mix.compilers(),
    ```

3. (optional) In your `config/dev.exs`, find `debug_heex_annotations`, and also add `debug_tags_location` for improved annotations:

    ```elixir
    config :phoenix_live_view,
      debug_heex_annotations: true,
      debug_tags_location: true,
      enable_expensive_runtime_checks: true
    ```

4. (optional) To enable colocated hooks, you must update `esbuild` with `mix deps.update esbuild` and then update your `config/config.exs` accordingly. In particular, append `--alias:@=.` to the `args` list and pass a list of paths to the `"NODE_PATH"` env var, as shown below:

    ```elixir
    your_app_name: [
      args:
        ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
      env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]},
    ```

## Macro components and colocated hooks

A `Phoenix.Component.MacroComponent` defines a compile-time transformation of a HEEx tag. This can be used to transform a tag and its content into something else, for example to perform compile time syntax highlighting, or even remove tags from the template entirely and write them elsewhere. `Phoenix.LiveView.ColocatedHook` is a macro component that allows you to co-locate LiveView [JavaScript hooks](https://hexdocs.pm/phoenix_live_view/js-interop.html#client-hooks-via-phx-hook) next to the component code that uses them, while ensuring they are included in your regular JavaScript bundle. A colocated hook is defined by placing the special `:type` attribute on a `<script>` tag:

```elixir
alias Phoenix.LiveView.ColocatedHook

def input(%{type: "phone-number"} = assigns) do
  ~H"""
  <input type="text" name={@name} id={@id} value={@value} phx-hook=".PhoneNumber" />
  <script :type={ColocatedHook} name=".PhoneNumber">
    export default {
      mounted() {
        this.el.addEventListener("input", e => {
          let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
          if(match) {
            this.el.value = `${match[1]}-${match[2]}-${match[3]}`
          }
        })
      }
    }
  </script>
  """
end
```

Important: LiveView now supports the `phx-hook` attribute to start with a dot (`.PhoneNumber` above) for namespacing. Any hook name starting with a dot is prefixed at compile time with the module name of the component. If you named your hooks with a leading dot in the past, you'll need to adjust this for your hooks to work properly on LiveView 1.1.

Colocated hooks are extracted to a `phoenix-colocated` folder inside your `_build/$MIX_ENV` directory (`Mix.Project.build_path()`). See the quick update section at the top of the changelog on how to adjust your `esbuild` configuration to handle this. With everything configured, you can import your colocated hooks inside of your `app.js` like this:

```diff
...
  import {LiveSocket} from "phoenix_live_view"
+ import {hooks as colocatedHooks} from "phoenix-colocated/my_app"
  import topbar from "../vendor/topbar"
...
  const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
+   params: {_csrf_token, csrfToken},
+   hooks: {...colocatedHooks}
  })
```

The `phoenix-colocated` folder has subfolders for each application that uses colocated hooks, therefore you'll need to adjust the `my_app` part of the import depending on the name of your project (defined in your `mix.exs`). You can read more about colocated hooks in the module documentation of `Phoenix.LiveView.ColocatedHook` and `Phoenix.LiveView.ColocatedJS`.

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

## Phoenix.Component.portal

When designing reusable HTML components for UI elements like tooltips or dialogs, it is sometimes necessary to render a part of a component's template outside of the regular DOM hierarchy of that component, for example to prevent clipping due to CSS rules like `overflow: hidden` that are not controlled by the component itself. Modern browser APIs for rendering elements in [the top layer](https://developer.mozilla.org/en-US/docs/Glossary/Top_layer) can help in many cases, but if you cannot use those for whatever reasons, LiveView previously did not have a solution to solve that problem. In LiveView 1.1, we introduce a new `.portal` component:

```heex
<%!-- somewhere in the DOM, for example in your root.html.heex --%>
<div id="portal-target"></div>

<%!-- in some nested LiveView or component --%>
<.portal id="my-element" target="portal-target">
  <%!-- any content here will be teleported into the #portal-target --%>
</.portal>
```

Any element can be teleported, even LiveComponents and nested LiveViews, and any `phx-*` events from inside a portal will still be handled by the correct LiveView. This is similar to [`<Teleport>` in Vue.js](https://vuejs.org/guide/built-ins/teleport) or [`createPortal` in React](https://react.dev/reference/react-dom/createPortal).

As a demo, we created [an example for implementing tooltips using `Phoenix.Component.portal`](https://gist.github.com/SteffenDE/f599405c7c2eddbb14723ed4f3b7213f) as a single-file Elixir script. When saved as `portal.exs`, you can execute it as `elixir portal.exs` and visit `http://localhost:5001` in your browser.

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
* Add `Phoenix.LiveView.JS.ignore_attributes/1` to allow marking specific attributes to be ignored when LiveView patches an element ([#3765](https://github.com/phoenixframework/phoenix_live_view/pull/3765))
* Add `Phoenix.LiveView.Debug` module with functions for inspecting LiveViews at runtime ([#3776](https://github.com/phoenixframework/phoenix_live_view/pull/3776))
* Add `Phoenix.Component.MacroComponent` ([#3810](https://github.com/phoenixframework/phoenix_live_view/pull/3810))
* Add `Phoenix.LiveView.ColocatedHook` and `Phoenix.LiveView.ColocatedJS` ([#3810](https://github.com/phoenixframework/phoenix_live_view/pull/3810))
* Add `:update_only` option to `Phoenix.LiveView.stream_insert/4` ([#3573](https://github.com/phoenixframework/phoenix_live_view/pull/3573))
* Use [`LazyHTML`](https://hexdocs.pm/lazy_html/) instead of [Floki](https://hexdocs.pm/floki) internally for LiveViewTest
* Normalize whitespace in LiveViewTest's text filters ([#3621](https://github.com/phoenixframework/phoenix_live_view/pull/3621))
* Raise by default when LiveViewTest detects duplicate DOM or LiveComponent IDs. This can be changed by passing `on_error` to `Phoenix.LiveViewTest.live/3` / `Phoenix.LiveViewTest.live_isolated/3`
* Raise an exception when trying to bind a single DOM element to multiple views (this could happen when accidentally loading your app.js twice) ([#3805](https://github.com/phoenixframework/phoenix_live_view/pull/3805))
* Ensure promise rejections include stack traces ([#3738](https://github.com/phoenixframework/phoenix_live_view/pull/3738))
* Treat form associated custom elements as form inputs ([3823](https://github.com/phoenixframework/phoenix_live_view/pull/3823))

## v1.0

The CHANGELOG for v1.0 and earlier releases can be found in the [v1.0 branch](https://github.com/phoenixframework/phoenix_live_view/blob/v1.0/CHANGELOG.md).

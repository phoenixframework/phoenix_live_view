# Changelog for v1.1

## Quick update guide

When updating from LiveView 1.0, you can also use [igniter](https://hexdocs.pm/igniter) to perform the following changes for you:

```bash
# Prior to / without running `mix deps.update`
mix igniter.upgrade phoenix_live_view

# Or if you have previously run `mix deps.update phoenix_live_view` or are upgrading from a release candidate.
mix igniter.apply_upgrades phoenix_live_view:1.0.0:1.1.0
```

Here is a quick summary of the changes necessary to upgrade to LiveView v1.1:

1. In your `mix.exs`, update `phoenix_live_view` to latest and add `lazy_html` as a dependency:

    ```elixir
    {:phoenix_live_view, "~> 1.1"},
    {:lazy_html, ">= 0.0.0", only: :test},
    ```

   Note you may remove `floki` as a dependency if you don't use it anywhere.

2. Still in your `mix.exs`, prepend `:phoenix_live_view` to your list of compilers inside `def project`, such as:

    ```elixir
    compilers: [:phoenix_live_view] ++ Mix.compilers(),
    ```

3. (optional) In your `config/dev.exs`, find `debug_heex_annotations`, and also add `debug_attributes` for improved annotations:

    ```elixir
    config :phoenix_live_view,
      debug_heex_annotations: true,
      debug_attributes: true,
      enable_expensive_runtime_checks: true
    ```

4. (optional) To enable colocated hooks, you must update `esbuild` with `mix deps.update esbuild` and then update your `config/config.exs` accordingly. In particular, append `--alias:@=.` to the `args` list and pass a list of paths to the `"NODE_PATH"` env var, as shown below:

    ```elixir
    your_app_name: [
      args:
        ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
      env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]},
    ```

## Colocated hooks

LiveView v1.1 introduces colocated hooks to allow writing the hook's JavaScript code in the same file as your regular component code.

A colocated hook is defined by placing the special `:type` attribute on a `<script>` tag:

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

Important: LiveView now supports the `phx-hook` attribute to start with a dot (`.PhoneNumber` above) for namespacing. Any hook name starting with a dot is prefixed at compile time with the module name of the component. If you named your hooks with a leading dot in the past, you'll need to adjust this for your hooks to work properly on LiveView v1.1.

Colocated hooks are extracted to a `phoenix-colocated` folder inside your `_build/$MIX_ENV` directory (`Mix.Project.build_path()`). See the quick update section at the top of the changelog on how to adjust your `esbuild` configuration to handle this. With everything configured, you can import your colocated hooks inside of your `app.js` like this:

```diff
...
  import {LiveSocket} from "phoenix_live_view"
+ import {hooks as colocatedHooks} from "phoenix-colocated/my_app"
  import topbar from "../vendor/topbar"
...
  const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: {_csrf_token: csrfToken},
+   hooks: {...colocatedHooks}
  })
```

The `phoenix-colocated` folder has subfolders for each application that uses colocated hooks, therefore you'll need to adjust the `my_app` part of the import depending on the name of your project (defined in your `mix.exs`). You can read more about colocated hooks in the module documentation of `Phoenix.LiveView.ColocatedHook`. There's also a more generalized version for colocated JavaScript, see the documentation for `Phoenix.LiveView.ColocatedJS`.

We're planning to make the private `Phoenix.Component.MacroComponent` API that we use for those features public in a future release.

Note: Colocated hooks require Phoenix 1.8+.

> #### Compilation order {: .info}
>
> Colocated hooks are only written when the corresponding component is compiled.
> Therefore, whenever you need to access a colocated hook, you need to ensure
> `mix compile` runs first. This automatically happens in development.
>
> If you have a custom mix alias, instead of
>
> ```
> release: ["assets.deploy", "release"]
> ```
>
> do
>
> ```
> release: ["compile", "assets.deploy", "release"]
> ```
>
> to ensure that all colocated hooks are extracted before esbuild or any other bundler runs.
>
> If you have a `Dockerfile` based on `mix phx.gen.release --docker`, ensure that `mix compile` runs before `mix assets.deploy`.

## Change tracking in comprehensions

One pitfall when rendering collections in LiveView was that they were not change tracked. If you had code like this:

```heex
<ul>
  <li :for={item <- @items}>{item.name}</li>
</ul>
```

When changing `@items`, all elements were re-sent over the wire. LiveView still optimized the static and dynamic parts of the template, but if you had 100 items in your list and only changed a single one (also applies to append, prepend, etc.), LiveView still sent the dynamic parts of all items.

To improve this, LiveView prior to v1.1 had two solutions:

1. Use streams. Streams are not kept in memory on the server and if you `stream_insert` a single item, only that item is sent over the wire. But because the server does not keep any state for streams, this also means that if you update an item in a stream, all the dynamic parts of the updated item are sent again.
2. Use a LiveComponent for each entry. LiveComponents perform change tracking on their own assigns. So when you update a single item, LiveView only sends a list of component IDs and the changed parts for that item.

So LiveComponents allow for more granular diffs and also a more declarative approach than streams, but require more memory on the server. Thus, when memory usage is a concern, especially for very large collections, streams should be your first choice. Another downside of LiveComponents is that they require you to write a whole separate module just to get an optimized diff.

LiveView v1.1 changes how comprehensions are handled to enable change tracking by default. If you only change a single item in a list, only its changes are sent. To do this, LiveView uses an element's index to track changes. This means that if you prepend an entry in a list, all items after the new one will be sent again. To improve this even further, LiveView v1.1 introduces a new `:key` attribute that can be used with `:for`:

```heex
<ul>
  <li :for={item <- @items} :key={item.id}>{item.name}</li>
</ul>
```

LiveView uses the key to efficiently calculate a diff that only contains the new indexes of moved items. Change tracking in comprehensions comes with a slightly increased memory footprint. If memory is a concern, you should think about using streams.

## Types for public interfaces

LiveView v1.1 adds official types to the JavaScript client. This allows IntelliSense to work in editors that support it and is a massive improvement to the user experience when writing JavaScript hooks. If you're not using TypeScript, you can also add the necessary JSDoc hints to your hook definitions, assuming your editor supports them.

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

Using [`@types/phoenix_live_view`](https://www.npmjs.com/package/@types/phoenix_live_view) (not maintained by the Phoenix team) is no longer necessary.

## `<.portal>` component

When designing reusable HTML components for UI elements like tooltips or dialogs, it is sometimes necessary to render a part of a component's template outside of the regular DOM hierarchy of that component, for example to prevent clipping due to CSS rules like `overflow: hidden` that are not controlled by the component itself. Modern browser APIs for rendering elements in [the top layer](https://developer.mozilla.org/en-US/docs/Glossary/Top_layer) can help in many cases, but if you cannot use those for whatever reasons, LiveView previously did not have a solution to solve that problem. In LiveView v1.1, we introduce a new `Phoenix.Component.portal/1` component:

```heex
<%!-- in some nested LiveView or component --%>
<.portal id="my-element" target="body">
  <%!-- any content here will be teleported into the body tag --%>
</.portal>
```

Any element can be teleported, even LiveComponents and nested LiveViews, and any `phx-*` events from inside a portal will still be handled by the correct LiveView. This is similar to [`<Teleport>` in Vue.js](https://vuejs.org/guide/built-ins/teleport) or [`createPortal` in React](https://react.dev/reference/react-dom/createPortal).

As a demo, we created [an example for implementing tooltips using `Phoenix.Component.portal`](https://gist.github.com/SteffenDE/f599405c7c2eddbb14723ed4f3b7213f) as a single-file Elixir script. When saved as `portal.exs`, you can execute it as `elixir portal.exs` and visit `http://localhost:5001` in your browser.

## `JS.ignore_attributes`

Sometimes it is useful to prevent some attributes from being patched by LiveView. One example where this frequently came up is when using a native `<dialog>` or `<details>` element that is controlled by the `open` attribute, which is special in that it is actually set (and removed) by the browser. Previously, LiveView would remove those attributes on update and required additional patching, now you can simply call `JS.ignore_attributes` in the `phx-mounted` attribute:

```heex
<details phx-mounted={JS.ignore_attributes(["open"])}>
  <summary>...</summary>
  ...
</details>
```

## Moving from Floki to LazyHTML

LiveView v1.1 moves to [LazyHTML](https://hexdocs.pm/lazy_html/) as the HTML engine used by `LiveViewTest`. LazyHTML is based on [lexbor](https://github.com/lexbor/lexbor) and allows the use of modern CSS selector features, like `:is()`, `:has()`, etc. to target elements. Lexbor's stated goal is to create output that "should match that of modern browsers, meeting industry specifications".

This is a mostly backwards compatible change. The only way in which this affects LiveView projects is when using Floki specific selectors (`fl-contains`, `fl-icontains`), which will not work any more in selectors passed to LiveViewTest's [`element/3`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#element/3) function. In most cases, the `text_filter` option of [`element/3`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#element/3) should be a sufficient replacement, which has been available since LiveView v0.12.

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

When `:debug_heex_annotations` is enabled, LiveView will now annotate the beginning and end of each slot. A new `:debug_attributes` option has also been added, which adds the starting line of each tag as a `data-phx-loc` attribute. It also adds the LiveView PID to the root element of each LiveView. The goal is to provide more precise information to tools.

To enable this, a new callback called `annotate_slot/4` was added. Custom implementations of `Phoenix.LiveView.TagEngine` must implement it accordingly.

## v1.1.14 (2025-10-07)

### Bug fixes

* Fix form recovery not working when form is teleported ([#4009](https://github.com/phoenixframework/phoenix_live_view/pull/4009))
* Fix `handle_event` hook not being able to return `{:halt, reply, socket}` in LiveComponents ([#4006](https://github.com/phoenixframework/phoenix_live_view/pull/4006))
* Only set title to default when it is set to empty by the main view, not by nested or sticky views ([#4003](https://github.com/phoenixframework/phoenix_live_view/issues/4003))

### Enhancements

* Automatically update esbuild version when using Igniter upgrader from 1.0 to 1.1 ([#4011](https://github.com/phoenixframework/phoenix_live_view/pull/4011))
* Fix unused require warnings on Elixir 1.19

## v1.1.13 (2025-09-18)

### Bug fixes

* Fix invalid stream merging in LiveViewTest ([#3993](https://github.com/phoenixframework/phoenix_live_view/issues/3993))
* Fix extra spaces when formatting nested inline tags ([#3995](https://github.com/phoenixframework/phoenix_live_view/pull/3995))
* Ensure error reasons are serialized into message on the client ([#3984](https://github.com/phoenixframework/phoenix_live_view/pull/3984))
* Prevent JavaScript exception when passing `"*"` to `JS.ignore_attributes/3` ([#3996](https://github.com/phoenixframework/phoenix_live_view/issues/3996))

## v1.1.12 (2025-09-14)

### Bug fixes

* Prevent HEEx line from being reported as uncovered when using a pattern in `:let={}` ([#3989](https://github.com/phoenixframework/phoenix_live_view/pull/3989))

### Enhancements

* Automatically symlink `assets/node_modules` folder for colocated hooks (see the documentation for `Phoenix.LiveView.ColocatedJS`, [#3988](https://github.com/phoenixframework/phoenix_live_view/pull/3988))

## v1.1.11 (2025-09-04)

### Bug fixes

* Fix LiveComponents being destroyed when their DOM ID changes, even though they are still rendered ([#3981](https://github.com/phoenixframework/phoenix_live_view/pull/3981))
* Fix warning when an empty comprehension is rendered in LiveViewTest

### Enhancements

* Speed up duplicate ID check in LiveViewTest ([#3962](https://github.com/phoenixframework/phoenix_live_view/pull/3962))

## v1.1.10 (2025-09-03)

### Bug fixxes

* Regression in v1.1.9 - fix `Phoenix.LiveViewTest.submit_form/2` and `Phoenix.LiveViewTest.follow_trigger_action/2` crashing when using keywords lists and not properly handling atom keys ([#3975](https://github.com/phoenixframework/phoenix_live_view/issues/3975))

## v1.1.9 (2025-09-02)

### Bug fixes

* Fix moved comprehension diff crashing LiveViewTest ([#3963](https://github.com/phoenixframework/phoenix_live_view/pull/3963))
* Ensure `push_patch` works during form recovery ([#3964](https://github.com/phoenixframework/phoenix_live_view/issues/3964))
* Fix diff crash in LiveViewTest when rendering structs ([#3970](https://github.com/phoenixframework/phoenix_live_view/pull/3970))

### Enhancements

* Include form values from DOM in `Phoenix.LiveViewTest.submit_form/2` and `Phoenix.LiveViewTest.follow_trigger_action/2` to mimic browser behavior ([#3885](https://github.com/phoenixframework/phoenix_live_view/issues/3885))
* Allow assigning generic hooks to type `Hook` ([#3955](https://github.com/phoenixframework/phoenix_live_view/issues/3955))
* Allow typing hook element when using TypeScript ([#3956](https://github.com/phoenixframework/phoenix_live_view/issues/3956))
* Add more metadata to `phx:page-loading-start` event in case of errors ([#3910](https://github.com/phoenixframework/phoenix_live_view/issues/3910))

## v1.1.8 (2025-08-20)

### Bug fixes

* Fix race condition where patches were discarded when a join was still pending ([#3957](https://github.com/phoenixframework/phoenix_live_view/issues/3957), big thank you to [@DaTrader](https://github.com/DaTrader))

## v1.1.7 (2025-08-18)

### Bug fixes

* Fix regression introduced in v1.1.6

## v1.1.6 (2025-08-18)

### Bug fixes

* Fix live components in nested views accidentally destroying live components in parent views ([#3953](https://github.com/phoenixframework/phoenix_live_view/issues/3953))

## v1.1.5 (2025-08-18)

### Bug fixes

* Fix hooks not working when used inside of `Phoenix.Component.portal/1` ([#3950](https://github.com/phoenixframework/phoenix_live_view/issues/3950))
* Fix form participating custom elements not being reset to empty in some cases ([#3946](https://github.com/phoenixframework/phoenix_live_view/pull/3946))

### Enhancements

* Allow `assign_async` to return a keyword list
* Add `Phoenix.LiveView.stream_async/4` to asynchronously insert items into a stream

## v1.1.4 (2025-08-13)

### Bug fixes

* Fix LiveComponent updates being inadvertently discarded in rare circumstances when locked DOM trees are restored ([#3941](https://github.com/phoenixframework/phoenix_live_view/issues/3941))

## v1.1.3 (2025-08-05)

### Bug fixes

* Fix warning when importing LiveView JS ([#3926](https://github.com/phoenixframework/phoenix_live_view/pull/3926))
* Ensure form recovery respects fieldsets ([#3921](https://github.com/phoenixframework/phoenix_live_view/pull/3921))
* LiveViewTest: Fix crash when submitting a form with custom submitter, but without ID ([#3927](https://github.com/phoenixframework/phoenix_live_view/issues/3927))
* LiveViewTest: Ensure whitespace in textarea content is preserved when submitting a form ([#3928](https://github.com/phoenixframework/phoenix_live_view/pull/3928))
* Make hook types less strict ([#3913](https://github.com/phoenixframework/phoenix_live_view/issues/3913))

### Enhancements

* HTMLFormatter: do not try to format attributes into a single line when they are spread over multiple lines.
  This follows the behavior of the Elixir formatter that also respects newlines.
* Re-enable component change tracking in case the dynamic expression does not have any dependencies, for example:
  `<.my_component some="key" {%{static: "map"}}>` ([#3936](https://github.com/phoenixframework/phoenix_live_view/pull/3936))

## v1.1.2 (2025-07-31)

### Bug fixes

* Fix invalid component rendering when using dynamic assigns (`<.my_component {...}>`) in rare circumstances by
  disabling change tracking. LiveView cannot properly track changes in those cases and this could lead to weird bugs ([#3919](https://github.com/phoenixframework/phoenix_live_view/issues/3919))
  that were now more likely to surface with change tracked comprehensions.
* Fix `LiveViewTest` not considering some LiveViews as main when using `live_render` ([#3917](https://github.com/phoenixframework/phoenix_live_view/issues/3917))
* Fix JavaScript type definitions not being considered when using TypeScript in `bundler` resolution mode ([#3915](https://github.com/phoenixframework/phoenix_live_view/pull/3915))

## v1.1.1 (2025-07-30)

### Bug fixes

* Fix `key will be overridden in map` warning ([#3912](https://github.com/phoenixframework/phoenix_live_view/issues/3912))

## v1.1.0 (2025-07-30) 🚀

### Bug fixes

* Ensure nested variable access is properly change tracked in components ([#3908](https://github.com/phoenixframework/phoenix_live_view/pull/3908))

## v1.1.0-rc.4 (2025-07-22)

### Enhancements

* Rename `debug_tags_location` to `debug_attributes` and add `data-phx-pid` ([#3898](https://github.com/phoenixframework/phoenix_live_view/pull/3898))
* Simplify code generated for slots in HEEx when the slot does not contain any dynamic code ([#3902](https://github.com/phoenixframework/phoenix_live_view/pull/3902))

### Bug fixes

* Prevent `focus_wrap` from focusing the last element instead of the first on Firefox in rare cases ([#3895](https://github.com/phoenixframework/phoenix_live_view/pull/3895))
* Ensure comprehension entries perform a full render when change tracking is disabled ([#3904](https://github.com/phoenixframework/phoenix_live_view/pull/3904))

## v1.1.0-rc.3 (2025-07-15)

### Enhancements

* Add [igniter](https://hexdocs.pm/igniter) upgrader for LiveView 1.0 to 1.1: `mix igniter.upgrade phoenix_live_view@1.1.0-rc.3` ([#3889](https://github.com/phoenixframework/phoenix_live_view/pull/3889))
  * Note: before the final release, the actual upgrade requires a separate `mix igniter.apply_upgrades phoenix_live_view:1.0.0:1.1.0` after updating the dependency
* Allow `ColocatedHook`s to work at the root of a LiveComponent ([#3882](https://github.com/phoenixframework/phoenix_live_view/pull/3882))
* Use `"on"` as default value for checkboxes in LiveViewTest ([#3886](https://github.com/phoenixframework/phoenix_live_view/pull/3886))
* Raise when using `ColocatedHook` / `ColocatedJS` on an unsupported Phoenix version

## v1.1.0-rc.2 (2025-07-05)

### Enhancements

* Allow omitting the `name` attribute when using `Phoenix.LiveView.ColocatedJS` ([#3860](https://github.com/phoenixframework/phoenix_live_view/pull/3860))
* Add change tracking in comprehensions by default; `:key` does not use LiveComponents anymore which allows it to be used on components and improves payload sizes ([#3865](https://github.com/phoenixframework/phoenix_live_view/pull/3865))

### Bug fixes

* Fix `Phoenix.LiveView.Debug.live_components/1` raising instead of returning an error tuple ([#3861](https://github.com/phoenixframework/phoenix_live_view/pull/3861))

## v1.1.0-rc.1 (2025-06-20)

### Bug fixes

* Fix variable tainting which could cause some template parts to not be re-rendered ([#3856](https://github.com/phoenixframework/phoenix_live_view/pull/3856)).

## v1.1.0-rc.0 (2025-06-17)

### Enhancements

* Add type annotations to all public JavaScript APIs ([#3789](https://github.com/phoenixframework/phoenix_live_view/pull/3789))
* Add `Phoenix.LiveView.JS.ignore_attributes/1` to allow marking specific attributes to be ignored when LiveView patches an element ([#3765](https://github.com/phoenixframework/phoenix_live_view/pull/3765))
* Add `Phoenix.LiveView.Debug` module with functions for inspecting LiveViews at runtime ([#3776](https://github.com/phoenixframework/phoenix_live_view/pull/3776))
* Add `Phoenix.LiveView.ColocatedHook` and `Phoenix.LiveView.ColocatedJS` ([#3810](https://github.com/phoenixframework/phoenix_live_view/pull/3810))
* Add `:update_only` option to `Phoenix.LiveView.stream_insert/4` ([#3573](https://github.com/phoenixframework/phoenix_live_view/pull/3573))
* Use [`LazyHTML`](https://hexdocs.pm/lazy_html/) instead of `Floki` internally for LiveViewTest
* Normalize whitespace in LiveViewTest's text filters ([#3621](https://github.com/phoenixframework/phoenix_live_view/pull/3621))
* Raise by default when LiveViewTest detects duplicate DOM or LiveComponent IDs. This can be changed by passing `on_error` to `Phoenix.LiveViewTest.live/3` / `Phoenix.LiveViewTest.live_isolated/3`
* Raise an exception when trying to bind a single DOM element to multiple views (this could happen when accidentally loading your app.js twice) ([#3805](https://github.com/phoenixframework/phoenix_live_view/pull/3805))
* Ensure promise rejections include stack traces ([#3738](https://github.com/phoenixframework/phoenix_live_view/pull/3738))
* Treat form associated custom elements as form inputs ([3823](https://github.com/phoenixframework/phoenix_live_view/pull/3823))
* Add `:inline_matcher` option to `Phoenix.LiveView.HTMLFormatter` which can be configured as a list of strings and regular expressions to match against tag names to treat them as inline ([#3795](https://github.com/phoenixframework/phoenix_live_view/pull/3795))

## v1.0

The CHANGELOG for v1.0 and earlier releases can be found in the [v1.0 branch](https://github.com/phoenixframework/phoenix_live_view/blob/v1.0/CHANGELOG.md).

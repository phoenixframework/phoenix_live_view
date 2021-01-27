# Changelog

## 0.15.4 (2021-01-26)

### Bug fixes
  - Fix nested `live_render`'s causing remound of child LiveView even when ID does not change
  - Do not attempt push hook events unless connected
  - Fix preflighted refs causing `auto_upload: true` to fail to submit form
  - Replace single upload entry when max_entires is 1 instead of accumulating multiple file selections
  - Fix static_path in open_browser failing to load stylesheets

## 0.15.3 (2021-01-02)

### Bug fixes
  - Fix `push_redirect` back causing timeout on the client

## 0.15.2 (2021-01-01)

### Backwards incompatible changes
  - Remove `beforeDestroy` from phx-hook callbacks

### Bug fixes
  - Fix form recovery failing to send input on first connection failure
  - Fix hooks not getting remounted after liveview reconnect
  - Fix hooks `reconnected` callback being fired with no prior disconnect

## 0.15.1 (2020-12-20)

### Enhancements
  - Ensure all click events bubble for mobile Safari
  - Run `consume_uploaded_entries` in LiveView caller process

### Bug fixes
  - Fix hooks not getting remounted after liveview recovery
  - Fix bug causing reload with jitter on timeout from previously closed channel
  - Fix component child nodes being lost when component patch goes from single root node to multiple child siblings
  - Fix `phx-capture-click` triggering on mouseup during text selection
  - Fix LiveView `push_event`'s not clearing up in components
  - Fix textarea being patched by LV while focused

## 0.15.0 (2020-11-20)

### Enhancements
  - Add live uploads support for file progress, interactive file selection, and direct to cloud support
  - Implement `Phoenix.LiveViewTest.open_browser/2` that opens up a browser with the LiveView page

### Backwards incompatible changes
  - Remove `@inner_content` in components and introduce `render_block` for rendering component `@inner_block`
  - Remove `@live_module` in socket templates in favor of `@socket.view`

### Bug fixes
  - Make sure URLs are decoded after they are split
  - Do not recover forms without inputs
  - Fix race condition when components are removed and then immediately re-added before the client can notify their CIDs have been destroyed
  - Do not render LiveView if only events/replies have been added to the socket
  - Properly merge different components when sharing component subtrees on initial render
  - Allow variables inside do-blocks to be tainted
  - Fix `push_redirect` from mount hanging on the client and causing a fallback to full page reload when following a clicked `live_redirect` on the client

## 0.14.8 (2020-10-30)

### Bug fixes
  - Fix compatiblity with latest Plug

## 0.14.7 (2020-09-25)

### Bug fixes
  - Fix `redirect(socket, external: ...)` when returned from an event
  - Properly follow location hashes on live patch/redirect
  - Fix failure in `Phoenix.LiveViewTest` when phx-update has non-HTML nodes as children
  - Fix `phx_trigger_action` submitting the form before the DOM updates are complete

## 0.14.6 (2020-09-21)

### Bug fixes
  - Fix race condition on `phx-trigger-action` causing reconnects before server form submit

## 0.14.5 (2020-09-20)

### Enhancements

  - Optimize DOM prepend and append operations
  - Add `Phoenix.LiveView.send_update_after/3`

### Bug fixes
  - Fix scroll position when using back/forward with `live_redirect`'s
  - Handle recursive components when generating diffs
  - Support hard redirects on mount
  - Properly track nested components on deletion on `Phoenix.LiveViewTest`

## 0.14.4 (2020-07-30)

### Bug fixes
  - Fix hidden inputs throwing selection range error

## 0.14.3 (2020-07-24)

### Enhancements
  - Support `render_layout` with LiveEEx

### Bug fixes
  - Fix focused inputs being overwritten by latent patch
  - Fix LiveView error when `"_target"` input name contains array
  - Fix change tracking when passing a do-block to components

## 0.14.2 (2020-07-21)

### Bug fixes
  - Fix Map of assigns together with `@inner_content` causing `no function clause matching in Keyword.put/3` error
  - Fix `LiveViewTest` failing to patch children properly for append/prepend based phx-update's
  - Fix argument error when providing `:as` option to a `live` route
  - Fix page becoming unresponsive when the server crashes while handling a live patch
  - Fix empty diff causing pending data-ref based updates, such as classes and disable-with content to not be updated
  - Fix bug where throttling keydown events would eat key presses
  - Fix textarea's failing to be disabled on form submit
  - Fix text node DOM memory leak when using phx-update append/prepend

### Enhancements
  - Allow `:router` to be given to `render_component`
  - Display file on compile warning for `~L`
  - Log error on client when using a hook without a DOM ID
  - Optimize phx-update append/prepend based DOM updates

## 0.14.1 (2020-07-09)

### Bug fixes
  - Fix nested `live_render`'s failing to be torn down when removed from the DOM in certain cases
  - Fix LEEx issue for nested conditions failing to be re-evaluated

## 0.14.0 (2020-07-07)

### Bug fixes
  - Fix IE11 issue where `document.activeElement` creates a null reference
  - Fix setup and teardown of root views when explicitly calling `liveSocket.disconnect()` followed by `liveSocket.connect()`
  - Fix `error_tag` failing to be displayed for non-text based inputs such as selects and checkboxes as the phx-no-feedback class was always applied
  - Fix `phx-error` class being applied on `live_redirect`
  - Properly handle Elixir's special variables, such as `__MODULE__`
  - No longer set disconnected class during patch
  - Track flash keys to fix back-to-back flashes from being discarded
  - Properly handle empty component diffs in the client for cases where the component has already been removed on the server
  - Make sure components in nested live views do not conflict
  - Fix `phx-static` not being sent from the client for child views
  - Do not fail when trying to delete a view that was already deleted
  - Ensure `beforeDestroy` is called on hooks in children of a removed element

### Enhancements
  - Allow the whole component static subtree to be shared when the component already exists on the client
  - Add telemetry events to `mount`, `handle_params`, and `handle_event`
  - Add `push_event` for pushing events and data from the server to the client
  - Add client `handleEvent` hook method for receiving events pushed from the server
  - Add ability to receive a reply to a `pushEvent` from the server via `{:reply, map, socket}`
  - Use event listener for popstate to avoid conflicting with user-defined popstate handlers
  - Log error on client when rendering a component with no direct DOM children
  - Make `assigns.myself` a struct to catch mistakes
  - Log if component doesn't exist on `send_update`, raise if module is unavailable

## 0.13.3 (2020-06-04)

### Bug fixes
  - Fix duplicate debounced events from being triggered on blur with timed debounce
  - Fix client error when live_redirected'd route results in a redirect to a non-live route on the server
  - Fix DOM siblings being removed when a rootless component is updated
  - Fix debounced input failing to send last change when blurred via Tab, Meta, or other non-printable keys

### Enhancements
  - Add `dom` option to `LiveSocket` with `onBeforeElUpdated` callback for external client library support of broad DOM operations

## 0.13.2 (2020-05-27)

### Bug fixes
  - Fix a bug where swapping a root template with components would cause the LiveView to crash

## 0.13.1 (2020-05-26)

### Bug fixes
  - Fix forced page refresh when push_redirect from a live_redirect

### Enhancements
  - Optimize component diffs to avoid sending empty diffs
  - Optimize components to share static values
  - [LiveViewTest] Automatically synchronize before render events

## 0.13.0 (2020-05-21)

### Backwards incompatible changes
  - No longer send event metadata by default. Metadata is now opt-in and user defined at the `LiveSocket` level.
  To maintain backwards compatiblity with pre-0.13 behaviour, you can provide the following metadata option:

  ```javascript
  let liveSocket = new LiveSocket("/live", Socket, {
    params: {_csrf_token: csrfToken},
    metadata: {
      click: (e, el) => {
        return {
          altKey: e.altKey,
          shiftKey: e.shiftKey,
          ctrlKey: e.ctrlKey,
          metaKey: e.metaKey,
          x: e.x || e.clientX,
          y: e.y || e.clientY,
          pageX: e.pageX,
          pageY: e.pageY,
          screenX: e.screenX,
          screenY: e.screenY,
          offsetX: e.offsetX,
          offsetY: e.offsetY,
          detail: e.detail || 1,
        }
      },
      keydown: (e, el) => {
        return {
          altGraphKey: e.altGraphKey,
          altKey: e.altKey,
          code: e.code,
          ctrlKey: e.ctrlKey,
          key: e.key,
          keyIdentifier: e.keyIdentifier,
          keyLocation: e.keyLocation,
          location: e.location,
          metaKey: e.metaKey,
          repeat: e.repeat,
          shiftKey: e.shiftKey
        }
      }
    }
  })
  ```

### Bug fixes
  - Fix error caused by Chrome sending a keydown event on native UI autocomplete without a `key`
  - Fix server error when a live navigation request issues a redirect
  - Fix double window bindings when explicit calls to LiveSocket connect/disconnect/connect

### Enhancements
  - Add `Phoenix.LiveView.get_connect_info/1`
  - Add `Phoenix.LiveViewTest.put_connect_info/2` and `Phoenix.LiveViewTest.put_connect_params/2`
  - Add support for tracking static asset changes on the page across cold server deploys
  - Add support for passing a `@myself` target to a hook's `pushEventTo` target
  - Add configurable metadata for events with new `metadata` LiveSocket option
  - Add `"_mounts"` key in connect params which specifies the number of times a LiveView has mounted

## 0.12.1 (2020-04-19)

### Bug fixes
  - Fix component `innerHTML` being discarded when a sibling DOM element appears above it, in cases where the component lacks a DOM ID
  - Fix Firefox reconnecting briefly during hard redirects
  - Fix `phx-disable-with` and other pending attributes failing to be restored when an empty patch is returned by server
  - Ensure LiveView module is loaded before mount to prevent first application request logging errors if the very first request is to a connected LiveView

## 0.12.0 (2020-04-16)

This version of LiveView comes with an overhaul of the testing module, more closely integrating your LiveView template with your LiveView events. For example, in previous versions, you could write this test:

  ```elixir
  render_click(live_view, "increment_by", %{by: 1})
  ```

However, there is no guarantee that there is any element on the page with a `phx-click="increment"` attribute and `phx-value-by` set to 1. With LiveView 0.12.0, you can now write:

  ```elixir
  live_view
  |> element("#term .buttons a", "Increment")
  |> render_click()
  ```

The new implementation will check there is a button at `#term .buttons a`, with "Increment" as text, validate that it has a `phx-click` attribute and automatically submit to it with all relevant `phx-value` entries. This brings us closer to integration/acceptance test frameworks without any of the overhead and complexities of running a headless browser.

### Enhancements
  - Add `assert_patch/3` and `assert_patched/2` for asserting on patches
  - Add `follow_redirect/3` to automatically follow redirects from `render_*` events
  - Add `phx-trigger-action` form annotation to trigger an HTTP form submit on next DOM patch

### Bug fixes
  - Fix `phx-target` `@myself` targetting a sibling LiveView component with the same component ID
  - Fix `phx:page-loading-stop` firing before the DOM patch has been performed
  - Fix `phx-update="prepend"` failing to properly patch the DOM when the same ID is updated back to back
  - Fix redirects on mount failing to copy flash

### Backwards incompatible changes
  - `phx-error-for` has been removed in favor of `phx-feedback-for`. `phx-feedback-for` will set a `phx-no-feedback` class whenever feedback has to be hidden
  - `Phoenix.LiveViewTest.children/1` has been renamed to `Phoenix.LiveViewTest.live_children/1`
  - `Phoenix.LiveViewTest.find_child/2` has been renamed to `Phoenix.LiveViewTest.find_live_child/2`
  - `Phoenix.LiveViewTest.assert_redirect/3` no longer matches on the flash, instead it returns the flash
  - `Phoenix.LiveViewTest.assert_redirect/3` no longer matches on the patch redirects, use `assert_patch/3` instead
  - `Phoenix.LiveViewTest.assert_remove/3` has been removed. If the LiveView crashes, it will cause the test to crash too
  - Passing a path with DOM IDs to `render_*` test functions is deprecated. Furthermore, they now require a `phx-target="<%= @id %>"` on the given DOM ID:

    ```html
    <div id="component-id" phx-target="component-id">
      ...
    </div>
    ```

    ```elixir
    html = render_submit([view, "#component-id"], event, value)
    ```

    In any case, this API is deprecated and you should migrate to the new element based API.

## 0.11.1 (2020-04-08)

### Bug fixes
  - Fix readonly states failing to be undone after an empty diff
  - Fix dynamically added child failing to be joined by the client
  - Fix teardown bug causing stale client sessions to attempt a rejoin on reconnect
  - Fix orphaned prepend/append content across joins
  - Track `unless` in LiveEEx engine

### Backwards incompatible changes
  - `render_event`/`render_click` and friends now expect a DOM ID selector to be given when working with components. For example, instead of `render_click([live, "user-13"])`, you should write `render_click([live, "#user-13"])`, mirroring the `phx-target` API.
  - Accessing the socket assigns directly `@socket.assigns[...]` in a template will now raise the exception `Phoenix.LiveView.Socket.AssignsNotInSocket`. The socket assigns are available directly inside the template as LiveEEx `assigns`, such as `@foo` and `@bar`. Any assign access should be done using the assigns in the template where proper change tracking takes place.

### Enhancements
  - Trigger debounced events immediately on input blur
  - Support `defaults` option on `LiveSocket` constructor to configure default `phx-debounce` and `phx-throttle` values, allowing `<input ... phx-debounce>`
  - Add `detail` key to click event metadata for detecting double/triple clicks

## 0.11.0 (2020-04-06)

### Backwards incompatible changes
  - Remove `socket.assigns` during render to avoid change tracking bugs. If you were previously relying on passing `@socket` to functions then referencing socket assigns, pass the explicit assign instead to your functions from the template.
  - Removed `assets/css/live_view.css`. If you want to show a progress bar then in `app.css`, replace


    ```diff
    - @import "../../../../deps/phoenix_live_view/assets/css/live_view.css";
    + @import "../node_modules/nprogress/nprogress.css";
    ```

    and add `nprogress` to `assets/package.json`. Full details in the [Progress animation guide](https://hexdocs.pm/phoenix_live_view/0.11.0/installation.html#progress-animation)

### Bug fixes
  - Fix client issue with greater than two levels of LiveView nesting
  - Fix bug causing entire LiveView to be re-rendering with only a component changed
  - Fix issue where rejoins would not trigger `phx:page-loading-stop`

### Enhancements
  - Support deep change tracking so `@foo.bar` only executes and diffs when bar changes
  - Add `@myself` assign, to allow components to target themselves instead of relying on a DOM ID, for example: `phx-target="<%= @myself %>"`
  - Optimize various client rendering scenarios for faster DOM patching
  of components and append/prepended content
  - Add `enableProfiling()` and `disableProfiling()` to `LiveSocket` for client performance profiling to aid the development process
  - Allow LiveViews to be rendered inside LiveComponents
  - Add support for clearing flash inside components

## 0.10.0 (2020-03-18)

### Backwards incompatible changes
  - Rename socket assign `@live_view_module` to `@live_module`
  - Rename socket assign `@live_view_action` to `@live_action`
  - LiveView no longer uses the default app layout and `put_live_layout` is no longer supported. Instead, use `put_root_layout`. Note, however, that the layout given to `put_root_layout` must use `@inner_content` instead of `<%= render(@view_module, @view_template, assigns) %>` and that the root layout will also be used by regular views. Check the [Live Layouts](https://hexdocs.pm/phoenix_live_view/0.10.0/Phoenix.LiveView.html#module-live-layouts) section of the docs.

### Bug fixes
  - Fix loading states causing nested LiveViews to be removed during live navigation
  - Only trigger `phx-update="ignore"` hook if data attributes have changed
  - Fix LiveEEx fingerprint bug causing no diff to be sent in certain cases

### Enhancements
  - Support collocated templates where an `.html.leex` template of the same basename of the LiveView will be automatically used for `render/1`
  - Add `live_title_tag/2` helper for automatic prefix/suffix on `@page_title` updates

## 0.9.0 (2020-03-08)

### Bug fixes
  - Do not set ignored inputs and buttons as readonly
  - Only decode paths in URIs
  - Only destroy main descendents when replacing main
  - Fix sibling component patches when siblings at same root DOM tree
  - Do not pick the layout from `:use` on child LiveViews
  - Respect when the layout is set to `false` in the router and on mount
  - Fix sibling component patch when component siblings lack a container
  - Make flash optional (i.e. LiveView will still work if you don't `fetch_flash` before)

### Enhancements
  - Raise if `:flash` is given as an assign
  - Support user-defined metadata in router
  - Allow the router to be accessed as `socket.router`
  - Allow `MFArgs` as the `:session` option in the `live` router macro
  - Trigger page loading event when main LV errors
  - Automatially clear the flash on live navigation examples - only the newly assigned flash is persisted

## 0.8.1 (2020-02-27)

### Enhancements
  - Support `phx-disable-with` on live redirect and live patch links

### Bug Fixes
  - Fix focus issue on date and time inputs
  - Fix LiveViews failing to mount when page restored from back/forward cache following a `redirect` on the server
  - Fix IE coercing `undefined` to string when issuing pushState
  - Fix IE error when focused element is null
  - Fix client error when using components and live navigation where a dynamic template is rendered
  - Fix latent component diff causing error when component removed from DOM before patch arrives
  - Fix race condition where a component event received on the server for a component already removed by the server raised a match error

## 0.8.0 (2020-02-22)

### Backwards incompatible changes
  - Remove `Phoenix.LiveView.Flash` in favor of `:fetch_live_flash` imported by `Phoenix.LiveView.Router`
  - Live layout must now access the child contents with `@inner_content` instead of invoking the LiveView directly
  - Returning `:stop` tuples from LiveView `mount` or `handle_[params|call|cast|info|event]` is no longer supported. LiveViews are stopped when issuing a `redirect` or `push_redirect`

### Enhancements
  - Add `put_live_layout` plug to put the root layout used for live routes
  - Allow `redirect` and `push_redirect` from mount
  - Use acknowledgement tracking to avoid patching inputs until the server has processed the form event
  - Add css loading states to all phx bound elements with event specfic css classes
  - Dispatch `phx:page-loading-start` and `phx:page-loading-stop` on window for live navigation, initial page loads, and form submits, for user controlled page loading integration
  - Allow any phx bound element to specify `phx-page-loading` to dispatch loading events above when the event is pushed
  - Add client side latency simulator with new `enableLatencySim(milliseconds)` and `disableLatencySim()`
  - Add `enableDebug()` and `disableDebug()` to `LiveSocket` for ondemand browser debugging from the web console
  - Do not connect LiveSocket WebSocket or bind client events unless a LiveView is found on the page
  - Add `transport_pid/1` to return the websocket transport pid when the socket is connected

### Bug Fixes
  - Fix issue where a failed mount from a `live_redirect` would reload the current URL instead of the attempted new URL

## 0.7.1 (2020-02-13)

### Bug Fixes
  - Fix checkbox bug failing to send `phx-change` event to the server in certain cases
  - Fix checkbox bug failing to maintain checked state when a checkbox is programmatically updated by the server
  - Fix select bug in Firefox causing the highlighted index to jump when a patch is applied during hover state

## 0.7.0 (2020-02-12)

### Backwards incompatible changes
  - `live_redirect` was removed in favor of `push_patch` (for updating the URL and params of the current LiveView) and `push_redirect` (for updating the URL to another LiveView)
  - `live_link` was removed in favor of  `live_patch` (for updating the URL and params of the current LiveView) and `live_redirect` (for updating the URL to another LiveView)
  - `Phoenix.LiveViewTest.assert_redirect` no longer accepts an anonymous function in favor of executing the code
  prior to asserting the redirects, just like `assert_receive`.

### Enhancements
  - Support `@live_view_action` in LiveViews to simplify tracking of URL state
  - Recovery form input data automatically on disconnects or crash recovery
  - Add `phx-auto-recover` form binding for specialized recovery
  - Scroll to top of page while respecting anchor hash targets on `live_patch` and `live_redirect`
  - Add `phx-capture-click` to use event capturing to bind a click event as it propagates inwards from the target
  - Revamp flash support so it works between static views, live views, and components
  - Add `phx-key` binding to scope `phx-window-keydown` and `phx-window-keyup` events

### Bug Fixes
  - Send `phx-value-*` on key events
  - Trigger `updated` hook callbacks on `phx-update="ignore"` container when the container's attributes have changed
  - Fix nested `phx-update="append"` raising ArgumentError in LiveViewTest
  - Fix updates not being applied in rare cases where an leex template is wrapped in an if expression

## 0.6.0 (2020-01-22)

### Deprecations
  - LiveView `mount/2` has been deprecated in favor of `mount/3`. The params are now passed as the first argument to `mount/3`, followed by the session and socket.

### Backwards incompatible changes
  - The socket session now accepts only string keys

### Enhancements
  - Allow window beforeunload to be cancelled without losing websocket connection

### Bug Fixes
  - Fix handle_params not decoding URL path parameters properly
  - Fix LiveViewTest error when routing at root path
  - Fix URI encoded params failing to be decoded in `handle_params`
  - Fix component target failing to locate correct component when the target is on an input tag


## 0.5.2 (2020-01-17)

### Bug Fixes
  - Fix optimization bug causing some DOM nodes to be removed on updates

## 0.5.1 (2020-01-15)

### Bug Fixes
  - Fix phx-change bug causing phx-target to not be used

## 0.5.0 (2020-01-15)

LiveView now makes the connection session automatically available in LiveViews. However, to do so, you need to configure your endpoint accordingly, **otherwise LiveView will fail to connect**.

The steps are:

  1) Find `plug Plug.Session, ...` in your endpoint.ex and move the options `...` to a module attribute:

      ```elixir
      @session_options [
        ...
      ]
      ```

  2) Change the `plug Plug.Session` to use said attribute:

      ```elixir
      plug Plug.Session, @session_options
      ```

  3) Also pass the `@session_options` to your LiveView socket:

      ```elixir
      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [session: @session_options]]
      ```

  4) You should define the CSRF meta tag inside <head> in your layout, before `app.js` is included:

      ```html
      <%= csrf_meta_tag() %>
      <script type="text/javascript" src="<%= Routes.static_path(@conn, "/js/app.js") %>"></script>
      ```

  5) Then in your app.js:

      ```javascript
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});
      ```

Also note that **the session from now on will have string keys**. LiveView will warn if atom keys are used.

### Enhancements
  - Respect new tab behavior in `live_link`
  - Add `beforeUpdate` and `beforeDestroy` JS hooks
  - Make all assigns defined on the socket mount available on the layout on first render
  - Provide support for live layouts with new `:layout` option
  - Detect duplicate IDs on the front-end when DEBUG mode is enabled
  - Automatically forward the session to LiveView
  - Support "live_socket_id" session key for identifying (and disconnecting) LiveView sockets
  - Add support for `hibernate_after` on LiveView processes
  - Support redirecting to full URLs on `live_redirect` and `redirect`
  - Add `offsetX` and `offsetY` to click event metadata
  - Allow `live_link` and `live_redirect` to exist anywhere in the page and it will always target the main LiveView (the one defined at the router)

### Backwards incompatible changes
  - `phx-target="window"` has been removed in favor of `phx-window-keydown`, `phx-window-focus`, etc, and the `phx-target` binding has been repurposed for targetting LiveView and LiveComponent events from the client
  - `Phoenix.LiveView` no longer defined `live_render` and `live_link`. These functions have been moved to `Phoenix.LiveView.Helpers` which can now be fully imported in your views. In other words, replace `import Phoenix.LiveView, only: [live_render: ..., live_link: ...]` by `import Phoenix.LiveView.Helpers`

## 0.4.1 (2019-11-07)

### Bug Fixes
  - Fix bug causing blurred inputs

## 0.4.0 (2019-11-07)

### Enhancements
  - Add `Phoenix.LiveComponent` to compartmentalize state, markup, and events in LiveView
  - Handle outdated clients by refreshing the page with jitter when a valid, but outdated session is detected
  - Only dispatch live link clicks to router LiveView
  - Refresh the page for graceful error recovery on failed mount when the socket is in a connected state

### Bug Fixes
  - Fix `phx-hook` destroyed callback failing to be called in certain cases
  - Fix back/forward bug causing LiveView to fail to remount

## 0.3.1 (2019-09-23)

### Backwards incompatible changes
  - `live_isolated` in tests no longer requires a router and a pipeline (it now expects only 3 arguments)
  - Raise if `handle_params` is used on a non-router LiveView

### Bug Fixes
  - [LiveViewTest] Fix function clause errors caused by HTML comments

## 0.3.0 (2019-09-19)

### Enhancements
  - Add `phx-debounce` and `phx-throttle` bindings to rate limit events

### Backwards incompatible changes
  - IE11 support now requires two additional polyfills, `mdn-polyfills/CustomEvent` and `mdn-polyfills/String.prototype.startsWith`

### Bug Fixes
  - Fix IE11 support caused by unsupported `getAttributeNames` lookup
  - Fix Floki dependency compilation warnings

## 0.2.1 (2019-09-17)

### Bug Fixes
  - [LiveView.Router] Fix module concat failing to build correct layout module when using custom namespace
  - [LiveViewTest] Fix `phx-update` append/prepend containers not building proper DOM content
  - [LiveViewTest] Fix `phx-update` append/prepend containers not updating existing child containers with matching IDs

## 0.2.0 (2019-09-12)

### Enhancements
  - [LiveView] Add new `:container` option to `use Phoenix.LiveView`
  - [LiveViewTest] Add `live_isolated` test helper for testing LiveViews which are not routable

### Backwards incompatible changes
  - Replace `configure_temporary_assigns/2` with 3-tuple mount return, supporting a `:temporary_assigns` key
  - Do not allow `redirect`/`live_redirect` on mount nor in child live views
  - All `phx-update` containers now require a unique ID
  - `LiveSocket` JavaScript constructor now requires explicit dependency injection of Phoenix Socket constructor. For example:

```javascript
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"

let liveSocket = new LiveSocket("/live", Socket, {...})
```

### Bug Fixes
  - Fix `phx-update=append/prepend` failing to join new nested live views or wire up new phx-hooks
  - Fix number input handling causing some browsers to reset form fields on invalid inputs
  - Fix multi-select decoding causing server error
  - Fix multi-select change tracking failing to submit an event when a value is deselected
  - Fix live redirect loop triggered under certain scenarios
  - Fix params failing to update on re-mounts after live_redirect
  - Fix blur event metadata being sent with type of `"focus"`

## 0.1.2

### Backwards incompatible changes
  - `phx-value` has no effect, use `phx-value-*` instead
  - The `:path_params` key in session has no effect (use `handle_params` in `LiveView` instead)

## 0.1.1 (2019-08-27)

### Enhancements
  - Use optimized `insertAdjacentHTML` for faster append/prepend and proper css animation handling
  - Allow for replacing previously appended/prepended elements by replacing duplicate IDs during append/prepend instead of adding new DOM nodes

### Bug Fixes
  - Fix duplicate append/prepend updates when parent content is updated
  - Fix JS hooks not being applied for appending and prepended content

## 0.1.0 (2019-08-25)

### Enhancements
  - The LiveView `handle_in/3` callback now receives a map of metadata about the client event
  - For `phx-change` events, `handle_in/3` now receives a `"_target"` param representing the keyspace of the form input name which triggered the change
  - Multiple values may be provided for any phx binding by using the `phx-value-` prefix, such as `phx-value-myval1`, `phx-value-myval2`, etc
  - Add control over the DOM patching via `phx-update`, which can be set to `"replace"`, `"append"`, `"prepend"` or `"ignore"`

### Backwards incompatible changes
  - `phx-ignore` was renamed to `phx-update="ignore"`

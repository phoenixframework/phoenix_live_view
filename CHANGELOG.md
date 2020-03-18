## 0.10.0 (2020-03-18)

### Backwards incompatible changes
  - Rename socket assign `@live_view_module` to `@live_module`
  - Rename socket assign `@live_view_action` to `@live_action`
  - LiveView no longer uses the default app layout and `put_live_layout` is no longer supported. Instead, use `put_root_layout`. Note, however, that the layout given to `put_root_layout` must use `@inner_content` instead of `<%= render(@view_module, @view_template, assigns) %>` and that the root layout will also be used by regular views. Therefore, we recommend setting `put_root_layout` in a pipeline that is exclusive to LiveViews

### Bug fixes
  - Fix loading states causing nested LiveViews to be removed during live navigation
  - Only trigger `phx-update=ignore` hook if data attributes have changed
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
  - Fix checkbox bug failing to send phx-change event to the server in certain cases
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

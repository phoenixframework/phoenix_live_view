## 0.3.1 (2019-09-23)

### Backwards incompatible changes
  - `live_isolated` in tests no longer requires a router and a pipeline (it now expects only 3 arguments)
  - Raise if `handle_params` is used on a non-router LiveView

### Bug Fixes
  - [LiveViewTest] Fix function clause errors caused by HTML comments
  - Fix `live_redirect` failing to detect back button URL changes

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
  - [LiveViewTest] Fix phx-update append/prepend containers not building proper DOM content
  - [LiveViewTest] Fix phx-update append/prepend containers not updating existing child containers with matching IDs

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
        ````

### Bug Fixes
  - Fix phx-update=append/prepend failing to join new nested live views or wire up new phx-hooks
  - Fix number input handling causing some browsers to reset form fields on invalid inputs
  - Fix multi-select decoding causing server error
  - Fix multi-select change tracking failing to submit an event when a value is deselected
  - Fix live redirect loop triggered under certain scenarios
  - Fix params failing to update on re-mounts after live_redirect
  - Fix blur event metadata being sent with type of "focus"

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
  - Add control over the DOM patching via `phx-update`, which can be set to "replace", "append", "prepend" or "ignore"

### Backwards incompatible changes
  - `phx-ignore` was renamed to `phx-update="ignore"`

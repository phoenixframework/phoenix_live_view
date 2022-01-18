# Changelog

## 0.17.6 (2022-01-18)

### Enhancements
  - Add `JS.set_attribute` and `JS.remove_attribute`
  - Add `sticky: true` option to `live_render` to maintain a nested child on across live redirects
  - Dispatch `phx:show-start`, `phx:show-end`, `phx:hide-start` and `phx:hide-end` on `JS.show|hide|toggle`
  - Add `get_connect_info/2` that also works on disconnected render
  - Add `LiveSocket` constructor options for configuration failsafe behavior via new `maxReloads`, `reloadJitterMin`, `reloadJitterMax`, `failsafeJitter` options

### Bug fixes
  - Show form errors after submit even when no changes occur on server
  - Fix `phx-disable-with` failing to disable elements outside of forms
  - Fix phx ref tracking leaving elements in awaiting state when targeting an external LiveView
  - Fix diff on response failing to await for active transitions in certain cases
  - Fix `phx-click-away` not respecting `phx-target`
  - Fix "disconnect" broadcast failing to failsafe refresh the page
  - Fix `JS.push` with `:target` failing to send to correct component in certain cases

### Deprecations
   - Deprecate `Phoenix.LiveView.get_connect_info/1` in favor of `get_connect_info/2`
   - Deprecate `Phoenix.LiveViewTest.put_connect_info/2` in favor of calling the relevant functions in `Plug.Conn`

## 0.17.5 (2021-11-02)

### Bug fixes
  - Do not trigger `phx-click-away` if element is not visible
  - Fix `phx-remove` failing to tear down nested live children

## 0.17.4 (2021-11-01)

### Bug fixes
  - Fix variable scoping issues causing various content block or duplication rendering bugs

## 0.17.3 (2021-10-28)

### Enhancements
  - Support 3-tuple for JS class transitions to support staged animations where a transition class is applied with a starting and ending class
  - Allow JS commands to be executed on DOM nodes outside of the LiveView container

### Optimization
  - Avoid duplicate statics inside comprehension. In previous versions, comprehensions were able to avoid duplication only in the content of their root. Now we recursively traverse all comprehension nodes and send the static only once for the whole comprehension. This should massively reduce the cost of sending comprehensions over the wire

### Bug fixes
  - Fix HTML engine bug causing expressions to be duplicated or not rendered correctly
  - Fix HTML engine bug causing slots to not be re-rendered when they should have
  - Fix form recovery being sent to wrong target

## 0.17.2 (2021-10-22)

### Bug fixes
  - Fix HTML engine bug causing attribute expressions to be incorrectly evaluated in certain cases
  - Fix show/hide/toggle custom display not being restored
  - Fix default `to` target for `JS.show|hide|dispatch`
  - Fix form input targeting

## 0.17.1 (2021-10-21)

### Bug fixes
  - Fix SVG element support for `phx` binding interactions

## 0.17.0 (2021-10-21)

### Breaking Changes

#### `on_mount` changes

The hook API introduced in LiveView 0.16 has been improved based on feedback.
LiveView 0.17 removes the custom module-function callbacks for the
`Phoenix.LiveView.on_mount/1` macro and the `:on_mount` option for
`Phoenix.LiveView.Router.live_session/3` in favor of supporting a custom
argument. For clarity, the module function to be invoked during the mount
lifecycle stage will always be named `on_mount/4`.

For example, if you had invoked `on_mount/1` like so:

```elixir
on_mount MyAppWeb.MyHook
on_mount {MyAppWeb.MyHook, :assign_current_user}
```

and defined your callbacks as:

```elixir
# my_hook.ex

def mount(_params, _session, _socket) do
end

def assign_current_user(_params, _session, _socket) do
end
```

Change the callback to:

```elixir
# my_hook.ex

def on_mount(:default, _params, _session, _socket) do
end

def on_mount(:assign_current_user, _params, _session, _socket) do
end
```

When given only a module name, the first argument to `on_mount/4` will be the
atom `:default`.

#### LEEx templates in stateful LiveComponents

Stateful LiveComponents (where an `:id` is given) must now return HEEx templates
(`~H` sigil or `.heex` extension). LEEx templates (`~L` sigil or `.leex` extension)
are no longer supported. This addresses bugs and allows stateful components
to be rendered more efficiently client-side.

#### `phx-disconnected` class has been replaced with `phx-loading`

Due to a bug in the newly released Safari 15, the previously used `.phx-disconnected` class has been replaced by a new `.phx-loading` class. The reason for the change is `phx.new` included a `.phx-disconnected` rule in the generated `app.css` which triggers the Safari bug. Renaming the class avoids applying the erroneous rule for existing applications. Folks can upgrade by simply renaming their `.phx-disconnected` rules to `.phx-loading`.

#### `phx-capture-click` has been deprecated in favor of `phx-click-away`

The new `phx-click-away` binding replaces `phx-capture-click` and is much more versatile because it can detect "click focus" being lost on containers.

#### Removal of previously deprecated functionality

Some functionality that was previously deprecated has been removed:

  - Implicit assigns in `live_component` do-blocks is no longer supported
  - Passing a `@socket` to `live_component` will now raise if possible

### Enhancements
  - Allow slots in function components: they are marked as `<:slot_name>` and can be rendered with `<%= render_slot @slot_name %>`
  - Add `JS` command for executing JavaScript utility operations on the client with an extended push API
  - Optimize string attributes:
    - If the attribute is a string interpolation, such as `<div class={"foo bar #{@baz}"}>`, only the interpolation part is marked as dynamic
    - If the attribute can be empty, such as "class" and "style", keep the attribute name as static
  - Add a function component for rendering `Phoenix.LiveComponent`. Instead of `<%= live_component FormComponent, id: "form" %>`, you must now do: `<.live_component module={FormComponent} id="form" />`

### Bug fixes
  - Fix LiveViews with form recovery failing to properly mount following a reconnect when preceded by a live redirect
  - Fix stale session causing full redirect fallback when issuing a `push_redirect` from mount
  - Add workaround for Safari bug causing `<img>` tags with srcset and video with autoplay to fail to render
  - Support EEx interpolation inside HTML comments in HEEx templates
  - Support HTML tags inside script tags (as in regular HTML)
  - Raise if using quotes in attribute names
  - Include the filename in error messages when it is not possible to parse interpolated attributes
  - Make sure the test client always sends the full URL on `live_patch`/`live_redirect`. This mirrors the behaviour of the JavaScript client
  - Do not reload flash from session on `live_redirect`s
  - Fix select drop-down flashes in Chrome when the DOM is patched during focus

### Deprecations
  - `<%= live_component MyModule, id: @user.id, user: @user %>` is deprecated in favor of `<.live_component module={MyModule} id={@user.id} user={@user} />`. Notice the new API requires using HEEx templates. This change allows us to further improve LiveComponent and bring new features such as slots to them.
  - `render_block/2` in deprecated in favor of `render_slot/2`

## 0.16.4 (2021-09-22)

### Enhancements
  - Improve HEEx error messages
  - Relax HTML tag validation to support mixed case tags
  - Support self closing HTML tags
  - Remove requirement for `handle_params` to be defined for lifecycle hooks

### Bug fixes
  - Fix pushes failing to include channel `join_ref` on messages

## 0.16.3 (2021-09-03)

### Bug fixes
  - Fix `on_mount` hooks calling view mount before redirecting when the hook issues a halt redirect.

## 0.16.2 (2021-09-03)

### Enhancements
  - Improve error messages on tokenization
  - Improve error message if `@inner_block` is missing

### Bug fixes
  - Fix `phx-change` form recovery event being sent to wrong component on reconnect when component order changes

## 0.16.1 (2021-08-26)

### Enhancements
  - Relax `phoenix_html` dependency requirement
  - Allow testing functional components by passing a function reference
    to `Phoenix.LiveViewTest.render_component/3`

### Bug fixes
  - Do not generate CSRF tokens for non-POST forms
  - Do not add compile-time dependencies on `on_mount` declarations

## 0.16.0 (2021-08-10)

## # Security Considerations Upgrading from 0.15

LiveView v0.16 optimizes live redirects by supporting navigation purely
over the existing WebSocket connection. This is accomplished by the new
`live_session/3` feature of `Phoenix.LiveView.Router`. The
[security guide](/guides/server/security-model.md) has always stressed
the following:

> ... As we have seen, LiveView begins its life-cycle as a regular HTTP
> request. Then a stateful connection is established. Both the HTTP
> request and the stateful connection receives the client data via
> parameters and session. This means that any session validation must
> happen both in the HTTP request (plug pipeline) and the stateful
> connection (LiveView mount) ...

These guidelines continue to be valid, but it is now essential that the
stateful connection enforces authentication and session validation within
the LiveView mount lifecycle because **a `live_redirect` from the client
will not go through the plug pipeline** as a hard-refresh or initial HTTP
render would. This means authentication, authorization, etc that may be
done in the `Plug.Conn` pipeline must also be performed within the
LiveView mount lifecycle.

Live sessions allow you to support a shared security model by allowing
`live_redirect`s to only be issued between routes defined under the same
live session name. If a client attempts to live redirect to a different
live session, it will be refused and a graceful client-side redirect will
trigger a regular HTTP request to the attempted URL.

See the `Phoenix.LiveView.Router.live_session/3` docs for more information
and example usage.

### New HTML Engine

LiveView v0.16 introduces HEEx (HTML + EEx) templates and the concept of function
components via `Phoenix.Component`. The new HEEx templates validate the markup in
the template while also providing smarter change tracking as well as syntax
conveniences to make it easier to build composable components.

A function component is any function that receives a map of assigns and returns
a `~H` template:

```elixir
defmodule MyComponent do
  use Phoenix.Component

  def btn(assigns) do
    ~H"""
    <button class="btn"><%= @text %></button>
    """
  end
end
```

This component can now be used as in your HEEx templates as:

    <MyComponent.btn text="Save">

The introduction of HEEx and function components brings a series of deprecation
warnings, some introduced in this release and others which will be added in the
future. Note HEEx templates require Elixir v1.12+.

### Upgrading and deprecations

The main deprecation in this release is that the `~L` sigil and the `.leex` extension
are now soft-deprecated. The docs have been updated to discourage them and using them
will emit warnings in future releases. We recommend using the `~H` sigil and the `.heex`
extension for all future templates in your application. You should also plan to migrate
the old templates accordingly using the recommendations below.

Migrating from `LEEx` to `HEEx` is relatively straightforward. There are two main differences.
First of all, HEEx does not allow interpolation inside tags. So instead of:

```elixir
<div id="<%= @id %>">
  ...
</div>
```

One should use the HEEx syntax:

```elixir
<div id={@id}>
  ...
</div>
```

The other difference is in regards to `form_for`. Some templates may do the following:

```elixir
~L"""
<%= f = form_for @changeset, "#" %>
  <%= input f, :foo %>
</form>
"""
```

However, when converted to `~H`, it is not valid HTML: there is a `</form>` tag but
its opening is hidden inside the Elixir code. On LiveView v0.16, there is a function
component named `form`:

```elixir
~H"""
<.form let={f} for={@changeset}>
  <%= input f, :foo %>
</.form>
"""
```

We understand migrating all templates from `~L` to `~H` can be a daunting task.
Therefore we plan to support `~L` in LiveViews for a long time. However, we can't
do the same for stateful LiveComponents, as some important client-side features and
optimizations will depend on the `~H` sigil. Therefore **our recommendation is to
replace `~L` by `~H` first in live components**, particularly stateful live components.

Furthermore, stateless `live_component` (i.e. live components without an `:id`)
will be deprecated in favor of the new function components. Our plan is to support
them for a reasonable period of time, but you should avoid creating new ones in
your application.

### Breaking Changes

LiveView 0.16 removes the `:layout` and `:container` options from
`Phoenix.LiveView.Routing.live/4` in favor of the `:root_layout`
and `:container` options on `Phoenix.Router.live_session/3`.

For instance, if you have the following in LiveView 0.15 and prior:

```elixir
live "/path", MyAppWeb.PageLive, layout: {MyAppWeb.LayoutView, "custom_layout.html"}
```

Change it to:

```elixir
live_session :session_name, root_layout: {MyAppWeb.LayoutView, "custom_layout.html"} do
  live "/path", MyAppWeb.PageLive
end
```

On the client, the `phoenix_live_view` package no longer provides a default export for `LiveSocket`.

If you have the following in your JavaScript entrypoint (typically located at `assets/js/app.js`):

```js
import LiveSocket from "phoenix_live_view"
```

Change it to:

```js
import { LiveSocket } from "phoenix_live_view"
```

Additionally on the client, the root LiveView element no longer exposes the
LiveView module name, therefore the `phx-view` attribute is never set.
Similarly, the `viewName` property of client hooks has been removed.

Codebases calling a custom function `component/3` should rename it or specify its module to avoid a conflict,
as LiveView introduces a macro with that name and it is special cased by the underlying engine.

### Enhancements
  - Introduce HEEx templates
  - Introduce `Phoenix.Component`
  - Introduce `Phoenix.Router.live_session/3` for optimized live redirects
  - Introduce `on_mount` and `attach_hook` hooks which provide a mechanism to tap into key stages of the LiveView lifecycle
  - Add upload methods to client-side hooks
  - [Helpers] Optimize `live_img_preview` rendering
  - [Helpers] Introduce `form` function component which wraps `Phoenix.HTML.form_for`
  - [LiveViewTest] Add `with_target` for scoping components directly
  - [LiveViewTest] Add `refute_redirected`
  - [LiveViewTest] Support multiple `phx-target` values to mirror JS client
  - [LiveViewTest] Add `follow_trigger_action`
  - [JavaScript Client] Add `sessionStorage` option `LiveSocket` constructor to support client storage overrides
  - [JavaScript Client] Do not failsafe reload the page in the background when a tab is unable to connect if the page is not visible


### Bug fixes
  - Make sure components are loaded on `render_component` to ensure all relevant callbacks are invoked
  - Fix `Phoenix.LiveViewTest.page_title` returning `nil` in some cases
  - Fix buttons being re-enabled when explicitly set to disabled on server
  - Fix live patch failing to update URL when live patch link is patched again via `handle_params` within the same callback lifecycle
  - Fix `phx-no-feedback` class not applied when page is live-patched
  - Fix `DOMException, querySelector, not a valid selector` when performing DOM lookups on non-standard IDs
  - Fix select dropdown flashing close/opened when assigns are updated on Chrome/macOS
  - Fix error with multiple `live_file_input` in one form
  - Fix race condition in `showError` causing null `querySelector`
  - Fix statics not resolving correctly across recursive diffs
  - Fix no function clause matching in `Phoenix.LiveView.Diff.many_to_iodata`
  - Fix upload input not being cleared after files are uploaded via a component
  - Fix channel crash when uploading during reconnect
  - Fix duplicate progress events being sent for large uploads

### Deprecations
  - Implicit assigns when passing a `do-end` block to `live_component` is deprecated
  - The `~L` sigil and the `.leex` extension are now soft-deprecated in favor of `~H` and `.heex`
  - Stateless live components (a `live_component` call without an `:id`) are deprecated in favor of the new function component feature

## 0.15.7 (2021-05-24)

### Bug fixes
  - Fix broken webpack build throwing missing morphdom dependency

## 0.15.6 (2021-05-24)

### Bug fixes
  - Fix live patch failing to update URL when live patch link is patched again from `handle_params`
  - Fix regression in `LiveViewTest.render_upload/3` when using channel uploads and progress callback
  - Fix component uploads not being cleaned up on remove
  - Fix `KeyError` on LiveView reconnect when an active upload was previously in progress

### Enhancements
  - Support function components via `component/3`
  - Optimize progress events to send less messages for larger file sizes
  - Allow session and local storage client overrides

### Deprecations
  - Deprecate `@socket/socket` argument on `live_component/3` call

## 0.15.5 (2021-04-20)

### Enhancements
  - Add `upload_errors/1` for returning top-level upload errors

### Bug fixes
  - Fix `consume_uploaded_entry/3` with external uploads causing inconsistent entries state
  - Fix `push_event` losing events when a single diff produces multiple events from different components
  - Fix deep merging of component tree sharing

## 0.15.4 (2021-01-26)

### Bug fixes
  - Fix nested `live_render`'s causing remound of child LiveView even when ID does not change
  - Do not attempt push hook events unless connected
  - Fix preflighted refs causing `auto_upload: true` to fail to submit form
  - Replace single upload entry when `max_entries` is 1 instead of accumulating multiple file selections
  - Fix `static_path` in `open_browser` failing to load stylesheets

## 0.15.3 (2021-01-02)

### Bug fixes
  - Fix `push_redirect` back causing timeout on the client

## 0.15.2 (2021-01-01)

### Backwards incompatible changes
  - Remove `beforeDestroy` from `phx-hook` callbacks

### Bug fixes
  - Fix form recovery failing to send input on first connection failure
  - Fix hooks not getting remounted after LiveView reconnect
  - Fix hooks `reconnected` callback being fired with no prior disconnect

## 0.15.1 (2020-12-20)

### Enhancements
  - Ensure all click events bubble for mobile Safari
  - Run `consume_uploaded_entries` in LiveView caller process

### Bug fixes
  - Fix hooks not getting remounted after LiveView recovery
  - Fix bug causing reload with jitter on timeout from previously closed channel
  - Fix component child nodes being lost when component patch goes from single root node to multiple child siblings
  - Fix `phx-capture-click` triggering on mouseup during text selection
  - Fix LiveView `push_event`'s not clearing up in components
  - Fix `<textarea>` being patched by LiveView while focused

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
  - Fix compatibility with latest Plug

## 0.14.7 (2020-09-25)

### Bug fixes
  - Fix `redirect(socket, external: ...)` when returned from an event
  - Properly follow location hashes on live patch/redirect
  - Fix failure in `Phoenix.LiveViewTest` when `phx-update` has non-HTML nodes as children
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
  - Fix empty diff causing pending data-ref based updates, such as classes and `phx-disable-with` content to not be updated
  - Fix bug where throttling keydown events would eat key presses
  - Fix `<textarea>`'s failing to be disabled on form submit
  - Fix text node DOM memory leak when using `phx-update` append/prepend

### Enhancements
  - Allow `:router` to be given to `render_component`
  - Display file on compile warning for `~L`
  - Log error on client when using a hook without a DOM ID
  - Optimize `phx-update` append/prepend based DOM updates

## 0.14.1 (2020-07-09)

### Bug fixes
  - Fix nested `live_render`'s failing to be torn down when removed from the DOM in certain cases
  - Fix LEEx issue for nested conditions failing to be re-evaluated

## 0.14.0 (2020-07-07)

### Bug fixes
  - Fix IE11 issue where `document.activeElement` creates a null reference
  - Fix setup and teardown of root views when explicitly calling `liveSocket.disconnect()` followed by `liveSocket.connect()`
  - Fix `error_tag` failing to be displayed for non-text based inputs such as selects and checkboxes as the `phx-no-feedback` class was always applied
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
  - Fix client error when `live_redirect`ed route results in a redirect to a non-live route on the server
  - Fix DOM siblings being removed when a rootless component is updated
  - Fix debounced input failing to send last change when blurred via Tab, Meta, or other non-printable keys

### Enhancements
  - Add `dom` option to `LiveSocket` with `onBeforeElUpdated` callback for external client library support of broad DOM operations

## 0.13.2 (2020-05-27)

### Bug fixes
  - Fix a bug where swapping a root template with components would cause the LiveView to crash

## 0.13.1 (2020-05-26)

### Bug fixes
  - Fix forced page refresh when `push_redirect` from a `live_redirect`

### Enhancements
  - Optimize component diffs to avoid sending empty diffs
  - Optimize components to share static values
  - [LiveViewTest] Automatically synchronize before render events

## 0.13.0 (2020-05-21)

### Backwards incompatible changes
  - No longer send event metadata by default. Metadata is now opt-in and user defined at the `LiveSocket` level.
  To maintain backwards compatibility with pre-0.13 behaviour, you can provide the following metadata option:

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
  - Fix `phx-target` `@myself` targeting a sibling LiveView component with the same component ID
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
  - Automatically clear the flash on live navigation examples - only the newly assigned flash is persisted

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
  - Add css loading states to all phx bound elements with event specific css classes
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
  - `phx-target="window"` has been removed in favor of `phx-window-keydown`, `phx-window-focus`, etc, and the `phx-target` binding has been repurposed for targeting LiveView and LiveComponent events from the client
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

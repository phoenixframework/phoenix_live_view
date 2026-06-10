# Changelog for v1.2

## Colocated CSS

LiveView v1.2 introduces colocated CSS to allow writing CSS rules in the same file as your regular component code.

To use colocated CSS, you need to implement the `Phoenix.LiveView.ColocatedCSS` behaviour. See the module documentation for more details.
It also includes instructions for configuring `:tailwind` to bundle colocated CSS.

Then, you can define it similar to how you would define a colocated hook or `Phoenix.LiveView.ColocatedJS`:

```elixir
def table(assigns) do
  ~H"""
  <style :type={MyAppWeb.ColocatedCSS}>
    thead color: {
      ...;
    }
    tbody, tr:hover {
      ...
    }
  </style>
  <table>...</table>
  """
end
```

## Formatting script and style tags

The `Phoenix.LiveView.HTMLFormatter.TagFormatter` behaviour allows you to format
`<script>` and `<style>` tags with third party tooling when running `mix format`,
especially useful if your project uses colocated assets.

The module documentation contains an example using [prettier](https://prettier.io/), which we also
use [in the LiveView repository itself](https://github.com/phoenixframework/phoenix_live_view/blob/main/lib/prettier.ex).

## Encoding JS commands to JSON

`Phoenix.LiveView.JS` structs can now be encoded to JSON for usage in `push_event`. So now you can do

```elixir
push_event(socket, "highlight", %{toggle: JS.toggle_class(...)})
```

```javascript
// some hook
this.handleEvent("highlight", ({ toggle }) => {
  this.js().execJS(this.el, toggle);
});
```

while in the past you'd have to render the command in an element attribute and
then refer back to it in your hook.

LiveView implements `JSON.Encoder` and `Jason.Encoder` automatically. If you use a different
library, you can invoke `JS.to_encodable/1` manually.

## Opting out of debug annotations

You can now opt out of HEEx debug annotations for specific modules by setting

```elixir
@debug_heex_annotations false
@debug_attributes false
```

as module attributes in the module that defines your HEEx template. The module
attributes override the application configuration:

```elixir
config :phoenix_live_view,
  debug_heex_annotations: true
  debug_attributes: true
```

This is useful if you render some templates for different purposes like email
where the comments and attributes LiveView adds for debugging in development are
a problem.

Here's an example that shows the debug annotations:

```html
<!-- @caller lib/demo_web/live/posts_live/index.ex:19 (demo) -->
<!-- <DemoWeb.CoreComponents.table> lib/demo_web/components/core_components.ex:362 (demo) -->
<table data-phx-loc="363" class="table table-zebra">
  <thead data-phx-loc="364">
    <tr data-phx-loc="365">
      <th data-phx-loc="366">Title</th>
      <th data-phx-loc="367">
        <span data-phx-loc="368" class="sr-only">Actions</span>
      </th>
    </tr>
  </thead>
  ...
```

The comments can be disabled with `debug_heex_annotations` and the `data-phx-loc` attributes with `debug_attributes`.

## Granular configuration for test warnings

LiveView includes some built in checks that run on the DOM when testing. For example,
tests will raise an exception if a duplicate ID is detected. We added a new check for forms
with `phx-change` but missing `id` attribute, because without an `id` [form recovery](https://phoenix-live-view.hexdocs.pm/form-bindings.html#recovery-following-crashes-or-disconnects)
does not work. Since the severity of that check is different compared to a duplicate ID,
LiveView now allows you to configure what should happen for each check:

```elixir
config :phoenix_live_view, :test_warnings,
  duplicate_id: :warn, # one of :warn, :raise, :ignore
  ...
```

By default, a form without an ID will now emit a warning. You can opt out of this check per form
by setting `phx-ignore-missing-id` or disable it globally with the `:missing_form_id` warning option.

See the module documentation or `Phoenix.LiveViewTest` for more information.

## v1.2.0 (2026-06-10) 🚀

### Enhancements

* Support events pushed when connected mount redirects ([#4269](https://github.com/phoenixframework/phoenix_live_view/issues/4269))

### Bug fixes

* Ensure for comprehensions in HEEx use deterministic variables
* Ensure `connect_params` are kept when following redirects in LiveViewTest ([#4005](https://github.com/phoenixframework/phoenix_live_view/issues/4005))
* Ensure exceptions during LiveComponent renders are emitted as `:telemetry` event ([#4258](https://github.com/phoenixframework/phoenix_live_view/issues/4258))
* Fix whitespace handling of EEx nodes in HEEx compiler ([#4277](https://github.com/phoenixframework/phoenix_live_view/pull/4277))

## v1.2.0-rc.3 (2026-05-29)

### Enhancements

* Add [official documentation for the JavaScript client](https://phoenix-live-view.hexdocs.pm/1.2.0-rc.3/js/)
* Validate URL scheme in `push_patch` / `push_navigate`, `JS.patch` / `JS.navigate`, and clientside `js().patch` / `js().navigate` ([#4250](https://github.com/phoenixframework/phoenix_live_view/pull/4250))

### Bug fixes

* Fix nested assign change tracking ([#4225](https://github.com/phoenixframework/phoenix_live_view/pull/4225))
* Ensure `Phoenix.LiveViewTest.live_redirect/2` properly passes the URI as a string in `handle_params` ([#4247](https://github.com/phoenixframework/phoenix_live_view/pull/4247))

## v1.2.0-rc.2 (2026-05-05)

### Bug fixes

* Ensure internal phx-viewport hook does not crash on update if no scroll container is used ([#4214](https://github.com/phoenixframework/phoenix_live_view/issues/4214))

## v1.2.0-rc.1 (2026-05-04)

### Enhancements

* Align `Phoenix.Component` global attributes list with [reference list from MDN](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes) ([#4207](https://github.com/phoenixframework/phoenix_live_view/pull/4207)). If you relied on one of the removed attributes, use the `include` option instead. For example:
  ```elixir
  attr :rest, :global, include: ~w(width height)
  ```
* Allow setting `id` attributes clientside for accessibility with `this.js().setAttribute()` ([#4146](https://github.com/phoenixframework/phoenix_live_view/pull/4146))
* Export `getFileURLForUpload` helper ([#4206](https://github.com/phoenixframework/phoenix_live_view/pull/4206))
* Use `moveBefore` if available when reordering stream items ([#4212](https://github.com/phoenixframework/phoenix_live_view/issues/4212))

### Bug fixes

* Handle locks on skipped nodes ([#4209](https://github.com/phoenixframework/phoenix_live_view/issues/4209))

## v1.2.0-rc.0 (2026-04-23)

### Enhancements

* Add `Phoenix.LiveView.ColocatedCSS`
* Deprecate the `:colocated_js` configuration in favor of `:colocated_assets`
* Add `phx-no-unused-field` to prevent sending `_unused` parameters to the server ([#3577](https://github.com/phoenixframework/phoenix_live_view/issues/3577))
* Add `Phoenix.LiveView.JS.to_encodable/1` pushing JS commands via events ([#4060](https://github.com/phoenixframework/phoenix_live_view/pull/4060))
  * `%JS{}` now also implements the `JSON.Encoder` and `Jason.Encoder` protocols
* HTMLFormatter: Better preserve whitespace around tags and inside inline elements ([#3718](https://github.com/phoenixframework/phoenix_live_view/issues/3718))
* HEEx: Allow to opt out of debug annotations for a module ([#4119](https://github.com/phoenixframework/phoenix_live_view/pull/4119))
* HEEx: warn when missing a space between attributes ([#3999](https://github.com/phoenixframework/phoenix_live_view/issues/3999))
* HTMLFormatter: Add `TagFormatter` behaviour for formatting `<style>` and `<script>` tags ([#4140](https://github.com/phoenixframework/phoenix_live_view/pull/4140))
* Add configuration option for `:test_warnings` and warn for forms without an ID by default ([#4128](https://github.com/phoenixframework/phoenix_live_view/pull/4128))
* Performance optimizations in diffing hot path (Thank you [@preciz](https://github.com/preciz)!)

## v1.1

The CHANGELOG for v1.1 releases can be found [in the v1.1 branch](https://github.com/phoenixframework/phoenix_live_view/blob/v1.1/CHANGELOG.md).

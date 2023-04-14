# Live layouts

From Phoenix v1.7, your application is made of two layouts:

  * the root layout - this is a layout used by both LiveView and
    regular views. This layout typically contains the `<html>`
    definition alongside the head and body tags. Any content defined
    in the root layout will remain the same, even as you live navigate
    across LiveViews. The root layout is typically declared on the
    router with `put_root_layout` and defined as "root.html.heex"
    in your layouts folder

  * the app layout - this is the default application layout which
    is rendered on both regular HTTP requests and LiveViews.
    It defaults to "app.html.heex"

Overall, those layouts are found in `components/layouts` and are
embedded within `MyAppWeb.Layouts`.

All layouts must call `<%= @inner_content %>` to inject the
content rendered by the layout.

## Root layout

The "root" layout is rendered only on the initial request and
therefore it has access to the `@conn` assign. The root layout
is typically defined in your router:

    plug :put_root_layout, html: {MyAppWeb.LayoutView, :root}

The root layout can also be set via the `:root_layout` option
in your router via `Phoenix.LiveView.Router.live_session/2`.

## Application layout

The "app.html.heex" layout is rendered with either `@conn` or
`@socket`. Both Controllers and LiveViews explicitly define
the default layouts they will use. See the `def controller`
and `def live_view` definitions in your `MyAppWeb` to learn how
it is included.

For LiveViews, the default layout can be overidden in two different
ways for flexibility:

  1. The `:layout` option in `Phoenix.LiveView.Router.live_session/2`,
     when set, will override the `:layout` option given via
     `use Phoenix.LiveView`

  2. The `:layout` option returned on mount, via `{:ok, socket, layout: ...}`
     will override any previously set layout option

The LiveView itself will be rendered inside the layout wrapped by
the `:container` tag.

## Updating document title

Because the root layout from the Plug pipeline is rendered outside of
LiveView, the contents cannot be dynamically changed. The one exception
is the `<title>` of the HTML document. Phoenix LiveView special cases
the `@page_title` assign to allow dynamically updating the title of the
page, which is useful when using live navigation, or annotating the browser
tab with a notification. For example, to update the user's notification
count in the browser's title bar, first set the `page_title` assign on
mount:

      def mount(_params, _session, socket) do
        socket = assign(socket, page_title: "Latest Posts")
        {:ok, socket}
      end

Then access `@page_title` in the root layout:

```heex
<title><%= @page_title %></title>
```

You can also use the `Phoenix.Component.live_title/1` component to support
adding automatic prefix and suffix to the page title when rendered and
on subsequent updates:

```heex
<Phoenix.Component.live_title prefix="MyApp – ">
  <%= assigns[:page_title] || "Welcome" %>
</Phoenix.Component.live_title>
```

Although the root layout is not updated by LiveView, by simply assigning
to `page_title`, LiveView knows you want the title to be updated:

    def handle_info({:new_messages, count}, socket) do
      {:noreply, assign(socket, page_title: "Latest Posts (#{count} new)")}
    end

*Note*: If you find yourself needing to dynamically patch other parts of the
base layout, such as injecting new scripts or styles into the `<head>` during
live navigation, *then a regular, non-live, page navigation should be used
instead*. Assigning the `@page_title` updates the `document.title` directly,
and therefore cannot be used to update any other part of the base layout.

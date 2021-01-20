# Live layouts

*NOTE:* Make sure you've read the [Assigns and LiveEEx templates](assigns-eex.md)
guide before moving forward.

When working with LiveViews, there are usually three layouts to be
considered:

  * the root layout - this is a layout used by both LiveView and
    regular views. This layout typically contains the `<html>`
    definition alongside the head and body tags. Any content defined
    in the root layout will remain the same, even as you live navigate
    across LiveViews. All LiveViews defined at the router must have
    a root layout. The root layout is typically declared on the
    router with `put_root_layout` and defined as "root.html.leex"
    in your `MyAppWeb.LayoutView`. It may also be given via the
    `:layout` option to the router's `live` macro.

  * the app layout - this is the default application layout which
    is not included or used by LiveViews. It defaults to "app.html.eex"
    in your `MyAppWeb.LayoutView`.

  * the live layout - this is the layout which wraps a LiveView and
    is rendered as part of the LiveView life-cycle. It must be opt-in
    by passing the `:layout` option on `use Phoenix.LiveView`. It is
    typically set to "live.html.leex"in your `MyAppWeb.LayoutView`.

Overall, those layouts are found in `templates/layout` with the
following names:

    * root.html.leex
    * app.html.eex
    * live.html.leex

All layouts must call `<%= @inner_content %>` to inject the
content rendered by the layout.

The "root" layout is shared by both "app" and "live" layouts.
It is rendered only on the initial request and therefore it
has access to the `@conn` assign. The root layout must be defined
in your router:

    plug :put_root_layout, {MyAppWeb.LayoutView, :root}

Alternatively, the root layout can be passed individually to the
`live` macro of your **live routes**:

    live "/dashboard", MyAppWeb.Dashboard, layout: {MyAppWeb.LayoutView, :root}

The "app" and "live" layouts are often small and similar to each
other, but the "app" layout uses the `@conn` and is used as part
of the regular request life-cycle. The "live" layout is part of
the LiveView and therefore has direct access to the `@socket`.

For example, you can define a new `live.html.leex` layout with
dynamic content. You must use `@inner_content` where the output
of the actual template will be placed at:

    <p><%= live_flash(@flash, :notice) %></p>
    <p><%= live_flash(@flash, :error) %></p>
    <%= @inner_content %>

To use the live layout, update your LiveView to pass the `:layout`
option to `use Phoenix.LiveView`:

    use Phoenix.LiveView, layout: {MyAppWeb.LayoutView, "live.html"}

If you are using Phoenix v1.5, the layout is automatically set
when generating apps with the `mix phx.new --live` flag.

The `:layout` option on `use` does not apply to LiveViews rendered
within other LiveViews. If you want to render child live views or
opt-in to a layout, use `:layout` as an option in mount:

      def mount(_params, _session, socket) do
        socket = assign(socket, new_message_count: 0)
        {:ok, socket, layout: {MyAppWeb.LayoutView, "live.html"}}
      end

*Note*: The live layout is always wrapped by the LiveView's `:container` tag.

## Updating the HTML document title

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

    <title><%= @page_title %></title>

You can also use `Phoenix.LiveView.Helpers.live_title_tag/2` to support
adding automatic prefix and suffix to the page title when rendered and
on subsequent updates:

    <%= live_title_tag assigns[:page_title] || "Welcome", prefix: "MyApp – " %>

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

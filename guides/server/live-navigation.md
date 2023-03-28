# Live navigation

LiveView provides functionality to allow page navigation using the
[browser's pushState API](https://developer.mozilla.org/en-US/docs/Web/API/History_API).
With live navigation, the page is updated without a full page reload.

You can trigger live navigation in two ways:

  * From the client - this is done by passing either `patch={url}` or `navigate={url}`
    to the `Phoenix.Component.link/1` component.

  * From the server - this is done by `Phoenix.LiveView.push_patch/2` or `Phoenix.LiveView.push_navigate/2`.

For example, instead of writing the following in a template:

```heex
<.link href={~p"/pages/#{@page + 1}"}>Next</.link>
```

You would write:

```heex
<.link patch={~p"/pages/#{@page + 1}"}>Next</.link>
```

Or in a LiveView:

```elixir
{:noreply, push_patch(socket, to: ~p"/pages/#{@page + 1}")}
```

The "patch" operations must be used when you want to navigate to the
current LiveView, simply updating the URL and the current parameters,
without mounting a new LiveView. When patch is used, the
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) callback is
invoked and the minimal set of changes are sent to the client.
See the next section for more information.

The "navigate" operations must be used when you want to dismount the
current LiveView and mount a new one. You can only "navigate" between
LiveViews in the same session. While redirecting, a `phx-loading` class
is added to the LiveView, which can be used to indicate to the user a
new page is being loaded.

If you attempt to patch to another LiveView or navigate across live sessions,
a full page reload is triggered. This means your application continues to work,
in case your application structure changes and that's not reflected in the navigation.

Here is a quick breakdown:

  * `<.link href={...}>` and [`redirect/2`](`Phoenix.Controller.redirect/2`)
    are HTTP-based, work everywhere, and perform full page reloads

  * `<.link navigate={...}>` and [`push_navigate/2`](`Phoenix.LiveView.push_navigate/2`)
    work across LiveViews in the same session. They mount a new LiveView
    while keeping the current layout

  * `<.link patch={...}>` and [`push_patch/2`](`Phoenix.LiveView.push_patch/2`)
    updates the current LiveView and sends only the minimal diff while also
    maintaining the scroll position

## `handle_params/3`

The [`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) callback is invoked
after [`mount/3`](`c:Phoenix.LiveView.mount/3`) and before the initial render.
It is also invoked every time `<.link patch={...}>`
or [`push_patch/2`](`Phoenix.LiveView.push_patch/2`) are used.
It receives the request parameters as first argument, the url as second,
and the socket as third.

For example, imagine you have a `UserTable` LiveView to show all users in
the system and you define it in the router as:

    live "/users", UserTable

Now to add live sorting, you could do:

```heex
<.link patch={path(~p"/users", sort_by: "name")}>Sort by name</.link>
```

When clicked, since we are navigating to the current LiveView,
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) will be invoked.
Remember you should never trust the received params, so you must use the callback to
validate the user input and change the state accordingly:

    def handle_params(params, _uri, socket) do
      socket =
        case params["sort_by"] do
          sort_by when sort_by in ~w(name company) -> assign(socket, sort_by: sort_by)
          _ -> socket
        end

      {:noreply, load_users(socket)}
    end

Note we returned `{:noreply, socket}`, where `:noreply` means no
additional information is sent to the client. As with other `handle_*`
callbacks, changes to the state inside
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) will trigger
a new server render.

Note the parameters given to [`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`)
are the same as the ones given to [`mount/3`](`c:Phoenix.LiveView.mount/3`).
So how do you decide which callback to use to load data?
Generally speaking, data should always be loaded on [`mount/3`](`c:Phoenix.LiveView.mount/3`),
since [`mount/3`](`c:Phoenix.LiveView.mount/3`) is invoked once per LiveView life-cycle.
Only the params you expect to be changed via
`<.link patch={...}>` or
[`push_patch/2`](`Phoenix.LiveView.push_patch/2`) must be loaded on
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`).

For example, imagine you have a blog. The URL for a single post is:
"/blog/posts/:post_id". In the post page, you have comments and they are paginated.
You use `<.link patch={...}>` to update the shown
comments every time the user paginates, updating the URL to "/blog/posts/:post_id?page=X".
In this example, you will access `"post_id"` on [`mount/3`](`c:Phoenix.LiveView.mount/3`) and
the page of comments on [`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`).

## Replace page address

LiveView also allows the current browser URL to be replaced. This is useful when you
want certain events to change the URL but without polluting the browser's history.
This can be done by passing the `<.link replace>` option to any of the navigation helpers.

## Multiple LiveViews in the same page

LiveView allows you to have multiple LiveViews in the same page by calling
`Phoenix.Component.live_render/3` in your templates. However, only
the LiveViews defined directly in your router can use the "Live Navigation"
functionality described here. This is important because LiveViews work
closely with your router, guaranteeing you can only navigate to known
routes.

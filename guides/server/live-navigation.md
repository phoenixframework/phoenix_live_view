# Live navigation

LiveView provides functionality to allow page navigation using the
[browser's pushState API](https://developer.mozilla.org/en-US/docs/Web/API/History_API).
With live navigation, the page is updated without a full page reload.

You can trigger live navigation in two ways:

  * From the client - this is done by replacing `Phoenix.HTML.Link.link/2`
    by `Phoenix.LiveView.Helpers.live_patch/2` or
    `Phoenix.LiveView.Helpers.live_redirect/2`

  * From the server - this is done by replacing `Phoenix.Controller.redirect/2` calls
    by `Phoenix.LiveView.push_patch/2` or `Phoenix.LiveView.push_redirect/2`.

For example, in a template you may write:

    <%= live_patch "next", to: Routes.live_path(@socket, MyLive, @page + 1) %>

or in a LiveView:

    {:noreply, push_patch(socket, to: Routes.live_path(socket, MyLive, page + 1))}

The "patch" operations must be used when you want to navigate to the
current LiveView, simply updating the URL and the current parameters,
without mounting a new LiveView. When patch is used, the
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) callback is
invoked and the minimal set of changes are sent to the client.
See the next section for more information.

The "redirect" operations must be used when you want to dismount the
current LiveView and mount a new one. In those cases, an Ajax request
is made to fetch the necessary information about the new LiveView,
which is mounted in place of the current one within the current layout.
While redirecting, a `phx-disconnected` class is added to the LiveView,
which can be used to indicate to the user a new page is being loaded.

At the end of the day, regardless if you invoke [`link/2`](`Phoenix.HTML.Link.link/2`),
[`live_patch/2`](`Phoenix.LiveView.Helpers.live_patch/2`),
and [`live_redirect/2`](`Phoenix.LiveView.Helpers.live_redirect/2`) from the client,
or [`redirect/2`](`Phoenix.Controller.redirect/2`),
[`push_patch/2`](`Phoenix.LiveView.push_patch/2`),
and [`push_redirect/2`](`Phoenix.LiveView.push_redirect/2`) from the server,
the user will end-up on the same page. The difference between those is mostly
the amount of data sent over the wire:

  * [`link/2`](`Phoenix.HTML.Link.link/2`) and
    [`redirect/2`](`Phoenix.Controller.redirect/2`) do full page reloads

  * [`live_redirect/2`](`Phoenix.LiveView.Helpers.live_redirect/2`) and
  [`push_redirect/2`](`Phoenix.LiveView.push_redirect/2`) mounts a new LiveView while
    keeping the current layout

  * [`live_patch/2`](`Phoenix.LiveView.Helpers.live_patch/2`) and
    [`push_patch/2`](`Phoenix.LiveView.push_patch/2`) updates the current LiveView
    and sends only the minimal diff while also maintaining the scroll position

An easy rule of thumb is to stick with
[`live_redirect/2`](`Phoenix.LiveView.Helpers.live_redirect/2`) and
[`push_redirect/2`](`Phoenix.LiveView.push_redirect/2`) and use the patch
helpers only in the cases where you want to minimize the
amount of data sent when navigating within the same LiveView (for example,
if you want to change the sorting of a table while also updating the URL).

## `handle_params/3`

The [`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) callback is invoked
after [`mount/3`](`c:Phoenix.LiveView.mount/3`) and before the initial render.
It is also invoked every time [`live_patch/2`](`Phoenix.LiveView.Helpers.live_patch/2`)
or [`push_patch/2`](`Phoenix.LiveView.push_patch/2`) are used.
It receives the request parameters as first argument, the url as second,
and the socket as third.

For example, imagine you have a `UserTable` LiveView to show all users in
the system and you define it in the router as:

    live "/users", UserTable

Now to add live sorting, you could do:

    <%= live_patch "Sort by name", to: Routes.live_path(@socket, UserTable, %{sort_by: "name"}) %>

When clicked, since we are navigating to the current LiveView,
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) will be invoked.
Remember you should never trust the received params, so you must use the callback to
validate the user input and change the state accordingly:

    def handle_params(params, _uri, socket) do
      socket =
        case params["sort_by"] do
          sort_by when sort_by in ~w(name company) -> assign(socket, sort_by: sort)
          _ -> socket
        end

      {:noreply, load_users(socket)}
    end

As with other `handle_*` callbacks, changes to the state inside
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) will trigger a server render.

Note the parameters given to [`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`)
are the same as the ones given to [`mount/3`](`c:Phoenix.LiveView.mount/3`).
So how do you decide which callback to use to load data?
Generally speaking, data should always be loaded on [`mount/3`](`c:Phoenix.LiveView.mount/3`),
since [`mount/3`](`c:Phoenix.LiveView.mount/3`) is invoked once per LiveView life-cycle.
Only the params you expect to be changed via
[`live_patch/2`](`Phoenix.LiveView.Helpers.live_patch/2`) or
[`push_patch/2`](`Phoenix.LiveView.push_patch/2`) must be loaded on
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`).

For example, imagine you have a blog. The URL for a single post is:
"/blog/posts/:post_id". In the post page, you have comments and they are paginated.
You use [`live_patch/2`](`Phoenix.LiveView.Helpers.live_patch/2`) to update the shown
comments every time the user paginates, updating the URL to "/blog/posts/:post_id?page=X".
In this example, you will access `"post_id"` on [`mount/3`](`c:Phoenix.LiveView.mount/3`) and
the page of comments on [`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`).

Furthermore, it is very important to not access the same parameters on both
[`mount/3`](`c:Phoenix.LiveView.mount/3`) and
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`).
For example, do NOT do this:

    def mount(%{"post_id" => post_id}, session, socket) do
      # do something with post_id
    end

    def handle_params(%{"post_id" => post_id, "page" => page}, url, socket) do
      # do something with post_id and page
    end

If you do that, because [`mount/3`](`c:Phoenix.LiveView.mount/3`) is called once and
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) multiple times, the "post_id"
read on mount can get out of sync with the one in
[`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`).
So once a parameter is read on mount, it should not be read elsewhere. Instead, do this:

    def mount(%{"post_id" => post_id}, session, socket) do
      # do something with post_id
    end

    def handle_params(%{"sort_by" => sort_by}, url, socket) do
      post_id = socket.assigns.post.id
      # do something with sort_by
    end

## Replace page address

LiveView also allows the current browser URL to be replaced. This is useful when you
want certain events to change the URL but without polluting the browser's history.
This can be done by passing the `replace: true` option to any of the navigation helpers.

## Multiple LiveViews in the same page

LiveView allows you to have multiple LiveViews in the same page by calling
`Phoenix.LiveView.Helpers.live_render/3` in your templates. However, only
the LiveViews defined directly in your router can use the "Live Navigation"
functionality described here. This is important because LiveViews work
closely with your router, guaranteeing you can only navigate to known
routes.

# Security considerations

LiveView begins its life-cycle as a regular HTTP request. Then a stateful
connection is established. Both the HTTP request and the stateful connection
receive the client data via parameters and session.

This means that any session validation must happen both in the HTTP request
(plug pipeline) and the stateful connection (LiveView mount).

## Authentication vs authorization

When speaking about security, there are two terms commonly used:
authentication and authorization. Authentication is about identifying
a user. Authorization is about telling if a user has access to a certain
resource or feature in the system.

In a regular web application, once a user is authenticated, for example by
entering their email and password, or by using a third-party service such as
Google, Twitter, or Facebook, a token identifying the user is stored in the
session, which is a cookie (a key-value pair) stored in the user's browser.

Every time there is a request, we read the value from the session, and, if
valid, we fetch the user stored in the session from the database. The session
is automatically validated by Phoenix and tools like `mix phx.gen.auth` can
generate the building blocks of an authentication system for you.

Once the user is authenticated, they may perform many actions on the page,
and some of those actions require specific permissions. This is called
authorization and the specific rules often change per application.

In a regular web application, we perform authentication and authorization
checks on every request. In LiveView, we should also run those exact same
checks, always. Once the user is authenticated, we typically validate the
sessions on the `mount` callback. Authorization rules generally happen on
`mount` (for instance, is the user allowed to see this page?) and also on
`handle_event` (is the user allowed to delete this item?).

## Mounting considerations

The [`mount/3`](`c:Phoenix.LiveView.mount/3`) callback is invoked both on
the initial HTTP mount and when LiveView is connected. Therefore, any
authentication performed during mount will cover all scenarios.

However, if you perform user authentication and confirmation exclusively on HTTP
requests via Plugs, such as this:

    plug :ensure_user_authenticated
    plug :ensure_user_confirmed

Then the [`mount/3`](`c:Phoenix.LiveView.mount/3`) callback of your LiveView
should execute those same verifications:

    def mount(_params, %{"user_id" => user_id} = _session, socket) do
      socket = assign(socket, current_user: Accounts.get_user!(user_id))

      socket =
        if socket.assigns.current_user.confirmed_at do
          socket
        else
          redirect(socket, to: "/login")
        end

      {:ok, socket}
    end

Beginning with v0.17, LiveView includes the `on_mount` (`Phoenix.LiveView.on_mount/1`) hook,
which allows you to encapsulate this logic and execute it on every mount,
as you would with plug:

    defmodule MyAppWeb.UserLiveAuth do
      import Phoenix.Component
      import Phoenix.LiveView
      alias MyAppWeb.Accounts # from `mix phx.gen.auth`

      def on_mount(:default, _params, %{"user_token" => user_token} = _session, socket) do
        socket =
          assign_new(socket, :current_user, fn ->
            Accounts.get_user_by_session_token(user_token)
          end)

        if socket.assigns.current_user.confirmed_at do
          {:cont, socket}
        else
          {:halt, redirect(socket, to: "/login")}
        end
      end
    end

We use [`assign_new/3`](`Phoenix.Component.assign_new/3`). This is a
convenience to avoid fetching the `current_user` multiple times across
LiveViews.

Now we can use the hook whenever relevant. One option is to specify
the hook in your router under `live_session`:

    live_session :default, on_mount: MyAppWeb.UserLiveAuth do
      # Your routes
    end

Alternatively, you can either specify the hook directly in the LiveView:

    defmodule MyAppWeb.PageLive do
      use MyAppWeb, :live_view
      on_mount MyAppWeb.UserLiveAuth

      ...
    end

If you prefer, you can add the hook to `def live_view` under `MyAppWeb`,
to run it on all LiveViews by default:

    def live_view do
      quote do
        use Phoenix.LiveView,
          layout: {MyAppWeb.LayoutView, :live}

        on_mount MyAppWeb.UserLiveAuth
        unquote(html_helpers())
      end
    end

## Events considerations

Every time the user performs an action on your system, you should verify if the user
is authorized to do so, regardless if you are using LiveViews or not. For example,
imagine a user can see all projects in a web application, but they may not have
permission to delete any of them. At the UI level, you handle this accordingly
by not showing the delete button in the projects listing, but a savvy user can
directly talk to the server and request a deletion anyway. For this reason, **you
must always verify permissions on the server**.

In LiveView, most actions are handled by the `handle_event` callback. Therefore,
you typically authorize the user within those callbacks. In the scenario just
described, one might implement this:

    on_mount MyAppWeb.UserLiveAuth

    def mount(_params, _session, socket) do
      {:ok, load_projects(socket)}
    end

    def handle_event("delete_project", %{"project_id" => project_id}, socket) do
      Project.delete!(socket.assigns.current_user, project_id)
      {:noreply, update(socket, :projects, &Enum.reject(&1, fn p -> p.id == project_id end)}
    end

    defp load_projects(socket) do
      projects = Project.all_projects(socket.assigns.current_user)
      assign(socket, projects: projects)
    end

First, we used `on_mount` to authenticate the user based on the data stored in
the session. Then we load all projects based on the authenticated user. Now,
whenever there is a request to delete a project, we still pass the current user
as argument to the `Project` context, so it verifies if the user is allowed to
delete it or not. In case it cannot delete, it is fine to just raise an exception.
After all, users are not meant to trigger this code path anyway (unless they are
fiddling with something they are not supposed to!).

## Disconnecting all instances of a live user

So far, the security model between LiveView and regular web applications have
been remarkably similar. After all, we must always authenticate and authorize
every user. The main difference between them happens on logout or when revoking
access.

Because LiveView is a permanent connection between client and server, if a user
is logged out, or removed from the system, this change won't reflect on the
LiveView part unless the user reloads the page.

Luckily, it is possible to address this by setting a `live_socket_id` in the
session. For example, when logging in a user, you could do:

    conn
    |> put_session(:current_user_id, user.id)
    |> put_session(:live_socket_id, "users_socket:#{user.id}")

Now all LiveView sockets will be identified and listen to the given `live_socket_id`.
You can then disconnect all live users identified by said ID by broadcasting on
the topic:

    MyAppWeb.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})

> Note: If you use `mix phx.gen.auth` to generate your authentication system,
> lines to that effect are already present in the generated code. The generated
> code uses a `user_token` instead of referring to the `user_id`.

Once a LiveView is disconnected, the client will attempt to reestablish
the connection and re-execute the [`mount/3`](`c:Phoenix.LiveView.mount/3`)
callback. In this case, if the user is no longer logged in or it no longer has
access to the current resource, `mount/3` will fail and the user will be
redirected.

This is the same mechanism provided by `Phoenix.Channel`s. Therefore, if
your application uses both channels and LiveViews, you can use the same
technique to disconnect any stateful connection.

## `live_session` and `live_redirect`

LiveView supports live redirect, which allows users to navigate between
pages over the LiveView connection. Whenever there is a `live_redirect`,
a new LiveView will be mounted, skipping the regular HTTP requests and
without going through the plug pipeline.

However, if you want to draw stronger boundaries between parts of your
application, you can also use `Phoenix.LiveView.Router.live_session/2`
to group your live routes. This can be handy because you can only
`live_redirect` between LiveViews in the same `live_session`.

For example, imagine you need to authenticate two distinct types of users.
Your regular users login via email and password, and you have an admin
dashboard that uses http auth. You can specify different `live_session`s
for each authentication flow:

    live_session :default do
      scope "/" do
        pipe_through [:authenticate_user]
        get ...
        live ...
      end
    end

    live_session :admin do
      scope "/admin" do
        pipe_through [:http_auth_admin]
        get ...
        live ...
      end
    end

Now every time you try to navigate to an admin panel, and out of it,
a regular page navigation will happen and a brand new live connection
will be established.

Once again, it is worth remembering that LiveViews require their own
security checks, so we use `pipe_through` above to protect the regular
routes (get, post, etc.) and the LiveViews should run their own checks
using `on_mount` hooks.

`live_session` can also be used to enforce each LiveView group has
a different root layout, since layouts are not updated between live
redirects:

    live_session :default, root_layout: {LayoutView, :root} do
      ...
    end

    live_session :admin, root_layout: {LayoutView, :admin} do
      ...
    end

Finally, you can even combine `live_session` with `on_mount`. Instead
of declaring `on_mount` on every LiveView, you can declare it at the
router level and it will enforce it on all LiveViews under it:

    live_session :default, on_mount: MyAppWeb.UserLiveAuth do
      scope "/" do
        pipe_through [:authenticate_user]
        live ...
      end
    end

    live_session :admin, on_mount: MyAppWeb.AdminLiveAuth do
      scope "/admin" do
        pipe_through [:authenticate_admin]
        live ...
      end
    end

Each live route under the `:default` `live_session` will invoke
the `MyAppWeb.UserLiveAuth` hook on mount. This module was defined
earlier in this guide. We will also pipe regular web requests through
`:authenticate_user`, which must execute the same checks as
`MyAppWeb.UserLiveAuth`, but tailored to plug.

Similarly, the `:admin` `live_session` has its own authentication
flow, powered by `MyAppWeb.AdminLiveAuth`. It also defines a plug
equivalent named `:authenticate_admin`, which will be used by any
regular request. If there are no regular web requests defined under
a live session, then the `pipe_through` checks are not necessary.

Declaring the `on_mount` on `live_session` is exactly the same as
declaring it in each LiveView. It will be executed every time a
LiveView is mounted, even after `live_redirect`s.

## Summing up

The important concepts to keep in mind are:

  * If you have both LiveViews and regular web requests, then any
    logic in your plugs must be replicated in your LiveView. Code
    that executes on the `mount` callback always runs on both live
    and regular web requests to that LiveView

  * All actions (events) must also be explicitly authorized by
    checking permissions. Those permissions are often domain/business
    specific, and typically happen in your context modules

  * `live_session` can be used to draw boundaries between groups of
    LiveViews. While you could use `live_session` to draw lines between
    different authorization rules, doing so would lead to frequent page
    reloads. For this reason, we typically use `live_session` to enforce
    different *authentication* requirements or whenever you need to
    change root layouts

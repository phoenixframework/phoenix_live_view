# Security considerations of the LiveView model

As we have seen, LiveView begins its life-cycle as a regular HTTP request.
Then a stateful connection is established. Both the HTTP request and
the stateful connection receives the client data via parameters and session.
This means that any session validation must happen both in the HTTP request
and the stateful connection.

## Mounting considerations

For example, if you perform user authentication and confirmation on every
HTTP request via Plugs, such as this:

    plug :ensure_user_authenticated
    plug :ensure_user_confirmed

Then the [`mount/3`](`c:Phoenix.LiveView.mount/3`) callback of your LiveView
should execute those same verifications:

    def mount(params, %{"user_id" => user_id} = _session, socket) do
      socket = assign(socket, current_user: Accounts.get_user!(user_id))

      socket =
        if socket.assigns.current_user.confirmed_at do
          socket
        else
          redirect(socket, to: "/login")
        end

      {:ok, socket}
    end

Given almost all [`mount/3`](`c:Phoenix.LiveView.mount/3`) actions in your
application will have to perform these exact steps, we recommend creating a
function called `assign_defaults/2` or similar, putting it in a new module like
`MyAppWeb.LiveHelpers`, and modifying `lib/my_app_web.ex` so all
LiveViews automatically import it:

    def live_view do
      quote do
        # ...other stuff...
        import MyAppWeb.LiveHelpers
      end
    end

Then make sure to call it in every LiveView's [`mount/3`](`c:Phoenix.LiveView.mount/3`):

    def mount(params, session, socket) do
      {:ok, assign_defaults(session, socket)}
    end

Where `MyAppWeb.LiveHelpers` can be something like:

    defmodule MyAppWeb.LiveHelpers do
      import Phoenix.LiveView

      def assign_defaults(%{"user_id" => user_id}, socket) do
        socket = assign(socket, current_user: Accounts.get_user!(user_id))

        if socket.assigns.current_user.confirmed_at do
          socket
        else
          redirect(socket, to: "/login")
        end
      end
    end

One possible concern in this approach is that in regular HTTP requests the
current user will be fetched twice: once in the HTTP request and again on
[`mount/3`](`c:Phoenix.LiveView.mount/3`). You can address this by using the
[`assign_new/3`](`Phoenix.LiveView.assign_new/3`) function, that will
reuse any of the connection assigns from the HTTP request:

    def assign_defaults(%{"user_id" => user_id}, socket) do
      socket = assign_new(socket, :current_user, fn -> Accounts.get_user!(user_id) end)

      if socket.assigns.current_user.confirmed_at do
        socket
      else
        redirect(socket, to: "/login")
      end
    end

## Events considerations

It is also important to keep in mind that LiveViews are stateful. Therefore,
if you load any data on [`mount/3`](`c:Phoenix.LiveView.mount/3`) and the data
itself changes, the data won't be automatically propagated to the LiveView,
unless you broadcast those events with `Phoenix.PubSub`.

Generally speaking, the simplest and safest approach is to perform authorization
whenever there is an action. For example, imagine that you have a LiveView
for a "Blog", and only editors can edit posts. Therefore, it is best to validate
the user is an editor on mount and on every event:

    def mount(%{"post_id" => post_id}, session, socket) do
      socket = assign_defaults(session, socket)
      post = Blog.get_post_for_user!(socket.assigns.current_user, post_id)
      {:ok, assign(socket, post: post)}
    end

    def handle_event("update_post", params, socket) do
      updated_post = Blog.update_post(socket.assigns.current_user, socket.assigns.post, params)
      {:noreply, assign(socket, post: updated_post)}
    end

In the example above, the Blog context receives the user on both `get` and
`update` operations, and always validates accordingly that the user has access,
raising an error otherwise.

## Disconnecting all instances of a given live user

Another security consideration is how to disconnect all instances of a given
live user. For example, imagine the user logs outs, its account is terminated,
or any other reason.

Luckily, it is possible to identify all LiveView sockets by setting a `live_socket_id`
in the session. For example, when signing in a user, you could do:

    conn
    |> put_session(:current_user_id, user.id)
    |> put_session(:live_socket_id, "users_socket:#{user.id}")

Now all LiveView sockets will be identified and listening to the given
`live_socket_id`. You can disconnect all live users identified by said
ID by broadcasting on the topic:

    MyAppWeb.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})

Once a LiveView is disconnected, the client will attempt to reestablish
the connection, re-executing the [`mount/3`](`c:Phoenix.LiveView.mount/3`) callback.
In this case, if the user is no longer logged in or it no longer has access to its
current resource, [`mount/3`](`c:Phoenix.LiveView.mount/3`) will fail and the user
will be redirected to the proper page.

This is the same mechanism provided by `Phoenix.Channel`s. Therefore, if
your application uses both channels and LiveViews, you can use the same
technique to disconnect any stateful connection.

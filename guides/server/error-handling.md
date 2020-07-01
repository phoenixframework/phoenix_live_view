# Error and exception handling

As with any other Elixir code, exceptions may happen during the LiveView
life-cycle. In this section we will describe how LiveView reacts to errors
at different stages.

## Expected scenarios

In this section, we will talk about error cases that you expect to happen
within your application. For example, a user filling in a form with invalid
data is expected. In a LiveView, we typically handle those cases by storing
a change in the LiveView state, which causes the LiveView to be re-rendered
with the error message.

We may also use `flash` messages for this. For example, imagine you have a
page to manage all "Team members" in an organization. However, if there is
only one member left in the organization, they should not be allowed to
leave. You may want to handle this by using flash messages:

    if MyApp.Org.leave(socket.assigns.current_org, member) do
      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "last member cannot leave organization")}
    end

However, one may argue that, if the last member of an organization cannot
leave it, it may be better to not even show the "Leave" button in the UI
when the organization has only one member.

Given the button does not appear in the UI, triggering the "leave" when
the organization has now only one member is an unexpected scenario. This
means we can probably rewrite the code above to:

    true = MyApp.Org.leave(socket.assigns.current_org, member)
    {:noreply, socket}

If `leave` returns false by any chance, it will just raise. Or you can
even provide a `leave!` function that raises a specific exception:

    MyApp.Org.leave!(socket.assigns.current_org, member)
    {:noreply, socket}

However, what will happen with a LiveView in case of exceptions?
Let's talk about unexpected scenarios.

## Unexpected scenarios

Elixir developers tend to write assertive code. This means that, if we
expect `leave` to always return true, we can explicitly match on its
result, as we did above:

    true = MyApp.Org.leave(socket.assigns.current_org, member)
    {:noreply, socket}

If `leave` fails and returns `false`, an exception is raised. It is common
for Elixir developers to use exceptions for unexpected scenarios in their
Phoenix applications.

For example, if you are building an application where a user may belong to
one or more organizations, when accessing the organization page, you may want to
check that the user has access to it like this:

    organizations_query = Ecto.assoc(socket.assigns.current_user, :organizations)
    Repo.get!(organizations_query, params["org_id"])

The code above builds a query that returns all organizations that belongs to
the current user and then validates that the given "org_id" belongs to the
user. If there is no such "org_id" or if the user has no access to it, an
`Ecto.NotFoundError` exception is raised.

During a regular controller request, this exception will be converted to a
404 exception and rendered as a custom error page, as
[detailed here](https://hexdocs.pm/phoenix/custom_error_pages.html).
To understand how a LiveView reacts to exceptions, we need to consider two
scenarios: exceptions on mount and during any event.

## Exceptions on mount

Given the code on mount runs both on the initial disconnected render and the
connected render, an exception on mount will trigger the following events:

Exceptions during disconnected render:

  1. An exception on mount is caught and converted to an exception page
    by Phoenix error views - pretty much like the way it works with controllers

Exceptions during connected render:

  1. An exception on mount will crash the LiveView process - which will be logged
  2. Once the client has noticed the crash during `mount`, it will fully reload the page
  3. Reloading the page will start a disconnected render, that will cause `mount`
    to be invoked again and most likely raise the same exception. Except this time
    it will be caught and converted to an exception page by Phoenix error views

In other words, LiveView will reload the page in case of errors, making it
fail as if LiveView was not involved in the rendering in the first place.

## Exceptions on events (`handle_info`, `handle_event`, etc)

If the error happens during an event, the LiveView process will crash. The client
will notice the error and remount the LiveView - without reloading the page. This
is enough to update the page and show the user the latest information.

For example, let's say two users try to leave the organization at the same time.
In this case, both of them see the "Leave" button, but our `leave` function call
will succeed only for one of them:

    true = MyApp.Org.leave(socket.assigns.current_org, member)
    {:noreply, socket}

When the exception raises, the client will remount the LiveView. Once you remount,
your code will now notice that there is only one user in the organization and
therefore no longer show the "Leave" button. In other words, by remounting,
we often update the state of the page, allowing exceptions to be automatically
handled.

Note that the choice between conditionally checking on the result of the `leave`
function with an `if`, or simply asserting it returns `true`, is completely
up to you. If the likelihood of everyone leaving the organization at the same
time is low, then you may as well treat it as an unexpected scenario. Although
other developers will be more comfortable by explicitly handling those cases.
In both scenarios, LiveView has you covered.

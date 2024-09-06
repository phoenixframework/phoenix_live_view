# Error and exception handling

As with any other Elixir code, exceptions may happen during the LiveView
life-cycle. This page describes how LiveView handles errors at different
stages.

## Expected scenarios

In this section, we will talk about error cases that you expect to happen
within your application. For example, a user filling in a form with invalid
data is expected. In a LiveView, we typically handle those cases by storing
the form state in LiveView assigns and rendering any relevant error message
back to the client.

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

Given the button does not appear in the UI, triggering the "leave" action when
the organization has only one member is an unexpected scenario. This means we
can rewrite the code above to:

    true = MyApp.Org.leave(socket.assigns.current_org, member)
    {:noreply, socket}

If `leave` does not return `true`, Elixir will raise a `MatchError`
exception. Or you could provide a `leave!` function that raises a specific
exception:

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
the current user and then validates that the given `org_id` belongs to the
user. If there is no such `org_id` or if the user has no access to it,
`Repo.get!` will raise an `Ecto.NoResultsError` exception.

During a regular controller request, this exception will be converted to a
404 exception and rendered as a custom error page, as
[detailed here](https://hexdocs.pm/phoenix/custom_error_pages.html).
LiveView will react to exceptions in three different ways, depending on
where it is in its life-cycle.

### Exceptions during HTTP mount

When you first access a LiveView, a regular HTTP request is sent to the server
and processed by the LiveView. The `mount` callback is invoked and then a page
is rendered. Any exception here is caught, logged, and converted to an exception
page by Phoenix error views - exactly how it works with controllers too.

### Exceptions during connected mount

If the initial HTTP request succeeds, LiveView will connect to the server
using a stateful connection, typically a WebSocket. This spawns a long-running
lightweight Elixir process on the server, which invokes the `mount` callback
and renders an updated version of the page.

An exception during this stage will crash the LiveView process, which will be logged.
Once the client notices the crash, it fully reloads the page. This will cause `mount`
to be invoked again during a regular HTTP request (the exact scenario of the previous
subsection).

In other words, LiveView will reload the page in case of errors, making it
fail as if LiveView was not involved in the rendering in the first place.

### Exceptions after connected mount

Once your LiveView is mounted and connected, any error will cause the LiveView process
to crash and be logged. Once the client notices the error, it will remount the LiveView
over the stateful connection, without reloading the page (the exact scenario of the
previous subsection). If remounting succeeds, the LiveView goes back to a working
state, updating the page and showing the user the latest information.

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

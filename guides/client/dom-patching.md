# DOM patching & temporary assigns

A container can be marked with `phx-update`, allowing the DOM patch
operations to avoid updating or removing portions of the LiveView, or to append
or prepend the updates rather than replacing the existing contents. This
is useful for client-side interop with existing libraries that do their
own DOM operations. The following `phx-update` values are supported:

  * `replace` - the default operation. Replaces the element with the contents
  * `ignore` - ignores updates to the DOM regardless of new content changes
  * `append` - append the new DOM contents instead of replacing
  * `prepend` - prepend the new DOM contents instead of replacing

When using `phx-update`, a unique DOM ID must always be set in the
container. If using "append" or "prepend", a DOM ID must also be set
for each child. When appending or prepending elements containing an
ID already present in the container, LiveView will replace the existing
element with the new content instead appending or prepending a new
element.

The "ignore" behaviour is frequently used when you need to integrate
with another JS library. The "append" and "prepend" feature is often
used with "Temporary assigns" to work with large amounts of data. Let's
learn more.

## Temporary assigns

By default, all LiveView assigns are stateful, which enables change
tracking and stateful interactions. In some cases, it's useful to mark
assigns as temporary, meaning they will be reset to a default value after
each update. This allows otherwise large but infrequently updated values
to be discarded after the client has been patched.

Imagine you want to implement a chat application with LiveView. You
could render each message like this:

    <%= for message <- @messages do %>
      <p><span><%= message.username %>:</span> <%= message.text %></p>
    <% end %>

Every time there is a new message, you would append it to the `@messages`
assign and re-render all messages.

As you may suspect, keeping the whole chat conversation in memory
and resending it on every update would be too expensive, even with
LiveView smart change tracking. By using temporary assigns and phx-update,
we don't need to keep any messages in memory, and send messages to be
appended to the UI only when there are new ones.

To do so, the first step is to mark which assigns are temporary and
what values they should be reset to on mount:

    def mount(_params, _session, socket) do
      socket = assign(socket, :messages, load_last_20_messages())
      {:ok, socket, temporary_assigns: [messages: []]}
    end

On mount we also load the initial number of messages we want to
send. After the initial render, the initial batch of messages will
be reset back to an empty list.

Now, whenever there are one or more new messages, we will assign
only the new messages to `@messages`:

    socket = assign(socket, :messages, new_messages)

In the template, we want to wrap all of the messages in a container
and tag this content with `phx-update`. Remember, we must add an ID
to the container as well as to each child:

    <div id="chat-messages" phx-update="append">
      <%= for message <- @messages do %>
        <p id="<%= message.id %>">
          <span><%= message.username %>:</span> <%= message.text %>
        </p>
      <% end %>
    </div>

When the client receives new messages, it now knows to append to the
old content rather than replace it.

You can also update the direction of messages. Suppose there is an edit to a message
that is being sent to your LiveView like this:

    def handle_info({:update_message, message}, socket) do
      {:noreply, update(socket, :messages, fn messages -> [message | messages] end)}
    end
    
You can add it to the list like you do with new messages. LiveView is aware that this
message was rendered on the client, even though the message itself is discarded on the 
server after it is rendered.

LiveView uses DOM ids to check if a message is rendered before or not. If an id is 
rendered before, the DOM element is updated rather than appending or prepending a new node. 
Also, the order of elements is not changed. You can use it to show edited messages, show likes, or
anything that would require an update to a rendered message.

## Pitfall: temporary assigns to reset or control UI state

Temporary assigns are useful when you want to render some data and
then discard it so LiveView no longer needs to keep it in memory.

For this reason, a temporary assign is not re-rendered until it is
set again. This means that temporary assigns should not be used to
reset or control UI state. Let's see an example.

Imagine you want to show an error message when the input is less than
3 chars. You can write this code:

```elixir
  def render(assigns) do
    ~L"""
    <%= if @too_short do %>
      Input too short...
    <% end %>

    Searched for: <%= @search %>
    <form><input phx-change="search" name="term" /></form>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, too_short: false, search: ""),
     temporary_assigns: [too_short: false]}
  end

  def handle_event("search", %{"term" => term}, socket) do
    # do not search if user provides less then 3 chars
    if String.length(term) >= 3 do
      {:noreply, assign(socket, search: term)}
    else
      {:noreply, assign(socket, too_short: true, search: term)}
    end
  end
```

The idea here is that, while the term is less than 3 characters,
we will set `@too_short` to true and show an error message in the
UI accordingly. We also set `@too_short` as a temporary assign,
so that it resets to `false` after every render.

However, once a temporary assign resets to its original value,
it won't be re-rendered, unless we explicitly assign it to something
else. This means that the LiveView will never re-render the
`if` block and we will continue to show "Input too short..." even
after the input has 3 or more characters.

The mistake here is using `:temporary_assigns` to reset or control
UI state, while `:temporary_assigns` should rather be used when we
don't have (or don't want to keep) certain data around. The fix is
to set `too_short: false` on the `if` branch, making sure it is
reset whenever the search input changes.

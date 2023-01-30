# DOM patching & temporary assigns

A container can be marked with `phx-update`, allowing the DOM patch
operations to avoid updating or removing portions of the LiveView, or to append
or prepend the updates rather than replacing the existing contents. This
is useful for client-side interop with existing libraries that do their
own DOM operations. The following `phx-update` values are supported:

  * `replace` - the default operation. Replaces the element with the contents
  * `stream` - supports stream operations. Streams are used to manage large
    collections in the UI without having to store the collection on the server
  * `ignore` - ignores updates to the DOM regardless of new content changes

When using `phx-update`, a unique DOM ID must always be set in the
container. If using "stream", a DOM ID must also be set
for each child. When inserting stream elements containing an
ID already present in the container, LiveView will replace the existing
element with the new content. See `Phoenix.LiveView.stream/3` for more
information.

The "ignore" behaviour is frequently used when you need to integrate
with another JS library. Note only the element contents are ignored,
its attributes can still be updated.

To react to elements being mounted to the DOM, the `phx-mounted` binding
can be used. For example, to animate an element on mount:

    <div phx-mounted={JS.transition("animate-ping", time: 500)}>

If `phx-mounted` is used on the initial page render, it will be invoked only
after the initial WebSocket connection is established.

To react to elements being removed from the DOM, the `phx-remove` binding
may be specified, which can contain a `Phoenix.LiveView.JS` command to execute.

*Note*: The `phx-remove` command is only executed for the removed parent element.
It does not cascade to children.

## Temporary assigns

By default, all LiveView assigns are stateful, which enables change
tracking and stateful interactions. In some cases, it's useful to mark
assigns as temporary, meaning they will be reset to a default value after
each update. This allows otherwise large but infrequently updated values
to be discarded after the client has been patched.

Imagine you want to implement a chat application with LiveView. You
could render each message like this:

```heex
<%= for message <- @messages do %>
  <p><span><%= message.username %>:</span> <%= message.text %></p>
<% end %>
```

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

```heex
<div id="chat-messages" phx-update="append">
  <%= for message <- @messages do %>
    <p id={message.id}>
      <span><%= message.username %>:</span> <%= message.text %>
    </p>
  <% end %>
</div>
```

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

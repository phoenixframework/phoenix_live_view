# Assigns and LiveEEx templates

All of the data in a LiveView is stored in the socket as assigns.
The `Phoenix.LiveView.assign/2` and `Phoenix.LiveView.assign/3`
functions help store those values. Those values can be accessed
in the LiveView as `socket.assigns.name` but they are accessed
inside LiveView templates as `@name`.

`Phoenix.LiveView`'s built-in templates are identified by the `.leex`
extension (Live EEx) or `~L` sigil. They are similar to regular `.eex`
templates except they are designed to minimize the amount of data sent
over the wire by splitting static and dynamic parts and tracking changes.

When you first render a `.leex` template, it will send all of the
static and dynamic parts of the template to the client. After that,
any change you do on the server will now send only the dynamic parts,
and only if those parts have changed.

The tracking of changes is done via assigns. Imagine this template:

    <h1><%= expand_title(@title) %></h1>

If the `@title` assign changes, then LiveView will execute
`expand_title(@title)` and send the new content. If `@title` is
the same, nothing is executed and nothing is sent.

Change tracking also works when accessing map/struct fields.
Take this template:

    <div id="user_<%= @user.id %>">
      <%= @user.name %>
    </div>

If the `@user.name` changes but `@user.id` doesn't, then LiveView
will re-render only `@user.name` and it will not execute or resend `@user.id`
at all.

The change tracking also works when rendering other templates as
long as they are also `.leex` templates:

    <%= render "child_template.html", assigns %>

The assign tracking feature also implies that you MUST avoid performing
direct operations in the template. For example, if you perform a database
query in your template:

    <%= for user <- Repo.all(User) do %>
      <%= user.name %>
    <% end %>

Then Phoenix will never re-render the section above, even if the number of
users in the database changes. Instead, you need to store the users as
assigns in your LiveView before it renders the template:

    assign(socket, :users, Repo.all(User))

Generally speaking, **data loading should never happen inside the template**,
regardless if you are using LiveView or not. The difference is that LiveView
enforces this best practice.

## LiveEEx pitfalls

There are two common pitfalls to keep in mind when using the `~L` sigil
or `.leex` templates.

When it comes to `do/end` blocks, change tracking is supported only on blocks
given to Elixir's basic constructs, such as `if`, `case`, `for`, and friends.
If the do/end block is given to a library function or user function, such as
`content_tag`, change tracking won't work. For example, imagine the following
template that renders a `div`:

    <%= content_tag :div, id: "user_#{@id}" do %>
      <%= @name %>
      <%= @description %>
    <% end %>

LiveView knows nothing about `content_tag`, which means the whole `div` will
be sent whenever any of the assigns change. This can be easily fixed by
writing the HTML directly:

    <div id="user_<%= @id %>">
      <%= @name %>
      <%= @description %>
    </div>

Another pitfall of `.leex` templates is related to variables. Due to the scope
of variables, LiveView has to disable change tracking whenever variables are
used in the template, with the exception of variables introduced by Elixir
basic `case`, `for`, and other block constructs. Therefore, you **must avoid**
code like this in your LiveEEx:

    <% some_var = @x + @y %>
    <%= some_var %>

Instead, use a function:

    <%= sum(@x, @y) %>

Similarly, **do not** define variables at the top of your `render` function:

    def render(assigns) do
      sum = assigns.x + assigns.y

      ~L"""
      <%= sum %>
      """
    end

Instead explicitly precompute the assign in your LiveView, outside of render:

    assign(socket, sum: socket.assigns.x + socket.assigns.y)

Generally speaking, avoid accessing variables inside LiveViews. This also applies
to the `assigns` variable, except when rendering another `.leex` template. In such
cases, it is ok to pass the whole assigns, as LiveView will continue to perform
change tracking in the called template:

    <%= render "sidebar.html", assigns %>

Similarly, variables introduced by Elixir's block constructs are fine. For example,
accessing the `post` variable defined by the comprehension below works as expected:

    <%= for post <- @posts do %>
      ...
    <% end %>

As are the variables matched defined in a `case` or `cond`:

    <%= cond do %>
      <% is_nil(@post) -> %>
        ...
      <% @post -> %>
        ...
    <% end %>

To sum up:

  1. Avoid passing block expressions to library and custom functions

  2. Never do anything on `def render(assigns)` besides rendering a template
    or invoking the `~L` sigil

  3. Avoid defining local variables, except within `for`, `case`, and friends

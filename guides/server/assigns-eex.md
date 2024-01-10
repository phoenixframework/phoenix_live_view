# Assigns and HEEx templates

All of the data in a LiveView is stored in the socket, which is a server 
side struct called `Phoenix.LiveView.Socket`. Your own data is stored
under the `assigns` key of said struct. The server data is never shared
with the client beyond what your template renders.

Phoenix template language is called HEEx (HTML+EEx). EEx is Embedded 
Elixir, an Elixir string template engine. Those templates
are either files with the `.heex` extension or they are created
directly in source files via the `~H` sigil. You can learn more about
the HEEx syntax by checking the docs for [the `~H` sigil](`Phoenix.Component.sigil_H/2`).

The `Phoenix.Component.assign/2` and `Phoenix.Component.assign/3`
functions help store those values. Those values can be accessed
in the LiveView as `socket.assigns.name` but they are accessed
inside HEEx templates as `@name`.

In this section, we are going to cover how LiveView minimizes
the payload over the wire by understanding the interplay between
assigns and templates.

## Change tracking

When you first render a `.heex` template, it will send all of the
static and dynamic parts of the template to the client. Imagine the
following template:

```heex
<h1><%= expand_title(@title) %></h1>
```

It has two static parts, `<h1>` and `</h1>` and one dynamic part
made of `expand_title(@title)`. Further rendering of this template
won't resend the static parts and it will only resend the dynamic
part if it changes.

The tracking of changes is done via assigns. If the `@title` assign
changes, then LiveView will execute `expand_title(@title)` and send
the new content. If `@title` is the same, nothing is executed and
nothing is sent.

Change tracking also works when accessing map/struct fields.
Take this template:

```heex
<div id={"user_#{@user.id}"}>
  <%= @user.name %>
</div>
```

If the `@user.name` changes but `@user.id` doesn't, then LiveView
will re-render only `@user.name` and it will not execute or resend `@user.id`
at all.

The change tracking also works when rendering other templates as
long as they are also `.heex` templates:

```heex
<%= render "child_template.html", assigns %>
```

Or when using function components:

```heex
<.show_name name={@user.name} />
```

The assign tracking feature also implies that you MUST avoid performing
direct operations in the template. For example, if you perform a database
query in your template:

```heex
<%= for user <- Repo.all(User) do %>
  <%= user.name %>
<% end %>
```

Then Phoenix will never re-render the section above, even if the number of
users in the database changes. Instead, you need to store the users as
assigns in your LiveView before it renders the template:

    assign(socket, :users, Repo.all(User))

Generally speaking, **data loading should never happen inside the template**,
regardless if you are using LiveView or not. The difference is that LiveView
enforces this best practice.

## Pitfalls

There are some common pitfalls to keep in mind when using the `~H` sigil
or `.heex` templates inside LiveViews.

When it comes to `do/end` blocks, change tracking is supported only on blocks
given to Elixir's basic constructs, such as `if`, `case`, `for`, and similar.
If the do/end block is given to a library function or user function, such as
`content_tag`, change tracking won't work. For example, imagine the following
template that renders a `div`:

```heex
<%= content_tag :div, id: "user_#{@id}" do %>
  <%= @name %>
  <%= @description %>
<% end %>
```

LiveView knows nothing about `content_tag`, which means the whole `div` will
be sent whenever any of the assigns change. Luckily, HEEx templates provide
a nice syntax for building tags, so there is rarely a need to use `content_tag`
inside `.heex` templates:

```heex
<div id={"user_#{@id}"}>
  <%= @name %>
  <%= @description %>
</div>
```

---

The next pitfall is related to variables. Due to the scope of variables,
LiveView has to disable change tracking whenever variables are used in the
template, with the exception of variables introduced by Elixir basic `case`,
`for`, and other block constructs. Therefore, you **must avoid** code like
this in your `HEEx` templates:

```heex
<% some_var = @x + @y %>
<%= some_var %>
```

Instead, use a function:

```heex
<%= sum(@x, @y) %>
```

Similarly, **do not** define variables at the top of your `render` function
for LiveViews or LiveComponents:

    def render(assigns) do
      sum = assigns.x + assigns.y

      ~H"""
      <%= sum %>
      """
    end

Instead explicitly precompute the assign outside of render:

    assign(socket, sum: socket.assigns.x + socket.assigns.y)

Unlike LiveView, a `Phoenix.Component` function can modify the assigns it receives
via the `assign/2`, `assign/3`, `assign_new/3`, and `update/3` functions.
Therefore, you can assign the computed values before declaring your template:

    attr :x, :integer, required: true
    attr :y, :integer, required: true
    def sum_component(assigns) do
      assigns = assign(assigns, sum: assigns.x + assigns.y)

      ~H"""
      <%= @sum %>
      """
    end

Generally speaking, avoid accessing variables inside `HEEx` templates, as code that
access variables is always executed on every render. This also applies to the
`assigns` variable. The exception are variables introduced by Elixir's block
constructs. For example, accessing the `post` variable defined by the comprehension
below works as expected:

```heex
<%= for post <- @posts do %>
  ...
<% end %>
```

---

Sometimes you might want to pass all assigns from one function component to
another. For example, imagine you have a `card` component that is quite
complex and has a header, content and footer section.
You might refactor your component into three smaller components internally:

```elixir
def card(assigns) do
  ~H"""
  <div class="card">
    <.card_header {assigns} />
    <.card_body {assigns} />
    <.card_footer {assigns} />
  </div>
  """
end

defp card_header(assigns) do
  ...
end

defp card_body(assigns) do
  ...
end

defp card_footer(assigns) do
  ...
end
```

Because of the way function components track changes, the above code will
not work as expected. When any assign changes, even if it is only used in
one of the child components, all three components will be re-rendered,
leading to a large diff over the wire.

Generally, you should avoid passing all assigns and instead be explicit about
which assigns the child components need:

```elixir
def card(assigns) do
  ~H"""
  <div class="card">
    <.card_header title={@title} class={@title_class} />
    <.card_body>
      <%= render_slot(@inner_block) %>
    </.card_body>
    <.card_footer on_close={@on_close} />
  </div>
  """
end
```

If you really need to pass all assigns you should instead use the regular
function call syntax:

```elixir
def card(assigns) do
  ~H"""
  <div class="card">
    <%= card_header(assigns) %>
    <%= card_body(assigns) %>
    <%= card_footer(assigns) %>
  </div>
  """
end
```

This ensures that the change tracking information from the parent component
is passed to the child components. In this case, changing an assign that is
only used in one child component will only re-render the parts of the component
that changed.

---

To sum up:

  1. Avoid passing block expressions to library and custom functions,
     instead prefer to use the conveniences in `HEEx` templates

  2. Avoid defining local variables, except within Elixir's constructs

  3. Avoid passing all assigns to child components, instead be explicit
     about which assigns the child components need or, as a last resort, use
     `<%= component(assigns) %>` instead of `<.component {assigns} />`.

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
<h1>{expand_title(@title)}</h1>
```

It has two static parts, `<h1>` and `</h1>` and one dynamic part
made of `expand_title(@title)`. Further rendering of this template
won't resend the static parts and it will only resend the dynamic
part if it changes.

The tracking of changes is done via assigns. If the `@title` assign
changes, then LiveView will execute the dynamic parts of the template,
`expand_title(@title)`, and send the new content. If `@title` is the same,
nothing is executed and nothing is sent.

Change tracking also works when accessing map/struct fields.
Take this template:

```heex
<div id={"user_#{@user.id}"}>
  {@user.name}
</div>
```

If the `@user.name` changes but `@user.id` doesn't, then LiveView
will re-render only `@user.name` and it will not execute or resend `@user.id`
at all.

The change tracking also works when rendering other templates as
long as they are also `.heex` templates:

```heex
{render("child_template.html", assigns)}
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
  {user.name}
<% end %>
```

Then Phoenix will never re-render the section above, even if the number of
users in the database changes. Instead, you need to store the users as
assigns in your LiveView before it renders the template:

    assign(socket, :users, Repo.all(User))

Generally speaking, **data loading should never happen inside the template**,
regardless if you are using LiveView or not. The difference is that LiveView
enforces this best practice.

## Common pitfalls

There are some common pitfalls to keep in mind when using the `~H` sigil
or `.heex` templates inside LiveViews.

### Variables

Due to the scope of variables, LiveView has to disable change tracking
whenever variables are used in the template, with the exception of
variables introduced by Elixir block constructs such as `case`,
`for`, `if`, and others. Therefore, you **must avoid** code like
this in your HEEx templates:

```heex
<% some_var = @x + @y %>
{some_var}
```

Instead, use a function:

```heex
{sum(@x, @y)}
```

Similarly, **do not** define variables at the top of your `render` function
for LiveViews or LiveComponents. Since LiveView cannot track `sum` or `title`,
if either value changes, both must be re-rendered by LiveView.

    def render(assigns) do
      sum = assigns.x + assigns.y
      title = assigns.title

      ~H"""
      <h1>{title}</h1>

      {sum}
      """
    end

Instead use the `assign/2`, `assign/3`, `assign_new/3`, and `update/3`
functions to compute it. Any assign defined or updated this way will be marked as
changed, while other assigns like `@title` will still be tracked by LiveView.

    assign(assigns, sum: assigns.x + assigns.y)

The same functions can be used inside function components too:

    attr :x, :integer, required: true
    attr :y, :integer, required: true
    attr :title, :string, required: true
    def sum_component(assigns) do
      assigns = assign(assigns, sum: assigns.x + assigns.y)

      ~H"""
      <h1>{@title}</h1>

      {@sum}
      """
    end

Generally speaking, avoid accessing variables inside `HEEx` templates, as code that
access variables is always executed on every render. The exception are variables
introduced by Elixir's block constructs, such as `if` and `for` comprehensions.
For example, accessing the `post` variable defined by the comprehension below
works as expected:

```heex
<%= for post <- @posts do %>
  ...
<% end %>
```

### The `assigns` variable

When talking about variables, it is also worth discussing the `assigns`
special variable. Every time you use the `~H` sigil, you must define an
`assigns` variable, which is also available on every `.heex` template.
However, we must avoid accessing this variable directly inside templates
and instead use `@` for accessing specific keys. This also applies to
function components. Let's see some examples.

Sometimes you might want to pass all assigns from one function component to
another. For example, imagine you have a complex `card` component with
header, content and footer section. You might refactor your component
into three smaller components internally:

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

Because of the way function components handle attributes, the above code will
not perform change tracking and it will always re-render all three components
on every change.

Generally, you should avoid passing all assigns and instead be explicit about
which assigns the child components need:

```elixir
def card(assigns) do
  ~H"""
  <div class="card">
    <.card_header title={@title} class={@title_class} />
    <.card_body>
      {render_slot(@inner_block)}
    </.card_body>
    <.card_footer on_close={@on_close} />
  </div>
  """
end
```

If you really need to pass all assigns you should instead use the regular
function call syntax. This is the only case where accessing `assigns` inside
templates is acceptable:

```elixir
def card(assigns) do
  ~H"""
  <div class="card">
    {card_header(assigns)}
    {card_body(assigns)}
    {card_footer(assigns)}
  </div>
  """
end
```

This ensures that the change tracking information from the parent component
is passed to each child component, only re-rendering what is necessary.
However, generally speaking, it is best to avoid passing `assigns` altogether
and instead let LiveView figure out the best way to track changes.

### Comprehensions

HEEx supports comprehensions in templates, which is a way to traverse lists
and collections. For example:

```heex
<%= for post <- @posts do %>
  <section>
    <h1>{expand_title(post.title)}</h1>
  </section>
<% end %>
```

Or using the special `:for` attribute:

```heex
<section :for={post <- @posts}>
  <h1>{expand_title(post.title)}</h1>
</section>
```

Comprehensions in templates are optimized so the static parts of
a comprehension are only sent once, regardless of the number of items.
However, keep in mind LiveView does not track changes within the
collection given to the comprehension. In other words, if one entry
in `@posts` changes, all posts are sent again.

There are two common solutions to this problem.

The first one is to also provide a `:key` expression:

```heex
<section :for={post <- @posts} :key={post.id}>
  <h1>{expand_title(post.title)}</h1>
</section>
```

This is functionally equivalent to doing:

```heex
<section :for={post <- @posts}>
  <.live_component module={PostComponent} id={"post-#{post.id}"} post={post} />
</section>
```

Since LiveComponents have their own assigns, LiveComponents would allow
you to perform change tracking for each item. If the `@posts` variable
changes, the client will simply send a list of component IDs (which are
integers) and only the data for the posts that actually changed.
You can read more about `:key` in the [documentation for `sigil_H/2`](Phoenix.Component.html#sigil_H/2-special-attributes).

The second solution is to use `Phoenix.LiveView.stream/4`, which gives you
precise control over how elements are added, removed, and updated. Streams
are particularly useful when you don't need to keep the collection in memory,
allowing you to reduce the data sent over the wire and the server memory
usage.

### Summary

To sum up:

  1. Avoid defining local variables inside HEEx templates, except within Elixir's constructs

  2. Avoid passing or accessing the `assigns` variable inside HEEx templates

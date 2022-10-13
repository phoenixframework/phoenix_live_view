defmodule Phoenix.Component do
  @moduledoc ~S'''
  Define reusable function components with HEEx templates.

  A function component is any function that receives an assigns map as an argument and returns
  a rendered struct built with [the `~H` sigil](`sigil_H/2`):

      defmodule MyComponent do
        use Phoenix.Component

        def greet(assigns) do
          ~H"""
          <p>Hello, <%= @name %>!</p>
          """
        end
      end

  When invoked within a `~H` sigil or HEEx template file:

  ```heex
  <MyComponent.greet name="Jane" />
  ```

  The following HTML is rendered:

  ```html
  <p>Hello, Jane!</p>
  ```

  If the function component is defined locally, or its module is imported, then the caller can
  invoke the function directly without specifying the module:

  ```heex
  <.greet name="Jane" />
  ```

  For dynamic values, you can interpolate Elixir expressions into a function component:

  ```heex
  <.greet name={@user.name} />
  ```

  Function components can also accept blocks of HEEx content (more on this later):

  ```heex
  <.card>
    <p>This is the body of my card!</p>
  </.card>
  ```

  Like `Phoenix.LiveView` and `Phoenix.LiveComponent`, function components are implemented using
  a map of assigns, and follow [the same rules and best practices](../guides/server/assigns-eex.md).
  However, we typically do not implement function components by manipulating the assigns map
  directly, as `Phoenix.Component` provides two higher-level abstractions for us:
  attributes and slots.

  ## Attributes

  `Phoenix.Component` provides the `attr/3` macro to declare what attributes the proceeding function
  component expects to receive when invoked:

      attr :name, :string, required: true

      def greet(assigns) do
        ~H"""
        <p>Hello, <%= @name %>!</p>
        """
      end

  By calling `attr/3`, it is now clear that `greet/1` requires a string attribute called `name`
  present in its assigns map to properly render. Failing to do so will result in a compilation
  warning:

  ```heex
  <MyComponent.greet />
    <!-- warning: missing required attribute "name" for component MyAppWeb.MyComponent.greet/1
             lib/app_web/my_component.ex:15 -->
  ```

  Attributes can provide default values that are automatically merged into the assigns map:

      attr :name, :string, default: "Bob"

  Now you can invoke the function component without providing a value for `name`:

  ```heex
  <.greet />
  ```

  Rendering the following HTML:

  ```html
  <p>Hello, Bob!</p>
  ```

  Accessing an attribute which is required and does not have a default value will fail.
  You must explicitly declare `default: nil` or assign a value programmatically with the
  `assign_new/3` function.

  Multiple attributes can be declared for the same function component:

      attr :name, :string, required: true
      attr :age, :integer, required: true

      def celebrate(assigns) do
        ~H"""
        <p>
          Happy birthday <%= @name %>!
          You are <%= @age %> years old.
        </p>
        """
      end

  Allowing the caller to pass multiple values:

  ```heex
  <.celebrate name={"Genevieve"} age={34} />
  ```

  Rendering the following HTML:

  ```html
  <p>
    Happy birthday Genevieve!
    You are 34 years old.
  </p>
  ```

  Multiple function components can be defined in the same module, with different attributes. In the
  following example, `<Components.greet/>` requires a `name`, but *does not* require a `title`, and
  `<Component.heading>` requires a `title`, but *does not* require a `name`.

      defmodule Components do
        use Phoenix.Component

        attr :title, :string, required: true

        def heading(assigns) do
          ~H"""
          <h1><%= @title %></h1>
          """
        end

        attr :name, :string, required: true

        def greet(assigns) do
          ~H"""
          <p>Hello <%= @name %></p>
          """
        end
      end

  With the `attr/3` macro you have the core ingredients to create reusable function components.
  But what if you need your function components to support dynamic attributes, such as common HTML
  attributes to mix into a component's container?

  ### Global Attributes

  Global attributes are a set of attributes that a function component can accept when it
  declares an attribute of type `:global`. By default, the set of attributes accepted are those
  attributes common to all standard HTML tags.
  See [Global attributes](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes)
  for a complete list of attributes.

  Once a global attribute is declared, any number of attributes in the set can be passed by
  the caller without having to modify the function component itself.

  Below is an example of a function component that accepts a dynamic number of global attributes:

      attr :message, :string, required: true
      attr :rest, :global

      def notification(assigns) do
        ~H"""
        <span {@rest}><%= @message %></span>
        """
      end

  The caller can pass multiple global attributes (such as `phx-*` bindings or the `class` attribute):

  ```heex
  <.notification message="You've got mail!" class="bg-green-200" phx-click="close" />
  ```

  Rendering the following HTML:

  ```html
  <span class="bg-green-200" phx-click="close">You've got mail!</span>
  ```

  Note that the function component did not have to explicitly declare a `class` or `phx-click`
  attribute in order to render.

  Global attribute can define defaults which are merged with attributes provided by the caller.
  For example, you may declare a default `class` if the caller does not provide one:

      attr :rest, :global, default: %{class: "bg-blue-200"}

  Now you can call the function component without a `class` attribute:

  ```heex
  <.notification message="You've got mail!" phx-click="close" />
  ```

  Rendering the following HTML:

  ```html
  <span class="bg-blue-200" phx-click="close">You've got mail!</span>
  ```

  You may also specify which attributes are included in addition to the known globals
  with the `:include` option. For example to support the `form` attribute on a button
  component:

  ```elixir
  # <.button form="my-form"/>
  attr :rest, :global, include: ~w(form)
  slot :inner_block
  def button(assigns) do
    ~H"""
    <button {@rest}><%= render_slot(@inner_block) %>
    """
  end
  ```

  The `:include` option is useful to apply global additions on a case-by-case basis, but
  sometimes you want attributes to be available to all globals you provide, such
  as when using frameworks that use attribute prefixes, like Alpine.js's `x-on:click`.
  For these cases, custom global attribute prefixes can be provided, which we'll outline
  next.

  ### Custom Global Attribute Prefixes

  You can extend the set of global attributes by providing a list of attribute prefixes to
  `use Phoenix.Component`. Like the default attributes common to all HTML elements,
  any number of attributes that start with a global prefix will be accepted by function
  components defined in this module. By default, the following prefixes are supported:
  `phx-`, `aria-`, and `data-`. For example, to support the `x-` prefix used by
  [Alpine.js](https://alpinejs.dev/), you can pass the `:global_prefixes` option to
  `use Phoenix.Component`:

      use Phoenix.Component, global_prefixes: ~w(x-)

  Now all function components defined in this module will accept any number of attributes prefixed
  with `x-`, in addition to the default global prefixes.

  You can learn more about attributes by reading the documentation for `attr/3`.

  ## Slots

  In addition to attributes, function components can accept blocks of HEEx content, referred to
  as slots. Slots enable further customization of the rendered HTML, as the caller can pass the
  function component HEEx content they want the component to render. `Phoenix.Component` provides
  the `slot/3` macro used to declare slots for function components:

      slot :inner_block, required: true

      def button(assigns) do
        ~H"""
        <button>
          <%= render_slot(@inner_block) %>
        </button>
        """
      end

  The expression `render_slot(@inner_block)` renders the HEEx content. You can invoke this function
  component like so:

  ```heex
  <.button>
    This renders <strong>inside</strong> the button!
  </.button>
  ```

  Which renders the following HTML:

  ```html
  <button>
    This renders <strong>inside</strong> the button!
  </button>
  ```

  Like the `attr/3` macro, using the `slot/3` macro will provide compile-time validations.
  For example, invoking `button/1` without a slot of HEEx content will result in a compilation
  warning being emitted:

  ```heex
  <.button />
    <!-- warning: missing required slot "inner_block" for component MyAppWeb.MyComponent.button/1
             lib/app_web/my_component.ex:15 -->
  ```

  ### The Default Slot

  The example above uses the default slot, accessible as an assign named `@inner_block`, to render
  HEEx content via the `render_slot/2` function.

  If the values rendered in the slot need to be dynamic, you can pass a second value back to the
  HEEx content by calling `render_slot/2`:

      slot :inner_block, required: true

      attr :entries, :list, default: []

      def unordered_list(assigns) do
        ~H"""
        <ul>
          <%= for entry <- @entries do %>
            <li><%= render_slot(@inner_block, entry) %></li>
          <% end %>
        </ul>
        """
      end

  When invoking the function component, you can use the special attribute `:let` to take the value
  that the function component passes back and bind it to a variable:

  ```heex
  <.unordered_list :let={fruit} entries={~w(apples bananas cherries)}>
    I like <%= fruit %>!
  </.unordered_list>
  ```

  Rendering the following HTML:

  ```html
  <ul>
    <li>I like apples!</li>
    <li>I like bananas!</li>
    <li>I like cherries!</li>
  </ul>
  ```

  Now the separation of concerns is maintained: the caller can specify multiple values in a list
  attribute without having to specify the HEEx content that surrounds and separates them.

  ### Named Slots

  In addition to the default slot, function components can accept multiple, named slots of HEEx
  content. For example, imagine you want to create a modal that has a header, body, and footer:

      slot :header
      slot :inner_block, required: true
      slot :footer, required: true

      def modal(assigns) do
        ~H"""
        <div class="modal">
          <div class="modal-header">
            <%= render_slot(@header) || "Modal" %>
          </div>
          <div class="modal-body">
            <%= render_slot(@inner_block) %>
          </div>
          <div class="modal-footer">
            <%= render_slot(@footer) %>
          </div>
        </div>
        """
      end

  You can invoke this function component using the named slot HEEx syntax:

  ```heex
  <.modal>
    This is the body, everything not in a named slot is rendered in the default slot.
    <:footer>
      This is the bottom of the modal.
    </:footer>
  </.modal>
  ```

  Rendering the following HTML:

  ```html
  <div class="modal">
    <div class="modal-header">
      Modal.
    </div>
    <div class="modal-body">
      This is the body, everything not in a named slot is rendered in the default slot.
    </div>
    <div class="modal-footer">
      This is the bottom of the modal.
    </div>
  </div>
  ```

  As shown in the example above, `render_slot/1` returns `nil` when an optional slot
  is declared and none is given. This can be used to attach default behaviour.

  ### Slot Attributes

  Unlike the default slot, it is possible to pass a named slot multiple pieces of HEEx content.
  Named slots can also accept attributes, defined by passing a block to the `slot/3` macro.
  If multiple pieces of content are passed, `render_slot/2` will merge and render all the values.

  Below is a table component illustrating multiple named slots with attributes:

      slot :column, doc: "Columns with column labels" do
        attr :label, :string, required: true, doc: "Column label"
      end

      attr :rows, :list, default: []

      def table(assigns) do
        ~H"""
        <table>
          <tr>
            <%= for col <- @column do %>
              <th><%= col.label %></th>
            <% end %>
          </tr>
          <%= for row <- @rows do %>
            <tr>
              <%= for col <- @column do %>
                <td><%= render_slot(col, row) %></td>
              <% end %>
            </tr>
          <% end %>
        </table>
        """
      end

  You can invoke this function component like so:

  ```heex
  <.table rows={[%{name: "Jane", age: "34"}, %{name: "Bob", age: "51"}]}>
    <:column :let={user} label="Name">
      <%= user.name %>
    </:column>
    <:column :let={user} label="Age">
      <%= user.age %>
    </:column>
  </.table>
  ```

  Rendering the following HTML:

  ```html
  <table>
    <tr>
      <th>Name</th>
      <th>Age</th>
    </tr>
    <tr>
      <td>Jane</td>
      <td>34</td>
    </tr>
    <tr>
      <td>Bob</td>
      <td>51</td>
    </tr>
  </table>
  ```

  You can learn more about slots and the `slot/3` macro [in its documentation](`slot/3`).

  ### Embedding external template files

  The `embed_templates/1` macro can be used to embed `.html.heex` files
  as function components. The directory path is based on the current
  module (`__DIR__`), and a wildcard pattern may be used to select all
  files within a directory tree. For example, imagine a directory listing:

      ├── components.ex
      ├── pages
      │   ├── about_page.html.heex
      │   └── welcome_page.html.heex

  Then to embed the page templates in your `components.ex` moddule:

      defmodule MyAppWeb.Components do
        use Phoenix.Component

        embed_templates "page/*"
      end

  Now, your module will have an `about_page/1` and `welcome_page/1` function
  component defined. Embedded templates also support declarative assigns
  via bodyless function definitions, for example:

      defmodule MyAppWeb.Components do
        use Phoenix.Component

        embed_templates "page/*"

        attr :name, :string, required: true
        def welcome_page(assigns)

        slot :header
        def about_page(assigns)
      end
  '''

  ## Functions

  alias Phoenix.LiveView.{Static, Socket}
  @reserved_assigns Phoenix.Component.Declarative.__reserved__()
  @phoenix_embeds :phoenix_embeds

  @doc ~S'''
  The `~H` sigil for writing HEEx templates inside source files.

  > Note: The HEEx HTML formatter requires Elixir >= 1.13.4. See the
  > `Phoenix.LiveView.HTMLFormatter` for more information on template formatting.

  `HEEx` is a HTML-aware and component-friendly extension of Elixir Embedded
  language (`EEx`) that provides:

  * Built-in handling of HTML attributes.

  * An HTML-like notation for injecting function components.

  * Compile-time validation of the structure of the template.

  * The ability to minimize the amount of data sent over the wire.

  ## Example

      ~H"""
      <div title="My div" class={@class}>
        <p>Hello <%= @name %></p>
        <MyApp.Weather.city name="Kraków"/>
      </div>
      """

  ## Syntax

  `HEEx` is built on top of Embedded Elixir (`EEx`). In this section, we are going to
  cover the basic constructs in `HEEx` templates as well as its syntax extensions.

  ### Interpolation

  Both `HEEx` and `EEx` templates use `<%= ... %>` for interpolating code inside the body
  of HTML tags:

  ```heex
  <p>Hello, <%= @name %></p>
  ```

  Similarly, conditionals and other block Elixir constructs are supported:

  ```heex
  <%= if @show_greeting? do %>
    <p>Hello, <%= @name %></p>
  <% end %>
  ```

  Note we don't include the equal sign `=` in the closing `<% end %>` tag
  (because the closing tag does not output anything).

  There is one important difference between `HEEx` and Elixir's builtin `EEx`.
  `HEEx` uses a specific annotation for interpolating HTML tags and attributes.
  Let's check it out.

  ### HEEx extension: Defining attributes

  Since `HEEx` must parse and validate the HTML structure, code interpolation using
  `<%= ... %>` and `<% ... %>` are restricted to the body (inner content) of the
  HTML/component nodes and it cannot be applied within tags.

  For instance, the following syntax is invalid:

  ```heex
  <div class="<%= @class %>">
    ...
  </div>
  ```

  Instead do:

  ```heex
  <div class={@class}>
    ...
  </div>
  ```

  You can put any Elixir expression between `{ ... }`. For example, if you want
  to set classes, where some are static and others are dynamic, you can using
  string interpolation:

  ```heex
  <div class={"btn btn-#{@type}"}>
    ...
  </div>
  ```

  The following attribute values have special meaning:

  * `true` - if a value is `true`, the attribute is rendered with no value at all.
    For example, `<input required={true}>` is the same as `<input required>`;

  * `false` or `nil` - if a value is `false` or `nil`, the attribute is not rendered;

  * `list` (only for the `class` attribute) - each element of the list is processed
    as a different class. `nil` and `false` elements are discarded.

  For multiple dynamic attributes, you can use the same notation but without
  assigning the expression to any specific attribute.

  ```heex
  <div {@dynamic_attrs}>
    ...
  </div>
  ```

  The expression inside `{...}` must be either a keyword list or a map containing
  the key-value pairs representing the dynamic attributes.

  You can pair this notation `assigns_to_attributes/2` to strip out any internal
  LiveView attributes and user-defined assigns from being expanded into the HTML tag:

  ```heex
  <div {assigns_to_attributes(assigns, [:visible])}>
    ...
  </div>
  ```

  The above would add all caller attributes into the HTML, but strip out LiveView
  assigns like slots, as well as user-defined assigns like `:visible` that are not
  meant to be added to the HTML itself. This approach is useful to allow a component
  to accept arbitrary HTML attributes like class, ARIA attributes, etc.

  ### HEEx extension: Defining function components

  Function components are stateless components implemented as pure functions
  with the help of the `Phoenix.Component` module. They can be either local
  (same module) or remote (external module).

  `HEEx` allows invoking these function components directly in the template
  using an HTML-like notation. For example, a remote function:

  ```heex
  <MyApp.Weather.city name="Kraków"/>
  ```

  A local function can be invoked with a leading dot:

  ```heex
  <.city name="Kraków"/>
  ```

  where the component could be defined as follows:

      defmodule MyApp.Weather do
        use Phoenix.Component

        def city(assigns) do
          ~H"""
          The chosen city is: <%= @name %>.
          """
        end

        def country(assigns) do
          ~H"""
          The chosen country is: <%= @name %>.
          """
        end
      end

  It is typically best to group related functions into a single module, as
  opposed to having many modules with a single `render/1` function. Function
  components support other important features, such as slots. You can learn
  more about components in `Phoenix.Component`.

  ### HEEx extension: special attributes

  Apart from normal HTML attributes, HEEx also support some special attributes
  such as `:let` and `:for`.

  #### :let

  This is used by components and slots that want to yield a value back to the
  caller. For an example, see how `form/1` works:

  ```heex
  <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save">
    <%= label(f, :username) %>
    <%= text_input(f, :username) %>
    ...
  </.form>
  ```

  Notice how the variable `f`, defined by `.form`, is used by `label` and
  `text_input`. The `Phoenix.Component` module has detailed documentation on
  how to use and implement such functionality.

  #### :if and :for

  It is a syntax sugar for `<%= if .. do %>` and `<%= for .. do %>` that can be
  used in regular HTML, function components, and slots.

  For example in an HTML tag:

  ```heex
  <table id="admin-table" :if={@admin?}>
    <tr :for={user <- @users}>
      <td><%= user.name %>
    </tr>
  <table>
  ```

  The snippet above will only render the table if `@admin?` is true,
  and generate a `tr` per user as you would expect from the collection.

  `:for` can be used similarly in function components:

  ```heex
  <.error :for={msg <- @errors} message={msg}/>
  ```

  Which is equivalent to writing:

  ```heex
  <%= for msg <- @errors do %>
    <.error message={msg} />
  <% end %>
  ```

  And `:for` in slots behaves the same way:

  ```heex
  <.table id="my-table" rows={@users}>
    <:col :for={header <- @headers} let={user}>
      <td><%= user[:header] %></td>
    </:col>
  <table>
  ```

  You can also combine `:for` and `:if` for tags, components, and slot to act as a filter:

  ```heex
  <.error :for={msg <- @errors} :if={msg != nil} message={msg} />
  ```
  '''
  defmacro sigil_H({:<<>>, meta, [expr]}, []) do
    unless Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      raise "~H requires a variable named \"assigns\" to exist and be set to a map"
    end

    options = [
      engine: Phoenix.LiveView.HTMLEngine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      caller: __CALLER__,
      indentation: meta[:indentation] || 0
    ]

    EEx.compile_string(expr, options)
  end

  @doc ~S'''
  Filters the assigns as a list of keywords for use in dynamic tag attributes.

  Useful for transforming caller assigns into dynamic attributes while
  stripping reserved keys from the result.

  ## Examples

  Imagine the following `my_link` component which allows a caller
  to pass a `new_window` assign, along with any other attributes they
  would like to add to the element, such as class, data attributes, etc:

  ```heex
  <.my_link href="/" id={@id} new_window={true} class="my-class">Home</.my_link>
  ```

  We could support the dynamic attributes with the following component:

      def my_link(assigns) do
        target = if assigns[:new_window], do: "_blank", else: false
        extra = assigns_to_attributes(assigns, [:new_window])

        assigns =
          assigns
          |> assign(:target, target)
          |> assign(:extra, extra)

        ~H"""
        <a href={@href} target={@target} {@extra}>
          <%= render_slot(@inner_block) %>
        </a>
        """
      end

  The above would result in the following rendered HTML:

  ```heex
  <a href="/" target="_blank" id="1" class="my-class">Home</a>
  ```

  The second argument (optional) to `assigns_to_attributes` is a list of keys to
  exclude. It typically includes reserved keys by the component itself, which either
  do not belong in the markup, or are already handled explicitly by the component.
  '''
  def assigns_to_attributes(assigns, exclude \\ []) do
    excluded_keys = @reserved_assigns ++ exclude
    for {key, val} <- assigns, key not in excluded_keys, into: [], do: {key, val}
  end

  @doc """
  Renders a LiveView within a template.

  This is useful in two situations:

  * When rendering a child LiveView inside a LiveView.

  * When rendering a LiveView inside a regular (non-live) controller/view.

  ## Options

  * `:session` - a map of binary keys with extra session data to be serialized and sent
  to the client. All session data currently in the connection is automatically available
  in LiveViews. You can use this option to provide extra data. Remember all session data is
  serialized and sent to the client, so you should always keep the data in the session
  to a minimum. For example, instead of storing a User struct, you should store the "user_id"
  and load the User when the LiveView mounts.

  * `:container` - an optional tuple for the HTML tag and DOM attributes to be used for the
  LiveView container. For example: `{:li, style: "color: blue;"}`. By default it uses the module
  definition container. See the "Containers" section below for more information.

  * `:id` - both the DOM ID and the ID to uniquely identify a LiveView. An `:id` is
  automatically generated when rendering root LiveViews but it is a required option when
  rendering a child LiveView.

  * `:sticky` - an optional flag to maintain the LiveView across live redirects, even if it is
  nested within another LiveView. If you are rendering the sticky view within your live layout,
  make sure that the sticky view itself does not use the same layout. You can do so by returning
  `{:ok, socket, layout: false}` from mount.

  ## Examples

  When rendering from a controller/view, you can call:

  ```heex
  <%= live_render(@conn, MyApp.ThermostatLive) %>
  ```

  Or:

  ```heex
  <%= live_render(@conn, MyApp.ThermostatLive, session: %{"home_id" => @home.id}) %>
  ```

  Within another LiveView, you must pass the `:id` option:

  ```heex
  <%= live_render(@socket, MyApp.ThermostatLive, id: "thermostat") %>
  ```

  ## Containers

  When a `LiveView` is rendered, its contents are wrapped in a container. By default,
  the container is a `div` tag with a handful of `LiveView` specific attributes.

  The container can be customized in different ways:

  * You can change the default `container` on `use Phoenix.LiveView`:

        use Phoenix.LiveView, container: {:tr, id: "foo-bar"}

  * You can override the container tag and pass extra attributes when calling `live_render`
  (as well as on your `live` call in your router):

        live_render socket, MyLiveView, container: {:tr, class: "highlight"}

  """
  def live_render(conn_or_socket, view, opts \\ [])

  def live_render(%Plug.Conn{} = conn, view, opts) do
    case Static.render(conn, view, opts) do
      {:ok, content, _assigns} ->
        content

      {:stop, _} ->
        raise RuntimeError, "cannot redirect from a child LiveView"
    end
  end

  def live_render(%Socket{} = parent, view, opts) do
    Static.nested_render(parent, view, opts)
  end

  @doc ~S'''
  Renders a slot entry with the given optional `argument`.

  ```heex
  <%= render_slot(@inner_block, @form) %>
  ```

  If the slot has no entries, nil is returned.

  If multiple slot entries are defined for the same slot,`render_slot/2` will automatically render
  all entries, merging their contents. In case you want to use the entries' attributes, you need
  to iterate over the list to access each slot individually.

  For example, imagine a table component:

  ```heex
  <.table rows={@users}>
    <:col :let={user} label="Name">
      <%= user.name %>
    </:col>

    <:col :let={user} label="Address">
      <%= user.address %>
    </:col>
  </.table>
  ```

  At the top level, we pass the rows as an assign and we define a `:col` slot for each column we
  want in the table. Each column also has a `label`, which we are going to use in the table header.

  Inside the component, you can render the table with headers, rows, and columns:

      def table(assigns) do
        ~H"""
        <table>
          <tr>
            <%= for col <- @col do %>
              <th><%= col.label %></th>
            <% end %>
          </tr>
          <%= for row <- @rows do %>
            <tr>
              <%= for col <- @col do %>
                <td><%= render_slot(col, row) %></td>
              <% end %>
            </tr>
          <% end %>
        </table>
        """
      end

  '''
  defmacro render_slot(slot, argument \\ nil) do
    quote do
      unquote(__MODULE__).__render_slot__(
        var!(changed, Phoenix.LiveView.Engine),
        unquote(slot),
        unquote(argument)
      )
    end
  end

  @doc false
  def __render_slot__(_, [], _), do: nil

  def __render_slot__(changed, [entry], argument) do
    call_inner_block!(entry, changed, argument)
  end

  def __render_slot__(changed, entries, argument) when is_list(entries) do
    assigns = %{entries: entries, changed: changed, argument: argument}

    ~H"""
    <%= for entry <- @entries do %><%= call_inner_block!(entry, @changed, @argument) %><% end %>
    """
  end

  def __render_slot__(changed, entry, argument) when is_map(entry) do
    entry.inner_block.(changed, argument)
  end

  defp call_inner_block!(entry, changed, argument) do
    if !entry.inner_block do
      message = "attempted to render slot <:#{entry.__slot__}> but the slot has no inner content"
      raise RuntimeError, message
    end

    entry.inner_block.(changed, argument)
  end

  @doc """
  Returns the flash message from the LiveView flash assign.

  ## Examples

  ```heex
  <p class="alert alert-info"><%= live_flash(@flash, :info) %></p>
  <p class="alert alert-danger"><%= live_flash(@flash, :error) %></p>
  ```
  """
  @doc deprecated: "Use Phoenix.Flash.get/2 in Phoenix v1.7+"
  def live_flash(%_struct{} = other, _key) do
    raise ArgumentError, "live_flash/2 expects a @flash assign, got: #{inspect(other)}"
  end

  def live_flash(%{} = flash, key), do: Map.get(flash, to_string(key))

  @doc """
  Returns the entry errors for an upload.

  The following error may be returned:

  * `:too_many_files` - The number of selected files exceeds the `:max_entries` constraint

  ## Examples

      def error_to_string(:too_many_files), do: "You have selected too many files"

  ```heex
  <%= for err <- upload_errors(@uploads.avatar) do %>
    <div class="alert alert-danger">
      <%= error_to_string(err) %>
    </div>
  <% end %>
  ```
  """
  def upload_errors(%Phoenix.LiveView.UploadConfig{} = conf) do
    for {ref, error} <- conf.errors, ref == conf.ref, do: error
  end

  @doc """
  Returns the entry errors for an upload.

  The following errors may be returned:

  * `:too_large` - The entry exceeds the `:max_file_size` constraint
  * `:not_accepted` - The entry does not match the `:accept` MIME types

  ## Examples

      def error_to_string(:too_large), do: "Too large"
      def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  ```heex
  <%= for entry <- @uploads.avatar.entries do %>
    <%= for err <- upload_errors(@uploads.avatar, entry) do %>
      <div class="alert alert-danger">
        <%= error_to_string(err) %>
      </div>
    <% end %>
  <% end %>
  ```
  """
  def upload_errors(
        %Phoenix.LiveView.UploadConfig{} = conf,
        %Phoenix.LiveView.UploadEntry{} = entry
      ) do
    for {ref, error} <- conf.errors, ref == entry.ref, do: error
  end

  @doc ~S'''
  Assigns the given `key` with value from `fun` into `socket_or_assigns` if one does not yet exist.

  The first argument is either a LiveView `socket` or an `assigns` map from function components.

  This function is useful for lazily assigning values and referencing parent assigns.
  We will cover both use cases next.

  ## Lazy assigns

  Imagine you have a function component that accepts a color:

  ```heex
  <.my_component color="red" />
  ```

  The color is also optional, so you can skip it:

  ```heex
  <.my_component />
  ```

  In such cases, the implementation can use `assign_new` to lazily
  assign a color if none is given. Let's make it so it picks a random one
  when none is given:

      def my_component(assigns) do
        assigns = assign_new(assigns, :color, fn -> Enum.random(~w(red green blue)) end)

        ~H"""
        <div class={"bg-#{@color}"}>
          Example
        </div>
        """
      end

  ## Referencing parent assigns

  When a user first accesses an application using LiveView, the LiveView is first rendered in its
  disconnected state, as part of a regular HTML response. In some cases, there may be data that is
  shared by your Plug pipelines and your LiveView, such as the `:current_user` assign.

  By using `assign_new` in the mount callback of your LiveView, you can instruct LiveView to
  re-use any assigns set in your Plug pipelines as part of `Plug.Conn`, avoiding sending additional
  queries to the database. Imagine you have a Plug that does:

      # A plug
      def authenticate(conn, _opts) do
        if user_id = get_session(conn, :user_id) do
          assign(conn, :current_user, Accounts.get_user!(user_id))
        else
          send_resp(conn, :forbidden)
        end
      end

  You can re-use the `:current_user` assign in your LiveView during the initial render:

      def mount(_params, %{"user_id" => user_id}, socket) do
        {:ok, assign_new(socket, :current_user, fn -> Accounts.get_user!(user_id) end)}
      end

  In such case `conn.assigns.current_user` will be used if present. If there is no such
  `:current_user` assign or the LiveView was mounted as part of the live navigation, where no Plug
  pipelines are invoked, then the anonymous function is invoked to execute the query instead.

  LiveView is also able to share assigns via `assign_new` within nested LiveView. If the parent
  LiveView defines a `:current_user` assign and the child LiveView also uses `assign_new/3` to
  fetch the `:current_user` in its `mount/3` callback, as above, the assign will be fetched from
  the parent LiveView, once again avoiding additional database queries.

  Note that `fun` also provides access to the previously assigned values:

      assigns =
          assigns
          |> assign_new(:foo, fn -> "foo" end)
          |> assign_new(:bar, fn %{foo: foo} -> foo <> "bar" end)
  '''
  def assign_new(socket_or_assigns, key, fun)

  def assign_new(%Socket{} = socket, key, fun) when is_function(fun, 1) do
    validate_assign_key!(key)

    case socket do
      %{assigns: %{^key => _}} ->
        socket

      %{private: %{assign_new: {assigns, keys}}} ->
        # It is important to store the keys even if they are not in assigns
        # because maybe the controller doesn't have it but the view does.
        socket = put_in(socket.private.assign_new, {assigns, [key | keys]})

        Phoenix.LiveView.Utils.force_assign(
          socket,
          key,
          case assigns do
            %{^key => value} -> value
            %{} -> fun.(socket.assigns)
          end
        )

      %{assigns: assigns} ->
        Phoenix.LiveView.Utils.force_assign(socket, key, fun.(assigns))
    end
  end

  def assign_new(%Socket{} = socket, key, fun) when is_function(fun, 0) do
    validate_assign_key!(key)

    case socket do
      %{assigns: %{^key => _}} ->
        socket

      %{private: %{assign_new: {assigns, keys}}} ->
        # It is important to store the keys even if they are not in assigns
        # because maybe the controller doesn't have it but the view does.
        socket = put_in(socket.private.assign_new, {assigns, [key | keys]})
        Phoenix.LiveView.Utils.force_assign(socket, key, Map.get_lazy(assigns, key, fun))

      %{} ->
        Phoenix.LiveView.Utils.force_assign(socket, key, fun.())
    end
  end

  def assign_new(%{__changed__: changed} = assigns, key, fun) when is_function(fun, 1) do
    case assigns do
      %{^key => _} -> assigns
      %{} -> Phoenix.LiveView.Utils.force_assign(assigns, changed, key, fun.(assigns))
    end
  end

  def assign_new(%{__changed__: changed} = assigns, key, fun) when is_function(fun, 0) do
    case assigns do
      %{^key => _} -> assigns
      %{} -> Phoenix.LiveView.Utils.force_assign(assigns, changed, key, fun.())
    end
  end

  def assign_new(assigns, _key, fun) when is_function(fun, 0) or is_function(fun, 1) do
    raise_bad_socket_or_assign!("assign_new/3", assigns)
  end

  defp raise_bad_socket_or_assign!(name, assigns) do
    extra =
      case assigns do
        %_{} ->
          ""

        %{} ->
          """
          You passed an assigns map that does not have the relevant change tracking \
          information. This typically means you are calling a function component by \
          hand instead of using the HEEx template syntax. If you are using HEEx, make \
          sure you are calling a component using:

              <.component attribute={value} />

          If you are outside of HEEx and you want to test a component, use \
          Phoenix.LiveViewTest.render_component/2:

              Phoenix.LiveViewTest.render_component(&component/1, attribute: "value")

          """

        _ ->
          ""
      end

    raise ArgumentError,
          "#{name} expects a socket from Phoenix.LiveView/Phoenix.LiveComponent " <>
            " or an assigns map from Phoenix.Component as first argument, got: " <>
            inspect(assigns) <> extra
  end

  @doc """
  Adds a `key`-`value` pair to `socket_or_assigns`.

  The first argument is either a LiveView `socket` or an `assigns` map from function components.

  ## Examples

      iex> assign(socket, :name, "Elixir")

  """
  def assign(socket_or_assigns, key, value)

  def assign(%Socket{} = socket, key, value) do
    validate_assign_key!(key)
    Phoenix.LiveView.Utils.assign(socket, key, value)
  end

  def assign(%{__changed__: changed} = assigns, key, value) do
    case assigns do
      %{^key => ^value} ->
        assigns

      %{} ->
        Phoenix.LiveView.Utils.force_assign(assigns, changed, key, value)
    end
  end

  def assign(assigns, _key, _val) do
    raise_bad_socket_or_assign!("assign/3", assigns)
  end

  @doc """
  Adds key-value pairs to assigns.

  The first argument is either a LiveView `socket` or an `assigns` map from function components.

  A keyword list or a map of assigns must be given as argument to be merged into existing assigns.

  ## Examples

      iex> assign(socket, name: "Elixir", logo: "💧")
      iex> assign(socket, %{name: "Elixir"})

  """
  def assign(socket_or_assigns, keyword_or_map)
      when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign(acc, key, value)
    end)
  end

  defp validate_assign_key!(:flash) do
    raise ArgumentError,
          ":flash is a reserved assign by LiveView and it cannot be set directly. " <>
            "Use the appropriate flash functions instead."
  end

  defp validate_assign_key!(_key), do: :ok

  @doc """
  Updates an existing `key` with `fun` in the given `socket_or_assigns`.

  The first argument is either a LiveView `socket` or an `assigns` map from function components.

  The update function receives the current key's value and returns the updated value.
  Raises if the key does not exist.

  The update function may also be of arity 2, in which case it receives the current key's value
  as the first argument and the current assigns as the second argument.
  Raises if the key does not exist.

  ## Examples

      iex> update(socket, :count, fn count -> count + 1 end)
      iex> update(socket, :count, &(&1 + 1))
      iex> update(socket, :max_users_this_session, fn current_max, %{users: users} ->
             max(current_max, length(users))
           end)
  """
  def update(socket_or_assigns, key, fun)

  def update(%Socket{assigns: assigns} = socket, key, fun) when is_function(fun, 2) do
    update(socket, key, &fun.(&1, assigns))
  end

  def update(%Socket{assigns: assigns} = socket, key, fun) when is_function(fun, 1) do
    case assigns do
      %{^key => val} -> assign(socket, key, fun.(val))
      %{} -> raise KeyError, key: key, term: assigns
    end
  end

  def update(assigns, key, fun) when is_function(fun, 2) do
    update(assigns, key, &fun.(&1, assigns))
  end

  def update(assigns, key, fun) when is_function(fun, 1) do
    case assigns do
      %{^key => val} -> assign(assigns, key, fun.(val))
      %{} -> raise KeyError, key: key, term: assigns
    end
  end

  def update(assigns, _key, fun) when is_function(fun, 1) or is_function(fun, 2) do
    raise_bad_socket_or_assign!("update/3", assigns)
  end

  @doc """
  Checks if the given key changed in `socket_or_assigns`.

  The first argument is either a LiveView `socket` or an `assigns` map from function components.

  ## Examples

      iex> changed?(socket, :count)

  """
  def changed?(socket_or_assigns, key)

  def changed?(%Socket{assigns: assigns}, key) do
    Phoenix.LiveView.Utils.changed?(assigns, key)
  end

  def changed?(%{__changed__: _} = assigns, key) do
    Phoenix.LiveView.Utils.changed?(assigns, key)
  end

  def changed?(assigns, _key) do
    raise_bad_socket_or_assign!("changed?/2", assigns)
  end

  defmacro embed_templates(pattern, opts \\ []) do
    quote do
        Phoenix.Template.compile_all(
          &Phoenix.Component.__embed__/1,
          unquote(opts)[:root] || __DIR__,
          unquote(pattern)
        )
    end
  end
  end

  ## Declarative assigns API

  @doc false
  defmacro __using__(opts \\ []) do
    Module.register_attribute(__CALLER__.module, @phoenix_embeds, accumulate: true)
    conditional =
      if __CALLER__.module != Phoenix.LiveView.Helpers do
        quote do: import(Phoenix.LiveView.Helpers)
      end

    imports =
      quote bind_quoted: [opts: opts] do
        import Kernel, except: [def: 2, defp: 2]
        import Phoenix.Component
        import Phoenix.Component.Declarative
        @before_compile Phoenix.Component
        use Phoenix.Template

        for {prefix_match, value} <- Phoenix.Component.Declarative.__setup__(__MODULE__, opts) do
          @doc false
          def __global__?(unquote(prefix_match)), do: unquote(value)
        end
      end

    [conditional, imports]
  end

  defmacro __before_compile__(_env) do
    quote do
      templates =
        for {root, pattern} <- @phoenix_embeds do
          converter = &(&1 |> Path.basename() |> Path.rootname(".html.heex"))
          Phoenix.Template.compile_all(converter, root, pattern)
        end

      @phoenix_component_embedded templates
      def __templates__, do: @phoenix_component_embedded
    end
  end

  @doc ~S'''
  Declares a function component slot.

  ## Arguments

  * `name` - an atom defining the name of the slot. Note that slots cannot define the same name
  as any other slots or attributes declared for the same component.

  * `opts` - a keyword list of options. Defaults to `[]`.

  * `block` - a code block containing calls to `attr/3`. Defaults to `nil`.

  ### Options

  * `:required` - marks a slot as required. If a caller does not pass a value for a required slot,
  a compilation warning is emitted. Otherwise, an omitted slot will default to `[]`.

  * `:doc` - documentation for the slot. Any slot attributes declared
  will have their documentation listed alongside the slot.

  ### Slot Attributes

  A named slot may declare attributes by passing a block with calls to `attr/3`.

  Unlike attributes, slot attributes cannot accept the `:default` option. Passing one
  will result in a compile warning being issued.

  ### The Default Slot

  The default slot can be declared by passing `:inner_block` as the `name` of the slot.

  Note that the `:inner_block` slot declaration cannot accept a block. Passing one will
  result in a compilation error.

  ## Compile-Time Validations

  LiveView performs some validation of slots via the `:phoenix_live_view` compiler.
  When slots are defined, LiveView will warn at compilation time on the caller if:

  * A required slot of a component is missing.

  * An unknown slot is given.

  * An unknown slot attribute is given.

  On the side of the function component itself, defining attributes provides the following
  quality of life improvements:

  * Slot documentation is generated for the component.

  * Calls made to the component are tracked for reflection and validation purposes.

  ## Documentation Generation

  Public function components that define slots will have their docs injected into the function's
  documentation, depending on the value of the `@doc` module attribute:

  * if `@doc` is a string, the slot docs are injected into that string. The optional placeholder
  `[INSERT LVATTRDOCS]` can be used to specify where in the string the docs are injected.
  Otherwise, the docs are appended to the end of the `@doc` string.

  * if `@doc` is unspecified, the slot docs are used as the default `@doc` string.

  * if `@doc` is `false`, the slot docs are omitted entirely.

  The injected slot docs are formatted as a markdown list:

    * `name` (required) - slot docs. Accepts attributes:
      * `name` (`:type`) (required) - attr docs. Defaults to `:default`.

  By default, all slots will have their docs injected into the function `@doc` string.
  To hide a specific slot, you can set the value of `:doc` to `false`.

  ## Example

      slot :header
      slot :inner_block, required: true
      slot :footer

      def modal(assigns) do
        ~H"""
        <div class="modal">
          <div class="modal-header">
            <%= render_slot(@header) || "Modal" %>
          </div>
          <div class="modal-body">
            <%= render_slot(@inner_block) %>
          </div>
          <div class="modal-footer">
            <%= render_slot(@footer) || submit_button() %>
          </div>
        </div>
        """
      end

  As shown in the example above, `render_slot/1` returns `nil` when an optional slot is declared
  and none is given. This can be used to attach default behaviour.
  '''
  defmacro slot(name, opts, block)

  defmacro slot(name, opts, do: block) when is_atom(name) and is_list(opts) do
    quote do
      Phoenix.Component.Declarative.__slot__!(
        __MODULE__,
        unquote(name),
        unquote(opts),
        __ENV__.line,
        __ENV__.file,
        fn -> unquote(block) end
      )
    end
  end

  @doc """
  Declares a slot. See `slot/3` for more information.
  """
  defmacro slot(name, opts \\ []) when is_atom(name) and is_list(opts) do
    {block, opts} = Keyword.pop(opts, :do, nil)

    quote do
      Phoenix.Component.Declarative.__slot__!(
        __MODULE__,
        unquote(name),
        unquote(opts),
        __ENV__.line,
        __ENV__.file,
        fn -> unquote(block) end
      )
    end
  end

  @doc ~S'''
  Declares attributes for a HEEx function components.

  ## Arguments

  * `name` - an atom defining the name of the attribute. Note that attributes cannot define the
  same name as any other attributes or slots declared for the same component.

  * `type` - an atom defining the type of the attribute.

  * `opts` - a keyword list of options. Defaults to `[]`.

  ### Types

  An attribute is declared by its name, type, and options. The following types are supported:

  | Name            | Description                                                          |
  |-----------------|----------------------------------------------------------------------|
  | `:any`          | any term                                                             |
  | `:string`       | any binary string                                                    |
  | `:atom`         | any atom (including `true`, `false`, and `nil`)                      |
  | `:boolean`      | any boolean                                                          |
  | `:integer`      | any integer                                                          |
  | `:float`        | any float                                                            |
  | `:list`         | any list of any arbitrary types                                      |
  | `:global`       | any common HTML attributes, plus those defined by `:global_prefixes` |
  | A struct module | any module that defines a struct with `defstruct/1`                  |

  ### Options

  * `:required` - marks an attribute as required. If a caller does not pass the given attribute,
  a compile warning is issued.

  * `:default` - the default value for the attribute if not provided. If this option is
    not set and the attribute is not given, accessing the attribute will fail unless a
    value is explicitly set with `assign_new/3`.

  * `:examples` - a non-exhaustive list of values accepted by the attribute, used for documentation
    purposes.

  * `:values` - an exhaustive list of values accepted by the attributes. If a caller passes a literal
    not contained in this list, a compile warning is issued.

  * `:doc` - documentation for the attribute.

  ## Compile-Time Validations

  LiveView performs some validation of attributes via the `:phoenix_live_view` compiler.
  When attributes are defined, LiveView will warn at compilation time on the caller if:

  * A required attribute of a component is missing.

  * An unknown attribute is given.

  * You specify a literal attribute (such as `value="string"` or `value`, but not `value={expr}`)
  and the type does not match. The following types currently support literal validation:
  `:string`, `:atom`, `:boolean`, `:integer`, `:float`, and `:list`.

  * You specify a literal attribute and it is not a member of the `:values` list.

  LiveView does not perform any validation at runtime. This means the type information is mostly
  used for documentation and reflection purposes.

  On the side of the LiveView component itself, defining attributes provides the following quality
  of life improvements:

  * The default value of all attributes will be added to the `assigns` map upfront. Note that
  unless an attribute is marked as required or has a default defined, omitting a value for an
  attribute will result in `nil` being passed as the default value to the `assigns` map,
  regardless of the type defined for the attribute.

  * Attribute documentation is generated for the component.

  * Required struct types are annotated and emit compilation warnings. For example, if you specify
  `attr :user, User, required: true` and then you write `@user.non_valid_field` in your template,
  a warning will be emitted.

  * Calls made to the component are tracked for reflection and validation purposes.

  ## Documentation Generation

  Public function components that define attributes will have their attribute
  types and docs injected into the function's documentation, depending on the
  value of the `@doc` module attribute:

  * if `@doc` is a string, the attribute docs are injected into that string. The optional
  placeholder `[INSERT LVATTRDOCS]` can be used to specify where in the string the docs are
  injected. Otherwise, the docs are appended to the end of the `@doc` string.

  * if `@doc` is unspecified, the attribute docs are used as the default `@doc` string.

  * if `@doc` is `false`, the attribute docs are omitted entirely.

  The injected attribute docs are formatted as a markdown list:

    * `name` (`:type`) (required) - attr docs. Defaults to `:default`.

  By default, all attributes will have their types and docs injected into the function `@doc`
  string. To hide a specific attribute, you can set the value of `:doc` to `false`.

  ## Example

      attr :name, :string, required: true
      attr :age, :integer, required: true

      def celebrate(assigns) do
        ~H"""
        <p>
          Happy birthday <%= @name %>!
          You are <%= @age %> years old.
        </p>
        """
      end
  '''
  defmacro attr(name, type, opts \\ []) when is_atom(name) and is_list(opts) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      Phoenix.Component.Declarative.__attr__!(
        __MODULE__,
        name,
        type,
        opts,
        __ENV__.line,
        __ENV__.file
      )
    end
  end

  ## Components

  # TODO: Insert docs for components

  import Kernel, except: [def: 2, defp: 2]
  import Phoenix.Component.Declarative
  alias Phoenix.Component.Declarative

  # We need to bootstrap by hand to avoid conflicts.
  [] = Declarative.__setup__(__MODULE__, [])

  attr = fn name, type, opts ->
    Declarative.__attr__!(__MODULE__, name, type, opts, __ENV__.line, __ENV__.file)
  end

  slot = fn name, opts ->
    Declarative.__slot__!(__MODULE__, name, opts, __ENV__.line, __ENV__.file, fn -> nil end)
  end

  @doc """
  A function component for rendering `Phoenix.LiveComponent` within a parent LiveView.

  While `LiveView`s can be nested, each LiveView starts its own process. A `LiveComponent` provides
  similar functionality to `LiveView`, except they run in the same process as the `LiveView`,
  with its own encapsulated state. That's why they are called stateful components.

  ## Attributes

  * `id` (`:string`) (required) - A unique identifier for the LiveComponent. Note the `id` won't
  necessarily be used as the DOM `id`. That is up to the component to decide.

  * `module` (`:atom`) (required) - The LiveComponent module to render.

  Any additional attributes provided will be passed to the LiveComponent as a map of assigns.
  See `Phoenix.LiveComponent` for more information.

  ## Examples

  ```heex
  <.live_component module={MyApp.WeatherComponent} id="thermostat" city="Kraków" />
  ```
  """
  @doc type: :component
  def live_component(assigns)

  # TODO: add declarative attrs once we support non-global dynamic attrs
  def live_component(assigns) when is_map(assigns) do
    id = assigns[:id]

    {module, assigns} =
      assigns
      |> Map.delete(:__changed__)
      |> Map.pop(:module)

    if module == nil or not is_atom(module) do
      raise ArgumentError,
            ".live_component expects module={...} to be given and to be an atom, " <>
              "got: #{inspect(module)}"
    end

    if id == nil do
      raise ArgumentError, ".live_component expects id={...} to be given, got: nil"
    end

    case module.__live__() do
      %{kind: :component} ->
        %Phoenix.LiveView.Component{id: id, assigns: assigns, component: module}

      %{kind: kind} ->
        raise ArgumentError, "expected #{inspect(module)} to be a component, but it is a #{kind}"
    end
  end

  def live_component(component) when is_atom(component) do
    IO.warn(
      "<%= live_component Component %> is deprecated, " <>
        "please use <.live_component module={Component} id=\"hello\" /> inside HEEx templates instead"
    )

    Phoenix.LiveView.Helpers.__live_component__(component.__live__(), %{}, nil)
  end

  @doc """
  Renders a title with automatic prefix/suffix on `@page_title` updates.

  [INSERT LVATTRDOCS]

  ## Examples

  ```heex
  <.live_title prefix="MyApp – ">
    <%= assigns[:page_title] || "Welcome" %>
  </.live_title>
  ```

  ```heex
  <.live_title suffix="- MyApp">
    <%= assigns[:page_title] || "Welcome" %>
  </.live_title>
  ```
  """
  @doc type: :component
  attr.(:prefix, :string, default: nil, doc: "A prefix added before the content of `inner_block`.")

  attr.(:suffix, :string, default: nil, doc: "A suffix added after the content of `inner_block`.")
  slot.(:inner_block, required: true, doc: "Content rendered inside the `title` tag.")

  def live_title(assigns) do
    ~H"""
    <title data-prefix={@prefix} data-suffix={@suffix}><%= @prefix %><%= render_slot(@inner_block) %><%= @suffix %></title>
    """
  end

  @doc """
  Renders a form.

  [INSERT LVATTRDOCS]

  This function is built on top of `Phoenix.HTML.Form.form_for/4`.

  For more information about  options and how to build inputs, see `Phoenix.HTML.Form`.

  ## Examples

  ### Inside LiveView

  The `:for` attribute is typically an
  [`Ecto.Changeset`](https://hexdocs.pm/ecto/Ecto.Changeset.html):

  ```heex
  <.form
    :let={f}
    for={@changeset}
    phx-change="change_name"
  >
    <%= text_input f, :name %>
  </.form>

  <.form
    :let={user_form}
    for={@changeset}
    multipart
    phx-change="change_user"
    phx-submit="save_user"
  >
    <%= text_input user_form, :name %>
    <%= submit "Save" %>
  </.form>
  ```

  Notice how both examples use `phx-change`. The LiveView must implement the `phx-change` event
  and store the input values as they arrive on change. This is important because, if an unrelated
  change happens on the page, LiveView should re-render the inputs with their updated values.
  Without `phx-change`, the inputs would otherwise be cleared. Alternatively, you can use
  `phx-update="ignore"` on the form to discard any updates.

  The `:for` attribute can also be an atom, in case you don't have an existing data layer but you
  want to use the existing form helpers. In this case, you need to pass the input values explicitly
   as they change (or use `phx-update="ignore"` as per the previous paragraph):

  ```heex
  <.form :let={user_form} for={:user} multipart phx-change="change_user" phx-submit="save_user">
    <%= text_input user_form, :name, value: @user_name %>
    <%= submit "Save" %>
  </.form>
  ```

  In those cases, it may be more straight-forward to drop `:let` altogether and simply rely on
  HTML to generate inputs:

  ```heex
  <.form for={:form} multipart phx-change="change_user" phx-submit="save_user">
    <input type="text" name="user[name]" value={@user_name}>
    <input type="submit" name="Save">
  </.form>
  ```

  ### Outside LiveView

  The `form` component can still be used to submit forms outside of LiveView. In such cases, the
  `action` attribute MUST be given. Without said attribute, the `form` method and csrf token are
  discarded.

  ```heex
  <.form :let={f} for={@changeset} action={Routes.comment_path(:create, @comment)}>
    <%= text_input f, :body %>
  </.form>
  ```
  """
  @doc type: :component
  attr.(:for, :any, required: true, doc: "The form source data.")

  attr.(:action, :string,
    default: nil,
    doc: """
    The action to submit the form on.
    This attribute must be given if you intend to submit the form to a URL without LiveView.
    """
  )

  attr.(:as, :atom,
    default: nil,
    doc: """
    The server side parameter in which all params for this form
    will be collected (i.e. `as: :user_params` would mean all fields for this form will be
    accessed as `conn.params.user_params` server side).
    Automatically inflected when a changeset is given.
    """
  )

  attr.(:multipart, :boolean,
    default: false,
    doc: """
    Sets `enctype` to `multipart/form-data`.
    Required when uploading files.
    """
  )

  attr.(:method, :string,
    doc: """
    The HTTP method.
    It is only used if an `:action` is given. If the method is not `get` nor `post`,
    an input tag with name `_method` is generated alongside the form tag.
    """
  )

  attr.(:csrf_token, :any,
    doc: """
    A token to authenticate the validity of requests.
    One is automatically generated when an action is given and the method is not `get`.
    When set to `false`, no token is generated.
    """
  )

  attr.(:errors, :list,
    default: [],
    doc: """
    Use this to manually pass a keyword list of errors to the form,
    e.g. `conn.assigns[:errors]`. This option is only used when a connection is used as the form
    source and it will make the errors available under `f.errors`.
    """
  )

  attr.(:rest, :global,
    include: ~w(autocomplete name rel enctype novalidate target),
    doc: "Additional HTML attributes to add to the form tag."
  )

  slot.(:inner_block, required: true, doc: "The content rendered inside of the form tag.")

  def form(assigns) do
    # Extract options and then to the same call as form_for
    action = assigns[:action]
    form_for = assigns[:for] || raise ArgumentError, "missing :for assign to form"
    form_options = assigns_to_attributes(Map.merge(assigns, assigns.rest), [:action, :for, :rest])

    # Since FormData may add options, read the actual options from form
    %{options: opts} =
      form = %Phoenix.HTML.Form{
        Phoenix.HTML.FormData.to_form(form_for, form_options)
        | action: action || "#"
      }

    # By default, we will ignore action, method, and csrf token
    # unless the action is given.
    {attrs, hidden_method, csrf_token} =
      if action do
        {method, opts} = Keyword.pop(opts, :method)
        {method, hidden_method} = form_method(method)

        {csrf_token, opts} =
          Keyword.pop_lazy(opts, :csrf_token, fn ->
            if method == "post" do
              Plug.CSRFProtection.get_csrf_token_for(action)
            end
          end)

        {[action: action, method: method] ++ opts, hidden_method, csrf_token}
      else
        {opts, nil, nil}
      end

    attrs =
      case Keyword.pop(attrs, :multipart, false) do
        {false, attrs} -> attrs
        {true, attrs} -> Keyword.put(attrs, :enctype, "multipart/form-data")
      end

    assigns =
      assign(assigns,
        form: form,
        csrf_token: csrf_token,
        hidden_method: hidden_method,
        attrs: attrs
      )

    ~H"""
    <form {@attrs}>
      <%= if @hidden_method && @hidden_method not in ~w(get post) do %>
        <input name="_method" type="hidden" value={@hidden_method}>
      <% end %>
      <%= if @csrf_token do %>
        <input name="_csrf_token" type="hidden" value={@csrf_token}>
      <% end %>
      <%= render_slot(@inner_block, @form) %>
    </form>
    """
  end

  defp form_method(nil), do: {"post", nil}
  defp form_method(method) when method in ~w(get post), do: {method, nil}
  defp form_method(method) when is_binary(method), do: {"post", method}

  @doc """
  Generates a link for live and href navigation.

  [INSERT LVATTRDOCS]

  ## Examples

  ```heex
  <.link href="/">Regular anchor link</.link>
  ```

  ```heex
  <.link navigate={Routes.page_path(@socket, :index)} class="underline">home</.link>
  ```

  ```heex
  <.link navigate={Routes.live_path(@socket, MyLive, dir: :asc)} replace={false}>
    Sort By Price
  </.link>
  ```

  ```heex
  <.link patch={Routes.page_path(@socket, :index, :details)}>view details</.link>
  ```

  ```heex
  <.link href={URI.parse("https://elixir-lang.org")}>hello</.link>
  ```

  ```heex
  <.link href="/the_world" method={:delete} data-confirm="Really?">delete</.link>
  ```

  ## JavaScript dependency

  In order to support links where `:method` is not `:get` or use the above data attributes,
  `Phoenix.HTML` relies on JavaScript. You can load `priv/static/phoenix_html.js` into your
  build tool.

  ### Data attributes

  Data attributes are added as a keyword list passed to the `data` key. The following data
  attributes are supported:

  * `data-confirm` - shows a confirmation prompt before generating and submitting the form when
  `:method` is not `:get`.

  ### Overriding the default confirm behaviour

  `phoenix_html.js` does trigger a custom event `phoenix.link.click` on the clicked DOM element
  when a click happened. This allows you to intercept the event on it's way bubbling up
  to `window` and do your own custom logic to enhance or replace how the `data-confirm`
  attribute is handled. You could for example replace the browsers `confirm()` behavior with
  a custom javascript implementation:

  ```javascript
  // listen on document.body, so it's executed before the default of
  // phoenix_html, which is listening on the window object
  document.body.addEventListener('phoenix.link.click', function (e) {
    // Prevent default implementation
    e.stopPropagation();
    // Introduce alternative implementation
    var message = e.target.getAttribute("data-confirm");
    if(!message){ return true; }
    vex.dialog.confirm({
      message: message,
      callback: function (value) {
        if (value == false) { e.preventDefault(); }
      }
    })
  }, false);
  ```

  Or you could attach your own custom behavior.

  ```javascript
  window.addEventListener('phoenix.link.click', function (e) {
    // Introduce custom behaviour
    var message = e.target.getAttribute("data-prompt");
    var answer = e.target.getAttribute("data-prompt-answer");
    if(message && answer && (answer != window.prompt(message))) {
      e.preventDefault();
    }
  }, false);
  ```

  The latter could also be bound to any `click` event, but this way you can be sure your custom
  code is only executed when the code of `phoenix_html.js` is run.

  ## CSRF Protection

  By default, CSRF tokens are generated through `Plug.CSRFProtection`.
  """
  @doc type: :component
  attr.(:navigate, :string,
    doc: """
    Navigates from a LiveView to a new LiveView.
    The browser page is kept, but a new LiveView process is mounted and its content on the page
    is reloaded. It is only possible to navigate between LiveViews declared under the same router
    `Phoenix.LiveView.Router.live_session/3`. Otherwise, a full browser redirect is used.
    """
  )

  attr.(:patch, :string,
    doc: """
    Patches the current LiveView.
    The `handle_params` callback of the current LiveView will be invoked and the minimum content
    will be sent over the wire, as any other LiveView diff.
    """
  )

  attr.(:href, :any,
    doc: """
    Uses traditional browser navigation to the new location.
    This means the whole page is reloaded on the browser.
    """
  )

  attr.(:replace, :boolean,
    default: false,
    doc: """
    When using `:patch` or `:navigate`,
    should the browser's history be replaced with `pushState`?
    """
  )

  attr.(:method, :string,
    default: "get",
    doc: """
    The HTTP method to use with the link.
    In case the method is not `get`, the link is generated inside the form which sets the proper
    information. In order to submit the form, JavaScript must be enabled in the browser.
    """
  )

  attr.(:csrf_token, :any,
    default: true,
    doc: """
    A boolean or custom token to use for links with an HTTP method other than `get`.
    """
  )

  attr.(:rest, :global,
    include: ~w(download hreflang referrerpolicy rel target type),
    doc: """
    Additional HTML attributes added to the `a` tag.
    """
  )

  slot.(:inner_block,
    required: true,
    doc: """
    The content rendered inside of the `a` tag.
    """
  )

  def link(%{navigate: to} = assigns) when is_binary(to) do
    ~H"""
    <a
      href={@navigate}
      data-phx-link="redirect"
      data-phx-link-state={if @replace, do: "replace", else: "push"}
      {@rest}
    ><%= render_slot(@inner_block) %></a>
    """
  end

  def link(%{patch: to} = assigns) when is_binary(to) do
    ~H"""
    <a
      href={@patch}
      data-phx-link="patch"
      data-phx-link-state={if @replace, do: "replace", else: "push"}
      {@rest}
    ><%= render_slot(@inner_block) %></a>
    """
  end

  def link(%{href: href} = assigns) when href != "#" and not is_nil(href) do
    href = Phoenix.LiveView.Utils.valid_destination!(href, "<.link>")
    assigns = assign(assigns, :href, href)

    ~H"""
    <a
      href={@href}
      data-method={if @method != "get", do: @method}
      data-csrf={if @method != "get", do: csrf_token(@csrf_token, @href)}
      data-to={if @method != "get", do: @href}
      {@rest}
    ><%= render_slot(@inner_block) %></a>
    """
  end

  def link(%{} = assigns) do
    ~H"""
    <a href="#" {@rest}><%= render_slot(@inner_block) %></a>
    """
  end

  defp csrf_token(true, href), do: Phoenix.HTML.Tag.csrf_token_value(href)
  defp csrf_token(false, _href), do: nil
  defp csrf_token(csrf, _href) when is_binary(csrf), do: csrf

  @doc """
  Wraps tab focus around a container for accessibility.

  This is an essential accessibility feature for interfaces such as modals, dialogs, and menus.

  [INSERT LVATTRDOCS]

  ## Examples

  Simply render your inner content within this component and focus will be wrapped around the
  container as the user tabs through the containers content:

  ```heex
  <.focus_wrap id="my-modal" class="bg-white">
    <div id="modal-content">
      Are you sure?
      <button phx-click="cancel">Cancel</button>
      <button phx-click="confirm">OK</button>
    </div>
  </.focus_wrap>
  ```
  """
  @doc type: :component
  attr.(:id, :string, required: true, doc: "The DOM identifier of the container tag.")

  attr.(:rest, :global, doc: "Additional HTML attributes to add to the container tag.")

  slot.(:inner_block, required: true, doc: "The content rendered inside of the container tag.")

  def focus_wrap(assigns) do
    ~H"""
    <div id={@id} phx-hook="Phoenix.FocusWrap" {@rest}>
      <span id={"#{@id}-start"} tabindex="0" aria-hidden="true"></span>
      <%= render_slot(@inner_block) %>
      <span id={"#{@id}-end"} tabindex="0" aria-hidden="true"></span>
    </div>
    """
  end

  @doc """
  Generates a dynamically named HTML tag.

  Raises an `ArgumentError` if the tag name is found to be unsafe HTML.

  [INSERT LVATTRDOCS]

  ## Examples

  ```heex
  <.dynamic_tag name="input" type="text"/>
  ```

  ```html
  <input type="text"/>
  ```

  ```heex
  <.dynamic_tag name="p">content</.dynamic_tag>
  ```

  ```html
  <p>content</p>
  ```
  """
  @doc type: :component
  attr.(:name, :string, required: true, doc: "The name of the tag, such as `div`.")

  attr.(:rest, :global,
    doc: """
    Additional HTML attributes to add to the tag, ensuring proper escaping.
    """
  )

  slot.(:inner_block, [])

  def dynamic_tag(%{name: name, rest: rest} = assigns) do
    tag_name = to_string(name)

    tag =
      case Phoenix.HTML.html_escape(tag_name) do
        {:safe, ^tag_name} ->
          tag_name

        {:safe, _escaped} ->
          raise ArgumentError,
                "expected dynamic_tag name to be safe HTML, got: #{inspect(tag_name)}"
      end

    assigns =
      assigns
      |> assign(:tag, tag)
      |> assign(:escaped_attrs, Phoenix.HTML.attributes_escape(rest))

    if assigns.inner_block != [] do
      ~H"""
      <%= {:safe, [?<, @tag]} %><%= @escaped_attrs %><%= {:safe, [?>]} %><%= render_slot(@inner_block) %><%= {:safe, [?<, ?/, @tag, ?>]} %>
      """
    else
      ~H"""
      <%= {:safe, [?<, @tag]} %><%= @escaped_attrs %><%= {:safe, [?/, ?>]} %>
      """
    end
  end

  @doc """
  Builds a file input tag for a LiveView upload.

  ## Attributes

  * `:upload` - The `%Phoenix.LiveView.UploadConfig{}` struct.

  Arbitrary attributes may be passed to be applied to the file input tag.

  ## Drag and Drop

  Drag and drop is supported by annotating the droppable container with a `phx-drop-target`
  attribute pointing to the DOM `id` of the file input. By default, the file input `id` is the
  upload `ref`, so the following markup is all that is required for drag and drop support:

  ```heex
  <div class="container" phx-drop-target={@uploads.avatar.ref}>
    <!-- ... -->
    <.live_file_input upload={@uploads.avatar} />
  </div>
  ```

  ## Examples

  ```heex
  <.live_file_input upload={@uploads.avatar} />
  ```
  """
  @doc type: :component
  def live_file_input(assigns)

  def live_file_input(%Phoenix.LiveView.UploadConfig{} = conf) do
    IO.warn(
      "live_file_input(upload) is deprecated, please use <.live_file_input upload={upload} /> instead"
    )

    Phoenix.LiveView.Helpers.live_file_input(conf, [])
  end

  # TODO: Use attr when the backwards compatibility clause above is removed.
  # attr :upload, Phoenix.LiveView.UploadConfig, required: true
  # attr :rest, :global
  def live_file_input(%{} = assigns) do
    conf =
      case assigns do
        %{id: _} -> raise ArgumentError, "the :id cannot be overridden on a live_file_input"
        %{upload: %Phoenix.LiveView.UploadConfig{} = conf} -> conf
        %{} -> raise ArgumentError, "missing required :upload attribute to <.live_file_input/>"
      end

    rest = assigns_to_attributes(assigns, [:upload])

    rest =
      if conf.max_entries > 1 do
        Keyword.put(rest, :multiple, true)
      else
        rest
      end

    assigns =
      assign(assigns,
        conf: conf,
        rest: rest,
        valid?: Enum.any?(conf.entries) && Enum.empty?(conf.errors),
        done_entries: for(entry <- conf.entries, entry.done?, do: entry),
        preflighted_entries: for(entry <- conf.entries, entry.preflighted?, do: entry)
      )

    ~H"""
    <input
      id={@upload.ref}
      type="file"
      name={@upload.name}
      accept={@upload.accept != :any && @upload.accept}
      data-phx-hook="Phoenix.LiveFileUpload"
      data-phx-update="ignore"
      data-phx-upload-ref={@conf.ref}
      data-phx-active-refs={Enum.map_join(@conf.entries, ",", & &1.ref)}
      data-phx-done-refs={Enum.map_join(@done_entries, ",", & &1.ref)}
      data-phx-preflighted-refs={Enum.map_join(@preflighted_entries, ",", & &1.ref)}
      data-phx-auto-upload={@valid? && @conf.auto_upload?}
      {@rest}
    />
    """
  end

  @doc """
  Generates an image preview on the client for a selected file.

  ## Examples

  ```heex
  <%= for entry <- @uploads.avatar.entries do %>
    <.live_img_preview entry={entry} width="75" />
  <% end %>
  ```
  """
  @doc type: :component
  def live_img_preview(assigns)

  def live_img_preview(%Phoenix.LiveView.UploadEntry{} = entry) do
    IO.warn("""
    live_img_preview(entry) is deprecated, please use <.live_img_preview entry={entry} /> instead
    """)

    live_img_preview(%{entry: entry})
  end

  # TODO: Use attr when the backwards compatibility clause above is removed.
  # attr :entry, Phoenix.LiveView.UploadEntry, required: true
  # attr :rest, :global
  def live_img_preview(%{entry: %Phoenix.LiveView.UploadEntry{ref: ref} = entry} = assigns) do
    rest =
      assigns
      |> assigns_to_attributes([:entry])
      |> Keyword.put_new_lazy(:id, fn -> "phx-preview-#{ref}" end)

    assigns = assign(assigns, entry: entry, ref: ref, rest: rest)

    ~H"""
    <img
      data-phx-upload-ref={@entry.upload_ref}
      data-phx-entry-ref={@ref}
      data-phx-hook="Phoenix.LiveImgPreview"
      data-phx-update="ignore"
      {@rest} />
    """
  end

  def live_img_preview(_assigns) do
    raise ArgumentError, "missing required :entry attribute to <.live_img_preview/>"
  end

  @doc """
  Intersperses separator slot between an enumerable.

  Useful when you need to add a separator between items such as when
  rendering breadcrumbs for navigation. Provides each item to the
  inner block.

  ## Examples

  ```heex
  <.intersperse :let={item} enum={["home", "profile", "settings"]}>
    <:separator>
      <span class="sep">|</span>
    </:separator>
    <%= item.name %>
  </.intersperse>
  ```

  Renders the following markup:

      home <span class="sep">|</span> profile <span class="sep">|</span> settings
  """
  attr.(:enum, :any, required: true, doc: "the enumerable to intersperse with separators")
  slot.(:inner_block, required: true, doc: "the inner_block to render for each item")
  slot.(:separator, required: true, doc: "the slot for the separator")

  def intersperse(assigns) do
    ~H"""
    <%= for item <- Enum.intersperse(@enum, :separator) do %>
      <%= if item == :separator do %>
        <%= render_slot(@separator) %>
      <% else %>
        <%= render_slot(@inner_block, item) %>
      <% end %>
    <% end %>
    """
  end
end

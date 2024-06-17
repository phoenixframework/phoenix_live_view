defmodule Phoenix.Component do
  @moduledoc ~S'''
  Define reusable function components with HEEx templates.

  A function component is any function that receives an assigns
  map as an argument and returns a rendered struct built with
  [the `~H` sigil](`sigil_H/2`):

      defmodule MyComponent do
        # In Phoenix apps, the line is typically: use MyAppWeb, :html
        use Phoenix.Component

        def greet(assigns) do
          ~H"""
          <p>Hello, <%= @name %>!</p>
          """
        end
      end

  This function uses the `~H` sigil to return a rendered template.
  `~H` stands for HEEx (HTML + EEx). HEEx is a template language for
  writing HTML mixed with Elixir interpolation. We can write Elixir
  code inside HEEx using `<%= ... %>` tags and we use `@name` to
  access the key `name` defined inside `assigns`.

  When invoked within a `~H` sigil or HEEx template file:

  ```heex
  <MyComponent.greet name="Jane" />
  ```

  The following HTML is rendered:

  ```html
  <p>Hello, Jane!</p>
  ```

  If the function component is defined locally, or its module is imported,
  then the caller can invoke the function directly without specifying the module:

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

  In this module we will learn how to build rich and composable components to
  use in our applications.

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
  `<Components.heading>` requires a `title`, but *does not* require a `name`.

      defmodule Components do
        # In Phoenix apps, the line is typically: use MyAppWeb, :html
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

  ## Global attributes

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

  Global attributes can define defaults which are merged with attributes provided by the caller.
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

  Note that the global attribute cannot be provided directly and doing so will emit
  a warning. In other words, this is invalid:

  ```heex
  <.notification message="You've got mail!" rest={%{"phx-click" => "close"}} />
  ```

  ### Included globals

  You may also specify which attributes are included in addition to the known globals
  with the `:include` option. For example to support the `form` attribute on a button
  component:

  ```elixir
  # <.button form="my-form"/>
  attr :rest, :global, include: ~w(form)
  slot :inner_block
  def button(assigns) do
    ~H"""
    <button {@rest}><%= render_slot(@inner_block) %></button>
    """
  end
  ```

  The `:include` option is useful to apply global additions on a case-by-case basis,
  but sometimes you want to extend existing components with new global attributes,
  such as Alpine.js' `x-` prefixes, which we'll outline next.

  ### Custom global attribute prefixes

  You can extend the set of global attributes by providing a list of attribute prefixes to
  `use Phoenix.Component`. Like the default attributes common to all HTML elements,
  any number of attributes that start with a global prefix will be accepted by function
  components invoked by the current module. By default, the following prefixes are supported:
  `phx-`, `aria-`, and `data-`. For example, to support the `x-` prefix used by
  [Alpine.js](https://alpinejs.dev/), you can pass the `:global_prefixes` option to
  `use Phoenix.Component`:

      use Phoenix.Component, global_prefixes: ~w(x-)

  In your Phoenix application, this is typically done in your
  `lib/my_app_web.ex` file, inside the `def html` definition:

      def html do
        quote do
          use Phoenix.Component, global_prefixes: ~w(x-)
          # ...
        end
      end

  Now all function components invoked by this module will accept any number of attributes
  prefixed with `x-`, in addition to the default global prefixes.

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

  ### The default slot

  The example above uses the default slot, accessible as an assign named `@inner_block`, to render
  HEEx content via the `render_slot/1` function.

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
    I like <b><%= fruit %></b>!
  </.unordered_list>
  ```

  Rendering the following HTML:

  ```html
  <ul>
    <li>I like <b>apples</b>!</li>
    <li>I like <b>bananas</b>!</li>
    <li>I like <b>cherries</b>!</li>
  </ul>
  ```

  Now the separation of concerns is maintained: the caller can specify multiple values in a list
  attribute without having to specify the HEEx content that surrounds and separates them.

  ### Named slots

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

  ### Slot attributes

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

  ## Embedding external template files

  The `embed_templates/1` macro can be used to embed `.html.heex` files
  as function components. The directory path is based on the current
  module (`__DIR__`), and a wildcard pattern may be used to select all
  files within a directory tree. For example, imagine a directory listing:

      ├── components.ex
      ├── cards
      │   ├── pricing_card.html.heex
      │   └── features_card.html.heex

  Then you can embed the page templates in your `components.ex` module
  and call them like any other function component:

      defmodule MyAppWeb.Components do
        use Phoenix.Component

        embed_templates "cards/*"

        def landing_hero(assigns) do
          ~H"""
          <.pricing_card />
          <.features_card />
          """
        end
      end

  See `embed_templates/1` for more information, including declarative
  assigns support for embedded templates.

  ## Debug Annotations

  HEEx templates support debug annotations, which are special HTML comments
  that wrap around rendered components to help you identify where markup
  in your HTML document is rendered within your function component tree.

  For example, imagine the following HEEx template:

  ```heex
  <.header>
    <.button>Click</.button>
  </.header>
  ```

  The HTML document would receive the following comments when debug annotations
  are enabled:

  ```html
  <!-- @caller lib/app_web/home_live.ex:20 -->
  <!-- <AppWeb.CoreComponents.header> lib/app_web/core_components.ex:123 -->
  <header class="p-5">
    <!-- @caller lib/app_web/home_live.ex:48 -->
    <!-- <AppWeb.CoreComponents.button> lib/app_web/core_components.ex:456 -->
    <button class="px-2 bg-indigo-500 text-white">Click</button>
    <!-- </AppWeb.CoreComponents.button> -->
  </header>
  <!-- </AppWeb.CoreComponents.header> -->
  ```

  Debug annotations work across any `~H` or `.html.heex` template.
  They can be enabled globally with the following configuration in your
  `config/dev.exs` file:

      config :phoenix_live_view, debug_heex_annotations: true

  Changing this configuration will require `mix clean` and a full recompile.
  '''

  ## Functions

  alias Phoenix.LiveView.{Static, Socket, AsyncResult}
  @reserved_assigns Phoenix.Component.Declarative.__reserved__()
  # Note we allow live_action as it may be passed down to a component, so it is not listed
  @non_assignables [:uploads, :streams, :socket, :myself]

  @doc ~S'''
  The `~H` sigil for writing HEEx templates inside source files.

  `HEEx` is a HTML-aware and component-friendly extension of Elixir Embedded
  language (`EEx`) that provides:

    * Built-in handling of HTML attributes

    * An HTML-like notation for injecting function components

    * Compile-time validation of the structure of the template

    * The ability to minimize the amount of data sent over the wire

    * Out-of-the-box code formatting via `mix format`

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

  * `false` or `nil` - if a value is `false` or `nil`, the attribute is omitted.
    Some attributes may be rendered with an empty value, for optimization
    purposes, if it has the same effect as omitting. For example,
    `<checkbox checked={false}>` renders to `<checkbox>` while,
    `<div class={false}>` renders to `<div class="">`;

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

  Apart from normal HTML attributes, HEEx also supports some special attributes
  such as `:let` and `:for`.

  #### :let

  This is used by components and slots that want to yield a value back to the
  caller. For an example, see how `form/1` works:

  ```heex
  <.form :let={f} for={@form} phx-change="validate" phx-submit="save">
    <.input field={f[:username]} type="text" />
    ...
  </.form>
  ```

  Notice how the variable `f`, defined by `.form` is used by your `input` component.
  The `Phoenix.Component` module has detailed documentation on how to use and
  implement such functionality.

  #### :if and :for

  It is a syntax sugar for `<%= if .. do %>` and `<%= for .. do %>` that can be
  used in regular HTML, function components, and slots.

  For example in an HTML tag:

  ```heex
  <table id="admin-table" :if={@admin?}>
    <tr :for={user <- @users}>
      <td><%= user.name %></td>
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
    <:col :for={header <- @headers} :let={user}>
      <td><%= user[header] %></td>
    </:col>
  <table>
  ```

  You can also combine `:for` and `:if` for tags, components, and slot to act as a filter:

  ```heex
  <.error :for={msg <- @errors} :if={msg != nil} message={msg} />
  ```

  Note that unlike Elixir's regular `for`, HEEx' `:for` does not support multiple
  generators in one expression.

  ## Code formatting

  You can automatically format HEEx templates (.heex) and `~H` sigils
  using `Phoenix.LiveView.HTMLFormatter`. Please check that module
  for more information.
  '''
  @doc type: :macro
  defmacro sigil_H({:<<>>, meta, [expr]}, []) do
    unless Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      raise "~H requires a variable named \"assigns\" to exist and be set to a map"
    end

    options = [
      engine: Phoenix.LiveView.TagEngine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      caller: __CALLER__,
      indentation: meta[:indentation] || 0,
      source: expr,
      tag_handler: Phoenix.LiveView.HTMLEngine
    ]

    EEx.compile_string(expr, options)
  end

  @doc ~S'''
  Filters the assigns as a list of keywords for use in dynamic tag attributes.

  One should prefer to use declarative assigns and `:global` attributes
  over this function.

  ## Examples

  Imagine the following `my_link` component which allows a caller
  to pass a `new_window` assign, along with any other attributes they
  would like to add to the element, such as class, data attributes, etc:

  ```heex
  <.my_link to="/" id={@id} new_window={true} class="my-class">Home</.my_link>
  ```

  We could support the dynamic attributes with the following component:

      def my_link(assigns) do
        target = if assigns[:new_window], do: "_blank", else: false
        extra = assigns_to_attributes(assigns, [:new_window, :to])

        assigns =
          assigns
          |> assign(:target, target)
          |> assign(:extra, extra)

        ~H"""
        <a href={@to} target={@target} {@extra}>
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

  When a LiveView is rendered, its contents are wrapped in a container. By default,
  the container is a `div` tag with a handful of LiveView-specific attributes.

  The container can be customized in different ways:

  * You can change the default `container` on `use Phoenix.LiveView`:

        use Phoenix.LiveView, container: {:tr, id: "foo-bar"}

  * You can override the container tag and pass extra attributes when calling `live_render`
  (as well as on your `live` call in your router):

        live_render socket, MyLiveView, container: {:tr, class: "highlight"}

  If you don't want the container to affect layout, you can use the CSS property
  `display: contents` or a class that applies it, like Tailwind's `.contents`.

  Beware if you set this to `:body`, as any content injected inside the body
  (such as `Phoenix.LiveReload` features) will be discarded once the LiveView
  connects
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
  @deprecated "Use Phoenix.Flash.get/2 in Phoenix v1.7+"
  def live_flash(%_struct{} = other, _key) do
    raise ArgumentError, "live_flash/2 expects a @flash assign, got: #{inspect(other)}"
  end

  def live_flash(%{} = flash, key), do: Map.get(flash, to_string(key))

  @doc """
  Returns errors for the upload as a whole.

  For errors that apply to a specific upload entry, use `upload_errors/2`.

  The output is a list. The following error may be returned:

  * `:too_many_files` - The number of selected files exceeds the `:max_entries` constraint

  ## Examples

      def upload_error_to_string(:too_many_files), do: "You have selected too many files"

  ```heex
  <div :for={err <- upload_errors(@uploads.avatar)} class="alert alert-danger">
    <%= upload_error_to_string(err) %>
  </div>
  ```
  """
  def upload_errors(%Phoenix.LiveView.UploadConfig{} = conf) do
    for {ref, error} <- conf.errors, ref == conf.ref, do: error
  end

  @doc """
  Returns errors for the upload entry.

  For errors that apply to the upload as a whole, use `upload_errors/1`.

  The output is a list. The following errors may be returned:

  * `:too_large` - The entry exceeds the `:max_file_size` constraint
  * `:not_accepted` - The entry does not match the `:accept` MIME types
  * `:external_client_failure` - When external upload fails
  * `{:writer_failure, reason}` - When the custom writer fails with `reason`

  ## Examples

  ```elixir
  defp upload_error_to_string(:too_large), do: "The file is too large"
  defp upload_error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp upload_error_to_string(:external_client_failure), do: "Something went terribly wrong"
  ```

  ```heex
  <%= for entry <- @uploads.avatar.entries do %>
    <div :for={err <- upload_errors(@uploads.avatar, entry)} class="alert alert-danger">
      <%= upload_error_to_string(err) %>
    </div>
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

  This function is useful for lazily assigning values and sharing assigns.
  We will cover both use cases next.

  ## Lazy assigns

  Imagine you have a function component that accepts a color:

  ```heex
  <.my_component bg_color="red" />
  ```

  The color is also optional, so you can skip it:

  ```heex
  <.my_component />
  ```

  In such cases, the implementation can use `assign_new` to lazily
  assign a color if none is given. Let's make it so it picks a random one
  when none is given:

      def my_component(assigns) do
        assigns = assign_new(assigns, :bg_color, fn -> Enum.random(~w(bg-red-200 bg-green-200 bg-blue-200)) end)

        ~H"""
        <div class={@bg_color}>
          Example
        </div>
        """
      end

  ## Sharing assigns

  It is possible to share assigns between the Plug pipeline and LiveView on disconnected render
  and between parent-child LiveViews when connected.

  ### When disconnected

  When a user first accesses an application using LiveView, the LiveView is first rendered in its
  disconnected state, as part of a regular HTML response. By using `assign_new` in the mount
  callback of your LiveView, you can instruct LiveView to re-use any assigns already set in `conn`
  during disconnected state.

  Imagine you have a Plug that does:

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

  ### When connected

  LiveView is also able to share assigns via `assign_new` with children LiveViews,
  as long as the child LiveView is also mounted when the parent LiveView is mounted.
  Let's see an example.

  If the parent LiveView defines a `:current_user` assign and the child LiveView also
  uses `assign_new/3` to fetch the `:current_user` in its `mount/3` callback, as in
  the previous subsection, the assign will be fetched from the parent LiveView, once
  again avoiding additional database queries.

  Note that `fun` also provides access to the previously assigned values:

      assigns =
        assigns
        |> assign_new(:foo, fn -> "foo" end)
        |> assign_new(:bar, fn %{foo: foo} -> foo <> "bar" end)

  Assigns sharing is performed when possible but not guaranteed. Therefore, you must
  ensure the result of the function given to `assign_new/3` is the same as if the value
  was fetched from the parent. Otherwise consider passing values to the child LiveView
  as part of its session.
  '''
  def assign_new(socket_or_assigns, key, fun)

  def assign_new(%Socket{} = socket, key, fun) do
    validate_assign_key!(key)
    Phoenix.LiveView.Utils.assign_new(socket, key, fun)
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
      # force assign the key if the attribute was given with matching value
      %{^key => ^value, __given__: given} when not is_map_key(given, key) ->
        Phoenix.LiveView.Utils.force_assign(assigns, changed, key, value)

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
            "Use the appropriate flash functions instead"
  end

  defp validate_assign_key!(assign) when assign in @non_assignables do
    raise ArgumentError,
          "#{inspect(assign)} is a reserved assign by LiveView and it cannot be set directly"
  end

  defp validate_assign_key!(key) when is_atom(key), do: :ok

  defp validate_assign_key!(key) do
    raise ArgumentError, "assigns in LiveView must be atoms, got: #{inspect(key)}"
  end

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
      ...>   max(current_max, length(users))
      ...> end)
  """
  def update(socket_or_assigns, key, fun)

  def update(%Socket{assigns: assigns} = socket, key, fun) when is_function(fun, 2) do
    update(socket, key, &fun.(&1, assigns))
  end

  def update(%Socket{assigns: assigns} = socket, key, fun) when is_function(fun, 1) do
    case assigns do
      %{^key => val} -> Phoenix.LiveView.Utils.assign(socket, key, fun.(val))
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

  @doc """
  Converts a given data structure to a `Phoenix.HTML.Form`.

  This is commonly used to convert a map or an Ecto changeset
  into a form to be given to the `form/1` component.

  ## Creating a form from params

  If you want to create a form based on `handle_event` parameters,
  you could do:

      def handle_event("submitted", params, socket) do
        {:noreply, assign(socket, form: to_form(params))}
      end

  When you pass a map to `to_form/1`, it assumes said map contains
  the form parameters, which are expected to have string keys.

  You can also specify a name to nest the parameters:

      def handle_event("submitted", %{"user" => user_params}, socket) do
        {:noreply, assign(socket, form: to_form(user_params, as: :user))}
      end

  ## Creating a form from changesets

  When using changesets, the underlying data, form parameters, and
  errors are retrieved from it. The `:as` option is automatically
  computed too. For example, if you have a user schema:

      defmodule MyApp.Users.User do
        use Ecto.Schema

        schema "..." do
          ...
        end
      end

  And then you create a changeset that you pass to `to_form`:

      %MyApp.Users.User{}
      |> Ecto.Changeset.change()
      |> to_form()

  In this case, once the form is submitted, the parameters will
  be available under `%{"user" => user_params}`.

  ## Options

    * `:as` - the `name` prefix to be used in form inputs
    * `:id` - the `id` prefix to be used in form inputs
    * `:errors` - keyword list of errors (used by maps exclusively)

  The underlying data may accept additional options when
  converted to forms. For example, a map accepts `:errors`
  to list errors, but such option is not accepted by
  changesets. `:errors` is a keyword of tuples in the shape
  of `{error_message, options_list}`. Here is an example:

      to_form(%{"search" => nil}, errors: [search: {"Can't be blank", []}])

  If an existing `Phoenix.HTML.Form` struct is given, the
  options above will override its existing values if given.
  Then the remaining options are merged with the existing
  form options.

  Errors in a form are only displayed if the changeset's `action`
  field is set (and it is not set to `:ignore`). Refer to
  [a note on :errors for more information](#form/1-a-note-on-errors).
  """
  def to_form(data_or_params, options \\ [])

  def to_form(%Phoenix.HTML.Form{} = data, options) do
    {name, id} =
      case Keyword.fetch(options, :as) do
        {:ok, as} ->
          name = if as == nil, do: as, else: to_string(as)
          {name, Keyword.get(options, :id) || name}

        :error ->
          case Keyword.fetch(options, :id) do
            {:ok, id} -> {data.name, id}
            :error -> {data.name, data.id}
          end
      end

    {_as, options} = Keyword.pop(options, :as)
    {errors, options} = Keyword.pop(options, :errors, data.errors)
    options = Keyword.merge(data.options, options)

    %{data | errors: errors, id: id, name: name, options: options}
  end

  def to_form(data, options) do
    if is_atom(data) do
      IO.warn("""
      Passing an atom to "for" in the form component is deprecated.
      Instead of:

          <.form :let={f} for={#{inspect(data)}} ...>

      You might do:

          <.form :let={f} for={%{}} as={#{inspect(data)}} ...>

      Or, if you prefer, use to_form to create a form in your LiveView:

          assign(socket, form: to_form(%{}, as: #{inspect(data)}))

      and then use it in your templates (no :let required):

          <.form for={@form}>
      """)
    end

    Phoenix.HTML.FormData.to_form(data, options)
  end

  @doc """
  Embeds external template files into the module as function components.

  ## Options

    * `:root` - The root directory to embed files. Defaults to the current
      module's directory (`__DIR__`)
    * `:suffix` - A string value to append to embedded function names. By
      default, function names will be the name of the template file excluding
      the format and engine.

  A wildcard pattern may be used to select all files within a directory tree.
  For example, imagine a directory listing:

      ├── components.ex
      ├── pages
      │   ├── about_page.html.heex
      │   └── welcome_page.html.heex

  Then to embed the page templates in your `components.ex` module:

      defmodule MyAppWeb.Components do
        use Phoenix.Component

        embed_templates "pages/*"
      end

  Now, your module will have an `about_page/1` and `welcome_page/1` function
  component defined. Embedded templates also support declarative assigns
  via bodyless function definitions, for example:

      defmodule MyAppWeb.Components do
        use Phoenix.Component

        embed_templates "pages/*"

        attr :name, :string, required: true
        def welcome_page(assigns)

        slot :header
        def about_page(assigns)
      end

  Multiple invocations of `embed_templates` is also supported, which can be
  useful if you have more than one template format. For example:

      defmodule MyAppWeb.Emails do
        use Phoenix.Component

        embed_templates "emails/*.html", suffix: "_html"
        embed_templates "emails/*.text", suffix: "_text"
      end

  Note: this function is the same as `Phoenix.Template.embed_templates/2`.
  It is also provided here for convenience and documentation purposes.
  Therefore, if you want to embed templates for other formats, which are
  not related to `Phoenix.Component`, prefer to
  `import Phoenix.Template, only: [embed_templates: 1]` than this module.
  """
  @doc type: :macro
  defmacro embed_templates(pattern, opts \\ []) do
    quote bind_quoted: [pattern: pattern, opts: opts] do
      Phoenix.Template.compile_all(
        &Phoenix.Component.__embed__(&1, opts[:suffix]),
        Path.expand(opts[:root] || __DIR__, __DIR__),
        pattern
      )
    end
  end

  @doc false
  def __embed__(path, suffix),
    do:
      path
      |> Path.basename()
      |> Path.rootname()
      |> Path.rootname()
      |> Kernel.<>(suffix || "")

  ## Declarative assigns API

  @doc false
  defmacro __using__(opts \\ []) do
    conditional =
      if __CALLER__.module != Phoenix.LiveView.Helpers do
        quote do: import(Phoenix.LiveView.Helpers)
      end

    imports =
      quote bind_quoted: [opts: opts] do
        import Kernel, except: [def: 2, defp: 2]
        import Phoenix.Component
        import Phoenix.Component.Declarative
        require Phoenix.Template

        for {prefix_match, value} <- Phoenix.Component.Declarative.__setup__(__MODULE__, opts) do
          @doc false
          def __global__?(unquote(prefix_match)), do: unquote(value)
        end
      end

    [conditional, imports]
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

  * `:validate_attrs` - when set to `false`, no warning is emitted when a caller passes attributes
  to a slot defined without a do block. If not set, defaults to `true`.

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
  @doc type: :macro
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
  @doc type: :macro
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
  | `:map`          | any map of any arbitrary types                                       |
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
  `:string`, `:atom`, `:boolean`, `:integer`, `:float`, `:map` and `:list`.

  * You specify a literal attribute and it is not a member of the `:values` list.

  LiveView does not perform any validation at runtime. This means the type information is mostly
  used for documentation and reflection purposes.

  On the side of the LiveView component itself, defining attributes provides the following quality
  of life improvements:

  * The default value of all attributes will be added to the `assigns` map upfront.

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
  @doc type: :macro
  defmacro attr(name, type, opts \\ []) do
    # TODO: Use Macro.expand_literals on Elixir v1.14.1+
    type =
      if Macro.quoted_literal?(type) do
        Macro.prewalk(type, &expand_alias(&1, __CALLER__))
      else
        type
      end

    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

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

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:__attr__, 3}})

  defp expand_alias(other, _env), do: other

  ## Components

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

  While LiveViews can be nested, each LiveView starts its own process. A LiveComponent provides
  similar functionality to LiveView, except they run in the same process as the LiveView,
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
  attr.(:prefix, :string,
    default: nil,
    doc: "A prefix added before the content of `inner_block`."
  )

  attr.(:suffix, :string, default: nil, doc: "A suffix added after the content of `inner_block`.")
  slot.(:inner_block, required: true, doc: "Content rendered inside the `title` tag.")

  def live_title(assigns) do
    ~H"""
    <title data-prefix={@prefix} data-suffix={@suffix}><%= @prefix %><%= render_slot(@inner_block) %><%= @suffix %></title>
    """
  end

  @doc ~S'''
  Renders a form.

  This function receives a `Phoenix.HTML.Form` struct, generally created with
  `to_form/2`, and generates the relevant form tags. It can be used either
  inside LiveView or outside.

  > To see how forms work in practice, you can run
  > `mix phx.gen.live Blog Post posts title body:text` inside your Phoenix
  > application, which will setup the necessary database tables and LiveViews
  > to manage your data.

  ## Examples: inside LiveView

  Inside LiveViews, this function component is typically called with
  as `for={@form}`, where `@form` is the result of the `to_form/1` function.
  `to_form/1` expects either a map or an [`Ecto.Changeset`](https://hexdocs.pm/ecto/Ecto.Changeset.html)
  as the source of data and normalizes it into `Phoenix.HTML.Form` structure.

  For example, you may use the parameters received in a
  `c:Phoenix.LiveView.handle_event/3` callback to create an Ecto changeset
  and then use `to_form/1` to convert it to a form. Then, in your templates,
  you pass the `@form` as argument to `:for`:

  ```heex
  <.form
    for={@form}
    phx-change="change_name"
  >
    <.input field={@form[:email]} />
  </.form>
  ```

  The `.input` component is generally defined as part of your own application
  and adds all styling necessary:

  ```heex
  def input(assigns) do
    ~H"""
    <input type="text" name={@field.name} id={@field.id} value={@field.value} class="..." />
    """
  end
  ```

  A form accepts multiple options. For example, if you are doing file uploads
  and you want to capture submissions, you might write instead:

  ```heex
  <.form
    for={@form}
    multipart
    phx-change="change_user"
    phx-submit="save_user"
  >
    ...
    <input type="submit" value="Save" />
  </.form>
  ```

  Notice how both examples use `phx-change`. The LiveView must implement the
  `phx-change` event and store the input values as they arrive on change.
  This is important because, if an unrelated change happens on the page,
  LiveView should re-render the inputs with their updated values. Without `phx-change`,
  the inputs would otherwise be cleared. Alternatively, you can use `phx-update="ignore"`
  on the form to discard any updates.

  ### Using the `for` attribute

  The `for` attribute can also be a map or an Ecto.Changeset. In such cases,
  a form will be created on the fly, and you can capture it using `:let`:

  ```heex
  <.form
    :let={form}
    for={@changeset}
    phx-change="change_user"
  >
  ```

  However, such approach is discouraged in LiveView for two reasons:

    * LiveView can better optimize your code if you access the form fields
      using `@form[:field]` rather than through the let-variable `form`

    * Ecto changesets are meant to be single use. By never storing the changeset
      in the assign, you will be less tempted to use it across operations

  ### A note on `:errors`

  Even if `changeset.errors` is non-empty, errors will not be displayed in a
  form if [the changeset
  `:action`](https://hexdocs.pm/ecto/Ecto.Changeset.html#module-changeset-actions)
  is `nil` or `:ignore`.

  This is useful for things like validation hints on form fields, e.g. an empty
  changeset for a new form. That changeset isn't valid, but we don't want to
  show errors until an actual user action has been performed.

  For example, if the user submits and a `Repo.insert/1` is called and fails on
  changeset validation, the action will be set to `:insert` to show that an
  insert was attempted, and the presence of that action will cause errors to be
  displayed. The same is true for Repo.update/delete.

  If you want to show errors manually you can also set the action yourself,
  either directly on the `Ecto.Changeset` struct field or by using
  `Ecto.Changeset.apply_action/2`. Since the action can be arbitrary, you can
  set it to `:validate` or anything else to avoid giving the impression that a
  database operation has actually been attempted.

  ## Example: outside LiveView (regular HTTP requests)

  The `form` component can still be used to submit forms outside of LiveView.
  In such cases, the `action` attribute MUST be given. Without said attribute,
  the `form` method and csrf token are discarded.

  ```heex
  <.form :let={f} for={@changeset} action={~p"/comments/#{@comment}"}>
    <.input field={f[:body]} />
  </.form>
  ```

  In the example above, we passed a changeset to `for` and captured
  the value using `:let={f}`. This approach is ok outside of LiveViews,
  as there are no change tracking optimizations to consider.

  ### CSRF protection

  CSRF protection is a mechanism to ensure that the user who rendered
  the form is the one actually submitting it. This module generates a
  CSRF token by default. Your application should check this token on
  the server to avoid attackers from making requests on your server on
  behalf of other users. Phoenix by default checks this token.

  When posting a form with a host in its address, such as "//host.com/path"
  instead of only "/path", Phoenix will include the host signature in the
  token and validate the token only if the accessed host is the same as
  the host in the token. This is to avoid tokens from leaking to third
  party applications. If this behaviour is problematic, you can generate
  a non-host specific token with `Plug.CSRFProtection.get_csrf_token/0` and
  pass it to the form generator via the `:csrf_token` option.

  [INSERT LVATTRDOCS]
  '''
  @doc type: :component
  attr.(:for, :any, required: true, doc: "An existing form or the form source data.")

  attr.(:action, :string,
    doc: """
    The action to submit the form on.
    This attribute must be given if you intend to submit the form to a URL without LiveView.
    """
  )

  attr.(:as, :atom,
    doc: """
    The prefix to be used in names and IDs generated by the form.
    For example, setting `as: :user_params` means the parameters
    will be nested "user_params" in your `handle_event` or
    `conn.params["user_params"]` for regular HTTP requests.
    If you set this option, you must capture the form with `:let`.
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
    doc: """
    Use this to manually pass a keyword list of errors to the form.
    This option is useful when a regular map is given as the form
    source and it will make the errors available under `f.errors`.
    If you set this option, you must capture the form with `:let`.
    """
  )

  attr.(:method, :string,
    doc: """
    The HTTP method.
    It is only used if an `:action` is given. If the method is not `get` nor `post`,
    an input tag with name `_method` is generated alongside the form tag.
    If an `:action` is given with no method, the method will default to `post`.
    """
  )

  attr.(:multipart, :boolean,
    default: false,
    doc: """
    Sets `enctype` to `multipart/form-data`.
    Required when uploading files.
    """
  )

  attr.(:rest, :global,
    include: ~w(autocomplete name rel enctype novalidate target),
    doc: "Additional HTML attributes to add to the form tag."
  )

  slot.(:inner_block, required: true, doc: "The content rendered inside of the form tag.")

  def form(assigns) do
    action = assigns[:action]

    # We require for={...} to be given but we automatically handle nils for convenience
    form_for =
      case assigns[:for] do
        nil -> %{}
        other -> other
      end

    form_options =
      assigns
      |> Map.take([:as, :csrf_token, :errors, :method, :multipart])
      |> Map.merge(assigns.rest)
      |> Map.to_list()

    # Since FormData may add options, read the actual options from form
    %{options: opts} = form = to_form(form_for, form_options)

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
        <input name="_method" type="hidden" hidden value={@hidden_method}>
      <% end %>
      <%= if @csrf_token do %>
        <input name="_csrf_token" type="hidden" hidden value={@csrf_token}>
      <% end %>
      <%= render_slot(@inner_block, @form) %>
    </form>
    """
  end

  defp form_method(nil), do: {"post", nil}
  defp form_method(method) when method in ~w(get post), do: {method, nil}
  defp form_method(method) when is_binary(method), do: {"post", method}

  @doc """
  Renders nested form inputs for associations or embeds.

  [INSERT LVATTRDOCS]

  ## Examples

  ```heex
  <.form
    :let={f}
    phx-change="change_name"
  >
    <.inputs_for :let={f_nested} field={f[:nested]}>
      <.input type="text" field={f_nested[:name]} />
    </.inputs_for>
  </.form>
  ```

  ## Dynamically adding and removing inputs

  Dynamically adding and removing inputs is supported by rendering named buttons for
  inserts and removals. Like inputs, buttons with name/value pairs are serialized with
  form data on change and submit events. Libraries such as Ecto, or custom param
  filtering can then inspect the parameters and handle the added or removed fields.
  This can be combined with `Ecto.Changeset.cast/3`'s `:sort_param` and `:drop_param`
  options. For example, imagine a parent with an `:emails` `has_many` or `embeds_many`
  association. To cast the user input from a nested form, one simply needs to configure
  the options:

      schema "mailing_lists" do
        field :title, :string

        embeds_many :emails, EmailNotification, on_replace: :delete do
          field :email, :string
          field :name, :string
        end
      end

      def changeset(list, attrs) do
        list
        |> cast(attrs, [:title])
        |> cast_embed(:emails,
          with: &email_changeset/2,
          sort_param: :emails_sort,
          drop_param: :emails_drop
        )
      end

  Here we see the `:sort_param` and `:drop_param` options in action.

  > Note: `on_replace: :delete` on the `has_many` and `embeds_many` is required
  > when using these options.

  When Ecto sees the specified sort or drop parameter from the form, it will sort
  the children based on the order they appear in the form, add new children it hasn't
  seen, or drop children if the parameter instructs it to do so.

  The markup for such a schema and association would look like this:

  ```heex
  <.inputs_for :let={ef} field={@form[:emails]}>
    <input type="hidden" name="mailing_list[emails_sort][]" value={ef.index} />
    <.input type="text" field={ef[:email]} placeholder="email" />
    <.input type="text" field={ef[:name]} placeholder="name" />
    <button
      type="button"
      name="mailing_list[emails_drop][]"
      value={ef.index}
      phx-click={JS.dispatch("change")}
    >
      <.icon name="hero-x-mark" class="w-6 h-6 relative top-2" />
    </button>
  </.inputs_for>

  <input type="hidden" name="mailing_list[emails_drop][]" />

  <button type="button" name="mailing_list[emails_sort][]" value="new" phx-click={JS.dispatch("change")}>
    add more
  </button>
  ```

  We used `inputs_for` to render inputs for the `:emails` association, which
  contains an email address and name input for each child. Within the nested inputs,
  we render a hidden `mailing_list[emails_sort][]` input, which is set to the index of the
  given child. This tells Ecto's cast operation how to sort existing children, or
  where to insert new children. Next, we render the email and name inputs as usual.
  Then we render a button containing the "delete" text with the name `mailing_list[emails_drop][]`,
  containing the index of the child as its value.

  Like before, this tells Ecto to delete the child at this index when the button is
  clicked. We use `phx-click={JS.dispatch("change")}` on the button to tell LiveView
  to treat this button click as a change event, rather than a submit event on the form,
  which invokes our form's `phx-change` binding.

  Outside the `inputs_for`, we render an empty `mailing_list[emails_drop][]` input,
  to ensure that all children are deleted when saving a form where the user
  dropped all entries. This hidden input is required whenever dropping associations.

  Finally, we also render another button with the sort param name `mailing_list[emails_sort][]`
  and `value="new"` name with accompanied "add more" text. Please note that this button must
  have `type="button"` to prevent it from submitting the form.
  Ecto will treat unknown sort params as new children and build a new child.
  This button is optional and only necessary if you want to dyamically add entries.
  You can optionally add a similar button before the `<.inputs_for>`, in the case you want
  to prepend entries.
  """
  @doc type: :component
  attr.(:field, Phoenix.HTML.FormField,
    required: true,
    doc: "A %Phoenix.HTML.Form{}/field name tuple, for example: {@form[:email]}."
  )

  attr.(:id, :string,
    doc: """
    The id to be used in the form, defaults to the concatenation of the given
    field to the parent form id.
    """
  )

  attr.(:as, :atom,
    doc: """
    The name to be used in the form, defaults to the concatenation of the given
    field to the parent form name.
    """
  )

  attr.(:default, :any, doc: "The value to use if none is available.")

  attr.(:prepend, :list,
    doc: """
    The values to prepend when rendering. This only applies if the field value
    is a list and no parameters were sent through the form.
    """
  )

  attr.(:append, :list,
    doc: """
    The values to append when rendering. This only applies if the field value
    is a list and no parameters were sent through the form.
    """
  )

  attr.(:skip_hidden, :boolean,
    default: false,
    doc: """
    Skip the automatic rendering of hidden fields to allow for more tight control
    over the generated markup.
    """
  )

  attr.(:options, :list,
    default: [],
    doc: """
    Any additional options for the `Phoenix.HTML.FormData` protocol
    implementation.
    """
  )

  slot.(:inner_block, required: true, doc: "The content rendered for each nested form.")

  @persistent_id "_persistent_id"
  def inputs_for(assigns) do
    %Phoenix.HTML.FormField{field: field_name, form: parent_form} = assigns.field
    options = assigns |> Map.take([:id, :as, :default, :append, :prepend]) |> Keyword.new()

    options =
      parent_form.options
      |> Keyword.take([:multipart])
      |> Keyword.merge(options)
      |> Keyword.merge(assigns.options)

    forms = parent_form.impl.to_form(parent_form.source, parent_form, field_name, options)
    seen_ids = for f <- forms, vid = f.params[@persistent_id], into: %{}, do: {vid, true}
    acc = {seen_ids, 0}

    {forms, _} =
      Enum.map_reduce(forms, acc, fn
        %Phoenix.HTML.Form{params: params} = form, {seen_ids, index} ->
          id =
            case params do
              %{@persistent_id => id} -> id
              %{} -> next_id(map_size(seen_ids), seen_ids)
            end

          form_id = "#{parent_form.id}_#{field_name}_#{id}"
          new_params = Map.put(params, @persistent_id, id)
          new_hidden = [{@persistent_id, id} | form.hidden]

          new_form = %Phoenix.HTML.Form{
            form
            | id: form_id,
              params: new_params,
              hidden: new_hidden,
              index: index
          }

          {new_form, {Map.put(seen_ids, id, true), index + 1}}
      end)

    assigns = assign(assigns, :forms, forms)

    ~H"""
    <%= for finner <- @forms do %>
      <%= unless @skip_hidden do %>
        <%= for {name, value_or_values} <- finner.hidden,
                name = name_for_value_or_values(finner, name, value_or_values),
                value <- List.wrap(value_or_values) do %>
          <input type="hidden" name={name} value={value} />
        <% end %>
      <% end %>
      <%= render_slot(@inner_block, finner) %>
    <% end %>
    """
  end

  defp next_id(idx, %{} = seen_ids) do
    id_str = to_string(idx)

    if Map.has_key?(seen_ids, id_str) do
      next_id(idx + 1, seen_ids)
    else
      id_str
    end
  end

  defp name_for_value_or_values(form, field, values) when is_list(values) do
    Phoenix.HTML.Form.input_name(form, field) <> "[]"
  end

  defp name_for_value_or_values(form, field, _value) do
    Phoenix.HTML.Form.input_name(form, field)
  end

  @doc """
  Generates a link to a given route.

  To navigate across pages, using traditional browser navigation, use
  the `href` attribute. To patch the current LiveView or navigate
  across LiveViews, use `patch` and `navigate` respectively.

  [INSERT LVATTRDOCS]

  ## Examples

  ```heex
  <.link href="/">Regular anchor link</.link>
  ```

  ```heex
  <.link navigate={~p"/"} class="underline">home</.link>
  ```

  ```heex
  <.link navigate={~p"/?sort=asc"} replace={false}>
    Sort By Price
  </.link>
  ```

  ```heex
  <.link patch={~p"/details"}>view details</.link>
  ```

  ```heex
  <.link href={URI.parse("https://elixir-lang.org")}>hello</.link>
  ```

  ```heex
  <.link href="/the_world" method="delete" data-confirm="Really?">delete</.link>
  ```

  ## JavaScript dependency

  In order to support links where `:method` is not `"get"` or use the above data attributes,
  `Phoenix.HTML` relies on JavaScript. You can load `priv/static/phoenix_html.js` into your
  build tool.

  ### Data attributes

  Data attributes are added as a keyword list passed to the `data` key. The following data
  attributes are supported:

  * `data-confirm` - shows a confirmation prompt before generating and submitting the form when
  `:method` is not `"get"`.

  ### Overriding the default confirm behaviour

  `phoenix_html.js` does trigger a custom event `phoenix.link.click` on the clicked DOM element
  when a click happened. This allows you to intercept the event on its way bubbling up
  to `window` and do your own custom logic to enhance or replace how the `data-confirm`
  attribute is handled. You could for example replace the browsers `confirm()` behavior with
  a custom javascript implementation:

  ```javascript
  // Compared to a javascript window.confirm, the custom dialog does not block
  // javascript execution. Therefore to make this work as expected we store
  // the successful confirmation as an attribute and re-trigger the click event.
  // On the second click, the `data-confirm-resolved` attribute is set and we proceed.
  const RESOLVED_ATTRIBUTE = "data-confirm-resolved";
  // listen on document.body, so it's executed before the default of
  // phoenix_html, which is listening on the window object
  document.body.addEventListener('phoenix.link.click', function (e) {
    // Prevent default implementation
    e.stopPropagation();
    // Introduce alternative implementation
    var message = e.target.getAttribute("data-confirm");
    if(!message){ return; }

    // Confirm is resolved execute the click event
    if (e.target?.hasAttribute(RESOLVED_ATTRIBUTE)) {
      e.target.removeAttribute(RESOLVED_ATTRIBUTE);
      return;
    }

    // Confirm is needed, preventDefault and show your modal
    e.preventDefault();
    e.target?.setAttribute(RESOLVED_ATTRIBUTE, "");

    vex.dialog.confirm({
      message: message,
      callback: function (value) {
        if (value == true) {
          // Customer confirmed, re-trigger the click event.
          e.target?.click();
        } else {
          // Customer canceled
          e.target?.removeAttribute(RESOLVED_ATTRIBUTE);
        }
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
    The HTTP method to use with the link. This is intended for usage outside of LiveView
    and therefore only works with the `href={...}` attribute. It has no effect on `patch`
    and `navigate` instructions.

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

  defp csrf_token(true, href), do: Plug.CSRFProtection.get_csrf_token_for(href)
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
      |> assign(:escaped_attrs, Phoenix.LiveView.HTMLEngine.attributes_escape(rest))

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

  [INSERT LVATTRDOCS]

  ## Drag and Drop

  Drag and drop is supported by annotating the droppable container with a `phx-drop-target`
  attribute pointing to the UploadConfig `ref`, so the following markup is all that is required
  for drag and drop support:

  ```heex
  <div class="container" phx-drop-target={@uploads.avatar.ref}>
    <!-- ... -->
    <.live_file_input upload={@uploads.avatar} />
  </div>
  ```

  ## Examples

  Rendering a file input:

  ```heex
  <.live_file_input upload={@uploads.avatar} />
  ```

  Rendering a file input with a label:

  ```heex
  <label for={@uploads.avatar.ref}>Avatar</label>
  <.live_file_input upload={@uploads.avatar} />
  ```
  """
  @doc type: :component

  attr.(:upload, Phoenix.LiveView.UploadConfig,
    required: true,
    doc: "The `Phoenix.LiveView.UploadConfig` struct"
  )

  attr.(:accept, :string,
    doc:
      "the optional override for the accept attribute. Defaults to :accept specified by allow_upload"
  )

  attr.(:rest, :global, include: ~w(webkitdirectory required disabled capture form))

  def live_file_input(%{upload: upload} = assigns) do
    assigns = assign_new(assigns, :accept, fn -> upload.accept != :any && upload.accept end)

    ~H"""
    <input
      id={@upload.ref}
      type="file"
      name={@upload.name}
      accept={@accept}
      data-phx-hook="Phoenix.LiveFileUpload"
      data-phx-update="ignore"
      data-phx-upload-ref={@upload.ref}
      data-phx-active-refs={join_refs(for(entry <- @upload.entries, do: entry.ref))}
      data-phx-done-refs={join_refs(for(entry <- @upload.entries, entry.done?, do: entry.ref))}
      data-phx-preflighted-refs={join_refs(for(entry <- @upload.entries, entry.preflighted?, do: entry.ref))}
      data-phx-auto-upload={@upload.auto_upload?}
      {if @upload.max_entries > 1, do: Map.put(@rest, :multiple, true), else: @rest}
    />
    """
  end

  defp join_refs(entries), do: Enum.join(entries, ",")

  @doc ~S"""
  Generates an image preview on the client for a selected file.

  [INSERT LVATTRDOCS]

  ## Examples

  ```heex
  <%= for entry <- @uploads.avatar.entries do %>
    <.live_img_preview entry={entry} width="75" />
  <% end %>
  ```

  When you need to use it multiple times, make sure that they have distinct ids

  ```heex
  <%= for entry <- @uploads.avatar.entries do %>
    <.live_img_preview entry={entry} width="75" />
  <% end %>

  <%= for entry <- @uploads.avatar.entries do %>
    <.live_img_preview id={"modal-#{entry.ref}"} entry={entry} width="500" />
  <% end %>
  ```
  """
  @doc type: :component

  attr.(:entry, Phoenix.LiveView.UploadEntry,
    required: true,
    doc: "The `Phoenix.LiveView.UploadEntry` struct"
  )

  attr.(:id, :string,
    default: nil,
    doc:
      "the id of the img tag. Derived by default from the entry ref, but can be overridden as needed if you need to render a preview of the same entry multiple times on the same page"
  )

  attr.(:rest, :global, [])

  def live_img_preview(assigns) do
    ~H"""
    <img
      id={@id || "phx-preview-#{@entry.ref}"}
      data-phx-upload-ref={@entry.upload_ref}
      data-phx-entry-ref={@entry.ref}
      data-phx-hook="Phoenix.LiveImgPreview"
      data-phx-update="ignore"
      {@rest} />
    """
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
    <%= item %>
  </.intersperse>
  ```

  Renders the following markup:

      home <span class="sep">|</span> profile <span class="sep">|</span> settings
  """
  @doc type: :component
  attr.(:enum, :any, required: true, doc: "the enumerable to intersperse with separators")
  slot.(:inner_block, required: true, doc: "the inner_block to render for each item")
  slot.(:separator, required: true, doc: "the slot for the separator")

  def intersperse(assigns) do
    ~H"""
    <%= for item <- Enum.intersperse(@enum, :separator) do %><%=
      if item == :separator do
        render_slot(@separator)
      else
        render_slot(@inner_block, item)
      end
    %><% end %>
    """
  end

  @doc """
  Renders an async assign with slots for the different loading states.
  The result state takes precedence over subsequent loading and failed
  states.

  *Note*: The inner block receives the result of the async assign as a :let.
  The let is only accessible to the inner block and is not in scope to the
  other slots.

  ## Examples

  ```heex
  <.async_result :let={org} assign={@org}>
    <:loading>Loading organization...</:loading>
    <:failed :let={_failure}>there was an error loading the organization</:failed>
    <%= if org do %>
      <%= org.name %>
    <% else %>
      You don't have an organization yet.
    <% end %>
  </.async_result>
  ```

  To display loading and failed states again on subsequent `assign_async` calls,
  reset the assign to a result-free `%AsyncResult{}`:

  ```elixir
  {:noreply,
    socket
    |> assign_async(:page, :data, &reload_data/0)
    |> assign(:page, AsyncResult.loading())}
  ```
  """
  @doc type: :component
  attr.(:assign, AsyncResult, required: true)
  slot.(:loading, doc: "rendered while the assign is loading for the first time")

  slot.(:failed,
    doc:
      "rendered when an error or exit is caught or assign_async returns `{:error, reason}` for the first time. Receives the error as a `:let`"
  )

  slot.(:inner_block,
    doc:
      "rendered when the assign is loaded successfully via `AsyncResult.ok/2`. Receives the result as a `:let`"
  )

  def async_result(%{assign: async_assign} = assigns) do
    cond do
      async_assign.ok? ->
        ~H|<%= render_slot(@inner_block, @assign.result) %>|

      async_assign.loading ->
        ~H|<%= render_slot(@loading, @assign.loading) %>|

      async_assign.failed ->
        ~H|<%= render_slot(@failed, @assign.failed) %>|
    end
  end
end

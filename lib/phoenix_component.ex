defmodule Phoenix.Component do
  @moduledoc ~S'''
  Define reusable function components with HEEx templates.

  A function component is any function that receives an assigns map as an argument and returns 
  a rendered struct built with [the `~H` sigil](`Phoenix.LiveView.Helpers.sigil_H/2`):

      defmodule MyComponent do
        use Phoenix.Component
    
        def greet(assigns) do
          ~H"""
          <p>Hello, <%= @name %>!</p>
          """
        end
      end

  When invoked within a `~H` sigil or HEEx template file:

      <MyComponent.greet name="Jane" />

  The following HTML is rendered:

      <p>Hello, Jane!</p>

  If the function component is defined locally, or its module is imported, then the caller can
  invoke the function directly without specifying the module:

      <.greet name="Jane" />

  For dynamic values, you can interpolate Elixir expressions into a function component:

      <.greet name={@user.name} />

  Function components can also accept blocks of HEEx content (more on this later):

      <.card>
        <p>This is the body of my card!</p>
      </.card>

  Like `Phoenix.LiveView` and `Phoenix.LiveComponent`, function components are implemented using
  a map of assigns, and follow [the same rules and best practices](../guides/server/assigns-eex.md).
  However, we typically do not implement function components by manipulating the assigns map 
  directly, as `Phoenix.Component` provides two higher-level abstractions for us: 
  attributes and slots.

  ## Attributes

  `Phoenix.Component` provides the `attr/3` macro to declare what attributes a function component
  expects to receive when invoked:

      attr :name, :string, required: true

      def greet(assigns) do
        ~H"""
        <p>Hello, <%= @name %>!</p>
        """
      end

  By calling `attr/3`, it is now clear that `greet/1` requires a string attribute called `name` 
  present in its assigns map to properly render. Failing to do so will result in a compilation 
  warning:

      <MyComponent.greet />
        warning: missing required attribute "name" for component MyAppWeb.MyComponent.greet/1
                 lib/app_web/my_component.ex:15

  Attributes can provide default values that are automatically merged into the assigns map:

      attr :name, :string, default: "Bob"

  Now you can invoke the function component without providing a value for `name`:

      <.greet />

  Rendering the following HTML:

      <p>Hello, Bob!</p>

  Multiple attributes can be declared for the same function component:

      attr :name, :string, required: true
      attr :age, :integer, required: true

      def celebrate(assigns) do
        ~H"""
        <p>
          Happy birthday <%= @name %>!
          You are <%= @age %> years old.
        <p>
        """
      end

  Allowing the caller to pass multiple values:

      <.celebrate name={"Genevieve"} age={34} />

  Rendering the following HTML:

      <p>
        Happy birthday Genevieve!
        You are 34 years old.
      </p>

  With the `attr/3` macro you have the core ingredients to create reusable function components.
  But what if you need your function components to support dynamic attributes, such as common HTML 
  attributes to mix into a component's container?

  ### Global Attributes

  Global attributes are a set of attributes that a function component can accept when it
  declares an attribute of type `:global`. By default, the set of attributes accepted are those
  [common to all HTML elements](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes).
  Once a global attribute is declared, any number of attributes in the set can be passed by
  the caller without having to modify the function componet itself.

  Below is an example of a function component that accepts a dynamic number of global attributes:

      attr :message, :string, required: true
      attr :rest, :global

      def notification(assigns) do
        ~H"""
        <span {@rest}><%= @message %></span>
        """
      end

  The caller can pass multiple global attributes (such as `phx-*` bindings or the `class` attribute):

      <.notification message="You've got mail!" class="bg-green-200" phx-click="close" />

  Rendering the following HTML:

      <span class="bg-green-200" phx-click="close">You've got mail!</span>

  Note that the function component did not have to explicitly declare a `class` or `phx-click` 
  attribute in order to render. 

  Global attribute can define defaults which are merged with attributes provided by the caller. 
  For example, you may declare a default `class` if the caller does not provide one:

      attr :rest, :global, default: %{class: "bg-blue-200"}

  Now you can call the function component without a `class` attribute:

      <.notification message="You've got mail!" phx-click="close" />

  Rendering the following HTML:

      <span class="bg-blue-200" phx-click="close">You've got mail!</span>

  ### Custom Global Attribute Prefixes

  You can extend the set of global attributes by providing a list of attribute prefixes to
  `use Phoenix.Component`. Like the default attributes common to all HTML elements, 
  any number of attributes with that start with a global prefix will be accepted by function
  components defined in this module. By default, the following prefixes are supported: 
  `phx-`, `aria-`, and `data-`. For example, to support the `x-` prefix used by 
  [Alpine.js](https://alpinejs.dev/), you can pass the `:global_prefixes` option to 
  `use Phoenix.Component`:

      use Phoenix.Component, global_prefixes: ~w(x-)

  Now all function components defined in this module will accept any number of attributes prefixed
  with `x-`, in addition to the default global prefixes.

  You can learn more about attributes by reading the documentation for `Phoenix.Component.attr/3`.

  ## Slots

  In addition to attributes, function components can accept blocks of HEEx content, referred to as
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

      <.button>
        This renders <strong>inside</strong> the button!
      </.button>

  Which renderes the following HTML:

      <button>
        This renders <strong>inside</strong> the button!
      </button>

  Like the `attr/3` macro, using the `slot/3` macro will provide compile-time validations. 
  For example, invoking `button/1` without a slot of HEEx content will result in a compilation 
  warning being emitted:

      <.button />
        warning: missing required slot "inner_block" for component MyAppWeb.MyComponent.button/1
                 lib/app_web/my_component.ex:15

  ### The Default Slot

  The example above uses the default slot, accesible as an assign named `@inner_block`, to render 
  HEEx content via the `Phoenix.LiveView.Helpers.render_slot/2` function.

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

      <.unordered_list :let={fruit} entries={~w(apples bananas cherries)}>
        I like <%= fruit %>!
      </.unordered_list>

  Rendering the following HTML:

      <ul>
        <li>I like apples!</li>
        <li>I like bananas!</li>
        <li>I like cherries!</li>
      </ul>

  Now the separation of concerns is maintained: the caller can specify multiple values in a list
  attribute without having to specify the HEEx content that surrounds and separates them.

  ### Named Slots

  In addition to the default slot, function components can accept multiple, named slots of HEEx
  content. For example, imagine you want to create a modal that has a header, body, and footer:

      slot :header
      slot :inner_block
      slot :footer

      def modal(assigns) do
        ~H"""
        <div class="modal">
          <div class="modal-header">
            <%= render_slot(@header) %>
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

      <.modal>
        <:header>
          This is the top of the modal.
        </:header>
        This is the body, everything not in a named slot is rendered in the default slot.
        <:footer>
          This is the bottom of the modal.
        </:footer>
      </.modal>

  Rendering the following HTML:

      <div class="modal">
        <div class="modal-header">
          This is the top of the modal.
        </div>
        <div class="modal-body">
          This is the body, everything not in a named slot is rendered in the default slot.
        </div>
        <div class="modal-footer">
          This is the bottom of the modal.
        </div>
      </div>

  ### Slot Attributes

  Unlike the default slot, it is possible to pass a named slot multiple pieces of HEEx content. 
  Named slots can also accept attributes, defined by passing a block to the `slot/3` macro. 
  If multiple pieces of content are passed,`Phoenix.LiveView.Helpers.render_slot/2` will merge 
  and render all the values.

  Below is a table component illustrating multiple named slots with attributes:

      slot :column do
        attr :label, :string, required: true
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

      <.table rows={[%{name: "Jane", age: "34"}, %{name: "Bob", age: "51"}]}>
        <:column :let={user} label="Name">
          <%= user.name %>
        </:column>
        <:column :let={user} label="Age">
          <%= user.age %>
        </:column>    
      </.table>

  Rendering the following HTML:

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

  You can learn more about slots and the `slot/3` macro [in its documentation](`Phoenix.Component.slot/3`).
  '''

  @global_prefixes ~w(
    phx-
    aria-
    data-
  )
  @globals ~w(
    xml:lang
    xml:base
    onabort
    onautocomplete
    onautocompleteerror
    onblur
    oncancel
    oncanplay
    oncanplaythrough
    onchange
    onclick
    onclose
    oncontextmenu
    oncuechange
    ondblclick
    ondrag
    ondragend
    ondragenter
    ondragleave
    ondragover
    ondragstart
    ondrop
    ondurationchange
    onemptied
    onended
    onerror
    onfocus
    oninput
    oninvalid
    onkeydown
    onkeypress
    onkeyup
    onload
    onloadeddata
    onloadedmetadata
    onloadstart
    onmousedown
    onmouseenter
    onmouseleave
    onmousemove
    onmouseout
    onmouseover
    onmouseup
    onmousewheel
    onpause
    onplay
    onplaying
    onprogress
    onratechange
    onreset
    onresize
    onscroll
    onseeked
    onseeking
    onselect
    onshow
    onsort
    onstalled
    onsubmit
    onsuspend
    ontimeupdate
    ontoggle
    onvolumechange
    onwaiting
    accesskey
    autocapitalize
    autofocus
    class
    contenteditable
    contextmenu
    dir
    draggable
    enterkeyhint
    exportparts
    hidden
    id
    inputmode
    is
    itemid
    itemprop
    itemref
    itemscope
    itemtype
    lang
    nonce
    part
    role
    slot
    spellcheck
    style
    tabindex
    target
    title
    translate
  )

  @doc false
  def __global__?(module, name) when is_atom(module) and is_binary(name) do
    if function_exported?(module, :__global__?, 1) do
      module.__global__?(name) or __global__?(name)
    else
      __global__?(name)
    end
  end

  for prefix <- @global_prefixes do
    def __global__?(unquote(prefix) <> _), do: true
  end

  for name <- @globals do
    def __global__?(unquote(name)), do: true
  end

  def __global__?(_), do: false

  @doc false
  def __reserved_assigns__, do: [:__changed__, :__slot__, :inner_block, :myself, :flash, :socket]

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
        import Phoenix.LiveView

        @doc false
        for prefix <- Phoenix.Component.__setup__(__MODULE__, opts) do
          def __global__?(unquote(prefix) <> _), do: true
        end

        def __global__?(_), do: false
      end

    [conditional, imports]
  end

  @doc false
  @valid_opts [:global_prefixes]
  def __setup__(module, opts) do
    {prefixes, invalid_opts} = Keyword.pop(opts, :global_prefixes, [])

    for prefix <- prefixes do
      unless String.ends_with?(prefix, "-") do
        raise ArgumentError,
              "global prefixes for #{inspect(module)} must end with a dash, got: #{inspect(prefix)}"
      end
    end

    if invalid_opts != [] do
      raise ArgumentError, """
      invalid options passed to #{inspect(__MODULE__)}.

      The following options are supported: #{inspect(@valid_opts)}, got: #{inspect(invalid_opts)}
      """
    end

    Module.register_attribute(module, :__attrs__, accumulate: true)
    Module.register_attribute(module, :__slot_attrs__, accumulate: true)
    Module.register_attribute(module, :__slots__, accumulate: true)
    Module.register_attribute(module, :__slot__, accumulate: false)
    Module.register_attribute(module, :__components_calls__, accumulate: true)
    Module.put_attribute(module, :__components__, %{})
    Module.put_attribute(module, :on_definition, __MODULE__)
    Module.put_attribute(module, :before_compile, __MODULE__)

    prefixes
  end

  @doc ~S'''
  Declares a function component slot.

  ## Arguments

  * `name` - an atom defining the name of the slot. Note that slots cannot define the same name 
  as any other slots or attributes declared for the same component.
  * `opts` - a keyword list of options. Defaults to `[]`.
  * `block` - a code block containing calls to `Phoenix.Component.attr/3`. Defaults to `nil`.

  ### Options

  * `:required` - marks a slot as required. If a caller does not pass a value for a required slot, 
  a compilation warning is emitted. Otherwise, an omitted slot will default to `[]`.
  * `:doc` - documentation for the slot. Any slot attributes declared
  will have their documentation listed alongside the slot.

  ### Slot Attributes

  A named slot may declare attributes by passing a block with calls to `Phoenix.Component.attr/3`.

  Unlike attributes, slot attributes cannot accept the `:default` option. Passing one
  will result in a compile warning being issued.

  ### The Default Slot

  The default slot can be declared by passing `:inner_block` as the `name` of the slot.

  Note that the default slot cannot accept a block. Passing one will result in a compilation
  warning being emitted.

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

  Public function components that define slots will have their docs 
  injected into the function's documentation, depending on the value 
  of the `@doc` module attribute:

  * if `@doc` is a string, the slot docs are injected into that string.
    The optional placeholder `[[INJECT LVDOCS]]` can be used to specify where
    in the string the docs are injected. Otherwise, the docs are appended
    to the end of the `@doc` string.

  * if `@doc` is unspecified, the slot docs are used as the
    default `@doc` string.

  * if `@doc` is `false`, the slot docs are omitted entirely.

  The injected slot docs are formatted as a markdown list:

    * `name` (required) - slot docs. Accepts attributes:
      * `name` (`:type`) (required) - attr docs. Defaults to `:default`.

  By default, all slots will have their docs injected into
  the function `@doc` string. To hide a specific slot, you can set
  the value of `:doc` to `false`.

  ## Example
    
      slot :header
      slot :inner_block
      slot :footer

      def modal(assigns) do
        ~H"""
        <div class="modal">
          <div class="modal-header">
            <%= render_slot(@header) %>
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
  '''
  defmacro slot(name, opts, block)

  defmacro slot(name, opts, do: block) when is_atom(name) and is_list(opts) do
    quote do
      Phoenix.Component.__slot__!(
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
  Declares a slot. See `Phoenix.Component.slot/3` for more information.
  """
  defmacro slot(name, opts \\ []) when is_atom(name) and is_list(opts) do
    {block, opts} = Keyword.pop(opts, :do, nil)

    quote do
      Phoenix.Component.__slot__!(
        __MODULE__,
        unquote(name),
        unquote(opts),
        __ENV__.line,
        __ENV__.file,
        fn -> unquote(block) end
      )
    end
  end

  @doc false
  def __slot__!(module, name, opts, line, file, block_fun) do
    {doc, opts} = Keyword.pop(opts, :doc, nil)

    unless is_binary(doc) or is_nil(doc) or doc == false do
      compile_error!(line, file, ":doc must be a string or false, got: #{inspect(doc)}")
    end

    {required, opts} = Keyword.pop(opts, :required, false)

    unless is_boolean(required) do
      compile_error!(line, file, ":required must be a boolean, got: #{inspect(required)}")
    end

    Module.put_attribute(module, :__slot__, name)

    slot_attrs =
      try do
        block_fun.()
        module |> Module.get_attribute(:__slot_attrs__) |> Enum.reverse()
      after
        Module.put_attribute(module, :__slot__, nil)
        Module.delete_attribute(module, :__slot_attrs__)
      end

    slot = %{
      name: name,
      required: required,
      opts: opts,
      doc: doc,
      line: line,
      attrs: slot_attrs
    }

    validate_slot!(module, slot, line, file)
    Module.put_attribute(module, :__slots__, slot)
    :ok
  end

  defp validate_slot!(module, slot, line, file) do
    slots = Module.get_attribute(module, :__slots__) || []

    if Enum.find(slots, &(&1.name == slot.name)) do
      compile_error!(line, file, """
      a duplicate slot with name #{inspect(slot.name)} already exists\
      """)
    end

    if slot.name == :inner_block and slot.attrs != [] do
      compile_error!(line, file, """
      cannot define attributes in a slot with name #{inspect(slot.name)}
      """)
    end
  end

  @doc ~S'''
  Declares attributes for a HEEx function components.

  ## Arguments

  * `name` - an atom defining the name of the attribute. Note that attributes cannot define
  the same name as any other attributes or slots declared for the same component.
  * `type` - an atom defining the type of the attribute.
  * `opts` - a keyword list of options. Defaults to `[]`.

  ### Types

  An attribute is declared by its name, type, and options. The following types are supported:


  | Name            | Description                                                                     |
  |-----------------|---------------------------------------------------------------------------------|
  | `:any`          | any term                                                                        |
  | `:string`       | any binary string                                                               |
  | `:atom`         | any atom (including `true`, `false`, and `nil`)                                 |
  | `:boolean`      | any boolean                                                                     |
  | `:integer`      | any integer                                                                     |
  | `:float`        | any float                                                                       |
  | `:list`         | a list of any arbitrary types                                                   |
  | `:global`       | any undefined, common HTML attributes, plus those defined by `:global_prefixes` |
  | A struct module | any module that defines a struct with `defstruct/1`                             |


  ### Options

  * `:required` - marks an attribute as required. If a caller does not pass
    the given attribute, a compile warning is issued.
  * `:default` - the default value for the attribute if not provided.
  * `:doc` - documentation for the attribute.

  ## Compile-Time Validations

  LiveView performs some validation of attributes via the `:phoenix_live_view`
  compiler. When attributes are defined, LiveView will warn at compilation
  time on the caller if:

  * A required attribute of a component is missing.

  * An unknown attribute is given.

  * You specify a literal attribute (such as `value="string"` or `value`,
    but not `value={expr}`) and the type does not match. The following
    types currently support literal validation: `:string`, `:atom`, `:boolean`, 
    `:integer`, `:float`, `:list`.

  LiveView does not perform any validation at runtime. This means the type
  information is mostly used for documentation and reflection purposes.

  On the side of the LiveView component itself, defining attributes provides
  the following quality of life improvements:

  * The default value of all attributes will be added to the `assigns`
    map upfront. Note that unless an attribute is marked as required 
    or has a default defined, omitting a value for an attribute will 
    result in `nil` being passed as the default value to the `assigns`
    map, regardless of the type defined for the attribute.
      
  * Attribute documentation is generated for the component.

  * Required struct types are annotated and emit compilation warnings.
    For example, if you specify `attr :user, User, required: true` and
    then you write `@user.non_valid_field` in your template, a warning
    will be emitted.
    
  * Calls made to the component are tracked for reflection and 
    validation purposes.

  ## Documentation Generation

  Public function components that define attributes will have their attribute
  types and docs injected into the function's documentation, depending on the
  value of the `@doc` module attribute:

  * if `@doc` is a string, the attribute docs are injected into that string.
    The optional placeholder `[[INJECT LVDOCS]]` can be used to specify where
    in the string the docs are injected. Otherwise, the docs are appended
    to the end of the `@doc` string.

  * if `@doc` is unspecified, the attribute docs are used as the
    default `@doc` string.

  * if `@doc` is `false`, the attribute docs are omitted entirely.

  The injected attribute docs are formatted as a markdown list:

    * `name` (`:type`) (required) - attr docs. Defaults to `:default`.

  By default, all attributes will have their types and docs injected into
  the function `@doc` string. To hide a specific attribute, you can set
  the value of `:doc` to `false`.

  ## Example
    
      attr :name, :string, required: true
      attr :age, :integer, required: true

      def celebrate(assigns) do
        ~H"""
        <p>
          Happy birthday <%= @name %>!
          You are <%= @age %> years old.
        <p>
        """
      end
  '''
  defmacro attr(name, type, opts \\ []) when is_atom(name) and is_list(opts) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      Phoenix.Component.__attr__!(
        __MODULE__,
        @__slot__,
        name,
        type,
        opts,
        __ENV__.line,
        __ENV__.file
      )
    end
  end

  @doc false
  def __attr__!(module, slot, name, type, opts, line, file) do
    if name == :inner_block do
      compile_error!(
        line,
        file,
        "cannot define attribute called :inner_block. Maybe you wanted to use `slot` instead?"
      )
    end

    if type == :global and Keyword.has_key?(opts, :required) do
      compile_error!(line, file, "global attributes do not support the :required option")
    end

    {doc, opts} = Keyword.pop(opts, :doc, nil)

    unless is_binary(doc) or is_nil(doc) or doc == false do
      compile_error!(line, file, ":doc must be a string or false, got: #{inspect(doc)}")
    end

    {required, opts} = Keyword.pop(opts, :required, false)

    unless is_boolean(required) do
      compile_error!(line, file, ":required must be a boolean, got: #{inspect(required)}")
    end

    if required and Keyword.has_key?(opts, :default) do
      compile_error!(line, file, "only one of :required or :default must be given")
    end

    key = if slot, do: :__slot_attrs__, else: :__attrs__
    type = validate_attr_type!(module, key, slot, name, type, line, file)
    validate_attr_opts!(slot, name, opts, line, file)

    if Keyword.has_key?(opts, :default) do
      validate_attr_default!(slot, name, type, opts[:default], line, file)
    end

    attr = %{
      slot: slot,
      name: name,
      type: type,
      required: required,
      opts: opts,
      doc: doc,
      line: line
    }

    Module.put_attribute(module, key, attr)
    :ok
  end

  @builtin_types [:boolean, :integer, :float, :string, :atom, :list, :map, :global]
  @valid_types [:any] ++ @builtin_types

  defp validate_attr_type!(module, key, slot, name, type, line, file) when is_atom(type) do
    attrs = Module.get_attribute(module, key) || []

    cond do
      Enum.find(attrs, fn attr -> attr.name == name end) ->
        compile_error!(line, file, """
        a duplicate attribute with name #{attr_slot(name, slot)} already exists\
        """)

      existing = type == :global && Enum.find(attrs, fn attr -> attr.type == :global end) ->
        compile_error!(line, file, """
        cannot define :global attribute #{inspect(name)} because one \
        is already defined as #{attr_slot(existing.name, slot)}. \
        Only a single :global attribute may be defined\
        """)

      true ->
        :ok
    end

    case Atom.to_string(type) do
      "Elixir." <> _ -> {:struct, type}
      _ when type in @valid_types -> type
      _ -> bad_type!(slot, name, type, line, file)
    end
  end

  defp validate_attr_type!(_module, _key, slot, name, type, line, file) do
    bad_type!(slot, name, type, line, file)
  end

  defp bad_type!(slot, name, type, line, file) do
    compile_error!(line, file, """
    invalid type #{inspect(type)} for attr #{attr_slot(name, slot)}. \
    The following types are supported:

      * any Elixir struct, such as URI, MyApp.User, etc
      * one of #{Enum.map_join(@builtin_types, ", ", &inspect/1)}
      * :any for all other types
    """)
  end

  defp attr_slot(name, nil), do: "#{inspect(name)}"
  defp attr_slot(name, slot), do: "#{inspect(name)} in slot #{inspect(slot)}"

  defp validate_attr_default!(slot, name, type, default, line, file) do
    case {type, default} do
      {_type, nil} ->
        :ok

      {:any, _default} ->
        :ok

      {:string, default} when not is_binary(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:atom, default} when not is_atom(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:boolean, default} when not is_boolean(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:integer, default} when not is_integer(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:float, default} when not is_float(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:list, default} when not is_list(default) ->
        bad_default!(slot, name, type, default, line, file)

      {{:struct, mod}, default} when not is_struct(default) ->
        bad_default!(slot, name, mod, default, line, file)

      {_type, _default} ->
        :ok
    end
  end

  defp bad_default!(slot, name, type, default, line, file) do
    compile_error!(line, file, """
    expected the default value for attr #{attr_slot(name, slot)} to be #{type_with_article(type)}, \
    got: #{inspect(default)}
    """)
  end

  defp validate_attr_opts!(slot, name, opts, line, file) do
    for {key, _} <- opts, message = invalid_attr_message(key, slot) do
      compile_error!(line, file, """
      invalid option #{inspect(key)} for attr #{attr_slot(name, slot)}. #{message}\
      """)
    end
  end

  defp invalid_attr_message(:default, nil), do: nil

  defp invalid_attr_message(:default, _),
    do:
      ":default is not supported inside slot attributes, " <>
        "instead use Map.get/3 with a default value when accessing a slot attribute"

  defp invalid_attr_message(:required, _), do: nil
  defp invalid_attr_message(_key, nil), do: "The supported options are: [:required, :default]"

  defp invalid_attr_message(_key, _slot),
    do: "The supported options inside slots are: [:required]"

  defp compile_error!(line, file, msg) do
    raise CompileError, line: line, file: file, description: msg
  end

  @doc false
  defmacro def(expr, body) do
    quote do
      Kernel.def(unquote(annotate_def(:def, expr)), unquote(body))
    end
  end

  @doc false
  defmacro defp(expr, body) do
    quote do
      Kernel.defp(unquote(annotate_def(:defp, expr)), unquote(body))
    end
  end

  defp annotate_def(kind, expr) do
    case expr do
      {:when, meta, [left, right]} -> {:when, meta, [annotate_call(kind, left), right]}
      left -> annotate_call(kind, left)
    end
  end

  defp annotate_call(_kind, {name, meta, [{:\\, _, _} = arg]}), do: {name, meta, [arg]}

  defp annotate_call(kind, {name, meta, [arg]}),
    do: {name, meta, [quote(do: unquote(__MODULE__).__pattern__!(unquote(kind), unquote(arg)))]}

  defp annotate_call(_kind, left),
    do: left

  defmacro __pattern__!(kind, arg) do
    {name, 1} = __CALLER__.function
    {_slots, attrs} = register_component!(kind, __CALLER__, name, true)

    fields =
      for %{name: name, required: true, type: {:struct, struct}} <- attrs do
        {name, quote(do: %unquote(struct){})}
      end

    if fields == [] do
      arg
    else
      quote(do: %{unquote_splicing(fields)} = unquote(arg))
    end
  end

  @doc false
  def __on_definition__(env, kind, name, args, _guards, body) do
    case args do
      [_] when body == nil ->
        register_component!(kind, env, name, false)

      _ ->
        attrs = pop_attrs(env)

        validate_misplaced_attrs!(attrs, env.file, fn ->
          case length(args) do
            1 ->
              "could not define attributes for function #{name}/1. " <>
                "Components cannot be dynamically defined or have default arguments"

            arity ->
              "cannot declare attributes for function #{name}/#{arity}. Components must be functions with arity 1"
          end
        end)

        slots = pop_slots(env)

        validate_misplaced_slots!(slots, env.file, fn ->
          case length(args) do
            1 ->
              "could not define slots for function #{name}/1. " <>
                "Components cannot be dynamically defined or have default arguments"

            arity ->
              "cannot declare slots for function #{name}/#{arity}. Components must be functions with arity 1"
          end
        end)
    end
  end

  @after_verify_supported Version.match?(System.version(), ">= 1.14.0-dev")

  @doc false
  defmacro __before_compile__(env) do
    attrs = pop_attrs(env)

    validate_misplaced_attrs!(attrs, env.file, fn ->
      "cannot define attributes without a related function component"
    end)

    slots = pop_slots(env)

    validate_misplaced_slots!(slots, env.file, fn ->
      "cannot define slots without a related function component"
    end)

    components = Module.get_attribute(env.module, :__components__)
    components_calls = Module.get_attribute(env.module, :__components_calls__) |> Enum.reverse()

    names_and_defs =
      for {name, %{kind: kind, attrs: attrs, slots: slots}} <- components do
        attr_defaults =
          for %{name: name, required: false, opts: opts} <- attrs,
              Keyword.has_key?(opts, :default) do
            {name, Macro.escape(opts[:default])}
          end

        slot_defaults =
          for %{name: name, required: false} <- slots do
            {name, []}
          end

        defaults = attr_defaults ++ slot_defaults

        {global_name, global_default} =
          case Enum.find(attrs, fn attr -> attr.type == :global end) do
            %{name: name, opts: opts} -> {name, Macro.escape(Keyword.get(opts, :default, %{}))}
            nil -> {nil, nil}
          end

        attr_names = for(attr <- attrs, do: attr.name)
        slot_names = for(slot <- slots, do: slot.name)
        known_keys = attr_names ++ slot_names ++ __reserved_assigns__()

        def_body =
          if global_name do
            quote do
              {assigns, caller_globals} = Map.split(assigns, unquote(known_keys))

              globals =
                case assigns do
                  %{unquote(global_name) => explicit_global_assign} -> explicit_global_assign
                  %{} -> Map.merge(unquote(global_default), caller_globals)
                end

              merged = Map.merge(%{unquote_splicing(defaults)}, assigns)
              super(Phoenix.LiveView.assign(merged, unquote(global_name), globals))
            end
          else
            quote do
              super(Map.merge(%{unquote_splicing(defaults)}, assigns))
            end
          end

        merge =
          quote do
            Kernel.unquote(kind)(unquote(name)(assigns)) do
              unquote(def_body)
            end
          end

        {{name, 1}, merge}
      end

    {names, defs} = Enum.unzip(names_and_defs)

    overridable =
      if names != [] do
        quote do
          defoverridable unquote(names)
        end
      end

    def_components_ast =
      quote do
        def __components__() do
          unquote(Macro.escape(components))
        end
      end

    def_components_calls_ast =
      if components_calls != [] and @after_verify_supported do
        quote do
          @after_verify {__MODULE__, :__phoenix_component_verify__}

          @doc false
          def __phoenix_component_verify__(module) do
            Phoenix.Component.__verify__(module, unquote(Macro.escape(components_calls)))
          end
        end
      end

    {:__block__, [], [def_components_ast, def_components_calls_ast, overridable | defs]}
  end

  defp register_component!(kind, env, name, check_if_defined?) do
    slots = pop_slots(env)
    attrs = pop_attrs(env)

    cond do
      slots != [] or attrs != [] ->
        check_if_defined? and raise_if_function_already_defined!(env, name, slots, attrs)
        register_component_doc(env, kind, slots, attrs)

        for %{name: slot_name, line: line} <- slots,
            Enum.find(attrs, &(&1.name == slot_name)) do
          compile_error!(line, env.file, """
          cannot define a slot with name #{inspect(slot_name)}, as an attribute with that name already exists\
          """)
        end

        components =
          env.module
          |> Module.get_attribute(:__components__)
          # Sort by name as this is used when they are validated
          |> Map.put(name, %{
            kind: kind,
            attrs: Enum.sort_by(attrs, & &1.name),
            slots: Enum.sort_by(slots, & &1.name)
          })

        Module.put_attribute(env.module, :__components__, components)
        Module.put_attribute(env.module, :__last_component__, name)
        {slots, attrs}

      Module.get_attribute(env.module, :__last_component__) == name ->
        %{slots: slots, attrs: attrs} = Module.get_attribute(env.module, :__components__)[name]
        {slots, attrs}

      true ->
        {[], []}
    end
  end

  # Documentation handling

  defp register_component_doc(env, :def, slots, attrs) do
    case Module.get_attribute(env.module, :doc) do
      {_line, false} ->
        :ok

      {line, doc} ->
        Module.put_attribute(env.module, :doc, {line, build_component_doc(doc, slots, attrs)})

      nil ->
        Module.put_attribute(env.module, :doc, {env.line, build_component_doc(slots, attrs)})
    end
  end

  defp register_component_doc(_env, :defp, _slots, _attrs) do
    :ok
  end

  defp build_component_doc(doc \\ "", slots, attrs) do
    [left | right] = String.split(doc, "[[INSERT LVDOCS]]")

    IO.iodata_to_binary([
      build_left_doc(left),
      build_component_docs(slots, attrs),
      build_right_doc(right)
    ])
  end

  defp build_left_doc("") do
    [""]
  end

  defp build_left_doc(left) do
    [left, ?\n]
  end

  defp build_component_docs(slots, attrs) do
    case {slots, attrs} do
      {[], []} ->
        []

      {slots, [] = _attrs} ->
        [build_slots_docs(slots)]

      {[] = _slots, attrs} ->
        [build_attrs_docs(attrs)]

      {slots, attrs} ->
        [build_attrs_docs(attrs), ?\n, build_slots_docs(slots)]
    end
  end

  defp build_slots_docs(slots) do
    [
      "## Slots",
      ?\n,
      for slot <- slots, slot.doc != false, into: [] do
        slot_attrs =
          for slot_attr <- slot.attrs,
              slot_attr.doc != false,
              slot_attr.slot == slot.name,
              do: slot_attr

        [
          ?\n,
          "* ",
          build_slot_name(slot),
          build_slot_required(slot),
          build_slot_doc(slot, slot_attrs)
        ]
      end
    ]
  end

  defp build_attrs_docs(attrs) do
    [
      "## Attributes",
      ?\n,
      for attr <- attrs, attr.doc != false, into: [] do
        [
          ?\n,
          "* ",
          build_attr_name(attr),
          build_attr_type(attr),
          build_attr_required(attr),
          build_attr_doc_and_default(attr)
        ]
      end
    ]
  end

  defp build_slot_name(%{name: name}) do
    ["`", Atom.to_string(name), "`"]
  end

  defp build_slot_doc(%{doc: nil}, []) do
    []
  end

  defp build_slot_doc(%{doc: doc}, []) do
    [" - ", doc]
  end

  defp build_slot_doc(%{doc: nil}, slot_attrs) do
    ["Accepts attributes: ", build_slot_attrs_docs(slot_attrs)]
  end

  defp build_slot_doc(%{doc: doc}, slot_attrs) do
    [" - ", doc, ". Accepts attributes: ", build_slot_attrs_docs(slot_attrs)]
  end

  defp build_slot_attrs_docs(slot_attrs) do
    for slot_attr <- slot_attrs do
      [
        ?\n,
        ?\t,
        "* ",
        build_attr_name(slot_attr),
        build_attr_type(slot_attr),
        build_attr_required(slot_attr),
        build_attr_doc_and_default(slot_attr)
      ]
    end
  end

  defp build_slot_required(%{required: true}) do
    [" (required)"]
  end

  defp build_slot_required(_slot) do
    []
  end

  defp build_attr_name(%{name: name}) do
    ["`", Atom.to_string(name), "` "]
  end

  defp build_attr_type(%{type: {:struct, type}}) do
    ["(`", inspect(type), "`)"]
  end

  defp build_attr_type(%{type: type}) do
    ["(`", inspect(type), "`)"]
  end

  defp build_attr_required(%{required: true}) do
    [" (required)"]
  end

  defp build_attr_required(_attr) do
    []
  end

  defp build_attr_doc_and_default(%{doc: nil, opts: [default: default]}) do
    [" - Defaults to `", inspect(default), "`."]
  end

  defp build_attr_doc_and_default(%{doc: doc, opts: [default: default]}) do
    [" - ", doc, ". Defaults to `", inspect(default), "`."]
  end

  defp build_attr_doc_and_default(%{doc: nil}) do
    []
  end

  defp build_attr_doc_and_default(%{doc: doc}) do
    [" - ", doc]
  end

  defp build_right_doc("") do
    [""]
  end

  defp build_right_doc(right) do
    [?\n, right]
  end

  defp validate_misplaced_attrs!(attrs, file, message_fun) do
    with [%{line: first_attr_line} | _] <- attrs do
      compile_error!(first_attr_line, file, message_fun.())
    end
  end

  defp validate_misplaced_slots!(slots, file, message_fun) do
    with [%{line: first_slot_line} | _] <- slots do
      compile_error!(first_slot_line, file, message_fun.())
    end
  end

  defp pop_attrs(env) do
    slots = Module.delete_attribute(env.module, :__attrs__) || []
    Enum.reverse(slots)
  end

  defp pop_slots(env) do
    slots = Module.delete_attribute(env.module, :__slots__) || []
    Enum.reverse(slots)
  end

  defp raise_if_function_already_defined!(env, name, slots, attrs) do
    if Module.defines?(env.module, {name, 1}) do
      {:v1, _, meta, _} = Module.get_definition(env.module, {name, 1})

      with [%{line: first_attr_line} | _] <- attrs do
        compile_error!(first_attr_line, env.file, """
        attributes must be defined before the first function clause at line #{meta[:line]}
        """)
      end

      with [%{line: first_slot_line} | _] <- slots do
        compile_error!(first_slot_line, env.file, """
        slots must be defined before the first function clause at line #{meta[:line]}
        """)
      end
    end
  end

  # Verification

  @doc false
  def __verify__(module, component_calls) do
    for %{component: {submod, fun}} = call <- component_calls,
        function_exported?(submod, :__components__, 0),
        component = submod.__components__()[fun],
        do: verify(module, call, component)

    :ok
  end

  defp verify(
         caller_module,
         %{slots: slots, attrs: attrs, root: root} = call,
         %{slots: slots_defs, attrs: attrs_defs}
       ) do
    {attrs, has_global?} =
      Enum.reduce(attrs_defs, {attrs, false}, fn attr_def, {attrs, has_global?} ->
        %{name: name, required: required, type: type} = attr_def
        {value, attrs} = Map.pop(attrs, name)

        case {type, value} do
          # missing required attr
          {_type, nil} when not root and required ->
            message = "missing required attribute \"#{name}\" for component #{component_fa(call)}"
            warn(message, call.file, call.line)

          # missing optional attr, or dynamic attr
          {_type, nil} when root or not required ->
            :ok

          # global attrs cannot be directly used
          {:global, {line, _column, _type_value}} ->
            message =
              "global attribute \"#{name}\" in component #{component_fa(call)} may not be provided directly"

            warn(message, call.file, line)

          {type, {line, _column, type_value}} ->
            if value_ast_to_string = type_mismatch(type, type_value) do
              message =
                "attribute \"#{name}\" in component #{component_fa(call)} must be #{type_with_article(type)}, got: " <>
                  value_ast_to_string

              [warn(message, call.file, line)]
            end
        end

        {attrs, has_global? || type == :global}
      end)

    for {name, {line, _column, _type_value}} <- attrs,
        not (has_global? and __global__?(caller_module, Atom.to_string(name))) do
      message = "undefined attribute \"#{name}\" for component #{component_fa(call)}"
      warn(message, call.file, line)
    end

    slots =
      Enum.reduce(slots_defs, slots, fn slot_def, slots ->
        %{name: slot_name, required: required, attrs: attrs} = slot_def
        {slot_values, slots} = Map.pop(slots, slot_name)

        case slot_values do
          # missing required slot
          nil when required ->
            message = "missing required slot \"#{slot_name}\" for component #{component_fa(call)}"
            warn(message, call.file, call.line)

          # missing optional slot
          nil ->
            :ok

          # slot with attributes
          _ ->
            has_global? = Enum.any?(attrs, &(&1.type == :global))
            slot_attr_defs = Enum.into(attrs, %{}, &{&1.name, &1})
            required_attrs = for {attr_name, %{required: true}} <- slot_attr_defs, do: attr_name

            for %{attrs: slot_attrs, line: slot_line, root: false} <- slot_values,
                attr_name <- required_attrs,
                not Map.has_key?(slot_attrs, attr_name) do
              message =
                "missing required attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                  "for component #{component_fa(call)}"

              warn(message, call.file, slot_line)
            end

            for %{attrs: slot_attrs} <- slot_values,
                {attr_name, {line, _column, type_value}} <- slot_attrs do
              case slot_attr_defs do
                %{^attr_name => %{type: :global}} ->
                  message =
                    "global attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                      "for component #{component_fa(call)} may not be provided directly"

                  warn(message, call.file, line)

                %{^attr_name => %{type: type}} ->
                  if value_ast_to_string = type_mismatch(type, type_value) do
                    message =
                      "attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                        "for component #{component_fa(call)} must be #{type_with_article(type)}, got: " <>
                        value_ast_to_string

                    warn(message, call.file, line)
                  end

                # undefined attribute
                %{} ->
                  if attr_name == :inner_block or
                       (has_global? and __global__?(caller_module, Atom.to_string(attr_name))) do
                    :ok
                  else
                    message =
                      "undefined attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                        "for component #{component_fa(call)}"

                    warn(message, call.file, line)
                  end
              end
            end
        end

        slots
      end)

    for {slot_name, slot_values} <- slots,
        slot_name != :inner_block,
        %{line: line} <- slot_values do
      message = "undefined slot \"#{slot_name}\" for component #{component_fa(call)}"
      warn(message, call.file, line)
    end

    :ok
  end

  defp type_mismatch(:any, _type_value), do: nil
  defp type_mismatch(_type, :any), do: nil
  defp type_mismatch(type, {type, _value}), do: nil
  defp type_mismatch(:atom, {:boolean, _value}), do: nil
  defp type_mismatch(_type, {_, value}), do: Macro.to_string(value)

  defp component_fa(%{component: {mod, fun}}) do
    "#{inspect(mod)}.#{fun}/1"
  end

  ## Shared helpers

  defp type_with_article(type) when type in [:atom, :integer], do: "an #{inspect(type)}"
  defp type_with_article(type), do: "a #{inspect(type)}"

  # TODO: Provide column information in error messages
  # TODO: Also validate local function component calls (and what about private components?)
  defp warn(message, file, line) do
    IO.warn(message, file: file, line: line)
  end
end

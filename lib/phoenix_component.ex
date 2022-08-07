defmodule Phoenix.Component do
  @moduledoc ~S'''
  API for function components.

  A function component is any function that receives
  an assigns map as argument and returns a rendered
  struct built with [the `~H` sigil](`Phoenix.LiveView.Helpers.sigil_H/2`).

  Here is an example:

      defmodule MyComponent do
        use Phoenix.Component

        # Optionally also bring the HTML helpers
        # use Phoenix.HTML

        def greet(assigns) do
          ~H"""
          <p>Hello, <%= assigns.name %></p>
          """
        end
      end

  The component can be invoked as a regular function:

      MyComponent.greet(%{name: "Jane"})

  But it is typically invoked using the function component
  syntax from the `~H` sigil:

      ~H"""
      <MyComponent.greet name="Jane" />
      """

  If the `MyComponent` module is imported or if the function
  is defined locally, you can skip the module name:

      ~H"""
      <.greet name="Jane" />
      """

  Similar to any HTML tag inside the `~H` sigil, you can
  interpolate attributes values too:

      ~H"""
      <.greet name={@user.name} />
      """

  You can learn more about the `~H` sigil [in its documentation](`Phoenix.LiveView.Helpers.sigil_H/2`).

  ## `use Phoenix.Component`

  Modules that define function components should call
  `use Phoenix.Component` at the top. Doing so will import
  the functions from both `Phoenix.LiveView` and
  `Phoenix.LiveView.Helpers` modules. `Phoenix.LiveView`
  and `Phoenix.LiveComponent` automatically invoke
  `use Phoenix.Component` for you.

  You must avoid defining a module for each component. Instead,
  we should use modules to group side-by-side related function
  components.

  ## Assigns

  While inside a function component, you must use `Phoenix.LiveView.assign/3`
  and `Phoenix.LiveView.assign_new/3` to manipulate assigns,
  so that LiveView can track changes to the assigns values.
  For example, let's imagine a component that receives the first
  name and last name and must compute the name assign. One option
  would be:

      def show_name(assigns) do
        assigns = assign(assigns, :name, assigns.first_name <> assigns.last_name)

        ~H"""
        <p>Your name is: <%= @name %></p>
        """
      end

  However, when possible, it may be cleaner to break the logic over function
  calls instead of precomputed assigns:

      def show_name(assigns) do
        ~H"""
        <p>Your name is: <%= full_name(@first_name, @last_name) %></p>
        """
      end

      defp full_name(first_name, last_name), do: first_name <> last_name

  Another example is making an assign optional by providing
  a default value:

      def field_label(assigns) do
        assigns = assign_new(assigns, :help, fn -> nil end)

        ~H"""
        <label>
          <%= @text %>

          <%= if @help do %>
            <span class="help"><%= @help %></span>
          <% end %>
        </label>
        """
      end

  ## Slots

  Slots is a mechanism to give HTML blocks to function components
  as in regular HTML tags.

  ### Default slots

  Any content you pass inside a component is assigned to a default slot
  called `@inner_block`. For example, imagine you want to create a button
  component like this:

      <.button>
        This renders <strong>inside</strong> the button!
      </.button>

  It is quite simple to do so. Simply define your component and call
  `render_slot(@inner_block)` where you want to inject the content:

      def button(assigns) do
        ~H"""
        <button class="btn">
          <%= render_slot(@inner_block) %>
        </button>
        """
      end

  In a nutshell, the contents given to the component is assigned to
  the `@inner_block` assign and then we use `Phoenix.LiveView.Helpers.render_slot/2`
  to render it.

  You can even have the component give a value back to the caller,
  by using the special attribute `:let` (note the leading `:`).
  Imagine this component:

      def unordered_list(assigns) do
        ~H"""
        <ul>
          <%= for entry <- @entries do %>
            <li><%= render_slot(@inner_block, entry) %></li>
          <% end %>
        </ul>
        """
      end

  And now you can invoke it as:

      <.unordered_list :let={entry} entries={~w(apple banana cherry)}>
        I like <%= entry %>
      </.unordered_list>

  You can also pattern match the arguments provided to the render block. Let's
  make our `unordered_list` component fancier:

      def unordered_list(assigns) do
        ~H"""
        <ul>
          <%= for entry <- @entries do %>
            <li><%= render_slot(@inner_block, %{entry: entry, gif_url: random_gif()}) %></li>
          <% end %>
        </ul>
        """
      end

  And now we can invoke it like this:

      <.unordered_list :let={%{entry: entry, gif_url: url}}>
        I like <%= entry %>. <img src={url} />
      </.unordered_list>

  ### Named slots

  Besides `@inner_block`, it is also possible to pass named slots
  to the component. For example, imagine that you want to create
  a modal component. The modal component has a header, a footer,
  and the body of the modal, which we would use like this:

      <.modal>
        <:header>
          This is the top of the modal.
        </:header>

        This is the body - everything not in a
        named slot goes to @inner_block.

        <:footer>
          <button>Save</button>
        </:footer>
      </.modal>

  The component itself could be implemented like this:

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

  If you want to make the `@header` and `@footer` optional,
  you can assign them a default of an empty list at the top:

      def modal(assigns) do
        assigns =
          assigns
          |> assign_new(:header, fn -> [] end)
          |> assign_new(:footer, fn -> [] end)

        ~H"""
        <div class="modal">
          ...
      end

  ### Named slots with attributes

  It is also possible to pass the same named slot multiple
  times and also give attributes to each of them.

  If multiple slot entries are defined for the same slot,
  `render_slot/2` will automatically render all entries,
  merging their contents. But sometimes we want more fine
  grained control over each individual slot, including access
  to their attributes. Let's see an example. Imagine we want
  to implement a table component

  For example, imagine a table component:

      <.table rows={@users}>
        <:col :let={user} label="Name">
          <%= user.name %>
        </:col>

        <:col :let={user} label="Address">
          <%= user.address %>
        </:col>
      </.table>

  At the top level, we pass the rows as an assign and we define
  a `:col` slot for each column we want in the table. Each
  column also has a `label`, which we are going to use in the
  table header.

  Inside the component, you can render the table with headers,
  rows, and columns:

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

  Each named slot (including the `@inner_block`) is a list of maps,
  where the map contains all slot attributes, allowing us to access
  the label as `col.label`. This gives us complete control over how
  we render them.

  ## Attributes

  Function components support declarative assigns with compile-time
  verification and validation. For example a progress bar function
  component may declare its attributes like so:

      attr :id, :string, required: true
      attr :min, :integer, default: 0
      attr :max, :integer, default: 100
      attr :val, :integer, default: nil
      attr :rest, :global, default: %{class: "w-4 h-4 inline-block"}

      def progress_bar(assigns) do
        ~H"""
        <div id={@id} data-min={@min} data-max={@max} data-val={@val || @min} {@rest}></div>
        """
      end

  And a caller rendering such a component would receive helpful errors by the
  LiveView compiler if they rendered it incorrectly:

      <.progress_bar value={@percent} />

      warning: missing required attribute "id" for component MyAppWeb.LiveHelpers.progress_bar/1
               lib/app_web/live_helpers.ex:15

  *Note*: Declarative assigns requires the `:phoenix_live_view` compiler to be added
  to your `:compiler` options in your `mix.exs`'s `project` configuration:

      def project do
        [
          ...,
          compilers: [:gettext, :phoenix_live_view] ++ Mix.compilers(),
        ]
      end

  See `attr/3` for full usage details.

  ### Global Attributes

  Global attributes may be provided to any component that declares a
  `:global` attribute. By default, the supported global attributes are
  those common to all HTML elements. The full list can be found
  [here](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes)

  Custom attribute prefixes can be provided by the caller module with
  the `:global_prefixes` option to `use Phoenix.Component`. For example, the
  following would allow Alpine JS annotations, such as `x-on:click`,
  `x-data`, etc:

      use Phoenix.Component, global_prefixes: ~w(x-)

  Global attribute defaults are merged with caller attributes. For example
  you may declare a default class if the caller does not provide one:

      attr :rest, :global, default: %{class: "w-4 h-4 inline-block"}
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
  Declares attributes for a HEEx function components with compile-time verification and documentation generation.

  ## Options

    * `:required` - marks an attribute as required. If a caller does not pass
      the given attribute, a compile warning is issued.
    * `:default` - the default value for the attribute if not provided
    * `:doc` - documentation for the attribute

  ## Types

  An attribute is declared by its name, type, and options. The following
  types are supported:

    * `:any` - any term
    * `:string` - any binary string
    * `:atom` - any atom
    * `:boolean` - any boolean
    * `:integer` - any integer
    * `:float` - any float
    * `:list` - a List of any aribitrary types
    * `:global` - represents all other undefined attributes
      passed by the caller that match common HTML attributes as well as
      those defined via the `:global_prefixes` option to `use Phoenix.Component`.
      The optional map of global attribute defaults are merged with caller attributes.
      See the `Phoenix.Component` module documenation for full details.
    * Any struct module

  ## Validations

  LiveView performs some validation of attributes via the `:live_view`
  compiler. When attributes are defined, LiveView will warn at compilation
  time on the caller if:

    * if a required attribute of a component is missing

    * if an unknown attribute is given

    * if you specify a literal attribute (such as `value="string"` or `value`,
      but not `value={expr}`) and the type does not match

  LiveView does not perform any validation at runtime. This means the type
  information is mostly used for documentation and reflection purposes.

  On the side of the LiveView component itself, defining attributes provides
  the following quality of life improvements:

    * The default value of all attributes will be added to the `assigns`
      map upfront

    * Required struct types are annotated and emit compilation warnings.
      For example, if you specify `attr :user, User, required: true` and
      then you write `@user.non_valid_field` in your template, a warning
      will be emitted

  This list may increase in the future.

  ## Documentation

  Public function components that define attributes will have their attribute
  types and docs injected into the function's documentation, depending on the
  value of the `@doc` module attribute:

    * if `@doc` is a string, the attribute docs are injected into that string.
      The optional placeholder `[[INJECT LVDOCS]]` can be used to specify where
      in the string the docs are injected. Otherwise, the docs are appended
      to the end of the `@doc` string.

    * if `@doc` is unspecified, the attribute docs are used as the
      default `@doc` string.

    * if `@doc` is false, the attribute docs are omitted entirely.

  The injected attribute docs are formatted as a markdown list:

    ```markdown
    * `name` (`:type`) (required) - attr docs. Defaults to `:default`.
    ```

  By default, all attributes will have their types and docs injected into
  the function `@doc` string. To hide a specific attribute, you can set
  the value of `:doc` to `false`.

  ## Examples

      attr :id, :string, required: true
      attr :min, :integer, default: 0
      attr :max, :integer, default: 100
      attr :val, :integer, default: nil
      attr :rest, :global, default: %{class: "w-4 h-4 inline-block"}

      def progress_bar(assigns) do
        ~H"""
        <div id={@id} data-min={@min} data-max={@max} data-val={@val || @min} {@rest}></div>
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

    type = validate_attr_type!(module, slot, name, type, line, file)
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

    if slot do
      Module.put_attribute(module, :__slot_attrs__, attr)
    else
      Module.put_attribute(module, :__attrs__, attr)
    end
  end

  @builtin_types [:boolean, :integer, :float, :string, :atom, :list, :map, :global]
  @valid_types [:any] ++ @builtin_types

  defp validate_attr_type!(module, slot, name, type, line, file) when is_atom(type) do
    attrs = get_attrs(module)

    cond do
      Enum.find(attrs, fn attr -> attr.name == name end) && is_nil(slot) ->
        compile_error!(line, file, """
        a duplicate attribute with name #{inspect(name)} already exists\
        """)

      # TODO: can slot attributes be global?
      existing = type == :global && Enum.find(attrs, fn attr -> attr.type == :global end) ->
        compile_error!(line, file, """
        cannot define global attribute #{inspect(name)} because one is already defined under #{inspect(existing.name)}.

        Only a single global attribute may be defined.
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

  defp validate_attr_type!(_module, slot, name, type, line, file) do
    bad_type!(slot, name, type, line, file)
  end

  defp compile_error!(line, file, msg) do
    raise CompileError, line: line, file: file, description: msg
  end

  defp bad_type!(nil, name, type, line, file) do
    compile_error!(line, file, """
    invalid type #{inspect(type)} for attr #{inspect(name)}. \
    The following types are supported:

      * any Elixir struct, such as URI, MyApp.User, etc
      * one of #{Enum.map_join(@builtin_types, ", ", &inspect/1)}
      * :any for all other types
    """)
  end

  defp bad_type!(slot, name, type, line, file) do
    compile_error!(line, file, """
    invalid type #{inspect(type)} for attr #{inspect(name)} in slot #{inspect(slot)}. \
    The following types are supported:

      * any Elixir struct, such as URI, MyApp.User, etc
      * one of #{Enum.map_join(@builtin_types, ", ", &inspect/1)}
      * :any for all other types
    """)
  end

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

      {{:struct, mod}, default} when not is_struct(default, mod) ->
        bad_default!(slot, name, mod, default, line, file)

      {_type, _default} ->
        :ok
    end
  end

  defp bad_default!(nil, name, type, default, line, file) do
    compile_error!(line, file, """
    expected the default value for attr #{inspect(name)} \
    to be #{type_with_article(type)}, \
    got: #{inspect(default)}.
    """)
  end

  defp bad_default!(slot, name, type, default, line, file) do
    compile_error!(line, file, """
    expected the default value for attr #{inspect(name)} \
    in slot #{inspect(slot)} \
    to be #{type_with_article(type)}, \
    got: #{inspect(default)}.
    """)
  end

  defp type_with_article(type) when type in [:atom, :integer], do: "an #{inspect(type)}"

  defp type_with_article(type), do: "a #{inspect(type)}"

  @valid_opts [:required, :default]
  defp validate_attr_opts!(nil, name, opts, line, file) do
    for {key, _} <- opts, key not in @valid_opts do
      compile_error!(line, file, """
      invalid option #{inspect(key)} for attr #{inspect(name)}. \
      The supported options are: #{inspect(@valid_opts)}
      """)
    end
  end

  defp validate_attr_opts!(slot, name, opts, line, file) do
    for {key, _} <- opts, key not in @valid_opts do
      compile_error!(line, file, """
      invalid option #{inspect(key)} for attr #{inspect(name)} in slot #{inspect(slot)}. \
      The supported options are: #{inspect(@valid_opts)}
      """)
    end
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
      for {name, %{kind: kind, attrs: attrs}} <- components do
        defaults =
          for %{name: name, required: false, opts: opts} <- attrs,
              Keyword.has_key?(opts, :default) do
            {name, Macro.escape(opts[:default])}
          end

        {global_name, global_default} =
          case Enum.find(attrs, fn attr -> attr.type == :global end) do
            %{name: name, opts: opts} -> {name, Macro.escape(Keyword.get(opts, :default, %{}))}
            nil -> {nil, nil}
          end

        known_keys = for(attr <- attrs, do: attr.name) ++ __reserved_assigns__()

        def_body =
          if global_name do
            quote do
              {assigns, caller_globals} = Map.split(assigns, unquote(known_keys))

              globals =
                case Map.fetch(assigns, unquote(global_name)) do
                  {:ok, explicit_global_assign} -> explicit_global_assign
                  :error -> Map.merge(unquote(global_default), caller_globals)
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
      if components_calls != [] do
        quote do
          def __components_calls__() do
            unquote(Macro.escape(components_calls))
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

  defp get_attrs(module) do
    Module.get_attribute(module, :__attrs__) || []
  end

  defp pop_attrs(env) do
    attrs =
      env.module
      |> get_attrs()
      |> Enum.reverse()

    Module.delete_attribute(env.module, :__attrs__)
    attrs
  end

  defp get_slots(module) do
    Module.get_attribute(module, :__slots__) || []
  end

  defp pop_slots(env) do
    slots =
      env.module
      |> get_slots()
      |> Enum.reverse()

    Module.delete_attribute(env.module, :__slots__)
    slots
  end

  defp raise_if_function_already_defined!(env, name, slots, attrs) do
    if Module.defines?(env.module, {name, 1}) do
      {:v1, _, meta, _} = Module.get_definition(env.module, {name, 1})

      unless Enum.empty?(attrs) do
        [%{line: first_attr_line} | _] = attrs

        compile_error!(first_attr_line, env.file, """
        attributes must be defined before the first function clause at line #{meta[:line]}
        """)
      end

      unless Enum.empty?(slots) do
        [%{line: first_slot_line} | _] = slots

        compile_error!(first_slot_line, env.file, """
        slots must be defined before the first function clause at line #{meta[:line]}
        """)
      end
    end
  end

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

  @doc false
  def __slot__!(module, name, opts, line, file, block_fun \\ fn -> :ok end) do
    {doc, opts} = Keyword.pop(opts, :doc, nil)

    unless is_binary(doc) or is_nil(doc) or doc == false do
      compile_error!(line, file, ":doc must be a string or false, got: #{inspect(doc)}")
    end

    {required, opts} = Keyword.pop(opts, :required, false)

    unless is_boolean(required) do
      compile_error!(line, file, ":required must be a boolean, got: #{inspect(required)}")
    end

    Module.put_attribute(module, :__slot__, name)

    try do
      block_fun.()
    rescue
      e ->
        Module.put_attribute(module, :__slot__, nil)
        Module.delete_attribute(module, :__slot_attrs__)
        Module.register_attribute(module, :__slot_attrs__, accumulate: true)
        reraise e, __STACKTRACE__
    end

    slot_attrs =
      module
      |> Module.get_attribute(:__slot_attrs__)
      |> Enum.reverse()

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
    Module.put_attribute(module, :__slot__, nil)
    Module.delete_attribute(module, :__slot_attrs__)
    Module.register_attribute(module, :__slot_attrs__, accumulate: true)
  end

  defp validate_slot!(module, slot, line, file) do
    slots = get_slots(module)

    if Enum.find(slots, &(&1.name == slot.name)) do
      compile_error!(line, file, """
      a duplicate slot with name #{inspect(slot.name)} already exists
      """)
    end

    if slot.name == :inner_block and not Enum.empty?(slot.attrs) do
      compile_error!(line, file, """
      cannot define attributes in slot #{inspect(slot.name)}
      """)
    end

    for {attr_name, attr_defs} <- Enum.group_by(slot.attrs, & &1.name),
        length(attr_defs) > 1,
        %{line: line} <- attr_defs do
      compile_error!(line, file, """
      a duplicate attribute with name #{inspect(attr_name)} in slot #{inspect(slot.name)} already exists
      """)
    end
  end
end

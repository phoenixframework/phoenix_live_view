defmodule Phoenix.Component.Declarative do
  @moduledoc false

  ## Reserved assigns

  # This list should only contain attributes that are given to components by engines
  # @socket, @myself, etc. should not be listed here, as they shouldn't be given to
  # function components in the first place
  @reserved_assigns [:__changed__, :__slot__, :__given__, :inner_block]

  @doc false
  def __reserved__, do: @reserved_assigns

  ## Global

  @global_prefixes ~w(
    phx-
    aria-
    data-
  )
  @globals ~w(
    accesskey
    alt
    autocapitalize
    autofocus
    class
    contenteditable
    contextmenu
    dir
    draggable
    enterkeyhint
    exportparts
    height
    hidden
    id
    inert
    inputmode
    is
    itemid
    itemprop
    itemref
    itemscope
    itemtype
    lang
    nonce
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
    part
    placeholder
    rel
    role
    slot
    spellcheck
    style
    tabindex
    target
    title
    translate
    type
    width
    xml:base
    xml:lang
  )

  @doc false
  def __global__?(module, name, global_attr) when is_atom(module) and is_binary(name) do
    includes = Keyword.get(global_attr.opts, :include, [])

    if function_exported?(module, :__global__?, 1) do
      module.__global__?(name) or __global__?(name) or name in includes
    else
      __global__?(name) or name in includes
    end
  end

  for prefix <- @global_prefixes do
    def __global__?(unquote(prefix) <> _), do: true
  end

  for name <- @globals do
    def __global__?(unquote(name)), do: true
  end

  def __global__?(_), do: false

  ## Def overrides

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

  defp annotate_call(kind, {name, meta, [{:\\, default_meta, [left, right]}]}),
    do: {name, meta, [{:\\, default_meta, [annotate_arg(kind, left), right]}]}

  defp annotate_call(kind, {name, meta, [arg]}),
    do: {name, meta, [annotate_arg(kind, arg)]}

  defp annotate_call(_kind, left),
    do: left

  defp annotate_arg(kind, {:=, meta, [{name, _, ctx} = var, arg]})
       when is_atom(name) and is_atom(ctx) do
    {:=, meta, [var, quote(do: unquote(__MODULE__).__pattern__!(unquote(kind), unquote(arg)))]}
  end

  defp annotate_arg(kind, {:=, meta, [arg, {name, _, ctx} = var]})
       when is_atom(name) and is_atom(ctx) do
    {:=, meta, [quote(do: unquote(__MODULE__).__pattern__!(unquote(kind), unquote(arg))), var]}
  end

  defp annotate_arg(kind, {name, meta, ctx} = var) when is_atom(name) and is_atom(ctx) do
    {:=, meta, [quote(do: unquote(__MODULE__).__pattern__!(unquote(kind), _)), var]}
  end

  defp annotate_arg(kind, arg) do
    quote(do: unquote(__MODULE__).__pattern__!(unquote(kind), unquote(arg)))
  end

  ## Attrs/slots

  @doc false
  @valid_opts [:global_prefixes]
  def __setup__(module, opts) do
    {prefixes, invalid_opts} = Keyword.pop(opts, :global_prefixes, [])

    prefix_matches =
      for prefix <- prefixes do
        if not String.ends_with?(prefix, "-") do
          raise ArgumentError,
                "global prefixes for #{inspect(module)} must end with a dash, got: #{inspect(prefix)}"
        end

        quote(do: {unquote(prefix) <> _, true})
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

    if prefix_matches == [] do
      []
    else
      prefix_matches ++ [quote(do: {_, false})]
    end
  end

  @doc false
  def __slot__!(module, name, opts, line, file, block_fun) do
    ensure_used!(module, line, file)
    {doc, opts} = Keyword.pop(opts, :doc, nil)

    if not (is_binary(doc) or is_nil(doc) or doc == false) do
      compile_error!(line, file, ":doc must be a string or false, got: #{inspect(doc)}")
    end

    {required, opts} = Keyword.pop(opts, :required, false)
    {validate_attrs, opts} = Keyword.pop(opts, :validate_attrs, true)

    if not is_boolean(required) do
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
      attrs: slot_attrs,
      validate_attrs: validate_attrs
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

    if slot.opts != [] do
      compile_error!(
        line,
        file,
        "invalid options #{inspect(slot.opts)} for slot #{inspect(slot.name)}. The supported options are: [:required, :doc, :validate_attrs]"
      )
    end
  end

  @doc false
  def __attr__!(module, name, type, opts, line, file) when is_atom(name) and is_list(opts) do
    ensure_used!(module, line, file)
    slot = Module.get_attribute(module, :__slot__)

    if name == :inner_block do
      compile_error!(
        line,
        file,
        "cannot define attribute called :inner_block. Maybe you wanted to use `slot` instead?"
      )
    end

    if type == :global && slot do
      compile_error!(line, file, "cannot define :global slot attributes")
    end

    if type == :global and Keyword.has_key?(opts, :required) do
      compile_error!(line, file, "global attributes do not support the :required option")
    end

    if type == :global and Keyword.has_key?(opts, :values) do
      compile_error!(line, file, "global attributes do not support the :values option")
    end

    if type == :global and Keyword.has_key?(opts, :examples) do
      compile_error!(line, file, "global attributes do not support the :examples option")
    end

    if type != :global and Keyword.has_key?(opts, :include) do
      compile_error!(line, file, ":include is only supported for :global attributes")
    end

    {doc, opts} = Keyword.pop(opts, :doc, nil)

    if not (is_binary(doc) or is_nil(doc) or doc == false) do
      compile_error!(line, file, ":doc must be a string or false, got: #{inspect(doc)}")
    end

    {required, opts} = Keyword.pop(opts, :required, false)

    if not is_boolean(required) do
      compile_error!(line, file, ":required must be a boolean, got: #{inspect(required)}")
    end

    if required and Keyword.has_key?(opts, :default) do
      compile_error!(line, file, "only one of :required or :default must be given")
    end

    key = if slot, do: :__slot_attrs__, else: :__attrs__
    type = validate_attr_type!(module, key, slot, name, type, line, file)
    validate_attr_opts!(slot, name, opts, line, file)

    if Keyword.has_key?(opts, :values) and Keyword.has_key?(opts, :examples) do
      compile_error!(line, file, "only one of :values or :examples must be given")
    end

    if Keyword.has_key?(opts, :values) do
      validate_attr_values!(slot, name, type, opts[:values], line, file)
    end

    if Keyword.has_key?(opts, :examples) do
      validate_attr_examples!(slot, name, type, opts[:examples], line, file)
    end

    if Keyword.has_key?(opts, :default) do
      validate_attr_default!(slot, name, type, opts, line, file)
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

  @builtin_types [:boolean, :integer, :float, :string, :atom, :list, :map, :fun, :global]
  @valid_types [:any] ++ @builtin_types

  defp validate_attr_type!(module, key, slot, name, type, line, file)
       when is_atom(type) or is_tuple(type) do
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

    cond do
      type in @valid_types -> type
      is_tuple(type) -> validate_tuple_attr_type!(slot, name, type, line, file)
      type |> Atom.to_string() |> String.starts_with?("Elixir.") -> {:struct, type}
      true -> bad_type!(slot, name, type, line, file)
    end
  end

  defp validate_attr_type!(_module, _key, slot, name, type, line, file) do
    bad_type!(slot, name, type, line, file)
  end

  defp validate_tuple_attr_type!(_slot, _name, {:fun, arity} = type, _line, _file)
       when is_integer(arity) do
    type
  end

  defp validate_tuple_attr_type!(slot, name, type, line, file) do
    bad_type!(slot, name, type, line, file)
  end

  defp bad_type!(slot, name, type, line, file) do
    compile_error!(line, file, """
    invalid type #{inspect(type)} for attr #{attr_slot(name, slot)}. \
    The following types are supported:

      * any Elixir struct, such as URI, MyApp.User, etc
      * one of #{Enum.map_join(@builtin_types, ", ", &inspect/1)}
      * a function written as:
          * without arity, ex: :fun
          * with a specific arity, ex: {:fun, 2}
      * :any for all other types
    """)
  end

  defp attr_slot(name, nil), do: "#{inspect(name)}"
  defp attr_slot(name, slot), do: "#{inspect(name)} in slot #{inspect(slot)}"

  defp validate_attr_default!(slot, name, type, opts, line, file) do
    case {opts[:default], opts[:values]} do
      {default, nil} ->
        if not valid_value?(type, default) do
          bad_default!(slot, name, type, default, line, file)
        end

      {default, values} ->
        if default not in values do
          compile_error!(line, file, """
          expected the default value for attr #{attr_slot(name, slot)} to be one of #{inspect(values)}, \
          got: #{inspect(default)}
          """)
        end
    end
  end

  defp bad_default!(slot, name, type, default, line, file) do
    compile_error!(line, file, """
    expected the default value for attr #{attr_slot(name, slot)} to be #{type_with_article(type)}, \
    got: #{inspect(default)}
    """)
  end

  defp validate_attr_values!(slot, name, type, values, line, file) do
    if not is_enumerable(values) or Enum.empty?(values) do
      compile_error!(line, file, """
      :values must be a non-empty enumerable, got: #{inspect(values)}
      """)
    end

    for value <- values,
        not valid_value?(type, value),
        do: bad_value!(slot, name, type, value, line, file)
  end

  defp is_enumerable(values) do
    Enumerable.impl_for(values) != nil
  end

  defp bad_value!(slot, name, type, value, line, file) do
    compile_error!(line, file, """
    expected the values for attr #{attr_slot(name, slot)} to be #{type_with_article(type)}, \
    got: #{inspect(value)}
    """)
  end

  defp validate_attr_examples!(slot, name, type, examples, line, file) do
    if not is_list(examples) or Enum.empty?(examples) do
      compile_error!(line, file, """
      :examples must be a non-empty list, got: #{inspect(examples)}
      """)
    end

    for example <- examples,
        not valid_value?(type, example),
        do: bad_example!(slot, name, type, example, line, file)
  end

  defp bad_example!(slot, name, type, example, line, file) do
    compile_error!(line, file, """
    expected the examples for attr #{attr_slot(name, slot)} to be #{type_with_article(type)}, \
    got: #{inspect(example)}
    """)
  end

  defp valid_value?(_type, nil), do: true
  defp valid_value?(:any, _value), do: true
  defp valid_value?(:string, value), do: is_binary(value)
  defp valid_value?(:atom, value), do: is_atom(value)
  defp valid_value?(:boolean, value), do: is_boolean(value)
  defp valid_value?(:integer, value), do: is_integer(value)
  defp valid_value?(:float, value), do: is_float(value)
  defp valid_value?(:list, value), do: is_list(value)
  defp valid_value?({:struct, mod}, value), do: is_struct(value, mod)
  defp valid_value?(_type, _value), do: true

  defp validate_attr_opts!(slot, name, opts, line, file) do
    for {key, _} <- opts, message = invalid_attr_message(key, slot) do
      compile_error!(line, file, """
      invalid option #{inspect(key)} for attr #{attr_slot(name, slot)}. #{message}\
      """)
    end
  end

  defp invalid_attr_message(:include, inc) when is_list(inc) or is_nil(inc), do: nil

  defp invalid_attr_message(:include, other),
    do: "include only supports a list of attributes, got: #{inspect(other)}"

  defp invalid_attr_message(:default, nil), do: nil

  defp invalid_attr_message(:default, _),
    do:
      ":default is not supported inside slot attributes, " <>
        "instead use Map.get/3 with a default value when accessing a slot attribute"

  defp invalid_attr_message(:required, _), do: nil
  defp invalid_attr_message(:values, _), do: nil
  defp invalid_attr_message(:examples, _), do: nil

  defp invalid_attr_message(_key, nil),
    do: "The supported options are: [:required, :default, :values, :examples, :include]"

  defp invalid_attr_message(_key, _slot),
    do: "The supported options inside slots are: [:required]"

  defp compile_error!(line, file, msg) do
    raise CompileError, line: line, file: file, description: msg
  end

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
    check? = not String.starts_with?(to_string(name), "__")

    cond do
      check? and length(args) == 1 and body == nil ->
        register_component!(kind, env, name, false)

      check? ->
        attrs = pop_attrs(env)

        validate_misplaced_attrs!(attrs, env.file, fn ->
          case length(args) do
            1 ->
              "could not define attributes for function #{name}/1. " <>
                "Please make sure that you have `use Phoenix.Component` and that the function has no default arguments"

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

      true ->
        :ok
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
      for {name, %{kind: kind, attrs: attrs, slots: slots, line: line}} <- components do
        attr_defaults =
          for %{name: name, required: false, opts: opts} <- attrs,
              Keyword.has_key?(opts, :default),
              do: {name, Macro.escape(opts[:default])}

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
        known_keys = attr_names ++ slot_names ++ @reserved_assigns

        def_body =
          if global_name do
            quote do
              {assigns, caller_globals} = Map.split(assigns, unquote(known_keys))

              globals =
                case assigns do
                  %{unquote(global_name) => explicit_global_assign} -> explicit_global_assign
                  %{} -> Map.merge(unquote(global_default), caller_globals)
                end

              merged =
                %{unquote_splicing(defaults)}
                |> Map.merge(assigns)
                |> Map.put(:__given__, assigns)

              super(Phoenix.Component.assign(merged, unquote(global_name), globals))
            end
          else
            quote do
              merged =
                %{unquote_splicing(defaults)}
                |> Map.merge(assigns)
                |> Map.put(:__given__, assigns)

              super(merged)
            end
          end

        merge =
          quote line: line do
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
            unquote(__MODULE__).__verify__(module, unquote(Macro.escape(components_calls)))
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
            slots: Enum.sort_by(slots, & &1.name),
            line: env.line
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
    [left | right] = String.split(doc, "[INSERT LVATTRDOCS]")

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
      "## Slots\n",
      for slot <- slots, slot.doc != false, into: [] do
        slot_attrs =
          for slot_attr <- slot.attrs,
              slot_attr.doc != false,
              slot_attr.slot == slot.name,
              do: slot_attr

        [
          "\n* ",
          build_slot_name(slot),
          build_slot_required(slot),
          build_slot_doc(slot, slot_attrs)
        ]
      end
    ]
  end

  defp build_attrs_docs(attrs) do
    [
      "## Attributes\n",
      for attr <- attrs, attr.doc != false and attr.type != :global do
        [
          "\n* ",
          build_attr_name(attr),
          build_attr_type(attr),
          build_attr_required(attr),
          build_hyphen(attr),
          build_attr_doc_and_default(attr, "  "),
          build_attr_values_or_examples(attr)
        ]
      end,
      # global always goes at the end
      case Enum.find(attrs, &(&1.type === :global)) do
        nil -> []
        attr -> build_attr_doc_and_default(attr, "  ")
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
    [" - ", build_doc(doc, "  ", false)]
  end

  defp build_slot_doc(%{doc: nil}, slot_attrs) do
    [" - Accepts attributes:\n", build_slot_attrs_docs(slot_attrs)]
  end

  defp build_slot_doc(%{doc: doc}, slot_attrs) do
    [
      " - ",
      build_doc(doc, "  ", true),
      "Accepts attributes:\n",
      build_slot_attrs_docs(slot_attrs)
    ]
  end

  defp build_slot_attrs_docs(slot_attrs) do
    for slot_attr <- slot_attrs do
      [
        "\n  * ",
        build_attr_name(slot_attr),
        build_attr_type(slot_attr),
        build_attr_required(slot_attr),
        build_hyphen(slot_attr),
        build_attr_doc_and_default(slot_attr, "    "),
        build_attr_values_or_examples(slot_attr)
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

  defp build_attr_doc_and_default(%{doc: doc, type: :global, opts: opts}, indent) do
    [
      "\n* Global attributes are accepted.",
      if(doc, do: [" ", build_doc(doc, indent, false)], else: []),
      case Keyword.get(opts, :include) do
        inc when is_list(inc) and inc != [] ->
          [" ", "Supports all globals plus:", " ", build_literal(inc), "."]

        _ ->
          []
      end
    ]
  end

  defp build_attr_doc_and_default(%{doc: doc, opts: opts}, indent) do
    case Keyword.fetch(opts, :default) do
      {:ok, default} ->
        if doc do
          [build_doc(doc, indent, true), "Defaults to ", build_literal(default), "."]
        else
          ["Defaults to ", build_literal(default), "."]
        end

      :error ->
        if doc, do: [build_doc(doc, indent, false)], else: []
    end
  end

  defp build_doc(doc, indent, text_after?) do
    doc = String.trim(doc)
    [head | tail] = String.split(doc, ["\r\n", "\n"])
    dot = if String.ends_with?(doc, "."), do: [], else: [?.]

    tail =
      Enum.map(tail, fn
        "" -> "\n"
        other -> [?\n, indent | other]
      end)

    case tail do
      # Single line
      [] when text_after? ->
        [[head | tail], dot, ?\s]

      [] ->
        [[head | tail], dot]

      # Multi-line
      _ when text_after? ->
        [[head | tail], "\n\n", indent]

      _ ->
        [[head | tail], "\n"]
    end
  end

  defp build_attr_values_or_examples(%{opts: [values: values]}) do
    ["Must be one of ", build_literals_list(values, "or"), ?.]
  end

  defp build_attr_values_or_examples(%{opts: [examples: examples]}) do
    ["Examples include ", build_literals_list(examples, "and"), ?.]
  end

  defp build_attr_values_or_examples(_attr) do
    []
  end

  defp build_literals_list([literal], _condition) do
    [build_literal(literal)]
  end

  defp build_literals_list(literals, condition) do
    literals
    |> Enum.map_intersperse(", ", &build_literal/1)
    |> List.insert_at(-2, [condition, " "])
  end

  defp build_literal(literal) do
    [?`, inspect(literal, charlists: :as_list), ?`]
  end

  defp build_hyphen(%{doc: doc}) when is_binary(doc) do
    [" - "]
  end

  defp build_hyphen(%{opts: []}) do
    []
  end

  defp build_hyphen(%{opts: _opts}) do
    [" - "]
  end

  defp build_right_doc("") do
    []
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
         %{slots: slots_defs, attrs: attrs_defs} = _component
       ) do
    {attrs, global_attr} =
      Enum.reduce(attrs_defs, {attrs, nil}, fn attr_def, {attrs, global_attr} ->
        %{name: name, required: required, type: type, opts: opts} = attr_def
        attr_values = Keyword.get(opts, :values, nil)
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

          # attrs must be one of values
          {_type, {line, _column, {_, type_value}}} when not is_nil(attr_values) ->
            if type_value not in attr_values do
              message =
                "attribute \"#{name}\" in component #{component_fa(call)} must be one of #{inspect(attr_values)}, got: #{inspect(type_value)}"

              warn(message, call.file, line)
            end

          # attrs must be of the declared type
          {type, {line, _column, type_value}} ->
            if value_ast_to_string = type_mismatch(type, type_value) do
              message =
                "attribute \"#{name}\" in component #{component_fa(call)} must be #{type_with_article(type)}, got: " <>
                  value_ast_to_string

              [warn(message, call.file, line)]
            end
        end

        {attrs, global_attr || (type == :global and attr_def)}
      end)

    for {name, {line, _column, _type_value}} <- attrs,
        !(global_attr && __global__?(caller_module, Atom.to_string(name), global_attr)) do
      message = "undefined attribute \"#{name}\" for component #{component_fa(call)}"
      warn(message, call.file, line)
    end

    undefined_slots =
      Enum.reduce(slots_defs, slots, fn slot_def, slots ->
        %{name: slot_name, required: required, attrs: attrs, validate_attrs: validate_attrs} =
          slot_def

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
                # slots cannot accept global attributes
                %{^attr_name => %{type: :global}} ->
                  message =
                    "global attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                      "for component #{component_fa(call)} may not be provided directly"

                  warn(message, call.file, line)

                # slot attrs must be one of values
                %{^attr_name => %{type: _type, opts: [values: attr_values]}}
                when is_tuple(type_value) and tuple_size(type_value) == 2 ->
                  {_, attr_value} = type_value

                  if attr_value not in attr_values do
                    message =
                      "attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                        "for component #{component_fa(call)} must be one of #{inspect(attr_values)}, got: " <>
                        inspect(attr_value)

                    warn(message, call.file, line)
                  end

                # slot attrs must be of the declared type
                %{^attr_name => %{type: type}} ->
                  if value_ast_to_string = type_mismatch(type, type_value) do
                    message =
                      "attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                        "for component #{component_fa(call)} must be #{type_with_article(type)}, got: " <>
                        value_ast_to_string

                    warn(message, call.file, line)
                  end

                # undefined slot attr
                %{} ->
                  cond do
                    attr_name == :inner_block ->
                      :ok

                    attrs == [] and not validate_attrs ->
                      :ok

                    true ->
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

    for {slot_name, slot_values} <- undefined_slots,
        %{line: line} <- slot_values,
        not implicit_inner_block?(slot_name, slots_defs) do
      message = "undefined slot \"#{slot_name}\" for component #{component_fa(call)}"
      warn(message, call.file, line)
    end

    :ok
  end

  defp implicit_inner_block?(slot_name, slots_defs) do
    slot_name == :inner_block and length(slots_defs) > 0
  end

  defp type_mismatch(:any, _type_value), do: nil
  defp type_mismatch(_type, :any), do: nil
  defp type_mismatch(type, {type, _value}), do: nil
  defp type_mismatch(:atom, {:boolean, _value}), do: nil
  defp type_mismatch({:struct, _}, {:map, {:%{}, _, [{:|, _, [_, _]}]}}), do: nil
  defp type_mismatch(:fun, {:fun, _}), do: nil
  defp type_mismatch({:fun, arity}, {:fun, arity}), do: nil
  defp type_mismatch({:fun, _arity}, {:fun, arity}), do: type_with_article({:fun, arity})
  defp type_mismatch(_type, {_, value}), do: Macro.to_string(value)

  defp component_fa(%{component: {mod, fun}}) do
    "#{inspect(mod)}.#{fun}/1"
  end

  ## Shared helpers

  defp type_with_article({:struct, struct}), do: "a #{inspect(struct)} struct"
  defp type_with_article(:fun), do: "a function"
  defp type_with_article({:fun, arity}), do: "a function of arity #{arity}"
  defp type_with_article(type) when type in [:atom, :integer], do: "an #{inspect(type)}"
  defp type_with_article(type), do: "a #{inspect(type)}"

  # TODO: Provide column information in error messages
  defp warn(message, file, line) do
    IO.warn(message, file: file, line: line)
  end

  defp ensure_used!(module, line, file) do
    if !Module.get_attribute(module, :__attrs__) do
      compile_error!(
        line,
        file,
        "you must `use Phoenix.Component` to declare attributes. It is currently only imported."
      )
    end
  end
end

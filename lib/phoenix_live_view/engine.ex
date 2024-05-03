defmodule Phoenix.LiveView.Component do
  @moduledoc """
  The struct returned by components in .heex templates.

  This component is never meant to be output directly
  into the template. It should always be handled by
  the diffing algorithm.
  """

  defstruct [:id, :component, :assigns]

  @type t :: %__MODULE__{
          id: binary(),
          component: module(),
          assigns: map()
        }

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%{id: id, component: component}) do
      raise ArgumentError, """
      cannot convert component #{inspect(component)} with id #{inspect(id)} to HTML.

      A component must always be returned directly as part of a LiveView template.

      For example, this is not allowed:

          <%= content_tag :div do %>
            <.live_component module={SomeComponent} id="myid" />
          <% end %>

      That's because the component is inside `content_tag`. However, this works:

          <div>
            <.live_component module={SomeComponent} id="myid" />
          </div>

      Components are also allowed inside Elixir's special forms, such as
      `if`, `for`, `case`, and friends.

          <%= for item <- items do %>
            <.live_component module={SomeComponent} id={item} />
          <% end %>

      However, using other module functions such as `Enum`, will not work:

          <%= Enum.map(items, fn item -> %>
            <.live_component module={SomeComponent} id={item} />
          <% end %>
      """
    end
  end
end

defmodule Phoenix.LiveView.Comprehension do
  @moduledoc """
  The struct returned by for-comprehensions in .heex templates.

  See a description about its fields and use cases
  in `Phoenix.LiveView.Engine` docs.
  """

  defstruct [:static, :dynamics, :fingerprint, :stream]

  @type t :: %__MODULE__{
          stream: list() | nil,
          static: [String.t()],
          dynamics: [
            [
              iodata()
              | Phoenix.LiveView.Rendered.t()
              | Phoenix.LiveView.Comprehension.t()
              | Phoenix.LiveView.Component.t()
            ]
          ],
          fingerprint: integer()
        }

  @doc false
  def __mark_consumable__(%Phoenix.LiveView.LiveStream{} = stream) do
    %Phoenix.LiveView.LiveStream{stream | consumable?: true}
  end

  def __mark_consumable__(collection), do: collection

  @doc false
  def __annotate__(comprehension, %Phoenix.LiveView.LiveStream{} = stream) do
    inserts = for {id, at, _item, limit} <- stream.inserts, do: [id, at, limit]
    data = [stream.ref, inserts, stream.deletes]

    if stream.reset? do
      Map.put(comprehension, :stream, data ++ [true])
    else
      Map.put(comprehension, :stream, data)
    end
  end

  def __annotate__(comprehension, _collection), do: comprehension

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%Phoenix.LiveView.Comprehension{static: static, dynamics: dynamics}) do
      for dynamic <- dynamics, do: to_iodata(static, dynamic)
    end

    defp to_iodata([static_head | static_tail], [%_{} = struct | dynamic_tail]) do
      dynamic_head = Phoenix.HTML.Safe.to_iodata(struct)
      [static_head, dynamic_head | to_iodata(static_tail, dynamic_tail)]
    end

    defp to_iodata([static_head | static_tail], [dynamic_head | dynamic_tail]) do
      [static_head, dynamic_head | to_iodata(static_tail, dynamic_tail)]
    end

    defp to_iodata([static_head], []) do
      [static_head]
    end
  end
end

defmodule Phoenix.LiveView.Rendered do
  @moduledoc """
  The struct returned by .heex templates.

  See a description about its fields and use cases
  in `Phoenix.LiveView.Engine` docs.
  """

  defstruct [:static, :dynamic, :fingerprint, :root, caller: :not_available]

  @type t :: %__MODULE__{
          static: [String.t()],
          dynamic: (boolean() ->
                      [
                        nil
                        | iodata()
                        | Phoenix.LiveView.Rendered.t()
                        | Phoenix.LiveView.Comprehension.t()
                        | Phoenix.LiveView.Component.t()
                      ]),
          fingerprint: integer(),
          root: nil | true | false,
          caller:
            :not_available
            | {module(), function :: {atom(), non_neg_integer()}, file :: String.t(),
               line :: pos_integer()}
        }

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%Phoenix.LiveView.Rendered{static: static, dynamic: dynamic}) do
      to_iodata(static, dynamic.(false), [])
    end

    def to_iodata(%_{} = struct) do
      Phoenix.HTML.Safe.to_iodata(struct)
    end

    def to_iodata(nil) do
      raise "cannot convert .heex/.leex template with change tracking to iodata"
    end

    def to_iodata(other) do
      other
    end

    defp to_iodata([static_head | static_tail], [dynamic_head | dynamic_tail], acc) do
      to_iodata(static_tail, dynamic_tail, [to_iodata(dynamic_head), static_head | acc])
    end

    defp to_iodata([static_head], [], acc) do
      Enum.reverse([static_head | acc])
    end
  end
end

defmodule Phoenix.LiveView.Engine do
  @moduledoc ~S"""
  An `EEx` template engine that tracks changes.

  This is often used by `Phoenix.LiveView.TagEngine` which also adds
  HTML validation. In the documentation below, we will explain how it
  works internally. For user-facing documentation, see `Phoenix.LiveView`.

  ## Phoenix.LiveView.Rendered

  Whenever you render a live template, it returns a
  `Phoenix.LiveView.Rendered` structure. This structure has
  three fields: `:static`, `:dynamic` and `:fingerprint`.

  The `:static` field is a list of literal strings. This
  allows the Elixir compiler to optimize this list and avoid
  allocating its strings on every render.

  The `:dynamic` field contains a function that takes a boolean argument
  (see "Tracking changes" below), and returns a list of dynamic content.
  Each element in the list is either one of:

    1. iodata - which is the dynamic content
    2. nil - the dynamic content did not change
    3. another `Phoenix.LiveView.Rendered` struct, see "Nesting and fingerprinting" below
    4. a `Phoenix.LiveView.Comprehension` struct, see "Comprehensions" below
    5. a `Phoenix.LiveView.Component` struct, see "Component" below

  When you render a live template, you can convert the
  rendered structure to iodata by alternating the static
  and dynamic fields, always starting with a static entry
  followed by a dynamic entry. The last entry will always
  be static too. So the following structure:

      %Phoenix.LiveView.Rendered{
        static: ["foo", "bar", "baz"],
        dynamic: fn track_changes? -> ["left", "right"] end
      }

  Results in the following content to be sent over the wire
  as iodata:

      ["foo", "left", "bar", "right", "baz"]

  This is also what calling `Phoenix.HTML.Safe.to_iodata/1`
  with a `Phoenix.LiveView.Rendered` structure returns.

  Of course, the benefit of live templates is exactly
  that you do not need to send both static and dynamic
  segments every time. So let's talk about tracking changes.

  ## Tracking changes

  By default, a live template does not track changes.
  Change tracking can be enabled by including a changed
  map in the assigns with the key `__changed__` and passing
  `true` to the dynamic parts. The map should contain
  the name of any changed field as key and the boolean
  true as value. If a field is not listed in `__changed__`,
  then it is always considered unchanged.

  If a field is unchanged and live believes a dynamic
  expression no longer needs to be computed, its value
  in the `dynamic` list will be `nil`. This information
  can be leveraged to avoid sending data to the client.

  ## Nesting and fingerprinting

  `Phoenix.LiveView` also tracks changes across live
  templates. Therefore, if your view has this:

      <%= render "form.html", assigns %>

  Phoenix will be able to track what is static and dynamic
  across templates, as well as what changed. A rendered
  nested `live` template will appear in the `dynamic`
  list as another `Phoenix.LiveView.Rendered` structure,
  which must be handled recursively.

  However, because the rendering of live templates can
  be dynamic in itself, it is important to distinguish
  which live template was rendered. For example,
  imagine this code:

      <%= if something?, do: render("one.html", assigns), else: render("other.html", assigns) %>

  To solve this, all `Phoenix.LiveView.Rendered` structs
  also contain a fingerprint field that uniquely identifies
  it. If the fingerprints are equal, you have the same
  template, and therefore it is possible to only transmit
  its changes.

  ## Comprehensions

  Another optimization done by live templates is to
  track comprehensions. If your code has this:

      <%= for point <- @points do %>
        x: <%= point.x %>
        y: <%= point.y %>
      <% end %>

  Instead of rendering all points with both static and
  dynamic parts, it returns a `Phoenix.LiveView.Comprehension`
  struct with the static parts, that are shared across all
  points, and a list of dynamics to be interpolated inside
  the static parts. If `@points` is a list with `%{x: 1, y: 2}`
  and `%{x: 3, y: 4}`, the above expression would return:

      %Phoenix.LiveView.Comprehension{
        static: ["\n  x: ", "\n  y: ", "\n"],
        dynamics: [
          ["1", "2"],
          ["3", "4"]
        ]
      }

  This allows live templates to drastically optimize
  the data sent by comprehensions, as the static parts
  are emitted only once, regardless of the number of items.

  The list of dynamics is always a list of iodatas or components,
  as we don't perform change tracking inside the comprehensions
  themselves. Similarly, comprehensions do not have fingerprints
  because they are only optimized at the root, so conditional
  evaluation, as the one seen in rendering, is not possible.
  The only possible outcome for a dynamic field that returns a
  comprehension is `nil`.

  ## Components

  Live also supports stateful components defined with
  `Phoenix.LiveComponent`. Since they are stateful, they are always
  handled lazily by the diff algorithm.
  """

  alias Phoenix.HTML.Form
  @behaviour Phoenix.Template.Engine

  @impl true
  def compile(path, _name) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)
    EEx.compile_file(path, engine: __MODULE__, line: 1, trim: trim)
  end

  @behaviour EEx.Engine
  @assigns_var Macro.var(:assigns, nil)

  @impl true
  def init(opts) do
    # Phoenix.LiveView.TagEngine calls this engine in a non-linear order
    # to evaluate slots, which can lead to variable conflicts. Therefore we
    # use a counter to ensure all variable names are unique.
    %{
      static: [],
      dynamic: [],
      counter: :counters.new(1, []),
      caller: opts[:caller]
    }
  end

  @impl true
  def handle_begin(state) do
    %{state | static: [], dynamic: []}
  end

  @impl true
  def handle_end(state) do
    %{static: static, dynamic: dynamic} = state
    safe = {:safe, Enum.reverse(static)}
    {:__block__, [live_rendered: true], Enum.reverse([safe | dynamic])}
  end

  @impl true
  def handle_body(state, opts \\ []) do
    {:ok, rendered} =
      to_rendered_struct(handle_end(state), {:untainted, %{}}, %{}, state.caller, opts)

    quote do
      require Phoenix.LiveView.Engine
      unquote(rendered)
    end
  end

  @impl true
  def handle_text(state, _meta, text) do
    %{static: static} = state
    %{state | static: [text | static]}
  end

  @impl true
  def handle_expr(state, "=", ast) do
    %{static: static, dynamic: dynamic, counter: counter} = state
    i = :counters.get(counter, 1)
    var = Macro.var(:"v#{i}", __MODULE__)
    ast = quote do: unquote(var) = unquote(__MODULE__).to_safe(unquote(ast))

    :counters.add(counter, 1, 1)
    %{state | dynamic: [ast | dynamic], static: [var | static]}
  end

  def handle_expr(state, "", ast) do
    %{dynamic: dynamic} = state
    %{state | dynamic: [ast | dynamic]}
  end

  def handle_expr(state, marker, ast) do
    EEx.Engine.handle_expr(state, marker, ast)
  end

  ## Entry point for rendered structs

  defp to_rendered_struct(expr, vars, assigns, caller, opts) do
    with {:__block__, [live_rendered: true], entries} <- expr,
         {dynamic, [{:safe, static}]} <- Enum.split(entries, -1) do
      {block, static, dynamic, fingerprint} =
        analyze_static_and_dynamic(static, dynamic, vars, assigns, caller)

      static =
        case Keyword.fetch(opts, :body_annotation) do
          {:ok, {before, aft}} ->
            case static do
              [] ->
                ["#{before}#{aft}"]

              [first | rest] ->
                List.update_at([to_string(before) <> first | rest], -1, &(&1 <> to_string(aft)))
            end

          :error ->
            static
        end

      changed =
        quote generated: true do
          case unquote(@assigns_var) do
            %{__changed__: changed} when track_changes? -> changed
            _ -> nil
          end
        end

      {:ok,
       quote do
         dynamic = fn track_changes? ->
           changed = unquote(changed)
           unquote({:__block__, [], block})
           unquote(dynamic)
         end

         %Phoenix.LiveView.Rendered{
           static: unquote(static),
           dynamic: dynamic,
           fingerprint: unquote(fingerprint),
           root: unquote(opts[:root])
         }
       end}
    else
      _ -> :error
    end
  end

  defmacrop to_safe_match(var, ast) do
    quote do
      {:=, [],
       [
         {_, _, __MODULE__} = unquote(var),
         {{:., _, [__MODULE__, :to_safe]}, _, [unquote(ast)]}
       ]}
    end
  end

  defp analyze_static_and_dynamic(static, dynamic, initial_vars, assigns, caller) do
    {block, _} =
      Enum.map_reduce(dynamic, initial_vars, fn
        to_safe_match(var, ast), vars ->
          vars = set_vars(initial_vars, vars)
          {ast, keys, vars} = analyze_and_return_tainted_keys(ast, vars, assigns, caller)
          live_struct = to_live_struct(ast, vars, assigns, caller)
          {to_conditional_var(keys, var, live_struct), vars}

        ast, vars ->
          vars = set_vars(initial_vars, vars)
          {ast, vars, _} = analyze(ast, vars, assigns, caller)
          {ast, vars}
      end)

    {static, dynamic} = bins_and_vars(static)
    {block, static, dynamic, fingerprint(block, static)}
  end

  ## Optimize possible expressions into live structs (rendered / comprehensions)

  defp to_live_struct({:for, _, [_ | _]} = expr, vars, _assigns, caller) do
    with {:for, meta, [gen | args]} <- expr,
         {:<-, gen_meta, [gen_pattern, gen_collection]} <- gen,
         {filters, [[do: {:__block__, _, block}]]} <- Enum.split(args, -1),
         {dynamic, [{:safe, static}]} <- Enum.split(block, -1) do
      {block, static, dynamic, fingerprint} =
        analyze_static_and_dynamic(static, dynamic, taint_vars(vars), %{}, caller)

      gen_var = Macro.unique_var(:for, __MODULE__)

      gen_collection =
        quote do
          unquote(gen_var) =
            Phoenix.LiveView.Comprehension.__mark_consumable__(unquote(gen_collection))
        end

      gen = {:<-, gen_meta, [gen_pattern, gen_var]}
      for = {:for, meta, [gen | filters] ++ [[do: {:__block__, [], block ++ [dynamic]}]]}

      quote do
        unquote(gen_collection)

        Phoenix.LiveView.Comprehension.__annotate__(
          %Phoenix.LiveView.Comprehension{
            static: unquote(static),
            dynamics: unquote(for),
            fingerprint: unquote(fingerprint)
          },
          unquote(gen_var)
        )
      end
    else
      _ -> to_safe(expr, true)
    end
  end

  defp to_live_struct({left, meta, [_ | _] = args}, vars, assigns, caller) do
    call = extract_call(left)

    args =
      with :live <- classify_taint(call, args),
           {args, [opts]} when is_list(opts) <- Enum.split(args, -1) do
        # The reason we can safely ignore assigns here is because
        # each branch in the live/render constructs are their own
        # rendered struct and, if the rendered has a new fingerprint,
        # then change tracking is fully disabled.
        #
        # For example, take this code:
        #
        #     <%= if @foo do %>
        #       <%= @bar %>
        #     <% else %>
        #       <%= @baz %>
        #     <% end %>
        #
        # In theory, @bar and @baz should be recomputed whenever
        # @foo changes, because changing @foo may require a value
        # that was not available on the page to show. However,
        # given the branches have different fingerprints, the
        # diff mechanism takes care of forcing all assigns to
        # be rendered without us needing to handle it here.
        #
        # Similarly, when expanding the blocks, we can remove all
        # untainting, as the parent untainting is already causing
        # the block to be rendered and then we can proceed with
        # its own tainting.
        {args, vars, _} = analyze_list(args, vars, assigns, caller, [])

        opts =
          for {key, value} <- opts do
            {key, maybe_block_to_rendered(value, vars, caller)}
          end

        args ++ [opts]
      else
        _ -> args
      end

    args =
      case {call, args} do
        # If we have a component, we provide change tracking to individual keys.
        {:component, [fun, expr, metadata]} ->
          [fun, to_component_tracking(meta, fun, expr, [], vars, caller), metadata]

        {_, _} ->
          args
      end

    to_safe({left, meta, args}, true)
  end

  defp to_live_struct(expr, _vars, _assigns, _caller) do
    to_safe(expr, true)
  end

  defp extract_call({:., _, [{:__aliases__, _, [:Phoenix, :LiveView, :TagEngine]}, func]}),
    do: func

  defp extract_call(call),
    do: call

  defp maybe_block_to_rendered([{:->, _, _} | _] = blocks, vars, caller) do
    for {:->, meta, [args, block]} <- blocks do
      {args, vars, assigns} = analyze_list(args, vars, %{}, caller, [])

      case to_rendered_struct(block, untaint_vars(vars), assigns, caller, []) do
        {:ok, rendered} -> {:->, meta, [args, rendered]}
        :error -> {:->, meta, [args, block]}
      end
    end
  end

  defp maybe_block_to_rendered(block, vars, caller) do
    case to_rendered_struct(block, untaint_vars(vars), %{}, caller, []) do
      {:ok, rendered} -> rendered
      :error -> block
    end
  end

  defp to_conditional_var(:all, var, live_struct) do
    quote do: unquote(var) = unquote(live_struct)
  end

  defp to_conditional_var(keys, var, live_struct) when keys == %{} do
    quote generated: true do
      unquote(var) =
        case changed do
          %{} -> nil
          _ -> unquote(live_struct)
        end
    end
  end

  defp to_conditional_var(keys, var, live_struct) do
    quote do
      unquote(var) =
        case unquote(changed_assigns(keys)) do
          true -> unquote(live_struct)
          false -> nil
        end
    end
  end

  defp changed_assigns(assigns) do
    checks =
      for {key, _} <- assigns, not nested_and_parent_is_checked?(key, assigns) do
        case key do
          [assign] ->
            quote do
              unquote(__MODULE__).changed_assign?(changed, unquote(assign))
            end

          [assign | tail] ->
            quote do
              unquote(__MODULE__).nested_changed_assign?(
                unquote(tail),
                unquote(assign),
                unquote(@assigns_var),
                changed
              )
            end
        end
      end

    Enum.reduce(checks, &{:or, [], [&1, &2]})
  end

  defguardp is_access(mod)
            when mod == Access or
                   (is_tuple(mod) and elem(mod, 0) == :__aliases__ and elem(mod, 2) == [:Access])

  # If we are accessing @foo.bar.baz but in the same place we also pass
  # @foo.bar or @foo, we don't need to check for @foo.bar.baz.

  # If there is no nesting, then we are not nesting.
  defp nested_and_parent_is_checked?([_], _assigns),
    do: false

  # Otherwise, we convert @foo.bar.baz into [:baz, :bar, :foo], discard :baz,
  # and then check if [:foo, :bar] and then [:foo] is in it.
  defp nested_and_parent_is_checked?(keys, assigns),
    do: parent_is_checked?(tl(Enum.reverse(keys)), assigns)

  defp parent_is_checked?([], _assigns),
    do: false

  defp parent_is_checked?(rest, assigns),
    do: Map.has_key?(assigns, Enum.reverse(rest)) or parent_is_checked?(tl(rest), assigns)

  ## Component keys change tracking

  defp to_component_tracking(meta, fun, expr, extra, vars, caller) do
    # Separate static and dynamic parts
    {static, dynamic} =
      case expr do
        {{:., _, [{:__aliases__, _, [:Map]}, :merge]}, _, [dynamic, {:%{}, _, static}]} ->
          {static, dynamic}

        {:%{}, _, static} ->
          {static, %{}}

        static ->
          {static, %{}}
      end

    # And now validate the static bits. If they are not valid,
    # treat the whole thing as dynamic.
    {static, dynamic} =
      if Keyword.keyword?(static) do
        {static, dynamic}
      else
        {[], expr}
      end

    static_extra = extra ++ static

    static_changed =
      if static_extra != [] do
        keys =
          for {key, value} <- static_extra,
              # We pass empty assigns because if this code is rendered,
              # it means that upstream assigns were change tracked.
              {_, keys, _} = analyze_and_return_tainted_keys(value, vars, %{}, caller),
              # If keys are empty, it is never changed.
              keys != %{},
              do: {key, to_component_keys(keys)}

        quote do
          unquote(__MODULE__).to_component_static(unquote(keys), unquote(@assigns_var), changed)
        end
      else
        Macro.escape(%{})
      end

    static = slots_to_rendered(static, vars, caller, Keyword.get(meta, :slots, []))

    cond do
      # We can't infer anything, so return the expression as is.
      static_extra == [] and dynamic == %{} ->
        expr

      # Live components do not need to compute the changed because they track their own changed.
      match?({:&, _, [{:/, _, [{:live_component, _, _}, 1]}]}, fun) ->
        if dynamic == %{} do
          quote do: %{unquote_splicing(static)}
        else
          quote do: Map.merge(unquote(dynamic), %{unquote_splicing(static)})
        end

      # We were actually able to find some static bits, but no dynamic.
      # Embed the static parts alongside the computed changed.
      dynamic == %{} ->
        quote do
          %{unquote_splicing([__changed__: static_changed] ++ static)}
        end

      # Merge both static and dynamic.
      true ->
        {_, keys, _} = analyze_and_return_tainted_keys(dynamic, vars, %{}, caller)

        quote do
          unquote(__MODULE__).to_component_dynamic(
            %{unquote_splicing(static)},
            unquote(dynamic),
            unquote(static_changed),
            unquote(to_component_keys(keys)),
            unquote(@assigns_var),
            changed
          )
        end
    end
  end

  defp to_component_keys(:all), do: :all
  defp to_component_keys(map), do: Map.keys(map)

  @doc false
  def to_component_static(_keys, _assigns, nil) do
    nil
  end

  def to_component_static(keys, assigns, changed) do
    for {assign, entries} <- keys,
        changed = component_changed(entries, assigns, changed),
        into: %{},
        do: {assign, changed}
  end

  @doc false
  def to_component_dynamic(static, dynamic, _static_changed, _keys, _assigns, nil) do
    merge_dynamic_static_changed(dynamic, static, nil)
  end

  def to_component_dynamic(static, dynamic, static_changed, keys, assigns, changed) do
    component_changed =
      if component_changed(keys, assigns, changed) do
        Enum.reduce(dynamic, static_changed, fn {k, _}, acc -> Map.put(acc, k, true) end)
      else
        static_changed
      end

    merge_dynamic_static_changed(dynamic, static, component_changed)
  end

  defp merge_dynamic_static_changed(dynamic, static, changed) do
    dynamic |> Map.merge(static) |> Map.put(:__changed__, changed)
  end

  defp component_changed(:all, _assigns, _changed), do: true

  defp component_changed([path], assigns, changed) do
    case path do
      [key] -> changed_assign(changed, key)
      [key | tail] -> nested_changed_assign(tail, key, assigns, changed)
    end
  end

  defp component_changed(entries, assigns, changed) do
    Enum.any?(entries, fn
      [key] -> changed_assign?(changed, key)
      [key | tail] -> nested_changed_assign?(tail, key, assigns, changed)
    end)
  end

  defp slots_to_rendered(static, vars, caller, slots) do
    for {key, value} <- static do
      value =
        if key in slots do
          slot_to_rendered(value, key, vars, caller)
        else
          value
        end

      {key, value}
    end
  end

  defp slot_to_rendered(
         {:%{}, map_meta, [__slot__: key, inner_block: inner_block] ++ attrs} = maybe_slot,
         key,
         vars,
         caller
       ) do
    with {call, meta, [^key, [do: block]]} <- inner_block,
         :inner_block <- extract_call(call) do
      inner_block = {call, meta, [key, [do: maybe_block_to_rendered(block, vars, caller)]]}

      {:%{}, map_meta, [__slot__: key, inner_block: inner_block] ++ attrs}
    else
      _ -> maybe_slot
    end
  end

  defp slot_to_rendered({left, meta, args}, key, vars, caller) do
    {left, meta, slot_to_rendered(args, key, vars, caller)}
  end

  defp slot_to_rendered({left, right}, key, vars, caller) do
    {slot_to_rendered(left, key, vars, caller), slot_to_rendered(right, key, vars, caller)}
  end

  defp slot_to_rendered(list, key, vars, caller) when is_list(list) do
    Enum.map(list, &slot_to_rendered(&1, key, vars, caller))
  end

  defp slot_to_rendered(other, _key, _vars, _caller) do
    other
  end

  ## Extracts binaries and variable from iodata

  defp bins_and_vars(acc),
    do: bins_and_vars(acc, [], [])

  defp bins_and_vars([bin1, bin2 | acc], bins, vars) when is_binary(bin1) and is_binary(bin2),
    do: bins_and_vars([bin1 <> bin2 | acc], bins, vars)

  defp bins_and_vars([bin, var | acc], bins, vars) when is_binary(bin) and is_tuple(var),
    do: bins_and_vars(acc, [bin | bins], [var | vars])

  defp bins_and_vars([var | acc], bins, vars) when is_tuple(var),
    do: bins_and_vars(acc, ["" | bins], [var | vars])

  defp bins_and_vars([bin], bins, vars) when is_binary(bin),
    do: {Enum.reverse([bin | bins]), Enum.reverse(vars)}

  defp bins_and_vars([], bins, vars),
    do: {Enum.reverse(["" | bins]), Enum.reverse(vars)}

  ## Assigns tracking

  # Here we compute if an expression should be always computed,
  # never computed, or some times computed based on assigns.
  #
  # If any assign is used, we store it in the assigns and use it to compute
  # if it should be changed or not.
  #
  # However, operations that change the lexical scope, such as imports and
  # defining variables, taint the analysis. Because variables can be set at
  # any moment in Elixir, via macros, without appearing on the left side of
  # `=` or in a clause, whenever we see a variable, we consider it as tainted,
  # regardless of its position.
  #
  # The tainting that happens from lexical scope is called weak-tainting,
  # because it is disabled under certain special forms. There is also
  # strong-tainting, which are always computed. Strong-tainting only happens
  # if the `assigns` variable is used.
  defp analyze_and_return_tainted_keys(ast, vars, assigns, caller) do
    {ast, vars, assigns} = analyze(ast, vars, assigns, caller)
    {tainted_assigns?, assigns} = Map.pop(assigns, __MODULE__, false)
    keys = if match?({:tainted, _}, vars) or tainted_assigns?, do: :all, else: assigns
    {ast, keys, vars}
  end

  # @name
  defp analyze_assign({:@, meta, [{name, _, context}]}, vars, assigns, _caller, nest)
       when is_atom(name) and is_atom(context) do
    expr = {{:., meta, [@assigns_var, name]}, [no_parens: true] ++ meta, []}
    {expr, vars, Map.put(assigns, [name | nest], true)}
  end

  # assigns.name
  defp analyze_assign(
         {{:., _, [{:assigns, _, nil}, name]}, _, args} = expr,
         vars,
         assigns,
         _caller,
         nest
       )
       when is_atom(name) and args in [[], nil] do
    {expr, vars, Map.put(assigns, [name | nest], true)}
  end

  # assigns[:name]
  defp analyze_assign(
         {{:., _, [access, :get]}, _, [{:assigns, _, nil}, name]} = expr,
         vars,
         assigns,
         _caller,
         nest
       )
       when is_atom(name) and is_access(access) do
    {expr, vars, Map.put(assigns, [name | nest], true)}
  end

  # Maybe: assigns.foo[:bar]
  defp analyze_assign(
         {{:., dot_meta, [access, :get]}, meta, [left, right]},
         vars,
         assigns,
         caller,
         nest
       )
       when is_access(access) do
    {args, vars, assigns} =
      if Macro.quoted_literal?(right) do
        {left, vars, assigns} =
          analyze_assign(left, vars, assigns, caller, [{:access, right} | nest])

        {[left, right], vars, assigns}
      else
        {left, vars, assigns} = analyze(left, vars, assigns, caller)
        {right, vars, assigns} = analyze(right, vars, assigns, caller)
        {[left, right], vars, assigns}
      end

    {{{:., dot_meta, [Access, :get]}, meta, args}, vars, assigns}
  end

  # Maybe: assigns.foo.bar
  defp analyze_assign({{:., dot_meta, [left, right]}, meta, args}, vars, assigns, caller, nest)
       when args in [[], nil] do
    {left, vars, assigns} = analyze_assign(left, vars, assigns, caller, [{:struct, right} | nest])
    {{{:., dot_meta, [left, right]}, meta, []}, vars, assigns}
  end

  defp analyze_assign(expr, vars, assigns, caller, _nest) do
    analyze(expr, vars, assigns, caller)
  end

  # Delegates to analyze assign
  defp analyze({{:., _, [access, :get]}, _, [_, _]} = expr, vars, assigns, caller)
       when is_access(access) do
    analyze_assign(expr, vars, assigns, caller, [])
  end

  defp analyze({{:., _, [_, _]}, _, args} = expr, vars, assigns, caller) when args in [[], nil] do
    analyze_assign(expr, vars, assigns, caller, [])
  end

  defp analyze({:@, _, [{name, _, context}]} = expr, vars, assigns, caller)
       when is_atom(name) and is_atom(context) do
    analyze_assign(expr, vars, assigns, caller, [])
  end

  # Assigns is a strong-taint
  defp analyze({:assigns, _, nil} = expr, vars, assigns, _caller) do
    {expr, vars, taint_assigns(assigns)}
  end

  # Ignore underscore
  defp analyze({:_, _, context} = expr, vars, assigns, _caller) when is_atom(context) do
    {expr, vars, assigns}
  end

  # Also skip special variables
  defp analyze({name, _, context} = expr, vars, assigns, _caller)
       when name in [:__MODULE__, :__ENV__, :__STACKTRACE__, :__DIR__] and is_atom(context) do
    {expr, vars, assigns}
  end

  # Vars always taint unless we are in restricted mode.
  defp analyze({name, meta, nil} = expr, {:restricted, map}, assigns, caller)
       when is_atom(name) do
    if Map.has_key?(map, name) do
      maybe_warn_taint(name, meta, caller)
      {expr, {:tainted, map}, assigns}
    else
      {expr, {:restricted, map}, assigns}
    end
  end

  defp analyze({name, meta, nil} = expr, {_, map}, assigns, caller) when is_atom(name) do
    maybe_warn_taint(name, meta, caller)
    {expr, {:tainted, Map.put(map, name, true)}, assigns}
  end

  # Quoted vars are ignored as they come from engine code.
  defp analyze({name, _meta, context} = expr, vars, assigns, _caller)
       when is_atom(name) and is_atom(context) do
    {expr, vars, assigns}
  end

  # Ignore right side of |> if a variable
  defp analyze({:|>, meta, [left, {_, _, context} = right]}, vars, assigns, caller)
       when is_atom(context) do
    {left, vars, assigns} = analyze(left, vars, assigns, caller)
    {{:|>, meta, [left, right]}, vars, assigns}
  end

  # Ignore binary modifiers
  defp analyze({:"::", meta, [left, right]}, vars, assigns, caller) do
    {left, vars, assigns} = analyze(left, vars, assigns, caller)
    {{:"::", meta, [left, right]}, vars, assigns}
  end

  # Handle for/with to consider the first generator.
  # Ideally we would track all variables on the patterns and expand all generators
  # but except for the unlikely scenario of combinations, all comprehensions will
  # be using nested generators.
  defp analyze({for_with, meta, [{:<-, arrow_meta, [left, right]} | args]}, vars, assigns, caller)
       when for_with in [:for, :with] do
    {right, vars, assigns} = analyze(right, vars, assigns, caller)

    {[left | args], vars, assigns} =
      analyze_with_restricted_vars([left | args], vars, assigns, caller)

    {{for_with, meta, [{:<-, arrow_meta, [left, right]} | args]}, vars, assigns}
  end

  # Classify calls
  defp analyze({left, meta, args}, vars, assigns, caller) do
    call = extract_call(left)

    case classify_taint(call, args) do
      :special_form ->
        code = quote do: unquote(__MODULE__).__raise__(unquote(call), unquote(length(args)))
        {code, vars, assigns}

      :none ->
        {left, vars, assigns} = analyze(left, vars, assigns, caller)
        {args, vars, assigns} = analyze_list(args, vars, assigns, caller, [])
        {{left, meta, args}, vars, assigns}

      :live ->
        {args, [opts]} = Enum.split(args, -1)
        {args, vars, assigns} = analyze_skip_assignment_list(args, vars, assigns, caller, [])
        {opts, vars, assigns} = analyze_with_restricted_vars(opts, vars, assigns, caller)
        {{left, meta, args ++ [opts]}, vars, assigns}

      :never ->
        {args, vars, assigns} = analyze_with_restricted_vars(args, vars, assigns, caller)
        {{left, meta, args}, vars, assigns}
    end
  end

  defp analyze({left, right}, vars, assigns, caller) do
    {left, vars, assigns} = analyze(left, vars, assigns, caller)
    {right, vars, assigns} = analyze(right, vars, assigns, caller)
    {{left, right}, vars, assigns}
  end

  defp analyze([_ | _] = list, vars, assigns, caller) do
    analyze_list(list, vars, assigns, caller, [])
  end

  defp analyze(other, vars, assigns, _caller) do
    {other, vars, assigns}
  end

  defp analyze_list([head | tail], vars, assigns, caller, acc) do
    {head, vars, assigns} = analyze(head, vars, assigns, caller)
    analyze_list(tail, vars, assigns, caller, [head | acc])
  end

  defp analyze_list([], vars, assigns, _caller, acc) do
    {Enum.reverse(acc), vars, assigns}
  end

  defp analyze_skip_assignment_list(
         [{:=, meta, [left, right]} | tail],
         vars,
         assigns,
         caller,
         acc
       ) do
    {right, vars, assigns} = analyze(right, vars, assigns, caller)
    analyze_skip_assignment_list(tail, vars, assigns, caller, [{:=, meta, [left, right]} | acc])
  end

  defp analyze_skip_assignment_list([head | tail], vars, assigns, caller, acc) do
    {head, vars, assigns} = analyze(head, vars, assigns, caller)
    analyze_skip_assignment_list(tail, vars, assigns, caller, [head | acc])
  end

  defp analyze_skip_assignment_list([], vars, assigns, _caller, acc) do
    {Enum.reverse(acc), vars, assigns}
  end

  # vars is one of:
  #
  #   * {:tainted, map}
  #   * {:restricted, map}
  #   * {:untainted, map}
  #
  # Seeing a variable at any moment taints it unless we are inside a
  # scope. For example, in case/cond/with/fn/try, the variable is only
  # tainted if it came from outside of the case/cond/with/fn/try.
  # So for those constructs we set the mode to restricted and stop
  # collecting vars.
  defp analyze_with_restricted_vars(ast, {kind, map}, assigns, caller) do
    {ast, {new_kind, _}, assigns} =
      analyze(ast, {unless_tainted(kind, :restricted), map}, assigns, caller)

    {ast, {unless_tainted(new_kind, kind), map}, assigns}
  end

  defp set_vars({kind, _}, {_, map}), do: {kind, map}
  defp taint_vars({_, map}), do: {:tainted, map}
  defp untaint_vars({_, map}), do: {:untainted, map}

  defp unless_tainted(:tainted, _), do: :tainted
  defp unless_tainted(_, kind), do: kind

  defp taint_assigns(assigns), do: Map.put(assigns, __MODULE__, true)

  ## Callbacks

  defp maybe_warn_taint(name, meta, caller) do
    if caller && Macro.Env.has_var?(caller, {name, nil}) do
      message = """
      you are accessing the variable \"#{name}\" inside a LiveView template.

      Using variables in HEEx templates are discouraged as they disable change tracking. \
      You are only allowed to access variables defined by Elixir control-flow structures, \
      such as if/case/for, or those defined by the special attributes :let/:if/:for. \
      If you are shadowing a variable defined outside of the template using a control-flow \
      structure, you must choose a unique variable name within the template.

      Instead of:

          def add(assigns) do
            result = assigns.a + assigns.b
            ~H"the result is: <%= result %>"
          end

      You must do:

          def add(assigns) do
            assigns = assign(assigns, :result, assigns.a + assigns.b)
            ~H"the result is: <%= @result %>"
          end
      """

      line = meta[:line] || caller.line
      IO.warn(message, Macro.Env.stacktrace(%{caller | line: line}))
    end
  end

  defp fingerprint(block, static) do
    # The fingerprint must be unique and we don’t check for collisions in the
    # Diff module as doing so would be expensive. Therefore it is important
    # that the algorithm we use here has a low number of collisions.

    <<fingerprint::8*16>> =
      [block | static]
      |> :erlang.term_to_binary()
      |> :erlang.md5()

    fingerprint
  end

  @doc false
  defmacro __raise__(special_form, arity) do
    message = "cannot invoke special form #{special_form}/#{arity} inside HEEx templates"
    reraise ArgumentError.exception(message), Macro.Env.stacktrace(__CALLER__)
  end

  @doc false
  defmacro to_safe(ast) do
    to_safe(ast, false)
  end

  defp to_safe(ast, bool) do
    to_safe(ast, line_from_expr(ast), bool)
  end

  defp line_from_expr({_, meta, _}) when is_list(meta), do: Keyword.get(meta, :line, 0)
  defp line_from_expr(_), do: 0

  defp to_safe(literal, _line, _extra_clauses?)
       when is_binary(literal) or is_atom(literal) or is_number(literal) do
    literal
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp to_safe(literal, line, _extra_clauses?) when is_list(literal) do
    quote line: line, do: Phoenix.HTML.Safe.List.to_iodata(unquote(literal))
  end

  # Calls to attributes escape is always safe
  defp to_safe(
         {{:., _, [Phoenix.LiveView.TagEngine, :attributes_escape]}, _, [_]} = safe,
         line,
         _extra_clauses?
       ) do
    quote line: line do
      elem(unquote(safe), 1)
    end
  end

  defp to_safe(expr, line, false) do
    quote line: line, do: unquote(__MODULE__).safe_to_iodata(unquote(expr))
  end

  defp to_safe(expr, line, true) do
    quote line: line, do: unquote(__MODULE__).live_to_iodata(unquote(expr))
  end

  @doc false
  def safe_to_iodata(expr) do
    case expr do
      {:safe, data} -> data
      bin when is_binary(bin) -> Plug.HTML.html_escape_to_iodata(bin)
      other -> Phoenix.HTML.Safe.to_iodata(other)
    end
  end

  @doc false
  def live_to_iodata(expr) do
    case expr do
      {:safe, data} -> data
      %{__struct__: Phoenix.LiveView.Rendered} = other -> other
      %{__struct__: Phoenix.LiveView.Component} = other -> other
      %{__struct__: Phoenix.LiveView.Comprehension} = other -> other
      bin when is_binary(bin) -> Plug.HTML.html_escape_to_iodata(bin)
      other -> Phoenix.HTML.Safe.to_iodata(other)
    end
  end

  @doc false
  def changed_assign?(changed, name) do
    case changed do
      %{^name => _} -> true
      %{} -> false
      nil -> true
    end
  end

  defp changed_assign(changed, name) do
    case changed do
      %{^name => value} -> value
      %{} -> false
      nil -> true
    end
  end

  @doc false
  def nested_changed_assign?(tail, head, assigns, changed),
    do: nested_changed_assign(tail, head, assigns, changed) != false

  defp nested_changed_assign(tail, head, assigns, changed) do
    case changed do
      %{^head => changed} ->
        case assigns do
          %{^head => assigns} -> recur_changed_assign(tail, assigns, changed)
          %{} -> true
        end

      %{} ->
        false

      nil ->
        true
    end
  end

  defp recur_changed_assign([{:struct, head} | tail], assigns, changed) do
    recur_changed_assign(tail, head, assigns, changed)
  end

  defp recur_changed_assign([{:access, head}], %Form{} = form1, %Form{} = form2) do
    Form.input_changed?(form1, form2, head)
  end

  defp recur_changed_assign([{:access, head} | tail], assigns, changed) do
    if match?(%_{}, assigns) or match?(%_{}, changed) do
      true
    else
      recur_changed_assign(tail, head, assigns, changed)
    end
  end

  defp recur_changed_assign([], head, assigns, changed) do
    case {assigns, changed} do
      {%{^head => value}, %{^head => value}} -> false
      {_, %{^head => value}} when is_map(value) -> value
      {_, _} -> true
    end
  end

  defp recur_changed_assign(tail, head, assigns, changed) do
    case {assigns, changed} do
      {%{^head => assigns_value}, %{^head => changed_value}} ->
        recur_changed_assign(tail, assigns_value, changed_value)

      {_, _} ->
        true
    end
  end

  # For case/if/unless in particular, we are not leaking the
  # variables defined in arguments, such as `if var = ... do`.
  # This does not follow Elixir semantics, but yields better
  # optimizations.
  defp classify_taint(:case, [_, _]), do: :live
  defp classify_taint(:if, [_, _]), do: :live
  defp classify_taint(:unless, [_, _]), do: :live
  defp classify_taint(:cond, [_]), do: :live
  defp classify_taint(:try, [_]), do: :live
  defp classify_taint(:receive, [_]), do: :live

  # with/for are specially handled during analyze
  defp classify_taint(:with, [_ | _]), do: :live
  defp classify_taint(:for, [_ | _]), do: :live

  # Constructs from Phoenix and TagEngine
  defp classify_taint(:inner_block, [_, [do: _]]), do: :live
  defp classify_taint(:render_layout, [_, _, _, [do: _]]), do: :live

  # Special forms are forbidden and raise.
  defp classify_taint(:alias, [_]), do: :special_form
  defp classify_taint(:import, [_]), do: :special_form
  defp classify_taint(:require, [_]), do: :special_form
  defp classify_taint(:alias, [_, _]), do: :special_form
  defp classify_taint(:import, [_, _]), do: :special_form
  defp classify_taint(:require, [_, _]), do: :special_form

  defp classify_taint(:&, [_]), do: :never
  defp classify_taint(:fn, _), do: :never
  defp classify_taint(_, _), do: :none
end

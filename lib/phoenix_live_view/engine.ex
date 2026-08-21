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
  """
  defstruct [:static, :has_key?, :entries, :fingerprint, :stream]

  @type key :: term()
  @type keyed_render_fun :: (map(), boolean() -> [Phoenix.LiveView.Rendered.dyn()])

  @type t :: %__MODULE__{
          static: [String.t()] | non_neg_integer(),
          has_key?: boolean(),
          # Each entry is a three-element tuple.
          #
          #   The first element is the evaluated key (or nil if there is none).
          #
          #   The second element is a map of variables to be change-tracked.
          #
          #   The third element is the keyed render function that receives the vars_changed map,
          #   and a boolean to enable or disable change tracking.
          #
          entries: [{key(), map(), keyed_render_fun()}],
          fingerprint: term(),
          stream: list() | nil
        }

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%Phoenix.LiveView.Comprehension{static: static, entries: entries}) do
      for {_key, _vars, render} <- entries, do: to_iodata(static, render.(%{}, false))
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

  @type dyn ::
          nil
          | iodata()
          | Phoenix.LiveView.Rendered.t()
          | Phoenix.LiveView.Comprehension.t()
          | Phoenix.LiveView.Component.t()

  @type t :: %__MODULE__{
          static: [String.t()],
          dynamic: (boolean() -> [dyn()]),
          fingerprint: integer(),
          root: nil | true | false,
          caller:
            :not_available
            | {module(), function :: {atom(), non_neg_integer()}, file :: String.t(),
               line :: pos_integer()}
        }

  defimpl Phoenix.HTML.Safe do
    def to_iodata(data) do
      recur_iodata(data)
    end

    defp recur_iodata(%Phoenix.LiveView.Rendered{static: static, dynamic: dynamic}) do
      recur_iodata(static, dynamic.(false))
    end

    defp recur_iodata(%_{} = struct) do
      Phoenix.HTML.Safe.to_iodata(struct)
    end

    defp recur_iodata(other) do
      other
    end

    defp recur_iodata([static_head | static_tail], [dynamic_head | dynamic_tail]) do
      [static_head, recur_iodata(dynamic_head) | recur_iodata(static_tail, dynamic_tail)]
    end

    defp recur_iodata([static_head], []) do
      [static_head]
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

  ```heex
  {render("form.html", assigns)}
  ```

  Phoenix will be able to track what is static and dynamic
  across templates, as well as what changed. A rendered
  nested `live` template will appear in the `dynamic`
  list as another `Phoenix.LiveView.Rendered` structure,
  which must be handled recursively.

  However, because the rendering of live templates can
  be dynamic in itself, it is important to distinguish
  which live template was rendered. For example,
  imagine this code:

  ```heex
  <%= if something?, do: render("one.html", assigns), else: render("other.html", assigns) %>
  ```

  To solve this, all `Phoenix.LiveView.Rendered` structs
  also contain a fingerprint field that uniquely identifies
  it. If the fingerprints are equal, you have the same
  template, and therefore it is possible to only transmit
  its changes.

  ## Comprehensions

  Another optimization done by live templates is to
  track comprehensions. If your code has this:

  ```heex
  <%= for point <- @points do %>
    x: {point.x}
    y: {point.y}
  <% end %>
  ```

  Instead of rendering all points with both static and
  dynamic parts, it returns a `Phoenix.LiveView.Comprehension`
  struct with the static parts, that are shared across all
  points, and a list of entries with a render function for the
  dynamics inside. If `@points` is a list with `%{x: 1, y: 2}`
  and `%{x: 3, y: 4}`, the above expression would return:

      %Phoenix.LiveView.Comprehension{
        static: ["\n  x: ", "\n  y: ", "\n"],
        entries: [
          {nil, %{point: %{x: 1, y: 2}}, fn vars_changed, track_changes? -> ... end,
          {nil, %{point: %{x: 3, y: 4}}, fn vars_changed, track_changes? -> ... end,
        ]
      }

  This allows live templates to send the static parts only once,
  regardless of the number of items. Moreover, the diff algorithm
  also tracks the variables introduced by the comprehension as part
  of the entries and calculates which variables changed between renders.

  In HEEx templates, a `:key` attribute can be provided when using `:for`
  on a tag to make the diffing more efficient. By default, the index
  of each item is used for diffing, which means that if an element is
  prepended to the list, the whole collection is sent again.

  ## Components

  Live also supports stateful components defined with
  `Phoenix.LiveComponent`. Since they are stateful, they are always
  handled lazily by the diff algorithm.
  """

  alias Phoenix.LiveView.Assigns
  @behaviour Phoenix.Template.Engine

  @impl true
  def compile(path, _name) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)
    EEx.compile_file(path, engine: __MODULE__, line: 1, trim: trim)
  end

  @behaviour EEx.Engine
  @assigns_var Assigns.assigns_var()

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
  def handle_end(state, opts \\ []) do
    %{static: static, dynamic: dynamic} = state
    safe = {:safe, Enum.reverse(static)}
    meta = [live_rendered: true] ++ Keyword.get(opts, :meta, [])
    {:__block__, meta, Enum.reverse([safe | dynamic])}
  end

  @impl true
  def handle_body(state, opts \\ []) do
    {:ok, rendered} =
      state
      |> handle_end(opts)
      |> to_rendered_struct({:untainted, %{}}, %{}, state, opts)

    quote do
      require Phoenix.LiveView.Engine
      vars_changed = nil
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
    var = new_var(counter)
    ast = quote do: unquote(var) = unquote(__MODULE__).to_safe(unquote(ast))
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

  defp new_var(counter) do
    i = :counters.get(counter, 1)
    :counters.add(counter, 1, 1)
    Macro.var(:"v#{i}", __MODULE__)
  end

  defp to_rendered_struct(expr, vars, assigns, state, opts) do
    with {:__block__, [live_rendered: true] ++ meta, entries} <- expr,
         {dynamic, [{:safe, static}]} <- Enum.split(entries, -1) do
      {block, static, dynamic, fingerprint} =
        analyze_static_and_dynamic(static, dynamic, vars, assigns, state)

      static =
        case Keyword.fetch(meta, :template_annotation) do
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

      root = Keyword.get(opts, :root, meta[:root])

      dynamic =
        if dynamic == [] do
          quote do
            fn _ ->
              _ = unquote(@assigns_var)
              []
            end
          end
        else
          quote generated: true do
            fn track_changes? ->
              changed = unquote(changed)
              vars_changed = if track_changes?, do: vars_changed
              unquote({:__block__, [], block})
              unquote(dynamic)
            end
          end
        end

      {:ok,
       quote do
         dynamic = unquote(dynamic)

         %Phoenix.LiveView.Rendered{
           static: unquote(static),
           dynamic: dynamic,
           fingerprint: unquote(fingerprint),
           root: unquote(root)
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

  defp analyze_static_and_dynamic(static, dynamic, initial_vars, assigns, state) do
    caller = state.caller

    {block, _} =
      Enum.map_reduce(dynamic, initial_vars, fn
        to_safe_match(var, ast), vars ->
          vars = set_vars(initial_vars, vars)
          {ast, keys, vars} = Assigns.analyze_and_return_tainted_keys(ast, vars, assigns, caller, &maybe_warn_taint/3)
          live_struct = to_live_struct(ast, vars, assigns, state)
          {to_conditional_var(keys, var, live_struct), vars}

        ast, vars ->
          vars = set_vars(initial_vars, vars)
          {ast, vars, _} = Assigns.analyze(ast, vars, assigns, caller, &maybe_warn_taint/3)
          {ast, vars}
      end)

    {static, dynamic} = bins_and_vars(static)
    {block, static, dynamic, fingerprint(block, static)}
  end

  defp set_vars({kind, _}, {_, map}), do: {kind, map}
  defp untaint_vars({_, map}), do: {:untainted, map}

  ## Optimize possible expressions into live structs (rendered / comprehensions)

  defp to_live_struct({:for, _, [_ | _]} = expr, vars, assigns, state) do
    with {:for, meta, [gen | args]} <- expr,
         {:<-, gen_meta, [gen_pattern, gen_collection]} <- gen,
         {filters, [[do: {:__block__, _, block}]]} <- Enum.split(args, -1),
         {dynamic, [{:safe, static}]} <- Enum.split(block, -1) do
      gen_var = new_var(state.counter)
      caller = state.caller

      gen_collection =
        quote do
          unquote(gen_var) =
            Phoenix.LiveView.LiveStream.mark_consumable(unquote(gen_collection))
        end

      {gen_pattern, variables} = mark_variables_as_change_tracked(gen_pattern, %{})
      {gen_pattern, vars, _} = Assigns.analyze(gen_pattern, vars, assigns, caller, &maybe_warn_taint/3)

      {block, static, dynamic, fingerprint} =
        analyze_static_and_dynamic(static, dynamic, vars, %{}, state)

      key_expr =
        case Keyword.get(gen_meta, :key_expr) do
          nil ->
            nil

          expr ->
            {expr, _vars, _} = Assigns.analyze(expr, vars, assigns, caller, &maybe_warn_taint/3)
            expr
        end

      dynamic =
        quote generated: true do
          fn local_vars_changed, track_changes? ->
            vars_changed =
              case local_vars_changed do
                %{} when track_changes? ->
                  Map.merge(vars_changed || %{}, local_vars_changed)

                _ ->
                  nil
              end

            changed = if track_changes?, do: changed
            unquote({:__block__, [], block ++ [dynamic]})
          end
        end

      entry =
        quote do
          {unquote(key_expr), %{unquote_splicing(Map.to_list(variables))}, unquote(dynamic)}
        end

      gen = {:<-, gen_meta, [gen_pattern, gen_var]}
      for = {:for, meta, [gen | filters] ++ [[do: entry]]}

      quote do
        unquote(gen_collection)

        Phoenix.LiveView.LiveStream.annotate_comprehension(
          %Phoenix.LiveView.Comprehension{
            has_key?: unquote(key_expr != nil),
            static: unquote(static),
            entries: unquote(for),
            fingerprint: unquote(fingerprint)
          },
          unquote(gen_var)
        )
      end
    else
      _ -> to_safe(expr, true)
    end
  end

  defp to_live_struct({left, meta, [_ | _] = args}, vars, assigns, state) do
    caller = state.caller
    call = extract_call(left)

    args =
      with :live <- Assigns.classify_taint(call, args),
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
        {args, vars, _} = Assigns.analyze_list(args, vars, assigns, caller, [], &maybe_warn_taint/3)

        opts =
          for {key, value} <- opts do
            {key, maybe_block_to_rendered(value, vars, state)}
          end

        args ++ [opts]
      else
        _ -> args
      end

    args =
      case {call, args} do
        # If we have a component, we provide change tracking to individual keys.
        {:component, [fun, expr, metadata]} ->
          [fun, to_component_tracking(meta, fun, expr, [], vars, state), metadata]

        {_, _} ->
          args
      end

    to_safe({left, meta, args}, true)
  end

  defp to_live_struct(expr, _vars, _assigns, _state) do
    to_safe(expr, true)
  end

  @doc false
  def mark_variables_as_change_tracked({:^, _, [_]} = ast, vars) do
    {ast, vars}
  end

  def mark_variables_as_change_tracked({:"::", meta, [left, right]}, vars) do
    {left, vars} = mark_variables_as_change_tracked(left, vars)
    {{:"::", meta, [left, right]}, vars}
  end

  def mark_variables_as_change_tracked({name, meta, context}, vars)
      when is_atom(name) and is_list(meta) and is_atom(context) do
    case Atom.to_string(name) do
      "_" <> _rest ->
        {{name, meta, context}, vars}

      _ ->
        var = {name, [change_track: true] ++ meta, context}
        {var, Map.put(vars, name, var)}
    end
  end

  def mark_variables_as_change_tracked({left, meta, right}, vars) do
    {left, vars} = mark_variables_as_change_tracked(left, vars)
    {right, vars} = mark_variables_as_change_tracked(right, vars)
    {{left, meta, right}, vars}
  end

  def mark_variables_as_change_tracked({left, right}, vars) do
    {left, vars} = mark_variables_as_change_tracked(left, vars)
    {right, vars} = mark_variables_as_change_tracked(right, vars)
    {{left, right}, vars}
  end

  def mark_variables_as_change_tracked([_ | _] = list, vars) do
    Enum.map_reduce(list, vars, &mark_variables_as_change_tracked/2)
  end

  def mark_variables_as_change_tracked(other, vars) do
    {other, vars}
  end

  defp extract_call({:., _, [{:__aliases__, _, [:Phoenix, :LiveView, :TagEngine]}, func]}),
    do: func

  defp extract_call(call),
    do: call

  defp maybe_block_to_rendered([{:->, _, _} | _] = blocks, vars, state) do
    caller = state.caller

    for {:->, meta, [args, block]} <- blocks do
      {args, vars, assigns} = Assigns.analyze_list(args, vars, %{}, caller, [], &maybe_warn_taint/3)

      case to_rendered_struct(block, untaint_vars(vars), assigns, state, []) do
        {:ok, rendered} -> {:->, meta, [args, rendered]}
        :error -> {:->, meta, [args, block]}
      end
    end
  end

  defp maybe_block_to_rendered(block, vars, state) do
    case to_rendered_struct(block, untaint_vars(vars), %{}, state, []) do
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
      for {{changed_var, key}, _} <- assigns,
          not Assigns.nested_and_parent_is_checked?(changed_var, key, assigns) do
        changed = Macro.var(changed_var, Phoenix.LiveView.Engine)

        case key do
          [assign] ->
            quote do
              Phoenix.LiveView.Assigns.changed_assign?(unquote(changed), unquote(assign))
            end

          [assign | tail] ->
            assigns_var =
              case changed_var do
                :changed ->
                  @assigns_var

                :vars_changed ->
                  # we pass a map %{var: var} for nested change tracking
                  quote do
                    %{unquote(assign) => unquote(Macro.var(assign, nil))}
                  end
              end

            quote do
              Phoenix.LiveView.Assigns.nested_changed_assign?(
                unquote(tail),
                unquote(assign),
                unquote(assigns_var),
                unquote(changed)
              )
            end
        end
      end

    Enum.reduce(checks, &{:or, [], [&1, &2]})
  end

  ## Component keys change tracking

  defp to_component_tracking(meta, fun, expr, extra, vars, state) do
    caller = state.caller

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

    # Rewrite slots in static parts
    static = slots_to_rendered(static, vars, state, Keyword.get(meta, :slots, []))

    static =
      cond do
        # Live components have their own tracking, so we skip the logic below
        match?({:&, _, [{:/, _, [{:live_component, _, _}, 1]}]}, fun) ->
          static

        # Compute change tracking for static parts
        static_extra != [] and (dynamic == %{} or without_dependencies?(dynamic, vars, caller)) ->
          keys =
            for {key, value} <- static_extra,
                # We pass empty assigns because if this code is rendered,
                # it means that upstream assigns were change tracked.
                {_, keys, _} = Assigns.analyze_and_return_tainted_keys(value, vars, %{}, caller, &maybe_warn_taint/3),
                # If keys are empty, it is never changed.
                keys != %{},
                do: {key, to_component_keys(keys)}

          # [id: [changed: [:id]], children: [vars_changed: [:children]]]
          # -> [changed: [:id], vars_changed: [:children]]
          vars_changed_keys =
            Enum.flat_map(keys, fn
              {_assign, :all} -> []
              {_assign, keys} -> keys
            end)

          static_changed =
            quote do
              unquote(__MODULE__).to_component_static(
                unquote(keys),
                unquote(@assigns_var),
                changed,
                %{unquote_splicing(vars_changed_vars(vars_changed_keys))},
                vars_changed
              )
            end

          [__changed__: static_changed] ++ static

        true ->
          # We must disable change tracking when there is a non empty dynamic part
          # (for example `<.my_component {assigns}>`) in case the parent assigns
          # already contain a `__changed__` key
          [__changed__: nil] ++ static
      end

    if dynamic == %{} do
      quote do: %{unquote_splicing(static)}
    else
      quote do: Map.merge(unquote(dynamic), %{unquote_splicing(static)})
    end
  end

  defp without_dependencies?(ast, vars, caller) do
    {_, keys, _} = Assigns.analyze_and_return_tainted_keys(ast, vars, %{}, caller, &maybe_warn_taint/3)
    keys == %{}
  end

  defp to_component_keys(:all), do: :all
  defp to_component_keys(map), do: Map.keys(map)

  defp vars_changed_vars(keys) do
    # when we calculate the changed map for components, we need to
    # also pass the variables for vars_changed;
    # we do that by going over the keys [changed: [:id], vars_changed: [:item, struct: :name]]
    # which would mean that the component accesses @id and item.name, thus
    # we need to pass %{item: item} as "vars_changed_vars" to be later checked by nested_changed_assign
    Enum.flat_map(keys, fn
      {:vars_changed, [var | _]} ->
        [{var, Macro.var(var, nil)}]

      _ ->
        []
    end)
    |> Enum.uniq()
  end

  @doc false
  def to_component_static(_keys, _assigns, nil, _vars_changed_vars, nil) do
    nil
  end

  def to_component_static(keys, assigns, changed, vars_changed_vars, vars_changed) do
    for {assign, entries} <- keys,
        changed = component_changed(entries, assigns, changed, vars_changed_vars, vars_changed),
        into: %{},
        do: {assign, changed}
  end

  defp component_changed(:all, _assigns, _changed, _vars_changed_vars, _vars_changed), do: true

  defp component_changed([path], assigns, changed, vars_changed_vars, vars_changed) do
    case path do
      {:changed, [key]} ->
       Assigns.changed_assign(changed, key)

      {:changed, [key | tail]} ->
        Assigns.nested_changed_assign(tail, key, assigns, changed)

      {:vars_changed, [key]} ->
        Assigns.changed_assign(vars_changed, key)

      {:vars_changed, [key | tail]} ->
        Assigns.nested_changed_assign(tail, key, vars_changed_vars, vars_changed)
    end
  end

  defp component_changed(entries, assigns, changed, vars_changed_vars, vars_changed) do
    Enum.any?(entries, fn
      {:changed, [key]} ->
        Assigns.changed_assign?(changed, key)

      {:changed, [key | tail]} ->
        Assigns.nested_changed_assign?(tail, key, assigns, changed)

      {:vars_changed, [key]} ->
        Assigns.changed_assign?(vars_changed, key)

      {:vars_changed, [key | tail]} ->
        Assigns.nested_changed_assign?(tail, key, vars_changed_vars, vars_changed)
    end)
  end

  defp slots_to_rendered(static, vars, state, slots) do
    for {key, value} <- static do
      value =
        if key in slots do
          slot_to_rendered(value, key, vars, state)
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
         state
       ) do
    with {call, meta, [^key, [do: block]]} <- inner_block,
         :inner_block <- extract_call(call) do
      inner_block =
        case block do
          [
            {:->, _,
             [
               [{:_, _, _}],
               {:__block__, [live_rendered: true] ++ _meta, [{:safe, _}]} = static_block
             ]}
          ] ->
            # This is an optimization that removes the extra anonymous function from
            # the TagEngine's build_component_clauses function used for slots.
            # We can do this when the slot does not contain any dynamics, which also helps
            # to prevent uncovered lines when rendering a component with only a named slot.
            # In that case, the component still has an inner_block, but it only consists of
            # whitespace.
            maybe_block_to_rendered(static_block, vars, state)

          _ ->
            {call, meta, [key, [do: maybe_block_to_rendered(block, vars, state)]]}
        end

      {:%{}, map_meta, [__slot__: key, inner_block: inner_block] ++ attrs}
    else
      _ -> maybe_slot
    end
  end

  defp slot_to_rendered({left, meta, args}, key, vars, state) do
    {left, meta, slot_to_rendered(args, key, vars, state)}
  end

  defp slot_to_rendered({left, right}, key, vars, state) do
    {slot_to_rendered(left, key, vars, state), slot_to_rendered(right, key, vars, state)}
  end

  defp slot_to_rendered(list, key, vars, state) when is_list(list) do
    Enum.map(list, &slot_to_rendered(&1, key, vars, state))
  end

  defp slot_to_rendered(other, _key, _vars, _state) do
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
            ~H"the result is: {result}"
          end

      You must do:

          def add(assigns) do
            assigns = assign(assigns, :result, assigns.a + assigns.b)
            ~H"the result is: {@result}"
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
end

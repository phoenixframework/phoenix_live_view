defmodule Phoenix.LiveView.Comprehension do
  @moduledoc """
  The struct returned by for-comprehensions in .leex templates.

  See a description about its fields and use cases
  in `Phoenix.LiveView.Engine` docs.
  """

  defstruct [:static, :dynamics]

  @type t :: %__MODULE__{
          static: [String.t()],
          dynamics: [[iodata()]]
        }

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%Phoenix.LiveView.Comprehension{static: static, dynamics: dynamics}) do
      for dynamic <- dynamics, do: to_iodata(static, dynamic, [])
    end

    defp to_iodata([static_head | static_tail], [dynamic_head | dynamic_tail], acc) do
      to_iodata(static_tail, dynamic_tail, [dynamic_head, static_head | acc])
    end

    defp to_iodata([static_head], [], acc) do
      Enum.reverse([static_head | acc])
    end
  end
end

defmodule Phoenix.LiveView.Rendered do
  @moduledoc """
  The struct returned by .leex templates.

  See a description about its fields and use cases
  in `Phoenix.LiveView.Engine` docs.
  """

  defstruct [:static, :dynamic, :fingerprint]

  @type t :: %__MODULE__{
          static: [String.t()],
          dynamic: [
            nil | iodata() | Phoenix.LiveView.Rendered.t() | Phoenix.LiveView.Comprehension.t()
          ],
          fingerprint: integer()
        }

  defimpl Phoenix.HTML.Safe do
    def to_iodata(%Phoenix.LiveView.Rendered{static: static, dynamic: dynamic}) do
      to_iodata(static, dynamic, [])
    end

    def to_iodata(%Phoenix.LiveView.Comprehension{} = for) do
      Phoenix.HTML.Safe.Phoenix.LiveView.Comprehension.to_iodata(for)
    end

    def to_iodata(nil) do
      raise "cannot convert .leex template with change tracking to iodata"
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
  The `.leex` (Live EEx) template engine that tracks changes.

  On the docs below, we will explain how it works internally.
  For user-facing documentation, see `Phoenix.LiveView`.

  ## User facing docs

  TODO: Move this to the Phoenix.LiveView module.

  `Phoenix.LiveView`'s built-in templates use the `.leex`
  extension, which stands for Live EEx. They are similar
  to regular `.eex` templates except they are designed to
  minimize the amount of data sent over the wire by tracking
  changes.

  When you first render a `.leex` template, it will send
  all of the static and dynamic parts of the template to
  the client. After that, any change you do on the server
  will now send only the dyamic parts and only if those
  parts have changed.

  The tracking of changes are done via assigns. Therefore,
  if part of your template does this:

      <%= something_with_user(@user) %>

  That particular section will be re-rendered only if the
  `@user` assign changes between events. Therefore, you
  MUST pass all of the data to your templates via assigns
  and avoid performing direct operations on the template
  as much as possible. For example, if you perform this
  operation in your template:

      <%= for user <- Repo.all(User) do %>
        <%= user.name %>
      <% end %>

  Then Phoenix will never re-render the section above, even
  if the amount of users in the database changes. Instead,
  you need to store the users as assigns in your LiveView
  before it renders the template:

      assign(socket, :users, Repo.all(User))

  Generally speaking, **data loading should never happen inside
  the template**, regardless if you are using LiveView or not.
  The difference is that LiveView enforces those as best
  practices.

  Another restriction of LiveView is that, in order to track
  variables, it may make some macros incompatible with `.leex`
  templates. However, this would only happen if those macros
  are injecting or accessing user variables, which are not
  recommended in the first place. Overall, `.leex` templates
  do their best to be compatible with any Elixir code, sometimes
  even turning off optimizations to keep compatibility.

  ## Phoenix.LiveView.Rendered

  Whenever you render a `.leex` template, it returns a
  `Phoenix.LiveView.Rendered` structure. This structure has
  three fields: `:static`, `:dynamic` and `:fingerprint`.

  The `:static` field is a list of literal strings. This
  allows the Elixir compiler to optimize this list and avoid
  allocating its strings on every render.

  The `:dynamic` field contains a list of dynamic content.
  Each element in the list is either one of:

    1. iodata - which is the dynamic content
    2. nil - the dynamic content did not change, see "Tracking changes" below
    3. another `Phoenix.LiveView.Rendered` struct, see "Nesting and fingerprinting" below
    4. a `Phoenix.LiveView.Comprehension` struct, see "Comprehensions" below

  When you render a `.leex` template, you can convert the
  rendered structure to iodata by intercalating the static
  and dynamic fields, always starting with a static entry
  followed by a dynamic entry. The last entry will always
  be static too. So the following structure:

      %Phoenix.LiveView.Rendered{
        static: ["foo", "bar", "baz"],
        dynamic: ["left", "right"]
      }

  Results in the following content to be sent over the wire
  as iodata:

      ["foo", "left", "bar", "right", "baz"]

  This is also what calling `Phoenix.HTML.Safe.to_iodata/1`
  with a `Phoenix.LiveView.Rendered` structure returns.

  Of course, the benefit of `.leex` templates is exactly
  that you do not need to send both static and dynamic
  segments every time. So let's talk about tracking changes.

  ## Tracking changes

  By default, a `.leex` template does not track changes.
  Change tracking can be enabled by passing a `socket`
  with two keys `:root_fingerprint` and `:changed`. If
  the `:root_fingerprint` matches the template fingerprint,
  then the `:changed` map is used. The map should
  contain the name of any changed field as key and the
  boolean true as value. If a field is not listed in
  `:changed`, then it is always considered unchanged.

  If a field is unchanged and `.leex` believes a dynamic
  expression no longer needs to be computed, its value
  in the `dynamic` list will be `nil`. This information
  can be leveraged to avoid sending data to the client.

  ## Nesting and fingerprinting

  `Phoenix.LiveView` also tracks changes across `.leex`
  templates. Therefore, if your view has this:

      <%= render "form.html", assigns %>

  Phoenix will be able to track what is static and dynamic
  across templates, as well as what changed. A rendered
  nested `.leex` template will appear in the `dynamic`
  list as another `Phoenix.LiveView.Rendered` structure,
  which must be handled recursively.

  However, because the rendering of live templates can
  be dynamic in itself, it is important to distinguish
  which `.leex` template was rendered. For example,
  imagine this code:

      <%= if something?, do: render("one.html", assigns), else: render("other.html", assigns) %>

  To solve this, all `Phoenix.LiveView.Rendered` structs
  also contain a fingerprint field that uniquely identifies
  it. If the fingerprints are equal, you have the same
  template, and therefore it is possible to only transmit
  its changes.

  ## Comprehensions

  Another optimization done by `.leex` templates is to
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
  and `%{x: 3, y: 4}`, the expression above would return:

      %Phoenix.LiveView.Comprehension{
        static: ["\n  x: ", "\n  y: ", "\n"],
        dynamics: [
          ["1", "2"],
          ["3", "4"]
        ]
      }

  This allows `.leex` templates to drastically optimize
  the data sent by comprehensions, as the static parts
  are emitted once, regardless of the number of items.

  The list of dynamics is always a list of iodatas, as we
  only perform change tracking at the root and never inside
  `case`, `cond`, `comprehensions`, etc. Similarly,
  comprehensions do not have fingerprints because they
  are only optimized at the root, so conditional evaluation,
  as the one seen in rendering, is not possible. The only
  possible outcome for a dynamic field that returns a
  comprehension is `nil`.
  """

  @behaviour Phoenix.Template.Engine

  @impl true
  def compile(path, _name) do
    EEx.compile_file(path, engine: __MODULE__, line: 1, trim: true)
  end

  @behaviour EEx.Engine

  @impl true
  def init(_opts) do
    %{
      static: [],
      dynamic: [],
      vars_count: 0,
      root: true
    }
  end

  @impl true
  def handle_begin(state) do
    %{state | static: [], dynamic: [], root: false}
  end

  @impl true
  def handle_end(state) do
    %{static: static, dynamic: dynamic} = state
    safe = {:safe, Enum.reverse(static)}
    {:__block__, [], Enum.reverse([safe | dynamic])}
  end

  @impl true
  def handle_body(state) do
    %{static: static, dynamic: dynamic} = state

    binaries = reverse_static(static)
    dynamic = Enum.reverse(dynamic)

    # We compute the term to binary instead of passing all binaries
    # because we need to take into account the positions of dynamics.
    <<fingerprint::8*16>> =
      binaries
      |> :erlang.term_to_binary()
      |> :erlang.md5()

    vars =
      for {counter, _} when is_integer(counter) <- dynamic do
        var(counter)
      end

    {block, _} =
      Enum.map_reduce(dynamic, %{}, fn
        {:ast, ast}, vars ->
          {ast, vars, _} = analyze(ast, vars)
          {ast, vars}

        {counter, ast}, vars ->
          {ast, vars, tainted_or_keys} = analyze(ast, vars)
          {to_conditional_var(ast, tainted_or_keys, var(counter)), vars}
      end)

    prelude =
      quote do
        __changed__ =
          case var!(assigns) do
            %{socket: %{root_fingerprint: unquote(fingerprint), changed: changed}} -> changed
            _ -> nil
          end
      end

    rendered =
      quote do
        %Phoenix.LiveView.Rendered{
          static: unquote(binaries),
          dynamic: unquote(vars),
          fingerprint: unquote(fingerprint)
        }
      end

    {:__block__, [], [prelude | block] ++ [rendered]}
  end

  @impl true
  def handle_text(state, text) do
    %{static: static} = state
    %{state | static: [text | static]}
  end

  @impl true
  def handle_expr(%{root: true} = state, "=", ast) do
    %{static: static, dynamic: dynamic, vars_count: vars_count} = state
    tuple = {vars_count, ast}
    %{state | dynamic: [tuple | dynamic], static: [:dynamic | static], vars_count: vars_count + 1}
  end

  def handle_expr(%{root: true} = state, "", ast) do
    %{dynamic: dynamic} = state
    %{state | dynamic: [{:ast, ast} | dynamic]}
  end

  def handle_expr(%{root: false} = state, "=", ast) do
    %{static: static, dynamic: dynamic, vars_count: vars_count} = state
    var = var(vars_count)
    ast = quote do: unquote(var) = unquote(to_safe(ast, []))
    %{state | dynamic: [ast | dynamic], static: [var | static], vars_count: vars_count + 1}
  end

  def handle_expr(%{root: false} = state, "", ast) do
    %{dynamic: dynamic} = state
    %{state | dynamic: [ast | dynamic]}
  end

  def handle_expr(state, marker, ast) do
    EEx.Engine.handle_expr(state, marker, ast)
  end

  ## Var handling

  defp var(counter) do
    Macro.var(:"arg#{counter}", __MODULE__)
  end

  ## Safe conversion

  defp to_safe(ast, extra_clauses) do
    to_safe(ast, line_from_expr(ast), extra_clauses)
  end

  defp line_from_expr({_, meta, _}) when is_list(meta), do: Keyword.get(meta, :line)
  defp line_from_expr(_), do: nil

  # We can do the work at compile time
  defp to_safe(literal, _line, _extra_clauses)
       when is_binary(literal) or is_atom(literal) or is_number(literal) do
    Phoenix.HTML.Safe.to_iodata(literal)
  end

  # We can do the work at runtime
  defp to_safe(literal, line, _extra_clauses) when is_list(literal) do
    quote line: line, do: Phoenix.HTML.Safe.List.to_iodata(unquote(literal))
  end

  # Emit a special data structure for comprehensions
  defp to_safe({:for, meta, args} = expr, line, extra_clauses) do
    with {filters, [[do: {:__block__, _, block}]]} <- Enum.split(args, -1),
         {exprs, [{:safe, iodata}]} <- Enum.split(block, -1) do
      # Unpack the safe tuple back into binaries and dynamics
      {static, dynamics} =
        Enum.reduce(iodata, {[], []}, fn
          binary, {static, dynamic} when is_binary(binary) ->
            {[binary | static], dynamic}

          var, {static, dynamic} when is_tuple(var) ->
            {[:dynamic | static], [var | dynamic]}
        end)

      binaries = reverse_static(static)
      dynamics = Enum.reverse(dynamics)
      for = {:for, meta, filters ++ [[do: {:__block__, [], exprs ++ [dynamics]}]]}

      quote do
        for = unquote(for)
        %Phoenix.LiveView.Comprehension{static: unquote(binaries), dynamics: for}
      end
    else
      _ -> to_safe_catch_all(expr, line, extra_clauses)
    end
  end

  # We need to check at runtime and we do so by optimizing common cases.
  defp to_safe(expr, line, extra_clauses) do
    to_safe_catch_all(expr, line, extra_clauses)
  end

  defp to_safe_catch_all(expr, line, extra_clauses) do
    # Keep stacktraces for protocol dispatch...
    fallback = quote line: line, do: Phoenix.HTML.Safe.to_iodata(other)

    # However ignore them for the generated clauses to avoid warnings
    clauses =
      quote generated: true do
        {:safe, data} -> data
        bin when is_binary(bin) -> Plug.HTML.html_escape_to_iodata(bin)
        other -> unquote(fallback)
      end

    quote generated: true do
      case unquote(expr), do: unquote(extra_clauses ++ clauses)
    end
  end

  ## Static traversal

  defp reverse_static([:dynamic | static]),
    do: reverse_static(static, [""])

  defp reverse_static(static),
    do: reverse_static(static, [])

  defp reverse_static([static, :dynamic | rest], acc) when is_binary(static),
    do: reverse_static(rest, [static | acc])

  defp reverse_static([:dynamic | rest], acc),
    do: reverse_static(rest, ["" | acc])

  defp reverse_static([static], acc) when is_binary(static),
    do: [static | acc]

  defp reverse_static([], acc),
    do: ["" | acc]

  ## Dynamic traversal

  @lexical_forms [:import, :alias, :require]

  # Here we compute if an expression should be always computed (:tainted),
  # never computed (no assigns) or some times computed based on assigns.
  #
  # If any assign is used, we store it in the assigns and use it to compute
  # if it shuold be changed or not.
  #
  # However, operations that change the lexical scope, such as imports and
  # defining variables, taint the analysis. Because variables can be set at
  # any moment in Elixir, via macros, without appearing on the left side of
  # `=` or in a clause, whenever we see a variable, we consider it as tainted,
  # regardless of its position.
  #
  # The only exceptions are variables used inside certain special forms,
  # which we know are not capable of leaking the scope. However, even if a
  # variable is inside a special form, it may have been define previously
  # in function of an assign, such as:
  #
  #     <% var = @foo %>
  #     <%= for _ <- [1, 2, 3], do: var %>
  #
  # In this case, the second expression does depend on the `@foo` assign.
  # Therefore we do track the relationship between vars and assigns by
  # attaching all assigns seen in an expression to all vars seen in said
  # expression. This is a very loose mechanism which disables the optimization
  # in many cases variables are used, but that's OK since we want to pass
  # most variables in templates as assigns anyway.
  #
  # The tainting that happens from lexical scope is called weak-tainting,
  # because it is disable under certain special forms. There is also
  # strong-tainting, which are always computed. Strong-tainting only happens
  # if the `assigns` variable is used.
  defp analyze(expr, previous_vars) do
    {expr, new_vars, assigns} = analyze(expr, previous_vars, %{}, %{})

    {tainted_vars?, new_vars} = Map.pop(new_vars, __MODULE__, false)
    {tainted_assigns?, assigns} = Map.pop(assigns, __MODULE__, false)

    tainted_or_keys = if tainted_vars? or tainted_assigns?, do: :tainted, else: Map.keys(assigns)
    {expr, merge_vars(previous_vars, new_vars, assigns), tainted_or_keys}
  end

  defp analyze({:@, meta, [{name, _, context}]}, _previous, vars, assigns)
       when is_atom(name) and is_atom(context) do
    expr =
      quote line: meta[:line] || 0 do
        unquote(__MODULE__).fetch_assign!(var!(assigns), unquote(name))
      end

    {expr, vars, Map.put(assigns, name, true)}
  end

  # Assigns is a strong-taint
  defp analyze({:assigns, _, nil} = expr, _previous, vars, assigns) do
    {expr, vars, taint(assigns)}
  end

  # Vars always taint
  defp analyze({name, _, context} = expr, previous, vars, assigns)
       when is_atom(name) and is_atom(context) do
    pair = {name, context}
    vars = vars |> Map.put(pair, true) |> taint()

    assigns =
      case previous do
        %{^pair => map} -> Map.merge(assigns, map)
        %{} -> assigns
      end

    {expr, vars, assigns}
  end

  # Lexical forms always taint
  defp analyze({lexical_form, _, [_]} = expr, _previous, vars, assigns)
       when lexical_form in @lexical_forms do
    {expr, taint(vars), assigns}
  end

  defp analyze({lexical_form, _, [_, _]} = expr, _previous, vars, assigns)
       when lexical_form in @lexical_forms do
    {expr, taint(vars), assigns}
  end

  # with/for/fn never taint regardless of arity
  defp analyze({special_form, meta, args}, previous, vars, assigns)
       when special_form in [:with, :for, :fn] do
    {args, _vars, assigns} = analyze_list(args, previous, vars, assigns, [])
    {{special_form, meta, args}, vars, assigns}
  end

  # case/2 only taint first arg
  defp analyze({:case, meta, [expr, blocks]}, previous, vars, assigns) do
    {expr, vars, assigns} = analyze(expr, previous, vars, assigns)
    {blocks, _vars, assigns} = analyze(blocks, previous, vars, assigns)
    {{:case, meta, [expr, blocks]}, vars, assigns}
  end

  # try/receive/cond/&/1 never taint
  defp analyze({special_form, meta, [blocks]}, previous, vars, assigns)
       when special_form in [:try, :receive, :cond, :&] do
    {blocks, _vars, assigns} = analyze(blocks, previous, vars, assigns)
    {{special_form, meta, [blocks]}, vars, assigns}
  end

  defp analyze({left, meta, args}, previous, vars, assigns) do
    {left, vars, assigns} = analyze(left, previous, vars, assigns)
    {args, vars, assigns} = analyze_list(args, previous, vars, assigns, [])
    {{left, meta, args}, vars, assigns}
  end

  defp analyze({left, right}, previous, vars, assigns) do
    {left, vars, assigns} = analyze(left, previous, vars, assigns)
    {right, vars, assigns} = analyze(right, previous, vars, assigns)
    {{left, right}, vars, assigns}
  end

  defp analyze([_ | _] = list, previous, vars, assigns) do
    analyze_list(list, previous, vars, assigns, [])
  end

  defp analyze(other, _previous, vars, assigns) do
    {other, vars, assigns}
  end

  defp analyze_list([head | tail], previous, vars, assigns, acc) do
    {head, vars, assigns} = analyze(head, previous, vars, assigns)
    analyze_list(tail, previous, vars, assigns, [head | acc])
  end

  defp analyze_list([], _previous, vars, assigns, acc) do
    {Enum.reverse(acc), vars, assigns}
  end

  defp taint(assigns) do
    Map.put(assigns, __MODULE__, true)
  end

  defp merge_vars(previous, new, assigns) do
    Enum.reduce(new, previous, fn {var, _}, acc ->
      case acc do
        %{^var => map} -> %{acc | var => Map.merge(map, assigns)}
        %{} -> Map.put(acc, var, assigns)
      end
    end)
  end

  @extra_clauses (quote do
                    %{__struct__: Phoenix.LiveView.Rendered} = other -> other
                  end)

  defp to_conditional_var(ast, :tainted, var) do
    quote do: unquote(var) = unquote(to_safe(ast, @extra_clauses))
  end

  defp to_conditional_var(ast, [], var) do
    quote do
      unquote(var) =
        case __changed__ do
          %{} -> nil
          _ -> unquote(to_safe(ast, @extra_clauses))
        end
    end
  end

  defp to_conditional_var(ast, assigns, var) do
    quote do
      unquote(var) =
        case unquote(changed_assigns(assigns)) do
          true -> unquote(to_safe(ast, @extra_clauses))
          false -> nil
        end
    end
  end

  defp changed_assigns(assigns) do
    assigns
    |> Enum.map(fn assign ->
      quote do: unquote(__MODULE__).changed_assign?(__changed__, unquote(assign))
    end)
    |> Enum.reduce(&{:or, [], [&1, &2]})
  end

  @doc false
  def changed_assign?(nil, _name) do
    true
  end

  def changed_assign?(changed, name) do
    case changed do
      %{^name => _} -> true
      %{} -> false
    end
  end

  @doc false
  def fetch_assign!(assigns, key) do
    case Access.fetch(assigns, key) do
      {:ok, val} ->
        val

      :error ->
        raise ArgumentError, """
        assign @#{key} not available in eex template.

        Please make sure all proper assigns have been set. If this
        is a child template, ensure assigns are given explicitly by
        the parent template as they are not automatically forwarded.

        Available assigns: #{inspect(Enum.map(assigns, &elem(&1, 0)))}
        """
    end
  end
end

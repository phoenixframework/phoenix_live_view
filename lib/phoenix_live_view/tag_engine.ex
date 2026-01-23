defmodule Phoenix.LiveView.TagEngine do
  @moduledoc """
  Building blocks for tag based `Phoenix.Template.Engine`s.

  This cannot be directly used by Phoenix applications.
  Instead, it is the building block for engines such as
  `Phoenix.LiveView.HTMLEngine`.

  It is typically invoked like this:

      Phoenix.LiveView.TagEngine.compile(source,
        line: 1,
        file: path,
        caller: __CALLER__,
        source: source,
        tag_handler: FooBarEngine
      )

  Where `:tag_handler` implements the behaviour defined by this module.
  """

  alias Phoenix.LiveView.TagEngine

  @doc """
  Compiles the given string into Elixir AST.

  The accepted options are:

    * `tag_handler` - Required. The module implementing the `Phoenix.LiveView.TagEngine` behavior.
    * `caller` - Required. The `Macro.Env`.
    * `line` - the starting line offset. Defaults to 1.
    * `file` - the file of the template. Defaults to `"nofile"`.
    * `indentation` - the indentation of the template. Defaults to 0.

  """
  def compile(source, options) do
    options =
      Keyword.validate!(options, [
        :caller,
        :tag_handler,
        :trim,
        line: 1,
        indentation: 0,
        file: "nofile",
        engine: Phoenix.LiveView.Engine
      ])
      |> Keyword.merge(source: source, trim_eex: false)

    source
    |> TagEngine.Parser.parse!(options)
    |> TagEngine.Compiler.compile(options)
  end

  @doc """
  Classify the tag type from the given binary.

  This must return a tuple containing the type of the tag and the name of tag.
  For instance, for LiveView which uses HTML as default tag handler this would
  return `{:tag, 'div'}` in case the given binary is identified as HTML tag.

  You can also return `{:error, "reason"}` so that the compiler will display this
  error.
  """
  @callback classify_type(name :: binary()) :: {type :: atom(), name :: binary()}

  @doc """
  Returns if the given tag name is void or not.

  That's mainly useful for HTML tags and used internally by the compiler. You
  can just implement as `def void?(_), do: false` if you want to ignore this.
  """
  @callback void?(name :: binary()) :: boolean()

  @doc """
  Implements processing of attributes.

  It returns a quoted expression or attributes. If attributes are returned,
  the second element is a list where each element in the list represents
  one attribute. If the list element is a two-element tuple, it is assumed
  the key is the name to be statically written in the template. The second
  element is the value which is also statically written to the template whenever
  possible (such as binaries or binaries inside a list).
  """
  @callback handle_attributes(ast :: Macro.t(), meta :: keyword) ::
              {:attributes, [{binary(), Macro.t()} | Macro.t()]} | {:quoted, Macro.t()}

  @doc """
  Callback invoked to add annotations around the whole body of a template.
  """
  @callback annotate_body(caller :: Macro.Env.t()) :: {String.t(), String.t()} | nil

  @doc """
  Callback invoked to add annotations around each slot of a template.

  In case the slot is an implicit inner block, the tag meta points to
  the component.
  """
  @callback annotate_slot(
              name :: atom(),
              tag_meta :: %{line: non_neg_integer(), column: non_neg_integer()},
              close_tag_meta :: %{line: non_neg_integer(), column: non_neg_integer()},
              caller :: Macro.Env.t()
            ) :: {String.t(), String.t()} | nil

  @doc """
  Callback invoked to add caller annotations before a function component is invoked.
  """
  @callback annotate_caller(file :: String.t(), line :: integer(), caller :: Macro.Env.t()) ::
              String.t() | nil

  @doc """
  Renders a component defined by the given function.

  This function is rarely invoked directly by users. Instead, it is used by `~H`
  and other engine implementations to render `Phoenix.Component`s. For example,
  the following:

  ```heex
  <MyApp.Weather.city name="Kraków" />
  ```

  Is the same as:

  ```heex
  <%= component(
        &MyApp.Weather.city/1,
        [name: "Kraków"],
        {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
      ) %>
  ```

  """
  def component(func, assigns, caller)
      when (is_function(func, 1) and is_list(assigns)) or is_map(assigns) do
    assigns =
      case assigns do
        %{__changed__: _} -> assigns
        _ -> assigns |> Map.new() |> Map.put_new(:__changed__, nil)
      end

    case func.(assigns) do
      %Phoenix.LiveView.Rendered{} = rendered ->
        %{rendered | caller: caller}

      %Phoenix.LiveView.Component{} = component ->
        component

      other ->
        raise RuntimeError, """
        expected #{inspect(func)} to return a %Phoenix.LiveView.Rendered{} struct

        Ensure your render function uses ~H to define its template.

        Got:

            #{inspect(other)}

        """
    end
  end

  @doc """
  Define a inner block, generally used by slots.

  This macro is mostly used by custom HTML engines that provide
  a `slot` implementation and rarely called directly. The
  `name` must be the assign name the slot/block will be stored
  under.

  If you're using HEEx templates, you should use its higher
  level `<:slot>` notation instead. See `Phoenix.Component`
  for more information.
  """
  defmacro inner_block(name, do: do_block) do
    # TODO: Remove the catch-all clause, it is no longer used
    case do_block do
      [{:->, meta, _} | _] ->
        inner_fun = {:fn, meta, do_block}

        quote do
          fn parent_changed, arg ->
            var!(assigns) =
              unquote(__MODULE__).__assigns__(var!(assigns), unquote(name), parent_changed)

            _ = var!(assigns)
            unquote(inner_fun).(arg)
          end
        end

      _ ->
        quote do
          fn parent_changed, arg ->
            var!(assigns) =
              unquote(__MODULE__).__assigns__(var!(assigns), unquote(name), parent_changed)

            _ = var!(assigns)
            unquote(do_block)
          end
        end
    end
  end

  @doc false
  def __assigns__(assigns, key, parent_changed) do
    # If the component is in its initial render (parent_changed == nil)
    # or the slot/block key is in parent_changed, then we render the
    # function with the assigns as is.
    #
    # Otherwise, we will set changed to an empty list, which is the same
    # as marking everything as not changed. This is correct because
    # parent_changed will always be marked as changed whenever any of the
    # assigns it references inside is changed. It will also be marked as
    # changed if it has any variable (such as the ones coming from let).
    if is_nil(parent_changed) or Map.has_key?(parent_changed, key) do
      assigns
    else
      Map.put(assigns, :__changed__, %{})
    end
  end

  @doc false
  def __unmatched_let__!(pattern, value) do
    message = """
    cannot match arguments sent from render_slot/2 against the pattern in :let.

    Expected a value matching `#{pattern}`, got: #{inspect(value)}\
    """

    stacktrace =
      self()
      |> Process.info(:current_stacktrace)
      |> elem(1)
      |> Enum.drop(2)

    reraise(message, stacktrace)
  end

  @behaviour EEx.Engine

  @impl true
  def init(opts) do
    IO.warn("""
    Using Phoenix.LiveView.TagEngine as an EEx.Engine is deprecated!

    To compile HEEx, use Phoenix.LiveView.TagEngine.compile/2 instead.
    """)

    {subengine, opts} = Keyword.pop(opts, :subengine, Phoenix.LiveView.Engine)
    tag_handler = Keyword.fetch!(opts, :tag_handler)
    caller = Keyword.fetch!(opts, :caller)

    %{
      subengine: subengine,
      substate: subengine.init(opts),
      file: Keyword.get(opts, :file, "nofile"),
      line: Keyword.get(opts, :line, caller.line),
      indentation: Keyword.get(opts, :indentation, 0),
      caller: caller,
      source: Keyword.fetch!(opts, :source),
      tag_handler: tag_handler
    }
  end

  ## EEx.Engine callbacks
  ## These delegate to the subengine to satisfy EEx's expectations,
  ## but handle_body ignores everything and reparses with TagEngine.Parser + TagEngine.Compiler.

  @impl true
  def handle_body(state) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)

    %{
      source: source,
      file: file,
      line: line,
      caller: caller,
      tag_handler: tag_handler,
      subengine: subengine,
      indentation: indentation
    } = state

    options = [
      engine: subengine,
      file: file,
      line: line,
      caller: caller,
      indentation: indentation,
      source: source,
      tag_handler: tag_handler,
      trim_tokens: true,
      trim: trim
    ]

    compile(source, options)
  end

  @impl true
  def handle_end(_state) do
    nil
  end

  @impl true
  def handle_begin(_state) do
    nil
  end

  @impl true
  def handle_text(state, _meta, _text) do
    state
  end

  @impl true
  def handle_expr(state, _marker, _expr) do
    state
  end
end

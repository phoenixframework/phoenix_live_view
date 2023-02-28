defmodule Phoenix.LiveView.Helpers do
  @moduledoc false
  import Phoenix.Component

  alias Phoenix.LiveView.{Component, Socket}

  @doc """
  Provides `~L` sigil with HTML safe Live EEx syntax inside source files.

      iex> ~L"\""
      ...> Hello <%= "world" %>
      ...> "\""
      {:safe, ["Hello ", "world", "\\n"]}

  """
  @doc deprecated: "Use ~H instead"
  defmacro sigil_L({:<<>>, meta, [expr]}, []) do
    options = [
      engine: Phoenix.LiveView.Engine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      indentation: meta[:indentation] || 0
    ]

    EEx.compile_string(expr, options)
  end

  @doc deprecated: "Use link/1 instead"
  def live_patch(opts) when is_list(opts) do
    live_link("patch", Keyword.fetch!(opts, :do), Keyword.delete(opts, :do))
  end

  @doc deprecated: "Use <.link> instead"
  def live_patch(text, opts)

  def live_patch(%Socket{}, _) do
    raise """
    you are invoking live_patch/2 with a socket but a socket is not expected.

    If you want to live_patch/2 inside a LiveView, use push_patch/2 instead.
    If you are inside a template, make the sure the first argument is a string.
    """
  end

  def live_patch(opts, do: block) when is_list(opts) do
    live_link("patch", block, opts)
  end

  def live_patch(text, opts) when is_list(opts) do
    live_link("patch", text, opts)
  end

  @doc deprecated: "Use <.link> instead"
  def live_redirect(opts) when is_list(opts) do
    live_link("redirect", Keyword.fetch!(opts, :do), Keyword.delete(opts, :do))
  end

  @doc deprecated: "Use <.link> instead"
  def live_redirect(text, opts)

  def live_redirect(%Socket{}, _) do
    raise """
    you are invoking live_redirect/2 with a socket but a socket is not expected.

    If you want to live_redirect/2 inside a LiveView, use push_redirect/2 instead.
    If you are inside a template, make the sure the first argument is a string.
    """
  end

  def live_redirect(opts, do: block) when is_list(opts) do
    live_link("redirect", block, opts)
  end

  def live_redirect(text, opts) when is_list(opts) do
    live_link("redirect", text, opts)
  end

  defp live_link(type, block_or_text, opts) do
    uri = Keyword.fetch!(opts, :to)
    replace = Keyword.get(opts, :replace, false)
    kind = if replace, do: "replace", else: "push"

    data = [phx_link: type, phx_link_state: kind]

    opts =
      opts
      |> Keyword.update(:data, data, &Keyword.merge(&1, data))
      |> Keyword.put(:href, uri)
      |> Keyword.delete(:to)

    assigns = %{opts: opts, content: block_or_text}

    ~H|<a {@opts}><%= @content %></a>|
  end

  @doc """
  Deprecated API for rendering `LiveComponent`.

  ## Upgrading

  In order to migrate from `<%= live_component ... %>` to `<.live_component>`,
  you must first:

    1. Migrate from `~L` sigil and `.leex` templates to
      `~H` sigil and `.heex` templates

    2. Then instead of:

       ```
       <%= live_component MyModule, id: "hello" do %>
       ...
       <% end %>
       ```

       You should do:

       ```
       <.live_component module={MyModule} id="hello">
       ...
       </.live_component>
       ```

    3. If your component is using `render_block/2`, replace
       it by `render_slot/2`

  """
  @doc deprecated: "Use .live_component (live_component/1) instead"
  defmacro live_component(component, assigns, do_block \\ []) do
    if is_assign?(:socket, component) do
      IO.warn(
        "passing the @socket to live_component is no longer necessary, " <>
          "please remove the socket argument",
        Macro.Env.stacktrace(__CALLER__)
      )
    end

    {inner_block, do_block, assigns} =
      case {do_block, assigns} do
        {[do: do_block], _} -> {rewrite_do!(do_block, :inner_block, __CALLER__), [], assigns}
        {_, [do: do_block]} -> {rewrite_do!(do_block, :inner_block, __CALLER__), [], []}
        {_, _} -> {nil, do_block, assigns}
      end

    if match?({:__aliases__, _, _}, component) or is_atom(component) or is_list(assigns) or
         is_map(assigns) do
      quote do
        Phoenix.LiveView.Helpers.__live_component__(
          unquote(component).__live__(),
          unquote(assigns),
          unquote(inner_block)
        )
      end
    else
      quote do
        case unquote(component) do
          %Phoenix.LiveView.Socket{} ->
            Phoenix.LiveView.Helpers.__live_component__(
              unquote(assigns).__live__(),
              unquote(do_block),
              unquote(inner_block)
            )

          component ->
            Phoenix.LiveView.Helpers.__live_component__(
              component.__live__(),
              unquote(assigns),
              unquote(inner_block)
            )
        end
      end
    end
  end

  @doc false
  def __live_component__(%{kind: :component, module: component}, assigns, inner)
      when is_list(assigns) or is_map(assigns) do
    assigns = assigns |> Map.new() |> Map.put_new(:id, nil)
    assigns = if inner, do: Map.put(assigns, :inner_block, inner), else: assigns
    id = assigns[:id]

    # TODO: Remove logic from Diff once stateless components are removed.
    # TODO: Remove live_component arity checks from Engine
    if is_nil(id) and
         (function_exported?(component, :handle_event, 3) or
            function_exported?(component, :preload, 1)) do
      raise "a component #{inspect(component)} that has implemented handle_event/3 or preload/1 " <>
              "requires an :id assign to be given"
    end

    %Component{id: id, assigns: assigns, component: component}
  end

  def __live_component__(%{kind: kind, module: module}, assigns, _inner)
      when is_list(assigns) or is_map(assigns) do
    raise "expected #{inspect(module)} to be a component, but it is a #{kind}"
  end

  defp rewrite_do!(do_block, key, caller) do
    if Macro.Env.has_var?(caller, {:assigns, nil}) do
      # TODO: make __inner_block__ private once this is removed.
      Phoenix.LiveView.TagEngine.__inner_block__(do_block, key)
    else
      raise ArgumentError,
            "cannot use live_component because the assigns var is unbound/unset"
    end
  end

  @doc """
  Renders the `@inner_block` assign of a component with the given `argument`.

      <%= render_block(@inner_block, value: @value)

  This function is deprecated for function components. Use `render_slot/2`
  instead.
  """
  @doc deprecated: "Use render_slot/2 instead"
  defmacro render_block(inner_block, argument \\ []) do
    quote do
      unquote(__MODULE__).__render_block__(unquote(inner_block)).(
        var!(changed, Phoenix.LiveView.Engine),
        unquote(argument)
      )
    end
  end

  @doc false
  def __render_block__([%{inner_block: fun}]), do: fun
  def __render_block__(fun), do: fun

  @doc deprecated: "Use <.live_img_preview /> instead"
  def live_img_preview(entry, opts) do
    live_img_preview(Enum.into(opts, %{entry: entry}))
  end

  @doc deprecated: "Use <.live_file_input /> instead"
  def live_file_input(%Phoenix.LiveView.UploadConfig{} = conf, opts) when is_list(opts) do
    require Phoenix.LiveViewTest
    assigns = Enum.into(opts, %{upload: conf})
    {:safe, Phoenix.LiveViewTest.render_component(&live_file_input/1, assigns)}
  end

  @doc """
  Renders a title tag with automatic prefix/suffix on `@page_title` updates.

  ## Examples

      <%= live_title_tag assigns[:page_title] || "Welcome", prefix: "MyApp – " %>

      <%= live_title_tag assigns[:page_title] || "Welcome", suffix: " – MyApp" %>
  """
  @doc deprecated: "Use <.live_title> instead"
  def live_title_tag(title, opts \\ []) do
    assigns = %{title: title, prefix: opts[:prefix], suffix: opts[:suffix]}

    ~H"""
    <Phoenix.Component.live_title prefix={@prefix} suffix={@suffix}><%= @title %></Phoenix.Component.live_title>
    """
  end

  defp is_assign?(assign_name, expression) do
    match?({:@, _, [{^assign_name, _, _}]}, expression) or
      match?({^assign_name, _, _}, expression) or
      match?({{:., _, [{:assigns, _, nil}, ^assign_name]}, _, []}, expression)
  end
end

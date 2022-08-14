defmodule Phoenix.ViewComponent do
  @moduledoc ~S'''
  ViewComponents are a convenience for defining function
  components in a manner similar to regular Phoenix Views.

  A ViewComponent module compiles all eex temaplte files
  in the same directory into function components named after the
  template filename, allowing larger function components to be
  isolated to single files without needing to use a LiveComponent.

  Here is an example usage:

      defmodule MyViewComponent do
        use Phoenix.Component
        use Phoenix.ViewComponent
      end

  Then any heex template can be placed in the same directory, and
  will be compiled into function components.

  An adjacent template file named `greet.html.heex` which looks like:

      ~H"""
      <p>Hello, <%= assigns.name %></p>
      """

  Is identical to the following definition in a classic function component module:

      defmodule MyComponent do
        use Phoenix.Component

        def greet(assigns) do
          ~H"""
          <p>Hello, <%= assigns.name %></p>
          """
        end
      end

  For futher documentation on function components, see documentation for `Phoenix.Component`
  '''
  defmacro __using__(_) do
    quote do
      @before_compile Phoenix.ViewComponent
    end
  end

  defmacro __before_compile__(env) do
    root = Path.dirname(env.file)
    templates = Phoenix.Template.find_all(root, "*")

    Enum.map(templates, fn template ->
      ext = template |> Path.extname() |> String.trim_leading(".") |> String.to_atom()
      engine = Map.fetch!(Phoenix.Template.engines(), ext)
      ast = engine.compile(template, template)

      quote do
        @file unquote(template)
        @external_resource unquote(template)
        def unquote(function_name(template))(var!(assigns)) when is_map(var!(assigns)) do
          unquote(ast)
        end
      end
    end)
  end

  defp function_name(template) do
    template
    |> Path.basename()
    |> String.split(".")
    |> List.first()
    |> String.to_atom()
  end
end

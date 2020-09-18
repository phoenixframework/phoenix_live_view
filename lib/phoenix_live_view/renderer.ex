defmodule Phoenix.LiveView.Renderer do
  @moduledoc false

  defmacro __before_compile__(env) do
    render? = Module.defines?(env.module, {:render, 1})
    root = Path.dirname(env.file)
    filename = template_filename(env)
    templates = Phoenix.Template.find_all(root, filename)

    case {render?, templates} do
      {true, [template | _]} ->
        IO.warn(
          "ignoring template #{inspect(template)} because the LiveView " <>
            "#{inspect(env.module)} defines a render/1 function",
          Macro.Env.stacktrace(env)
        )

        :ok

      {true, []} ->
        :ok

      {false, [template]} ->
        ext = template |> Path.extname() |> String.trim_leading(".") |> String.to_atom()
        engine = Map.fetch!(Phoenix.Template.engines(), ext)
        ast = engine.compile(template, filename)

        quote do
          @file unquote(template)
          @external_resource unquote(template)
          def render(var!(assigns)) when is_map(var!(assigns)) do
            unquote(ast)
          end
        end

      {false, [_ | _]} ->
        IO.warn(
          "multiple templates were found for #{inspect(env.module)}: #{inspect(templates)}",
          Macro.Env.stacktrace(env)
        )

        :ok

      {false, []} ->
        template = Path.join(root, filename <> ".leex")

        message = ~s'''
        render/1 was not implemented for #{inspect(env.module)}.

        Make sure to either explicitly define a render/1 clause with a LiveView template:

            def render(assigns) do
              ~L"""
              ...
              """
            end

        Or create a file at #{inspect(template)} with the LiveView template.
        '''

        IO.warn(message, Macro.Env.stacktrace(env))

        quote do
          @external_resource unquote(template)
          def render(_assigns) do
            raise unquote(message)
          end
        end
    end
  end

  defp template_filename(env) do
    env.module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>(".html")
  end
end

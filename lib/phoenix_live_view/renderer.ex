defmodule Phoenix.LiveView.Renderer do
  @moduledoc false

  defmacro __before_compile__(env) do
    render? = Module.defines?(env.module, {:render, 1})
    template = template_path(env)

    case {render?, File.regular?(template)} do
      {true, true} ->
        IO.warn(
          "ignoring template #{inspect(template)} because the LiveView " <>
            "#{inspect(env.module)} defines a render/1 function",
          Macro.Env.stacktrace(env)
        )

        :ok

      {true, false} ->
        :ok

      {false, true} ->
        ast = Phoenix.LiveView.Engine.compile(template, template_filename(env))

        quote do
          @file unquote(template)
          @external_resource unquote(template)
          def render(var!(assigns)) do
            unquote(ast)
          end
        end

      {false, false} ->
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
          def render(_assigns) do
            raise unquote(message)
          end
        end
    end
  end

  defp template_path(env) do
    env.file
    |> Path.dirname()
    |> Path.join(template_filename(env) <> ".leex")
    |> Path.relative_to_cwd()
  end

  def template_filename(env) do
    env.module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>(".html")
  end
end

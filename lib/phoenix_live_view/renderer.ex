defmodule Phoenix.LiveView.Renderer do
  @moduledoc false

  alias Phoenix.LiveView.{Rendered, Socket}

  defmacro __before_compile__(%{module: module, file: file} = env) do
    render? = Module.defines?(module, {:render, 1})
    root = Path.dirname(file)
    filename = template_filename(module)
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
        template = Path.join(root, filename <> ".heex")

        quote do
          @external_resource unquote(template)
        end
    end
  end

  defp template_filename(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>(".html")
  end

  @doc """
  Renders the view with socket into a rendered struct.
  """
  def to_rendered(socket, view) do
    assigns = render_assigns(socket)

    inner_content =
      case socket do
        %{private: %{render_with: render_with}} ->
          assigns
          |> render_with.()
          |> check_rendered!(render_with)

        %{} ->
          if function_exported?(view, :render, 1) do
            assigns
            |> view.render()
            |> check_rendered!(view)
          else
            template =
              view.__info__(:compile)[:source]
              |> Path.dirname()
              |> Path.join(template_filename(view) <> ".heex")

            raise ~s'''
            render/1 was not implemented for #{inspect(view)}.

            In order to render templates in LiveView/LiveComponent, you must either:

            1. Define a render/1 function that receives assigns and uses the ~H sigil:

                def render(assigns) do
                  ~H"""
                  <div>...</div>
                  """
                end

            2. Create a file at #{inspect(template)} with template contents

            3. Call Phoenix.LiveView.render_with/2 with a custom rendering function
            '''
          end
      end

    case layout(socket, view) do
      {layout_mod, layout_template} ->
        assigns = put_in(assigns[:inner_content], inner_content)
        assigns = put_in(assigns.__changed__[:inner_content], true)

        layout_mod
        |> Phoenix.Template.render(to_string(layout_template), "html", assigns)
        |> check_rendered!(layout_mod)

      false ->
        inner_content
    end
  end

  defp render_assigns(%{assigns: assigns} = socket) do
    socket = %Socket{socket | assigns: %Socket.AssignsNotInSocket{__assigns__: assigns}}
    Map.put(assigns, :socket, socket)
  end

  defp check_rendered!(%Rendered{} = rendered, _view), do: rendered

  defp check_rendered!(other, view) do
    raise RuntimeError, """
    expected #{inspect(view)} to return a %Phoenix.LiveView.Rendered{} struct

    Ensure your render function uses ~H, or your template uses the .heex extension.

    Got:

        #{inspect(other)}

    """
  end

  defp layout(socket, view) do
    case socket.private do
      %{live_layout: layout} -> layout
      %{} -> view.__live__()[:layout]
    end
  end
end

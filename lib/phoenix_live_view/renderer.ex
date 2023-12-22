defmodule Phoenix.LiveView.Renderer do
  @moduledoc false

  alias Phoenix.LiveView.{Rendered, Socket}

  import Phoenix.LiveView.Utils, only: [get_format: 1]

  defmacro __before_compile__(%{module: module, file: file} = env) do
    render? = Module.defines?(module, {:render, 1})
    root = Path.dirname(file)
    formats = Module.get_attribute(module, :phoenix_live_opts)[:formats] || [:html]

    templates = Enum.reduce(formats, [], fn(format, templates_acc) ->
      filename = template_filename(module, format)

      case Phoenix.Template.find_all(root, filename) do
        [] -> templates_acc
        templates when is_list(templates) ->
          List.insert_at(templates_acc, -1, {format, templates})
      end
    end)

    case {render?, templates} do
      {true, []}->
        :ok

      {true, templates} ->
        templates_list = 
          templates
          |> Keyword.values()
          |> Enum.map(fn([template | _]) -> "\n* #{template}" end)

        message = "ignoring these templates:\n" <>
          templates_list <>
          "\nbecause the LiveView #{inspect(env.module)} defines a render/1 function"

        IO.warn(message, Macro.Env.stacktrace(env))

        :ok

      {false, []} ->
        templates = Enum.map(formats, fn(format) ->
          filename = template_filename(module, format)
          template = Path.join(root, filename <> ".heex")
          {format, template}
        end)

        quote do
          for format <- unquote(formats) do
            @external_resource unquote(templates)[format]
          end
        end

      {false, templates} ->
        case verify_no_multiple_templates(templates) do
          {:warn, message} ->
            IO.warn(
              "multiple templates were found for #{inspect(env.module)}:\n#{message}",
              Macro.Env.stacktrace(env)
            )

            :ok
          :ok ->
            templates = Enum.into(templates, [], fn({key, [template]}) ->
              ext = template |> Path.extname() |> String.trim_leading(".") |> String.to_atom()
              engine = Map.fetch!(Phoenix.Template.engines(), ext)
              filename = Path.basename(template)
              ast = engine.compile(template, filename)
              {key, %{path: template, ast: ast}}
            end)

            render_ast = 
              quote do
                def render(var!(assigns)) when is_map(var!(assigns)) do
                  format = Phoenix.LiveView.Utils.get_format(var!(assigns).socket)
                  apply(__MODULE__, :"render_#{format}", [var!(assigns)])
                end
              end

            render_format_asts = 
              for format <- formats do
                quote do
                  @file unquote(templates[format][:path])
                  @external_resource unquote(templates[format][:path])
                  def unquote(:"render_#{format}")(var!(assigns)) do
                    unquote(templates[format][:ast])
                  end
                end
              end

            [render_ast | render_format_asts]
        end
    end
  end

  defp verify_no_multiple_templates(templates) do
    templates
    |> Keyword.values()
    |> Enum.reduce([], fn 
      [_template], acc -> acc
      [], acc -> acc
      [_ | _] = templates, acc -> 
        [templates | acc]
    end)
    |> case do
      [] -> :ok
      templates ->
        template_list = 
          templates
          |> List.flatten()
          |> Enum.map(fn(template) ->
            "\n* #{template}"
          end)
          |> Enum.join()

        {:warn, template_list}
    end
  end

  defp template_filename(module, format) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>(".#{format}")
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
            format = get_format(socket)
            template =
              view.__info__(:compile)[:source]
              |> Path.dirname()
              |> Path.join(template_filename(view, format) <> ".heex")

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
        format = get_format(socket)

        layout_mod
        |> Phoenix.Template.render(to_string(layout_template), format, assigns)
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
      %{} ->
        format =
          socket
          |> get_format()
          |> String.to_atom()

        case view.__live__()[:layouts] do
         layouts when is_list(layouts) -> layouts[format] 
         _ -> false
        end
    end
  end
end

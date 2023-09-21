defmodule Phoenix.LiveViewTest.HTML do
  require EasyHTML

  defmacro sigil_X({:<<>>, _, [binary]}, []) when is_binary(binary) do
    Macro.escape(EasyHTML.parse!(binary))
  end

  defmacro sigil_x(term, []) do
    quote bind_quoted: [term: term] do
      EasyHTML.parse!(term)
    end
  end

  def t2h(template) do
    template
    |> Phoenix.LiveViewTest.rendered_to_string()
    |> EasyHTML.parse!()
  end
end

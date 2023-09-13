defmodule Phoenix.LiveView.HtmlTestHelpers do
  @moduledoc false

  require EasyHTML

  defmacro sigil_X({:<<>>, _, [binary]}, []) do
    Macro.escape(EasyHTML.parse!(binary))
  end

  def t2h(template) do
    template
    |> Phoenix.LiveViewTest.rendered_to_string()
    |> EasyHTML.parse!()
  end
end

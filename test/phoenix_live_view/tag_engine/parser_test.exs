defmodule Phoenix.LiveView.TagEngine.ParserTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.TagEngine.Parser

  defp parse(source) do
    Parser.parse!(source,
      file: __ENV__.file,
      caller: __ENV__,
      source: source,
      tag_handler: Phoenix.LiveView.HTMLEngine,
      trim_eex: false
    )
  end

  describe "eex blocks" do
    test "merges split clause middle expressions" do
      source =
        "<%= with {:ok, x} <- @res do %>\n  {x}\n<% else %>\n  <% _ -> %>\n    bad\n<% end %>"

      assert %Parser{
               nodes: [
                 {:eex_block, " with {:ok, x} <- @res do ",
                  [
                    {[
                       {:text, "\n  ", %{}},
                       {:body_expr, "x", %{line: 2, column: 3}},
                       {:text, "\n", %{}}
                     ], " else \n   _ -> ", %{line: 3, opt: [], column: 1}},
                    {[{:text, "\n    bad\n", %{}}], " end ", %{line: 6, opt: [], column: 1}}
                  ], %{line: 1, opt: ~c"=", column: 1}}
               ]
             } = parse(source)
    end

    test "keeps whitespace after stab clauses as body content" do
      source = "<%= case @x do %>\n  <% :foo -> %>\n  <% :bar -> %>\n<% end %>"

      assert %Parser{
               nodes: [
                 {:eex_block, " case @x do ",
                  [
                    {[{:text, "\n  ", %{}}], " :foo -> ", %{line: 2, opt: [], column: 3}},
                    {[{:text, "\n  ", %{}}], " :bar -> ", %{line: 3, opt: [], column: 3}},
                    {[{:text, "\n", %{}}], " end ", %{line: 4, opt: [], column: 1}}
                  ], %{line: 1, opt: ~c"=", column: 1}}
               ]
             } = parse(source)
    end
  end
end

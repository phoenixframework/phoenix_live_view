defmodule Phoenix.LiveView.TagEngineTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.TagEngine

  describe "mark_variables_ast_change_tracked/1" do
    test "ignores pinned variables and binary modifiers" do
      ast =
        quote do
          %{foo: foo, bar: ^bar, bin: <<thebin::binary>>, other: other}
        end

      assert {new_ast, variables} = TagEngine.mark_variables_as_change_tracked(ast, %{})
      assert map_size(variables) == 3

      assert %{
               foo: {:foo, [change_track: true], _},
               other: {:other, [change_track: true], _},
               thebin: {:thebin, [change_track: true], _}
             } = variables

      assert new_ast != ast
    end
  end
end

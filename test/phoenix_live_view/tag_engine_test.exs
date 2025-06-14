defmodule Phoenix.LiveView.TagEngineTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.TagEngine

  describe "mark_variables_ast_change_tracked/1" do
    test "ignores pinned variables and binary modifiers" do
      ast =
        quote do
          %{foo: foo, bar: ^bar, bin: <<thebin::binary>>, other: other}
        end

      assert {new_ast, variables} = TagEngine.mark_variables_as_change_tracked(ast)

      assert [
               {:foo, {:foo, [change_track: true], _}},
               {:other, {:other, [change_track: true], _}},
               {:thebin, {:thebin, [change_track: true], _}}
             ] = Enum.sort_by(variables, &elem(&1, 0))

      assert new_ast != ast
    end
  end
end

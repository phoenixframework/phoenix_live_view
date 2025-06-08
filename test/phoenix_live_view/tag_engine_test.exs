defmodule Phoenix.LiveView.TagEngineTest do
  use ExUnit.Case, async: true

  defp to_ast(source) do
    options = [
      engine: Phoenix.LiveView.TagEngine,
      file: __ENV__.file,
      line: __ENV__.line,
      caller: __ENV__,
      indentation: 0,
      source: source,
      tag_handler: Phoenix.LiveView.HTMLEngine
    ]

    EEx.compile_string(source, options)
  end

  defmacrop keyed_comprehension(id, vars_changed) do
    quote do
      {{:., [], [{_, _, [:Phoenix, :LiveView, :TagEngine]}, :keyed_comprehension]}, [],
       [unquote(id), unquote(vars_changed), _]}
    end
  end

  defp keyed_comprehensions(ast) do
    {_, kc} =
      Macro.prewalk(ast, [], fn
        keyed_comprehension(id, vars_changed) = ast, acc ->
          {ast, [{id, vars_changed} | acc]}

        other, acc ->
          {other, acc}
      end)

    kc
  end

  describe "keyed comprehensions" do
    test "has vars_changed" do
      ast =
        to_ast("""
        <ul>
          <li :for={%{id: id, name: name} <- @items} :key={@id}>
            Count: <span>{@count}</span>,
            item: {name}
          </li>
        </ul>
        """)

      assert [{id, vars_changed}] = keyed_comprehensions(ast)
      assert {:{}, _, [__MODULE__, _line, _col, {{:., _, [{:assigns, _, _}, :id]}, _, []}]} = id
      assert {:%{}, [], keys_and_vars} = vars_changed

      assert [
               id: {:id, [{:change_track, true} | _], _},
               name: {:name, [{:change_track, true} | _], _}
             ] = Enum.sort_by(keys_and_vars, fn {key, _} -> key end)
    end

    test "vars_changed ignores pin and binary type" do
      ast =
        to_ast("""
        <ul>
          <li :for={{id, name, ^bar, <<other::binary>>, stuff} <- @items} :key={@id}>
            Count: <span>{@count}</span>,
            item: {name}
          </li>
        </ul>
        """)

      assert [{id, vars_changed}] = keyed_comprehensions(ast)
      assert {:{}, _, [__MODULE__, _line, _col, {{:., _, [{:assigns, _, _}, :id]}, _, []}]} = id
      assert {:%{}, [], keys_and_vars} = vars_changed

      assert [
               id: {:id, [{:change_track, true} | _], _},
               name: {:name, [{:change_track, true} | _], _},
               other: {:other, [{:change_track, true} | _], _},
               stuff: {:stuff, [{:change_track, true} | _], _}
             ] = Enum.sort_by(keys_and_vars, fn {key, _} -> key end)
    end
  end
end

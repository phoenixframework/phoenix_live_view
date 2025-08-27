defmodule Phoenix.LiveViewTest.DiffTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveViewTest.Diff

  describe "merge_diff" do
    test "merges unless static" do
      assert Diff.merge_diff(%{0 => "bar", s: "foo"}, %{0 => "baz"}) ==
               %{0 => "baz", s: "foo", streams: []}

      assert Diff.merge_diff(%{s: "foo", d: []}, %{s: "bar"}) ==
               %{s: "bar", streams: []}
    end

    test "resolves moved comprehensions" do
      base = %{
        k: %{
          0 => %{0 => "A"},
          1 => %{0 => "B"},
          2 => %{0 => "C", 1 => %{0 => "var1", :s => ["", ""]}},
          :kc => 3
        }
      }

      diff = %{
        k: %{
          0 => 1,
          1 => [2, %{1 => %{0 => "var2"}}],
          :kc => 2
        }
      }

      result = %{
        k: %{
          0 => %{0 => "B"},
          1 => %{0 => "C", 1 => %{0 => "var2", :s => ["", ""]}},
          :kc => 2
        },
        streams: []
      }

      assert Diff.merge_diff(base, diff) == result
    end
  end
end

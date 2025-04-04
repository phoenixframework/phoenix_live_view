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
  end
end

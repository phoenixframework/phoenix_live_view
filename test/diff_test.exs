defmodule Phoenix.LiveView.DiffTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.Diff

  @template %Phoenix.LiveView.Rendered{
    static: ["<h2>...", "\n<span>", "</span>\n"],
    dynamic: [
      "hi",
      %Phoenix.LiveView.Rendered{
        static: ["", "", ""],
        dynamic: ["abc"],
        fingerprint: 456
      },
      nil,
      %Phoenix.LiveView.Rendered{
        static: ["", ""],
        dynamic: ["efg"],
        fingerprint: 789
      }
    ],
    fingerprint: 123
  }

  test "full render without fingerprints" do
    {full_render, fingerprint_tree} = Diff.render(@template)

    assert full_render == %{
             dynamic: %{
               0 => "hi",
               1 => %{
                 dynamic: %{
                   0 => "abc"
                 },
                 static: ["", "", ""]
               },
               3 => %{dynamic: %{0 => "efg"}, static: ["", ""]}
             },
             static: ["<h2>...", "\n<span>", "</span>\n"]
           }

    assert fingerprint_tree == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
  end

  test "diffed render with fingerprints" do
    {diffed_render, diffed_tree} =
      Diff.render(@template, {123, %{1 => {456, %{1 => {1012, %{}}}}, 3 => {789, %{}}}})

    assert diffed_render ==
             %{
               dynamic: %{
                 0 => "hi",
                 3 => %{dynamic: %{0 => "efg"}},
                 1 => %{dynamic: %{0 => "abc"}}
               }
             }

    assert diffed_tree == {123, %{3 => {789, %{}}, 1 => {456, %{1 => {1012, %{}}}}}}
  end
end

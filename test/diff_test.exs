defmodule Phoenix.LiveView.DiffTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveView, only: [sigil_L: 2]

  alias Phoenix.LiveView.{Diff, Rendered}

  def basic_template(assigns) do
    ~L"""
    <div>
      <h2>It's <%= @time %></h2>
      <%= @subtitle %>
    </div>
    """
  end

  def literal_template(assigns) do
    ~L"""
    <div>
      <%= @title %>
      <%= "<div>" %>
    </div>
    """
  end

  def comprehension_template(assigns) do
    ~L"""
    <div>
      <h1><%= @title %></h1>
      <%= for name <- @names do %>
        <br/><%= name %>
      <% end %>
    </div>
    """
  end

  @nested %Rendered{
    static: ["<h2>...", "\n<span>", "</span>\n"],
    dynamic: [
      "hi",
      %Rendered{
        static: ["s1", "s2", "s3"],
        dynamic: ["abc"],
        fingerprint: 456
      },
      nil,
      %Rendered{
        static: ["s1", "s2"],
        dynamic: ["efg"],
        fingerprint: 789
      }
    ],
    fingerprint: 123
  }

  describe "full renders without fingerprints" do
    test "basic template" do
      rendered = basic_template(%{time: "10:30", subtitle: "Sunny"})
      {full_render, fingerprint_tree} = Diff.render(rendered)

      assert full_render == %{
               0 => "10:30",
               1 => "Sunny",
               :static => ["<div>\n  <h2>It's ", "</h2>\n  ", "\n</div>\n"]
             }

      assert fingerprint_tree == {rendered.fingerprint, %{}}
    end

    test "template with literal" do
      rendered = literal_template(%{title: "foo"})
      {full_render, fingerprint_tree} = Diff.render(rendered)

      assert full_render ==
               %{0 => "foo", 1 => "&lt;div&gt;", :static => ["<div>\n  ", "\n  ", "\n</div>\n"]}

      assert fingerprint_tree == {rendered.fingerprint, %{}}
    end

    test "nested %Renderered{}'s" do
      {full_render, fingerprint_tree} = Diff.render(@nested)

      assert full_render ==
               %{
                 :static => ["<h2>...", "\n<span>", "</span>\n"],
                 0 => "hi",
                 1 => %{0 => "abc", :static => ["s1", "s2", "s3"]},
                 3 => %{0 => "efg", :static => ["s1", "s2"]}
               }

      assert fingerprint_tree == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "comprehensions" do
      rendered = comprehension_template(%{title: "Users", names: ["phoenix", "elixir"]})
      {full_render, fingerprint_tree} = Diff.render(rendered)

      assert full_render ==
               %{
                 0 => "Users",
                 :static => ["<div>\n  <h1>", "</h1>\n  ", "\n</div>\n"],
                 1 => %{
                   static: ["\n    <br/>", "\n  "],
                   dynamics: [["phoenix"], ["elixir"]]
                 }
               }

      assert fingerprint_tree == {rendered.fingerprint, %{1 => :comprehension}}
    end
  end

  describe "diffed render with fingerprints" do
    test "basic template skips statics for known fingerprints" do
      rendered = basic_template(%{time: "10:30", subtitle: "Sunny"})
      {full_render, prints} = Diff.render(rendered, {rendered.fingerprint, %{}})

      assert full_render == %{0 => "10:30", 1 => "Sunny"}
      assert prints == {rendered.fingerprint, %{}}
    end

    test "renders nested %Renderered{}'s" do
      tree = {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
      {diffed_render, diffed_tree} = Diff.render(@nested, tree)

      assert diffed_render == %{0 => "hi", 1 => %{0 => "abc"}, 3 => %{0 => "efg"}}
      assert diffed_tree == tree
    end

    test "detects change in nested fingerprint" do
      old_tree = {123, %{3 => {789, %{}}, 1 => {100_001, %{}}}}
      {diffed_render, diffed_tree} = Diff.render(@nested, old_tree)

      assert diffed_render ==
               %{0 => "hi", 3 => %{0 => "efg"}, 1 => %{0 => "abc", :static => ["s1", "s2", "s3"]}}

      assert diffed_tree == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "detects change in root fingerprint" do
      old_tree = {99999, %{}}
      {diffed_render, diffed_tree} = Diff.render(@nested, old_tree)

      assert diffed_render ==
               %{
                 0 => "hi",
                 1 => %{0 => "abc", :static => ["s1", "s2", "s3"]},
                 3 => %{0 => "efg", :static => ["s1", "s2"]},
                 :static => ["<h2>...", "\n<span>", "</span>\n"]
               }

      assert diffed_tree == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
    end
  end
end

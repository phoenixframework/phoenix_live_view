defmodule Phoenix.LiveView.EngineTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.{Engine, Rendered}

  def safe(do: {:safe, _} = safe), do: safe
  def unsafe(do: {:safe, content}), do: content

  describe "rendering" do
    test "escapes HTML" do
      template = """
      <start> <%= "<escaped>" %>
      """

      assert render(template) == "<start> &lt;escaped&gt;\n"
    end

    test "escapes HTML from nested content" do
      template = """
      <%= Phoenix.LiveView.EngineTest.unsafe do %>
        <foo>
      <% end %>
      """

      assert render(template) == "\n  &lt;foo&gt;\n\n"
    end

    test "does not escape safe expressions" do
      assert render("Safe <%= {:safe, \"<value>\"} %>") == "Safe <value>"
    end

    test "nested content is always safe" do
      template = """
      <%= Phoenix.LiveView.EngineTest.safe do %>
        <foo>
      <% end %>
      """

      assert render(template) == "\n  <foo>\n\n"

      template = """
      <%= Phoenix.LiveView.EngineTest.safe do %>
        <%= "<foo>" %>
      <% end %>
      """

      assert render(template) == "\n  &lt;foo&gt;\n\n"
    end

    test "handles assigns" do
      assert render("<%= @foo %>", %{foo: "<hello>"}) == "&lt;hello&gt;"
    end

    test "supports non-output expressions" do
      template = """
      <% foo = @foo %>
      <%= foo %>
      """

      assert render(template, %{foo: "<hello>"}) == "\n&lt;hello&gt;\n"
    end

    test "supports mixed non-output expressions" do
      template = """
      prea
      <% @foo %>
      posta
      <%= @foo %>
      preb
      <% @foo %>
      middleb
      <% @foo %>
      postb
      """

      assert render(template, %{foo: "<hello>"}) ==
               "prea\n\nposta\n&lt;hello&gt;\npreb\n\nmiddleb\n\npostb\n"
    end

    test "raises ArgumentError for missing assigns" do
      assert_raise ArgumentError,
                   ~r/assign @foo not available in eex template.*Available assigns: \[:bar\]/s,
                   fn -> render("<%= @foo %>", %{bar: true}) end
    end
  end

  describe "rendered structure" do
    test "contains two static parts and one dynamic" do
      %{static: static, dynamic: dynamic} = eval("foo<%= 123 %>bar")
      assert dynamic.(true) == ["123"]
      assert static == ["foo", "bar"]
    end

    test "contains one static part at the beginning and one dynamic" do
      %{static: static, dynamic: dynamic} = eval("foo<%= 123 %>")
      assert dynamic.(true) == ["123"]
      assert static == ["foo", ""]
    end

    test "contains one static part at the end and one dynamic" do
      %{static: static, dynamic: dynamic} = eval("<%= 123 %>bar")
      assert dynamic.(true) == ["123"]
      assert static == ["", "bar"]
    end

    test "contains one dynamic only" do
      %{static: static, dynamic: dynamic} = eval("<%= 123 %>")
      assert dynamic.(true) == ["123"]
      assert static == ["", ""]
    end

    test "contains two dynamics only" do
      %{static: static, dynamic: dynamic} = eval("<%= 123 %><%= 456 %>")
      assert dynamic.(true) == ["123", "456"]
      assert static == ["", "", ""]
    end

    test "contains two static parts and two dynamics" do
      %{static: static, dynamic: dynamic} = eval("foo<%= 123 %><%= 456 %>bar")
      assert dynamic.(true) == ["123", "456"]
      assert static == ["foo", "", "bar"]
    end

    test "contains three static parts and two dynamics" do
      %{static: static, dynamic: dynamic} = eval("foo<%= 123 %>bar<%= 456 %>baz")
      assert dynamic.(true) == ["123", "456"]
      assert static == ["foo", "bar", "baz"]
    end

    test "contains optimized comprehensions" do
      template = """
      before
      <%= for point <- @points do %>
        x: <%= point.x %>
        y: <%= point.y %>
      <% end %>
      after
      """

      %{static: static, dynamic: dynamic} =
        eval(template, %{points: [%{x: 1, y: 2}, %{x: 3, y: 4}]})

      assert static == ["before\n", "\nafter\n"]

      assert [
               %Phoenix.LiveView.Comprehension{
                 static: ["\n  x: ", "\n  y: ", "\n"],
                 dynamics: [
                   ["1", "2"],
                   ["3", "4"]
                 ]
               }
             ] = dynamic.(true)
    end
  end

  describe "change tracking" do
    test "does not render dynamic if it is unchanged" do
      template = "<%= @foo %>"
      assert changed(template, %{foo: 123}, nil) == ["123"]
      assert changed(template, %{foo: 123}, %{}) == [nil]
      assert changed(template, %{foo: 123}, %{foo: true}) == ["123"]
    end

    test "renders dynamic if any of the assigns change" do
      template = "<%= @foo + @bar %>"
      assert changed(template, %{foo: 123, bar: 456}, nil) == ["579"]
      assert changed(template, %{foo: 123, bar: 456}, %{}) == [nil]
      assert changed(template, %{foo: 123, bar: 456}, %{foo: true}) == ["579"]
      assert changed(template, %{foo: 123, bar: 456}, %{bar: true}) == ["579"]
    end

    test "does not render dynamic without assigns" do
      template = "<%= 1 + 2 %>"
      assert changed(template, %{}, nil) == ["3"]
      assert changed(template, %{}, %{}) == [nil]
    end

    test "does not render dynamic on bitstring modifiers" do
      template = "<%= <<@foo::binary>> %>"
      assert changed(template, %{foo: "123"}, nil) == ["123"]
      assert changed(template, %{foo: "123"}, %{}) == [nil]
      assert changed(template, %{foo: "123"}, %{foo: true}) == ["123"]
    end

    test "renders dynamic without change tracking" do
      assert changed("<%= @foo %>", %{foo: 123}, %{foo: true}, false) == ["123"]
      assert changed("<%= 1 + 2 %>", %{foo: 123}, %{}, 123) == ["3"]
    end

    test "renders dynamic if it has a lexical form" do
      template = "<%= import List %><%= flatten(@foo) %>"
      assert changed(template, %{foo: '123'}, nil) == ["Elixir.List", '123']
      assert changed(template, %{foo: '123'}, %{}) == ["Elixir.List", nil]
      assert changed(template, %{foo: '123'}, %{foo: true}) == ["Elixir.List", '123']
    end

    test "renders dynamic if it has variables" do
      template = "<%= foo = 1 + 2 %><%= foo %>"
      assert changed(template, %{}, nil) == ["3", "3"]
      assert changed(template, %{}, %{}) == ["3", "3"]
    end

    test "renders dynamic if it has variables from assigns" do
      template = "<%= foo = @foo %><%= foo %>"
      assert changed(template, %{foo: 123}, nil) == ["123", "123"]
      assert changed(template, %{foo: 123}, %{}) == ["123", "123"]
      assert changed(template, %{foo: 123}, %{foo: true}) == ["123", "123"]
    end

    test "does not render dynamic if it has variables inside special form" do
      template = "<%= cond do foo = @foo -> foo end %>"
      assert changed(template, %{foo: 123}, nil) == ["123"]
      assert changed(template, %{foo: 123}, %{}) == [nil]
      assert changed(template, %{foo: 123}, %{foo: true}) == ["123"]
    end

    test "renders dynamic if it has variables from outside inside special form" do
      template = "<% f = @foo %><%= cond do foo = f -> foo end %>"
      assert changed(template, %{foo: 123}, nil) == ["123"]
      assert changed(template, %{foo: 123}, %{}) == ["123"]
      assert changed(template, %{foo: 123}, %{foo: true}) == ["123"]
    end

    test "does not render dynamic if it has variables inside unoptimized comprehension" do
      template = "<%= for foo <- @foo, do: foo %>"
      assert changed(template, %{foo: [1, 2, 3]}, nil) == [[1, 2, 3]]
      assert changed(template, %{foo: [1, 2, 3]}, %{}) == [nil]
      assert changed(template, %{foo: [1, 2, 3]}, %{foo: true}) == [[1, 2, 3]]
    end

    test "does not render dynamic if it has variables inside optimized comprehension" do
      template = "<%= for foo <- @foo do %><%= foo %><% end %>"

      assert [%{dynamics: [["1"], ["2"], ["3"]]}] =
               changed(template, %{foo: ["1", "2", "3"]}, nil)

      assert [nil] = changed(template, %{foo: ["1", "2", "3"]}, %{})

      assert [%{dynamics: [["1"], ["2"], ["3"]]}] =
               changed(template, %{foo: ["1", "2", "3"]}, %{foo: true})
    end

    test "does not render dynamic if it has a variable after a condition inside optimized comprehension" do
      template =
        "<%= for foo <- @foo do %><%= if foo == @selected, do: ~s(selected) %><%= foo %><% end %>"

      assert [%{dynamics: [["", "1"], ["selected", "2"], ["", "3"]]}] =
               changed(template, %{foo: ["1", "2", "3"], selected: "2"}, nil)

      assert [nil] = changed(template, %{foo: ["1", "2", "3"], selected: "2"}, %{})

      assert [%{dynamics: [["", "1"], ["selected", "2"], ["", "3"]]}] =
               changed(template, %{foo: ["1", "2", "3"], selected: "2"}, %{foo: true})
    end

    test "does not render dynamic for nested optimized comprehensions with variables" do
      template =
        "<%= for x <- @foo do %>X: <%= for y <- @bar do %>Y: <%= x %><%= y %><% end %><% end %>"

      assert [
               %{
                 dynamics: [
                   [%{dynamics: [["1", "1"]], static: ["Y: ", "", ""]}]
                 ],
                 static: ["X: ", ""]
               }
             ] = changed(template, %{foo: [1], bar: [1]}, nil)

      assert [nil] = changed(template, %{foo: [1], bar: [1]}, %{})

      assert [
               %{
                 dynamics: [
                   [%{dynamics: [["1", "1"]], static: ["Y: ", "", ""]}]
                 ],
                 static: ["X: ", ""]
               }
             ] = changed(template, %{foo: [1], bar: [1]}, %{foo: true, bar: true})
    end

    test "renders dynamics for nested comprehensions" do
      template =
        "<%= for foo <- @foo do %><%= for bar <- foo.bar do %><%= foo.x %><%= bar.y %><% end %><% end %>"

      assert [
               %{
                 dynamics: [
                   [%{dynamics: [["1", "1"]], static: ["", "", ""]}]
                 ],
                 static: ["", ""]
               }
             ] = changed(template, %{foo: [%{x: 1, bar: [%{y: 1}]}]}, %{foo: true})
    end

    test "renders dynamic if it uses assigns" do
      template = "<%= for _ <- [1, 2, 3], do: assigns.foo %>"
      assert changed(template, %{foo: "a"}, nil) == [["a", "a", "a"]]
      assert changed(template, %{foo: "a"}, %{}) == [["a", "a", "a"]]
      assert changed(template, %{foo: "a"}, %{foo: true}) == [["a", "a", "a"]]
    end
  end

  describe "if" do
    test "converts if-do into rendered" do
      template = "<%= if true do %>one<%= @foo %>two<% end %>"

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, %{foo: true})
    end

    test "converts if-do into rendered with dynamic condition" do
      template = "<%= if @bar do %>one<%= @foo %>two<% end %>"

      # bar = true
      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123, bar: true}, nil)

      assert changed(template, %{foo: 123, bar: true}, %{}) ==
               [nil]

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123, bar: true}, %{foo: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123, bar: true}, %{bar: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123, bar: true}, %{foo: true, bar: true})

      # bar = false
      assert [""] = changed(template, %{foo: 123, bar: false}, nil)

      assert changed(template, %{foo: 123, bar: false}, %{}) ==
               [nil]

      assert changed(template, %{foo: 123, bar: false}, %{bar: true}) ==
               [""]
    end

    test "converts if-do-else into rendered with dynamic condition" do
      template = "<%= if @bar do %>one<%= @foo %>two<% else %>uno<%= @baz %>dos<% end %>"

      # bar = true
      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: true, baz: 456}, %{})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true, baz: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true})

      assert [%Rendered{dynamic: [nil], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{baz: true})

      # bar = false
      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: false, baz: 456}, %{})

      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true, bar: true})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{bar: true})

      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{baz: true})

      assert fptrue != fpfalse
    end

    test "converts if-do if-do into rendered" do
      template = "<%= if true do %>one<%= if true do %>uno<%= @foo %>dos<% end %>two<% end %>"

      assert [
               %Rendered{
                 dynamic: [%Rendered{dynamic: ["123"], static: ["uno", "dos"]}],
                 static: ["one", "two"]
               }
             ] = changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [
               %Rendered{
                 dynamic: [%Rendered{dynamic: ["123"], static: ["uno", "dos"]}],
                 static: ["one", "two"]
               }
             ] = changed(template, %{foo: 123}, %{foo: true})
    end

    test "does not convert if-do-else in the wrong format" do
      template = "<%= if @bar do @foo else @baz end %>"

      assert changed(template, %{foo: 123, bar: true, baz: 456}, nil) == ["123"]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{}) == [nil]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true}) == ["123"]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{foo: true}) == ["123"]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{baz: true}) == ["123"]

      assert changed(template, %{foo: 123, bar: false, baz: 456}, nil) == ["456"]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{}) == [nil]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{bar: true}) == ["456"]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true}) == ["456"]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{baz: true}) == ["456"]
    end
  end

  describe "case" do
    test "converts case into rendered" do
      template = "<%= case true do %><% true -> %>one<%= @foo %>two<% end %>"

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, %{foo: true})
    end

    test "converts multiple case into rendered with dynamic condition" do
      template =
        "<%= case @bar do %><% true -> %>one<%= @foo %>two<% false -> %>uno<%= @baz %>dos<% end %>"

      # bar = true
      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: true, baz: 456}, %{})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true, baz: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true})

      assert [%Rendered{dynamic: [nil], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{baz: true})

      # bar = false
      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: false, baz: 456}, %{})

      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true, bar: true})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{bar: true})

      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{baz: true})

      assert fptrue != fpfalse
    end

    test "converts nested case into rendered" do
      template =
        "<%= case true do %><% true -> %>one<%= case true do %><% true -> %>uno<%= @foo %>dos<% end %>two<% end %>"

      assert [
               %Rendered{
                 dynamic: [%Rendered{dynamic: ["123"], static: ["uno", "dos"]}],
                 static: ["one", "two"]
               }
             ] = changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [
               %Rendered{
                 dynamic: [%Rendered{dynamic: ["123"], static: ["uno", "dos"]}],
                 static: ["one", "two"]
               }
             ] = changed(template, %{foo: 123}, %{foo: true})
    end

    test "does not convert cases in the wrong format" do
      template = "<%= case @bar do true -> @foo; false -> @baz end %>"

      assert changed(template, %{foo: 123, bar: true, baz: 456}, nil) == ["123"]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{}) == [nil]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true}) == ["123"]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{foo: true}) == ["123"]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{baz: true}) == ["123"]

      assert changed(template, %{foo: 123, bar: false, baz: 456}, nil) == ["456"]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{}) == [nil]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{bar: true}) == ["456"]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true}) == ["456"]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{baz: true}) == ["456"]
    end
  end

  describe "cond" do
    test "converts cond into rendered" do
      template = "<%= cond do %><% true -> %>one<%= @foo %>two<% end %>"

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, %{foo: true})
    end

    test "converts multiple cond into rendered with dynamic condition" do
      template =
        "<%= cond do %><% @bar -> %>one<%= @foo %>two<% true -> %>uno<%= @baz %>dos<% end %>"

      # bar = true
      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: true, baz: 456}, %{})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true, baz: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true})

      assert [%Rendered{dynamic: [nil], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{baz: true})

      # bar = false
      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: false, baz: 456}, %{})

      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true, bar: true})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{bar: true})

      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{baz: true})

      assert fptrue != fpfalse
    end

    test "converts nested cond into rendered" do
      template =
        "<%= cond do %><% true -> %>one<%= cond do %><% true -> %>uno<%= @foo %>dos<% end %>two<% end %>"

      assert [
               %Rendered{
                 dynamic: [%Rendered{dynamic: ["123"], static: ["uno", "dos"]}],
                 static: ["one", "two"]
               }
             ] = changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [
               %Rendered{
                 dynamic: [%Rendered{dynamic: ["123"], static: ["uno", "dos"]}],
                 static: ["one", "two"]
               }
             ] = changed(template, %{foo: 123}, %{foo: true})
    end

    test "does not convert conds in the wrong format" do
      template = "<%= cond do @bar -> @foo; true -> @baz end %>"

      assert changed(template, %{foo: 123, bar: true, baz: 456}, nil) == ["123"]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{}) == [nil]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true}) == ["123"]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{foo: true}) == ["123"]
      assert changed(template, %{foo: 123, bar: true, baz: 456}, %{baz: true}) == ["123"]

      assert changed(template, %{foo: 123, bar: false, baz: 456}, nil) == ["456"]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{}) == [nil]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{bar: true}) == ["456"]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true}) == ["456"]
      assert changed(template, %{foo: 123, bar: false, baz: 456}, %{baz: true}) == ["456"]
    end
  end

  describe "fingerprints" do
    test "are integers" do
      rendered1 = eval("foo<%= @bar %>baz", %{bar: 123})
      rendered2 = eval("foo<%= @bar %>baz", %{bar: 456})
      assert is_integer(rendered1.fingerprint)
      assert rendered1.fingerprint == rendered2.fingerprint
    end

    test "changes even with dynamic content" do
      assert eval("<%= :foo %>").fingerprint != eval("<%= :bar %>").fingerprint
    end
  end

  describe "integration" do
    defmodule View do
      use Phoenix.View, root: "test/fixtures/templates", path: ""
    end

    @assigns %{pre: "pre", inner: "inner", post: "post"}

    test "renders live engine to string" do
      assert Phoenix.View.render_to_string(View, "inner_live.html", @assigns) == "live: inner"
    end

    test "renders live engine with live engine to string" do
      assert Phoenix.View.render_to_string(View, "live_with_live.html", @assigns) ==
               "pre: pre\nlive: inner\npost: post"
    end

    test "renders live engine with comprehension to string" do
      assigns = Map.put(@assigns, :points, [%{x: 1, y: 2}, %{x: 3, y: 4}])

      assert Phoenix.View.render_to_string(View, "live_with_comprehension.html", assigns) ==
               "pre: pre\n\n  x: 1\n  live: inner\n  y: 2\n\n  x: 3\n  live: inner\n  y: 4\n\npost: post"
    end

    test "renders live engine as is" do
      assert %Rendered{static: ["live: ", ""], dynamic: ["inner"]} =
               Phoenix.View.render(View, "inner_live.html", @assigns) |> expand_rendered(true)
    end

    test "renders live engine with nested live view" do
      assert %Rendered{
               static: ["pre: ", "\n", "\npost: ", ""],
               dynamic: [
                 "pre",
                 %Rendered{dynamic: ["inner"], static: ["live: ", ""]},
                 "post"
               ]
             } =
               Phoenix.View.render(View, "live_with_live.html", @assigns) |> expand_rendered(true)
    end

    test "renders live engine with nested dead view" do
      assert %Rendered{
               static: ["pre: ", "\n", "\npost: ", ""],
               dynamic: ["pre", ["dead: ", "inner"], "post"]
             } =
               Phoenix.View.render(View, "live_with_dead.html", @assigns) |> expand_rendered(true)
    end

    test "renders dead engine with nested live view" do
      assert Phoenix.View.render(View, "dead_with_live.html", @assigns) ==
               {:safe, ["pre: ", "pre", "\n", ["live: ", "inner", ""], "\npost: ", "post"]}
    end
  end

  defp eval(string, assigns \\ %{}) do
    EEx.eval_string(string, [assigns: assigns], file: __ENV__.file, engine: Engine)
  end

  defp changed(string, assigns, changed, track_changes? \\ true) do
    socket = %{changed: changed}
    %{dynamic: dynamic} = eval(string, Map.put(assigns, :socket, socket))
    expand_dynamic(dynamic, track_changes?)
  end

  defp expand_dynamic(dynamic, track_changes?) do
    Enum.map(dynamic.(track_changes?), &expand_rendered(&1, track_changes?))
  end

  defp expand_rendered(%Rendered{} = rendered, track_changes?) do
    update_in(rendered.dynamic, &expand_dynamic(&1, track_changes?))
  end

  defp expand_rendered(other, _track_changes), do: other

  defp render(string, assigns \\ %{}) do
    string
    |> eval(assigns)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end

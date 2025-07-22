defmodule Phoenix.LiveView.EngineTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.{Engine, Rendered, Comprehension}

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

    test "raises KeyError for missing assigns" do
      assert_raise KeyError, fn -> render("<%= @foo %>", %{bar: true}) end
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
                 entries: [
                   {nil, %{point: %{x: 1, y: 2}}, _},
                   {nil, %{point: %{x: 3, y: 4}}, _}
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

    test "does not render dynamic if it is unchanged via assigns dot" do
      template = "<%= assigns.foo %>"
      assert changed(template, %{foo: 123}, nil) == ["123"]
      assert changed(template, %{foo: 123}, %{}) == [nil]
      assert changed(template, %{foo: 123}, %{foo: true}) == ["123"]
    end

    test "does not render dynamic if it is unchanged via assigns access" do
      template = "<%= assigns[:foo] %>"
      assert changed(template, %{foo: 123}, nil) == ["123"]
      assert changed(template, %{foo: 123}, %{}) == [nil]
      assert changed(template, %{foo: 123}, %{foo: true}) == ["123"]
      assert changed(template, %{}, %{}) == [nil]
      assert changed(template, %{}, %{foo: true}) == [""]
      assert changed(template, %{}, %{foo: true}) == [""]

      template = "<%= Access.get(assigns, :foo) %>"
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
      assert changed("<%= 1 + 2 %>", %{foo: 123}, %{}, false) == ["3"]
    end

    test "renders dynamic does not change track underscore" do
      assert changed("<%= _ = 123 %>", %{}, nil) == ["123"]
      assert changed("<%= _ = 123 %>", %{}, %{}) == [nil]
    end

    test "renders dynamic with dot tracking" do
      template = "<%= @map.foo + @map.bar %>"
      old = %{map: %{foo: 123, bar: 456}}
      new_augmented = %{map: %{foo: 123, bar: 456, baz: 789}}
      new_changed_foo = %{map: %{foo: 321, bar: 456}}
      new_changed_bar = %{map: %{foo: 123, bar: 654}}
      assert changed(template, old, nil) == ["579"]
      assert changed(template, old, %{}) == [nil]
      assert changed(template, old, %{map: true}) == ["579"]
      assert changed(template, old, old) == [nil]
      assert changed(template, new_augmented, old) == [nil]
      assert changed(template, new_changed_foo, old) == ["777"]
      assert changed(template, new_changed_bar, old) == ["777"]
    end

    test "renders dynamic with dot tracking 3-levels deeps" do
      template = "<%= @root.map.foo + @root.map.bar %>"
      old = %{root: %{map: %{foo: 123, bar: 456}}}
      new_augmented = %{root: %{map: %{foo: 123, bar: 456, baz: 789}}}
      new_changed_foo = %{root: %{map: %{foo: 321, bar: 456}}}
      new_changed_bar = %{root: %{map: %{foo: 123, bar: 654}}}
      assert changed(template, old, nil) == ["579"]
      assert changed(template, old, %{}) == [nil]
      assert changed(template, old, %{root: true}) == ["579"]
      assert changed(template, old, %{root: %{map: true}}) == ["579"]
      assert changed(template, old, old) == [nil]
      assert changed(template, new_augmented, old) == [nil]
      assert changed(template, new_changed_foo, old) == ["777"]
      assert changed(template, new_changed_bar, old) == ["777"]
    end

    test "renders dynamic with access tracking" do
      template = "<%= @not_map[:foo] + @not_map[:bar] %>"
      old = %{not_map: [foo: 123, bar: 456]}
      new_augmented = %{not_map: [foo: 123, bar: 456, baz: 789]}
      new_changed_foo = %{not_map: [foo: 321, bar: 456]}
      new_changed_bar = %{not_map: [foo: 123, bar: 654]}
      assert changed(template, old, nil) == ["579"]
      assert changed(template, old, %{}) == [nil]
      assert changed(template, old, %{not_map: true}) == ["579"]
      assert changed(template, old, old) == ["579"]
      assert changed(template, new_augmented, old) == ["579"]
      assert changed(template, new_changed_foo, old) == ["777"]
      assert changed(template, new_changed_bar, old) == ["777"]

      template = "<%= @map[:foo] + @map[:bar] %>"
      old = %{map: %{foo: 123, bar: 456}}
      new_augmented = %{map: %{foo: 123, bar: 456, baz: 789}}
      new_changed_foo = %{map: %{foo: 321, bar: 456}}
      new_changed_bar = %{map: %{foo: 123, bar: 654}}
      assert changed(template, old, nil) == ["579"]
      assert changed(template, old, %{}) == [nil]
      assert changed(template, old, %{map: true}) == ["579"]
      assert changed(template, new_augmented, old) == [nil]
      assert changed(template, new_changed_foo, old) == ["777"]
      assert changed(template, new_changed_bar, old) == ["777"]
    end

    test "map access with non existing key" do
      template = "<%= @map[:baz] || \"default\" %>"
      old = %{map: %{foo: 123, bar: 456}}
      new_augmented = %{map: %{foo: 123, bar: 456, baz: 789}}
      new_changed_foo = %{map: %{foo: 321, bar: 456}}
      new_changed_bar = %{map: %{foo: 123, bar: 654}}
      assert changed(template, old, nil) == ["default"]
      assert changed(template, old, %{}) == [nil]
      assert changed(template, old, %{map: true}) == ["default"]
      assert changed(template, new_augmented, old) == ["789"]
      # no re-render when the key is still not present
      assert changed(template, new_changed_foo, old) == [nil]
      assert changed(template, new_changed_bar, old) == [nil]
    end

    test "renders dynamic with access tracking for forms" do
      form1 = Phoenix.Component.to_form(%{"foo" => "bar"})
      form2 = Phoenix.Component.to_form(%{"foo" => "bar", "baz" => "bat"})
      form3 = Phoenix.Component.to_form(%{"foo" => "baz"})

      template = "<%= Map.fetch!(@form[:foo], :value) %>"
      assert changed(template, %{form: form1}, nil) == ["bar"]

      template = "<%= Map.fetch!(@form[:foo], :value) %>"
      assert changed(template, %{form: form1}, %{}) == [nil]
      assert changed(template, %{form: form1}, %{form: form1}) == [nil]
      assert changed(template, %{form: form2}, %{form: form1}) == [nil]
      assert changed(template, %{form: form3}, %{form: form1}) == ["baz"]
    end

    test "handles _unused_ parameter changing for forms" do
      form1 = Phoenix.Component.to_form(%{"foo" => "bar", "_unused_foo" => ""})
      form2 = Phoenix.Component.to_form(%{"foo" => "bar"})

      template = "<%= Map.fetch!(@form[:foo], :value) %>"
      assert changed(template, %{form: form1}, nil) == ["bar"]

      template = "<%= Map.fetch!(@form[:foo], :value) %>"
      assert changed(template, %{form: form1}, %{}) == [nil]
      assert changed(template, %{form: form1}, %{form: form1}) == [nil]
      assert changed(template, %{form: form2}, %{form: form1}) == ["bar"]
    end

    test "renders dynamic with access tracking inside comprehension" do
      template = """
      <%= for x <- [:a, :b, :c] do %>
        <%= @map[x] %>
      <% end %>
      """

      old = %{map: [a: 1, b: 2, c: 3]}
      assert [%Phoenix.LiveView.Comprehension{}] = changed(template, old, nil)
      assert [nil] = changed(template, old, %{})
      assert [%Phoenix.LiveView.Comprehension{}] = changed(template, old, %{map: true})
      assert [%Phoenix.LiveView.Comprehension{}] = changed(template, old, old)
    end

    test "renders dynamic if it has variables" do
      template = "<%= foo = 1 + 2 %><%= foo %>"
      assert changed(template, %{}, nil) == ["3", "3"]
      assert changed(template, %{}, %{}) == ["3", "3"]
    end

    test "does not render dynamic if it has variables on the right side of the pipe" do
      template = "<%= @foo |> Kernel.+(@bar) |> is_integer %>"
      assert changed(template, %{foo: 1, bar: 2}, nil) == ["true"]
      assert changed(template, %{foo: 1, bar: 2}, %{}) == [nil]
      assert changed(template, %{foo: 1, bar: 2}, %{foo: true}) == ["true"]
      assert changed(template, %{foo: 1, bar: 2}, %{bar: true}) == ["true"]

      template = "<%= @foo |> is_integer |> is_boolean %>"
      assert changed(template, %{foo: 1}, nil) == ["true"]
      assert changed(template, %{foo: 1}, %{}) == [nil]
      assert changed(template, %{foo: 1}, %{foo: true}) == ["true"]
    end

    test "does not render dynamic for special variables" do
      template = "<%= __MODULE__ %>"
      assert changed(template, %{}, nil) == [""]
      assert changed(template, %{}, %{}) == [nil]
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

    test "does not render dynamic if it has variables as comprehension generators" do
      template = "<%= for x <- foo do %><%= x %><% end %>"

      rendered = eval(template, %{__changed__: nil}, foo: [1, 2, 3])
      assert [%{entries: [["1"], ["2"], ["3"]]}] = expand_dynamic(rendered.dynamic, true)

      rendered = eval(template, %{__changed__: %{}}, foo: [1, 2, 3])
      assert [%{entries: [["1"], ["2"], ["3"]]}] = expand_dynamic(rendered.dynamic, true)
    end

    test "does not render dynamic if it has variables inside optimized comprehension" do
      template = "<%= for foo <- @foo do %><%= foo %><% end %>"

      assert [%{entries: [["1"], ["2"], ["3"]]}] = changed(template, %{foo: ["1", "2", "3"]}, nil)

      assert [nil] = changed(template, %{foo: ["1", "2", "3"]}, %{})

      assert [%{entries: [["1"], ["2"], ["3"]]}] =
               changed(template, %{foo: ["1", "2", "3"]}, %{foo: true})
    end

    test "does not render dynamic if it has a variable after a condition inside optimized comprehension" do
      template =
        "<%= for foo <- @foo do %><%= if foo == @selected, do: ~s(selected) %><%= foo %><% end %>"

      assert [%{entries: [["", "1"], ["selected", "2"], ["", "3"]]}] =
               changed(template, %{foo: ["1", "2", "3"], selected: "2"}, nil)

      assert [nil] = changed(template, %{foo: ["1", "2", "3"], selected: "2"}, %{})

      assert [%{entries: [["", "1"], ["selected", "2"], ["", "3"]]}] =
               changed(template, %{foo: ["1", "2", "3"], selected: "2"}, %{foo: true})
    end

    test "does not render dynamic for nested optimized comprehensions with variables" do
      template =
        "<%= for x <- @foo do %>X: <%= for y <- @bar do %>Y: <%= x %><%= y %><% end %><% end %>"

      assert [
               %{
                 entries: [
                   [%{entries: [["1", "1"]], static: ["Y: ", "", ""]}]
                 ],
                 static: ["X: ", ""]
               }
             ] = changed(template, %{foo: [1], bar: [1]}, nil)

      assert [nil] = changed(template, %{foo: [1], bar: [1]}, %{})

      assert [
               %{
                 entries: [
                   [%{entries: [["1", "1"]], static: ["Y: ", "", ""]}]
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
                 entries: [
                   [%{entries: [["1", "1"]], static: ["", "", ""]}]
                 ],
                 static: ["", ""]
               }
             ] = changed(template, %{foo: [%{x: 1, bar: [%{y: 1}]}]}, %{foo: true})
    end

    test "renders dynamic if it uses assigns directly" do
      template = "<%= for _ <- [1, 2, 3], do: Map.get(assigns, :foo) %>"
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

      assert [%Rendered{dynamic: [nil], static: ["one", "two"]}] =
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

    test "converts if-do with var assignments into rendered" do
      template = "<%= if var = @foo do %>one<%= var %>two<% end %>"

      assert [%Rendered{dynamic: ["true"], static: ["one", "two"]}] =
               changed(template, %{foo: true}, nil)

      assert changed(template, %{foo: true}, %{}) == [nil]
      assert changed(template, %{foo: false}, %{foo: true}) == [""]
    end

    test "converts if-do with external var assignments into rendered but tainted" do
      template = "<%= var = @foo %><%= if var do %>one<%= var %>two<% end %>"

      assert ["true", %Rendered{dynamic: ["true"], static: ["one", "two"]}] =
               changed(template, %{foo: true}, nil)

      assert ["true", %Rendered{dynamic: ["true"], static: ["one", "two"]}] =
               changed(template, %{foo: true}, %{})

      assert ["false", ""] =
               changed(template, %{foo: false}, %{foo: true})
    end

    test "converts if-do-else into rendered with dynamic condition" do
      template = "<%= if @bar do %>one<%= @foo %>two<% else %>uno<%= @baz %>dos<% end %>"

      # bar = true
      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: true, baz: 456}, %{})

      assert [%Rendered{dynamic: [nil], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true, baz: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: [nil], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true})

      assert [%Rendered{dynamic: [nil], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{baz: true})

      # bar = false
      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: false, baz: 456}, %{})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true, bar: true})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
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

    test "converts if-do if-do with var assignment into rendered" do
      template = "<%= if var = @foo do %>one<%= if var do %>uno<%= var %>dos<% end %>two<% end %>"

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

    test "converts unless-do into rendered" do
      template = "<%= unless false do %>one<%= @foo %>two<% end %>"

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, %{foo: true})
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

    test "converts case into rendered with vars in head" do
      template = "<%= case true do %><% x when x == true -> %>one<%= @foo %>two<% end %>"

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, %{foo: true})

      template = "<%= case @foo do %><% x -> %>one<%= x %>two<% end %>"

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"]}] =
               changed(template, %{foo: 123}, %{foo: true})
    end

    test "converts case into rendered with vars in head and body" do
      template = "<%= case 456 do %><% x -> %>one<%= @foo %>two<%= x %>three<% end %>"

      assert [%Rendered{dynamic: ["123", "456"], static: ["one", "two", "three"]}] =
               changed(template, %{foo: 123}, nil)

      assert changed(template, %{foo: 123}, %{}) ==
               [nil]

      assert [%Rendered{dynamic: ["123", "456"], static: ["one", "two", "three"]}] =
               changed(template, %{foo: 123}, %{foo: true})

      template = "<%= case @bar do %><% x -> %>one<%= @foo %>two<%= x %>three<% end %>"

      assert [%Rendered{dynamic: ["123", "456"], static: ["one", "two", "three"]}] =
               changed(template, %{foo: 123, bar: 456}, nil)

      assert changed(template, %{foo: 123, bar: 456}, %{}) ==
               [nil]

      assert [%Rendered{dynamic: ["123", "456"], static: ["one", "two", "three"]}] =
               changed(template, %{foo: 123, bar: 456}, %{foo: true})

      assert [%Rendered{dynamic: [nil, "456"], static: ["one", "two", "three"]}] =
               changed(template, %{foo: 123, bar: 456}, %{bar: true})
    end

    test "converts multiple case into rendered with dynamic condition" do
      template =
        "<%= case @bar do %><% true -> %>one<%= @foo %>two<% false -> %>uno<%= @baz %>dos<% end %>"

      # bar = true
      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: true, baz: 456}, %{})

      assert [%Rendered{dynamic: [nil], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true, baz: true})

      assert [%Rendered{dynamic: ["123"], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: [nil], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{bar: true})

      assert [%Rendered{dynamic: [nil], static: ["one", "two"], fingerprint: ^fptrue}] =
               changed(template, %{foo: 123, bar: true, baz: 456}, %{baz: true})

      # bar = false
      assert [%Rendered{dynamic: ["456"], static: ["uno", "dos"], fingerprint: fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, nil)

      assert [nil] = changed(template, %{foo: 123, bar: false, baz: 456}, %{})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true, bar: true})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
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

    test "converts case with for into rendered" do
      template = "<%= case @foo do %><% val -> %><%= for i <- val do %><%= i %><% end %><% end %>"

      assert [
               %Phoenix.LiveView.Rendered{
                 dynamic: [
                   %Phoenix.LiveView.Comprehension{
                     static: ["", ""],
                     entries: [["1"], ["2"], ["3"]]
                   }
                 ],
                 static: ["", ""]
               }
             ] = changed(template, %{foo: 1..3}, nil)

      assert changed(template, %{foo: 1..3}, %{}) ==
               [nil]

      assert [
               %Phoenix.LiveView.Rendered{
                 dynamic: [
                   %Phoenix.LiveView.Comprehension{
                     static: ["", ""],
                     entries: [["1"], ["2"], ["3"]]
                   }
                 ],
                 static: ["", ""]
               }
             ] = changed(template, %{foo: 1..3}, %{foo: true})
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

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true, bar: true})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
               changed(template, %{foo: 123, bar: false, baz: 456}, %{foo: true})

      assert [%Rendered{dynamic: [nil], static: ["uno", "dos"], fingerprint: ^fpfalse}] =
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

  describe "mark_variables_ast_change_tracked/1" do
    test "ignores pinned variables and binary modifiers" do
      ast =
        quote do
          %{foo: foo, bar: ^bar, bin: <<thebin::binary>>, other: other}
        end

      assert {new_ast, variables} = Engine.mark_variables_as_change_tracked(ast, %{})
      assert map_size(variables) == 3

      assert %{
               foo: {:foo, [change_track: true], _},
               other: {:other, [change_track: true], _},
               thebin: {:thebin, [change_track: true], _}
             } = variables

      assert new_ast != ast
    end
  end

  describe "slots" do
    import Phoenix.Component, only: [sigil_H: 2]

    defp component(assigns) do
      %{inner_block: [%{inner_block: slot}]} = assigns
      throw(slot)
    end

    test "slots with no dynamics represented as rendered struct" do
      try do
        assigns = %{}

        %Phoenix.LiveView.Rendered{dynamic: dynamic} =
          ~H"<.component>No dynamics</.component>"

        dynamic.(true)
      catch
        slot ->
          assert %Phoenix.LiveView.Rendered{} = slot
      else
        _ -> flunk("Should have caught")
      end
    end

    test "slots with dynamics are represented as function" do
      try do
        assigns = %{}

        %Phoenix.LiveView.Rendered{dynamic: dynamic} =
          ~H"<.component>{1234}</.component>"

        dynamic.(true)
      catch
        slot ->
          assert is_function(slot)
      else
        _ -> flunk("Should have caught")
      end
    end
  end

  defp eval(string, assigns \\ %{}, binding \\ []) do
    EEx.eval_string(string, [assigns: assigns] ++ binding, file: __ENV__.file, engine: Engine)
  end

  defp changed(string, assigns, changed, track_changes? \\ true) do
    %{dynamic: dynamic} = eval(string, Map.put(assigns, :__changed__, changed))
    expand_dynamic(dynamic, track_changes?)
  end

  defp expand_dynamic(dynamic, track_changes?) do
    Enum.map(dynamic.(track_changes?), &expand_rendered(&1, track_changes?))
  end

  defp expand_rendered(%Rendered{} = rendered, track_changes?) do
    update_in(rendered.dynamic, &expand_dynamic(&1, track_changes?))
  end

  defp expand_rendered(%Comprehension{entries: entries} = comprehension, track_changes?) do
    expanded_entries =
      Enum.map(entries, fn {_key, _vars, render} ->
        # for simplicity, we don't care about vars_changed here
        Enum.map(render.(nil, track_changes?), &expand_rendered(&1, track_changes?))
      end)

    %{comprehension | entries: expanded_entries}
  end

  defp expand_rendered(other, _track_changes), do: other

  defp render(string, assigns \\ %{}) do
    string
    |> eval(assigns)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end

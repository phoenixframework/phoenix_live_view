defmodule Phoenix.LiveView.TagEngine.TokenizerTest do
  use ExUnit.Case, async: true
  alias Phoenix.LiveView.TagEngine.Tokenizer.ParseError
  alias Phoenix.LiveView.TagEngine.Tokenizer

  defp tokenizer_state(text), do: Tokenizer.init(0, "nofile", text, Phoenix.LiveView.HTMLEngine)

  defp tokenize(text) do
    Tokenizer.tokenize(text, [], [], {:text, :enabled}, tokenizer_state(text))
    |> elem(0)
    |> Enum.reverse()
  end

  describe "text" do
    test "represented as {:text, value}" do
      assert tokenize("Hello") == [{:text, "Hello", %{line_end: 1, column_end: 6}}]
    end

    test "with multiple lines" do
      tokens =
        tokenize("""
        first
        second
        third
        """)

      assert tokens == [{:text, "first\nsecond\nthird\n", %{line_end: 4, column_end: 1}}]
    end

    test "keep line breaks unchanged" do
      assert tokenize("first\nsecond\r\nthird") == [
               {:text, "first\nsecond\r\nthird", %{line_end: 3, column_end: 6}}
             ]
    end
  end

  describe "doctype" do
    test "generated as text" do
      assert tokenize("<!doctype html>") == [
               {:text, "<!doctype html>", %{line_end: 1, column_end: 16}}
             ]
    end

    test "multiple lines" do
      assert tokenize("<!DOCTYPE\nhtml\n>  <br />") == [
               {:text, "<!DOCTYPE\nhtml\n>  ", %{line_end: 3, column_end: 4}},
               {:tag, "br", [],
                %{column: 4, line: 3, closing: :void, tag_name: "br", inner_location: {3, 10}}}
             ]
    end

    test "incomplete" do
      assert_raise ParseError, ~r/unexpected end of string inside tag/, fn ->
        tokenize("<!doctype html")
      end
    end
  end

  describe "comment" do
    test "generated as text" do
      assert tokenize("Begin<!-- comment -->End") == [
               {:text, "Begin<!-- comment -->End",
                %{line_end: 1, column_end: 25, context: [:comment_start, :comment_end]}}
             ]
    end

    test "followed by curly" do
      assert tokenize("<!-- comment -->{hello}text") == [
               {:text, "<!-- comment -->",
                %{column_end: 17, context: [:comment_start, :comment_end], line_end: 1}},
               {:body_expr, "hello", %{line: 1, column: 17}},
               {:text, "text", %{line_end: 1, column_end: 28}}
             ]
    end

    test "multiple lines and wrapped by tags" do
      code = """
      <p>
      <!--
      <div>
      -->
      </p><br>\
      """

      assert [
               {:tag, "p", [], %{line: 1, column: 1}},
               {:text, "\n<!--\n<div>\n-->\n", %{line_end: 5, column_end: 1}},
               {:close, :tag, "p", %{line: 5, column: 1}},
               {:tag, "br", [], %{line: 5, column: 5}}
             ] = tokenize(code)
    end

    test "adds comment_start and comment_end" do
      first_part = """
      <p>
      <!--
      <div>
      """

      {first_tokens, cont} =
        Tokenizer.tokenize(first_part, [], [], {:text, :enabled}, tokenizer_state(first_part))

      second_part = """
      </div>
      -->
      </p>
      <div>
        <p>Hello</p>
      </div>
      """

      {tokens, {:text, :enabled}} =
        Tokenizer.tokenize(second_part, [], first_tokens, cont, tokenizer_state(second_part))

      assert Enum.reverse(tokens) == [
               {:tag, "p", [], %{column: 1, line: 1, inner_location: {1, 4}, tag_name: "p"}},
               {:text, "\n<!--\n<div>\n",
                %{column_end: 1, context: [:comment_start], line_end: 4}},
               {:text, "</div>\n-->\n", %{column_end: 1, context: [:comment_end], line_end: 3}},
               {:close, :tag, "p", %{column: 1, line: 3, inner_location: {3, 1}, tag_name: "p"}},
               {:text, "\n", %{column_end: 1, line_end: 4}},
               {:tag, "div", [], %{column: 1, line: 4, inner_location: {4, 6}, tag_name: "div"}},
               {:text, "\n  ", %{column_end: 3, line_end: 5}},
               {:tag, "p", [], %{column: 3, line: 5, inner_location: {5, 6}, tag_name: "p"}},
               {:text, "Hello", %{column_end: 11, line_end: 5}},
               {:close, :tag, "p",
                %{column: 11, line: 5, inner_location: {5, 11}, tag_name: "p"}},
               {:text, "\n", %{column_end: 1, line_end: 6}},
               {:close, :tag, "div",
                %{column: 1, line: 6, inner_location: {6, 1}, tag_name: "div"}},
               {:text, "\n", %{column_end: 1, line_end: 7}}
             ]
    end

    test "two comments in a row" do
      first_part = """
      <p>
      <!--
      <%= "Hello" %>
      """

      {first_tokens, cont} =
        Tokenizer.tokenize(first_part, [], [], {:text, :enabled}, tokenizer_state(first_part))

      second_part = """
      -->
      <!--
      <p><%= "World"</p>
      """

      {second_tokens, cont} =
        Tokenizer.tokenize(second_part, [], first_tokens, cont, tokenizer_state(second_part))

      third_part = """
      -->
      <div>
        <p>Hi</p>
      </p>
      """

      {tokens, {:text, :enabled}} =
        Tokenizer.tokenize(third_part, [], second_tokens, cont, tokenizer_state(third_part))

      assert Enum.reverse(tokens) == [
               {:tag, "p", [], %{column: 1, line: 1, inner_location: {1, 4}, tag_name: "p"}},
               {:text, "\n<!--\n<%= \"Hello\" %>\n",
                %{column_end: 1, context: [:comment_start], line_end: 4}},
               {:text, "-->\n<!--\n<p><%= \"World\"</p>\n",
                %{column_end: 1, context: [:comment_end, :comment_start], line_end: 4}},
               {:text, "-->\n", %{column_end: 1, context: [:comment_end], line_end: 2}},
               {:tag, "div", [], %{column: 1, line: 2, inner_location: {2, 6}, tag_name: "div"}},
               {:text, "\n  ", %{column_end: 3, line_end: 3}},
               {:tag, "p", [], %{column: 3, line: 3, inner_location: {3, 6}, tag_name: "p"}},
               {:text, "Hi", %{column_end: 8, line_end: 3}},
               {:close, :tag, "p", %{column: 8, line: 3, inner_location: {3, 8}, tag_name: "p"}},
               {:text, "\n", %{column_end: 1, line_end: 4}},
               {:close, :tag, "p", %{column: 1, line: 4, inner_location: {4, 1}, tag_name: "p"}},
               {:text, "\n", %{column_end: 1, line_end: 5}}
             ]
    end
  end

  describe "opening tag" do
    test "represented as {:tag, name, attrs, meta}" do
      tokens = tokenize("<div>")
      assert [{:tag, "div", [], %{}}] = tokens
    end

    test "with space after name" do
      tokens = tokenize("<div >")
      assert [{:tag, "div", [], %{}}] = tokens
    end

    test "with line break after name" do
      tokens = tokenize("<div\n>")
      assert [{:tag, "div", [], %{}}] = tokens
    end

    test "self close" do
      tokens = tokenize("<div/>")
      assert [{:tag, "div", [], %{closing: :self}}] = tokens
    end

    test "compute line and column" do
      tokens =
        tokenize("""
        <div>
          <span>

        <p/><br>\
        """)

      assert [
               {:tag, "div", [], %{line: 1, column: 1}},
               {:text, _, %{line_end: 2, column_end: 3}},
               {:tag, "span", [], %{line: 2, column: 3}},
               {:text, _, %{line_end: 4, column_end: 1}},
               {:tag, "p", [], %{column: 1, line: 4, closing: :self}},
               {:tag, "br", [], %{column: 5, line: 4}}
             ] = tokens
    end

    test "raise on missing/incomplete tag name" do
      message = """
      nofile:2:4: expected tag name after <. If you meant to use < as part of a text, use &lt; instead
        |
      1 | <div>
      2 |   <>
        |    ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("""
        <div>
          <>\
        """)
      end

      message = """
      nofile:1:2: expected tag name after <. If you meant to use < as part of a text, use &lt; instead
        |
      1 | <
        |  ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("<")
      end

      message = """
      nofile:1:2: a component name is required after .
        |
      1 | <./typo>
        |  ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("<./typo>")
      end

      assert_raise ParseError, ~r"nofile:1:5: expected closing `>` or `/>`", fn ->
        tokenize("<foo")
      end
    end
  end

  describe "attributes" do
    test "represented as a list of {name, tuple | nil, meta}, where tuple is the {type, value}" do
      attrs = tokenize_attrs(~S(<div class="panel" style={@style} hidden>))

      assert [
               {"class", {:string, "panel", %{}}, %{column: 6, line: 1}},
               {"style", {:expr, "@style", %{}}, %{column: 20, line: 1}},
               {"hidden", nil, %{column: 35, line: 1}}
             ] = attrs
    end

    test "accepts space between the name and `=`" do
      attrs = tokenize_attrs(~S(<div class ="panel">))

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "accepts line breaks between the name and `=`" do
      attrs = tokenize_attrs("<div class\n=\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs

      attrs = tokenize_attrs("<div class\r\n=\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "accepts space between `=` and the value" do
      attrs = tokenize_attrs(~S(<div class= "panel">))

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "accepts line breaks between `=` and the value" do
      attrs = tokenize_attrs("<div class=\n\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs

      attrs = tokenize_attrs("<div class=\r\n\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "raise on incomplete attribute" do
      message = """
      nofile:1:11: unexpected end of string inside tag
        |
      1 | <div class
        |           ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("<div class")
      end
    end

    test "raise on missing value" do
      message = """
      nofile:2:9: invalid attribute value after `=`. Expected either a value between quotes (such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)
        |
      1 | <div
      2 |   class=>
        |         ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("""
        <div
          class=>\
        """)
      end

      message = """
      nofile:1:13: invalid attribute value after `=`. Expected either a value between quotes (such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)
        |
      1 | <div class= >
        |             ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize(~S(<div class= >))
      end

      message = """
      nofile:1:12: invalid attribute value after `=`. Expected either a value between quotes (such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)
        |
      1 | <div class=
        |            ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("<div class=")
      end
    end

    test "raise on missing attribute name" do
      message = """
      nofile:2:8: expected attribute name
        |
      1 | <div>
      2 |   <div =\"panel\">
        |        ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("""
        <div>
          <div ="panel">\
        """)
      end

      message = """
      nofile:1:6: expected attribute name
        |
      1 | <div = >
        |      ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize(~S(<div = >))
      end

      message = """
      nofile:1:6: expected attribute name
        |
      1 | <div / >
        |      ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize(~S(<div / >))
      end
    end

    test "raise on attribute names with quotes" do
      message = """
      nofile:1:5: invalid character in attribute name: '
        |
      1 | <div'>
        |     ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize(~S(<div'>))
      end

      message = """
      nofile:1:5: invalid character in attribute name: \"
        |
      1 | <div">
        |     ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize(~S(<div">))
      end

      message = """
      nofile:1:10: invalid character in attribute name: '
        |
      1 | <div attr'>
        |          ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize(~S(<div attr'>))
      end

      message = """
      nofile:1:20: invalid character in attribute name: \"
        |
      1 | <div class={"test"}">
        |                    ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize(~S(<div class={"test"}">))
      end
    end

    test "raise on missing opening interpolation" do
      message = """
      nofile:1:29: expected attribute, but found end of interpolation: }
        |
      1 | <div class=\"image-container\"}>
        |                             ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize(~S(<div class="image-container"}>))
      end
    end
  end

  describe "boolean attributes" do
    test "represented as {name, nil, meta}" do
      attrs = tokenize_attrs("<div hidden>")

      assert [{"hidden", nil, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs("<div hidden selected>")

      assert [{"hidden", nil, %{}}, {"selected", nil, %{}}] = attrs
    end

    test "with space after" do
      attrs = tokenize_attrs("<div hidden >")

      assert [{"hidden", nil, %{}}] = attrs
    end

    test "in self close tag" do
      attrs = tokenize_attrs("<div hidden/>")

      assert [{"hidden", nil, %{}}] = attrs
    end

    test "in self close tag with space after" do
      attrs = tokenize_attrs("<div hidden />")

      assert [{"hidden", nil, %{}}] = attrs
    end
  end

  describe "attributes as double quoted string" do
    test "value is represented as {:string, value, meta}}" do
      attrs = tokenize_attrs(~S(<div class="panel">))

      assert [{"class", {:string, "panel", %{delimiter: ?"}}, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs(~S(<div class="panel" style="margin: 0px;">))

      assert [
               {"class", {:string, "panel", %{delimiter: ?"}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?"}}, %{}}
             ] = attrs
    end

    test "value containing single quotes" do
      attrs = tokenize_attrs(~S(<div title="i'd love to!">))

      assert [{"title", {:string, "i'd love to!", %{delimiter: ?"}}, %{}}] = attrs
    end

    test "value containing line breaks" do
      tokens =
        tokenize("""
        <div title="first
          second
        third"><span>\
        """)

      assert [
               {:tag, "div", [{"title", {:string, "first\n  second\nthird", _meta}, %{}}], %{}},
               {:tag, "span", [], %{line: 3, column: 8}}
             ] = tokens
    end

    test "raise on incomplete attribute value (EOF)" do
      assert_raise ParseError, ~r"nofile:2:15: expected closing `\"` for attribute value", fn ->
        tokenize("""
        <div
          class="panel\
        """)
      end
    end
  end

  describe "attributes as single quoted string" do
    test "value is represented as {:string, value, meta}}" do
      attrs = tokenize_attrs(~S(<div class='panel'>))

      assert [{"class", {:string, "panel", %{delimiter: ?'}}, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs(~S(<div class='panel' style='margin: 0px;'>))

      assert [
               {"class", {:string, "panel", %{delimiter: ?'}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?'}}, %{}}
             ] = attrs
    end

    test "value containing double quotes" do
      attrs = tokenize_attrs(~S(<div title='Say "hi!"'>))

      assert [{"title", {:string, ~S(Say "hi!"), %{delimiter: ?'}}, %{}}] = attrs
    end

    test "value containing line breaks" do
      tokens =
        tokenize("""
        <div title='first
          second
        third'><span>\
        """)

      assert [
               {:tag, "div", [{"title", {:string, "first\n  second\nthird", _meta}, %{}}], %{}},
               {:tag, "span", [], %{line: 3, column: 8}}
             ] = tokens
    end

    test "raise on incomplete attribute value (EOF)" do
      assert_raise ParseError, ~r"nofile:2:15: expected closing `\'` for attribute value", fn ->
        tokenize("""
        <div
          class='panel\
        """)
      end
    end
  end

  describe "attributes as expressions" do
    test "value is represented as {:expr, value, meta}" do
      attrs = tokenize_attrs(~S(<div class={@class}>))

      assert [{"class", {:expr, "@class", %{line: 1, column: 13}}, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs(~S(<div class={@class} style={@style}>))

      assert [
               {"class", {:expr, "@class", %{}}, %{}},
               {"style", {:expr, "@style", %{}}, %{}}
             ] = attrs
    end

    test "double quoted strings inside expression" do
      attrs = tokenize_attrs(~S(<div class={"text"}>))

      assert [{"class", {:expr, ~S("text"), %{}}, %{}}] = attrs
    end

    test "value containing curly braces" do
      attrs = tokenize_attrs(~S(<div class={ [{:active, @active}] }>))

      assert [{"class", {:expr, " [{:active, @active}] ", %{}}, %{}}] = attrs
    end

    test "ignore escaped curly braces inside elixir strings" do
      attrs = tokenize_attrs(~S(<div class={"\{hi"}>))

      assert [{"class", {:expr, ~S("\{hi"), %{}}, %{}}] = attrs

      attrs = tokenize_attrs(~S(<div class={"hi\}"}>))

      assert [{"class", {:expr, ~S("hi\}"), %{}}, %{}}] = attrs
    end

    test "compute line and columns" do
      attrs =
        tokenize_attrs("""
        <div
          class={@class}
            style={
              @style
            }
          title={@title}
        >\
        """)

      assert [
               {"class", {:expr, _, %{line: 2, column: 10}}, %{}},
               {"style", {:expr, _, %{line: 3, column: 12}}, %{}},
               {"title", {:expr, _, %{line: 6, column: 10}}, %{}}
             ] = attrs
    end

    test "raise on incomplete attribute expression (EOF)" do
      message = """
      nofile:2:9: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 | <div
      2 |   class={panel
        |         ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("""
        <div
          class={panel\
        """)
      end
    end
  end

  describe "root attributes" do
    test "represented as {:root, value, meta}" do
      attrs = tokenize_attrs("<div {@attrs}>")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "with space after" do
      attrs = tokenize_attrs("<div {@attrs} >")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "with line break after" do
      attrs = tokenize_attrs("<div {@attrs}\n>")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "in self close tag" do
      attrs = tokenize_attrs("<div {@attrs}/>")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "in self close tag with space after" do
      attrs = tokenize_attrs("<div {@attrs} />")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "multiple values among other attributes" do
      attrs = tokenize_attrs("<div class={@class} {@attrs1} hidden {@attrs2}/>")

      assert [
               {"class", {:expr, "@class", %{}}, %{}},
               {:root, {:expr, "@attrs1", %{}}, %{}},
               {"hidden", nil, %{}},
               {:root, {:expr, "@attrs2", %{}}, %{}}
             ] = attrs
    end

    test "compute line and columns" do
      attrs =
        tokenize_attrs("""
        <div
          {@root1}
            {
              @root2
            }
          {@root3}
        >\
        """)

      assert [
               {:root, {:expr, "@root1", %{line: 2, column: 4}}, %{line: 2, column: 4}},
               {:root, {:expr, "\n      @root2\n    ", %{line: 3, column: 6}},
                %{line: 3, column: 6}},
               {:root, {:expr, "@root3", %{line: 6, column: 4}}, %{line: 6, column: 4}}
             ] = attrs
    end

    test "raise on incomplete expression (EOF)" do
      message = """
      nofile:2:3: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 | <div
      2 |   {@attrs
        |   ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("""
        <div
          {@attrs\
        """)
      end
    end
  end

  describe "closing tag" do
    test "represented as {:close, :tag, name, meta}" do
      tokens = tokenize("</div>")
      assert [{:close, :tag, "div", %{}}] = tokens
    end

    test "compute line and columns" do
      tokens =
        tokenize("""
        <div>
        </div><br>\
        """)

      assert [
               {:tag, "div", [], _meta},
               {:text, "\n", %{column_end: 1, line_end: 2}},
               {:close, :tag, "div", %{line: 2, column: 1}},
               {:tag, "br", [], %{line: 2, column: 7}}
             ] = tokens
    end

    test "raise on missing closing `>`" do
      message = """
      nofile:2:6: expected closing `>`
        |
      1 | <div>
      2 | </div text
        |      ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("""
        <div>
        </div text\
        """)
      end
    end

    test "raise on missing tag name" do
      message = """
      nofile:2:5: expected tag name after </
        |
      1 | <div>
      2 |   </>
        |     ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("""
        <div>
          </>\
        """)
      end
    end
  end

  describe "script" do
    test "self-closing" do
      assert tokenize("""
             <script src="foo.js" />
             """) == [
               {:tag, "script",
                [{"src", {:string, "foo.js", %{delimiter: 34}}, %{column: 9, line: 1}}],
                %{
                  column: 1,
                  line: 1,
                  closing: :self,
                  tag_name: "script",
                  inner_location: {1, 24}
                }},
               {:text, "\n", %{column_end: 1, line_end: 2}}
             ]
    end

    test "traverses until </script>" do
      assert tokenize("""
             <script>
               a = "<a>Link</a>"
             </script>
             """) == [
               {:tag, "script", [],
                %{column: 1, line: 1, inner_location: {1, 9}, tag_name: "script"}},
               {:text, "\n  a = \"<a>Link</a>\"\n", %{column_end: 1, line_end: 3}},
               {:close, :tag, "script", %{column: 1, line: 3, inner_location: {3, 1}}},
               {:text, "\n", %{column_end: 1, line_end: 4}}
             ]
    end
  end

  describe "style" do
    test "self-closing" do
      assert tokenize("""
             <style src="foo.js" />
             """) == [
               {:tag, "style",
                [{"src", {:string, "foo.js", %{delimiter: 34}}, %{column: 8, line: 1}}],
                %{
                  column: 1,
                  line: 1,
                  closing: :self,
                  inner_location: {1, 23},
                  tag_name: "style"
                }},
               {:text, "\n", %{column_end: 1, line_end: 2}}
             ]
    end

    test "traverses until </style>" do
      assert tokenize("""
             <style>
               a = "<a>Link</a>"
             </style>
             """) == [
               {:tag, "style", [],
                %{column: 1, line: 1, inner_location: {1, 8}, tag_name: "style"}},
               {:text, "\n  a = \"<a>Link</a>\"\n", %{column_end: 1, line_end: 3}},
               {:close, :tag, "style", %{column: 1, line: 3, inner_location: {3, 1}}},
               {:text, "\n", %{column_end: 1, line_end: 4}}
             ]
    end
  end

  describe "local component" do
    test "self-closing" do
      assert tokenize("""
             <.live_component module={MyApp.WeatherComponent} id="thermostat" city="Kraków" />
             """) == [
               {:local_component, "live_component",
                [
                  {"module", {:expr, "MyApp.WeatherComponent", %{line: 1, column: 26}},
                   %{line: 1, column: 18}},
                  {"id", {:string, "thermostat", %{delimiter: 34}}, %{line: 1, column: 50}},
                  {"city", {:string, "Kraków", %{delimiter: 34}}, %{line: 1, column: 66}}
                ],
                %{
                  line: 1,
                  closing: :self,
                  column: 1,
                  tag_name: ".live_component",
                  inner_location: {1, 82}
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end

    test "traverses until </.link>" do
      assert tokenize("""
             <.link href="/">Regular anchor link</.link>
             """) == [
               {:local_component, "link",
                [{"href", {:string, "/", %{delimiter: 34}}, %{line: 1, column: 8}}],
                %{line: 1, column: 1, tag_name: ".link", inner_location: {1, 17}}},
               {:text, "Regular anchor link", %{line_end: 1, column_end: 36}},
               {:close, :local_component, "link",
                %{line: 1, column: 36, tag_name: ".link", inner_location: {1, 36}}},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end
  end

  describe "remote component" do
    test "self-closing" do
      assert tokenize("""
             <MyAppWeb.CoreComponents.flash kind={:info} flash={@flash} />
             """) == [
               {
                 :remote_component,
                 "MyAppWeb.CoreComponents.flash",
                 [
                   {"kind", {:expr, ":info", %{column: 38, line: 1}}, %{column: 32, line: 1}},
                   {"flash", {:expr, "@flash", %{column: 52, line: 1}}, %{column: 45, line: 1}}
                 ],
                 %{
                   closing: :self,
                   column: 1,
                   inner_location: {1, 62},
                   line: 1,
                   tag_name: "MyAppWeb.CoreComponents.flash"
                 }
               },
               {:text, "\n", %{column_end: 1, line_end: 2}}
             ]
    end

    test "traverses until </MyAppWeb.CoreComponents.modal>" do
      assert tokenize("""
             <MyAppWeb.CoreComponents.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
               This is another modal.
             </MyAppWeb.CoreComponents.modal>
             """) == [
               {
                 :remote_component,
                 "MyAppWeb.CoreComponents.modal",
                 [
                   {"id", {:string, "confirm", %{delimiter: 34}}, %{line: 1, column: 32}},
                   {"on_cancel", {:expr, "JS.navigate(~p\"/posts\")", %{line: 1, column: 56}},
                    %{line: 1, column: 45}}
                 ],
                 %{
                   line: 1,
                   column: 1,
                   tag_name: "MyAppWeb.CoreComponents.modal",
                   inner_location: {1, 81}
                 }
               },
               {:text, "\n  This is another modal.\n", %{line_end: 3, column_end: 1}},
               {:close, :remote_component, "MyAppWeb.CoreComponents.modal",
                %{
                  line: 3,
                  column: 1,
                  tag_name: "MyAppWeb.CoreComponents.modal",
                  inner_location: {3, 1}
                }},
               {:text, "\n", %{line_end: 4, column_end: 1}}
             ]
    end
  end

  describe "reserved component" do
    test "raise on using reserved slot :inner_block" do
      message = """
      nofile:1:2: the slot name :inner_block is reserved
        |
      1 | <:inner_block>Inner</:inner_block>
        |  ^\
      """

      assert_raise ParseError, message, fn ->
        tokenize("<:inner_block>Inner</:inner_block>")
      end
    end
  end

  test "mixing text and tags" do
    tokens =
      tokenize("""
      text before
      <div>
        text
      </div>
      text after
      """)

    assert [
             {:text, "text before\n", %{line_end: 2, column_end: 1}},
             {:tag, "div", [], %{}},
             {:text, "\n  text\n", %{line_end: 4, column_end: 1}},
             {:close, :tag, "div", %{line: 4, column: 1}},
             {:text, "\ntext after\n", %{line_end: 6, column_end: 1}}
           ] = tokens
  end

  defp tokenize_attrs(code) do
    [{:tag, "div", attrs, %{}}] = tokenize(code)
    attrs
  end
end

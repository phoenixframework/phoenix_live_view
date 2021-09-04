defmodule Phoenix.LiveView.HTMLEngineTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView.Helpers, only: [sigil_H: 2, render_block: 1, render_block: 2]

  alias Phoenix.LiveView.HTMLEngine
  alias Phoenix.LiveView.HTMLTokenizer.ParseError

  defp eval(string, assigns \\ %{}, opts \\ []) do
    opts =
      Keyword.merge(opts,
        file: __ENV__.file,
        engine: HTMLEngine,
        subengine: Phoenix.LiveView.Engine
      )

    EEx.eval_string(string, [assigns: assigns], opts)
  end

  defp render(string, assigns \\ %{}) do
    string
    |> eval(assigns)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defmacrop compile(string) do
    quote do
      unquote(EEx.compile_string(string, file: __ENV__.file, engine: HTMLEngine))
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()
    end
  end

  def assigns_component(assigns) do
    ~H"<%= inspect(Map.delete(assigns, :__changed__)) %>"
  end

  def remote_function_component(assigns) do
    ~H"REMOTE COMPONENT: Value: <%= @value %>"
  end

  def remote_function_component_with_inner_content(assigns) do
    ~H"REMOTE COMPONENT: Value: <%= @value %>, Content: <%= render_block(@inner_block) %>"
  end

  def remote_function_component_with_inner_content_args(assigns) do
    ~H"""
    REMOTE COMPONENT WITH ARGS: Value: <%= @value %>
    <%= render_block(@inner_block, %{
      downcase: String.downcase(@value),
      upcase: String.upcase(@value)
    }) %>
    """
  end

  defp local_function_component(assigns) do
    ~H"LOCAL COMPONENT: Value: <%= @value %>"
  end

  defp local_function_component_with_inner_content(assigns) do
    ~H"LOCAL COMPONENT: Value: <%= @value %>, Content: <%= render_block(@inner_block) %>"
  end

  defp local_function_component_with_inner_content_args(assigns) do
    ~H"""
    LOCAL COMPONENT WITH ARGS: Value: <%= @value %>
    <%= render_block(@inner_block, %{
      downcase: String.downcase(@value),
      upcase: String.upcase(@value)
    }) %>
    """
  end

  test "handles text" do
    assert render("Hello") == "Hello"
  end

  test "handles regular blocks" do
    assert render("""
           Hello <%= if true do %>world!<% end %>
           """) == "Hello world!\n"
  end

  test "handles html blocks with regular blocks" do
    assert render("""
           Hello <omg>w<%= if true do %>orld<% end %>!</omg>
           """) == "Hello <omg>world!</omg>\n"
  end

  test "handles string attributes" do
    assert render("""
           Hello <omg name="my name" phone="111">text</omg>
           """) == "Hello <omg name=\"my name\" phone=\"111\">text</omg>\n"
  end

  test "handles string attribute value keeping special chars unchanged" do
    assert render("<omg name='1 < 2'/>") == "<omg name='1 < 2'/>"
  end

  test "handles boolean attributes" do
    assert render("""
           Hello <omg hidden>text</omg>
           """) == "Hello <omg hidden>text</omg>\n"
  end

  test "handles interpolated attributes" do
    assert render("""
           Hello <omg name={to_string(123)} phone={to_string(456)}>text</omg>
           """) == "Hello <omg name=\"123\" phone=\"456\">text</omg>\n"
  end

  test "handles interpolated attribute value containing special chars" do
    assert render("<omg name={@val}/>", %{val: "1 < 2"}) == "<omg name=\"1 &lt; 2\"/>"
  end

  test "handles interpolated attributes with strings" do
    assert render("""
           <omg name={String.upcase("abc")}>text</omg>
           """) == "<omg name=\"ABC\">text</omg>\n"
  end

  test "handles interpolated attributes with curly braces" do
    assert render("""
           <omg name={elem({"abc"}, 0)}>text</omg>
           """) == "<omg name=\"abc\">text</omg>\n"
  end

  test "handles dynamic attributes" do
    assert render("Hello <omg {@attrs}>text</omg>", %{attrs: [name: "1", phone: to_string(2)]}) ==
             "Hello <omg name=\"1\" phone=\"2\">text</omg>"
  end

  test "sorts attributes by group: static, static_dynamic and dynamic" do
    assigns = %{attrs1: [d1: "1"], attrs2: [d2: "2"]}

    assert render(~S(<omg {@attrs1} sd1={1} s1="1" {@attrs2} sd2={2} s2="2" />), assigns) ==
             ~S(<omg s1="1" s2="2" sd1="1" sd2="2" d1="1" d2="2"/>)
  end

  test "handle void elements" do
    assert render("""
           <omg><br></omg>\
           """) == "<omg><br></omg>"
  end

  test "handle void elements with attributes" do
    assert render("""
           <omg><br attr='1'></omg>\
           """) == "<omg><br attr='1'></omg>"
  end

  test "handle self close elements" do
    assert render("<omg/>") == "<omg/>"
  end

  test "handle self close elements with attributes" do
    assert render("<omg attr='1'/>") == "<omg attr='1'/>"
  end

  describe "handle function components" do
    test "remote call (self close)" do
      assigns = %{}

      assert compile(
               "<Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1'/>"
             ) ==
               "REMOTE COMPONENT: Value: 1"
    end

    test "remote call from alias (self close)" do
      alias Phoenix.LiveView.HTMLEngineTest
      assigns = %{}

      assert compile("<HTMLEngineTest.remote_function_component value='1'/>") ==
               "REMOTE COMPONENT: Value: 1"
    end

    test "remote call with inner content" do
      assigns = %{}

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_content value='1'>
               The inner content
             </Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_content>
             """) == "REMOTE COMPONENT: Value: 1, Content: \n  The inner content\n\n"
    end

    test "remote call with inner content with args" do
      expected = """
      REMOTE COMPONENT WITH ARGS: Value: aBcD

        Upcase: ABCD
        Downcase: abcd
      """

      assigns = %{}

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_content_args
               value="aBcD"
               let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_content_args>
             """) =~ expected
    end

    test "raise on remote call with inner content passing non-matching args" do
      message = ~r"""
      cannot match arguments sent from `render_block/2` against the pattern in `let`.

      Expected a value matching `%{wrong: _}`, got: `%{downcase: "abcd", upcase: "ABCD"}`.
      """

      assigns =%{}

      assert_raise(RuntimeError, message, fn ->
        compile("""
        <Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_content_args
          {[value: "aBcD"]}
          let={%{wrong: _}}
        >
          ...
        </Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_content_args>
        """)
      end)
    end

    test "raise on remote call passing args to self close components" do
      message = ~r".exs:2: cannot use `let` on a component without inner content"

      assert_raise(CompileError, message, fn ->
        eval("""
        <br>
        <Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1' let={var}/>
        """)
      end)
    end

    test "local call (self close)" do
      assigns = %{}

      assert compile("<.local_function_component value='1'/>") ==
               "LOCAL COMPONENT: Value: 1"
    end

    test "local call with inner content" do
      assigns = %{}

      assert compile("""
             <.local_function_component_with_inner_content value='1'>
               The inner content
             </.local_function_component_with_inner_content>
             """) == "LOCAL COMPONENT: Value: 1, Content: \n  The inner content\n\n"
    end

    test "local call with inner content with args" do
      expected = """
      LOCAL COMPONENT WITH ARGS: Value: aBcD

        Upcase: ABCD
        Downcase: abcd
      """

      assigns = %{}

      assert compile("""
             <.local_function_component_with_inner_content_args
               value="aBcD"
               let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </.local_function_component_with_inner_content_args>
             """) =~ expected

      assert compile("""
             <.local_function_component_with_inner_content_args
               {[value: "aBcD"]}
               let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </.local_function_component_with_inner_content_args>
             """) =~ expected
    end

    test "raise on local call with inner content passing non-matching args" do
      message = ~r"""
      cannot match arguments sent from `render_block/2` against the pattern in `let`.

      Expected a value matching `%{wrong: _}`, got: `%{downcase: "abcd", upcase: "ABCD"}`.
      """

      assigns =%{}

      assert_raise(RuntimeError, message, fn ->
        compile("""
        <.local_function_component_with_inner_content_args
          {[value: "aBcD"]}
          let={%{wrong: _}}
        >
          ...
        </.local_function_component_with_inner_content_args>
        """)
      end)
    end

    test "raise on local call passing args to self close components" do
      message = ~r".exs:2: cannot use `let` on a component without inner content"

      assert_raise(CompileError, message, fn ->
        eval("""
        <br>
        <.local_function_component value='1' let={var}/>
        """)
      end)
    end

    test "raise on duplicated `let`" do
      message = ~r".exs:4:(8:)? cannot define multiple `let` attributes. Another `let` has already been defined at line 3"

      assert_raise(SyntaxError, message, fn ->
        eval("""
        <br>
        <Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1'
          let={var1}
          let={var2}
        />
        """)
      end)

      assert_raise(SyntaxError, message, fn ->
        eval("""
        <br>
        <.local_function_component value='1'
          let={var1}
          let={var2}
        />
        """)
      end)
    end

    test "empty attributes" do
      assigns = %{}
      assert compile("<.assigns_component />") == "%{}"
    end

    test "dynamic attributes" do
      assigns = %{attrs: [name: "1", phone: true]}

      assert compile("<.assigns_component {@attrs} />") ==
               "%{name: &quot;1&quot;, phone: true}"
    end

    test "sorts attributes by group: static + dynamic" do
      assigns = %{attrs1: [d1: "1"], attrs2: [d2: "2", d3: "3"]}

      assert compile(
               "<.assigns_component d1=\"one\" {@attrs1} d=\"middle\" {@attrs2} d2=\"two\" />"
             ) ==
               "%{d: &quot;middle&quot;, d1: &quot;one&quot;, d2: &quot;two&quot;, d3: &quot;3&quot;}"
    end
  end

  describe "tracks root" do
    test "valid cases" do
      assert eval("<foo></foo>").root == true
      assert eval("<foo><%= 123 %></foo>").root == true
      assert eval("<foo><bar></bar></foo>").root == true
      assert eval("<foo><br /></foo>").root == true

      assert eval("<foo />").root == true
      assert eval("<br />").root == true
      assert eval("<br>").root == true

      assert eval("  <foo></foo>  ").root == true
      assert eval("\n\n<foo></foo>\n\n").root == true
    end

    test "invalid cases" do
      assert eval("").root == false
      assert eval("<foo></foo><bar></bar>").root == false
      assert eval("<foo></foo><bar></bar>").root == false
      assert eval("<br /><br />").root == false
      assert eval("<%= 123 %>").root == false
      assert eval("<foo></foo><%= 123 %>").root == false
      assert eval("<%= 123 %><foo></foo>").root == false
      assert eval("123<foo></foo>").root == false
      assert eval("<foo></foo>123").root == false
      assert eval("<.to_string />").root == false
      assert eval("<.to_string></.to_string>").root == false
      assert eval("<Kernel.to_string />").root == false
      assert eval("<Kernel.to_string></Kernel.to_string>").root == false
    end
  end

  describe "tag validations" do
    test "unmatched open/close tags" do
      message = ~r".exs:4:(1:)? unmatched closing tag. Expected </div> for <div> at line 2, got: </span>"

      assert_raise(SyntaxError, message, fn ->
        eval("""
        <br>
        <div>
         text
        </span>
        """)
      end)
    end

    test "unmatched open/close tags with nested tags" do
      message = ~r".exs:6:(1:)? unmatched closing tag. Expected </div> for <div> at line 2, got: </span>"

      assert_raise(SyntaxError, message, fn ->
        eval("""
        <br>
        <div>
          <p>
            text
          </p>
        </span>
        """)
      end)
    end

    test "missing open tag" do
      message = ~r".exs:2:(3:)? missing opening tag for </span>"

      assert_raise(SyntaxError, message, fn ->
        eval("""
        text
          </span>
        """)
      end)
    end

    test "missing closing tag" do
      message = ~r/.exs:2:(1:)? end of file reached without closing tag for <div>/

      assert_raise(SyntaxError, message, fn ->
        eval("""
        <br>
        <div foo={@foo}>
        """)
      end)

      message = ~r/.exs:2:(3:)? end of file reached without closing tag for <span>/

      assert_raise(SyntaxError, message, fn ->
        eval("""
        text
          <span foo={@foo}>
            text
        """)
      end)
    end

    test "invalid tag name" do
      message = ~r/.exs:2:(3:)? invalid tag <Oops>/
      assert_raise(SyntaxError, message, fn ->
        eval("""
        <br>
          <Oops foo={@foo}>
            Bar
          </Oops>
        """)
      end)
    end

    test "invalid tag" do
      message = ~r/.exs:1:(11:)? expected closing `}` for expression/
      assert_raise(ParseError, message, fn ->
        eval("""
        <div foo={<%= @foo %>}>bar</div>
        """)
      end)
    end
  end

  describe "handle errors in expressions" do
    if Version.match?(System.version(), ">= 1.12.0") do
      test "inside attribute values" do
        assert_raise(SyntaxError, "nofile:12:22: syntax error before: ','", fn ->
          opts = [line: 10, indentation: 8]

          eval(
            """
            text
            <%= "interpolation" %>
            <div class={[,]}/>
            """,
            [],
            opts
          )
        end)
      end

      test "inside root attribute value" do
        assert_raise(SyntaxError, "nofile:12:16: syntax error before: ','", fn ->
          opts = [line: 10, indentation: 8]

          eval(
            """
            text
            <%= "interpolation" %>
            <div {[,]}/>
            """,
            [],
            opts
          )
        end)
      end
    else
      test "older versions cannot provide correct line on errors" do
        assert_raise(SyntaxError, ~r/nofile:2/, fn ->
          opts = [line: 10, indentation: 8]

          eval(
            """
            text
            <%= "interpolation" %>
            <div class={[,]}/>
            """,
            [],
            opts
          )
        end)
      end
    end
  end
end

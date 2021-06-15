defmodule Phoenix.LiveView.HTMLEngineTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView.Helpers, only: [sigil_H: 2, render_block: 1]
  alias Phoenix.LiveView.HTMLEngine

  defmacrop render_component(string) do
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

  defp local_function_component(assigns) do
    ~H"LOCAL COMPONENT: Value: <%= @value %>"
  end

  defp local_function_component_with_inner_content(assigns) do
    ~H"LOCAL COMPONENT: Value: <%= @value %>, Content: <%= render_block(@inner_block) %>"
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

      assert render_component(
               "<Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1'/>"
             ) ==
               "REMOTE COMPONENT: Value: 1"
    end

    test "remote call with inner content" do
      assigns = %{}

      assert render_component("""
             <Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_content value='1'>
               The inner content
             </Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_content>
             """) == "REMOTE COMPONENT: Value: 1, Content: \n  The inner content\n\n"
    end

    test "local call (self close)" do
      assigns = %{}

      assert render_component("<.local_function_component value='1'/>") ==
               "LOCAL COMPONENT: Value: 1"
    end

    test "local call with inner content" do
      assigns = %{}

      assert render_component("""
             <.local_function_component_with_inner_content value='1'>
               The inner content
             </.local_function_component_with_inner_content>
             """) == "LOCAL COMPONENT: Value: 1, Content: \n  The inner content\n\n"
    end

    test "dynamic attributes" do
      assigns = %{attrs: [name: "1", phone: true]}

      assert render_component("<.assigns_component {@attrs} />") ==
               "%{name: &quot;1&quot;, phone: true}"
    end

    test "sorts attributes by group: static + dynamic" do
      assigns = %{attrs1: [d1: "1"], attrs2: [d2: "2", d3: "3"]}

      assert render_component(
               "<.assigns_component d1=\"one\" {@attrs1} d=\"middle\" {@attrs2} d2=\"two\" />"
             ) ==
               "%{d: &quot;middle&quot;, d1: &quot;one&quot;, d2: &quot;two&quot;, d3: &quot;3&quot;}"
    end
  end

  describe "tag validations" do
    test "unmatched open/close tags" do
      assert_raise(RuntimeError, "missing open tag for </span>", fn ->
        eval("""
        <div>
         text
         <%= String.upcase("123") %>
        </span>
        """)
      end)
    end

    test "unmatched open/close tags with nested tags" do
      assert_raise(RuntimeError, "missing open tag for </span>", fn ->
        eval("""
        <div>
          <p>
            text
            <%= String.upcase("123") %>
          </p>
        </span>
        """)
      end)
    end

    test "missing open tag" do
      assert_raise(RuntimeError, "missing open tag for </span>", fn ->
        eval("""
        text
        </span>
        """)
      end)
    end
  end

  describe "handle errors in expressions" do
    if Version.match?(System.version(), ">= 1.12.0-rc.0") do
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
end

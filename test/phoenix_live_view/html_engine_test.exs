defmodule Phoenix.LiveView.HTMLEngineTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  import Phoenix.Component

  alias Phoenix.LiveView.TagEngine.Tokenizer.ParseError

  defp eval(string, assigns \\ %{}, opts \\ []) do
    {env, opts} = Keyword.pop(opts, :env, __ENV__)

    opts =
      Keyword.merge(opts,
        file: env.file,
        caller: env,
        tag_handler: Phoenix.LiveView.HTMLEngine
      )
      |> Keyword.put_new(:line, 1)

    quoted = Phoenix.LiveView.TagEngine.compile(string, opts)

    {result, _} = Code.eval_quoted(quoted, [assigns: assigns], env)
    result
  end

  defp render(string, assigns \\ %{}, opts \\ []) do
    string
    |> eval(assigns, opts)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defmacrop compile(string) do
    quote do
      unquote(
        Phoenix.LiveView.TagEngine.compile(string,
          file: __ENV__.file,
          caller: __CALLER__,
          tag_handler: Phoenix.LiveView.HTMLEngine
        )
      )
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()
    end
  end

  defmacro test_attr_macro(a) do
    case a do
      :base -> quote do: [{"style", "display: flex;"}, {"other", "foo"}, {"another", @bar}]
      _ -> quote do: a
    end
  end

  def assigns_component(assigns) do
    ~H"{inspect(Map.delete(assigns, :__changed__))}"
  end

  def textarea(assigns) do
    assigns =
      Phoenix.Component.assign(assigns, :extra_assigns, assigns_to_attributes(assigns, []))

    ~H"<textarea {@extra_assigns}><%= render_slot(@inner_block) %></textarea>"
  end

  def remote_function_component(assigns) do
    ~H"REMOTE COMPONENT: Value: {@value}"
  end

  def remote_function_component_with_inner_block(assigns) do
    ~H"REMOTE COMPONENT: Value: {@value}, Content: {render_slot(@inner_block)}"
  end

  def remote_function_component_with_inner_block_args(assigns) do
    ~H"""
    REMOTE COMPONENT WITH ARGS: Value: {@value}
    {render_slot(@inner_block, %{
      downcase: String.downcase(@value),
      upcase: String.upcase(@value)
    })}
    """
  end

  defp local_function_component(assigns) do
    ~H"LOCAL COMPONENT: Value: {@value}"
  end

  defp local_function_component_with_inner_block(assigns) do
    ~H"LOCAL COMPONENT: Value: {@value}, Content: {render_slot(@inner_block)}"
  end

  defp local_function_component_with_inner_block_args(assigns) do
    ~H"""
    LOCAL COMPONENT WITH ARGS: Value: {@value}
    {render_slot(@inner_block, %{
      downcase: String.downcase(@value),
      upcase: String.upcase(@value)
    })}
    """
  end

  test "handles text" do
    assert render("Hello") == "Hello"
  end

  test "handles regular blocks" do
    assert render("""
           Hello <%= if true do %>world!<% end %>
           """) == "Hello world!"
  end

  test "handles html blocks with regular blocks" do
    assert render("""
           Hello <div>w<%= if true do %>orld<% end %>!</div>
           """) == "Hello <div>world!</div>"
  end

  test "handles phx-no-curly-interpolation" do
    assert render("""
           <div phx-no-curly-interpolation>{open}<%= :eval %>{close}</div>
           """) == "<div>{open}eval{close}</div>"

    assert render("""
           <div phx-no-curly-interpolation>{open}{<%= :eval %>}{close}</div>
           """) == "<div>{open}{eval}{close}</div>"

    assert render("""
           {:pre}<style phx-no-curly-interpolation>{css}</style>{:post}
           """) == "pre<style>{css}</style>post"

    assert render("""
           <div phx-no-curly-interpolation>{:pre}<style phx-no-curly-interpolation>{css}</style>{:post}</div>
           """) == "<div>{:pre}<style>{css}</style>{:post}</div>"
  end

  test "handles string attributes" do
    assert render("""
           Hello <div name="my name" phone="111">text</div>
           """) == "Hello <div name=\"my name\" phone=\"111\">text</div>"
  end

  test "handles string attribute value keeping special chars unchanged" do
    assert render("<div name='1 < 2'/>") == "<div name='1 < 2'></div>"
  end

  test "handles boolean attributes" do
    assert render("""
           Hello <div hidden>text</div>
           """) == "Hello <div hidden>text</div>"
  end

  test "handles interpolated attributes" do
    assert render("""
           Hello <div name={to_string(123)} phone={to_string(456)}>text</div>
           """) == "Hello <div name=\"123\" phone=\"456\">text</div>"
  end

  test "handles interpolated body" do
    assert render("""
           Hello <div>2 + 2 = {2 + 2}</div>
           """) == "Hello <div>2 + 2 = 4</div>"
  end

  test "handles interpolated attribute value containing special chars" do
    assert render("<div name={@val}/>", %{val: "1 < 2"}) == "<div name=\"1 &lt; 2\"></div>"
  end

  test "handles interpolated attributes with strings" do
    assert render("""
           <div name={String.upcase("abc")}>text</div>
           """) == "<div name=\"ABC\">text</div>"
  end

  test "handles interpolated attributes with curly braces" do
    assert render("""
           <div name={elem({"abc"}, 0)}>text</div>
           """) == "<div name=\"abc\">text</div>"
  end

  test "handles dynamic attributes" do
    assert render("Hello <div {@attrs}>text</div>", %{attrs: [name: "1", phone: to_string(2)]}) ==
             "Hello <div name=\"1\" phone=\"2\">text</div>"
  end

  test "keeps underscores in dynamic attributes" do
    assert render("Hello <div {@attrs}>text</div>", %{attrs: [full_name: "1"]}) ==
             "Hello <div full_name=\"1\">text</div>"
  end

  test "keeps attribute ordering" do
    assigns = %{attrs1: [d1: "1"], attrs2: [d2: "2"]}
    template = ~S(<div {@attrs1} sd1={1} s1="1" {@attrs2} s2="2" sd2={2} />)

    assert render(template, assigns) ==
             ~S(<div d1="1" sd1="1" s1="1" d2="2" s2="2" sd2="2"></div>)

    assert %Phoenix.LiveView.Rendered{static: ["<div", "", " s1=\"1\"", " s2=\"2\"", "></div>"]} =
             eval(template, assigns)
  end

  test "inlines dynamic attributes when keys are known at compilation time" do
    assigns = %{val: 1}

    # keyword list
    template = ~S(<div {[d1: @val, d2: "2", d3: @val]} />)

    assert %Phoenix.LiveView.Rendered{static: ["<div", " d2=\"2\"", "></div>"]} =
             eval(template, assigns)

    # list with string keys
    template = ~S(<div {[{"d1", @val}, {"d2", "2"}, {"d3", @val}]} />)

    assert %Phoenix.LiveView.Rendered{static: ["<div", " d2=\"2\"", "></div>"]} =
             eval(template, assigns)

    # map with atom keys
    template = ~S(<div {%{d1: @val, d2: "2", d3: @val}} />)

    assert %Phoenix.LiveView.Rendered{static: ["<div", " d2=\"2\"", "></div>"]} =
             eval(template, assigns)

    # map with string keys
    template = ~S(<div {%{"d1" => @val, "d2" => "2", "d3" => @val}} />)

    assert %Phoenix.LiveView.Rendered{static: ["<div", " d2=\"2\"", "></div>"]} =
             eval(template, assigns)

    # macro is expanded
    template = ~S|<div {test_attr_macro(:base)} />|

    assert %Phoenix.LiveView.Rendered{static: ["<div style=\"", "\" other=\"foo\"", "></div>"]} =
             eval(template, %{bar: "baz"})

    assert render(template, %{bar: "baz"}) ==
             ~S|<div style="display: flex;" other="foo" another="baz"></div>|

    # if assign map access was expanded, this would raise
    expected = "<div qux=\"qux\"></div>"
    assigns = %{foo: %{bar: %{baz: %{"qux" => "qux"}}}}
    assert render(~S|<div {@foo.bar.baz} />|, assigns) == expected
  end

  test "optimizes attributes with literal string values" do
    assigns = %{unsafe: "<foo>", safe: {:safe, "<foo>"}}

    # binaries are extracted out
    template = ~S(<div id={"<foo>"} />)
    assert render(template, assigns) == ~S(<div id="&lt;foo&gt;"></div>)

    assert %Phoenix.LiveView.Rendered{static: ["<div id=\"&lt;foo&gt;\"></div>"]} =
             eval(template, assigns)

    # binary concatenation is extracted out
    template = ~S(<div id={"pre-" <> @unsafe} />)
    assert render(template, assigns) == ~S(<div id="pre-&lt;foo&gt;"></div>)

    assert %Phoenix.LiveView.Rendered{static: ["<div id=\"pre-", "\"></div>"]} =
             eval(template, assigns)

    template = ~S(<div id={"pre-" <> @unsafe <> "-pos"} />)
    assert render(template, assigns) == ~S(<div id="pre-&lt;foo&gt;-pos"></div>)

    assert %Phoenix.LiveView.Rendered{static: ["<div id=\"pre-", "-pos\"></div>"]} =
             eval(template, assigns)

    # interpolation is extracted out
    template = ~S(<div id={"pre-#{@unsafe}-pos"} />)
    assert render(template, assigns) == ~S(<div id="pre-&lt;foo&gt;-pos"></div>)

    assert %Phoenix.LiveView.Rendered{static: ["<div id=\"pre-", "-pos\"></div>"]} =
             eval(template, assigns)

    # mixture of interpolation and binary concatenation is extracted out
    template = ~S(<div id={"pre-" <> "#{@unsafe}-pos"} />)
    assert render(template, assigns) == ~S(<div id="pre-&lt;foo&gt;-pos"></div>)

    assert %Phoenix.LiveView.Rendered{static: ["<div id=\"pre-", "-pos\"></div>"]} =
             eval(template, assigns)

    # binaries in lists for classes are extracted out
    template = ~S(<div class={["<bar>", "<foo>"]} />)
    assert render(template, assigns) == ~S(<div class="&lt;bar&gt; &lt;foo&gt;"></div>)

    assert %Phoenix.LiveView.Rendered{static: ["<div class=\"&lt;bar&gt; &lt;foo&gt;\"></div>"]} =
             eval(template, assigns)

    # binaries in lists for classes are extracted out even with dynamic bits
    template = ~S(<div class={["<bar>", @unsafe]} />)
    assert render(template, assigns) == ~S(<div class="&lt;bar&gt; &lt;foo&gt;"></div>)

    assert %Phoenix.LiveView.Rendered{static: ["<div class=\"&lt;bar&gt; ", "\"></div>"]} =
             eval(template, assigns)

    # raises if not a binary
    assert_raise ArgumentError, "expected a binary in <>, got: {:safe, \"<foo>\"}", fn ->
      render(~S(<div id={"pre-" <> @safe} />), assigns)
    end
  end

  def do_block(do: block), do: block

  test "handles do blocks with expressions" do
    assigns = %{not_text: "not text", text: "text"}

    template = ~S"""
    <%= @text %>
    <%= Phoenix.LiveView.HTMLEngineTest.do_block do %><%= assigns[:not_text] %><% end %>
    """

    # A bug made it so "not text" appeared inside @text.
    assert render(template, assigns) == "text\nnot text"

    template = ~S"""
    <%= for i <- ["id1", "id2", "id3"] do %>
      <div id={i}>
        <%= Phoenix.LiveView.HTMLEngineTest.do_block do %>
          <%= i %>
        <% end %>
      </div>
    <% end %>
    """

    # A bug made it so "id={id}" was not handled properly
    assert render(template, assigns) =~ ~s'<div id="id1">'
  end

  test "optimizes class attributes" do
    assigns = %{
      nil_assign: nil,
      true_assign: true,
      false_assign: false,
      unsafe: "<foo>",
      safe: {:safe, "<foo>"},
      list: ["safe", false, nil, "<unsafe>"],
      recursive_list: ["safe", false, [nil, "<unsafe>"]]
    }

    assert %Phoenix.LiveView.Rendered{static: ["<div class=\"", "\"></div>"]} =
             eval(~S(<div class={@safe} />), assigns)

    template = ~S(<div class={@nil_assign} />)
    assert render(template, assigns) == ~S(<div class=""></div>)

    template = ~S(<div class={@false_assign} />)
    assert render(template, assigns) == ~S(<div class=""></div>)

    template = ~S(<div class={@true_assign} />)
    assert render(template, assigns) == ~S(<div class=""></div>)

    template = ~S(<div class={@unsafe} />)
    assert render(template, assigns) == ~S(<div class="&lt;foo&gt;"></div>)

    template = ~S(<div class={@safe} />)
    assert render(template, assigns) == ~S(<div class="<foo>"></div>)

    template = ~S(<div class={@list} />)
    assert render(template, assigns) == ~S(<div class="safe &lt;unsafe&gt;"></div>)

    template = ~S(<div class={@recursive_list} />)
    assert render(template, assigns) == ~S(<div class="safe &lt;unsafe&gt;"></div>)
  end

  test "optimizes attributes that can be empty" do
    assigns = %{
      nil_assign: nil,
      true_assign: true,
      false_assign: false,
      unsafe: "<foo>",
      safe: {:safe, "<foo>"},
      list: ["safe", false, nil, "<unsafe>"]
    }

    assert %Phoenix.LiveView.Rendered{static: ["<div style=\"", "\"></div>"]} =
             eval(~S(<div style={@safe} />), assigns)

    template = ~S(<div style={@nil_assign} />)
    assert render(template, assigns) == ~S(<div style=""></div>)

    template = ~S(<div style={@false_assign} />)
    assert render(template, assigns) == ~S(<div style=""></div>)

    template = ~S(<div style={@true_assign} />)
    assert render(template, assigns) == ~S(<div style=""></div>)

    template = ~S(<div style={@unsafe} />)
    assert render(template, assigns) == ~S(<div style="&lt;foo&gt;"></div>)

    template = ~S(<div style={@safe} />)
    assert render(template, assigns) == ~S(<div style="<foo>"></div>)
  end

  test "handle void elements" do
    assert render("""
           <div><br></div>\
           """) == "<div><br></div>"
  end

  test "handle void elements with attributes" do
    assert render("""
           <div><br attr='1'></div>\
           """) == "<div><br attr='1'></div>"
  end

  test "handle self close void elements" do
    assert render("<hr/>") == "<hr>"
  end

  test "handle self close void elements with attributes" do
    assert render(~S(<hr id="1"/>)) == ~S(<hr id="1">)
  end

  test "handle self close elements" do
    assert render("<div/>") == "<div></div>"
  end

  test "handle self close elements with attributes" do
    assert render("<div attr='1'/>") == "<div attr='1'></div>"
  end

  describe "debug annotations" do
    alias Phoenix.LiveViewTest.Support.DebugAnno
    import Phoenix.LiveViewTest.Support.DebugAnno

    test "components without tags" do
      assigns = %{}
      assert compile("<DebugAnno.remote value='1'/>") == "REMOTE COMPONENT: Value: 1"
      assert compile("<.local value='1'/>") == "LOCAL COMPONENT: Value: 1"
    end

    test "components with tags" do
      assigns = %{}

      assert compile("<DebugAnno.remote_with_tags value='1'/>") ==
               "<!-- <Phoenix.LiveViewTest.Support.DebugAnno.remote_with_tags> test/support/live_views/debug_anno.exs:11 () --><div data-phx-loc=\"12\">REMOTE COMPONENT: Value: 1</div><!-- </Phoenix.LiveViewTest.Support.DebugAnno.remote_with_tags> -->"

      assert compile("<.local_with_tags value='1'/>") ==
               "<!-- <Phoenix.LiveViewTest.Support.DebugAnno.local_with_tags> test/support/live_views/debug_anno.exs:19 () --><div data-phx-loc=\"20\">LOCAL COMPONENT: Value: 1</div><!-- </Phoenix.LiveViewTest.Support.DebugAnno.local_with_tags> -->"
    end

    test "nesting" do
      assigns = %{}

      assert compile("<DebugAnno.nested value='1'/>") ==
               """
               <!-- <Phoenix.LiveViewTest.Support.DebugAnno.nested> test/support/live_views/debug_anno.exs:23 () --><div data-phx-loc=\"24\">
                 <!-- @caller test/support/live_views/debug_anno.exs:25 () --><!-- <Phoenix.LiveViewTest.Support.DebugAnno.local_with_tags> test/support/live_views/debug_anno.exs:19 () --><div data-phx-loc=\"20\">LOCAL COMPONENT: Value: local</div><!-- </Phoenix.LiveViewTest.Support.DebugAnno.local_with_tags> -->
               </div><!-- </Phoenix.LiveViewTest.Support.DebugAnno.nested> -->\
               """
    end

    test "slots without tags" do
      assigns = %{}

      assert compile("<DebugAnno.slot />") ==
               """
               <!-- <Phoenix.LiveViewTest.Support.DebugAnno.slot> test/support/live_views/debug_anno.exs:31 () --><!-- @caller test/support/live_views/debug_anno.exs:32 () -->
                 1
               ,
                 2
               <!-- </Phoenix.LiveViewTest.Support.DebugAnno.slot> -->\
               """
    end

    test "slots with tags" do
      assigns = %{}

      assert compile("<DebugAnno.slot_with_tags />") ==
               """
               <!-- <Phoenix.LiveViewTest.Support.DebugAnno.slot_with_tags> test/support/live_views/debug_anno.exs:40 () --><!-- @caller test/support/live_views/debug_anno.exs:41 () --><!-- <:inner_block> test/support/live_views/debug_anno.exs:41 () -->
                 <div data-phx-loc=\"43\">1</div>
               <!-- </:inner_block> --><!-- <:separator> test/support/live_views/debug_anno.exs:42 () --><hr data-phx-loc=\"42\"><!-- </:separator> --><!-- <:inner_block> test/support/live_views/debug_anno.exs:41 () -->
                 <div data-phx-loc=\"43\">2</div>
               <!-- </:inner_block> --><!-- </Phoenix.LiveViewTest.Support.DebugAnno.slot_with_tags> -->\
               """
    end

    test "can opt out" do
      alias Phoenix.LiveViewTest.Support.DebugAnnoOptOut

      assigns = %{}

      assert compile("<DebugAnnoOptOut.slot_with_tags />") ==
               "\n  <div>1</div>\n<hr>\n  <div>2</div>\n"
    end
  end

  describe "handle function components" do
    test "remote call (self close)" do
      assigns = %{}

      assert compile("<Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1'/>") ==
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
             <Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block value='1'>
               The inner content
             </Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block>
             """) == "REMOTE COMPONENT: Value: 1, Content: \n  The inner content\n"
    end

    test "remote call with :let" do
      expected = """
      LOCAL COMPONENT WITH ARGS: Value: aBcD

        Upcase: ABCD
        Downcase: abcd
      """

      assigns = %{}

      assert compile("""
             <.local_function_component_with_inner_block_args
               value="aBcD"
               :let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </.local_function_component_with_inner_block_args>
             """) =~ expected
    end

    test "remote call with inner content with args" do
      expected = """
      REMOTE COMPONENT WITH ARGS: Value: aBcD

        Upcase: ABCD
        Downcase: abcd
      """

      assigns = %{}

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block_args
               value="aBcD"
               :let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block_args>
             """) =~ expected
    end

    test "raise on remote call with inner content passing non-matching args" do
      message = ~r"""
      cannot match arguments sent from render_slot/2 against the pattern in :let.

      Expected a value matching `%{wrong: _}`, got: %{downcase: "abcd", upcase: "ABCD"}\
      """

      assigns = %{}

      assert_raise(RuntimeError, message, fn ->
        compile("""
        <Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block_args
          {[value: "aBcD"]}
          :let={%{wrong: _}}
        >
          ...
        </Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block_args>
        """)
      end)
    end

    test "raise on remote call passing args to self close components" do
      message = ~r".exs:2: cannot use :let on a component without inner content"

      assert_raise(CompileError, message, fn ->
        eval("""
        <br>
        <Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1' :let={var}/>
        """)
      end)
    end

    test "raise when passing :key to slot" do
      message = ~r":key is not supported on slots: sample"

      assert_raise(ParseError, message, fn ->
        eval("""
        <.function_component_with_single_slot>
          <:sample :for={i <- 1..2} :key={i}>
            The sample slot
          </:sample>
        </.function_component_with_single_slot>
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
             <.local_function_component_with_inner_block value='1'>
               The inner content
             </.local_function_component_with_inner_block>
             """) == "LOCAL COMPONENT: Value: 1, Content: \n  The inner content\n"
    end

    test "local call with inner content with args" do
      expected = """
      LOCAL COMPONENT WITH ARGS: Value: aBcD

        Upcase: ABCD
        Downcase: abcd
      """

      assigns = %{}

      assert compile("""
             <.local_function_component_with_inner_block_args
               value="aBcD"
               :let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </.local_function_component_with_inner_block_args>
             """) =~ expected

      assert compile("""
             <.local_function_component_with_inner_block_args
               {[value: "aBcD"]}
               :let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </.local_function_component_with_inner_block_args>
             """) =~ expected
    end

    test "raise on local call with inner content passing non-matching args" do
      message = ~r"""
      cannot match arguments sent from render_slot/2 against the pattern in :let.

      Expected a value matching `%{wrong: _}`, got: %{downcase: "abcd", upcase: "ABCD"}\
      """

      assigns = %{}

      assert_raise(RuntimeError, message, fn ->
        compile("""
        <.local_function_component_with_inner_block_args
          {[value: "aBcD"]}
          :let={%{wrong: _}}
        >
          ...
        </.local_function_component_with_inner_block_args>
        """)
      end)
    end

    test "raise on local call passing args to self close components" do
      message = ~r".exs:2: cannot use :let on a component without inner content"

      assert_raise(CompileError, message, fn ->
        eval("""
        <br>
        <.local_function_component value='1' :let={var}/>
        """)
      end)
    end

    test "raise on duplicated :let" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:4:3: cannot define multiple :let attributes. Another :let has already been defined at line 3
        |
      1 | <br>
      2 | <Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1'
      3 |   :let={var1}
      4 |   :let={var2}
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <br>
        <Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1'
          :let={var1}
          :let={var2}
        />
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:4:3: cannot define multiple :let attributes. Another :let has already been defined at line 3
        |
      1 | <br>
      2 | <.local_function_component value='1'
      3 |   :let={var1}
      4 |   :let={var2}
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <br>
        <.local_function_component value='1'
          :let={var1}
          :let={var2}
        />
        """)
      end)
    end

    test "invalid :let expr" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:2:70: :let must be a pattern between {...} in remote component: Phoenix.LiveView.HTMLEngineTest.remote_function_component
        |
      1 | <br>
      2 | <Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1' :let=\"1\"
        |                                                                      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <br>
        <Phoenix.LiveView.HTMLEngineTest.remote_function_component value='1' :let="1"
        />
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:2:38: :let must be a pattern between {...} in local component: local_function_component
        |
      1 | <br>
      2 | <.local_function_component value='1' :let=\"1\"
        |                                      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <br>
        <.local_function_component value='1' :let="1"
        />
        """)
      end)
    end

    test "raise with invalid special attr" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:2:38: unsupported attribute \":bar\" in local component: local_function_component
        |
      1 | <br>
      2 | <.local_function_component value='1' :bar=\"1\" />
        |                                      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <br>
        <.local_function_component value='1' :bar="1" />
        />
        """)
      end)
    end

    test "raise on unclosed local call" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: end of template reached without closing tag for <.local_function_component>
        |
      1 | <.local_function_component value='1' :let={var}>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <.local_function_component value='1' :let={var}>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:2:3: end of do-block reached without closing tag for <.local_function_component>
        |
      1 | <%= if true do %>
      2 |   <.local_function_component value='1' :let={var}>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <%= if true do %>
          <.local_function_component value='1' :let={var}>
        <% end %>
        """)
      end)
    end

    test "when tag is unclosed" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:2:1: end of template reached without closing tag for <div>
        |
      1 | <div>Foo</div>
      2 | <div>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div>Foo</div>
        <div>
        <div>Bar</div>
        """)
      end)
    end

    test "when syntax error on HTML attributes" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:2:9: invalid attribute value after `=`. Expected either a value between quotes (such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)
        |
      1 | <div>Bar</div>
      2 | <div id=>Foo</div>
        |         ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div>Bar</div>
        <div id=>Foo</div>
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

  describe "named slots" do
    def function_component_with_single_slot(assigns) do
      ~H"""
      BEFORE SLOT
      <%= render_slot(@sample) %>
      AFTER SLOT
      """noformat
    end

    def function_component_with_slots(assigns) do
      ~H"""
      BEFORE HEADER
      <%= render_slot(@header) %>
      TEXT
      <%= render_slot(@footer) %>
      AFTER FOOTER
      """noformat
    end

    def function_component_with_slots_and_default(assigns) do
      ~H"""
      BEFORE HEADER
      <%= render_slot(@header) %>
      TEXT:<%= render_slot(@inner_block) %>:TEXT
      <%= render_slot(@footer) %>
      AFTER FOOTER
      """noformat
    end

    def function_component_with_slots_and_args(assigns) do
      ~H"""
      BEFORE SLOT
      <%= render_slot(@sample, 1) %>
      AFTER SLOT
      """noformat
    end

    def function_component_with_slot_attrs(assigns) do
      ~H"""
      <%= for entry <- @sample do %>
      <%= entry.a %>
      <%= render_slot(entry) %>
      <%= entry.b %>
      <% end %>
      """noformat
    end

    def function_component_with_multiple_slots_entries(assigns) do
      ~H"""
      <%= for entry <- @sample do %>
        <%= entry.id %>: <%= render_slot(entry, %{}) %>
      <% end %>
      """noformat
    end

    def function_component_with_self_close_slots(assigns) do
      ~H"""
      <%= for entry <- @sample do %>
        <%= entry.id %>
      <% end %>
      """noformat
    end

    def render_slot_name(assigns) do
      ~H"<%= for entry <- @sample do %>[<%= entry.__slot__ %>]<% end %>"noformat
    end

    def render_inner_block_slot_name(assigns) do
      ~H"<%= for entry <- @inner_block do %>[<%= entry.__slot__ %>]<% end %>"noformat
    end

    test "single slot" do
      assigns = %{}

      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

          The sample slot
        \

      AFTER SLOT
      """

      assert compile("""
             COMPONENT WITH SLOTS:
             <.function_component_with_single_slot>
               <:sample>
                 The sample slot
               </:sample>
             </.function_component_with_single_slot>
             """) == expected

      assert compile("""
             COMPONENT WITH SLOTS:
             <Phoenix.LiveView.HTMLEngineTest.function_component_with_single_slot>
               <:sample>
                 The sample slot
               </:sample>
             </Phoenix.LiveView.HTMLEngineTest.function_component_with_single_slot>
             """) == expected
    end

    test "raise when calling render_slot/2 on a slot without inner content" do
      message = ~r"attempted to render slot <:sample> but the slot has no inner content"

      assigns = %{}

      assert_raise(RuntimeError, message, fn ->
        compile("""
        <.function_component_with_single_slot>
          <:sample/>
        </.function_component_with_single_slot>
        """)
      end)

      assert_raise(RuntimeError, message, fn ->
        compile("""
        <.function_component_with_single_slot>
          <:sample/>
          <:sample/>
        </.function_component_with_single_slot>
        """)
      end)
    end

    test "multiple slot entries randered by a single rende_slot/2 call" do
      assigns = %{}

      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

          entry 1
        \

          entry 2
        \

      AFTER SLOT
      """

      assert compile("""
             COMPONENT WITH SLOTS:
             <.function_component_with_single_slot>
               <:sample>
                 entry 1
               </:sample>
               <:sample>
                 entry 2
               </:sample>
             </.function_component_with_single_slot>
             """) == expected

      assert compile("""
             COMPONENT WITH SLOTS:
             <Phoenix.LiveView.HTMLEngineTest.function_component_with_single_slot>
               <:sample>
                 entry 1
               </:sample>
               <:sample>
                 entry 2
               </:sample>
             </Phoenix.LiveView.HTMLEngineTest.function_component_with_single_slot>
             """) == expected
    end

    test "multiple slot entries handled by an explicit for comprehension" do
      assigns = %{}

      expected = """

        1: one

        2: two
      """

      assert compile("""
             <.function_component_with_multiple_slots_entries>
               <:sample id="1">one</:sample>
               <:sample id="2">two</:sample>
             </.function_component_with_multiple_slots_entries>
             """) == expected

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.function_component_with_multiple_slots_entries>
               <:sample id="1">one</:sample>
               <:sample id="2">two</:sample>
             </Phoenix.LiveView.HTMLEngineTest.function_component_with_multiple_slots_entries>
             """) == expected
    end

    test "slot attrs" do
      assigns = %{a: "A"}
      expected = "\nA\n and \nB\n"

      assert compile("""
             <.function_component_with_slot_attrs>
               <:sample a={@a} b="B"> and </:sample>
             </.function_component_with_slot_attrs>
             """) == expected

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.function_component_with_slot_attrs>
               <:sample a={@a} b="B"> and </:sample>
             </Phoenix.LiveView.HTMLEngineTest.function_component_with_slot_attrs>
             """) == expected
    end

    test "multiple slots" do
      assigns = %{}

      expected = """
      BEFORE COMPONENT
      BEFORE HEADER

          The header content
        \

      TEXT

          The footer content
        \

      AFTER FOOTER

      AFTER COMPONENT
      """

      assert compile("""
             BEFORE COMPONENT
             <.function_component_with_slots>
               <:header>
                 The header content
               </:header>
               <:footer>
                 The footer content
               </:footer>
             </.function_component_with_slots>
             AFTER COMPONENT
             """) == expected

      assert compile("""
             BEFORE COMPONENT
             <Phoenix.LiveView.HTMLEngineTest.function_component_with_slots>
               <:header>
                 The header content
               </:header>
               <:footer>
                 The footer content
               </:footer>
             </Phoenix.LiveView.HTMLEngineTest.function_component_with_slots>
             AFTER COMPONENT
             """) == expected
    end

    test "multiple slots with default" do
      assigns = %{middle: "middle"}

      expected = """
      BEFORE COMPONENT
      BEFORE HEADER

          The header content
        \

      TEXT:
        top
        foo middle bar
        bot
      :TEXT

          The footer content
        \

      AFTER FOOTER

      AFTER COMPONENT
      """

      assert compile("""
             BEFORE COMPONENT
             <.function_component_with_slots_and_default>
               top
               <:header>
                 The header content
               </:header>
               foo <%= @middle %> bar
               <:footer>
                 The footer content
               </:footer>
               bot
             </.function_component_with_slots_and_default>
             AFTER COMPONENT
             """) == expected

      assert compile("""
             BEFORE COMPONENT
             <Phoenix.LiveView.HTMLEngineTest.function_component_with_slots_and_default>
               top
               <:header>
                 The header content
               </:header>
               foo <%= @middle %> bar
               <:footer>
                 The footer content
               </:footer>
               bot
             </Phoenix.LiveView.HTMLEngineTest.function_component_with_slots_and_default>
             AFTER COMPONENT
             """) == expected
    end

    test "slots with args" do
      assigns = %{}

      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

          The sample slot
          Arg: 1
        \

      AFTER SLOT
      """

      assert compile("""
             COMPONENT WITH SLOTS:
             <.function_component_with_slots_and_args>
               <:sample :let={arg}>
                 The sample slot
                 Arg: <%= arg %>
               </:sample>
             </.function_component_with_slots_and_args>
             """) == expected

      assert compile("""
             COMPONENT WITH SLOTS:
             <Phoenix.LiveView.HTMLEngineTest.function_component_with_slots_and_args>
               <:sample :let={arg}>
                 The sample slot
                 Arg: <%= arg %>
               </:sample>
             </Phoenix.LiveView.HTMLEngineTest.function_component_with_slots_and_args>
             """) == expected
    end

    test "nested calls with slots" do
      assigns = %{}

      expected = """
      BEFORE SLOT

         The outer slot
          BEFORE SLOT

            The inner slot
            \

      AFTER SLOT

        \

      AFTER SLOT
      """

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.function_component_with_single_slot>
               <:sample>
                The outer slot
                 <.function_component_with_single_slot>
                   <:sample>
                   The inner slot
                   </:sample>
                 </.function_component_with_single_slot>
               </:sample>
             </Phoenix.LiveView.HTMLEngineTest.function_component_with_single_slot>
             """) == expected

      assert compile("""
             <.function_component_with_single_slot>
               <:sample>
                The outer slot
                 <.function_component_with_single_slot>
                   <:sample>
                   The inner slot
                   </:sample>
                 </.function_component_with_single_slot>
               </:sample>
             </.function_component_with_single_slot>
             """) == expected
    end

    test "self close slots" do
      assigns = %{}

      expected = """

        1

        2
      """

      assert compile("""
             <.function_component_with_self_close_slots>
               <:sample id="1"/>
               <:sample id="2"/>
             </.function_component_with_self_close_slots>
             """) == expected

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.function_component_with_self_close_slots>
               <:sample id="1"/>
               <:sample id="2"/>
             </Phoenix.LiveView.HTMLEngineTest.function_component_with_self_close_slots>
             """) == expected
    end

    test "raise if self close slot uses :let" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:2:19: cannot use :let on a slot without inner content
        |
      1 | <.function_component_with_self_close_slots>
      2 |   <:sample id="1" :let={var}/>
        |                   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <.function_component_with_self_close_slots>
          <:sample id="1" :let={var}/>
        </.function_component_with_self_close_slots>
        """)
      end)
    end

    test "store the slot name in __slot__" do
      assigns = %{}

      assert compile("""
             <.render_slot_name>
               <:sample>
                 The sample slot
               </:sample>
             </.render_slot_name>
             """) == "[sample]"

      assert compile("""
             <.render_slot_name>
               <:sample/>
               <:sample/>
             </.render_slot_name>
             """) == "[sample][sample]"
    end

    test "store the inner_block slot name in __slot__" do
      assigns = %{}

      assert compile("""
             <.render_inner_block_slot_name>
                 The content
             </.render_inner_block_slot_name>
             """) == "[inner_block]"
    end

    test "raise if the slot entry is not a direct child of a component" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:2:3: invalid slot entry <:sample>. A slot entry must be a direct child of a component
        |
      1 | <div>
      2 |   <:sample>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div>
          <:sample>
            Content
          </:sample>
        </div>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:3:3: invalid slot entry <:sample>. A slot entry must be a direct child of a component
        |
      1 | <Phoenix.LiveView.HTMLEngineTest.function_component_with_single_slot>
      2 | <%= if true do %>
      3 |   <:sample>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <Phoenix.LiveView.HTMLEngineTest.function_component_with_single_slot>
        <%= if true do %>
          <:sample>
            <p>Content</p>
          </:sample>
        <% end %>
        </Phoenix.LiveView.HTMLEngineTest.function_component_with_single_slot>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:3:5: invalid slot entry <:footer>. A slot entry must be a direct child of a component
        |
      1 | <.mydiv>
      2 |   <:sample>
      3 |     <:footer>
        |     ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <.mydiv>
          <:sample>
            <:footer>
              Content
            </:footer>
          </:sample>
        </.mydiv>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: invalid slot entry <:sample>. A slot entry must be a direct child of a component
        |
      1 | <:sample>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <:sample>
          Content
        </:sample>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: invalid slot entry <:sample>. A slot entry must be a direct child of a component
        |
      1 | <:sample>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <:sample>
          <p>Content</p>
        </:sample>
        """)
      end)
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
      assert eval("\n\n<foo></foo>\n").root == true
      assert eval("<%!-- comment --%>\n\n<foo></foo>\n").root == true
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
      assert eval("<div :for={item <- @items}><%= item %></div>").root == false
      assert eval("<!-- comment --><div></div>").root == false
      assert eval("<div></div><!-- comment -->").root == false
    end
  end

  describe "tag validations" do
    test "handles style" do
      assert render("<style>a = '<a>';<%= :b %> = '<b>';</style>") ==
               "<style>a = '<a>';b = '<b>';</style>"
    end

    test "handles script" do
      assert render("<script>a = '<a>';<%= :b %> = '<b>';</script>") ==
               "<script>a = '<a>';b = '<b>';</script>"
    end

    test "handles comments" do
      assert render("Begin<!-- <%= 123 %> -->End") ==
               "Begin<!-- 123 -->End"
    end

    test "unmatched comment" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:6: expected closing `-->` for comment
        |
      1 | Begin<!-- <%= 123 %>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("Begin<!-- <%= 123 %>")
      end)
    end

    test "unmatched open/close tags" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:4:1: unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      1 | <br>
      2 | <div>
      3 |  text
      4 | </span>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <br>
        <div>
         text
        </span>
        """)
      end)
    end

    test "unmatched open/close tags with nested tags" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:6:1: unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      3 |   <p>
      4 |     text
      5 |   </p>
      6 | </span>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
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

    test "unmatched open/close tags with void tags" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:16: unmatched closing tag. Expected </div> for <div> at line 1, got: </link> (note <link> is a void tag and cannot have any content)
        |
      1 | <div><link>Text</link></div>
        |                ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("<div><link>Text</link></div>")
      end)
    end

    test "invalid remote tag" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: invalid tag <Foo>
        |
      1 | <Foo foo=\"bar\" />
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <Foo foo="bar" />
        """)
      end)
    end

    test "missing open tag" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:2:3: missing opening tag for </span>
        |
      1 | text
      2 |   </span>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        text
          </span>
        """)
      end)
    end

    test "missing open tag with void tag" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:11: missing opening tag for </link> (note <link> is a void tag and cannot have any content)
        |
      1 | <link>Text</link>
        |           ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("<link>Text</link>")
      end)
    end

    test "missing closing tag" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:2:1: end of template reached without closing tag for <div>
        |
      1 | <br>
      2 | <div foo={@foo}>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <br>
        <div foo={@foo}>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:2:3: end of template reached without closing tag for <span>
        |
      1 | text
      2 |   <span foo={@foo}>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        text
          <span foo={@foo}>
            text
        """)
      end)
    end

    test "invalid tag name" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:2:3: invalid tag <Oops>
        |
      1 | <br>
      2 |   <Oops foo={@foo}>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <br>
          <Oops foo={@foo}>
            Bar
          </Oops>
        """)
      end)
    end

    test "invalid tag" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:10: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 | <div foo={<%= @foo %>}>bar</div>
        |          ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div foo={<%= @foo %>}>bar</div>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:2:3: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 | <div foo=
      2 |   {<%= @foo %>}>bar</div>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        eval(
          """
          <div foo=
            {<%= @foo %>}>bar</div>
          """,
          %{},
          indentation: 0
        )
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:2:6: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 |    <div foo=
      2 |      {<%= @foo %>}>bar</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval(
          """
          <div foo=
            {<%= @foo %>}>bar</div>

          """,
          %{},
          indentation: 3
        )
      end)
    end
  end

  test "do not render phx-no-format attr" do
    rendered = eval("<div phx-no-format>Content</div>")
    assert rendered.static == ["<div>Content</div>"]

    rendered = eval("<div phx-no-format />")
    assert rendered.static == ["<div></div>"]

    assigns = %{}

    assert compile("""
           <Phoenix.LiveView.HTMLEngineTest.textarea phx-no-format>
            Content
           </Phoenix.LiveView.HTMLEngineTest.textarea>
           """) == "<textarea>\n Content\n</textarea>"

    assert compile("<.textarea phx-no-format>Content</.textarea>") ==
             "<textarea>Content</textarea>"
  end

  describe "html validations" do
    test "phx-update attr requires an unique ID" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: attribute \"phx-update\" requires the \"id\" attribute to be set
        |
      1 | <div phx-update=\"ignore\">
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div phx-update="ignore">
          Content
        </div>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: attribute \"phx-update\" requires the \"id\" attribute to be set
        |
      1 | <div phx-update=\"ignore\" class=\"foo\">
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div phx-update="ignore" class="foo">
          Content
        </div>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: attribute \"phx-update\" requires the \"id\" attribute to be set
        |
      1 | <div phx-update=\"ignore\" class=\"foo\" />
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div phx-update="ignore" class="foo" />
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: attribute \"phx-update\" requires the \"id\" attribute to be set
        |
      1 | <div phx-update={@value}>Content</div>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div phx-update={@value}>Content</div>
        """)
      end)

      assert eval("""
             <div id="id" phx-update={@value}>Content</div>
             """)
    end

    test "validates phx-update values" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:14: the value of the attribute \"phx-update\" must be: ignore, stream, append, prepend, or replace
        |
      1 | <div id="id" phx-update="bar">
        |              ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div id="id" phx-update="bar">
          Content
        </div>
        """)
      end)
    end

    test "phx-hook attr requires an unique ID" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: attribute \"phx-hook\" requires the \"id\" attribute to be set
        |
      1 | <div phx-hook=\"MyHook\">
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div phx-hook="MyHook">
          Content
        </div>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:1:1: attribute \"phx-hook\" requires the \"id\" attribute to be set
        |
      1 | <div phx-hook=\"MyHook\" />
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div phx-hook="MyHook" />
        """)
      end)
    end

    test "don't raise when there are dynamic variables" do
      assert eval("""
             <div phx-hook="MyHook" {@some_var}>Content</div>
             """)

      assert eval("""
             <div phx-update="ignore" {@some_var}>Content</div>
             """)
    end

    test "raise on unsupported special attrs" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:6: unsupported attribute :let in tags
        |
      1 | <div :let={@user}>Content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div :let={@user}>Content</div>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:1:6: unsupported attribute :foo in tags
        |
      1 | <div :foo=\"something\" />
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div :foo="something" />
        """)
      end)
    end

    test "warns when input has id as name" do
      assert capture_io(:stderr, fn ->
               eval("""
               <input name="id" value="foo">
               """)
             end) =~
               "Setting the \"name\" attribute to \"id\" on an input tag overrides the ID of the corresponding form element"
    end
  end

  describe "handle errors in expressions" do
    test "inside attribute values" do
      exception =
        assert_raise SyntaxError, fn ->
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
        end

      message = Exception.message(exception)
      assert message =~ "test/phoenix_live_view/html_engine_test.exs:12:22:"
      assert message =~ "syntax error before: ','"
    end

    test "inside root attribute value" do
      exception =
        assert_raise SyntaxError, fn ->
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
        end

      message = Exception.message(exception)
      assert message =~ "test/phoenix_live_view/html_engine_test.exs:12:16:"
      assert message =~ "syntax error before: ','"
    end
  end

  describe ":for attr" do
    test "handle :for attr on HTML element" do
      expected = "<div>foo</div><div>bar</div><div>baz</div>"

      assigns = %{items: ["foo", "bar", "baz"]}

      assert compile("""
               <div :for={item <- @items}><%= item %></div>
             """) =~ expected
    end

    test "handle :for attr on self closed HTML element" do
      expected = ~s(<div class="foo"></div><div class="foo"></div><div class="foo"></div>)

      assigns = %{items: ["foo", "bar", "baz"]}

      assert compile("""
               <div class="foo" :for={_item <- @items} />
             """) =~ expected
    end

    test "raise on invalid :for expr" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:6: :for must be a generator expression (pattern <- enumerable) between {...}
        |
      1 | <div :for={@user}>Content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div :for={@user}>Content</div>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:1:6: :for must be an expression between {...}
        |
      1 | <div :for=\"1\">Content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div :for="1">Content</div>
        """)
      end)

      message = """
      test/phoenix_live_view/html_engine_test.exs:1:7: :for must be an expression between {...}
        |
      1 | <.div :for=\"1\">Content</.div>
        |       ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <.div :for="1">Content</.div>
        """)
      end)
    end

    test ":if components change tracking" do
      assert %Phoenix.LiveView.Rendered{static: ["", ""], dynamic: dynamic} =
               eval(
                 """
                 <Phoenix.LiveView.HTMLEngineTest.remote_function_component value={@val} :if={@val == 1} />
                 """,
                 %{__changed__: %{val: true}, val: 1}
               )

      assert [%Phoenix.LiveView.Rendered{static: ["", ""]}] = dynamic.(true)
    end

    test ":for components change tracking" do
      %Phoenix.LiveView.Rendered{static: ["", ""], dynamic: dynamic} =
        eval(
          """
          <Phoenix.LiveView.HTMLEngineTest.remote_function_component :for={val <- @items} value={val} />
          """,
          %{__changed__: %{items: true}, items: [1, 2]}
        )

      assert [%Phoenix.LiveView.Comprehension{}] = dynamic.(true)
    end

    test ":for in components" do
      assigns = %{items: [1, 2]}

      assert compile("""
             <.local_function_component :for={val <- @items} value={val} />
             """) == "LOCAL COMPONENT: Value: 1LOCAL COMPONENT: Value: 2"

      assert compile("""
             <br>
             <Phoenix.LiveView.HTMLEngineTest.remote_function_component :for={val <- @items} value={val} />
             """) == "<br>\nREMOTE COMPONENT: Value: 1REMOTE COMPONENT: Value: 2"

      assert compile("""
             <br>
             <Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block :for={val <- @items} value={val}>inner<%= val %></Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block>
             """) ==
               "<br>\nREMOTE COMPONENT: Value: 1, Content: inner1REMOTE COMPONENT: Value: 2, Content: inner2"

      assert compile("""
             <.local_function_component_with_inner_block :for={val <- @items} value={val}>inner<%= val %></.local_function_component_with_inner_block>
             """) ==
               "LOCAL COMPONENT: Value: 1, Content: inner1LOCAL COMPONENT: Value: 2, Content: inner2"
    end

    test "raise on duplicated :for" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:28: cannot define multiple \":for\" attributes. Another \":for\" has already been defined at line 1
        |
      1 | <div :for={item <- [1, 2]} :for={item <- [1, 2]}>Content</div>
        |                            ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div :for={item <- [1, 2]} :for={item <- [1, 2]}>Content</div>
        """)
      end)
    end

    test ":for in slots" do
      assigns = %{items: [1, 2, 3, 4]}

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.slot_if value={0}>
               <:slot :for={i <- @items}>slot<%= i %></:slot>
             </Phoenix.LiveView.HTMLEngineTest.slot_if>
             """) == "<div>0-slot1slot2slot3slot4</div>"
    end

    test ":for and :if in slots" do
      assigns = %{items: [1, 2, 3, 4]}

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.slot_if value={0}>
               <:slot :for={i <- @items} :if={rem(i, 2) == 0}>slot<%= i %></:slot>
             </Phoenix.LiveView.HTMLEngineTest.slot_if>
             """) == "<div>0-slot2slot4</div>"
    end

    test ":for and :if and :let in slots" do
      assigns = %{items: [1, 2, 3, 4]}

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.slot_if value={0}>
               <:slot :for={i <- @items} :if={rem(i, 2) == 0} :let={val}>slot<%= i %>(<%= val %>)</:slot>
             </Phoenix.LiveView.HTMLEngineTest.slot_if>
             """) == "<div>0-slot2(0)slot4(0)</div>"
    end

    test "multiple slot definitions with mixed regular/if/for" do
      assigns = %{items: [2, 3]}

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.slot_if value={0}>
               <:slot :if={false}>slot0</:slot>
               <:slot>slot1</:slot>
               <:slot :for={i <- @items}>slot<%= i %></:slot>
               <:slot>slot4</:slot>
             </Phoenix.LiveView.HTMLEngineTest.slot_if>
             """) == "<div>0-slot1slot2slot3slot4</div>"
    end
  end

  describe ":if attr" do
    test "handle :if attr on HTML element" do
      assigns = %{flag: true}

      assert compile("""
               <div :if={@flag} id="test">yes</div>
             """) =~ "<div id=\"test\">yes</div>"

      assert compile("""
               <div :if={!@flag} id="test">yes</div>
             """) == ""
    end

    test "handle :if attr on self closed HTML element" do
      assigns = %{flag: true}

      assert compile("""
               <div :if={@flag} id="test" />
             """) =~ "<div id=\"test\"></div>"

      assert compile("""
               <div :if={!@flag} id="test" />
             """) == ""
    end

    test "raise on invalid :if expr" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:6: :if must be an expression between {...}
        |
      1 | <div :if=\"1\">test</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div :if="1">test</div>
        """)
      end)
    end

    test ":if in components" do
      assigns = %{flag: true}

      assert compile("""
             <.local_function_component value="123" :if={@flag} />
             """) == "LOCAL COMPONENT: Value: 123"

      assert compile("""
             <.local_function_component value="123" :if={!@flag}>test</.local_function_component>
             """) == ""

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.remote_function_component value="123" :if={@flag} />
             """) == "REMOTE COMPONENT: Value: 123"

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.remote_function_component value="123" :if={!@flag}>test</Phoenix.LiveView.HTMLEngineTest.remote_function_component>
             """) == ""
    end

    test "raise on duplicated :if" do
      message = """
      test/phoenix_live_view/html_engine_test.exs:1:17: cannot define multiple \":if\" attributes. Another \":if\" has already been defined at line 1
        |
      1 | <div :if={true} :if={false}>test</div>
        |                 ^\
      """

      assert_raise(ParseError, message, fn ->
        eval("""
        <div :if={true} :if={false}>test</div>
        """)
      end)
    end

    def slot_if(assigns) do
      ~H"""
      <div>{@value}-{render_slot(@slot, @value)}</div>
      """
    end

    def slot_if_self_close(assigns) do
      ~H"""
      <div><%= @value %>-<%= for slot <- @slot do %><%= slot.val %>-<% end %></div>
      """noformat
    end

    test ":if in slots" do
      assigns = %{flag: true}

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.slot_if value={0}>
               <:slot :if={@flag}>slot1</:slot>
               <:slot :if={!@flag}>slot2</:slot>
               <:slot :if={@flag}>slot3</:slot>
             </Phoenix.LiveView.HTMLEngineTest.slot_if>
             """) == "<div>0-slot1slot3</div>"

      assert compile("""
             <Phoenix.LiveView.HTMLEngineTest.slot_if_self_close value={0}>
               <:slot :if={@flag} val={1} />
               <:slot :if={!@flag} val={2} />
               <:slot :if={@flag} val={3} />
             </Phoenix.LiveView.HTMLEngineTest.slot_if_self_close>
             """) == "<div>0-1-3-</div>"
    end
  end

  describe ":for and :if attr together" do
    test "handle attrs on HTML element" do
      assigns = %{items: [1, 2, 3, 4]}

      assert compile("""
               <div :for={i <- @items} :if={rem(i, 2) == 0}><%= i %></div>
             """) =~ "<div>2</div><div>4</div>"

      assert compile("""
               <div :for={i <- @items} :if={rem = rem(i, 2)}><%= i %>,<%= rem %></div>
             """) =~ "<div>1,1</div><div>2,0</div><div>3,1</div><div>4,0</div>"

      assert compile("""
               <div :for={i <- @items} :if={false}><%= i %></div>
             """) == ""
    end

    test "handle attrs on self closed HTML element" do
      assigns = %{items: [1, 2, 3, 4]}

      assert compile("""
               <div :for={i <- @items} :if={rem(i, 2) == 0} id={"post-" <> to_string(i)} />
             """) =~ "<div id=\"post-2\"></div><div id=\"post-4\"></div>"

      assert compile("""
               <div :for={i <- @items} :if={false}><%= i %></div>
             """) == ""
    end

    test "handle attrs on components" do
      assigns = %{items: [1, 2, 3, 4]}

      assert compile("""
               <.local_function_component  :for={i <- @items} :if={rem(i, 2) == 0} value={i}/>
             """) == "LOCAL COMPONENT: Value: 2LOCAL COMPONENT: Value: 4"

      assert compile("""
               <Phoenix.LiveView.HTMLEngineTest.remote_function_component  :for={i <- @items} :if={rem(i, 2) == 0} value={i}/>
             """) == "REMOTE COMPONENT: Value: 2REMOTE COMPONENT: Value: 4"

      assert compile("""
               <.local_function_component_with_inner_block  :for={i <- @items} :if={rem(i, 2) == 0} value={i}><%= i %></.local_function_component_with_inner_block>
             """) == "LOCAL COMPONENT: Value: 2, Content: 2LOCAL COMPONENT: Value: 4, Content: 4"

      assert compile("""
               <Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block  :for={i <- @items} :if={rem(i, 2) == 0} value={i}><%= i %></Phoenix.LiveView.HTMLEngineTest.remote_function_component_with_inner_block>
             """) ==
               "REMOTE COMPONENT: Value: 2, Content: 2REMOTE COMPONENT: Value: 4, Content: 4"
    end
  end

  describe "eex_block line/column positions" do
    # Helper to extract `if` nodes that test @status or @other (user's conditionals)
    # This filters out the internal `if` nodes generated for change tracking
    # Note: @status is transformed to assigns.status in the AST
    defp find_user_if_nodes(ast) do
      {_ast, nodes} =
        Macro.prewalk(ast, [], fn
          {:if, meta, [condition | _]} = node, acc ->
            # Check if the condition references assigns.status or assigns.other
            if references_assigns_field?(condition, :status) or
                 references_assigns_field?(condition, :other) do
              {node, [{:if, meta, condition} | acc]}
            else
              {node, acc}
            end

          node, acc ->
            {node, acc}
        end)

      Enum.reverse(nodes)
    end

    # @status becomes assigns.status which is {{:., _, [{:assigns, _, _}, :status]}, _, _}
    defp references_assigns_field?(ast, field_name) do
      {_ast, found} =
        Macro.prewalk(ast, false, fn
          {{:., _, [{:assigns, _, _}, ^field_name]}, _, _} = node, _acc -> {node, true}
          node, acc -> {node, acc}
        end)

      found
    end

    test "if/else/end preserves column positions" do
      template = """
      <%= if @status do %>
          <div>content</div>
        <% else %>
          <span>other</span>
      <% end %>
      """

      opts = [file: "test.heex", caller: __ENV__, tag_handler: Phoenix.LiveView.HTMLEngine]
      quoted = Phoenix.LiveView.TagEngine.compile(template, opts)

      if_nodes = find_user_if_nodes(quoted)
      assert length(if_nodes) == 1, "expected 1 user if node, got #{length(if_nodes)}"

      [{:if, meta, _condition}] = if_nodes
      # The `if` should be at line 1, column 5 (after `<%= `)
      assert meta[:line] == 1, "if should be at line 1, got #{meta[:line]}"
      # Column should be 5 (position after `<%= `)
      assert meta[:column] == 5,
             "if should be at column 5, got #{inspect(meta[:column])} (column tracking is broken)"
    end

    test "nested if blocks preserve line and column positions" do
      # Template with nested if in else block
      # Line 1: <%= if @status do %>
      # Line 5:     <%= if @other do %>
      template = """
      <%= if @status do %>
          <div>content</div>
        <% else %>
          <span>other</span>
          <%=  if @other do %>
             bar
          <% end %>
      <% end %>
      """

      opts = [file: "test.heex", caller: __ENV__, tag_handler: Phoenix.LiveView.HTMLEngine]
      quoted = Phoenix.LiveView.TagEngine.compile(template, opts)

      if_nodes = find_user_if_nodes(quoted)
      assert length(if_nodes) == 2, "expected 2 user if nodes, got #{length(if_nodes)}"

      [{:if, outer_meta, _}, {:if, inner_meta, _}] = if_nodes

      # Outer if should be at line 1, column 5
      assert outer_meta[:line] == 1, "outer if should be at line 1, got #{outer_meta[:line]}"

      assert outer_meta[:column] == 5,
             "outer if should be at column 5, got #{inspect(outer_meta[:column])}"

      # Nested if should be at line 5, column 10
      assert inner_meta[:line] == 5, "nested if should be at line 5, got #{inner_meta[:line]}"

      assert inner_meta[:column] == 10,
             "nested if should be at column 10, got #{inspect(inner_meta[:column])}"
    end
  end

  describe "compiler tracing" do
    alias Phoenix.Component, as: C, warn: false

    defmodule Tracer do
      def trace(event, _env)
          when elem(event, 0) in [
                 :alias_expansion,
                 :alias_reference,
                 :imported_function,
                 :remote_function
               ] do
        send(self(), event)
        :ok
      end

      def trace(_event, _env), do: :ok
    end

    defp tracer_eval(line, content) do
      eval(content, %{},
        env: %{__ENV__ | tracers: [Tracer], lexical_tracker: self(), line: line + 1},
        line: line + 1,
        indentation: 6
      )
    end

    test "handles imports" do
      tracer_eval(__ENV__.line, """
      <.focus_wrap>Ok</.focus_wrap>
      """)

      assert_receive {:imported_function, meta, Phoenix.Component, :focus_wrap, 1}
      assert meta[:line] == __ENV__.line - 4
      assert meta[:column] == 7
    end

    test "handles remote calls" do
      tracer_eval(__ENV__.line, """
      <Phoenix.Component.focus_wrap>Ok</Phoenix.Component.focus_wrap>
      """)

      assert_receive {:alias_reference, meta, Phoenix.Component}
      assert meta[:line] == __ENV__.line - 4
      assert meta[:column] == 7

      assert_receive {:remote_function, meta, Phoenix.Component, :focus_wrap, 1}
      assert meta[:line] == __ENV__.line - 8
      assert meta[:column] == 26
    end

    test "handles aliases" do
      tracer_eval(__ENV__.line, """
      <C.focus_wrap>Ok</C.focus_wrap>
      """)

      assert_receive {:alias_expansion, meta, Elixir.C, Phoenix.Component}
      assert meta[:line] == __ENV__.line - 4
      assert meta[:column] == 7

      assert_receive {:alias_reference, meta, Phoenix.Component}
      assert meta[:line] == __ENV__.line - 8
      assert meta[:column] == 7

      assert_receive {:remote_function, meta, Phoenix.Component, :focus_wrap, 1}
      assert meta[:line] == __ENV__.line - 12
      assert meta[:column] == 10
    end
  end

  describe "root tag attributes" do
    alias Phoenix.LiveViewTest.Support.RootTagAttr
    alias Phoenix.LiveViewTest.TreeDOM
    import Phoenix.LiveViewTest.TreeDOM, only: [sigil_X: 2]

    test "single self-closing tag" do
      assigns = %{}

      compiled = compile("<RootTagAttr.single_self_close/>")

      expected = ~X"<div phx-r></div>"

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "single tag with body" do
      assigns = %{}

      compiled = compile("<RootTagAttr.single_with_body/>")

      expected = ~X"<div phx-r>Test</div>"

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "multiple self-closing tags" do
      assigns = %{}

      compiled = compile("<RootTagAttr.multiple_self_close/>")

      expected = ~X"""
      <div phx-r></div>
      <div phx-r></div>
      <div phx-r></div>
      """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "multiple tags with bodies" do
      assigns = %{}

      compiled = compile("<RootTagAttr.multiple_with_bodies/>")

      expected = ~X"""
      <div phx-r>Test1</div>
      <div phx-r>Test2</div>
      <div phx-r>Test3</div>
      """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "tags root tags of nested tags" do
      assigns = %{}

      compiled = compile("<RootTagAttr.nested_tags/>")

      expected = ~X"""
      <div phx-r>
        <div>
          <div></div>
        </div>
        <div>
          <div></div>
        </div>
      </div>
      <div phx-r>
        <div>
          <div></div>
        </div>
        <div>
          <div></div>
        </div>
      </div>
      """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "tags root tags of component inner_blocks" do
      assigns = %{}

      compiled = compile("<RootTagAttr.component_inner_blocks/>")

      expected =
        ~X"""
        <div phx-r>
          <div>
            <section phx-r>
              <div phx-r>
                <div>
                  Inner Block 1
                </div>
              </div>
            </section>
            <section phx-r>
              <div phx-r>
                <div>
                  Inner Block 2
                </div>
              </div>
            </section>
          </div>
        </div>
        """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "tags root tags of component named slots" do
      assigns = %{}

      compiled = compile("<RootTagAttr.component_named_slots/>")

      expected =
        ~X"""
        <div phx-r>
          <div>
            <section phx-r>
              <aside>
                <div phx-r>
                  <div>
                    Inner Block 1
                  </div>
                </div>
              </aside>
            </section>
            <section phx-r>
              <aside>
                <div phx-r>
                  <div>
                    Inner Block 2
                  </div>
                </div>
              </aside>
            </section>
          </div>
        </div>
        """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "tags root tags correctly for complex nestings of tags, components, and slots" do
      assigns = %{}

      compiled = compile("<RootTagAttr.nested_tags_components_slots/>")

      expected =
        ~X"""
        <div phx-r>
          <div>
            <section phx-r>
                <div phx-r>
                  <section phx-r>
                    <div phx-r>
                      <p phx-r>Simple</p>
                    </div>
                    <aside>
                      <div phx-r>
                        <p phx-r>Simple</p>
                      </div>
                    </aside>
                  </section>
                </div>
              <aside>
                <div phx-r>
                  <section phx-r>
                    <div phx-r>
                      <p phx-r>Simple</p>
                    </div>
                    <aside>
                      <div phx-r>
                        <p phx-r>Simple</p>
                      </div>
                    </aside>
                  </section>
                </div>
              </aside>
            </section>
          </div>
        </div>
        """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "within nestings" do
      assigns = %{}

      compiled = compile("<RootTagAttr.within_nestings bool={true}/>")

      expected = ~X"""
        <div phx-r>
          <div>
              <section phx-r>
                <p phx-r>
                  <span>True</span>
                </p>
              </section>
          </div>
        </div>
      """

      assert TreeDOM.normalize_to_tree(compiled) == expected

      compiled = compile("<RootTagAttr.within_nestings bool={false}/>")

      expected = ~X"""
        <div phx-r>
          <div>
              <section phx-r>
                <p phx-r>
                  <span>False</span>
                </p>
              </section>
          </div>
        </div>
      """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "extra attributes with values provided by macro component directives" do
      assigns = %{}

      compiled = compile("<RootTagAttr.macro_component_attrs_with_values/>")

      expected =
        ~X"""
        <div phx-r phx-sample-one="test" phx-sample-two="test">
          <div>
            <section phx-r>
              <div phx-r phx-sample-two="test" phx-sample-one="test">Inner Block</div>
              <aside>
                <div phx-r phx-sample-two="test" phx-sample-one="test">
                  Named Slot
                </div>
              </aside>
            </section>
          </div>
        </div>
        """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "extra attributes without values provided by macro component directives" do
      assigns = %{}

      compiled = compile("<RootTagAttr.macro_component_attrs_without_values/>")

      expected =
        ~X"""
        <div phx-r phx-sample-two phx-sample-one>
          <div>
            <section phx-r>
              <div phx-r phx-sample-two phx-sample-one>Inner Block</div>
              <aside>
                <div phx-r phx-sample-two phx-sample-one>
                  Named Slot
                </div>
              </aside>
            </section>
          </div>
        </div>
        """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end

    test "extra attributes with values provided by macro component directives within nestings" do
      assigns = %{}

      compiled =
        compile("<RootTagAttr.macro_component_attrs_with_values_within_nestings bool={true}/>")

      expected = ~X"""
        <div phx-r phx-sample-two="test" phx-sample-one="test">
          <div>
              <section phx-r>
                <p phx-r phx-sample-two="test" phx-sample-one="test">
                  <span>True</span>
                </p>
              </section>
          </div>
        </div>
      """

      assert TreeDOM.normalize_to_tree(compiled) == expected

      compiled =
        compile("<RootTagAttr.macro_component_attrs_with_values_within_nestings bool={false}/>")

      expected = ~X"""
        <div phx-r phx-sample-two="test" phx-sample-one="test">
          <div>
              <section phx-r>
                <p phx-r phx-sample-two="test" phx-sample-one="test">
                  <span>False</span>
                </p>
              </section>
          </div>
        </div>
      """

      assert TreeDOM.normalize_to_tree(compiled) == expected
    end
  end
end

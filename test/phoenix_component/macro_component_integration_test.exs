defmodule Phoenix.Component.MacroComponentIntegrationTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import Phoenix.LiveViewTest.TreeDOM, only: [sigil_X: 2]

  alias Phoenix.LiveViewTest.TreeDOM
  alias Phoenix.Component.MacroComponent

  defmodule MyComponent do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def transform(ast, meta) do
      send(self(), {:ast, ast, meta})
      {:ok, Process.get(:new_ast, ast)}
    end
  end

  test "receives ast" do
    defmodule TestComponentAst do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent} id="1" other={@foo}>
          <p>This is some inner content</p>
          <h1>Cool</h1>
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <circle cx="50" cy="50" r="50" />
          </svg>
          <hr />
        </div>
        """
      end
    end

    assert_received {:ast, ast, meta}

    assert {:tag, _,
            [
              "div",
              [
                {:attribute, _, ["id", _, "1"]},
                {:attribute, _, ["other", _, {:@, [line: _], [{:foo, [line: _], nil}]}]}
              ],
              [
                {:do,
                 {:__block__, _,
                  [
                    {:<<>>, _, ["\n  "]},
                    {:tag, _,
                     [
                       "p",
                       _,
                       [{:do, {:__block__, _, [{:<<>>, _, ["This is some inner content"]}]}}]
                     ]},
                    {:<<>>, _, ["\n  "]},
                    {:tag, _,
                     [
                       "h1",
                       _,
                       [{:do, {:__block__, _, [{:<<>>, _, ["Cool"]}]}}]
                     ]},
                    {:<<>>, _, ["\n  "]},
                    {:tag, _,
                     [
                       "svg",
                       [
                         {:attribute, _, ["viewBox", _, "0 0 100 100"]},
                         {:attribute, _, ["xmlns", _, "http://www.w3.org/2000/svg"]}
                       ],
                       [
                         {:do,
                          {:__block__, _,
                           [
                             {:<<>>, _, ["\n    "]},
                             {:tag, _,
                              [
                                "circle",
                                [
                                  {:attribute, _, ["cx", _, "50"]},
                                  {:attribute, _, ["cy", _, "50"]},
                                  {:attribute, _, ["r", _, "50"]}
                                ],
                                [{:closing, :self}]
                              ]},
                             {:<<>>, _, ["\n  "]}
                           ]}}
                       ]
                     ]},
                    {:<<>>, _, ["\n  "]},
                    {:tag, _, ["hr", [], [{:closing, :void}]]},
                    {:<<>>, _, ["\n"]}
                  ]}}
              ]
            ]} = ast

    expected = ~X"""
    <div id="1" other="FOO!">
      <p>This is some inner content</p>
      <h1>Cool</h1>
      <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <circle cx="50" cy="50" r="50" />
      </svg>
      <hr>
    </div>
    """

    assert MacroComponent.ast_to_string(ast, binding: [assigns: %{foo: "FOO!"}])
           |> TreeDOM.normalize_to_tree() == expected

    assert %{env: env} = meta
    assert env.module == TestComponentAst
    assert env.file == __ENV__.file

    assert render_component(&TestComponentAst.render/1, foo: "FOO!")
           |> TreeDOM.normalize_to_tree() == expected
  end

  test "can replace the rendered content" do
    Process.put(
      :new_ast,
      quote do
        tag "div", [attribute("data-foo", [], "bar")] do
          tag "h1", [] do
            "Where is this coming from?"
          end

          tag "div", [attribute("id", [], @foo)] do
            "I have text content"
          end

          tag("hr", [], closing: :void)
        end
      end
    )

    defmodule TestComponentReplacedAst do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent} id="1" other={@foo}>
          <p>This is some inner content</p>
          <h1>Cool</h1>
        </div>
        """
      end
    end

    assert_received {:ast, ast, _meta}

    rendered = render_component(&TestComponentReplacedAst.render/1, foo: "bar\"baz")

    assert rendered =~ "bar&quot;baz"

    assert MacroComponent.ast_to_string(ast, binding: [assigns: %{foo: "bar\"baz"}])
           |> TreeDOM.normalize_to_tree() == ~X"""
           <div id="1" other="bar&quot;baz">
            <p>This is some inner content</p>
            <h1>Cool</h1>
           </div>
           """

    assert render_component(&TestComponentReplacedAst.render/1, foo: "bar\"baz")
           |> TreeDOM.normalize_to_tree() ==
             ~X"""
             <div data-foo="bar">
               <h1>Where is this coming from?</h1>
               <div id="bar&quot;baz">I have text content</div>
               <hr>
             </div>
             """
  end

  test "with EEx inside" do
    defmodule TestComponentWithEEx do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent} id="1" other={@foo}>
          <%= if @foo do %>
            <p>foo</p>
          <% end %>
        </div>
        """
      end
    end

    assert_received {:ast, ast, _}

    # it would be very fancy to have an assert_ast_equals or something and
    # then define the pattern with quote do ... end
    assert {:tag, _,
            [
              "div",
              [
                {:attribute, _, ["id", _, "1"]},
                {:attribute, _,
                 [
                   "other",
                   _,
                   {:@, _, [{:foo, _, nil}]}
                 ]}
              ],
              [
                do:
                  {:__block__, _,
                   [
                     {:<<>>, _, _},
                     {:expr, _,
                      [
                        {:if, _,
                         [
                           {:@, _, [{:foo, _, nil}]},
                           [
                             do:
                               {{:., _,
                                 [{:__aliases__, _, [:Phoenix, :LiveView, :TagEngine]}, :finalize]},
                                _,
                                [
                                  _,
                                  [
                                    do: [
                                      {:<<>>, _, _},
                                      {:tag, _,
                                       ["p", [], [do: {:__block__, _, [{:<<>>, _, ["foo"]}]}]]},
                                      {:<<>>, _, _}
                                    ]
                                  ]
                                ]}
                           ]
                         ]}
                      ]},
                     {:<<>>, _, _}
                   ]}
              ]
            ]} = ast

    assert MacroComponent.ast_to_string(ast, binding: [assigns: %{foo: true}])
           |> TreeDOM.normalize_to_tree() == ~X"""
           <div id="1" other>
            <p>foo</p>
           </div>
           """

    assert MacroComponent.ast_to_string(ast, binding: [assigns: %{foo: false}])
           |> TreeDOM.normalize_to_tree() == ~X"""
           <div id="1">
           </div>
           """

    assert render_component(&TestComponentWithEEx.render/1, foo: true)
           |> TreeDOM.normalize_to_tree() ==
             ~X"""
             <div id="1" other>
              <p>foo</p>
             </div>
             """
  end

  test "with interpolation inside" do
    defmodule TestComponentInterpolation do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent} id="1" other={@foo}>
          {@foo}
        </div>
        """
      end
    end

    assert_received {:ast, ast, _meta}

    assert {:tag, _,
            [
              "div",
              [
                {:attribute, _, ["id", _, "1"]},
                {:attribute, _, ["other", _, {:@, _, [{:foo, _, nil}]}]}
              ],
              [
                do:
                  {:__block__, _,
                   [
                     {:<<>>, _, _},
                     {:body_expr, _, [{:@, _, [{:foo, _, nil}]}]},
                     {:<<>>, _, _}
                   ]}
              ]
            ]} = ast

    assert MacroComponent.ast_to_string(ast, binding: [assigns: %{foo: "hello"}])
           |> TreeDOM.normalize_to_tree() == ~X"""
           <div id="1" other="hello">
             hello
           </div>
           """

    assert render_component(&TestComponentInterpolation.render/1, foo: "hello")
           |> TreeDOM.normalize_to_tree() ==
             ~X"""
             <div id="1" other="hello">
               hello
             </div>
             """
  end

  test "components inside" do
    defmodule TestComponentComponents do
      use Phoenix.Component

      defp my_other_component(assigns) do
        ~H"""
        yay
        """
      end

      def render(assigns) do
        ~H"""
        <div :type={MyComponent} id="1" other={@foo}>
          <.my_other_component />
        </div>
        """
      end
    end

    assert_received {:ast, ast, _meta}

    assert {:tag, _,
            [
              "div",
              [
                {:attribute, _, ["id", _, "1"]},
                {:attribute, _, ["other", _, {:@, _, [{:foo, _, nil}]}]}
              ],
              [
                do:
                  {:__block__, _,
                   [
                     {:<<>>, _, _},
                     {:local_component, _, ["my_other_component", _, [{:closing, :self}]]},
                     {:<<>>, _, _}
                   ]}
              ]
            ]} = ast

    # the `my_other_component` does not exist when evaluating the AST
    assert_raise UndefinedFunctionError, fn ->
      MacroComponent.ast_to_string(ast, binding: [assigns: %{foo: "hello"}])
    end

    assert render_component(&TestComponentComponents.render/1, foo: "hello")
           |> TreeDOM.normalize_to_tree() ==
             ~X"""
             <div id="1" other="hello">
               yay

             </div>
             """
  end

  test ":type on a component" do
    defmodule TestComponent do
      use Phoenix.Component

      defp my_other_component(assigns) do
        ~H"""
        hey!
        """
      end

      def render(assigns) do
        ~H"""
        <.my_other_component :type={MyComponent} />
        """
      end
    end

    assert_received {:ast, ast, _meta}

    assert {:local_component, _, ["my_other_component", [], [closing: :self]]} = ast

    defmodule TestComponentWithSlot do
      use Phoenix.Component

      defp my_other_component(assigns) do
        ~H"""
        hey!
        """
      end

      def render(assigns) do
        ~H"""
        <.my_other_component>
          <:my_slot :type={MyComponent} />
        </.my_other_component>
        """
      end
    end

    assert_received {:ast, ast, _meta}

    assert {:slot, _, ["my_slot", [], [closing: :self]]} = ast
  end

  test "handles dynamic attributes" do
    defmodule TestComponentDynamicAttributes1 do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent} id="1" other={@foo} {@bar}></div>
        """
      end
    end

    assert_received {:ast, ast, _meta}

    assert {:tag, _,
            [
              "div",
              [
                {:attribute, _, ["id", _, "1"]},
                {:attribute, _, ["other", _, {:@, _, [{:foo, _, nil}]}]},
                {:attribute, _, [:root, _, {:@, _, [{:bar, _, nil}]}]}
              ],
              [do: {:__block__, _, []}]
            ]} = ast

    defmodule TestComponentDynamicAttributes2 do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent} id="1" other={@foo}>
          <span {@bar}>Hey!</span>
        </div>
        """
      end
    end

    assert_received {:ast, ast, _meta}

    assert {:tag, _,
            [
              "div",
              [
                {:attribute, _, ["id", _, "1"]},
                {:attribute, _, ["other", _, {:@, _, [{:foo, _, nil}]}]}
              ],
              [
                do:
                  {:__block__, _,
                   [
                     {:<<>>, _, _},
                     {:tag, _,
                      [
                        "span",
                        [{:attribute, _, [:root, _, {:@, _, [{:bar, _, nil}]}]}],
                        [do: {:__block__, _, [{:<<>>, _, ["Hey!"]}]}]
                      ]},
                     _
                   ]}
              ]
            ]} = ast
  end

  test "handles quotes" do
    new_ast =
      quote do
        tag "div", [attribute("id", [], "1")] do
          tag("span", [attribute("class", [], "\"foo\"")], do: ["Test"])
          tag("span", [attribute("class", [], "'foo'")], do: ["Test"])
        end
      end

    Process.put(:new_ast, new_ast)

    defmodule TestComponentQuotes do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyComponent}></div>
        """
      end
    end

    assert_received {:ast, ast, _meta}

    assert MacroComponent.ast_to_string(ast, binding: [assigns: %{foo: "hello"}])
           |> TreeDOM.normalize_to_tree() == ~X"""
           <div></div>
           """

    assert MacroComponent.ast_to_string(new_ast, binding: [assigns: %{foo: "hello"}])
           |> TreeDOM.normalize_to_tree() == ~X"""
           <div id="1"><span class='"foo"'>Test</span><span class="'foo'">Test</span></div>
           """

    assert render_component(&TestComponentQuotes.render/1) == """
           <div id="1"><span class='"foo"'>Test</span><span class="'foo'">Test</span></div>\
           """

    # mixed quotes are invalid
    assert_raise ArgumentError,
                 ~r/invalid attribute value for "class"/,
                 fn ->
                   Process.put(
                     :new_ast,
                     quote do
                       tag("div", [attribute("class", [], unquote(~s["'"]))], do: [])
                     end
                   )

                   defmodule TestComponentQuotesInvalid do
                     use Phoenix.Component

                     def render(assigns) do
                       ~H"""
                       <div :type={MyComponent}></div>
                       """
                     end
                   end
                 end
  end

  test "get_data/2 provides a list of all data entries" do
    defmodule MyMacroComponent do
      @behaviour Phoenix.Component.MacroComponent

      @impl true
      def transform({:tag, _meta, [_name, attrs, _block]} = ast, meta) do
        {:ok, ast,
         %{
           file: meta.env.file,
           line: meta.env.line,
           opts:
             Map.new(attrs, fn
               {:attribute, _meta, [key, _, value]} -> {key, value}
               {:attribute, _meta, [key, nil]} -> {key, nil}
             end)
         }}
      end
    end

    defmodule TestComponentWithData1 do
      use Phoenix.Component

      def render(assigns) do
        ~H"""
        <div :type={MyMacroComponent} foo="bar" baz></div>
        <div>
          <h1 :type={MyMacroComponent} id="2">Content</h1>
        </div>
        """
      end
    end

    assert data = MacroComponent.get_data(TestComponentWithData1, MyMacroComponent)
    assert length(data) == 2

    assert Enum.find(data, fn %{opts: opts} -> opts == %{"baz" => nil, "foo" => "bar"} end)
    assert Enum.find(data, fn %{opts: opts} -> opts == %{"id" => "2"} end)
  end

  describe "root tracking" do
    test "performs root tracking as usual" do
      new_ast =
        quote do
          tag "div", [attribute("id", [], "1")] do
            tag("span", [attribute("class", [], "\"foo\"")], do: ["Test"])
            tag("span", [attribute("class", [], "'foo'")], do: ["Test"])
          end
        end

      Process.put(:new_ast, new_ast)

      defmodule TestComponentRoot do
        use Phoenix.Component

        def render(assigns) do
          ~H"""
          <div :type={MyComponent} foo="bar" baz></div>
          """
        end
      end

      assert TestComponentRoot.render(%{}).root

      new_ast =
        quote do
          tag "div", [attribute("id", [], "1")] do
            tag("span", [attribute("class", [], "\"foo\"")], do: ["Test"])
            tag("span", [attribute("class", [], "'foo'")], do: ["Test"])
          end

          tag("another tag", [], do: [])
        end

      Process.put(:new_ast, new_ast)

      defmodule TestComponentNoRoot do
        use Phoenix.Component

        def render(assigns) do
          ~H"""
          <div :type={MyComponent} foo="bar" baz></div>
          """
        end
      end

      refute TestComponentNoRoot.render(%{}).root
    end
  end
end

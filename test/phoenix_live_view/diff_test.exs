defmodule Phoenix.LiveView.DiffTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView.Helpers

  alias Phoenix.LiveView.{Socket, Diff, Rendered, Component}

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

  defp nested_rendered do
    %Rendered{
      static: ["<h2>", "</h2>", "<span>", "</span>"],
      dynamic: fn _ ->
        [
          "hi",
          %Rendered{
            static: ["s1", "s2", "s3"],
            dynamic: fn _ -> ["abc", "efg"] end,
            fingerprint: 456
          },
          %Rendered{
            static: ["s1", "s2"],
            dynamic: fn _ -> ["efg"] end,
            fingerprint: 789
          }
        ]
      end,
      fingerprint: 123
    }
  end

  defp render(
         rendered,
         fingerprints \\ Diff.new_fingerprints(),
         components \\ Diff.new_components()
       ) do
    socket = %Socket{endpoint: __MODULE__, fingerprints: fingerprints}
    Diff.render(socket, rendered, components)
  end

  defp rendered_to_binary(map) do
    map |> Diff.to_iodata() |> IO.iodata_to_binary()
  end

  describe "full renders without fingerprints" do
    test "basic template" do
      rendered = basic_template(%{time: "10:30", subtitle: "Sunny"})
      {socket, full_render, _} = render(rendered)

      assert full_render == %{
               0 => "10:30",
               1 => "Sunny",
               :s => ["<div>\n  <h2>It's ", "</h2>\n  ", "\n</div>\n"]
             }

      assert rendered_to_binary(full_render) ==
               "<div>\n  <h2>It's 10:30</h2>\n  Sunny\n</div>\n"

      assert socket.fingerprints == {rendered.fingerprint, %{}}
    end

    test "template with literal" do
      rendered = literal_template(%{title: "foo"})
      {socket, full_render, _} = render(rendered)

      assert full_render ==
               %{0 => "foo", 1 => "&lt;div&gt;", :s => ["<div>\n  ", "\n  ", "\n</div>\n"]}

      assert rendered_to_binary(full_render) ==
               "<div>\n  foo\n  &lt;div&gt;\n</div>\n"

      assert socket.fingerprints == {rendered.fingerprint, %{}}
    end

    test "nested %Renderered{}'s" do
      {socket, full_render, _} = render(nested_rendered())

      assert full_render ==
               %{
                 0 => "hi",
                 1 => %{
                   0 => "abc",
                   1 => "efg",
                   :s => ["s1", "s2", "s3"]
                 },
                 2 => %{0 => "efg", :s => ["s1", "s2"]},
                 :s => ["<h2>", "</h2>", "<span>", "</span>"]
               }

      assert rendered_to_binary(full_render) ==
               "<h2>hi</h2>s1abcs2efgs3<span>s1efgs2</span>"

      assert socket.fingerprints == {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "comprehensions" do
      %{fingerprint: fingerprint} =
        rendered = comprehension_template(%{title: "Users", names: ["phoenix", "elixir"]})

      {socket, full_render, _} = render(rendered)

      assert full_render == %{
               0 => "Users",
               :s => ["<div>\n  <h1>", "</h1>\n  ", "\n</div>\n"],
               1 => %{
                 s: ["\n    <br/>", "\n  "],
                 d: [["phoenix"], ["elixir"]]
               }
             }

      assert {^fingerprint, %{1 => comprehension_print}} = socket.fingerprints
      assert is_integer(comprehension_print)
    end

    test "empty comprehensions" do
      # If they are empty on first render, we don't send them
      %{fingerprint: fingerprint} =
        rendered = comprehension_template(%{title: "Users", names: []})

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => "Users",
               :s => ["<div>\n  <h1>", "</h1>\n  ", "\n</div>\n"],
               1 => ""
             }

      assert {^fingerprint, inner} = socket.fingerprints
      assert inner == %{}

      # Making them non-empty adds a fingerprint
      rendered = comprehension_template(%{title: "Users", names: ["phoenix", "elixir"]})
      {socket, full_render, components} = render(rendered, socket.fingerprints, components)

      assert full_render == %{
               0 => "Users",
               1 => %{
                 d: [["phoenix"], ["elixir"]],
                 s: ["\n    <br/>", "\n  "]
               }
             }

      assert {^fingerprint, %{1 => comprehension_print}} = socket.fingerprints
      assert is_integer(comprehension_print)

      # Making them empty again does not reset the fingerprint
      rendered = comprehension_template(%{title: "Users", names: []})
      {socket, full_render, _components} = render(rendered, socket.fingerprints, components)

      assert full_render == %{
               0 => "Users",
               1 => %{d: []}
             }

      assert {^fingerprint, %{1 => ^comprehension_print}} = socket.fingerprints
    end
  end

  describe "diffed render with fingerprints" do
    test "basic template skips statics for known fingerprints" do
      rendered = basic_template(%{time: "10:30", subtitle: "Sunny"})
      {socket, full_render, _} = render(rendered, {rendered.fingerprint, %{}})

      assert full_render == %{0 => "10:30", 1 => "Sunny"}
      assert socket.fingerprints == {rendered.fingerprint, %{}}
    end

    test "renders nested %Rendered{}'s" do
      tree = {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
      {socket, diffed_render, _} = render(nested_rendered(), tree)

      assert diffed_render == %{0 => "hi", 1 => %{0 => "abc", 1 => "efg"}, 2 => %{0 => "efg"}}
      assert socket.fingerprints == tree
    end

    test "detects change in nested fingerprint" do
      old_tree = {123, %{2 => {789, %{}}, 1 => {100_001, %{}}}}
      {socket, diffed_render, _} = render(nested_rendered(), old_tree)

      assert diffed_render ==
               %{
                 0 => "hi",
                 1 => %{
                   0 => "abc",
                   1 => "efg",
                   :s => ["s1", "s2", "s3"]
                 },
                 2 => %{0 => "efg"}
               }

      assert socket.fingerprints == {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "detects change in root fingerprint" do
      old_tree = {99999, %{}}
      {socket, diffed_render, _} = render(nested_rendered(), old_tree)

      assert diffed_render == %{
               0 => "hi",
               1 => %{
                 0 => "abc",
                 1 => "efg",
                 :s => ["s1", "s2", "s3"]
               },
               2 => %{0 => "efg", :s => ["s1", "s2"]},
               :s => ["<h2>", "</h2>", "<span>", "</span>"]
             }

      assert socket.fingerprints == {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
    end
  end

  defmodule MyComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      send(self(), {:mount, socket})
      {:ok, assign(socket, hello: "world")}
    end

    def update(assigns, socket) do
      send(self(), {:update, assigns, socket})
      {:ok, assign(socket, assigns)}
    end

    def render(assigns) do
      send(self(), :render)

      ~L"""
      FROM <%= @from %> <%= @hello %>
      """
    end
  end

  defmodule TempComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      send(self(), {:temporary_mount, socket})
      {:ok, assign(socket, :first_time, true), temporary_assigns: [first_time: false]}
    end

    def render(assigns) do
      send(self(), {:temporary_render, assigns})

      ~L"""
      FROM <%= if @first_time, do: "WELCOME!", else: @from %>
      """
    end
  end

  defmodule RenderOnlyComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      RENDER ONLY <%= @from %>
      """
    end
  end

  defmodule BlockComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, :id, "DEFAULT")}
    end

    def render(%{do: _}), do: raise("unexpected :do assign")

    def render(assigns) do
      ~L"""
      HELLO <%= @id %> <%= @inner_content.(value: 1) %>
      HELLO <%= @id %> <%= @inner_content.(value: 2) %>
      """
    end
  end

  defmodule TreeComponent do
    use Phoenix.LiveComponent

    def preload(list_of_assigns) do
      send(self(), {:preload, list_of_assigns})
      Enum.map(list_of_assigns, &Map.put(&1, :preloaded?, true))
    end

    def update(assigns, socket) do
      send(self(), {:update, assigns})
      {:ok, assign(socket, assigns)}
    end

    def render(assigns) do
      ~L"""
      <%= @id %> - <%= @preloaded? %>
      <%= for {component, index} <- Enum.with_index(@children, 0) do %>
        <%= index %>: <%= component %>
      <% end %>
      """
    end
  end

  def component_template(assigns) do
    ~L"""
    <div>
      <%= @component %>
    </div>
    """
  end

  def another_component_template(assigns) do
    ~L"""
    <span>
      <%= @component %>
    </span>
    """
  end

  describe "stateless components" do
    test "on mount" do
      component = %Component{assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{0 => "component", 1 => "world", :s => ["FROM ", " ", "\n"]},
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints != {rendered.fingerprint, %{}}
      assert components == Diff.new_components()

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}}

      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received _
    end

    test "on update" do
      component = %Component{assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {previous_socket, _, previous_components} = render(rendered)

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{
               0 => %{0 => "component", 1 => "world"}
             }

      assert socket.fingerprints == previous_socket.fingerprints
      assert components == previous_components
      assert components == Diff.new_components()

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}}

      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}}

      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received _
    end

    test "render only" do
      component = %Component{assigns: %{from: :component}, component: RenderOnlyComponent}
      rendered = component_template(%{component: component})
      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 0 => "component",
                 :s => ["RENDER ONLY ", "\n"]
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints != {rendered.fingerprint, %{}}
      assert components == Diff.new_components()
    end

    test "block tracking without assigns" do
      assigns = %{socket: %Socket{changed: nil}}

      rendered = ~L"""
      <%= live_component @socket, BlockComponent do %>
        WITH VALUE <%= @value %>
      <% end %>
      """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 0 => "",
                 1 => %{0 => "1", :s => ["\n  WITH VALUE ", "\n"]},
                 2 => "",
                 3 => %{0 => "2", :s => ["\n  WITH VALUE ", "\n"]},
                 :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
               },
               :s => ["", "\n"]
             }

      {_socket, full_render, _components} = render(rendered, socket.fingerprints, components)
      assert full_render == %{0 => %{0 => "", 1 => %{0 => "1"}, 2 => "", 3 => %{0 => "2"}}}
    end

    test "block tracking" do
      assigns = %{socket: %Socket{changed: nil}}

      rendered = ~L"""
      <%= live_component @socket, BlockComponent, id: "WORLD" do %>
        WITH VALUE <%= @value %>
      <% end %>
      """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => 0,
               :s => ["", "\n"],
               :c => %{
                 0 => %{
                   0 => "WORLD",
                   1 => %{0 => "1", :s => ["\n  WITH VALUE ", "\n"]},
                   2 => "WORLD",
                   3 => %{0 => "2", :s => ["\n  WITH VALUE ", "\n"]},
                   :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
                 }
               }
             }

      {_socket, full_render, _components} = render(rendered, socket.fingerprints, components)
      assert full_render == %{0 => 0, :c => %{0 => %{}}}
    end

    test "explicit block tracking" do
      assigns = %{socket: %Socket{}}

      rendered = ~L"""
      <%= live_component @socket, BlockComponent, id: "WORLD" do %>
        <% extra -> %>
          WITH EXTRA <%= inspect(extra) %>
      <% end %>
      """

      {_socket, full_render, _components} = render(rendered)

      assert full_render == %{
               0 => 0,
               :s => ["", "\n"],
               :c => %{
                 0 => %{
                   0 => "WORLD",
                   1 => %{0 => "[value: 1]", :s => ["\n    WITH EXTRA ", "\n"]},
                   2 => "WORLD",
                   3 => %{0 => "[value: 2]", :s => ["\n    WITH EXTRA ", "\n"]},
                   :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
                 }
               }
             }
    end

    defp tracking(assigns) do
      ~L"""
      <%= live_component @socket, BlockComponent, id: "TRACKING" do %>
        WITH PARENT VALUE <%= @parent_value %>
        WITH VALUE <%= @value %>
      <% end %>
      """
    end

    test "block tracking with child and parent assigns" do
      assigns = %{socket: %Socket{changed: nil}, parent_value: 123}
      {socket, full_render, components} = render(tracking(assigns))

      assert full_render == %{
               0 => 0,
               :c => %{
                 0 => %{
                   0 => "TRACKING",
                   1 => %{
                     0 => "123",
                     :s => [
                       "\n  WITH PARENT VALUE ",
                       "\n  WITH VALUE ",
                       "\n"
                     ],
                     1 => "1"
                   },
                   2 => "TRACKING",
                   3 => %{
                     0 => "123",
                     :s => [
                       "\n  WITH PARENT VALUE ",
                       "\n  WITH VALUE ",
                       "\n"
                     ],
                     1 => "2"
                   },
                   :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
                 }
               },
               :s => ["", "\n"]
             }

      {_socket, full_render, _components} =
        render(tracking(assigns), socket.fingerprints, components)

      assert full_render == %{0 => 0, :c => %{0 => %{}}}

      assigns = %{socket: %Socket{changed: %{parent_value: true}}, parent_value: 246}

      {_socket, full_render, _components} =
        render(tracking(assigns), socket.fingerprints, components)

      assert full_render == %{
               0 => 0,
               :c => %{
                 0 => %{
                   1 => %{0 => "246", 1 => "1"},
                   3 => %{0 => "246", 1 => "2"}
                 }
               }
             }
    end
  end

  describe "stateful components" do
    test "on mount" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => 0,
               :c => %{
                 0 => %{
                   0 => "component",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 }
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints == {rendered.fingerprint, %{}}

      {_, cids_to_ids, 1} = components
      assert cids_to_ids[0] == {MyComponent, "hello"}

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: 0}

      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received _
    end

    test "on root fingerprint change" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => 0,
               :c => %{
                 0 => %{
                   0 => "component",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 }
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints == {rendered.fingerprint, %{}}

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: 0}

      assert_received :render

      another_rendered = another_component_template(%{component: component})

      {another_socket, another_full_render, _} =
        render(another_rendered, socket.fingerprints, components)

      assert another_full_render == %{
               0 => 1,
               :c => %{
                 1 => %{
                   0 => "component",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 }
               },
               :s => ["<span>\n  ", "\n</span>\n"]
             }

      assert another_socket.fingerprints == {another_rendered.fingerprint, %{}}
      assert socket.fingerprints != another_socket.fingerprints

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: 1}

      assert_received :render
    end

    test "raises on duplicate component IDs" do
      assigns = %{socket: %Socket{}}

      rendered = ~L"""
      <%= live_component @socket, RenderOnlyComponent, id: "SAME", from: "SAME" %>
      <%= live_component @socket, RenderOnlyComponent, id: "SAME", from: "SAME" %>
      """

      assert_raise RuntimeError,
                   "found duplicate ID \"SAME\" for component Phoenix.LiveView.DiffTest.RenderOnlyComponent when rendering template",
                   fn -> render(rendered) end
    end

    test "on update without render" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {previous_socket, _, previous_components} = render(rendered)

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{0 => 0, :c => %{0 => %{}}}
      assert socket.fingerprints == previous_socket.fingerprints
      assert components == previous_components

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: 0}

      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      refute_received _
    end

    test "on update with render" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {previous_socket, _, previous_components} = render(rendered)

      component = %Component{id: "hello", assigns: %{from: :rerender}, component: MyComponent}
      rendered = component_template(%{component: component})

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{0 => 0, :c => %{0 => %{0 => "rerender"}}}
      assert socket.fingerprints == previous_socket.fingerprints
      assert components != previous_components

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: 0}

      assert_received {:update, %{from: :component},
                       %Socket{assigns: %{hello: "world", myself: 0}}}

      assert_received :render

      assert_received {:update, %{from: :rerender},
                       %Socket{assigns: %{hello: "world", myself: 0}}}

      assert_received :render
      refute_received _
    end

    test "on update with temporary" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: TempComponent}
      rendered = component_template(%{component: component})
      {previous_socket, full_render, previous_components} = render(rendered)

      assert full_render == %{
               0 => 0,
               :c => %{
                 0 => %{0 => "WELCOME!", :s => ["FROM ", "\n"]}
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      component = %Component{id: "hello", assigns: %{from: :rerender}, component: TempComponent}
      rendered = component_template(%{component: component})

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{0 => 0, :c => %{0 => %{0 => "rerender"}}}
      assert socket.fingerprints == previous_socket.fingerprints
      assert components != previous_components

      assert_received {:temporary_mount, %Socket{endpoint: __MODULE__}}
      assert_received {:temporary_render, %{first_time: true}}
      assert_received {:temporary_render, %{first_time: false}}
      refute_received _
    end

    test "on preload" do
      alias Component, as: C

      tree = %C{
        component: TreeComponent,
        id: "R",
        assigns: %{
          id: "R",
          children: [
            %C{
              component: TreeComponent,
              id: "A",
              assigns: %{
                id: "A",
                children: [
                  %C{component: TreeComponent, id: "B", assigns: %{id: "B", children: []}},
                  %C{component: TreeComponent, id: "C", assigns: %{id: "C", children: []}},
                  %C{component: TreeComponent, id: "D", assigns: %{id: "D", children: []}}
                ]
              }
            },
            %C{
              component: TreeComponent,
              id: "X",
              assigns: %{
                id: "X",
                children: [
                  %C{component: TreeComponent, id: "Y", assigns: %{id: "Y", children: []}},
                  %C{component: TreeComponent, id: "Z", assigns: %{id: "Z", children: []}}
                ]
              }
            }
          ]
        }
      }

      rendered = component_template(%{component: tree})
      {socket, full_render, components} = render(rendered)

      assert %{
               c: %{
                 0 => %{0 => "R"},
                 1 => %{0 => "A"},
                 2 => %{0 => "X"},
                 3 => %{0 => "B"},
                 4 => %{0 => "C"},
                 5 => %{0 => "D"},
                 6 => %{0 => "Y"},
                 7 => %{0 => "Z"}
               }
             } = full_render

      assert socket.fingerprints == {rendered.fingerprint, %{}}
      assert {_, _, 8} = components

      assert_received {:preload, [%{id: "R"}]}
      assert_received {:preload, [%{id: "A"}, %{id: "X"}]}
      assert_received {:preload, [%{id: "B"}, %{id: "C"}, %{id: "D"}, %{id: "Y"}, %{id: "Z"}]}

      for id <- ~w(R A X B C D Y Z) do
        assert_received {:update, %{id: ^id, preloaded?: true}}
      end
    end

    test "on addition" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {previous_socket, _, previous_components} = render(rendered)

      component = %Component{id: "another", assigns: %{from: :another}, component: MyComponent}
      rendered = component_template(%{component: component})

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{0 => "another", 1 => "world", :s => ["FROM ", " ", "\n"]}
               }
             }

      assert socket.fingerprints == previous_socket.fingerprints
      assert components != previous_components

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :another}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received _
    end

    test "duplicate IDs" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: TempComponent}
      rendered = component_template(%{component: component})
      {previous_socket, _, previous_components} = render(rendered)

      component = %Component{id: "hello", assigns: %{from: :replaced}, component: MyComponent}
      rendered = component_template(%{component: component})

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{0 => "replaced", 1 => "world", :s => ["FROM ", " ", "\n"]}
               }
             }

      assert socket.fingerprints == previous_socket.fingerprints
      assert components != previous_components

      assert_received {:temporary_mount, %Socket{endpoint: __MODULE__}}
      assert_received {:temporary_render, %{first_time: true, from: :component}}
      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :replaced}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received _
    end

    test "inside comprehension" do
      components = [
        %Component{id: "index_0", assigns: %{from: :index_0}, component: MyComponent},
        %Component{id: "index_1", assigns: %{from: :index_1}, component: MyComponent}
      ]

      assigns = %{components: components}

      %{fingerprint: fingerprint} =
        rendered = ~L"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 0) do %>
            <%= index %>: <%= component %>
          <% end %>
        </div>
        """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 d: [["0", 0], ["1", 1]],
                 s: ["\n    ", ": ", "\n  "]
               },
               :c => %{
                 0 => %{
                   0 => "index_0",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 },
                 1 => %{
                   0 => "index_1",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 }
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert {^fingerprint, %{0 => _}} = socket.fingerprints

      {_, cids_to_ids, 2} = components
      assert cids_to_ids[0] == {MyComponent, "index_0"}
      assert cids_to_ids[1] == {MyComponent, "index_1"}

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_0}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_1}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
    end

    test "inside nested comprehension" do
      components = [
        %Component{id: "index_0", assigns: %{from: :index_0}, component: MyComponent},
        %Component{id: "index_1", assigns: %{from: :index_1}, component: MyComponent}
      ]

      assigns = %{components: components, ids: ["foo", "bar"]}

      %{fingerprint: fingerprint} =
        rendered = ~L"""
        <div>
          <%= for prefix_id <- @ids do %>
            <%= prefix_id %>
            <%= for {component, index} <- Enum.with_index(@components, 0) do %>
              <%= index %>: <%= %{component | id: "#{prefix_id}-#{component.id}"} %>
            <% end %>
          <% end %>
        </div>
        """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 d: [
                   [
                     "foo",
                     %{d: [["0", 0], ["1", 1]], s: ["\n      ", ": ", "\n    "]}
                   ],
                   [
                     "bar",
                     %{d: [["0", 2], ["1", 3]], s: ["\n      ", ": ", "\n    "]}
                   ]
                 ],
                 s: ["\n    ", "\n    ", "\n  "]
               },
               :c => %{
                 0 => %{
                   0 => "index_0",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 },
                 1 => %{
                   0 => "index_1",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 },
                 2 => %{
                   0 => "index_0",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 },
                 3 => %{
                   0 => "index_1",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 }
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert {^fingerprint, %{0 => _}} = socket.fingerprints

      {_, cids_to_ids, 4} = components
      assert cids_to_ids[0] == {MyComponent, "foo-index_0"}
      assert cids_to_ids[1] == {MyComponent, "foo-index_1"}
      assert cids_to_ids[2] == {MyComponent, "bar-index_0"}
      assert cids_to_ids[3] == {MyComponent, "bar-index_1"}

      for from <- [:index_0, :index_1, :index_0, :index_1] do
        assert_received {:mount, %Socket{endpoint: __MODULE__}}
        assert_received {:update, %{from: ^from}, %Socket{assigns: %{hello: "world"}}}
        assert_received :render
      end
    end

    test "inside rendered inside comprehension" do
      components = [
        %Component{id: "index_0", assigns: %{from: :index_0}, component: MyComponent},
        %Component{id: "index_1", assigns: %{from: :index_1}, component: MyComponent}
      ]

      assigns = %{components: components}

      %{fingerprint: fingerprint} =
        rendered = ~L"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 0) do %>
            <%= index %>: <%= component_template(%{component: component}) %>
          <% end %>
        </div>
        """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 d: [
                   [
                     "0",
                     %{0 => 0, :s => ["<div>\n  ", "\n</div>\n"]}
                   ],
                   [
                     "1",
                     %{0 => 1, :s => ["<div>\n  ", "\n</div>\n"]}
                   ]
                 ],
                 s: ["\n    ", ": ", "\n  "]
               },
               :c => %{
                 0 => %{
                   0 => "index_0",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 },
                 1 => %{
                   0 => "index_1",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 }
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert {^fingerprint, %{0 => _}} = socket.fingerprints

      {_, cids_to_ids, 2} = components
      assert cids_to_ids[0] == {MyComponent, "index_0"}
      assert cids_to_ids[1] == {MyComponent, "index_1"}

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_0}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_1}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
    end

    test "inside condition inside comprehension" do
      components = [
        %Component{id: "index_0", assigns: %{from: :index_0}, component: MyComponent},
        %Component{id: "index_1", assigns: %{from: :index_1}, component: MyComponent}
      ]

      assigns = %{components: components}

      %{fingerprint: fingerprint} =
        rendered = ~L"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 0) do %>
            <%= if index > 0 do %><%= index %>: <%= component %><% end %>
          <% end %>
        </div>
        """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 d: [
                   [""],
                   [%{0 => "1", 1 => 0, :s => ["", ": ", ""]}]
                 ],
                 s: ["\n    ", "\n  "]
               },
               :c => %{
                 0 => %{
                   0 => "index_1",
                   1 => "world",
                   :s => ["FROM ", " ", "\n"]
                 }
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert {^fingerprint, %{0 => _}} = socket.fingerprints

      {_, cids_to_ids, 1} = components
      assert cids_to_ids[0] == {MyComponent, "index_1"}

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_1}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received {:update, %{from: :index_0}, %Socket{assigns: %{hello: "world"}}}
    end
  end
end

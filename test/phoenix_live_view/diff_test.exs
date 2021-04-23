defmodule Phoenix.LiveView.DiffTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView.Helpers

  alias Phoenix.LiveView.{Socket, Diff, Rendered, Component}
  alias Phoenix.LiveComponent.CID

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

  defp nested_rendered(changed? \\ true) do
    %Rendered{
      static: ["<h2>", "</h2>", "<span>", "</span>"],
      dynamic: fn _ ->
        [
          "hi",
          %Rendered{
            static: ["s1", "s2", "s3"],
            dynamic: fn _ -> if changed?, do: ["abc", "efg"], else: [nil, nil] end,
            fingerprint: 456
          },
          %Rendered{
            static: ["s1", "s2"],
            dynamic: fn _ -> if changed?, do: ["efg"], else: [nil] end,
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

  describe "to_iodata" do
    test "with subtrees chain" do
      assert rendered_to_binary(%{
               0 => %{d: [["1", 1], ["2", 2], ["3", 3]], s: ["\n", ":", ""]},
               :c => %{
                 1 => %{0 => %{0 => "index_1", :s => ["\nIF ", ""]}, :s => ["", ""]},
                 2 => %{0 => %{0 => "index_2", :s => ["\nELSE ", ""]}, :s => 1},
                 3 => %{0 => %{0 => "index_3"}, :s => 2}
               },
               :s => ["<div>", "\n</div>\n"]
             }) == """
             <div>
             1:
             IF index_1
             2:
             ELSE index_2
             3:
             ELSE index_3
             </div>
             """
    end

    test "with subtrees where a comprehension is replaced by rendered" do
      assert rendered_to_binary(%{
               0 => 1,
               1 => 2,
               :c => %{
                 1 => %{
                   0 => %{
                     0 => %{d: [[], [], []], s: ["ROW"]},
                     :s => ["\n", "\n"]
                   },
                   :s => ["<div>", "</div>"]
                 },
                 2 => %{
                   0 => %{
                     0 => %{0 => "BAR", :s => ["FOO", "BAZ"]},
                     :s => ["\n", "\n"]
                   },
                   :s => 1
                 }
               },
               :s => ["", "", ""]
             }) == "<div>\nROWROWROW\n</div><div>\nFOOBARBAZ\n</div>"
    end
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

    test "nested %Rendered{}'s" do
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

    test "does not emit nested %Rendered{}'s if they did not change" do
      tree = {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
      {socket, diffed_render, _} = render(nested_rendered(false), tree)

      assert diffed_render == %{0 => "hi"}
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

  defmodule IfComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, if: true)}
    end

    def render(assigns) do
      ~L"""
      <%= if @if do %>
        IF <%= @from %>
      <% else %>
        ELSE <%= @from %>
      <% end %>
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
      {:ok, assign(socket, id: "DEFAULT")}
    end

    def render(%{do: _}), do: raise("unexpected :do assign")

    def render(assigns) do
      ~L"""
      HELLO <%= @id %> <%= render_block(@inner_block, value: 1) %>
      HELLO <%= @id %> <%= render_block(@inner_block, value: 2) %>
      """
    end
  end

  defmodule BlockNoArgsComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, id: "DEFAULT")}
    end

    def render(%{do: _}), do: raise("unexpected :do assign")

    def render(assigns) do
      ~L"""
      HELLO <%= @id %> <%= render_block(@inner_block) %>
      HELLO <%= @id %> <%= render_block(@inner_block) %>
      """
    end
  end

  defmodule FunctionComponent do
    def render_only(assigns) do
      ~L"""
      RENDER ONLY <%= @from %>
      """
    end

    def render_with_block_no_args(assigns) do
      ~L"""
      HELLO <%= @id %> <%= render_block(@inner_block) %>
      HELLO <%= @id %> <%= render_block(@inner_block) %>
      """
    end

    def render_with_block(assigns) do
      ~L"""
      HELLO <%= @id %> <%= render_block(@inner_block, 1) %>
      HELLO <%= @id %> <%= render_block(@inner_block, 2) %>
      """
    end

    def render_with_live_component(assigns) do
      ~L"""
      COMPONENT
      <%= live_component BlockComponent, id: "WORLD" do %>
        WITH VALUE <%= @value %>
      <% end %>
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

  defmodule NestedDynamicComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      <%= render_itself(assigns) %>
      """
    end

    def render_itself(assigns) do
      case assigns.key do
        :a ->
          ~L"""
          <%= for key <- [:nothing] do %>
            <%= key %><%= key %>
          <% end %>
          """

        :b ->
          ~L"""
          <%= %>
          """

        :c ->
          ~L"""
          <%= live_component __MODULE__, id: make_ref(), key: :a %>
          """
      end
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

    test "block tracking" do
      assigns = %{socket: %Socket{}}

      rendered = ~L"""
      <%= live_component BlockNoArgsComponent do %>
        INSIDE BLOCK
      <% end %>
      """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 0 => "",
                 1 => %{s: ["\n  INSIDE BLOCK\n"]},
                 2 => "",
                 3 => %{s: ["\n  INSIDE BLOCK\n"]},
                 :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
               },
               :s => ["", "\n"]
             }

      {_socket, full_render, _components} = render(rendered, socket.fingerprints, components)
      assert full_render ==  %{0 => %{0 => "", 2 => ""}}
    end
  end

  describe "function components" do
    test "render only" do
      assigns = %{socket: %Socket{}}

      rendered = ~L"""
      <%= component &FunctionComponent.render_only/1, from: :component %>
      """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 0 => "component",
                 :s => ["RENDER ONLY ", "\n"]
               },
               :s => ["", "\n"]
             }

      assert socket.fingerprints != {rendered.fingerprint, %{}}
      assert components == Diff.new_components()
    end

    test "block tracking without args" do
      assigns = %{socket: %Socket{}}

      rendered = ~L"""
      <%= component &FunctionComponent.render_with_block_no_args/1, id: "DEFAULT" do %>
        INSIDE BLOCK
      <% end %>
      """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 0 => "DEFAULT",
                 1 => %{s: ["\n  INSIDE BLOCK\n"]},
                 2 => "DEFAULT",
                 3 => %{s: ["\n  INSIDE BLOCK\n"]},
                 :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
               },
               :s => ["", "\n"]
             }

      {_socket, full_render, _components} = render(rendered, socket.fingerprints, components)
      assert full_render == %{0 => %{0 => "DEFAULT", 2 => "DEFAULT"}}
    end

    defp function_tracking(assigns) do
      ~L"""
      <%= component &FunctionComponent.render_with_block/1, id: @id do %>
        <% value -> %>
          WITH VALUE <%= value %> - <%= @value %>
      <% end %>
      """
    end

    test "block tracking with args and parent assign" do
      assigns = %{socket: %Socket{}, value: 123, id: "DEFAULT"}

      {socket, full_render, components} = render(function_tracking(assigns))

      assert full_render == %{
               0 => %{
                 0 => "DEFAULT",
                 1 => %{0 => "1", :s => ["\n    WITH VALUE ", " - ", "\n"], 1 => "123"},
                 2 => "DEFAULT",
                 3 => %{0 => "2", :s => ["\n    WITH VALUE ", " - ", "\n"], 1 => "123"},
                 :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
               },
               :s => ["", "\n"]
             }

      {_socket, full_render, _components} =
        render(function_tracking(assigns), socket.fingerprints, components)

      assert full_render == %{
               0 => %{
                 0 => "DEFAULT",
                 1 => %{0 => "1", 1 => "123"},
                 2 => "DEFAULT",
                 3 => %{0 => "2", 1 => "123"}
               }
             }

      assigns = Map.put(assigns, :__changed__, %{})

      {_socket, full_render, _components} =
        render(function_tracking(assigns), socket.fingerprints, components)

      assert full_render == %{}

      assigns = Map.put(assigns, :__changed__, %{id: true})

      {_socket, full_render, _components} =
        render(function_tracking(assigns), socket.fingerprints, components)

      assert full_render == %{
               0 => %{
                 0 => "DEFAULT",
                 1 => %{0 => "1"},
                 2 => "DEFAULT",
                 3 => %{0 => "2"}
               }
             }

      assigns = Map.put(assigns, :__changed__, %{value: true})

      {_socket, full_render, _components} =
        render(function_tracking(assigns), socket.fingerprints, components)

      assert full_render == %{
               0 => %{
                 0 => "DEFAULT",
                 1 => %{0 => "1", 1 => "123"},
                 2 => "DEFAULT",
                 3 => %{0 => "2", 1 => "123"}
               }
             }
    end

    test "with live_component" do
      assigns = %{socket: %Socket{}}

      rendered = ~L"""
      <%= component &FunctionComponent.render_with_live_component/1 %>
      """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{0 => 1, :s => ["COMPONENT\n", "\n"]},
               :c => %{
                 1 => %{
                   0 => "WORLD",
                   1 => %{0 => "1", :s => ["\n  WITH VALUE ", "\n"]},
                   2 => "WORLD",
                   3 => %{0 => "2", :s => ["\n  WITH VALUE ", "\n"]},
                   :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
                 }
               },
               :s => ["", "\n"]
             }

      {_socket, full_render, _components} = render(rendered, socket.fingerprints, components)
      assert full_render == %{0 => %{0 => 1}}
    end
  end

  describe "stateful components" do
    test "on mount" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => 1,
               :c => %{1 => %{0 => "component", 1 => "world", :s => ["FROM ", " ", "\n"]}},
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints == {rendered.fingerprint, %{}}

      {cid_to_component, _, 2} = components
      assert {MyComponent, "hello", _, _, _} = cid_to_component[1]

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: %CID{cid: 1}}

      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received _
    end

    test "on root fingerprint change" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => 1,
               :c => %{1 => %{0 => "component", 1 => "world", :s => ["FROM ", " ", "\n"]}},
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints == {rendered.fingerprint, %{}}

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: %CID{cid: 1}}

      assert_received :render

      another_rendered = another_component_template(%{component: component})

      {another_socket, another_full_render, _} =
        render(another_rendered, socket.fingerprints, components)

      assert another_full_render == %{
               0 => 2,
               :c => %{2 => %{0 => "component", 1 => "world", :s => ["FROM ", " ", "\n"]}},
               :s => ["<span>\n  ", "\n</span>\n"]
             }

      assert another_socket.fingerprints == {another_rendered.fingerprint, %{}}
      assert socket.fingerprints != another_socket.fingerprints

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: %CID{cid: 2}}

      assert_received :render
    end

    test "raises on duplicate component IDs" do
      assigns = %{socket: %Socket{}}

      rendered = ~L"""
      <%= live_component RenderOnlyComponent, id: "SAME", from: "SAME" %>
      <%= live_component RenderOnlyComponent, id: "SAME", from: "SAME" %>
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

      assert full_render == %{0 => 1}
      assert socket.fingerprints == previous_socket.fingerprints
      assert components == previous_components

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: %CID{cid: 1}}

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

      assert full_render == %{0 => 1, :c => %{1 => %{0 => "rerender"}}}
      assert socket.fingerprints == previous_socket.fingerprints
      assert components != previous_components

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
                      when assigns == %{flash: %{}, myself: %CID{cid: 1}}

      assert_received {:update, %{from: :component},
                       %Socket{assigns: %{hello: "world", myself: %CID{cid: 1}}}}

      assert_received :render

      assert_received {:update, %{from: :rerender},
                       %Socket{assigns: %{hello: "world", myself: %CID{cid: 1}}}}

      assert_received :render
      refute_received _
    end

    test "on update with temporary" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: TempComponent}
      rendered = component_template(%{component: component})
      {previous_socket, full_render, previous_components} = render(rendered)

      assert full_render == %{
               0 => 1,
               :c => %{1 => %{0 => "WELCOME!", :s => ["FROM ", "\n"]}},
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      component = %Component{id: "hello", assigns: %{from: :rerender}, component: TempComponent}
      rendered = component_template(%{component: component})

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{0 => 1, :c => %{1 => %{0 => "rerender"}}}
      assert socket.fingerprints == previous_socket.fingerprints
      assert components != previous_components

      assert_received {:temporary_mount, %Socket{endpoint: __MODULE__}}
      assert_received {:temporary_render, %{first_time: true}}
      assert_received {:temporary_render, %{first_time: false}}
      refute_received _
    end

    test "on update with stateless/stateful swap" do
      component = %Component{assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {socket, diff, components} = render(rendered)

      assert diff == %{
               0 => %{0 => "component", 1 => "world", :s => ["FROM ", " ", "\n"]},
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert {root_prints, %{0 => {_, %{}}}} = socket.fingerprints
      assert {_, _, 1} = components

      component = %Component{id: "hello", assigns: %{from: :rerender}, component: MyComponent}
      rendered = component_template(%{component: component})

      {socket, diff, components} = render(rendered, socket.fingerprints, components)

      assert diff == %{
               0 => 1,
               :c => %{1 => %{0 => "rerender", 1 => "world", :s => ["FROM ", " ", "\n"]}}
             }

      assert socket.fingerprints == {root_prints, %{}}
      assert {_, _, 2} = components
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
                 1 => %{0 => "R"},
                 2 => %{0 => "A"},
                 3 => %{0 => "X"},
                 4 => %{0 => "B"},
                 5 => %{0 => "C"},
                 6 => %{0 => "D"},
                 7 => %{0 => "Y"},
                 8 => %{0 => "Z"}
               }
             } = full_render

      assert socket.fingerprints == {rendered.fingerprint, %{}}
      assert {_, _, 9} = components

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

      assert full_render == %{0 => 2, :c => %{2 => %{0 => "another", 1 => "world", :s => -1}}}

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
               0 => 2,
               :c => %{2 => %{0 => "replaced", 1 => "world", :s => ["FROM ", " ", "\n"]}}
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
        %Component{id: "index_1", assigns: %{from: :index_1}, component: MyComponent},
        %Component{id: "index_2", assigns: %{from: :index_2}, component: MyComponent}
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
               0 => %{d: [["0", 1], ["1", 2]], s: ["\n    ", ": ", "\n  "]},
               :c => %{
                 1 => %{0 => "index_1", 1 => "world", :s => ["FROM ", " ", "\n"]},
                 2 => %{0 => "index_2", 1 => "world", :s => 1}
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert {^fingerprint, %{0 => _}} = socket.fingerprints

      {cid_to_component, _, 3} = components
      assert {MyComponent, "index_1", _, _, _} = cid_to_component[1]
      assert {MyComponent, "index_2", _, _, _} = cid_to_component[2]

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_1}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_2}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
    end

    test "inside comprehension with subtree" do
      template = fn components ->
        assigns = %{components: components}

        ~L"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 0) do %>
            <%= index %>: <%= component %>
          <% end %>
        </div>
        """
      end

      # We start by rendering two components
      components = [
        %Component{id: "index_1", assigns: %{from: :index_1}, component: IfComponent},
        %Component{id: "index_2", assigns: %{from: :index_2}, component: IfComponent}
      ]

      {socket, full_render, diff_components} = render(template.(components))

      assert full_render == %{
               0 => %{d: [["0", 1], ["1", 2]], s: ["\n    ", ": ", "\n  "]},
               :c => %{
                 1 => %{0 => %{0 => "index_1", :s => ["\n  IF ", "\n"]}, :s => ["", "\n"]},
                 2 => %{0 => %{0 => "index_2"}, :s => 1}
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      {cid_to_component, _, 3} = diff_components
      assert {IfComponent, "index_1", _, _, _} = cid_to_component[1]
      assert {IfComponent, "index_2", _, _, _} = cid_to_component[2]

      # Now let's add a third component, it shall reuse index_1
      components = [
        %Component{id: "index_3", assigns: %{from: :index_3}, component: IfComponent}
      ]

      {socket, diff, diff_components} =
        render(template.(components), socket.fingerprints, diff_components)

      assert diff == %{
               0 => %{d: [["0", 3]]},
               :c => %{3 => %{0 => %{0 => "index_3"}, :s => -1}}
             }

      {cid_to_component, _, 4} = diff_components
      assert {IfComponent, "index_3", _, _, _} = cid_to_component[3]

      # Now let's add a fourth component, with a different subtree than index_0
      components = [
        %Component{id: "index_4", assigns: %{from: :index_4, if: false}, component: IfComponent}
      ]

      {socket, diff, diff_components} =
        render(template.(components), socket.fingerprints, diff_components)

      assert diff == %{
               0 => %{d: [["0", 4]]},
               :c => %{4 => %{0 => %{0 => "index_4", :s => ["\n  ELSE ", "\n"]}, :s => -1}}
             }

      {cid_to_component, _, 5} = diff_components
      assert {IfComponent, "index_4", _, _, _} = cid_to_component[4]

      # Finally, let's add a fifth component while changing the first component at the same time.
      # We should point to the index tree of index_0 before render.
      components = [
        %Component{id: "index_1", assigns: %{from: :index_1, if: false}, component: IfComponent},
        %Component{id: "index_5", assigns: %{from: :index_5}, component: IfComponent}
      ]

      {_socket, diff, diff_components} =
        render(template.(components), socket.fingerprints, diff_components)

      assert diff == %{
               0 => %{d: [["0", 1], ["1", 5]]},
               :c => %{
                 1 => %{0 => %{0 => "index_1", :s => ["\n  ELSE ", "\n"]}},
                 5 => %{0 => %{0 => "index_5"}, :s => -1}
               }
             }

      {cid_to_component, _, 6} = diff_components
      assert {IfComponent, "index_5", _, _, _} = cid_to_component[5]
    end

    test "inside nested comprehension" do
      components = [
        %Component{id: "index_1", assigns: %{from: :index_1}, component: MyComponent},
        %Component{id: "index_2", assigns: %{from: :index_2}, component: MyComponent}
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
                   ["foo", %{d: [["0", 1], ["1", 2]], s: ["\n      ", ": ", "\n    "]}],
                   ["bar", %{d: [["0", 3], ["1", 4]], s: ["\n      ", ": ", "\n    "]}]
                 ],
                 s: ["\n    ", "\n    ", "\n  "]
               },
               :c => %{
                 1 => %{0 => "index_1", 1 => "world", :s => ["FROM ", " ", "\n"]},
                 2 => %{0 => "index_2", 1 => "world", :s => 1},
                 3 => %{0 => "index_1", 1 => "world", :s => 1},
                 4 => %{0 => "index_2", 1 => "world", :s => 3}
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert {^fingerprint, %{0 => _}} = socket.fingerprints

      {cid_to_component, _, 5} = components
      assert {MyComponent, "foo-index_1", _, _, _} = cid_to_component[1]
      assert {MyComponent, "foo-index_2", _, _, _} = cid_to_component[2]
      assert {MyComponent, "bar-index_1", _, _, _} = cid_to_component[3]
      assert {MyComponent, "bar-index_2", _, _, _} = cid_to_component[4]

      for from <- [:index_1, :index_2, :index_1, :index_2] do
        assert_received {:mount, %Socket{endpoint: __MODULE__}}
        assert_received {:update, %{from: ^from}, %Socket{assigns: %{hello: "world"}}}
        assert_received :render
      end
    end

    test "inside rendered inside comprehension" do
      components = [
        %Component{id: "index_1", assigns: %{from: :index_1}, component: MyComponent},
        %Component{id: "index_2", assigns: %{from: :index_2}, component: MyComponent}
      ]

      assigns = %{components: components}

      %{fingerprint: fingerprint} =
        rendered = ~L"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 1) do %>
            <%= index %>: <%= component_template(%{component: component}) %>
          <% end %>
        </div>
        """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 d: [
                   ["1", %{0 => 1, :s => ["<div>\n  ", "\n</div>\n"]}],
                   ["2", %{0 => 2, :s => ["<div>\n  ", "\n</div>\n"]}]
                 ],
                 s: ["\n    ", ": ", "\n  "]
               },
               :c => %{
                 1 => %{0 => "index_1", 1 => "world", :s => ["FROM ", " ", "\n"]},
                 2 => %{0 => "index_2", 1 => "world", :s => 1}
               },
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert {^fingerprint, %{0 => _}} = socket.fingerprints

      {cid_to_component, _, 3} = components
      assert {MyComponent, "index_1", _, _, _} = cid_to_component[1]
      assert {MyComponent, "index_2", _, _, _} = cid_to_component[2]

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_1}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_2}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
    end

    test "inside condition inside comprehension" do
      components = [
        %Component{id: "index_1", assigns: %{from: :index_1}, component: MyComponent},
        %Component{id: "index_2", assigns: %{from: :index_2}, component: MyComponent}
      ]

      assigns = %{components: components}

      %{fingerprint: fingerprint} =
        rendered = ~L"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 1) do %>
            <%= if index > 1 do %><%= index %>: <%= component %><% end %>
          <% end %>
        </div>
        """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 d: [[""], [%{0 => "2", 1 => 1, :s => ["", ": ", ""]}]],
                 s: ["\n    ", "\n  "]
               },
               :c => %{1 => %{0 => "index_2", 1 => "world", :s => ["FROM ", " ", "\n"]}},
               :s => ["<div>\n  ", "\n</div>\n"]
             }

      assert {^fingerprint, %{0 => _}} = socket.fingerprints

      {cid_to_component, _, 2} = components
      assert {MyComponent, "index_2", _, _, _} = cid_to_component[1]

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :index_2}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received {:update, %{from: :index_1}, %Socket{assigns: %{hello: "world"}}}
    end

    test "inside comprehension inside live_component without static" do
      assigns = %{socket: %Socket{}}

      %{fingerprint: _fingerprint} =
        rendered = ~L"""
        <%= for key <- [:b, :c, :a] do %>
          <%= live_component(NestedDynamicComponent, id: key, key: key) %>
        <% end %>
        """

      {_socket, full_render, _components} = render(rendered)

      assert full_render == %{
               0 => %{d: [[1], [2], [3]], s: ["\n  ", "\n"]},
               :c => %{
                 1 => %{0 => %{0 => "", :s => ["", "\n"]}, :s => ["", "\n"]},
                 2 => %{0 => %{0 => 4, :s => ["", "\n"]}, :s => 1},
                 3 => %{
                   0 => %{
                     0 => %{d: [["nothing", "nothing"]], s: ["\n  ", "", "\n"]},
                     :s => ["", "\n"]
                   },
                   :s => 1
                 },
                 4 => %{0 => %{0 => %{d: [["nothing", "nothing"]]}}, :s => 3}
               },
               :s => ["", "\n"]
             }

      assert rendered_to_binary(full_render) =~ "nothingnothing"
    end

    test "block tracking" do
      assigns = %{socket: %Socket{}}

      rendered = ~L"""
      <%= live_component BlockComponent, id: "WORLD" do %>
        WITH VALUE <%= @value %>
      <% end %>
      """

      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{
                   0 => "WORLD",
                   1 => %{0 => "1", :s => ["\n  WITH VALUE ", "\n"]},
                   2 => "WORLD",
                   3 => %{0 => "2", :s => ["\n  WITH VALUE ", "\n"]},
                   :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
                 }
               },
               :s => ["", "\n"]
             }

      {_socket, full_render, _components} = render(rendered, socket.fingerprints, components)
      assert full_render == %{0 => 1}
    end

    defp tracking(assigns) do
      ~L"""
      <%= live_component BlockComponent, %{id: "TRACKING"} do %>
        WITH PARENT VALUE <%= @parent_value %>
        WITH VALUE <%= @value %>
      <% end %>
      """
    end

    # TODO: Change this to "with args and parent assign" once we deprecate implicit assigns
    test "block tracking with child and parent assigns" do
      assigns = %{socket: %Socket{}, parent_value: 123}
      {socket, full_render, components} = render(tracking(assigns))

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{
                   0 => "TRACKING",
                   1 => %{
                     0 => "123",
                     1 => "1",
                     :s => ["\n  WITH PARENT VALUE ", "\n  WITH VALUE ", "\n"]
                   },
                   2 => "TRACKING",
                   3 => %{
                     0 => "123",
                     1 => "2",
                     :s => ["\n  WITH PARENT VALUE ", "\n  WITH VALUE ", "\n"]
                   },
                   :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
                 }
               },
               :s => ["", "\n"]
             }

      {_socket, full_render, _components} =
        render(tracking(assigns), socket.fingerprints, components)

      assert full_render == %{0 => 1}

      # Changing the root assign
      assigns = %{socket: %Socket{}, parent_value: 123, __changed__: %{parent_value: true}}

      {_socket, full_render, _components} =
        render(tracking(assigns), socket.fingerprints, components)

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{
                   1 => %{0 => "123", 1 => "1"},
                   3 => %{0 => "123", 1 => "2"}
                 }
               }
             }
    end
  end
end

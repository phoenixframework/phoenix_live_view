defmodule Phoenix.LiveView.DiffTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView,
    only: [sigil_L: 2, live_component: 2, live_component: 3, live_component: 4]

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

  defp render(
         rendered,
         fingerprints \\ Diff.new_fingerprints(),
         components \\ Diff.new_components()
       ) do
    Diff.render(%Socket{endpoint: __MODULE__, fingerprints: fingerprints}, rendered, components)
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

      assert socket.fingerprints == {rendered.fingerprint, %{}}
    end

    test "template with literal" do
      rendered = literal_template(%{title: "foo"})
      {socket, full_render, _} = render(rendered)

      assert full_render ==
               %{0 => "foo", 1 => "&lt;div&gt;", :s => ["<div>\n  ", "\n  ", "\n</div>\n"]}

      assert socket.fingerprints == {rendered.fingerprint, %{}}
    end

    test "nested %Renderered{}'s" do
      {socket, full_render, _} = render(@nested)

      assert full_render ==
               %{
                 :s => ["<h2>...", "\n<span>", "</span>\n"],
                 0 => "hi",
                 1 => %{0 => "abc", :s => ["s1", "s2", "s3"]},
                 3 => %{0 => "efg", :s => ["s1", "s2"]}
               }

      assert socket.fingerprints == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "comprehensions" do
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

      assert socket.fingerprints == {rendered.fingerprint, %{1 => :comprehension}}
    end
  end

  describe "diffed render with fingerprints" do
    test "basic template skips statics for known fingerprints" do
      rendered = basic_template(%{time: "10:30", subtitle: "Sunny"})
      {socket, full_render, _} = render(rendered, {rendered.fingerprint, %{}})

      assert full_render == %{0 => "10:30", 1 => "Sunny"}
      assert socket.fingerprints == {rendered.fingerprint, %{}}
    end

    test "renders nested %Renderered{}'s" do
      tree = {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
      {socket, diffed_render, _} = render(@nested, tree)

      assert diffed_render == %{0 => "hi", 1 => %{0 => "abc"}, 3 => %{0 => "efg"}}
      assert socket.fingerprints == tree
    end

    test "detects change in nested fingerprint" do
      old_tree = {123, %{3 => {789, %{}}, 1 => {100_001, %{}}}}
      {socket, diffed_render, _} = render(@nested, old_tree)

      assert diffed_render ==
               %{0 => "hi", 3 => %{0 => "efg"}, 1 => %{0 => "abc", :s => ["s1", "s2", "s3"]}}

      assert socket.fingerprints == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "detects change in root fingerprint" do
      old_tree = {99999, %{}}
      {socket, diffed_render, _} = render(@nested, old_tree)

      assert diffed_render == %{
               0 => "hi",
               1 => %{0 => "abc", :s => ["s1", "s2", "s3"]},
               3 => %{0 => "efg", :s => ["s1", "s2"]},
               :s => ["<h2>...", "\n<span>", "</span>\n"]
             }

      assert socket.fingerprints == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
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

    def render(assigns) do
      ~L"""
      HELLO <%= @id %> <%= @inner_content.(value: 1) %>
      HELLO <%= @id %> <%= @inner_content.(value: 2) %>
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

  def components_template(assigns) do
    ~L"""
    <div>
      <%= for {component, index} <- Enum.with_index(@components, 0) do %>
        <%= index %>: <%= component %>
      <% end %>
    </div>
    """
  end

  def nested_components_template(assigns) do
    ~L"""
    <div>
      <%= for prefix_id <- @ids do %>
        <%= prefix_id %>
        <%= for {component, index} <- Enum.with_index(@components, 0) do %>
          <%= index %>: <%= %{component | id: "#{prefix_id}-#{component.id}"} %>
        <% end %>
      <% end %>
    </div>
    """
  end

  def rendered_components_template(assigns) do
    ~L"""
    <div>
      <%= for {component, index} <- Enum.with_index(@components, 0) do %>
        <%= index %>: <%= component_template(%{component: component}) %>
      <% end %>
    </div>
    """
  end

  def block_component_template(assigns) do
    ~L"""
    <%= live_component @socket, BlockComponent, id: "WORLD" do %>
      WITH VALUE <%= @value %>
    <% end %>
    """
  end

  def explicit_block_component_template(assigns) do
    ~L"""
    <%= live_component @socket, BlockComponent, id: "WORLD" do %>
      <% extra -> %>
        WITH EXTRA <%= inspect(extra) %>
    <% end %>
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

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
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

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      assert_received {:mount, %Socket{endpoint: __MODULE__}}
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
      rendered = block_component_template(%{socket: %Socket{}})
      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               :s => ["", "\n"],
               0 => %{
                 0 => "WORLD",
                 1 => %{0 => "1", :s => ["\n  WITH VALUE ", "\n"]},
                 2 => "WORLD",
                 3 => %{0 => "2", :s => ["\n  WITH VALUE ", "\n"]},
                 :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
               }
             }

      assert socket.fingerprints != {rendered.fingerprint, %{}}
      assert components == Diff.new_components()
    end

    test "explicit block tracking" do
      rendered = explicit_block_component_template(%{socket: %Socket{}})
      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 0 => "WORLD",
                 1 => %{
                   0 => "[value: 1]",
                   :s => ["\n    WITH EXTRA ", "\n"]
                 },
                 2 => "WORLD",
                 3 => %{
                   0 => "[value: 2]",
                   :s => ["\n    WITH EXTRA ", "\n"]
                 },
                 :s => ["HELLO ", " ", "\nHELLO ", " ", "\n"]
               },
               :s => ["", "\n"]
             }

      assert socket.fingerprints != {rendered.fingerprint, %{}}
      assert components == Diff.new_components()
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

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received _
    end

    test "on update without render" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {previous_socket, _, previous_components} = render(rendered)

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{0 => 0}
      assert socket.fingerprints == previous_socket.fingerprints
      assert components == previous_components

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
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

      assert_received {:mount, %Socket{endpoint: __MODULE__}}
      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      assert_received {:update, %{from: :rerender}, %Socket{assigns: %{hello: "world"}}}
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

      rendered = components_template(%{components: components})
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

      assert socket.fingerprints == {rendered.fingerprint, %{0 => :comprehension}}

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

      rendered = nested_components_template(%{components: components, ids: ["foo", "bar"]})
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

      assert socket.fingerprints == {rendered.fingerprint, %{0 => :comprehension}}

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

      rendered = rendered_components_template(%{components: components})
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

      assert socket.fingerprints == {rendered.fingerprint, %{0 => :comprehension}}

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
  end
end

defmodule Phoenix.LiveView.DiffTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveView, only: [sigil_L: 2]

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
               :static => ["<div>\n  <h2>It's ", "</h2>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints == {rendered.fingerprint, %{}}
    end

    test "template with literal" do
      rendered = literal_template(%{title: "foo"})
      {socket, full_render, _} = render(rendered)

      assert full_render ==
               %{0 => "foo", 1 => "&lt;div&gt;", :static => ["<div>\n  ", "\n  ", "\n</div>\n"]}

      assert socket.fingerprints == {rendered.fingerprint, %{}}
    end

    test "nested %Renderered{}'s" do
      {socket, full_render, _} = render(@nested)

      assert full_render ==
               %{
                 :static => ["<h2>...", "\n<span>", "</span>\n"],
                 0 => "hi",
                 1 => %{0 => "abc", :static => ["s1", "s2", "s3"]},
                 3 => %{0 => "efg", :static => ["s1", "s2"]}
               }

      assert socket.fingerprints == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "comprehensions" do
      rendered = comprehension_template(%{title: "Users", names: ["phoenix", "elixir"]})
      {socket, full_render, _} = render(rendered)

      assert full_render == %{
               0 => "Users",
               :static => ["<div>\n  <h1>", "</h1>\n  ", "\n</div>\n"],
               1 => %{
                 static: ["\n    <br/>", "\n  "],
                 dynamics: [["phoenix"], ["elixir"]]
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

    test "renders nested %Rendered{}'s" do
      tree = {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
      {socket, diffed_render, _} = render(@nested, tree)

      assert diffed_render == %{0 => "hi", 1 => %{0 => "abc"}, 3 => %{0 => "efg"}}
      assert socket.fingerprints == tree
    end

    test "detects change in nested fingerprint" do
      old_tree = {123, %{3 => {789, %{}}, 1 => {100_001, %{}}}}
      {socket, diffed_render, _} = render(@nested, old_tree)

      assert diffed_render ==
               %{0 => "hi", 3 => %{0 => "efg"}, 1 => %{0 => "abc", :static => ["s1", "s2", "s3"]}}

      assert socket.fingerprints == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "detects change in root fingerprint" do
      old_tree = {99999, %{}}
      {socket, diffed_render, _} = render(@nested, old_tree)

      assert diffed_render == %{
               0 => "hi",
               1 => %{0 => "abc", :static => ["s1", "s2", "s3"]},
               3 => %{0 => "efg", :static => ["s1", "s2"]},
               :static => ["<h2>...", "\n<span>", "</span>\n"]
             }

      assert socket.fingerprints == {123, %{3 => {789, %{}}, 1 => {456, %{}}}}
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
      {:ok, assign(socket, :first_time, true), temporary_assigns: [:first_time]}
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

  describe "stateless components" do
    test "on mount" do
      component = %Component{assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {socket, full_render, components} = render(rendered)

      assert full_render == %{
               0 => %{0 => "component", 1 => "world", :static => ["FROM ", " ", "\n"]},
               :static => ["<div>\n  ", "\n</div>\n"]
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
                 :static => ["RENDER ONLY ", "\n"]
               },
               :static => ["<div>\n  ", "\n</div>\n"]
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
               :components => %{
                 0 => %{
                   0 => "component",
                   1 => "world",
                   :static => ["FROM ", " ", "\n"]
                 }
               },
               :static => ["<div>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints == {rendered.fingerprint, %{}}

      {_, cids_to_ids, 1} = components
      assert cids_to_ids[0] == "hello"

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

      assert full_render == %{0 => 0, :components => %{0 => %{0 => "rerender"}}}
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
               :components => %{
                 0 => %{0 => "WELCOME!", :static => ["FROM ", "\n"]}
               },
               :static => ["<div>\n  ", "\n</div>\n"]
             }

      component = %Component{id: "hello", assigns: %{from: :rerender}, component: TempComponent}
      rendered = component_template(%{component: component})

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{0 => 0, :components => %{0 => %{0 => "rerender"}}}
      assert socket.fingerprints == previous_socket.fingerprints
      assert components != previous_components

      assert_received {:temporary_mount, %Socket{endpoint: __MODULE__}}
      assert_received {:temporary_render, %{first_time: true}}
      assert_received {:temporary_render, %{first_time: nil}}
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
               :components => %{
                 1 => %{0 => "another", 1 => "world", :static => ["FROM ", " ", "\n"]}
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

    test "on replace" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: TempComponent}
      rendered = component_template(%{component: component})
      {previous_socket, _, previous_components} = render(rendered)

      component = %Component{id: "hello", assigns: %{from: :replaced}, component: MyComponent}
      rendered = component_template(%{component: component})

      {socket, full_render, components} =
        render(rendered, previous_socket.fingerprints, previous_components)

      assert full_render == %{
               0 => 0,
               :components => %{
                 0 => %{0 => "replaced", 1 => "world", :static => ["FROM ", " ", "\n"]}
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
                 dynamics: [["0", 0], ["1", 1]],
                 static: ["\n    ", ": ", "\n  "]
               },
               :components => %{
                 0 => %{
                   0 => "index_0",
                   1 => "world",
                   :static => ["FROM ", " ", "\n"]
                 },
                 1 => %{
                   0 => "index_1",
                   1 => "world",
                   :static => ["FROM ", " ", "\n"]
                 }
               },
               :static => ["<div>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints == {rendered.fingerprint, %{0 => :comprehension}}

      {_, cids_to_ids, 2} = components
      assert cids_to_ids[0] == "index_0"
      assert cids_to_ids[1] == "index_1"

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
                 dynamics: [
                   [
                     "foo",
                     %{dynamics: [["0", 0], ["1", 1]], static: ["\n      ", ": ", "\n    "]}
                   ],
                   [
                     "bar",
                     %{dynamics: [["0", 2], ["1", 3]], static: ["\n      ", ": ", "\n    "]}
                   ]
                 ],
                 static: ["\n    ", "\n    ", "\n  "]
               },
               :components => %{
                 0 => %{
                   0 => "index_0",
                   1 => "world",
                   :static => ["FROM ", " ", "\n"]
                 },
                 1 => %{
                   0 => "index_1",
                   1 => "world",
                   :static => ["FROM ", " ", "\n"]
                 },
                 2 => %{
                   0 => "index_0",
                   1 => "world",
                   :static => ["FROM ", " ", "\n"]
                 },
                 3 => %{
                   0 => "index_1",
                   1 => "world",
                   :static => ["FROM ", " ", "\n"]
                 }
               },
               :static => ["<div>\n  ", "\n</div>\n"]
             }

      assert socket.fingerprints == {rendered.fingerprint, %{0 => :comprehension}}

      {_, cids_to_ids, 4} = components
      assert cids_to_ids[0] == "foo-index_0"
      assert cids_to_ids[1] == "foo-index_1"
      assert cids_to_ids[2] == "bar-index_0"
      assert cids_to_ids[3] == "bar-index_1"

      for from <- [:index_0, :index_1, :index_0, :index_1] do
        assert_received {:mount, %Socket{endpoint: __MODULE__}}
        assert_received {:update, %{from: ^from}, %Socket{assigns: %{hello: "world"}}}
        assert_received :render
      end
    end
  end
end

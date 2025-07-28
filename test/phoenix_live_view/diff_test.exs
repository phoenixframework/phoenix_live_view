defmodule Phoenix.LiveView.DiffTest do
  use ExUnit.Case, async: true

  import Phoenix.Component

  alias Phoenix.LiveView.{Socket, Diff, Rendered, Component}
  alias Phoenix.LiveComponent.CID

  def basic_template(assigns) do
    ~H"""
    <div>
      <h2>It's {@time}</h2>
      {@subtitle}
    </div>
    """
  end

  def literal_template(assigns) do
    ~H"""
    <div>
      {@title}
      {"<div>"}
    </div>
    """
  end

  def comprehension_template(assigns) do
    ~H"""
    <div>
      <h1>{@title}</h1>
      <%= for name <- @names do %>
        <br />{name}
      <% end %>
    </div>
    """
  end

  def nested_comprehension_template(assigns) do
    ~H"""
    <div>
      <h1>{@title}</h1>
      <%= for name <- @names do %>
        <br />{name}
        <%= for score <- @scores do %>
          <br />{score}
        <% end %>
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
    Diff.render(%Socket{endpoint: __MODULE__}, rendered, fingerprints, components)
  end

  defp rendered_to_binary(map) do
    map |> Diff.to_iodata() |> IO.iodata_to_binary()
  end

  describe "to_iodata" do
    test "with subtrees chain" do
      assert rendered_to_binary(%{
               0 => %{
                 k: %{
                   0 => %{0 => "1", 1 => 1},
                   1 => %{0 => "2", 1 => 2},
                   2 => %{0 => "3", 1 => 3},
                   kc: 3
                 },
                 s: ["\n", ":", ""]
               },
               :c => %{
                 1 => %{0 => %{0 => "index_1", :s => ["\nIF ", ""]}, :s => ["", ""]},
                 2 => %{0 => %{0 => "index_2", :s => ["\nELSE ", ""]}, :s => 1},
                 3 => %{0 => %{0 => "index_3"}, :s => 2}
               },
               :s => ["<div>", "\n</div>"]
             }) == """
             <div>
             1:
             IF index_1
             2:
             ELSE index_2
             3:
             ELSE index_3
             </div>\
             """
    end

    test "with subtrees where a comprehension is replaced by rendered" do
      assert rendered_to_binary(%{
               0 => 1,
               1 => 2,
               :c => %{
                 1 => %{
                   0 => %{
                     0 => %{k: %{0 => %{}, 1 => %{}, 2 => %{}, :kc => 3}, s: ["ROW"]},
                     :s => ["\n", ""]
                   },
                   :s => ["<div>", "</div>"]
                 },
                 2 => %{
                   0 => %{
                     0 => %{0 => "BAR", :s => ["FOO", "BAZ"]},
                     :s => ["\n", ""]
                   },
                   :s => 1
                 }
               },
               :s => ["", "", ""]
             }) == "<div>\nROWROWROW</div><div>\nFOOBARBAZ</div>"
    end
  end

  describe "full renders without fingerprints" do
    test "basic template" do
      rendered = basic_template(%{time: "10:30", subtitle: "Sunny"})
      {full_render, fingerprints, _} = render(rendered)

      assert full_render == %{
               0 => "10:30",
               1 => "Sunny",
               :r => 1,
               :s => 0,
               :p => %{0 => ["<div>\n  <h2>It's ", "</h2>\n  ", "\n</div>"]}
             }

      assert rendered_to_binary(full_render) ==
               "<div>\n  <h2>It's 10:30</h2>\n  Sunny\n</div>"

      assert fingerprints == {rendered.fingerprint, %{}}
    end

    test "template with literal" do
      rendered = literal_template(%{title: "foo"})
      {full_render, fingerprints, _} = render(rendered)

      assert full_render ==
               %{
                 0 => "foo",
                 1 => "&lt;div&gt;",
                 :r => 1,
                 :s => 0,
                 :p => %{0 => ["<div>\n  ", "\n  ", "\n</div>"]}
               }

      assert rendered_to_binary(full_render) ==
               "<div>\n  foo\n  &lt;div&gt;\n</div>"

      assert fingerprints == {rendered.fingerprint, %{}}
    end

    test "nested %Rendered{}'s" do
      {full_render, fingerprints, _} = render(nested_rendered())

      assert full_render ==
               %{
                 0 => "hi",
                 1 => %{0 => "abc", 1 => "efg", :s => 0},
                 2 => %{0 => "efg", :s => 1},
                 :s => 2,
                 :p => %{
                   0 => ["s1", "s2", "s3"],
                   1 => ["s1", "s2"],
                   2 => ["<h2>", "</h2>", "<span>", "</span>"]
                 }
               }

      assert rendered_to_binary(full_render) ==
               "<h2>hi</h2>s1abcs2efgs3<span>s1efgs2</span>"

      assert fingerprints == {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "comprehensions" do
      %{fingerprint: fingerprint} =
        rendered = comprehension_template(%{title: "Users", names: ["phoenix", "elixir"]})

      {full_render, fingerprints, _} = render(rendered)

      assert full_render == %{
               0 => "Users",
               1 => %{s: 0, k: %{0 => %{0 => "phoenix"}, 1 => %{0 => "elixir"}, :kc => 2}},
               :r => 1,
               :s => 1,
               :p => %{
                 0 => ["\n    <br>", "\n  "],
                 1 => ["<div>\n  <h1>", "</h1>\n  ", "\n</div>"]
               }
             }

      assert {^fingerprint, %{1 => comprehension_print}} = fingerprints

      assert {_,
              %{
                0 => %{index: 0, vars: %{name: "phoenix"}, child_prints: print},
                1 => %{index: 1, vars: %{name: "elixir"}, child_prints: print}
              }} = comprehension_print
    end

    test "empty comprehensions" do
      # If they are empty on first render, we don't send them
      %{fingerprint: fingerprint} =
        rendered = comprehension_template(%{title: "Users", names: []})

      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => "Users",
               1 => "",
               :r => 1,
               :s => 0,
               :p => %{0 => ["<div>\n  <h1>", "</h1>\n  ", "\n</div>"]}
             }

      assert {^fingerprint, inner} = fingerprints
      assert inner == %{}

      # Making them non-empty adds a fingerprint
      rendered = comprehension_template(%{title: "Users", names: ["phoenix", "elixir"]})
      {full_render, fingerprints, components} = render(rendered, fingerprints, components)

      assert full_render == %{
               0 => "Users",
               1 => %{s: 0, k: %{0 => %{0 => "phoenix"}, 1 => %{0 => "elixir"}, :kc => 2}},
               :p => %{0 => ["\n    <br>", "\n  "]}
             }

      assert {^fingerprint, %{1 => comprehension_print}} = fingerprints

      # Making them empty again changes the fingerprint
      rendered = comprehension_template(%{title: "Users", names: []})
      {full_render, fingerprints, _components} = render(rendered, fingerprints, components)

      assert full_render == %{0 => "Users", 1 => %{k: %{kc: 0}}}

      assert {^fingerprint, %{1 => new_comprehension_print}} = fingerprints
      refute comprehension_print == new_comprehension_print
    end

    test "nested comprehensions" do
      %{fingerprint: fingerprint} =
        rendered =
        nested_comprehension_template(%{
          title: "Users",
          names: ["phoenix", "elixir"],
          scores: [1, 2]
        })

      {full_render, fingerprints, _} = render(rendered)

      assert full_render == %{
               0 => "Users",
               1 => %{
                 k: %{
                   0 => %{
                     0 => "phoenix",
                     1 => %{k: %{0 => %{0 => "1"}, 1 => %{0 => "2"}, :kc => 2}, s: 0}
                   },
                   1 => %{
                     0 => "elixir",
                     1 => %{k: %{0 => %{0 => "1"}, 1 => %{0 => "2"}, :kc => 2}, s: 0}
                   },
                   :kc => 2
                 },
                 s: 1
               },
               :p => %{
                 0 => ["\n      <br>", "\n    "],
                 1 => ["\n    <br>", "\n    ", "\n  "],
                 2 => ["<div>\n  <h1>", "</h1>\n  ", "\n</div>"]
               },
               :r => 1,
               :s => 2
             }

      assert {^fingerprint, %{1 => comprehension_print}} = fingerprints

      assert {_,
              %{
                0 => %{index: 0, vars: %{name: "phoenix"}, child_prints: print},
                1 => %{index: 1, vars: %{name: "elixir"}, child_prints: print}
              }} = comprehension_print
    end
  end

  describe "diffed render with fingerprints" do
    test "basic template skips statics for known fingerprints" do
      rendered = basic_template(%{time: "10:30", subtitle: "Sunny"})
      {full_render, fingerprints, _} = render(rendered, {rendered.fingerprint, %{}})

      assert full_render == %{0 => "10:30", 1 => "Sunny"}
      assert fingerprints == {rendered.fingerprint, %{}}
    end

    test "renders nested %Rendered{}'s" do
      tree = {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
      {diffed_render, fingerprints, _} = render(nested_rendered(), tree)

      assert diffed_render == %{0 => "hi", 1 => %{0 => "abc", 1 => "efg"}, 2 => %{0 => "efg"}}
      assert fingerprints == tree
    end

    test "does not emit nested %Rendered{}'s if they did not change" do
      tree = {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
      {diffed_render, fingerprints, _} = render(nested_rendered(false), tree)

      assert diffed_render == %{0 => "hi"}
      assert fingerprints == tree
    end

    test "detects change in nested fingerprint" do
      old_tree = {123, %{2 => {789, %{}}, 1 => {100_001, %{}}}}
      {diffed_render, fingerprints, _} = render(nested_rendered(), old_tree)

      assert diffed_render ==
               %{
                 0 => "hi",
                 1 => %{0 => "abc", 1 => "efg", :s => 0},
                 2 => %{0 => "efg"},
                 :p => %{0 => ["s1", "s2", "s3"]}
               }

      assert fingerprints == {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
    end

    test "detects change in root fingerprint" do
      old_tree = {99999, %{}}
      {diffed_render, fingerprints, _} = render(nested_rendered(), old_tree)

      assert diffed_render == %{
               0 => "hi",
               1 => %{0 => "abc", 1 => "efg", :s => 0},
               2 => %{0 => "efg", :s => 1},
               :s => 2,
               :p => %{
                 0 => ["s1", "s2", "s3"],
                 1 => ["s1", "s2"],
                 2 => ["<h2>", "</h2>", "<span>", "</span>"]
               }
             }

      assert fingerprints == {123, %{2 => {789, %{}}, 1 => {456, %{}}}}
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

      ~H"""
      <div>FROM {@from} {@hello}</div>
      """
    end
  end

  defmodule IfComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, if: true)}
    end

    def render(assigns) do
      ~H"""
      <div>
        <%= if @if do %>
          IF {@from}
        <% else %>
          ELSE {@from}
        <% end %>
      </div>
      """
    end
  end

  defmodule RecurComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        ID: {@id}
        <%= for {id, children} <- @children do %>
          <.live_component module={__MODULE__} id={id} children={children} />
        <% end %>
      </div>
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

      ~H"""
      <div>FROM {if @first_time, do: "WELCOME!", else: @from}</div>
      """
    end
  end

  defmodule RenderOnlyComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>RENDER ONLY {@from}</div>
      """
    end
  end

  defmodule SlotComponent do
    use Phoenix.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, id: "DEFAULT")}
    end

    def render(%{do: _}), do: raise("unexpected :do assign")

    def render(assigns) do
      ~H"""
      <div>
        HELLO {@id} {render_slot(@inner_block, %{value: 1})} HELLO {@id} {render_slot(
          @inner_block,
          %{value: 2}
        )}
      </div>
      """
    end
  end

  defmodule FunctionComponent do
    def render_only(assigns) do
      ~H"""
      <div>RENDER ONLY {@from}</div>
      """
    end

    def render_inner_block_no_args(assigns) do
      ~H"""
      <div>
        HELLO {@id} {render_slot(@inner_block)} HELLO {@id} {render_slot(@inner_block)}
      </div>
      """
    end

    def render_with_slot_no_args(assigns) do
      ~H"""
      <div>
        HELLO {@id} {render_slot(@sample)} HELLO {@id} {render_slot(@sample)}
      </div>
      """
    end

    def render_inner_block(assigns) do
      ~H"""
      <div>
        HELLO {@id} {render_slot(@inner_block, 1)} HELLO {@id} {render_slot(
          @inner_block,
          2
        )}
      </div>
      """
    end

    def render_with_live_component(assigns) do
      ~H"""
      COMPONENT
      <.live_component :let={%{value: value}} module={SlotComponent} id="WORLD">
        WITH VALUE {value}
      </.live_component>
      """
    end
  end

  defmodule TreeComponent do
    use Phoenix.LiveComponent

    @impl true
    def update_many(assigns_sockets) do
      send(self(), {:update_many, assigns_sockets})

      Enum.map(assigns_sockets, fn {assigns, socket} ->
        socket |> assign(assigns) |> assign(:update_many_ran?, true)
      end)
    end

    @impl true
    def update(_assigns, _socket) do
      raise "this won't be invoked"
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div>
        {@id} - {@update_many_ran?}
        <%= for {component, index} <- Enum.with_index(@children, 0) do %>
          {index}: {component}
        <% end %>
      </div>
      """
    end
  end

  defmodule NestedDynamicComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        {render_itself(assigns)}
      </div>
      """
    end

    def render_itself(assigns) do
      case assigns.key do
        :a ->
          ~H"""
          <%= for key <- [:nothing] do %>
            {key}{key}
          <% end %>
          """

        :b ->
          ~H"""
          {}
          """

        :c ->
          ~H"""
          <.live_component module={__MODULE__} id={make_ref()} key={:a} />
          """
      end
    end
  end

  def component_template(assigns) do
    ~H"""
    <div>
      {@component}
    </div>
    """
  end

  def another_component_template(assigns) do
    ~H"""
    <span>
      {@component}
    </span>
    """
  end

  describe "function components" do
    test "render only" do
      assigns = %{socket: %Socket{}}

      rendered = ~H"""
      <FunctionComponent.render_only from={:component} />
      """

      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => %{0 => "component", :r => 1, :s => 0},
               :s => 1,
               :p => %{0 => ["<div>RENDER ONLY ", "</div>"], 1 => ["", ""]}
             }

      assert fingerprints != {rendered.fingerprint, %{}}
      assert components == Diff.new_components()
    end

    @raises_inside_rendered_line __ENV__.line + 3
    defp raises_inside_rendered(assigns) do
      ~H"""
      {Process.get(:unused, false) || raise "oops"}
      """
    end

    test "stacktrace" do
      assigns = %{socket: %Socket{}}
      line = __ENV__.line + 3

      rendered = ~H"""
      <.raises_inside_rendered />
      """

      try do
        render(rendered)
      rescue
        RuntimeError ->
          [{__MODULE__, _anonymous_fun, _anonymous_arity, info} | rest] = __STACKTRACE__
          assert List.to_string(info[:file]) =~ "diff_test.exs"
          assert info[:line] == @raises_inside_rendered_line

          assert Enum.any?(rest, fn {mod, fun, arity, info} ->
                   mod == __MODULE__ and __ENV__.function == {fun, arity} and
                     List.to_string(info[:file]) =~ "diff_test.exs" and info[:line] == line
                 end)
      else
        _ -> flunk("should have raised runtime error")
      end
    end

    test "@inner_block without args" do
      assigns = %{socket: %Socket{}}

      rendered = ~H"""
      <FunctionComponent.render_inner_block_no_args id="DEFAULT">
        INSIDE BLOCK
      </FunctionComponent.render_inner_block_no_args>
      """

      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 0 => "DEFAULT",
                 1 => %{s: 0},
                 2 => "DEFAULT",
                 3 => %{s: 0},
                 :r => 1,
                 :s => 1
               },
               :s => 2,
               :p => %{
                 0 => ["\n  INSIDE BLOCK\n"],
                 1 => ["<div>\n  HELLO ", " ", " HELLO ", " ", "\n</div>"],
                 2 => ["", ""]
               }
             }

      {full_render, _fingerprints, _components} =
        render(rendered, fingerprints, components)

      assert full_render == %{0 => %{0 => "DEFAULT", 2 => "DEFAULT"}}
    end

    test "slot tracking without args" do
      assigns = %{socket: %Socket{}}

      rendered = ~H"""
      <FunctionComponent.render_with_slot_no_args id="MY ID">
        <:sample>
          INSIDE SLOT
        </:sample>
      </FunctionComponent.render_with_slot_no_args>
      """

      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => %{0 => "MY ID", 1 => %{s: 0}, 2 => "MY ID", 3 => %{s: 0}, :r => 1, :s => 1},
               :s => 2,
               :p => %{
                 0 => ["\n    INSIDE SLOT\n  "],
                 1 => ["<div>\n  HELLO ", " ", " HELLO ", " ", "\n</div>"],
                 2 => ["", ""]
               }
             }

      {full_render, _fingerprints, _components} =
        render(rendered, fingerprints, components)

      assert full_render == %{0 => %{0 => "MY ID", 2 => "MY ID"}}
    end

    defp function_tracking(assigns) do
      ~H"""
      <FunctionComponent.render_inner_block :let={value} id={@id}>
        WITH VALUE {value} - {@value}
      </FunctionComponent.render_inner_block>
      """
    end

    test "@inner_block with args and parent assign" do
      assigns = %{socket: %Socket{}, value: 123, id: "DEFAULT"}

      {full_render, fingerprints, components} = render(function_tracking(assigns))

      assert full_render == %{
               0 => %{
                 0 => "DEFAULT",
                 1 => %{0 => "1", 1 => "123", :s => 0},
                 2 => "DEFAULT",
                 3 => %{0 => "2", 1 => "123", :s => 0},
                 :r => 1,
                 :s => 1
               },
               :s => 2,
               :p => %{
                 0 => ["\n  WITH VALUE ", " - ", "\n"],
                 1 => ["<div>\n  HELLO ", " ", " HELLO ", " ", "\n</div>"],
                 2 => ["", ""]
               }
             }

      {full_render, _fingerprints, _components} =
        render(function_tracking(assigns), fingerprints, components)

      assert full_render == %{
               0 => %{
                 0 => "DEFAULT",
                 1 => %{0 => "1", 1 => "123"},
                 2 => "DEFAULT",
                 3 => %{0 => "2", 1 => "123"}
               }
             }

      assigns = Map.put(assigns, :__changed__, %{})

      {full_render, _fingerprints, _components} =
        render(function_tracking(assigns), fingerprints, components)

      assert full_render == %{}

      assigns = Map.put(assigns, :__changed__, %{id: true})

      {full_render, _fingerprints, _components} =
        render(function_tracking(assigns), fingerprints, components)

      assert full_render == %{
               0 => %{
                 0 => "DEFAULT",
                 2 => "DEFAULT"
               }
             }

      assigns = Map.put(assigns, :__changed__, %{value: true})

      {full_render, _fingerprints, _components} =
        render(function_tracking(assigns), fingerprints, components)

      assert full_render == %{
               0 => %{
                 1 => %{0 => "1", 1 => "123"},
                 3 => %{0 => "2", 1 => "123"}
               }
             }
    end

    defp fake_form(assigns) do
      ~H"""
      {render_slot(@inner_block, @form)}
      """
    end

    defp access_let(assigns) do
      ~H"""
      <.fake_form :let={f} form={@form}>
        {f[:name].value}
      </.fake_form>
      """
    end

    test ":let + access" do
      assigns = %{socket: %Socket{}, form: %{name: %{value: "foo"}}}

      {full_render, fingerprints, components} = render(access_let(assigns))

      assert full_render == %{
               0 => %{0 => %{0 => "foo", :s => 0}, :s => 1},
               :s => 2,
               :p => %{0 => ["\n  ", "\n"], 1 => ["", ""], 2 => ["", ""]}
             }

      {full_render, _fingerprints, _components} =
        render(access_let(assigns), fingerprints, components)

      assert full_render == %{0 => %{0 => %{0 => "foo"}}}

      assigns = Map.put(assigns, :__changed__, %{})

      {full_render, _fingerprints, _components} =
        render(access_let(assigns), fingerprints, components)

      assert full_render == %{}

      assigns = Map.put(assigns, :__changed__, %{form: true})

      {full_render, _fingerprints, _components} =
        render(access_let(assigns), fingerprints, components)

      assert full_render == %{0 => %{0 => %{0 => "foo"}}}
    end

    def render_multiple_slots(assigns) do
      ~H"""
      <div>
        HEADER: {render_slot(@header)} FOOTER: {render_slot(@footer)}
      </div>
      """
    end

    def slot_tracking(assigns) do
      ~H"""
      <.render_multiple_slots>
        <:header>
          {@in_header}{@in_both}
        </:header>
        <:footer>
          {@in_footer}{@in_both}
        </:footer>
      </.render_multiple_slots>
      """
    end

    test "slot tracking with multiple slots" do
      assigns = %{socket: %Socket{}, in_header: "H", in_footer: "F", in_both: "B"}

      {full_render, fingerprints, components} = render(slot_tracking(assigns))

      assert full_render == %{
               0 => %{
                 0 => %{0 => "H", 1 => "B", :s => 0},
                 1 => %{0 => "F", 1 => "B", :s => 1},
                 :r => 1,
                 :s => 2
               },
               :s => 3,
               :p => %{
                 0 => ["\n    ", "", "\n  "],
                 1 => ["\n    ", "", "\n  "],
                 2 => ["<div>\n  HEADER: ", " FOOTER: ", "\n</div>"],
                 3 => ["", ""]
               }
             }

      {full_render, _fingerprints, _components} =
        render(slot_tracking(assigns), fingerprints, components)

      assert full_render == %{
               0 => %{
                 0 => %{0 => "H", 1 => "B"},
                 1 => %{0 => "F", 1 => "B"}
               }
             }

      assigns = Map.put(assigns, :__changed__, %{})

      {full_render, _fingerprints, _components} =
        render(slot_tracking(assigns), fingerprints, components)

      assert full_render == %{}

      assigns = Map.put(assigns, :__changed__, %{in_header: true})

      {full_render, _fingerprints, _components} =
        render(slot_tracking(assigns), fingerprints, components)

      assert full_render == %{0 => %{0 => %{0 => "H"}}}

      assigns = Map.put(assigns, :__changed__, %{in_footer: true})

      {full_render, _fingerprints, _components} =
        render(slot_tracking(assigns), fingerprints, components)

      assert full_render == %{0 => %{1 => %{0 => "F"}}}

      assigns = Map.put(assigns, :__changed__, %{in_both: true})

      {full_render, _fingerprints, _components} =
        render(slot_tracking(assigns), fingerprints, components)

      assert full_render == %{
               0 => %{
                 1 => %{1 => "B"},
                 0 => %{1 => "B"}
               }
             }
    end

    def conditional_slot_tracking(assigns) do
      ~H"""
      <.render_multiple_slots>
        <:header :if={@if}>
          <.live_component module={MyComponent} id="header" from={:component} />
        </:header>
        <:footer :if={@if}>
          <.live_component module={MyComponent} id="footer" from={:component} />
        </:footer>
      </.render_multiple_slots>
      """
    end

    test "slot tracking with live component inside conditional slot" do
      assigns = %{socket: %Socket{}, if: true}
      {_socket, _full_render, components} = render(conditional_slot_tracking(assigns))
      assert {_, _, 3} = components

      assigns = %{socket: %Socket{}, if: false}
      {_socket, _full_render, components} = render(conditional_slot_tracking(assigns))
      assert {_, _, 1} = components
    end

    test "with live_component" do
      assigns = %{socket: %Socket{}}

      rendered = ~H"""
      <FunctionComponent.render_with_live_component />
      """

      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => %{0 => 1, :s => 0},
               :c => %{
                 1 => %{
                   0 => "WORLD",
                   1 => %{0 => "1", :s => ["\n  WITH VALUE ", "\n"]},
                   2 => "WORLD",
                   3 => %{0 => "2", :s => ["\n  WITH VALUE ", "\n"]},
                   :r => 1,
                   :s => ["<div>\n  HELLO ", " ", " HELLO ", " ", "\n</div>"]
                 }
               },
               :s => 1,
               :p => %{0 => ["COMPONENT\n", ""], 1 => ["", ""]}
             }

      {full_render, _fingerprints, _components} =
        render(rendered, fingerprints, components)

      assert full_render == %{0 => %{0 => 1}}
    end

    def li(assigns) do
      ~H"""
      <li>{render_slot(@inner_block)}</li>
      """
    end

    defp comprehension_with_and_without_component(assigns) do
      ~H"""
      <div>
        <ul>
          <li :for={item <- @items}>
            {item.price}
          </li>
        </ul>

        <ul>
          <.li :for={item <- @items}>
            {item.price}
          </.li>
        </ul>
      </div>
      """
    end

    test "vars_changed" do
      # This came up in issue https://github.com/phoenixframework/phoenix_live_view/issues/3906
      assigns = %{socket: %Socket{}, items: [%{price: 0}], item: %{price: 0}}

      {full_render, fingerprints, components} =
        render(comprehension_with_and_without_component(assigns))

      assert full_render == %{
               0 => %{s: 0, k: %{0 => %{0 => "0"}, :kc => 1}},
               :p => %{
                 0 => ["<li>\n      ", "\n    </li>"],
                 1 => ["\n      ", "\n    "],
                 2 => ["<li>", "</li>"],
                 3 => ["", ""],
                 4 => ["<div>\n  <ul>\n    ", "\n  </ul>\n\n  <ul>\n    ", "\n  </ul>\n</div>"]
               },
               :s => 4,
               1 => %{
                 s: 3,
                 k: %{0 => %{0 => %{0 => %{0 => "0", :s => 1}, :s => 2, :r => 1}}, :kc => 1}
               },
               :r => 1
             }

      assigns =
        assigns
        |> Map.put(:items, [%{price: 1}])
        |> Map.put(:__changed__, %{items: true})

      {full_render, _fingerprints, _components} =
        render(comprehension_with_and_without_component(assigns), fingerprints, components)

      assert full_render == %{
               0 => %{k: %{0 => %{0 => "1"}, :kc => 1}},
               1 => %{k: %{0 => %{0 => %{0 => %{0 => "1"}}}, :kc => 1}}
             }
    end
  end

  describe "live components" do
    test "on mount" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{
                   0 => "component",
                   1 => "world",
                   :r => 1,
                   :s => ["<div>FROM ", " ", "</div>"]
                 }
               },
               :r => 1,
               :s => 0,
               :p => %{0 => ["<div>\n  ", "\n</div>"]}
             }

      assert fingerprints == {rendered.fingerprint, %{}}

      {cid_to_component, _, 2} = components
      assert {MyComponent, "hello", _, _, _} = cid_to_component[1]

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
      assert assigns[:flash] == %{}
      assert assigns[:myself] == %CID{cid: 1}

      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      refute_received _
    end

    test "on root fingerprint change" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{
                   0 => "component",
                   1 => "world",
                   :r => 1,
                   :s => ["<div>FROM ", " ", "</div>"]
                 }
               },
               :r => 1,
               :s => 0,
               :p => %{0 => ["<div>\n  ", "\n</div>"]}
             }

      assert fingerprints == {rendered.fingerprint, %{}}

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
      assert assigns[:flash] == %{}
      assert assigns[:myself] == %CID{cid: 1}

      assert_received :render

      another_rendered = another_component_template(%{component: component})

      {another_full_render, another_fingerprints, _} =
        render(another_rendered, fingerprints, components)

      assert another_full_render == %{
               0 => 2,
               :c => %{
                 2 => %{
                   0 => "component",
                   1 => "world",
                   :r => 1,
                   :s => ["<div>FROM ", " ", "</div>"]
                 }
               },
               :r => 1,
               :s => 0,
               :p => %{0 => ["<span>\n  ", "\n</span>"]}
             }

      assert another_fingerprints == {another_rendered.fingerprint, %{}}
      assert fingerprints != another_fingerprints

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
      assert assigns[:flash] == %{}
      assert assigns[:myself] == %CID{cid: 2}

      assert_received :render
    end

    test "raises on duplicate component IDs" do
      assigns = %{socket: %Socket{}}

      rendered = ~H"""
      <.live_component module={RenderOnlyComponent} id="SAME" from="SAME" />
      <.live_component module={RenderOnlyComponent} id="SAME" from="SAME" />
      """

      assert_raise RuntimeError,
                   "found duplicate ID \"SAME\" for component Phoenix.LiveView.DiffTest.RenderOnlyComponent when rendering template",
                   fn -> render(rendered) end
    end

    test "on update without render" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {_, previous_fingerprints, previous_components} = render(rendered)

      {full_render, fingerprints, components} =
        render(rendered, previous_fingerprints, previous_components)

      assert full_render == %{0 => 1}
      assert fingerprints == previous_fingerprints
      assert components == previous_components

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
      assert assigns[:flash] == %{}
      assert assigns[:myself] == %CID{cid: 1}

      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      assert_received :render
      assert_received {:update, %{from: :component}, %Socket{assigns: %{hello: "world"}}}
      refute_received _
    end

    test "on update with render" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {_, previous_fingerprints, previous_components} = render(rendered)

      component = %Component{id: "hello", assigns: %{from: :rerender}, component: MyComponent}
      rendered = component_template(%{component: component})

      {full_render, fingerprints, components} =
        render(rendered, previous_fingerprints, previous_components)

      assert full_render == %{0 => 1, :c => %{1 => %{0 => "rerender"}}}
      assert fingerprints == previous_fingerprints
      assert components != previous_components

      assert_received {:mount, %Socket{endpoint: __MODULE__, assigns: assigns}}
      assert assigns[:flash] == %{}
      assert assigns[:myself] == %CID{cid: 1}

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
      {full_render, previous_fingerprints, previous_components} = render(rendered)

      assert full_render == %{
               0 => 1,
               :c => %{1 => %{0 => "WELCOME!", :r => 1, :s => ["<div>FROM ", "</div>"]}},
               :r => 1,
               :s => 0,
               :p => %{0 => ["<div>\n  ", "\n</div>"]}
             }

      component = %Component{id: "hello", assigns: %{from: :rerender}, component: TempComponent}
      rendered = component_template(%{component: component})

      {full_render, fingerprints, components} =
        render(rendered, previous_fingerprints, previous_components)

      assert full_render == %{0 => 1, :c => %{1 => %{0 => "rerender"}}}
      assert fingerprints == previous_fingerprints
      assert components != previous_components

      assert_received {:temporary_mount, %Socket{endpoint: __MODULE__}}
      assert_received {:temporary_render, %{first_time: true}}
      assert_received {:temporary_render, %{first_time: false}}
      refute_received _
    end

    test "on update_many" do
      alias Component, as: C
      alias TreeComponent, as: TC

      tree = %C{
        component: TC,
        id: "R",
        assigns: %{
          id: "R",
          children: [
            %C{
              component: TC,
              id: "A",
              assigns: %{
                id: "A",
                children: [
                  %C{component: TC, id: "B", assigns: %{id: "B", children: []}},
                  %C{component: TC, id: "C", assigns: %{id: "C", children: []}},
                  %C{component: TC, id: "D", assigns: %{id: "D", children: []}}
                ]
              }
            },
            %C{
              component: TC,
              id: "X",
              assigns: %{
                id: "X",
                children: [
                  %C{component: TC, id: "Y", assigns: %{id: "Y", children: []}},
                  %C{component: TC, id: "Z", assigns: %{id: "Z", children: []}}
                ]
              }
            }
          ]
        }
      }

      rendered = component_template(%{component: tree})
      {full_render, fingerprints, components} = render(rendered)

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

      assert fingerprints == {rendered.fingerprint, %{}}
      assert {_, _, 9} = components

      assert_received {:update_many, [{%{id: "R"}, socket0}]}
      assert %Socket{assigns: %{myself: %CID{cid: 1}}} = socket0

      assert_received {:update_many, [{%{id: "A"}, socket0}, {%{id: "X"}, socket1}]}
      assert %Socket{assigns: %{myself: %CID{cid: 2}}} = socket0
      assert %Socket{assigns: %{myself: %CID{cid: 3}}} = socket1

      assert_received {:update_many,
                       [
                         {%{id: "B"}, %Socket{assigns: %{myself: %CID{cid: 4}}}},
                         {%{id: "C"}, %Socket{assigns: %{myself: %CID{cid: 5}}}},
                         {%{id: "D"}, %Socket{assigns: %{myself: %CID{cid: 6}}}},
                         {%{id: "Y"}, %Socket{assigns: %{myself: %CID{cid: 7}}}},
                         {%{id: "Z"}, %Socket{assigns: %{myself: %CID{cid: 8}}}}
                       ]}

      refute_received {:update, _}
    end

    test "on addition" do
      component = %Component{id: "hello", assigns: %{from: :component}, component: MyComponent}
      rendered = component_template(%{component: component})
      {_, previous_fingerprints, previous_components} = render(rendered)

      component = %Component{id: "another", assigns: %{from: :another}, component: MyComponent}
      rendered = component_template(%{component: component})

      {full_render, fingerprints, components} =
        render(rendered, previous_fingerprints, previous_components)

      assert full_render == %{0 => 2, :c => %{2 => %{0 => "another", 1 => "world", :s => -1}}}

      assert fingerprints == previous_fingerprints
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
      {_, previous_fingerprints, previous_components} = render(rendered)

      component = %Component{id: "hello", assigns: %{from: :replaced}, component: MyComponent}
      rendered = component_template(%{component: component})

      {full_render, fingerprints, components} =
        render(rendered, previous_fingerprints, previous_components)

      assert full_render == %{
               0 => 2,
               :c => %{
                 2 => %{
                   0 => "replaced",
                   1 => "world",
                   :s => ["<div>FROM ", " ", "</div>"],
                   :r => 1
                 }
               }
             }

      assert fingerprints == previous_fingerprints
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
        rendered = ~H"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 0) do %>
            {index}: {component}
          <% end %>
        </div>
        """

      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => %{s: 0, k: %{0 => %{0 => "0", 1 => 1}, 1 => %{0 => "1", 1 => 2}, :kc => 2}},
               :c => %{
                 1 => %{
                   0 => "index_1",
                   1 => "world",
                   :r => 1,
                   :s => ["<div>FROM ", " ", "</div>"]
                 },
                 2 => %{0 => "index_2", 1 => "world", :s => 1}
               },
               :r => 1,
               :s => 1,
               :p => %{0 => ["\n    ", ": ", "\n  "], 1 => ["<div>\n  ", "\n</div>"]}
             }

      assert {^fingerprint, %{0 => _}} = fingerprints

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

        ~H"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 0) do %>
            {index}: {component}
          <% end %>
        </div>
        """
      end

      # We start by rendering two components
      components = [
        %Component{id: "index_1", assigns: %{from: :index_1}, component: IfComponent},
        %Component{id: "index_2", assigns: %{from: :index_2}, component: IfComponent}
      ]

      {full_render, fingerprints, diff_components} = render(template.(components))

      assert full_render == %{
               0 => %{s: 0, k: %{0 => %{0 => "0", 1 => 1}, 1 => %{0 => "1", 1 => 2}, :kc => 2}},
               :c => %{
                 1 => %{
                   0 => %{0 => "index_1", :s => ["\n    IF ", "\n  "]},
                   :r => 1,
                   :s => ["<div>\n  ", "\n</div>"]
                 },
                 2 => %{0 => %{0 => "index_2"}, :s => 1}
               },
               :r => 1,
               :s => 1,
               :p => %{0 => ["\n    ", ": ", "\n  "], 1 => ["<div>\n  ", "\n</div>"]}
             }

      {cid_to_component, _, 3} = diff_components
      assert {IfComponent, "index_1", _, _, _} = cid_to_component[1]
      assert {IfComponent, "index_2", _, _, _} = cid_to_component[2]

      # Now let's add a third component, it shall reuse index_1
      components = [
        %Component{id: "index_3", assigns: %{from: :index_3}, component: IfComponent}
      ]

      {diff, _, diff_components} =
        render(template.(components), fingerprints, diff_components)

      assert diff == %{
               0 => %{k: %{0 => %{1 => 3}, :kc => 1}},
               :c => %{3 => %{0 => %{0 => "index_3"}, :s => -1}}
             }

      {cid_to_component, _, 4} = diff_components
      assert {IfComponent, "index_3", _, _, _} = cid_to_component[3]

      # Now let's add a fourth component, with a different subtree than index_0
      components = [
        %Component{id: "index_4", assigns: %{from: :index_4, if: false}, component: IfComponent}
      ]

      {diff, _, diff_components} =
        render(template.(components), fingerprints, diff_components)

      assert diff == %{
               0 => %{k: %{0 => %{1 => 4}, :kc => 1}},
               :c => %{4 => %{0 => %{0 => "index_4", :s => ["\n    ELSE ", "\n  "]}, :s => -1}}
             }

      {cid_to_component, _, 5} = diff_components
      assert {IfComponent, "index_4", _, _, _} = cid_to_component[4]

      # Finally, let's add a fifth component while changing the first component at the same time.
      # We should point to the index tree of index_0 before render.
      components = [
        %Component{id: "index_1", assigns: %{from: :index_1, if: false}, component: IfComponent},
        %Component{id: "index_5", assigns: %{from: :index_5}, component: IfComponent}
      ]

      {diff, _, diff_components} =
        render(template.(components), fingerprints, diff_components)

      assert diff == %{
               0 => %{k: %{0 => %{1 => 1}, 1 => %{1 => 5}, :kc => 2}},
               :c => %{
                 1 => %{0 => %{0 => "index_1", :s => ["\n    ELSE ", "\n  "]}},
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
        rendered = ~H"""
        <div>
          <%= for prefix_id <- @ids do %>
            {prefix_id}
            <%= for {component, index} <- Enum.with_index(@components, 0) do %>
              {index}: {%{component | id: "#{prefix_id}-#{component.id}"}}
            <% end %>
          <% end %>
        </div>
        """

      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 k: %{
                   0 => %{
                     0 => "foo",
                     1 => %{
                       k: %{0 => %{0 => "0", 1 => 1}, 1 => %{0 => "1", 1 => 2}, :kc => 2},
                       s: 0
                     }
                   },
                   1 => %{
                     0 => "bar",
                     1 => %{
                       k: %{0 => %{0 => "0", 1 => 3}, 1 => %{0 => "1", 1 => 4}, :kc => 2},
                       s: 0
                     }
                   },
                   :kc => 2
                 },
                 s: 1
               },
               :c => %{
                 1 => %{
                   0 => "index_1",
                   1 => "world",
                   :r => 1,
                   :s => ["<div>FROM ", " ", "</div>"]
                 },
                 2 => %{0 => "index_2", 1 => "world", :s => 1},
                 3 => %{0 => "index_1", 1 => "world", :s => 1},
                 4 => %{0 => "index_2", 1 => "world", :s => 3}
               },
               :p => %{
                 0 => ["\n      ", ": ", "\n    "],
                 1 => ["\n    ", "\n    ", "\n  "],
                 2 => ["<div>\n  ", "\n</div>"]
               },
               :r => 1,
               :s => 2
             }

      assert {^fingerprint, %{0 => _}} = fingerprints

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

    test "inside comprehension with recursive subtree" do
      template = fn id, children ->
        assigns = %{id: id, children: children}

        ~H"""
        <.live_component module={RecurComponent} id={@id} children={@children} />
        """
      end

      {full_render, fingerprints, diff_components} = render(template.(1, []))

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{0 => "1", 1 => "", :r => 1, :s => ["<div>\n  ID: ", "\n  ", "\n</div>"]}
               },
               :s => 0,
               :p => %{0 => ["", ""]}
             }

      {cid_to_component, _, 2} = diff_components
      assert {RecurComponent, 1, _, _, _} = cid_to_component[1]

      # Now let's add one level of nesting
      {diff, _, diff_components} =
        render(template.(1, [{2, []}]), fingerprints, diff_components)

      assert diff == %{
               0 => 1,
               :c => %{
                 1 => %{1 => %{s: ["\n    ", "\n  "], k: %{0 => %{0 => 2}, :kc => 1}}},
                 2 => %{0 => "2", 1 => "", :s => -1}
               }
             }

      {cid_to_component, _, 3} = diff_components
      assert {RecurComponent, 2, _, _, _} = cid_to_component[2]

      # Now let's add two levels of nesting
      {diff, _, diff_components} =
        render(template.(1, [{2, [{3, []}]}]), fingerprints, diff_components)

      assert diff == %{
               0 => 1,
               :c => %{
                 1 => %{1 => %{k: %{0 => %{0 => 2}, :kc => 1}}},
                 2 => %{1 => %{k: %{0 => %{0 => 3}, :kc => 1}, s: ["\n    ", "\n  "]}},
                 3 => %{0 => "3", 1 => %{k: %{kc: 0}}, :s => -1}
               }
             }

      {cid_to_component, _, 4} = diff_components
      assert {RecurComponent, 3, _, _, _} = cid_to_component[3]
    end

    test "inside comprehension with recursive subtree on update" do
      template = fn id, children ->
        assigns = %{id: id, children: children}

        ~H"""
        <.live_component module={RecurComponent} id={@id} children={@children} />
        """
      end

      {full_render, _fingerprints, diff_components} = render(template.(1, []))

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{0 => "1", 1 => "", :r => 1, :s => ["<div>\n  ID: ", "\n  ", "\n</div>"]}
               },
               :s => 0,
               :p => %{0 => ["", ""]}
             }

      {cid_to_component, _, 2} = diff_components
      assert {RecurComponent, 1, _, _, _} = cid_to_component[1]

      # Now let's add one level of nesting directly
      {diff, diff_components, :extra} =
        Diff.write_component(%Socket{endpoint: __MODULE__}, 1, diff_components, fn
          socket, _component ->
            {Phoenix.Component.assign(socket, children: [{2, []}]), :extra}
        end)

      assert diff == %{
               c: %{
                 1 => %{1 => %{s: ["\n    ", "\n  "], k: %{0 => %{0 => 2}, :kc => 1}}},
                 2 => %{0 => "2", 1 => "", :s => -1}
               }
             }

      {cid_to_component, _, 3} = diff_components
      assert {RecurComponent, 2, _, _, _} = cid_to_component[2]
    end

    test "inside rendered inside comprehension" do
      components = [
        %Component{id: "index_1", assigns: %{from: :index_1}, component: MyComponent},
        %Component{id: "index_2", assigns: %{from: :index_2}, component: MyComponent}
      ]

      assigns = %{components: components}

      %{fingerprint: fingerprint} =
        rendered = ~H"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 1) do %>
            {index}: {component_template(%{component: component})}
          <% end %>
        </div>
        """

      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 k: %{
                   0 => %{0 => "1", 1 => %{0 => 1, :r => 1, :s => 0}},
                   1 => %{0 => "2", 1 => %{0 => 2, :r => 1, :s => 0}},
                   :kc => 2
                 },
                 s: 1
               },
               :c => %{
                 1 => %{
                   0 => "index_1",
                   1 => "world",
                   :r => 1,
                   :s => ["<div>FROM ", " ", "</div>"]
                 },
                 2 => %{0 => "index_2", 1 => "world", :s => 1}
               },
               :p => %{
                 0 => ["<div>\n  ", "\n</div>"],
                 1 => ["\n    ", ": ", "\n  "],
                 2 => ["<div>\n  ", "\n</div>"]
               },
               :r => 1,
               :s => 2
             }

      assert {^fingerprint, %{0 => _}} = fingerprints

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
        rendered = ~H"""
        <div>
          <%= for {component, index} <- Enum.with_index(@components, 1) do %>
            <%= if index > 1 do %>
              {index}: {component}
            <% end %>
          <% end %>
        </div>
        """

      {full_render, fingerprints, components} = render(rendered)

      assert full_render == %{
               0 => %{
                 s: 1,
                 k: %{0 => %{0 => ""}, 1 => %{0 => %{0 => "2", 1 => 1, :s => 0}}, :kc => 2}
               },
               :c => %{
                 1 => %{
                   0 => "index_2",
                   1 => "world",
                   :r => 1,
                   :s => ["<div>FROM ", " ", "</div>"]
                 }
               },
               :r => 1,
               :s => 2,
               :p => %{
                 0 => ["\n      ", ": ", "\n    "],
                 1 => ["\n    ", "\n  "],
                 2 => ["<div>\n  ", "\n</div>"]
               }
             }

      assert {^fingerprint, %{0 => _}} = fingerprints

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
        rendered = ~H"""
        <%= for key <- [:b, :c] do %>
          <.live_component module={NestedDynamicComponent} id={key} key={key} />
        <% end %>
        """

      {full_render, _fingerprints, _components} = render(rendered)

      assert %{
               0 => %{s: 0, k: %{0 => %{0 => 1}, 1 => %{0 => 2}, :kc => 2}},
               :c => %{
                 1 => %{0 => %{0 => "", :s => ["", ""]}, :s => ["<div>\n  ", "\n</div>"], :r => 1},
                 2 => %{0 => %{0 => 3, :s => ["", ""]}, :s => 1},
                 3 => %{
                   0 => %{
                     0 => %{
                       s: ["\n  ", "", "\n"],
                       k: %{0 => %{0 => "nothing", 1 => "nothing"}, :kc => 1}
                     },
                     :s => ["", ""]
                   },
                   :s => static
                 }
               },
               :s => 1,
               :p => %{0 => ["\n  ", "\n"], 1 => ["", ""]}
             } = full_render

      assert is_integer(static)
      assert rendered_to_binary(full_render) =~ "nothingnothing"
    end

    defp tracking(assigns) do
      ~H"""
      <.live_component :let={%{value: value}} module={SlotComponent} id="TRACKING">
        WITH PARENT VALUE {@parent_value} WITH VALUE {value}
      </.live_component>
      """
    end

    test "@inner_block tracking with args and parent assigns" do
      assigns = %{socket: %Socket{}, parent_value: 123}
      {full_render, fingerprints, components} = render(tracking(assigns))

      assert full_render == %{
               0 => 1,
               :c => %{
                 1 => %{
                   0 => "TRACKING",
                   1 => %{
                     0 => "123",
                     1 => "1",
                     :s => ["\n  WITH PARENT VALUE ", " WITH VALUE ", "\n"]
                   },
                   2 => "TRACKING",
                   3 => %{
                     0 => "123",
                     1 => "2",
                     :s => ["\n  WITH PARENT VALUE ", " WITH VALUE ", "\n"]
                   },
                   :r => 1,
                   :s => ["<div>\n  HELLO ", " ", " HELLO ", " ", "\n</div>"]
                 }
               },
               :s => 0,
               :p => %{0 => ["", ""]}
             }

      {full_render, _fingerprints, _components} =
        render(tracking(assigns), fingerprints, components)

      assert full_render == %{0 => 1}

      # Changing the root assign
      assigns = %{socket: %Socket{}, parent_value: 123, __changed__: %{parent_value: true}}

      {full_render, _fingerprints, _components} =
        render(tracking(assigns), fingerprints, components)

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

  describe "keyed comprehensions" do
    defp keyed_comprehension_with_pattern(assigns) do
      ~H"""
      <ul>
        <li :for={%{id: id, name: name} <- @items} :key={id}>
          Outside assign: {@count} Inside assign: {name}
        </li>
      </ul>
      """
    end

    defp non_keyed_comprehension_with_pattern(assigns) do
      ~H"""
      <ul>
        <li :for={%{id: id, name: name} <- @items}>
          Outside assign: {@count} Inside assign: {name}
        </li>
      </ul>
      """
    end

    defp keyed_comprehension_with_nested_access(assigns) do
      ~H"""
      <ul>
        <li :for={{id, entry} <- @items} :key={id}>
          <span>Count: {@count}</span>
          <span>Dot: {entry.foo.bar}</span>
          <span>Access: {entry[:foo][:bar]}</span>
        </li>
      </ul>
      """
    end

    defp deep_keyed_comprehension(assigns) do
      ~H"""
      <.keyed_comprehension_with_pattern items={@items} count={100} />
      <.keyed_comprehension_with_pattern items={@items} count={200} />
      """
    end

    defp comprehended_keyed_comprehension(assigns) do
      ~H"""
      <%= for count <- [100, 200] do %>
        <.keyed_comprehension_with_pattern items={@items} count={count} />
      <% end %>
      """
    end

    defp keyed_comprehension_with_component(assigns) do
      ~H"""
      <.non_keyed_comprehension_with_pattern
        :for={{id, items} <- @list_of_items}
        :key={id}
        items={items}
        count={@count}
      />
      """
    end

    defp keyed_comprehension_with_component_and_slots(assigns) do
      ~H"""
      <.my_demo_list :for={item <- @items} :key={item.id}>
        <:entry :for={entry <- item.entries} key={entry.id}>
          {entry.title} {@count}
        </:entry>
      </.my_demo_list>
      """
    end

    defp my_demo_list(assigns) do
      ~H"""
      <ul>
        <li :for={slot <- @entry} :key={slot.key}>{render_slot(slot)}</li>
      </ul>
      """
    end

    defp comprehended_keyed_comprehension_with_slot(assigns) do
      ~H"""
      <%= for count <- [100, 200] do %>
        <.slotted_list :let={%{name: name}} items={@items}>
          Outside assign: {count} Inside assign: {name}
        </.slotted_list>
      <% end %>
      """
    end

    defp slotted_list(assigns) do
      ~H"""
      <ul>
        <li :for={%{id: id} = item <- @items} :key={id}>
          {render_slot(@inner_block, item)}}
        </li>
      </ul>
      """
    end

    test "change tracking with minimal diff updates" do
      items = [
        %{id: 1, name: "First"},
        %{id: 2, name: "Second"}
      ]

      assigns = %{socket: %Socket{}, items: items, count: 0, __changed__: %{}}
      {full_render, fingerprints, components} = render(keyed_comprehension_with_pattern(assigns))

      assert full_render == %{
               0 => %{
                 k: %{0 => %{0 => "0", 1 => "First"}, 1 => %{0 => "0", 1 => "Second"}, :kc => 2},
                 s: 0
               },
               :p => %{
                 0 => ["<li>\n    Outside assign: ", " Inside assign: ", "\n  </li>"],
                 1 => ["<ul>\n  ", "\n</ul>"]
               },
               :r => 1,
               :s => 1
             }

      # change order of items
      assigns = Phoenix.Component.assign(assigns, :items, Enum.reverse(assigns.items))

      {second_render, fingerprints, components} =
        render(keyed_comprehension_with_pattern(assigns), fingerprints, components)

      assert second_render == %{0 => %{k: %{0 => 1, 1 => 0, :kc => 2}}}

      # update count
      assigns = Phoenix.Component.assign(assigns, :count, 1)

      {third_render, fingerprints, components} =
        render(keyed_comprehension_with_pattern(assigns), fingerprints, components)

      assert third_render == %{0 => %{k: %{0 => %{0 => "1"}, 1 => %{0 => "1"}, :kc => 2}}}

      # replace item
      assigns =
        assigns
        |> Map.put(:__changed__, %{})
        |> Phoenix.Component.assign(:items, [
          %{id: 1, name: "First"},
          %{id: 3, name: "Third"}
        ])

      {fourth_render, _fingerprints, _components} =
        render(keyed_comprehension_with_pattern(assigns), fingerprints, components)

      assert fourth_render == %{0 => %{k: %{0 => 1, 1 => %{0 => "1", 1 => "Third"}, :kc => 2}}}
    end

    test "change tracking when no key is given" do
      items = [
        %{id: 1, name: "First"},
        %{id: 2, name: "Second"}
      ]

      assigns = %{socket: %Socket{}, items: items, count: 0, __changed__: %{}}

      {full_render, fingerprints, components} =
        render(non_keyed_comprehension_with_pattern(assigns))

      assert full_render == %{
               0 => %{
                 k: %{0 => %{0 => "0", 1 => "First"}, 1 => %{0 => "0", 1 => "Second"}, :kc => 2},
                 s: 0
               },
               :p => %{
                 0 => ["<li>\n    Outside assign: ", " Inside assign: ", "\n  </li>"],
                 1 => ["<ul>\n  ", "\n</ul>"]
               },
               :r => 1,
               :s => 1
             }

      # change order of items
      assigns = Phoenix.Component.assign(assigns, :items, Enum.reverse(assigns.items))

      {second_render, fingerprints, components} =
        render(non_keyed_comprehension_with_pattern(assigns), fingerprints, components)

      # the index is the key, so we get the reversed order for the names
      assert second_render == %{
               0 => %{k: %{0 => %{1 => "Second"}, 1 => %{1 => "First"}, :kc => 2}}
             }

      # update count
      assigns = Phoenix.Component.assign(assigns, :count, 1)

      {third_render, fingerprints, components} =
        render(non_keyed_comprehension_with_pattern(assigns), fingerprints, components)

      # only the new count is sent
      assert third_render == %{0 => %{k: %{0 => %{0 => "1"}, 1 => %{0 => "1"}, :kc => 2}}}

      # replace item
      assigns =
        assigns
        |> Map.put(:__changed__, %{})
        |> Phoenix.Component.assign(:items, [
          %{id: 1, name: "Second"},
          %{id: 3, name: "Third"}
        ])

      {fourth_render, _fingerprints, _components} =
        render(non_keyed_comprehension_with_pattern(assigns), fingerprints, components)

      # only index 1 is updated
      assert fourth_render == %{0 => %{k: %{1 => %{1 => "Third"}, :kc => 2}}}
    end

    test "change-tracking for complex access" do
      items = [
        {1, %{foo: %{bar: "First", baz: "1"}, other: "hey"}},
        {2, %{foo: %{bar: "Second", baz: "1"}, other: "hey"}}
      ]

      assigns = %{socket: %Socket{}, items: items, count: 0, __changed__: %{}}

      {full_render, fingerprints, components} =
        render(keyed_comprehension_with_nested_access(assigns))

      assert full_render == %{
               0 => %{
                 k: %{
                   0 => %{0 => "0", 1 => "First", 2 => "First"},
                   1 => %{0 => "0", 1 => "Second", 2 => "Second"},
                   :kc => 2
                 },
                 s: 0
               },
               :p => %{
                 0 => [
                   "<li>\n    <span>Count: ",
                   "</span>\n    <span>Dot: ",
                   "</span>\n    <span>Access: ",
                   "</span>\n  </li>"
                 ],
                 1 => ["<ul>\n  ", "\n</ul>"]
               },
               :r => 1,
               :s => 1
             }

      # change entries, but no part that is rendered
      assigns =
        Phoenix.Component.assign(
          assigns,
          :items,
          [
            {1, %{foo: %{bar: "First", baz: "2"}, other: "heyo"}},
            {2, %{foo: %{bar: "Second", baz: "2"}, other: "heyo"}}
          ]
        )

      {second_render, fingerprints, components} =
        render(keyed_comprehension_with_nested_access(assigns), fingerprints, components)

      # no diff, because nothing relevant changed
      assert second_render == %{}

      # now change bar for first entry
      assigns =
        Phoenix.Component.assign(assigns, :items, [
          {1, %{foo: %{bar: "Updated", baz: "2"}, other: "heyo"}},
          {2, %{foo: %{bar: "Second", baz: "2"}, other: "heyo"}}
        ])

      {third_render, _fingerprints, _components} =
        render(keyed_comprehension_with_nested_access(assigns), fingerprints, components)

      # no diff, because nothing relevant changed
      assert third_render == %{0 => %{k: %{0 => %{1 => "Updated", 2 => "Updated"}, :kc => 2}}}
    end

    test "keys don't need to be globally unique" do
      items = [
        %{id: 1, name: "First"},
        %{id: 2, name: "Second"}
      ]

      assigns = %{socket: %Socket{}, items: items, __changed__: %{}}
      {full_render, _fingerprints, _components} = render(deep_keyed_comprehension(assigns))

      assert full_render == %{
               0 => %{
                 0 => %{
                   k: %{
                     0 => %{0 => "100", 1 => "First"},
                     1 => %{0 => "100", 1 => "Second"},
                     :kc => 2
                   },
                   s: 0
                 },
                 :r => 1,
                 :s => 1
               },
               1 => %{
                 0 => %{
                   k: %{
                     0 => %{0 => "200", 1 => "First"},
                     1 => %{0 => "200", 1 => "Second"},
                     :kc => 2
                   },
                   s: 0
                 },
                 :r => 1,
                 :s => 1
               },
               :p => %{
                 0 => ["<li>\n    Outside assign: ", " Inside assign: ", "\n  </li>"],
                 1 => ["<ul>\n  ", "\n</ul>"],
                 2 => ["", "\n", ""]
               },
               :s => 2
             }
    end

    test "inside another comprehension" do
      items = [
        %{id: 1, name: "First"},
        %{id: 2, name: "Second"}
      ]

      assigns = %{socket: %Socket{}, items: items, __changed__: %{}}
      {full_render, _fingerprints, components} = render(comprehended_keyed_comprehension(assigns))

      assert full_render == %{
               0 => %{
                 k: %{
                   0 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => "100", 1 => "First"},
                           1 => %{0 => "100", 1 => "Second"},
                           :kc => 2
                         },
                         s: 0
                       },
                       :r => 1,
                       :s => 1
                     }
                   },
                   1 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => "200", 1 => "First"},
                           1 => %{0 => "200", 1 => "Second"},
                           :kc => 2
                         },
                         s: 0
                       },
                       :r => 1,
                       :s => 1
                     }
                   },
                   :kc => 2
                 },
                 s: 2
               },
               :p => %{
                 0 => ["<li>\n    Outside assign: ", " Inside assign: ", "\n  </li>"],
                 1 => ["<ul>\n  ", "\n</ul>"],
                 2 => ["\n  ", "\n"],
                 3 => ["", ""]
               },
               :s => 3
             }

      assert {%{}, %{}, 1} = components
    end

    test "vars_changed is reset for new items" do
      items = [
        %{id: 1, name: "First"},
        %{id: 2, name: "Second"}
      ]

      assigns = %{socket: %Socket{}, items: items, __changed__: %{}}

      {full_render, fingerprints, components} =
        render(comprehended_keyed_comprehension_with_slot(assigns))

      assert full_render == %{
               0 => %{
                 k: %{
                   0 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => %{0 => "100", 1 => "First", :s => 0}},
                           1 => %{0 => %{0 => "100", 1 => "Second", :s => 0}},
                           :kc => 2
                         },
                         s: 1
                       },
                       :r => 1,
                       :s => 2
                     }
                   },
                   1 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => %{0 => "200", 1 => "First", :s => 0}},
                           1 => %{0 => %{0 => "200", 1 => "Second", :s => 0}},
                           :kc => 2
                         },
                         s: 1
                       },
                       :r => 1,
                       :s => 2
                     }
                   },
                   :kc => 2
                 },
                 s: 3
               },
               :p => %{
                 0 => ["\n    Outside assign: ", " Inside assign: ", "\n  "],
                 1 => ["<li>\n    ", "}\n  </li>"],
                 2 => ["<ul>\n  ", "\n</ul>"],
                 3 => ["\n  ", "\n"],
                 4 => ["", ""]
               },
               :s => 4
             }

      assert {%{}, %{}, 1} = components

      assigns =
        Phoenix.Component.assign(assigns, :items, [
          %{id: 3, name: "Third"},
          %{id: 2, name: "Second"}
        ])

      assert {second_render, _fingerprints, _components} =
               render(
                 comprehended_keyed_comprehension_with_slot(assigns),
                 fingerprints,
                 components
               )

      # we still get 100 and 200 from the outer comprehension, even those did not change
      assert second_render == %{
               0 => %{
                 k: %{
                   0 => %{
                     0 => %{
                       0 => %{k: %{0 => %{0 => %{1 => "Third", :s => 0, 0 => "100"}}, :kc => 2}}
                     }
                   },
                   1 => %{
                     0 => %{
                       0 => %{k: %{0 => %{0 => %{1 => "Third", :s => 0, 0 => "200"}}, :kc => 2}}
                     }
                   },
                   :kc => 2
                 }
               },
               :p => %{0 => ["\n    Outside assign: ", " Inside assign: ", "\n  "]}
             }
    end

    test ":key on components" do
      list_of_items = [
        {1,
         [
           %{id: 1, name: "First"},
           %{id: 2, name: "Second"}
         ]},
        {2,
         [
           %{id: 1, name: "Third"},
           %{id: 2, name: "Fourth"}
         ]}
      ]

      assigns = %{socket: %Socket{}, list_of_items: list_of_items, count: 0, __changed__: %{}}

      {full_render, fingerprints, components} =
        render(keyed_comprehension_with_component(assigns))

      assert full_render == %{
               0 => %{
                 k: %{
                   0 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => "0", 1 => "First"},
                           1 => %{0 => "0", 1 => "Second"},
                           :kc => 2
                         },
                         s: 0
                       },
                       :r => 1,
                       :s => 1
                     }
                   },
                   1 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => "0", 1 => "Third"},
                           1 => %{0 => "0", 1 => "Fourth"},
                           :kc => 2
                         },
                         s: 0
                       },
                       :r => 1,
                       :s => 1
                     }
                   },
                   :kc => 2
                 },
                 s: 2
               },
               :p => %{
                 0 => ["<li>\n    Outside assign: ", " Inside assign: ", "\n  </li>"],
                 1 => ["<ul>\n  ", "\n</ul>"],
                 2 => ["", ""],
                 3 => ["", ""]
               },
               :s => 3
             }

      # change order of items
      assigns =
        Phoenix.Component.assign(assigns, :list_of_items, Enum.reverse(assigns.list_of_items))

      {second_render, fingerprints, components} =
        render(keyed_comprehension_with_component(assigns), fingerprints, components)

      # only the order changed
      assert second_render == %{0 => %{k: %{0 => 1, 1 => 0, :kc => 2}}}

      # update count
      assigns = Phoenix.Component.assign(%{assigns | __changed__: %{}}, :count, 1)

      {third_render, _fingerprints, _components} =
        render(keyed_comprehension_with_component(assigns), fingerprints, components)

      # only sends the updated count
      assert third_render == %{
               0 => %{
                 k: %{
                   0 => %{0 => %{0 => %{k: %{0 => %{0 => "1"}, 1 => %{0 => "1"}, :kc => 2}}}},
                   1 => %{0 => %{0 => %{k: %{0 => %{0 => "1"}, 1 => %{0 => "1"}, :kc => 2}}}},
                   :kc => 2
                 }
               }
             }
    end

    test ":key on component with slots" do
      items = [
        %{id: 1, entries: [%{id: 1, title: "1-1"}, %{id: 2, title: "1-2"}]},
        %{id: 2, entries: [%{id: 1, title: "2-1"}, %{id: 2, title: "2-2"}]}
      ]

      assigns = %{socket: %Socket{}, items: items, count: 0, __changed__: %{}}

      {full_render, fingerprints, components} =
        render(keyed_comprehension_with_component_and_slots(assigns))

      assert full_render == %{
               0 => %{
                 k: %{
                   0 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => %{0 => "1-1", 1 => "0", :s => 0}},
                           1 => %{0 => %{0 => "1-2", 1 => "0", :s => 0}},
                           :kc => 2
                         },
                         s: 1
                       },
                       :r => 1,
                       :s => 2
                     }
                   },
                   1 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => %{0 => "2-1", 1 => "0", :s => 0}},
                           1 => %{0 => %{0 => "2-2", 1 => "0", :s => 0}},
                           :kc => 2
                         },
                         s: 1
                       },
                       :r => 1,
                       :s => 2
                     }
                   },
                   :kc => 2
                 },
                 s: 3
               },
               :p => %{
                 0 => ["\n    ", " ", "\n  "],
                 1 => ["<li>", "</li>"],
                 2 => ["<ul>\n  ", "\n</ul>"],
                 3 => ["", ""],
                 4 => ["", ""]
               },
               :s => 4
             }

      # change order of items
      assigns = Phoenix.Component.assign(assigns, :items, Enum.reverse(assigns.items))

      {second_render, fingerprints, components} =
        render(keyed_comprehension_with_component_and_slots(assigns), fingerprints, components)

      # only the order changed
      assert second_render == %{0 => %{k: %{0 => 1, 1 => 0, :kc => 2}}}

      # update count
      assigns = Phoenix.Component.assign(%{assigns | __changed__: %{}}, :count, 1)

      {third_render, _fingerprints, _components} =
        render(keyed_comprehension_with_component_and_slots(assigns), fingerprints, components)

      # :for on slots is not optimized right now :(
      assert third_render == %{
               0 => %{
                 k: %{
                   0 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => %{0 => "2-1", 1 => "1"}},
                           1 => %{0 => %{0 => "2-2", 1 => "1"}},
                           :kc => 2
                         }
                       }
                     }
                   },
                   1 => %{
                     0 => %{
                       0 => %{
                         k: %{
                           0 => %{0 => %{0 => "1-1", 1 => "1"}},
                           1 => %{0 => %{0 => "1-2", 1 => "1"}},
                           :kc => 2
                         }
                       }
                     }
                   },
                   :kc => 2
                 }
               }
             }
    end

    defmodule LiveComponentForIssue3904 do
      # https://github.com/phoenixframework/phoenix_live_view/pull/3904
      use Phoenix.LiveComponent

      def render(assigns) do
        ~H"""
        <div>
          <div :for={i <- 1..assigns.count}>
            Shared
            <%= if i == 2 do %>
              1 {2} 3
            <% end %>
            <%= if i > 0 do %>
              Always
            <% end %>
          </div>
        </div>
        """
      end
    end

    test "considers element rendered in shared live component trees as new" do
      assigns = %{}

      template = ~H"""
      <.live_component id={0} module={LiveComponentForIssue3904} count={1} />
      <.live_component id={1} module={LiveComponentForIssue3904} count={2} />
      """

      {full_render, _fingerprints, _components} = render(template)

      assert full_render == %{
               0 => 1,
               1 => 2,
               :c => %{
                 1 => %{
                   0 => %{
                     p: %{0 => ["\n      Always\n    "]},
                     s: ["<div>\n    Shared\n    ", "\n    ", "\n  </div>"],
                     k: %{0 => %{0 => "", 1 => %{s: 0}}, :kc => 1}
                   },
                   :r => 1,
                   :s => ["<div>\n  ", "\n</div>"]
                 },
                 2 => %{
                   0 => %{
                     p: %{0 => ["\n      Always\n    "], 1 => ["\n      1 ", " 3\n    "]},
                     k: %{
                       0 => %{0 => "", 1 => %{s: 0}},
                       1 => %{0 => %{0 => "2", :s => 1}, 1 => %{s: 0}},
                       :kc => 2
                     }
                   },
                   :s => 1
                 }
               },
               :p => %{0 => ["", "\n", ""]},
               :s => 0
             }

      assert rendered_to_binary(full_render) ==
               "<div>\n  <div>\n    Shared\n    \n    \n      Always\n    \n  </div>\n</div>\n<div>\n  <div>\n    Shared\n    \n    \n      Always\n    \n  </div><div>\n    Shared\n    \n      1 2 3\n    \n    \n      Always\n    \n  </div>\n</div>"
    end
  end
end

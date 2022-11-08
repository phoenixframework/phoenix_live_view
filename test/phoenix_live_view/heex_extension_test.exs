defmodule Phoenix.LiveView.HEExExtensionTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.Rendered

  defmodule View do
    use Phoenix.View, root: "test/support/templates/heex", path: ""
  end

  defmodule SampleComponent do
    use Phoenix.LiveComponent
    def render(assigns), do: ~H"FROM COMPONENT"
  end

  @assigns %{
    pre: "pre",
    inner_content: "inner",
    post: "post",
    socket: %Phoenix.LiveView.Socket{}
  }

  test "renders live engine to string" do
    assert Phoenix.View.render_to_string(View, "inner_live.html", @assigns) == "live: inner"
  end

  test "renders live engine with live engine to string" do
    assert Phoenix.View.render_to_string(View, "live_with_live.html", @assigns) ==
              "pre: pre\nlive: inner\npost: post"
  end

  test "renders live engine with comprehension to string" do
    assigns = Map.put(@assigns, :points, [])

    assert Phoenix.View.render_to_string(View, "live_with_comprehension.html", assigns) ==
              "pre: pre\n\npost: post"

    assigns = Map.put(@assigns, :points, [%{x: 1, y: 2}, %{x: 3, y: 4}])

    assert Phoenix.View.render_to_string(View, "live_with_comprehension.html", assigns) ==
              "pre: pre\n\n  x: 1\n  live: inner\n  y: 2\n\n  x: 3\n  live: inner\n  y: 4\n\npost: post"
  end

  test "renders live engine as is" do
    assert %Rendered{static: ["live: ", ""], dynamic: ["inner"]} =
              Phoenix.View.render(View, "inner_live.html", @assigns) |> expand_rendered(true)
  end

  test "renders live engine with nested live view" do
    assert %Rendered{
              static: ["pre: ", "\n", "\npost: ", ""],
              dynamic: [
                "pre",
                %Rendered{dynamic: ["inner"], static: ["live: ", ""]},
                "post"
              ]
            } =
              Phoenix.View.render(View, "live_with_live.html", @assigns) |> expand_rendered(true)
  end

  test "renders live engine with nested dead view" do
    assert %Rendered{
              static: ["pre: ", "\n", "\npost: ", ""],
              dynamic: ["pre", ["dead: ", "inner"], "post"]
            } =
              Phoenix.View.render(View, "live_with_dead.html", @assigns) |> expand_rendered(true)
  end

  test "renders dead engine with nested live view" do
    assert Phoenix.View.render(View, "dead_with_live.html", @assigns) ==
              {:safe, ["pre: ", "pre", "\n", ["live: ", "inner", ""], "\npost: ", "post"]}
  end

  test "renders dead engine with function component" do
    assert %Rendered{
              static: ["pre: ", "\n", "\npost: ", ""],
              dynamic: ["pre", %Rendered{dynamic: ["the value"], static: ["COMPONENT:", ""]}, "post"]
            } =
              Phoenix.View.render(View, "dead_with_function_component.html", @assigns) |> expand_rendered(true)
  end

  test "renders dead engine with function component with inner content" do
    assert %Rendered{
              static: ["pre: ", "\n", "\npost: ", ""],
              dynamic: [
                "pre",
                %Rendered{
                  dynamic: [
                    "the value",
                    %Rendered{dynamic: [], static: ["\n  The inner content\n"]}
                  ],
                  static: ["COMPONENT:", ", Content: ", ""]
                },
                "post"
              ]
            } =
              Phoenix.View.render(View, "dead_with_function_component_with_inner_content.html", @assigns)
              |> expand_rendered(true)
  end

  defp expand_dynamic(dynamic, track_changes?) do
    Enum.map(dynamic.(track_changes?), &expand_rendered(&1, track_changes?))
  end

  defp expand_rendered(%Rendered{} = rendered, track_changes?) do
    update_in(rendered.dynamic, &expand_dynamic(&1, track_changes?))
  end

  defp expand_rendered(other, _track_changes), do: other
end

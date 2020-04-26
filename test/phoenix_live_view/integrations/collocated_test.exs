defmodule Phoenix.LiveView.CollocatedTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{
    Endpoint,
    CollocatedLive,
    CollocatedLiveSpecifyingExtension,
    CollocatedLiveSpecifyingEngine,
    CollocatedComponent,
    CollocatedComponentSpecifyingExtension,
    CollocatedComponentSpecifyingEngine
  }

  @endpoint Endpoint

  test "supports collocated views" do
    {:ok, view, html} = live_isolated(build_conn(), CollocatedLive)
    assert html =~ "Hello collocated world from live!\n</div>"
    assert render(view) =~ "Hello collocated world from live!\n</div>"
  end

  test "supports collocated views with custom extension" do
    {:ok, view, html} = live_isolated(build_conn(), CollocatedLiveSpecifyingExtension)
    assert html =~ "Hello collocated world from template with .foo extension!\n</div>"
    assert render(view) =~ "Hello collocated world from template with .foo extension!\n</div>"
  end

  test "supports collocated views with custom engine" do
    {:ok, view, html} = live_isolated(build_conn(), CollocatedLiveSpecifyingEngine)
    assert html =~ "Hello collocated world from live,\ncompiled by FooEngine!"
    assert render(view) =~ "Hello collocated world from live,\ncompiled by FooEngine!"
  end

  test "supports collocated components" do
    assert render_component(CollocatedComponent, world: "world") =~
             "Hello collocated world from component!\n"
  end

  test "supports collocated components with custom extension" do
    assert render_component(CollocatedComponentSpecifyingExtension, world: "world") =~
             "Hello collocated world from component with .foo extension!\n"
  end

  test "supports collocated components with custom engine" do
    assert render_component(CollocatedComponentSpecifyingEngine, world: "world") =~
             "Hello collocated world from component,\ncompiled by FooEngine!"
  end
end

defmodule Phoenix.LiveView.DetachedRootTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{
    Endpoint,
    DetachedRootLive,
    DetachedRootComponent,
    RootAndPathLive,
    RootAndPathComponent
  }

  @endpoint Endpoint

  test "supports detached views" do
    {:ok, view, html} = live_isolated(build_conn(), DetachedRootLive)
    assert html =~ "Hello detached world from live!\n</div>"
    assert render(view) =~ "Hello detached world from live!\n</div>"
  end

  test "supports detached components" do
    assert render_component(DetachedRootComponent, world: "world") =~
             "Hello detached world from component!\n"
  end

  test "supports path parameter in views" do
    {:ok, view, html} = live_isolated(build_conn(), RootAndPathLive)
    assert html =~ "Hello detached world from live!\n</div>"
    assert render(view) =~ "Hello detached world from live!\n</div>"
  end

  test "supports path parameter in components" do
    assert render_component(RootAndPathComponent, world: "world") =~
             "Hello detached world from component!\n"
  end
end

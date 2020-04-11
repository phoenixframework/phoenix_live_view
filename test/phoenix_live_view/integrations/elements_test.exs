defmodule Phoenix.LiveView.ElementsTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint}

  @endpoint Endpoint

  setup do
    {:ok, live, _} = live(Phoenix.ConnTest.build_conn(), "/elements")
    %{live: live}
  end

  describe "render/1" do
    test "renders a given element", %{live: view} do
      assert view |> element("#scoped-render") |> render() ==
               ~s|<div id="scoped-render"><span>This</span> is a div</div>|
    end

    test "renders with text filter", %{live: view} do
      assert view |> element("div", "This is a div") |> render() ==
               ~s|<div id="scoped-render"><span>This</span> is a div</div>|

      assert view |> element("#scoped-render", "This is a div") |> render() ==
               ~s|<div id="scoped-render"><span>This</span> is a div</div>|

      assert view |> element("#scoped-render", ~r/^This is a div$/) |> render() ==
               ~s|<div id="scoped-render"><span>This</span> is a div</div>|
    end

    test "raises on bad selector", %{live: view} do
      assert_raise ArgumentError,
                   "expected selector \"div\" to return a single element, but got 3",
                   fn -> view |> element("div") |> render() end

      assert_raise ArgumentError,
                   "expected selector \"#unknown\" to return a single element, but got none",
                   fn -> view |> element("#unknown") |> render() end
    end

    test "raises on bad selector with text filter", %{live: view} do
      assert_raise ArgumentError,
                   "selector \"#scoped-render\" did not match text filter \"This is not a div\", got: \"This is a div\"",
                   fn -> view |> element("#scoped-render", "This is not a div") |> render() end

      assert_raise ArgumentError,
                   "selector \"div\" returned 3 elements but none matched the text filter \"This is not a div\"",
                   fn -> view |> element("div", "This is not a div") |> render() end

      assert_raise ArgumentError,
                   "selector \"div\" returned 3 elements and 2 of them matched the text filter \"This\"",
                   fn -> view |> element("div", "This") |> render() end
    end
  end
end

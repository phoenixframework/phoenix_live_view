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

  describe "has_element?/1" do
    test "checks if given element is on the page", %{live: view} do
      assert view |> element("div") |> has_element?()
      assert view |> element("#scoped-render") |> has_element?()
      assert view |> element("div", "This is a div") |> has_element?()
      assert view |> element("#scoped-render", ~r/^This is a div$/) |> has_element?()

      refute view |> element("#unknown") |> has_element?()
      refute view |> element("div", "no matching text") |> has_element?()
    end
  end

  describe "has_element?/3" do
    test "checks if given element is on the page", %{live: view} do
      assert has_element?(view, "div")
      assert has_element?(view, "#scoped-render")
      assert has_element?(view, "div", "This is a div")
      assert has_element?(view, "#scoped-render", ~r/^This is a div$/)

      refute has_element?(view, "#unknown")
      refute has_element?(view, "div", "no matching text")
    end
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

  describe "render_click" do
    test "clicks the given element", %{live: view} do
      assert view |> element("span#span-click-no-value") |> render_click() =~ ~s|span-click: %{}|
    end

    test "clicks the given element with value", %{live: view} do
      assert view |> element("span#span-click-value") |> render_click() =~
               ~s|span-click: %{&quot;extra&quot; =&gt; &quot;456&quot;, &quot;value&quot; =&gt; &quot;123&quot;}|

      assert view |> element("span#span-click-value") |> render_click(%{"value" => "override"}) =~
               ~s|span-click: %{&quot;extra&quot; =&gt; &quot;456&quot;, &quot;value&quot; =&gt; &quot;override&quot;}|
    end

    test "clicks the given element with phx-value", %{live: view} do
      assert view |> element("span#span-click-phx-value") |> render_click() =~
               ~s|span-click: %{&quot;bar&quot; =&gt; &quot;456&quot;, &quot;foo&quot; =&gt; &quot;123&quot;}|

      assert view |> element("span#span-click-phx-value") |> render_click(%{"foo" => "override"}) =~
               ~s|span-click: %{&quot;bar&quot; =&gt; &quot;456&quot;, &quot;foo&quot; =&gt; &quot;override&quot;}|
    end

    test "raises if element does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"span#span-no-attr\" does not have phx-click attribute",
                   fn -> view |> element("span#span-no-attr") |> render_click() end
    end

    test "clicks links", %{live: view} do
      assert view |> element("a#click-a") |> render_click() =~ ~s|link: %{}|
    end

    test "clicks redirect links without phx-click", %{live: view} do
      assert {:error, {:redirect, %{to: "/"}}} = view |> element("a#redirect-a") |> render_click()
      assert_redirected(view, "/")
    end

    test "clicks live redirect links without phx-click", %{live: view} do
      assert {:error, {:live_redirect, %{to: "/example", kind: :push}}} =
               view |> element("a#live-redirect-a") |> render_click()

      assert_redirected(view, "/example")
    end

    test "clicks live redirect links without phx-click and kind is replace", %{live: view} do
      assert {:error, {:live_redirect, %{to: "/example", kind: :replace}}} =
               view |> element("a#live-redirect-replace-a") |> render_click()

      assert_redirected(view, "/example")
    end

    test "clicks live patch links without phx-click", %{live: view} do
      assert view |> element("a#live-patch-a") |> render_click() =~
               "handle_params: %{&quot;from&quot; =&gt; &quot;uri&quot;}"

      assert_patched(view, "/elements?from=uri")
    end

    test "raises if link does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "clicked link selected by \"a#a-no-attr\" does not have phx-click or href attributes",
                   fn -> view |> element("a#a-no-attr") |> render_click() end
    end
  end

  describe "render_hook" do
    test "hooks the given element", %{live: view} do
      assert view |> element("section#hook-section") |> render_hook("custom-event") =~
               ~s|custom-event: %{}|

      assert view
             |> element("section#hook-section")
             |> render_hook("custom-event", %{foo: "bar"}) =~
               ~s|custom-event: %{&quot;foo&quot; =&gt; &quot;bar&quot;}|
    end

    test "raises if element does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"span#span-no-attr\" does not have phx-hook attribute",
                   fn -> view |> element("span#span-no-attr") |> render_hook("custom-event") end
    end

    test "raises if element does not have id", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"section.idless-hook\" for phx-hook does not have an ID",
                   fn ->
                     view |> element("section.idless-hook") |> render_hook("custom-event")
                   end
    end
  end

  describe "render_blur" do
    test "blurs the given element", %{live: view} do
      assert view |> element("span#span-blur-no-value") |> render_blur() =~ ~s|span-blur: %{}|
    end

    test "blurs the given element with value", %{live: view} do
      assert view |> element("span#span-blur-value") |> render_blur() =~
               ~s|span-blur: %{&quot;extra&quot; =&gt; &quot;456&quot;, &quot;value&quot; =&gt; &quot;123&quot;}|

      assert view |> element("span#span-blur-value") |> render_blur(%{"value" => "override"}) =~
               ~s|span-blur: %{&quot;extra&quot; =&gt; &quot;456&quot;, &quot;value&quot; =&gt; &quot;override&quot;}|
    end

    test "blurs the given element with phx-value", %{live: view} do
      assert view |> element("span#span-blur-phx-value") |> render_blur() =~
               ~s|span-blur: %{&quot;bar&quot; =&gt; &quot;456&quot;, &quot;foo&quot; =&gt; &quot;123&quot;}|

      assert view |> element("span#span-blur-phx-value") |> render_blur(%{"foo" => "override"}) =~
               ~s|span-blur: %{&quot;bar&quot; =&gt; &quot;456&quot;, &quot;foo&quot; =&gt; &quot;override&quot;}|
    end

    test "raises if element does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"span#span-no-attr\" does not have phx-blur attribute",
                   fn -> view |> element("span#span-no-attr") |> render_blur() end
    end
  end

  describe "render_focus" do
    test "focuses the given element", %{live: view} do
      assert view |> element("span#span-focus-no-value") |> render_focus() =~ ~s|span-focus: %{}|
    end

    test "focuses the given element with value", %{live: view} do
      assert view |> element("span#span-focus-value") |> render_focus() =~
               ~s|span-focus: %{&quot;extra&quot; =&gt; &quot;456&quot;, &quot;value&quot; =&gt; &quot;123&quot;}|

      assert view |> element("span#span-focus-value") |> render_focus(%{"value" => "override"}) =~
               ~s|span-focus: %{&quot;extra&quot; =&gt; &quot;456&quot;, &quot;value&quot; =&gt; &quot;override&quot;}|
    end

    test "focuses the given element with phx-value", %{live: view} do
      assert view |> element("span#span-focus-phx-value") |> render_focus() =~
               ~s|span-focus: %{&quot;bar&quot; =&gt; &quot;456&quot;, &quot;foo&quot; =&gt; &quot;123&quot;}|

      assert view |> element("span#span-focus-phx-value") |> render_focus(%{"foo" => "override"}) =~
               ~s|span-focus: %{&quot;bar&quot; =&gt; &quot;456&quot;, &quot;foo&quot; =&gt; &quot;override&quot;}|
    end

    test "raises if element does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"span#span-no-attr\" does not have phx-focus attribute",
                   fn -> view |> element("span#span-no-attr") |> render_focus() end
    end
  end
end

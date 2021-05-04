defmodule Phoenix.LiveView.ElementsTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint}

  @endpoint Endpoint

  defp last_event(view) do
    view |> element("#last-event") |> render() |> HtmlEntities.decode()
  end

  setup do
    conn = Phoenix.ConnTest.build_conn()
    {:ok, live, _} = live(conn, "/elements")
    %{live: live, conn: conn}
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
                   ~r/expected selector "div" to return a single element, but got 3/,
                   fn -> view |> element("div") |> render() end

      assert_raise ArgumentError,
                   ~r/expected selector "#unknown" to return a single element, but got none/,
                   fn -> view |> element("#unknown") |> render() end
    end

    test "raises on bad selector with text filter", %{live: view} do
      assert_raise ArgumentError,
                   ~r/selector "#scoped-render" did not match text filter "This is not a div", got: \n\n    <div id="scoped-render"><span>This<\/span> is a div<\/div>/,
                   fn -> view |> element("#scoped-render", "This is not a div") |> render() end

      assert_raise ArgumentError,
                   ~r/selector "div" returned 3 elements but none matched the text filter "This is not a div"/,
                   fn -> view |> element("div", "This is not a div") |> render() end

      assert_raise ArgumentError,
                   ~r/selector "div" returned 3 elements and 2 of them matched the text filter "This"/,
                   fn -> view |> element("div", "This") |> render() end
    end
  end

  describe "render_click" do
    test "clicks the given element", %{live: view} do
      assert view |> element("span#span-click-no-value") |> render_click() |> is_binary()
      assert last_event(view) =~ ~s|span-click: %{}|
    end

    test "clicks the given element with value and proper escaping", %{live: view} do
      assert view |> element("span#span-click-value") |> render_click() =~
               ~s|span-click: %{&quot;extra&quot; =&gt; &quot;&lt;456&gt;&quot;, &quot;value&quot; =&gt; &quot;123&quot;}|

      assert view |> element("span#span-click-value") |> render_click(%{"value" => "override"}) =~
               ~s|span-click: %{&quot;extra&quot; =&gt; &quot;&lt;456&gt;&quot;, &quot;value&quot; =&gt; &quot;override&quot;}|
    end

    test "clicks the given element with phx-value", %{live: view} do
      assert view |> element("span#span-click-phx-value") |> render_click() |> is_binary()

      assert last_event(view) =~
               ~s|span-click: %{"bar" => "456", "foo" => "123"}|

      assert view
             |> element("span#span-click-phx-value")
             |> render_click(%{"foo" => "override"})
             |> is_binary()

      assert last_event(view) =~
               ~s|span-click: %{"bar" => "456", "foo" => "override"}|
    end

    test "raises if element does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"span#span-no-attr\" does not have phx-click attribute",
                   fn -> view |> element("span#span-no-attr") |> render_click() end
    end

    test "raises if element is disabled", %{live: view} do
      assert_raise ArgumentError,
                   "cannot click element \"button#button-disabled-click\" because it is disabled",
                   fn -> view |> element("button#button-disabled-click") |> render_click() end
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
      assert view |> element("a#live-patch-a") |> render_click() |> is_binary()
      assert last_event(view) =~ ~s|handle_params: %{"from" => "uri"}|

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
      assert view |> element("section#hook-section") |> render_hook("custom-event") |> is_binary()

      assert last_event(view) =~
               ~s|custom-event: %{}|

      assert view
             |> element("section#hook-section")
             |> render_hook("custom-event", %{foo: "bar"})
             |> is_binary()

      assert last_event(view) =~
               ~s|custom-event: %{"foo" => "bar"}|
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
      assert view |> element("span#span-blur-no-value") |> render_blur() |> is_binary()
      assert last_event(view) =~ ~s|span-blur: %{}|
    end

    test "blurs the given element with value", %{live: view} do
      assert view |> element("span#span-blur-value") |> render_blur() |> is_binary()

      assert last_event(view) =~
               ~s|span-blur: %{"extra" => "456", "value" => "123"}|

      assert view
             |> element("span#span-blur-value")
             |> render_blur(%{"value" => "override"})
             |> is_binary()

      assert last_event(view) =~
               ~s|span-blur: %{"extra" => "456", "value" => "override"}|
    end

    test "blurs the given element with phx-value", %{live: view} do
      assert view |> element("span#span-blur-phx-value") |> render_blur() |> is_binary()

      assert last_event(view) =~
               ~s|span-blur: %{"bar" => "456", "foo" => "123"}|

      assert view
             |> element("span#span-blur-phx-value")
             |> render_blur(%{"foo" => "override"})
             |> is_binary()

      assert last_event(view) =~
               ~s|span-blur: %{"bar" => "456", "foo" => "override"}|
    end

    test "raises if element does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"span#span-no-attr\" does not have phx-blur attribute",
                   fn -> view |> element("span#span-no-attr") |> render_blur() end
    end
  end

  describe "render_focus" do
    test "focuses the given element", %{live: view} do
      assert view |> element("span#span-focus-no-value") |> render_focus() |> is_binary()
      assert last_event(view) =~ ~s|span-focus: %{}|
    end

    test "focuses the given element with value", %{live: view} do
      assert view |> element("span#span-focus-value") |> render_focus() |> is_binary()

      assert last_event(view) =~
               ~s|span-focus: %{"extra" => "456", "value" => "123"}|

      assert view
             |> element("span#span-focus-value")
             |> render_focus(%{"value" => "override"})
             |> is_binary()

      assert last_event(view) =~
               ~s|span-focus: %{"extra" => "456", "value" => "override"}|
    end

    test "focuses the given element with phx-value", %{live: view} do
      assert view |> element("span#span-focus-phx-value") |> render_focus() |> is_binary()

      assert last_event(view) =~
               ~s|span-focus: %{"bar" => "456", "foo" => "123"}|

      assert view
             |> element("span#span-focus-phx-value")
             |> render_focus(%{"foo" => "override"})
             |> is_binary()

      assert last_event(view) =~
               ~s|span-focus: %{"bar" => "456", "foo" => "override"}|
    end

    test "raises if element does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"span#span-no-attr\" does not have phx-focus attribute",
                   fn -> view |> element("span#span-no-attr") |> render_focus() end
    end
  end

  describe "render_keyup" do
    test "keyups the given element", %{live: view} do
      assert view |> element("span#span-keyup-no-value") |> render_keyup() |> is_binary()
      assert last_event(view) =~ ~s|span-keyup: %{}|
    end

    test "keyups the given element with value", %{live: view} do
      assert view |> element("span#span-keyup-value") |> render_keyup() |> is_binary()

      assert last_event(view) =~
               ~s|span-keyup: %{"extra" => "456", "value" => "123"}|

      assert view
             |> element("span#span-keyup-value")
             |> render_keyup(%{"value" => "override"})
             |> is_binary()

      assert last_event(view) =~
               ~s|span-keyup: %{"extra" => "456", "value" => "override"}|
    end

    test "keyups the given element with phx-value", %{live: view} do
      assert view |> element("span#span-keyup-phx-value") |> render_keyup() |> is_binary()

      assert last_event(view) =~
               ~s|span-keyup: %{"bar" => "456", "foo" => "123"}|

      assert view
             |> element("span#span-keyup-phx-value")
             |> render_keyup(%{"foo" => "override"})
             |> is_binary()

      assert last_event(view) =~
               ~s|span-keyup: %{"bar" => "456", "foo" => "override"}|
    end

    test "keyups the given element with phx-window-keyup", %{live: view} do
      assert view |> element("span#span-window-keyup-phx-value") |> render_keyup() |> is_binary()

      assert last_event(view) =~
               ~s|span-window-keyup: %{"bar" => "456", "foo" => "123"}|
    end

    test "raises if element does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"span#span-no-attr\" does not have phx-keyup or phx-window-keyup attributes",
                   fn -> view |> element("span#span-no-attr") |> render_keyup() end
    end
  end

  describe "render_keydown" do
    test "keydowns the given element", %{live: view} do
      assert view |> element("span#span-keydown-no-value") |> render_keydown() |> is_binary()
      assert last_event(view) =~ ~s|span-keydown: %{}|
    end

    test "keydowns the given element with value", %{live: view} do
      assert view |> element("span#span-keydown-value") |> render_keydown() |> is_binary()
      assert last_event(view) =~ ~s|span-keydown: %{"extra" => "456", "value" => "123"}|

      assert view
             |> element("span#span-keydown-value")
             |> render_keydown(%{"value" => "override"})
             |> is_binary()

      assert last_event(view) =~ ~s|span-keydown: %{"extra" => "456", "value" => "override"}|
    end

    test "keydowns the given element with phx-value", %{live: view} do
      assert view |> element("span#span-keydown-phx-value") |> render_keydown() |> is_binary()
      assert last_event(view) =~ ~s|span-keydown: %{"bar" => "456", "foo" => "123"}|

      assert view
             |> element("span#span-keydown-phx-value")
             |> render_keydown(%{"foo" => "override"})
             |> is_binary()

      assert last_event(view) =~ ~s|span-keydown: %{"bar" => "456", "foo" => "override"}|
    end

    test "keydowns the given element with phx-window-keydown", %{live: view} do
      assert view
             |> element("span#span-window-keydown-phx-value")
             |> render_keydown()
             |> is_binary()

      assert last_event(view) =~ ~s|span-window-keydown: %{"bar" => "456", "foo" => "123"}|
    end

    test "raises if element does not have attribute", %{live: view} do
      assert_raise ArgumentError,
                   "element selected by \"span#span-no-attr\" does not have phx-keydown or phx-window-keydown attributes",
                   fn -> view |> element("span#span-no-attr") |> render_keydown() end
    end
  end

  describe "render_change" do
    test "raises if element is not a form", %{live: view} do
      assert_raise ArgumentError, "phx-change is only allowed in forms, got \"a\"", fn ->
        view |> element("#a-no-form") |> render_change()
      end
    end

    test "changes the given element", %{live: view} do
      assert view |> element("#empty-form") |> render_change()
      assert last_event(view) =~ ~s|form-change: %{}|

      assert view |> element("#empty-form") |> render_change(foo: "bar")
      assert last_event(view) =~ ~s|form-change: %{"foo" => "bar"}|

      assert view |> element("#empty-form") |> render_change(%{"foo" => "bar"})
      assert last_event(view) =~ ~s|form-change: %{"foo" => "bar"}|
    end
  end

  describe "render_submit" do
    test "raises if element is not a form", %{live: view} do
      assert_raise ArgumentError, "phx-submit is only allowed in forms, got \"a\"", fn ->
        view |> element("#a-no-form") |> render_submit()
      end
    end

    test "submits the given element", %{live: view} do
      assert view |> element("#empty-form") |> render_submit()
      assert last_event(view) =~ ~s|form-submit: %{}|

      assert view |> element("#empty-form") |> render_submit(foo: "bar")
      assert last_event(view) =~ ~s|form-submit: %{"foo" => "bar"}|

      assert view |> element("#empty-form") |> render_submit(%{"foo" => "bar"})
      assert last_event(view) =~ ~s|form-submit: %{"foo" => "bar"}|
    end
  end

  describe "follow_trigger_action" do
    test "raises if element is not a form", %{live: view, conn: conn} do
      assert_raise ArgumentError,
                   ~r"given element did not return a form",
                   fn -> view |> element("#a-no-form") |> follow_trigger_action(conn) end
    end

    test "raises if element doesn't set phx-trigger-action on the form element",
         %{live: view, conn: conn} do
      assert_raise ArgumentError,
                   ~r"\"#empty-form\" does not have phx-trigger-action attribute",
                   fn -> view |> element("#empty-form") |> follow_trigger_action(conn) end
    end

    test "uses default method and request path", %{live: view, conn: conn} do
      view |> element("#trigger-form-default") |> render_submit()

      conn = view |> element("#trigger-form-default") |> follow_trigger_action(conn)
      assert conn.method == "GET"
      assert conn.request_path == "/elements"

      conn = view |> form("#trigger-form-default", %{"foo" => "bar"}) |> follow_trigger_action(conn)
      assert conn.method == "GET"
      assert conn.request_path == "/elements"
      assert conn.query_string == "foo=bar"

      conn = view |> form("#trigger-form-value", %{"baz" => "bat"}) |> follow_trigger_action(conn)
      assert conn.method == "POST"
      assert conn.request_path == "/not_found"
      assert conn.params == %{"baz" => "bat"}
    end
  end

  describe "form" do
    test "defaults", %{live: view} do
      view |> form("#form") |> render_change()
      form = last_event(view)
      assert form =~ ~s|form-change: %{"hello" => %{|

      # Element without types are still handle
      assert form =~ ~s|"no-type" => "value"|

      # Latest always wins
      assert form =~ ~s|"latest" => "new"|

      # Hidden elements too
      assert form =~ ~s|"hidden" => "hidden"|
      assert form =~ ~s|"hidden_or_checkbox" => "false"|
      assert form =~ ~s|"hidden_or_text" => "true"|

      # Radio stores checked one but not disabled and not checked
      assert form =~ ~s|"radio" => "2"|
      refute form =~ ~s|"not-checked-radio"|
      refute form =~ ~s|"disabled-radio"|

      # Checkbox stores checked ones but not disabled and not checked
      assert form =~ ~s|"checkbox" => "2"|
      refute form =~ ~s|"not-checked-checkbox"|
      refute form =~ ~s|"disabled-checkbox"|

      # Multiple checkbox
      assert form =~ ~s|"multiple-checkbox" => ["2", "3"]|

      # Select
      assert form =~ ~s|"selected" => "1"|
      assert form =~ ~s|"not-selected" => "blank"|

      # Multiple Select
      assert form =~ ~s|"multiple-select" => ["2", "3"]|

      # Text area
      assert form =~ ~s|"textarea" => "Text"|
      assert form =~ ~s|"textarea_nl" => "Text"|

      # Ignore everything with no name, disabled, or submits
      refute form =~ "no-name"
      refute form =~ "disabled"
      refute form =~ "ignore-submit"
      refute form =~ "ignore-image"
    end

    test "fill in target", %{live: view} do
      view |> form("#form") |> render_change(%{"_target" => "order_item[addons][][name]"})
      form = last_event(view)
      assert form =~ ~s|"hello" => %{|
      assert form =~ ~s|%{"_target" => ["order_item", "addons", "name"]|
    end

    test "fill in missing", %{live: view} do
      assert_raise ArgumentError,
                   ~r/could not find non-disabled input, select or textarea with name "hello\[unknown\]"/,
                   fn -> view |> form("#form", hello: [unknown: "true"]) |> render_change() end
    end

    test "fill in forbidden", %{live: view} do
      assert_raise ArgumentError,
                   "cannot provide value to \"hello[ignore-submit]\" because submit inputs are never submitted",
                   fn ->
                     view |> form("#form", hello: ["ignore-submit": "true"]) |> render_change()
                   end

      assert_raise ArgumentError,
                   "cannot provide value to \"hello[ignore-image]\" because image inputs are never submitted",
                   fn ->
                     view |> form("#form", hello: ["ignore-image": "true"]) |> render_change()
                   end
    end

    test "fill in hidden", %{live: view} do
      assert_raise ArgumentError,
                   "value for hidden \"hello[hidden]\" must be one of [\"hidden\"], got: \"true\"",
                   fn -> view |> form("#form", hello: [hidden: "true"]) |> render_change() end

      assert view
             |> form("#form",
               hello: [
                 hidden: "hidden",
                 hidden_or_checkbox: "true",
                 hidden_or_text: "any text"
               ]
             )
             |> render_change()

      form = last_event(view)

      assert form =~ ~s|"hidden" => "hidden"|
      assert form =~ ~s|"hidden_or_checkbox" => "true"|
      assert form =~ ~s|"hidden_or_text" => "any text"|
    end

    test "fill in radio", %{live: view} do
      assert_raise ArgumentError,
                   "value for radio \"hello[radio]\" must be one of [\"1\", \"2\", \"3\"], got: \"unknown\"",
                   fn -> view |> form("#form", hello: [radio: "unknown"]) |> render_change() end

      assert view |> form("#form", hello: [radio: "1"]) |> render_change()
      assert last_event(view) =~ ~s|"radio" => "1"|

      assert_raise ArgumentError,
                   ~r/could not find non-disabled input, select or textarea with name "hello\[radio\]\[\]"/,
                   fn ->
                     view |> form("#form", hello: [radio: [1, 2]]) |> render_change()
                   end
    end

    test "fill in checkbox", %{live: view} do
      assert_raise ArgumentError,
                   "value for checkbox \"hello[checkbox]\" must be one of [\"1\", \"2\", \"3\"], got: \"unknown\"",
                   fn ->
                     view |> form("#form", hello: [checkbox: "unknown"]) |> render_change()
                   end

      assert view |> form("#form", hello: [checkbox: "1"]) |> render_change()
      assert last_event(view) =~ ~s|"checkbox" => "1"|

      assert_raise ArgumentError,
                   ~r/could not find non-disabled input, select or textarea with name "hello\[checkbox\]\[\]"/,
                   fn ->
                     view |> form("#form", hello: [checkbox: [1, 2]]) |> render_change()
                   end
    end

    test "fill in multiple checkbox", %{live: view} do
      assert_raise ArgumentError,
                   "value for checkbox \"hello[multiple-checkbox][]\" must be one of [\"1\", \"2\", \"3\"], got: \"unknown\"",
                   fn ->
                     view
                     |> form("#form", hello: ["multiple-checkbox": ["unknown"]])
                     |> render_change()
                   end

      assert view |> form("#form", hello: ["multiple-checkbox": [1, 2]]) |> render_change()
      assert last_event(view) =~ ~s|"multiple-checkbox" => ["1", "2"]|
    end

    test "fill in select", %{live: view} do
      assert_raise ArgumentError,
                   "value for select \"hello[selected]\" must be one of [\"blank\", \"1\", \"2\"], got: \"unknown\"",
                   fn ->
                     view |> form("#form", hello: [selected: "unknown"]) |> render_change()
                   end

      assert view |> form("#form", hello: [selected: "1"]) |> render_change()
      assert last_event(view) =~ ~s|"selected" => "1"|

      assert_raise ArgumentError,
                   ~r/could not find non-disabled input, select or textarea with name "hello\[selected\]\[\]"/,
                   fn ->
                     view |> form("#form", hello: [selected: [1, 2]]) |> render_change()
                   end
    end

    test "fill in multiple select", %{live: view} do
      assert_raise ArgumentError,
                   "value for multiple select \"hello[multiple-select][]\" must be one of [\"1\", \"2\", \"3\"], got: \"unknown\"",
                   fn ->
                     view
                     |> form("#form", hello: ["multiple-select": ["unknown"]])
                     |> render_change()
                   end

      assert view |> form("#form", hello: ["multiple-select": [1, 2]]) |> render_change()
      assert last_event(view) =~ ~s|"multiple-select" => ["1", "2"]|
    end

    test "fill in input", %{live: view} do
      assert view |> form("#form", hello: [latest: "i win"]) |> render_change()
      assert last_event(view) =~ ~s|"latest" => "i win"|

      assert view
             |> form("#form", hello: [latest: "i win"])
             |> render_change(hello: [latest: "i truly win"])

      assert last_event(view) =~ ~s|"latest" => "i truly win"|

      assert_raise ArgumentError,
                   ~r/could not find non-disabled input, select or textarea with name "hello\[latest\]\[\]"/,
                   fn ->
                     view |> form("#form", hello: [latest: ["i lose"]]) |> render_change()
                   end
    end

    test "fill in textarea", %{live: view} do
      assert view |> form("#form", hello: [textarea: "i win"]) |> render_change()
      assert last_event(view) =~ ~s|"textarea" => "i win"|

      assert view
             |> form("#form", hello: [textarea: "i win"])
             |> render_change(hello: [textarea: "i truly win"])

      assert last_event(view) =~ ~s|"textarea" => "i truly win"|

      assert_raise ArgumentError,
                   ~r/could not find non-disabled input, select or textarea with name "hello\[textarea\]\[\]"/,
                   fn ->
                     view |> form("#form", hello: [textarea: ["i lose"]]) |> render_change()
                   end
    end

    test "fill in calendar types", %{live: view} do
      assert_raise ArgumentError,
                   ~r/could not find non-disabled input, select or textarea with name "hello\[unknown\]"/,
                   fn ->
                     view |> form("#form", hello: [unknown: ~D"2020-04-17"]) |> render_change()
                   end

      assert view |> form("#form", hello: [date_text: "2020-04-17"]) |> render_change()
      assert last_event(view) =~ ~s|"date_text" => "2020-04-17"|

      assert view |> form("#form", hello: [date_select: ~D"2020-04-17"]) |> render_change()

      assert last_event(view) =~
               ~s|"date_select" => %{"day" => "17", "month" => "4", "year" => "2020"}|

      assert view |> form("#form", hello: [time_text: "14:15:16"]) |> render_change()
      assert last_event(view) =~ ~s|"time_text" => "14:15:16"|

      assert view |> form("#form", hello: [time_select: ~T"14:15:16"]) |> render_change()
      assert last_event(view) =~ ~s|"time_select" => %{"hour" => "14", "minute" => "15"}|

      assert view |> form("#form", hello: [naive_text: "2020-04-17 14:15:16"]) |> render_change()
      assert last_event(view) =~ ~s|"naive_text" => "2020-04-17 14:15:16"|

      assert view
             |> form("#form", hello: [naive_select: ~N"2020-04-17 14:15:16"])
             |> render_change()

      assert last_event(view) =~
               ~s|"naive_select" => %{"day" => "17", "hour" => "14", "minute" => "15", "month" => "4", "year" => "2020"}|

      assert view |> form("#form", hello: [utc_text: "2020-04-17 14:15:16Z"]) |> render_change()
      assert last_event(view) =~ ~s|"utc_text" => "2020-04-17 14:15:16Z"|

      assert view
             |> form("#form",
               hello: [utc_select: DateTime.from_naive!(~N"2020-04-17 14:15:16Z", "Etc/UTC")]
             )
             |> render_change()

      assert last_event(view) =~
               ~s|"utc_select" => %{"day" => "17", "hour" => "14", "minute" => "15", "month" => "4", "second" => "16", "year" => "2020"}|
    end
  end

  describe "open_browser" do
    setup do
      open_fun = fn path ->
        assert content = File.read!(path)

        assert content =~
                 ~r[<link rel="stylesheet" href="file:.*phoenix_live_view\/priv\/css\/custom\.css"\/>]

        assert content =~
                 ~r[<link rel="stylesheet" href="file:.*phoenix_live_view\/priv\/static\/css\/app\.css"\/>]

        assert content =~ "<link rel=\"stylesheet\" href=\"//example.com/a.css\"/>"
        assert content =~ "<link rel=\"stylesheet\" href=\"https://example.com/b.css\"/>"
        assert content =~ "body { background-color: #eee; }"
        refute content =~ "<script>"
        path
      end

      {:ok, live, _} = live(Phoenix.ConnTest.build_conn(), "/styled-elements")
      %{live: live, open_fun: open_fun}
    end

    test "render view", %{live: view, open_fun: open_fun} do
      assert view |> open_browser(open_fun) == view
    end

    test "render element", %{live: view, open_fun: open_fun} do
      element = element(view, "#scoped-render")
      assert element |> open_browser(open_fun) == element
    end
  end
end

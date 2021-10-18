defmodule Phoenix.LiveView.JSTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.JS

  describe "push" do
    test "with defaults" do
      assert JS.push("inc") == %JS{ops: [["push", %{event: "inc"}]]}
    end

    test "target" do
      assert JS.push("inc", target: "#modal") == %JS{
               ops: [["push", %{event: "inc", target: "#modal"}]]
             }

      assert JS.push("inc", target: 1) == %JS{
               ops: [["push", %{event: "inc", target: 1}]]
             }
    end

    test "loading" do
      assert JS.push("inc", loading: "#modal") == %JS{
               ops: [["push", %{event: "inc", loading: "#modal"}]]
             }
    end

    test "page_loading" do
      assert JS.push("inc", page_loading: true) == %JS{
               ops: [["push", %{event: "inc", page_loading: true}]]
             }
    end

    test "value" do
      assert JS.push("inc", value: %{one: 1, two: 2}) == %JS{
               ops: [["push", %{event: "inc", value: %{one: 1, two: 2}}]]
             }

      assert_raise ArgumentError, ~r/push :value expected to be a map/, fn ->
        JS.push("inc", value: "not-a-map")
      end
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for push/, fn ->
        JS.push("inc", to: "#modal", bad: :opt)
      end
    end

    test "composability" do
      js = JS.push("inc") |> JS.push("dec", loading: ".foo")

      assert js == %JS{
               ops: [["push", %{event: "inc"}], ["push", %{event: "dec", loading: ".foo"}]]
             }
    end

    test "encoding" do
      assert js_to_string(JS.push("inc", value: %{one: 1, two: 2})) ==
               "[[&quot;push&quot;,{&quot;event&quot;:&quot;inc&quot;,&quot;value&quot;:{&quot;one&quot;:1,&quot;two&quot;:2}}]]"
    end
  end

  describe "add_class" do
    test "with defaults" do
      assert JS.add_class("show") == %JS{
               ops: [["add_class", %{names: ["show"], time: 200, to: nil, transition: []}]]
             }

      assert JS.add_class("show", to: "#modal") == %JS{
               ops: [["add_class", %{names: ["show"], time: 200, to: "#modal", transition: []}]]
             }
    end

    test "multiple classes" do
      assert JS.add_class("show hl") == %JS{
               ops: [["add_class", %{names: ["show", "hl"], time: 200, to: nil, transition: []}]]
             }
    end

    test "custom time" do
      assert JS.add_class("show", time: 543) == %JS{
               ops: [["add_class", %{names: ["show"], time: 543, to: nil, transition: []}]]
             }
    end

    test "transition" do
      assert JS.add_class("show", transition: "fade") == %JS{
               ops: [["add_class", %{names: ["show"], time: 200, to: nil, transition: ["fade"]}]]
             }

      assert JS.add_class("c", transition: "a b") == %JS{
               ops: [["add_class", %{names: ["c"], time: 200, to: nil, transition: ["a", "b"]}]]
             }
    end

    test "composability" do
      js = JS.add_class("show", to: "#modal", time: 100) |> JS.add_class("hl")

      assert js == %JS{
               ops: [
                 ["add_class", %{names: ["show"], time: 100, to: "#modal", transition: []}],
                 ["add_class", %{names: ["hl"], time: 200, to: nil, transition: []}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for add_class/, fn ->
        JS.add_class("show", bad: :opt)
      end
    end

    test "encoding" do
      assert js_to_string(JS.add_class("show")) ==
               "[[&quot;add_class&quot;,{&quot;names&quot;:[&quot;show&quot;],&quot;time&quot;:200,&quot;to&quot;:null,&quot;transition&quot;:[]}]]"
    end
  end

  describe "remove_class" do
    test "with defaults" do
      assert JS.remove_class("show") == %JS{
               ops: [["remove_class", %{names: ["show"], time: 200, to: nil, transition: []}]]
             }

      assert JS.remove_class("show", to: "#modal") == %JS{
               ops: [
                 ["remove_class", %{names: ["show"], time: 200, to: "#modal", transition: []}]
               ]
             }
    end

    test "multiple classes" do
      assert JS.remove_class("show hl") == %JS{
               ops: [
                 ["remove_class", %{names: ["show", "hl"], time: 200, to: nil, transition: []}]
               ]
             }
    end

    test "custom time" do
      assert JS.remove_class("show", time: 543) == %JS{
               ops: [["remove_class", %{names: ["show"], time: 543, to: nil, transition: []}]]
             }
    end

    test "transition" do
      assert JS.remove_class("show", transition: "fade") == %JS{
               ops: [
                 ["remove_class", %{names: ["show"], time: 200, to: nil, transition: ["fade"]}]
               ]
             }

      assert JS.remove_class("c", transition: "a b") == %JS{
               ops: [
                 ["remove_class", %{names: ["c"], time: 200, to: nil, transition: ["a", "b"]}]
               ]
             }
    end

    test "composability" do
      js = JS.remove_class("show", to: "#modal", time: 100) |> JS.remove_class("hl")

      assert js == %JS{
               ops: [
                 ["remove_class", %{names: ["show"], time: 100, to: "#modal", transition: []}],
                 ["remove_class", %{names: ["hl"], time: 200, to: nil, transition: []}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for remove_class/, fn ->
        JS.remove_class("show", bad: :opt)
      end
    end

    test "encoding" do
      assert js_to_string(JS.remove_class("show")) ==
               "[[&quot;remove_class&quot;,{&quot;names&quot;:[&quot;show&quot;],&quot;time&quot;:200,&quot;to&quot;:null,&quot;transition&quot;:[]}]]"
    end
  end

  describe "dispatch" do
    test "with defaults" do
      assert JS.dispatch("click", to: "#modal") == %JS{
               ops: [["dispatch", %{to: "#modal", event: "click"}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for dispatch/, fn ->
        JS.dispatch("click", to: ".foo", bad: :opt)
      end
    end

    test "composability" do
      js = JS.dispatch("click", to: "#modal") |> JS.dispatch("keydown", to: "#keyboard")

      assert js == %JS{
               ops: [
                 ["dispatch", %{to: "#modal", event: "click"}],
                 ["dispatch", %{to: "#keyboard", event: "keydown"}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.dispatch("click", to: ".foo")) ==
               "[[&quot;dispatch&quot;,{&quot;event&quot;:&quot;click&quot;,&quot;to&quot;:&quot;.foo&quot;}]]"
    end
  end

  describe "toggle" do
    test "with defaults" do
      assert JS.toggle(to: "#modal") == %JS{
               ops: [["toggle", %{display: nil, ins: [], outs: [], time: 200, to: "#modal"}]]
             }
    end

    test "in and out classes" do
      assert JS.toggle(to: "#modal", in: "fade-in d-block", out: "fade-out d-block") ==
               %JS{
                 ops: [
                   [
                     "toggle",
                     %{
                       display: nil,
                       ins: ["fade-in", "d-block"],
                       outs: ["fade-out", "d-block"],
                       time: 200,
                       to: "#modal"
                     }
                   ]
                 ]
               }
    end

    test "custom time" do
      assert JS.toggle(to: "#modal", time: 123) == %JS{
               ops: [["toggle", %{display: nil, ins: [], outs: [], time: 123, to: "#modal"}]]
             }
    end

    test "custom display" do
      assert JS.toggle(to: "#modal", display: "block") == %JS{
               ops: [["toggle", %{display: "block", ins: [], outs: [], time: 200, to: "#modal"}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for toggle/, fn ->
        JS.toggle(to: "#modal", bad: :opt)
      end
    end

    test "composability" do
      js = JS.toggle(to: "#modal") |> JS.toggle(to: "#keyboard", time: 123)

      assert js == %JS{
               ops: [
                 ["toggle", %{to: "#modal", display: nil, ins: [], outs: [], time: 200}],
                 ["toggle", %{to: "#keyboard", display: nil, ins: [], outs: [], time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.toggle(to: "#modal")) ==
               "[[&quot;toggle&quot;,{&quot;display&quot;:null,&quot;ins&quot;:[],&quot;outs&quot;:[],&quot;time&quot;:200,&quot;to&quot;:&quot;#modal&quot;}]]"
    end
  end

  describe "show" do
    test "with defaults" do
      assert JS.show(to: "#modal") == %JS{
               ops: [["show", %{display: nil, transition: [], time: 200, to: "#modal"}]]
             }
    end

    test "transition classes" do
      assert JS.show(to: "#modal", transition: "fade-in d-block") ==
               %JS{
                 ops: [
                   [
                     "show",
                     %{
                       display: nil,
                       transition: ["fade-in", "d-block"],
                       time: 200,
                       to: "#modal"
                     }
                   ]
                 ]
               }
    end

    test "custom time" do
      assert JS.show(to: "#modal", time: 123) == %JS{
               ops: [["show", %{display: nil, transition: [], time: 123, to: "#modal"}]]
             }
    end

    test "custom display" do
      assert JS.show(to: "#modal", display: "block") == %JS{
               ops: [["show", %{display: "block", transition: [], time: 200, to: "#modal"}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for show/, fn ->
        JS.show(to: "#modal", bad: :opt)
      end
    end

    test "composability" do
      js = JS.show(to: "#modal") |> JS.show(to: "#keyboard", time: 123)

      assert js == %JS{
               ops: [
                 ["show", %{to: "#modal", display: nil, transition: [], time: 200}],
                 ["show", %{to: "#keyboard", display: nil, transition: [], time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.show(to: "#modal")) ==
               "[[&quot;show&quot;,{&quot;display&quot;:null,&quot;time&quot;:200,&quot;to&quot;:&quot;#modal&quot;,&quot;transition&quot;:[]}]]"
    end
  end

  describe "hide" do
    test "with defaults" do
      assert JS.hide(to: "#modal") == %JS{
               ops: [["hide", %{transition: [], time: 200, to: "#modal"}]]
             }
    end

    test "transition classes" do
      assert JS.hide(to: "#modal", transition: "fade-out d-block") ==
               %JS{
                 ops: [
                   [
                     "hide",
                     %{
                       transition: ["fade-out", "d-block"],
                       time: 200,
                       to: "#modal"
                     }
                   ]
                 ]
               }
    end

    test "custom time" do
      assert JS.hide(to: "#modal", time: 123) == %JS{
               ops: [["hide", %{transition: [], time: 123, to: "#modal"}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for hide/, fn ->
        JS.hide(to: "#modal", bad: :opt)
      end
    end

    test "composability" do
      js = JS.hide(to: "#modal") |> JS.hide(to: "#keyboard", time: 123)

      assert js == %JS{
               ops: [
                 ["hide", %{to: "#modal", transition: [], time: 200}],
                 ["hide", %{to: "#keyboard", transition: [], time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.hide(to: "#modal")) ==
               "[[&quot;hide&quot;,{&quot;time&quot;:200,&quot;to&quot;:&quot;#modal&quot;,&quot;transition&quot;:[]}]]"
    end
  end

  describe "transition" do
    test "with defaults" do
      assert JS.transition("shake") == %JS{
               ops: [["transition", %{names: ["shake"], time: 200, to: nil}]]
             }

      assert JS.transition("shake", to: "#modal") == %JS{
               ops: [["transition", %{names: ["shake"], time: 200, to: "#modal"}]]
             }

      assert JS.transition("shake swirl", to: "#modal") == %JS{
               ops: [["transition", %{names: ["shake", "swirl"], time: 200, to: "#modal"}]]
             }
    end

    test "custom time" do
      assert JS.transition("shake", to: "#modal", time: 123) == %JS{
               ops: [["transition", %{names: ["shake"], time: 123, to: "#modal"}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for transition/, fn ->
        JS.transition("shake", to: "#modal", bad: :opt)
      end
    end

    test "composability" do
      js = JS.transition("shake", to: "#modal") |> JS.transition("hl", to: "#keyboard", time: 123)

      assert js == %JS{
               ops: [
                 ["transition", %{to: "#modal", names: ["shake"], time: 200}],
                 ["transition", %{to: "#keyboard", names: ["hl"], time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.transition("shake", to: "#modal")) ==
               "[[&quot;transition&quot;,{&quot;names&quot;:[&quot;shake&quot;],&quot;time&quot;:200,&quot;to&quot;:&quot;#modal&quot;}]]"
    end
  end

  defp js_to_string(%JS{} = js) do
    js
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end

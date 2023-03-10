defmodule Phoenix.LiveView.JSTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.JS

  describe "exec" do
    test "with defaults" do
      assert JS.exec("phx-remove") == %JS{ops: [["exec", ["phx-remove"]]]}
      assert JS.exec("phx-remove", to: "#modal") == %JS{ops: [["exec", ["phx-remove", "#modal"]]]}
    end
  end

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
               ops: [
                 ["add_class", %{names: ["show"], time: 200, to: nil, transition: [[], [], []]}]
               ]
             }

      assert JS.add_class("show", to: "#modal") == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["show"], time: 200, to: "#modal", transition: [[], [], []]}
                 ]
               ]
             }
    end

    test "multiple classes" do
      assert JS.add_class("show hl") == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["show", "hl"], time: 200, to: nil, transition: [[], [], []]}
                 ]
               ]
             }
    end

    test "custom time" do
      assert JS.add_class("show", time: 543) == %JS{
               ops: [
                 ["add_class", %{names: ["show"], time: 543, to: nil, transition: [[], [], []]}]
               ]
             }
    end

    test "transition" do
      assert JS.add_class("show", transition: "fade") == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["show"], time: 200, to: nil, transition: [["fade"], [], []]}
                 ]
               ]
             }

      assert JS.add_class("c", transition: "a b") == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["c"], time: 200, to: nil, transition: [["a", "b"], [], []]}
                 ]
               ]
             }

      assert JS.add_class("show", transition: {"fade", "opacity-0", "opacity-100"}) == %JS{
               ops: [
                 [
                   "add_class",
                   %{
                     names: ["show"],
                     time: 200,
                     to: nil,
                     transition: [["fade"], ["opacity-0"], ["opacity-100"]]
                   }
                 ]
               ]
             }
    end

    test "composability" do
      js = JS.add_class("show", to: "#modal", time: 100) |> JS.add_class("hl")

      assert js == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["show"], time: 100, to: "#modal", transition: [[], [], []]}
                 ],
                 ["add_class", %{names: ["hl"], time: 200, to: nil, transition: [[], [], []]}]
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
               "[[&quot;add_class&quot;,{&quot;names&quot;:[&quot;show&quot;],&quot;time&quot;:200,&quot;to&quot;:null,&quot;transition&quot;:[[],[],[]]}]]"
    end
  end

  describe "remove_class" do
    test "with defaults" do
      assert JS.remove_class("show") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], time: 200, to: nil, transition: [[], [], []]}
                 ]
               ]
             }

      assert JS.remove_class("show", to: "#modal") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], time: 200, to: "#modal", transition: [[], [], []]}
                 ]
               ]
             }
    end

    test "multiple classes" do
      assert JS.remove_class("show hl") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show", "hl"], time: 200, to: nil, transition: [[], [], []]}
                 ]
               ]
             }
    end

    test "custom time" do
      assert JS.remove_class("show", time: 543) == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], time: 543, to: nil, transition: [[], [], []]}
                 ]
               ]
             }
    end

    test "transition" do
      assert JS.remove_class("show", transition: "fade") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], time: 200, to: nil, transition: [["fade"], [], []]}
                 ]
               ]
             }

      assert JS.remove_class("c", transition: "a b") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["c"], time: 200, to: nil, transition: [["a", "b"], [], []]}
                 ]
               ]
             }

      assert JS.remove_class("show", transition: {"fade", "opacity-0", "opacity-100"}) == %JS{
               ops: [
                 [
                   "remove_class",
                   %{
                     names: ["show"],
                     time: 200,
                     to: nil,
                     transition: [["fade"], ["opacity-0"], ["opacity-100"]]
                   }
                 ]
               ]
             }
    end

    test "composability" do
      js = JS.remove_class("show", to: "#modal", time: 100) |> JS.remove_class("hl")

      assert js == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], time: 100, to: "#modal", transition: [[], [], []]}
                 ],
                 ["remove_class", %{names: ["hl"], time: 200, to: nil, transition: [[], [], []]}]
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
               "[[&quot;remove_class&quot;,{&quot;names&quot;:[&quot;show&quot;],&quot;time&quot;:200,&quot;to&quot;:null,&quot;transition&quot;:[[],[],[]]}]]"
    end
  end

  describe "dispatch" do
    test "with defaults" do
      assert JS.dispatch("click", to: "#modal") == %JS{
               ops: [["dispatch", %{to: "#modal", event: "click"}]]
             }

      assert JS.dispatch("click") == %JS{
               ops: [["dispatch", %{to: nil, event: "click"}]]
             }
    end

    test "with optional flags" do
      assert JS.dispatch("click", bubbles: false) == %JS{
               ops: [["dispatch", %{to: nil, event: "click", bubbles: false}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for dispatch/, fn ->
        JS.dispatch("click", to: ".foo", bad: :opt)
      end
    end

    test "raises with click details" do
      assert_raise ArgumentError, ~r/click events cannot be dispatched with details/, fn ->
        JS.dispatch("click", to: ".foo", detail: %{id: 123})
      end
    end

    test "composability" do
      js =
        JS.dispatch("click", to: "#modal")
        |> JS.dispatch("keydown", to: "#keyboard")
        |> JS.dispatch("keyup")

      assert js == %JS{
               ops: [
                 ["dispatch", %{to: "#modal", event: "click"}],
                 ["dispatch", %{to: "#keyboard", event: "keydown"}],
                 ["dispatch", %{to: nil, event: "keyup"}]
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
               ops: [
                 [
                   "toggle",
                   %{display: nil, ins: [[], [], []], outs: [[], [], []], time: 200, to: "#modal"}
                 ]
               ]
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
                       ins: [["fade-in", "d-block"], [], []],
                       outs: [["fade-out", "d-block"], [], []],
                       time: 200,
                       to: "#modal"
                     }
                   ]
                 ]
               }

      assert JS.toggle(
               to: "#modal",
               in: {"fade-in", "opacity-0", "opacity-100"},
               out: {"fade-out", "opacity-100", "opacity-0"}
             ) ==
               %JS{
                 ops: [
                   [
                     "toggle",
                     %{
                       display: nil,
                       ins: [["fade-in"], ["opacity-0"], ["opacity-100"]],
                       outs: [["fade-out"], ["opacity-100"], ["opacity-0"]],
                       time: 200,
                       to: "#modal"
                     }
                   ]
                 ]
               }
    end

    test "custom time" do
      assert JS.toggle(to: "#modal", time: 123) == %JS{
               ops: [
                 [
                   "toggle",
                   %{display: nil, ins: [[], [], []], outs: [[], [], []], time: 123, to: "#modal"}
                 ]
               ]
             }
    end

    test "custom display" do
      assert JS.toggle(to: "#modal", display: "block") == %JS{
               ops: [
                 [
                   "toggle",
                   %{
                     display: "block",
                     ins: [[], [], []],
                     outs: [[], [], []],
                     time: 200,
                     to: "#modal"
                   }
                 ]
               ]
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
                 [
                   "toggle",
                   %{to: "#modal", display: nil, ins: [[], [], []], outs: [[], [], []], time: 200}
                 ],
                 [
                   "toggle",
                   %{
                     to: "#keyboard",
                     display: nil,
                     ins: [[], [], []],
                     outs: [[], [], []],
                     time: 123
                   }
                 ]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.toggle(to: "#modal")) ==
               "[[&quot;toggle&quot;,{&quot;display&quot;:null,&quot;ins&quot;:[[],[],[]],&quot;outs&quot;:[[],[],[]],&quot;time&quot;:200,&quot;to&quot;:&quot;#modal&quot;}]]"
    end
  end

  describe "show" do
    test "with defaults" do
      assert JS.show(to: "#modal") == %JS{
               ops: [["show", %{display: nil, transition: [[], [], []], time: 200, to: "#modal"}]]
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
                       transition: [["fade-in", "d-block"], [], []],
                       time: 200,
                       to: "#modal"
                     }
                   ]
                 ]
               }

      assert JS.show(
               to: "#modal",
               transition:
                 {"fade-in d-block", "opacity-0 -translate-x-full", "opacity-100 translate-x-0"}
             ) ==
               %JS{
                 ops: [
                   [
                     "show",
                     %{
                       display: nil,
                       transition: [
                         ["fade-in", "d-block"],
                         ["opacity-0", "-translate-x-full"],
                         ["opacity-100", "translate-x-0"]
                       ],
                       time: 200,
                       to: "#modal"
                     }
                   ]
                 ]
               }
    end

    test "custom time" do
      assert JS.show(to: "#modal", time: 123) == %JS{
               ops: [["show", %{display: nil, transition: [[], [], []], time: 123, to: "#modal"}]]
             }
    end

    test "custom display" do
      assert JS.show(to: "#modal", display: "block") == %JS{
               ops: [
                 ["show", %{display: "block", transition: [[], [], []], time: 200, to: "#modal"}]
               ]
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
                 ["show", %{to: "#modal", display: nil, transition: [[], [], []], time: 200}],
                 ["show", %{to: "#keyboard", display: nil, transition: [[], [], []], time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.show(to: "#modal")) ==
               "[[&quot;show&quot;,{&quot;display&quot;:null,&quot;time&quot;:200,&quot;to&quot;:&quot;#modal&quot;,&quot;transition&quot;:[[],[],[]]}]]"
    end
  end

  describe "hide" do
    test "with defaults" do
      assert JS.hide(to: "#modal") == %JS{
               ops: [["hide", %{transition: [[], [], []], time: 200, to: "#modal"}]]
             }
    end

    test "transition classes" do
      assert JS.hide(to: "#modal", transition: "fade-out d-block") ==
               %JS{
                 ops: [
                   [
                     "hide",
                     %{
                       transition: [["fade-out", "d-block"], [], []],
                       time: 200,
                       to: "#modal"
                     }
                   ]
                 ]
               }

      assert JS.hide(
               to: "#modal",
               transition:
                 {"fade-in d-block", "opacity-0 -translate-x-full", "opacity-100 translate-x-0"}
             ) ==
               %JS{
                 ops: [
                   [
                     "hide",
                     %{
                       transition: [
                         ["fade-in", "d-block"],
                         ["opacity-0", "-translate-x-full"],
                         ["opacity-100", "translate-x-0"]
                       ],
                       time: 200,
                       to: "#modal"
                     }
                   ]
                 ]
               }
    end

    test "custom time" do
      assert JS.hide(to: "#modal", time: 123) == %JS{
               ops: [["hide", %{transition: [[], [], []], time: 123, to: "#modal"}]]
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
                 ["hide", %{to: "#modal", transition: [[], [], []], time: 200}],
                 ["hide", %{to: "#keyboard", transition: [[], [], []], time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.hide(to: "#modal")) ==
               "[[&quot;hide&quot;,{&quot;time&quot;:200,&quot;to&quot;:&quot;#modal&quot;,&quot;transition&quot;:[[],[],[]]}]]"
    end
  end

  describe "transition" do
    test "with defaults" do
      assert JS.transition("shake") == %JS{
               ops: [["transition", %{transition: [["shake"], [], []], time: 200, to: nil}]]
             }

      assert JS.transition("shake", to: "#modal") == %JS{
               ops: [["transition", %{transition: [["shake"], [], []], time: 200, to: "#modal"}]]
             }

      assert JS.transition("shake swirl", to: "#modal") == %JS{
               ops: [
                 [
                   "transition",
                   %{transition: [["shake", "swirl"], [], []], time: 200, to: "#modal"}
                 ]
               ]
             }

      assert JS.transition({"shake swirl", "opacity-0 a", "opacity-100 b"}, to: "#modal") == %JS{
               ops: [
                 [
                   "transition",
                   %{
                     transition: [["shake", "swirl"], ["opacity-0", "a"], ["opacity-100", "b"]],
                     time: 200,
                     to: "#modal"
                   }
                 ]
               ]
             }
    end

    test "custom time" do
      assert JS.transition("shake", to: "#modal", time: 123) == %JS{
               ops: [["transition", %{transition: [["shake"], [], []], time: 123, to: "#modal"}]]
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
                 ["transition", %{to: "#modal", transition: [["shake"], [], []], time: 200}],
                 ["transition", %{to: "#keyboard", transition: [["hl"], [], []], time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.transition("shake", to: "#modal")) ==
               "[[&quot;transition&quot;,{&quot;time&quot;:200,&quot;to&quot;:&quot;#modal&quot;,&quot;transition&quot;:[[&quot;shake&quot;],[],[]]}]]"
    end
  end

  describe "set_attribute" do
    test "with defaults" do
      assert JS.set_attribute({"aria-expanded", "true"}) == %JS{
               ops: [
                 ["set_attr", %{attr: ["aria-expanded", "true"], to: nil}]
               ]
             }

      assert JS.set_attribute({"aria-expanded", "true"}, to: "#dropdown") == %JS{
               ops: [
                 ["set_attr", %{attr: ["aria-expanded", "true"], to: "#dropdown"}]
               ]
             }
    end

    test "composability" do
      js =
        JS.set_attribute({"expanded", "true"})
        |> JS.set_attribute({"has-popup", "true"})
        |> JS.set_attribute({"has-popup", "true"}, to: "#dropdown")

      assert js == %JS{
               ops: [
                 ["set_attr", %{to: nil, attr: ["expanded", "true"]}],
                 ["set_attr", %{to: nil, attr: ["has-popup", "true"]}],
                 ["set_attr", %{to: "#dropdown", attr: ["has-popup", "true"]}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for set_attribute/, fn ->
        JS.set_attribute({"disabled", ""}, bad: :opt)
      end
    end

    test "encoding" do
      assert js_to_string(JS.set_attribute({"disabled", "true"})) ==
               "[[&quot;set_attr&quot;,{&quot;attr&quot;:[&quot;disabled&quot;,&quot;true&quot;],&quot;to&quot;:null}]]"
    end
  end

  describe "remove_attribute" do
    test "with defaults" do
      assert JS.remove_attribute("aria-expanded") == %JS{
               ops: [
                 ["remove_attr", %{attr: "aria-expanded", to: nil}]
               ]
             }

      assert JS.remove_attribute("aria-expanded", to: "#dropdown") == %JS{
               ops: [
                 ["remove_attr", %{attr: "aria-expanded", to: "#dropdown"}]
               ]
             }
    end

    test "composability" do
      js =
        JS.remove_attribute("expanded")
        |> JS.remove_attribute("has-popup")
        |> JS.remove_attribute("has-popup", to: "#dropdown")

      assert js == %JS{
               ops: [
                 ["remove_attr", %{to: nil, attr: "expanded"}],
                 ["remove_attr", %{to: nil, attr: "has-popup"}],
                 ["remove_attr", %{to: "#dropdown", attr: "has-popup"}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for remove_attribute/, fn ->
        JS.remove_attribute("disabled", bad: :opt)
      end
    end

    test "encoding" do
      assert js_to_string(JS.remove_attribute("disabled")) ==
               "[[&quot;remove_attr&quot;,{&quot;attr&quot;:&quot;disabled&quot;,&quot;to&quot;:null}]]"
    end
  end

  describe "focus" do
    test "with defaults" do
      assert JS.focus() == %JS{ops: [["focus", %{to: nil}]]}
      assert JS.focus(to: "input") == %JS{ops: [["focus", %{to: "input"}]]}
    end

    test "composability" do
      js =
        JS.set_attribute({"expanded", "true"})
        |> JS.focus()

      assert js == %JS{
               ops: [["set_attr", %{attr: ["expanded", "true"], to: nil}], ["focus", %{to: nil}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for focus/, fn ->
        JS.focus(bad: :opt)
      end
    end

    test "encoding" do
      assert js_to_string(JS.focus()) == "[[&quot;focus&quot;,{&quot;to&quot;:null}]]"
    end
  end

  describe "focus_first" do
    test "with defaults" do
      assert JS.focus_first() == %JS{ops: [["focus_first", %{to: nil}]]}
      assert JS.focus_first(to: "input") == %JS{ops: [["focus_first", %{to: "input"}]]}
    end

    test "composability" do
      js =
        JS.set_attribute({"expanded", "true"})
        |> JS.focus_first()

      assert js == %JS{
               ops: [
                 ["set_attr", %{attr: ["expanded", "true"], to: nil}],
                 ["focus_first", %{to: nil}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for focus_first/, fn ->
        JS.focus_first(bad: :opt)
      end
    end

    test "encoding" do
      assert js_to_string(JS.focus_first()) == "[[&quot;focus_first&quot;,{&quot;to&quot;:null}]]"
    end
  end

  describe "push_focus" do
    test "with defaults" do
      assert JS.push_focus() == %JS{ops: [["push_focus", %{to: nil}]]}
      assert JS.push_focus(to: "input") == %JS{ops: [["push_focus", %{to: "input"}]]}
    end

    test "composability" do
      js =
        JS.set_attribute({"expanded", "true"})
        |> JS.push_focus()

      assert js == %JS{
               ops: [
                 ["set_attr", %{attr: ["expanded", "true"], to: nil}],
                 ["push_focus", %{to: nil}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for push_focus/, fn ->
        JS.push_focus(bad: :opt)
      end
    end

    test "encoding" do
      assert js_to_string(JS.push_focus()) == "[[&quot;push_focus&quot;,{&quot;to&quot;:null}]]"
    end
  end

  describe "pop_focus" do
    test "with defaults" do
      assert JS.pop_focus() == %JS{ops: [["pop_focus", %{}]]}
    end

    test "composability" do
      js =
        JS.set_attribute({"expanded", "true"})
        |> JS.pop_focus()

      assert js == %JS{
               ops: [["set_attr", %{attr: ["expanded", "true"], to: nil}], ["pop_focus", %{}]]
             }
    end

    test "encoding" do
      assert js_to_string(JS.pop_focus()) == "[[&quot;pop_focus&quot;,{}]]"
    end
  end

  defp js_to_string(%JS{} = js) do
    js
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end

defmodule Phoenix.LiveView.JSTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.JS

  describe "exec" do
    test "with defaults" do
      assert JS.exec("phx-remove") == %JS{ops: [["exec", %{attr: "phx-remove"}]]}

      assert JS.exec("phx-remove", to: "#modal") == %JS{
               ops: [["exec", %{attr: "phx-remove", to: "#modal"}]]
             }
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
                 ["add_class", %{names: ["show"]}]
               ]
             }

      assert JS.add_class("show", to: {:closest, "a"}) == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["show"], to: %{closest: "a"}}
                 ]
               ]
             }

      assert JS.add_class("show", to: "#modal") == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["show"], to: "#modal"}
                 ]
               ]
             }
    end

    test "multiple classes" do
      assert JS.add_class("show hl") == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["show", "hl"]}
                 ]
               ]
             }
    end

    test "custom time" do
      assert JS.add_class("show", time: 543) == %JS{
               ops: [
                 ["add_class", %{names: ["show"], time: 543}]
               ]
             }
    end

    test "transition" do
      assert JS.add_class("show", transition: "fade") == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["show"], transition: [["fade"], [], []]}
                 ]
               ]
             }

      assert JS.add_class("show", transition: "fade", blocking: false) == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["show"], transition: [["fade"], [], []], blocking: false}
                 ]
               ]
             }

      assert JS.add_class("c", transition: "a b") == %JS{
               ops: [
                 [
                   "add_class",
                   %{names: ["c"], transition: [["a", "b"], [], []]}
                 ]
               ]
             }

      assert JS.add_class("show", transition: {"fade", "opacity-0", "opacity-100"}) == %JS{
               ops: [
                 [
                   "add_class",
                   %{
                     names: ["show"],
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
                   %{names: ["show"], time: 100, to: "#modal"}
                 ],
                 ["add_class", %{names: ["hl"]}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for add_class/, fn ->
        JS.add_class("show", bad: :opt)
      end

      assert_raise ArgumentError, ~r/invalid scope for :to option in add_class/, fn ->
        JS.add_class("show", to: {:sibling, "foo"})
      end
    end

    test "encoding" do
      assert js_to_string(JS.add_class("show")) ==
               "[[&quot;add_class&quot;,{&quot;names&quot;:[&quot;show&quot;]}]]"
    end
  end

  describe "remove_class" do
    test "with defaults" do
      assert JS.remove_class("show") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"]}
                 ]
               ]
             }

      assert JS.remove_class("show", to: "#modal") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], to: "#modal"}
                 ]
               ]
             }

      assert JS.remove_class("show", to: {:inner, "a"}) == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], to: %{inner: "a"}}
                 ]
               ]
             }
    end

    test "multiple classes" do
      assert JS.remove_class("show hl") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show", "hl"]}
                 ]
               ]
             }
    end

    test "custom time" do
      assert JS.remove_class("show", time: 543) == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], time: 543}
                 ]
               ]
             }
    end

    test "transition" do
      assert JS.remove_class("show", transition: "fade") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], transition: [["fade"], [], []]}
                 ]
               ]
             }

      assert JS.remove_class("show", transition: "fade", blocking: false) == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["show"], transition: [["fade"], [], []], blocking: false}
                 ]
               ]
             }

      assert JS.remove_class("c", transition: "a b") == %JS{
               ops: [
                 [
                   "remove_class",
                   %{names: ["c"], transition: [["a", "b"], [], []]}
                 ]
               ]
             }

      assert JS.remove_class("show", transition: {"fade", "opacity-0", "opacity-100"}) == %JS{
               ops: [
                 [
                   "remove_class",
                   %{
                     names: ["show"],
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
                   %{names: ["show"], time: 100, to: "#modal"}
                 ],
                 ["remove_class", %{names: ["hl"]}]
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
               "[[&quot;remove_class&quot;,{&quot;names&quot;:[&quot;show&quot;]}]]"
    end
  end

  describe "toggle_class" do
    test "with defaults" do
      assert JS.toggle_class("show") == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{names: ["show"]}
                 ]
               ]
             }

      assert JS.toggle_class("show", to: "#modal") == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{names: ["show"], to: "#modal"}
                 ]
               ]
             }

      assert JS.toggle_class("show", to: {:document, "#modal"}) == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{names: ["show"], to: "#modal"}
                 ]
               ]
             }
    end

    test "multiple classes" do
      assert JS.toggle_class("show hl") == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{names: ["show", "hl"]}
                 ]
               ]
             }
    end

    test "custom time" do
      assert JS.toggle_class("show", time: 543) == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{names: ["show"], time: 543}
                 ]
               ]
             }
    end

    test "transition" do
      assert JS.toggle_class("show", transition: "fade") == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{names: ["show"], transition: [["fade"], [], []]}
                 ]
               ]
             }

      assert JS.toggle_class("show", transition: "fade", blocking: false) == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{names: ["show"], transition: [["fade"], [], []], blocking: false}
                 ]
               ]
             }

      assert JS.toggle_class("c", transition: "a b") == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{names: ["c"], transition: [["a", "b"], [], []]}
                 ]
               ]
             }

      assert JS.toggle_class("show", transition: {"fade", "opacity-0", "opacity-100"}) == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{
                     names: ["show"],
                     transition: [["fade"], ["opacity-0"], ["opacity-100"]]
                   }
                 ]
               ]
             }
    end

    test "composability" do
      js = JS.toggle_class("show", to: "#modal", time: 100) |> JS.toggle_class("hl")

      assert js == %JS{
               ops: [
                 [
                   "toggle_class",
                   %{names: ["show"], time: 100, to: "#modal"}
                 ],
                 ["toggle_class", %{names: ["hl"]}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for toggle_class/, fn ->
        JS.toggle_class("show", bad: :opt)
      end
    end

    test "encoding" do
      assert js_to_string(JS.toggle_class("show")) ==
               "[[&quot;toggle_class&quot;,{&quot;names&quot;:[&quot;show&quot;]}]]"
    end
  end

  describe "dispatch" do
    test "with defaults" do
      assert JS.dispatch("click", to: "#modal") == %JS{
               ops: [["dispatch", %{to: "#modal", event: "click"}]]
             }

      assert JS.dispatch("click") == %JS{
               ops: [["dispatch", %{event: "click"}]]
             }
    end

    test "with optional flags" do
      assert JS.dispatch("click", bubbles: false) == %JS{
               ops: [["dispatch", %{event: "click", bubbles: false}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for dispatch/, fn ->
        JS.dispatch("click", to: ".foo", bad: :opt)
      end

      assert_raise ArgumentError, ~r/invalid scope for :to option in dispatch/, fn ->
        JS.dispatch("click", to: {:winner, ".foo"})
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
                 ["dispatch", %{event: "keyup"}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.dispatch("click", to: ".foo")) ==
               "[[&quot;dispatch&quot;,{&quot;event&quot;:&quot;click&quot;,&quot;to&quot;:&quot;.foo&quot;}]]"
    end

    test "raises when done is a details key and blocking is true" do
      assert_raise ArgumentError, ~r/must not contain a `done` key/, fn ->
        JS.dispatch("foo", detail: %{done: true}, blocking: true)
      end
    end
  end

  describe "toggle" do
    test "with defaults" do
      assert JS.toggle(to: "#modal") == %JS{
               ops: [
                 [
                   "toggle",
                   %{to: "#modal"}
                 ]
               ]
             }

      assert JS.toggle(to: {:closest, ".modal"}) == %JS{
               ops: [
                 [
                   "toggle",
                   %{to: %{closest: ".modal"}}
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
                       ins: [["fade-in", "d-block"], [], []],
                       outs: [["fade-out", "d-block"], [], []],
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
                       ins: [["fade-in"], ["opacity-0"], ["opacity-100"]],
                       outs: [["fade-out"], ["opacity-100"], ["opacity-0"]],
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
                   %{time: 123, to: "#modal"}
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

      assert_raise ArgumentError, ~r/invalid scope for :to option in toggle/, fn ->
        JS.toggle(to: "#modal", to: {:bad, "123"})
      end
    end

    test "composability" do
      js = JS.toggle(to: "#modal") |> JS.toggle(to: "#keyboard", time: 123)

      assert js == %JS{
               ops: [
                 ["toggle", %{to: "#modal"}],
                 ["toggle", %{to: "#keyboard", time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.toggle(to: "#modal")) ==
               "[[&quot;toggle&quot;,{&quot;to&quot;:&quot;#modal&quot;}]]"
    end
  end

  describe "show" do
    test "with defaults" do
      assert JS.show(to: "#modal") == %JS{
               ops: [["show", %{to: "#modal"}]]
             }

      assert JS.show(to: {:inner, ".modal"}) == %JS{
               ops: [["show", %{to: %{inner: ".modal"}}]]
             }
    end

    test "transition classes" do
      assert JS.show(to: "#modal", transition: "fade-in d-block") ==
               %JS{
                 ops: [
                   [
                     "show",
                     %{
                       transition: [["fade-in", "d-block"], [], []],
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
                       transition: [
                         ["fade-in", "d-block"],
                         ["opacity-0", "-translate-x-full"],
                         ["opacity-100", "translate-x-0"]
                       ],
                       to: "#modal"
                     }
                   ]
                 ]
               }
    end

    test "custom time" do
      assert JS.show(to: "#modal", time: 123) == %JS{
               ops: [["show", %{time: 123, to: "#modal"}]]
             }
    end

    test "custom display" do
      assert JS.show(to: "#modal", display: "block") == %JS{
               ops: [
                 ["show", %{display: "block", to: "#modal"}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for show/, fn ->
        JS.show(to: "#modal", bad: :opt)
      end

      assert_raise ArgumentError, ~r/invalid scope for :to option in show/, fn ->
        JS.show(to: {:bad, "#modal"})
      end
    end

    test "composability" do
      js = JS.show(to: "#modal") |> JS.show(to: "#keyboard", time: 123)

      assert js == %JS{
               ops: [
                 ["show", %{to: "#modal"}],
                 ["show", %{to: "#keyboard", time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.show(to: "#modal")) ==
               "[[&quot;show&quot;,{&quot;to&quot;:&quot;#modal&quot;}]]"
    end
  end

  describe "hide" do
    test "with defaults" do
      assert JS.hide(to: "#modal") == %JS{
               ops: [["hide", %{to: "#modal"}]]
             }

      assert JS.hide(to: {:closest, "a"}) == %JS{
               ops: [["hide", %{to: %{closest: "a"}}]]
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
                       to: "#modal"
                     }
                   ]
                 ]
               }
    end

    test "custom time" do
      assert JS.hide(to: "#modal", time: 123) == %JS{
               ops: [["hide", %{time: 123, to: "#modal"}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for hide/, fn ->
        JS.hide(to: "#modal", bad: :opt)
      end

      assert_raise ArgumentError, ~r/invalid scope for :to option in hide/, fn ->
        JS.hide(to: {:bad, "#modal"})
      end
    end

    test "composability" do
      js = JS.hide(to: "#modal") |> JS.hide(to: "#keyboard", time: 123)

      assert js == %JS{
               ops: [
                 ["hide", %{to: "#modal"}],
                 ["hide", %{to: "#keyboard", time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.hide(to: "#modal")) ==
               "[[&quot;hide&quot;,{&quot;to&quot;:&quot;#modal&quot;}]]"
    end
  end

  describe "transition" do
    test "with defaults" do
      assert JS.transition("shake") == %JS{
               ops: [["transition", %{transition: [["shake"], [], []]}]]
             }

      assert JS.transition("shake", to: "#modal") == %JS{
               ops: [["transition", %{transition: [["shake"], [], []], to: "#modal"}]]
             }

      assert JS.transition("shake", to: {:inner, "a"}) == %JS{
               ops: [["transition", %{transition: [["shake"], [], []], to: %{inner: "a"}}]]
             }

      assert JS.transition("shake swirl", to: "#modal") == %JS{
               ops: [
                 [
                   "transition",
                   %{transition: [["shake", "swirl"], [], []], to: "#modal"}
                 ]
               ]
             }

      assert JS.transition({"shake swirl", "opacity-0 a", "opacity-100 b"}, to: "#modal") == %JS{
               ops: [
                 [
                   "transition",
                   %{
                     transition: [["shake", "swirl"], ["opacity-0", "a"], ["opacity-100", "b"]],
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

      assert_raise ArgumentError, ~r/invalid scope for :to option in transition/, fn ->
        JS.transition("shake", to: {:bad, "#modal"})
      end
    end

    test "composability" do
      js = JS.transition("shake", to: "#modal") |> JS.transition("hl", to: "#keyboard", time: 123)

      assert js == %JS{
               ops: [
                 ["transition", %{to: "#modal", transition: [["shake"], [], []]}],
                 ["transition", %{to: "#keyboard", transition: [["hl"], [], []], time: 123}]
               ]
             }
    end

    test "encoding" do
      assert js_to_string(JS.transition("shake", to: "#modal")) ==
               "[[&quot;transition&quot;,{&quot;to&quot;:&quot;#modal&quot;,&quot;transition&quot;:[[&quot;shake&quot;],[],[]]}]]"
    end
  end

  describe "set_attribute" do
    test "with defaults" do
      assert JS.set_attribute({"aria-expanded", "true"}) == %JS{
               ops: [
                 ["set_attr", %{attr: ["aria-expanded", "true"]}]
               ]
             }

      assert JS.set_attribute({"aria-expanded", "true"}, to: "#dropdown") == %JS{
               ops: [
                 ["set_attr", %{attr: ["aria-expanded", "true"], to: "#dropdown"}]
               ]
             }

      assert JS.set_attribute({"aria-expanded", "true"}, to: {:inner, ".dropdown"}) == %JS{
               ops: [
                 ["set_attr", %{attr: ["aria-expanded", "true"], to: %{inner: ".dropdown"}}]
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
                 ["set_attr", %{attr: ["expanded", "true"]}],
                 ["set_attr", %{attr: ["has-popup", "true"]}],
                 ["set_attr", %{to: "#dropdown", attr: ["has-popup", "true"]}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for set_attribute/, fn ->
        JS.set_attribute({"disabled", ""}, bad: :opt)
      end

      assert_raise ArgumentError, ~r/invalid scope for :to option in set_attribute/, fn ->
        JS.set_attribute({"disabled", ""}, to: {:bad, "#modal"})
      end
    end

    test "encoding" do
      assert js_to_string(JS.set_attribute({"disabled", "true"})) ==
               "[[&quot;set_attr&quot;,{&quot;attr&quot;:[&quot;disabled&quot;,&quot;true&quot;]}]]"
    end
  end

  describe "remove_attribute" do
    test "with defaults" do
      assert JS.remove_attribute("aria-expanded") == %JS{
               ops: [
                 ["remove_attr", %{attr: "aria-expanded"}]
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
                 ["remove_attr", %{attr: "expanded"}],
                 ["remove_attr", %{attr: "has-popup"}],
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
               "[[&quot;remove_attr&quot;,{&quot;attr&quot;:&quot;disabled&quot;}]]"
    end
  end

  describe "toggle_attribute" do
    test "with defaults" do
      assert JS.toggle_attribute({"open", "true"}) == %JS{
               ops: [
                 ["toggle_attr", %{attr: ["open", "true"]}]
               ]
             }

      assert JS.toggle_attribute({"open", "true"}, to: "#dropdown") == %JS{
               ops: [
                 ["toggle_attr", %{attr: ["open", "true"], to: "#dropdown"}]
               ]
             }

      assert JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#dropdown") == %JS{
               ops: [
                 ["toggle_attr", %{attr: ["aria-expanded", "true", "false"], to: "#dropdown"}]
               ]
             }

      assert JS.toggle_attribute({"aria-expanded", "true", "false"}, to: {:inner, ".dropdown"}) ==
               %JS{
                 ops: [
                   [
                     "toggle_attr",
                     %{attr: ["aria-expanded", "true", "false"], to: %{inner: ".dropdown"}}
                   ]
                 ]
               }
    end

    test "composability" do
      js =
        {"aria-expanded", "true", "false"}
        |> JS.toggle_attribute()
        |> JS.toggle_attribute({"open", "true"})
        |> JS.toggle_attribute({"disabled", "true"}, to: "#dropdown")

      assert js == %JS{
               ops: [
                 ["toggle_attr", %{attr: ["aria-expanded", "true", "false"]}],
                 ["toggle_attr", %{attr: ["open", "true"]}],
                 ["toggle_attr", %{to: "#dropdown", attr: ["disabled", "true"]}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for toggle_attribute/, fn ->
        JS.toggle_attribute({"disabled", "true"}, bad: :opt)
      end

      assert_raise ArgumentError, ~r/invalid scope for :to option in toggle_attribute/, fn ->
        JS.toggle_attribute({"disabled", "true"}, to: {:bad, "123"})
      end
    end

    test "encoding" do
      assert js_to_string(JS.toggle_attribute({"disabled", "true"})) ==
               "[[&quot;toggle_attr&quot;,{&quot;attr&quot;:[&quot;disabled&quot;,&quot;true&quot;]}]]"

      assert js_to_string(JS.toggle_attribute({"aria-expanded", "true", "false"})) ==
               "[[&quot;toggle_attr&quot;,{&quot;attr&quot;:[&quot;aria-expanded&quot;,&quot;true&quot;,&quot;false&quot;]}]]"
    end
  end

  describe "focus" do
    test "with defaults" do
      assert JS.focus() == %JS{ops: [["focus", %{}]]}
      assert JS.focus(to: "input") == %JS{ops: [["focus", %{to: "input"}]]}
      assert JS.focus(to: {:inner, "input"}) == %JS{ops: [["focus", %{to: %{inner: "input"}}]]}
    end

    test "composability" do
      js =
        JS.set_attribute({"expanded", "true"})
        |> JS.focus()

      assert js == %JS{
               ops: [["set_attr", %{attr: ["expanded", "true"]}], ["focus", %{}]]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for focus/, fn ->
        JS.focus(bad: :opt)
      end

      assert_raise ArgumentError, ~r/invalid scope for :to option in focus/, fn ->
        JS.focus(to: {:bad, "a"})
      end
    end

    test "encoding" do
      assert js_to_string(JS.focus()) == "[[&quot;focus&quot;,{}]]"
    end
  end

  describe "focus_first" do
    test "with defaults" do
      assert JS.focus_first() == %JS{ops: [["focus_first", %{}]]}
      assert JS.focus_first(to: "input") == %JS{ops: [["focus_first", %{to: "input"}]]}

      assert JS.focus_first(to: {:inner, "input"}) == %JS{
               ops: [["focus_first", %{to: %{inner: "input"}}]]
             }
    end

    test "composability" do
      js =
        JS.set_attribute({"expanded", "true"})
        |> JS.focus_first()

      assert js == %JS{
               ops: [
                 ["set_attr", %{attr: ["expanded", "true"]}],
                 ["focus_first", %{}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for focus_first/, fn ->
        JS.focus_first(bad: :opt)
      end

      assert_raise ArgumentError, ~r/invalid scope for :to option in focus_first/, fn ->
        JS.focus_first(to: {:bad, "a"})
      end
    end

    test "encoding" do
      assert js_to_string(JS.focus_first()) == "[[&quot;focus_first&quot;,{}]]"
    end
  end

  describe "push_focus" do
    test "with defaults" do
      assert JS.push_focus() == %JS{ops: [["push_focus", %{}]]}
      assert JS.push_focus(to: "input") == %JS{ops: [["push_focus", %{to: "input"}]]}

      assert JS.push_focus(to: {:inner, "input"}) == %JS{
               ops: [["push_focus", %{to: %{inner: "input"}}]]
             }
    end

    test "composability" do
      js =
        JS.set_attribute({"expanded", "true"})
        |> JS.push_focus()

      assert js == %JS{
               ops: [
                 ["set_attr", %{attr: ["expanded", "true"]}],
                 ["push_focus", %{}]
               ]
             }
    end

    test "raises with unknown options" do
      assert_raise ArgumentError, ~r/invalid option for push_focus/, fn ->
        JS.push_focus(bad: :opt)
      end

      assert_raise ArgumentError, ~r/invalid scope for :to option in push_focus/, fn ->
        JS.push_focus(to: {:bad, "a"})
      end
    end

    test "encoding" do
      assert js_to_string(JS.push_focus()) == "[[&quot;push_focus&quot;,{}]]"
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
               ops: [["set_attr", %{attr: ["expanded", "true"]}], ["pop_focus", %{}]]
             }
    end

    test "encoding" do
      assert js_to_string(JS.pop_focus()) == "[[&quot;pop_focus&quot;,{}]]"
    end
  end

  describe "concat" do
    test "combines multiple JS structs" do
      js1 = JS.push("inc", value: %{one: 1, two: 2})
      js2 = JS.add_class("show", to: "#modal", time: 100)
      js3 = JS.remove_class("show")

      assert JS.concat(js1, js2) |> JS.concat(js3) == %JS{
               ops: [
                 ["push", %{event: "inc", value: %{one: 1, two: 2}}],
                 ["add_class", %{names: ["show"], time: 100, to: "#modal"}],
                 ["remove_class", %{names: ["show"]}]
               ]
             }
    end
  end

  defp js_to_string(%JS{} = js) do
    js
    |> Map.update!(:ops, &order_ops_map_keys/1)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp order_ops_map_keys(ops) when is_list(ops) do
    Enum.map(ops, &order_ops_map_keys/1)
  end

  defp order_ops_map_keys(ops) when is_map(ops) do
    ops
    |> Enum.map(&order_ops_map_keys/1)
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Jason.OrderedObject.new()
  end

  defp order_ops_map_keys(ops) do
    ops
  end
end

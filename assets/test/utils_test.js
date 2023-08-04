import {Socket} from "phoenix"
import { closestPhxBinding, parsePhxKey, hasSpecificKeyBeenPressed } from "phoenix_live_view/utils"
import LiveSocket from "phoenix_live_view/live_socket"
import { simulateJoinedView, liveViewDOM } from "./test_helpers"

let setupView = (content) => {
  let el = liveViewDOM(content)
  global.document.body.appendChild(el)
  let liveSocket = new LiveSocket("/live", Socket)
  return simulateJoinedView(el, liveSocket)
}

describe("utils", () => {
  describe("closestPhxBinding", () => {
    test("if an element's parent has a phx-click binding and is not disabled, return the parent", () => {
      let view = setupView(`
      <button id="button" phx-click="toggle">
        <span id="innerContent">This is a button</span>
      </button>
      `)
      let element = global.document.querySelector("#innerContent")
      let parent = global.document.querySelector("#button")
      expect(closestPhxBinding(element, "phx-click")).toBe(parent)
    })

    test("if an element's parent is disabled, return null", () => {
      let view = setupView(`
      <button id="button" phx-click="toggle" disabled>
        <span id="innerContent">This is a button</span>
      </button>
      `)
      let element = global.document.querySelector("#innerContent")
      expect(closestPhxBinding(element, "phx-click")).toBe(null)
    })
  })

  describe("phx-key", () => {
    test("parsePhxKey", () => {
      expect(parsePhxKey("k")).toEqual(["k"])
      expect(parsePhxKey("meta.k")).toEqual(["meta", "k"])
      expect(parsePhxKey("alt.k")).toEqual(["alt", "k"])
      expect(parsePhxKey("ctrl.period")).toEqual(["ctrl", "period"])
      expect(parsePhxKey("shift.ctrl.slash")).toEqual(["shift", "ctrl", "slash"])
      expect(parsePhxKey("esc")).toEqual(["esc"])
    })

    test("hasSpecificKeyBeenPressed", () => {
      expect(hasSpecificKeyBeenPressed({key: "k"}, parsePhxKey("k"))).toEqual(true)
      expect(hasSpecificKeyBeenPressed({key: "j"}, parsePhxKey("k"))).toEqual(false)

      expect(hasSpecificKeyBeenPressed({key: "k", metaKey: true}, parsePhxKey("meta.k"))).toEqual(true)
      expect(hasSpecificKeyBeenPressed({key: "k", metaKey: true}, parsePhxKey("cmd.k"))).toEqual(true)
      expect(hasSpecificKeyBeenPressed({key: "k", metaKey: true}, parsePhxKey("super.k"))).toEqual(true)

      expect(hasSpecificKeyBeenPressed({key: "k", metaKey: false}, parsePhxKey("meta.k"))).toEqual(false)
      expect(hasSpecificKeyBeenPressed({key: "k", metaKey: false}, parsePhxKey("cmd.k"))).toEqual(false)
      expect(hasSpecificKeyBeenPressed({key: "k", metaKey: false}, parsePhxKey("super.k"))).toEqual(false)

      expect(hasSpecificKeyBeenPressed({key: "k", altKey: true}, parsePhxKey("alt.k"))).toEqual(true)
      expect(hasSpecificKeyBeenPressed({key: "k", altKey: false}, parsePhxKey("alt.k"))).toEqual(false)

      expect(hasSpecificKeyBeenPressed({key: ".", ctrlKey: true}, parsePhxKey("ctrl.period"))).toEqual(true)
      expect(hasSpecificKeyBeenPressed({key: ",", ctrlKey: false}, parsePhxKey("ctrl.period"))).toEqual(false)

      expect(hasSpecificKeyBeenPressed({key: "/", ctrlKey: true, shiftKey: true}, parsePhxKey("shift.ctrl.slash"))).toEqual(true)
      expect(hasSpecificKeyBeenPressed({key: "Escape"}, parsePhxKey("esc"))).toEqual(true)
    })
  })
})

import {Socket} from "phoenix"
import { closestPhxBinding } from "phoenix_live_view/utils"
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
})


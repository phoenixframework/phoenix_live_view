import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view/live_socket"

let stubViewPushInput = (view, callback) => {
  view.pushInput = (sourceEl, targetCtx, newCid, event, pushOpts, originalCallback) => {
    return callback(sourceEl, targetCtx, newCid, event, pushOpts, originalCallback)
  }
}

let prepareLiveViewDOM = (document, rootId) => {
  document.body.innerHTML = `
    <div data-phx-session="abc123"
         data-phx-root-id="${rootId}"
         id="${rootId}">
      <div class="form-wrapper" data-phx-component="2">
        <form id="form" phx-change="validate" phx-target="2">
          <label for="first_name">First Name</label>
          <input id="first_name" value="" name="user[first_name]" />

          <label for="last_name">Last Name</label>
          <input id="last_name" value="" name="user[last_name]" />
        </form>
      </div>
    </div>
  `
}

describe("events", () => {
  beforeEach(() => {
    prepareLiveViewDOM(global.document, "root")
  })

  test("send change event to correct target", () => {
    let liveSocket = new LiveSocket("/live", Socket)
    liveSocket.connect()
    let view = liveSocket.getViewByEl(document.getElementById("root"))
    view.isConnected = () => true
    let input = view.el.querySelector("#first_name")
    let meta = {
      event: null,
      target: null,
      changed: null,
    }

    stubViewPushInput(view, (sourceEl, targetCtx, newCid, event, pushOpts, callback) => {
      meta = {
        event,
        target: targetCtx,
        changed: pushOpts["_target"]
      }
    })

    input.value = "John Doe"
    input.dispatchEvent(new Event("change", {bubbles: true}))

    expect(meta).toEqual({
      event: "validate",
      target: 2,
      changed: "user[first_name]"
    })
  })
})

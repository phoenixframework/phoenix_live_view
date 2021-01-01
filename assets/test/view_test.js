import {Socket} from "phoenix"
import LiveSocket, {View, DOM} from "../js/phoenix_live_view"

import {tag, simulateJoinedView, stubChannel} from "./test_helpers"

function liveViewDOM(content) {
  const div = document.createElement("div")
  div.setAttribute("data-phx-view", "User.Form")
  div.setAttribute("data-phx-session", "abc123")
  div.setAttribute("id", "container")
  div.setAttribute("class", "user-implemented-class")
  div.innerHTML = content || `
    <form>
      <label for="plus">Plus</label>
      <input id="plus" value="1" name="increment" />
      <textarea id="note" name="note">2</textarea>
      <input type="checkbox" phx-click="toggle_me" />
      <button phx-click="inc_temperature">Inc Temperature</button>
    </form>
  `
  document.body.innerHTML = ""
  document.body.appendChild(div)
  return div
}

describe("View + DOM", function() {
  beforeEach(() => {
    submitBefore = HTMLFormElement.prototype.submit
    global.Phoenix = { Socket }
    global.document.body.innerHTML = liveViewDOM().outerHTML
  })

  afterAll(() => {
    global.document.body.innerHTML = ""
  })

  test("update", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let updateDiff = {
      s: ["<h2>", "</h2>"],
      fingerprint: 123
    }

    let view = simulateJoinedView(el, liveSocket)
    view.update(updateDiff, [])

    expect(view.el.firstChild.tagName).toBe("H2")
    expect(view.rendered.get()).toEqual(updateDiff)
  })

  test("pushWithReply", function() {
    expect.assertions(1)

    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.value).toBe("increment=1")
        return {
          receive(){ return this }
        }
      }
    }
    view.channel = channelStub

    view.pushWithReply(null, { target: el.querySelector("form") }, { value: "increment=1" })
  })

  test("pushWithReply with update", function() {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()

    let view = new View(el, liveSocket)
    let channelStub = {
      leave(){
        return {
          receive(status, cb){ return this }
        }
      },
      push(evt, payload, timeout) {
        expect(payload.value).toBe("increment=1")
        return {
          receive(status, cb) {
            let diff = {
              s: ["<h2>", "</h2>"],
              fingerprint: 123
            }
            cb(diff)
            return this
          }
        }
      }
    }
    view.channel = channelStub

    view.pushWithReply(null, { target: el.querySelector("form") }, { value: "increment=1" })

    expect(view.el.querySelector("form")).toBeTruthy()
  })

  test("pushEvent", function() {
    expect.assertions(3)

    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let input = el.querySelector("input")

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.type).toBe("keyup")
        expect(payload.event).toBeDefined()
        expect(payload.value).toEqual({"value": "1"})
        return {
          receive(){ return this }
        }
      }
    }
    view.channel = channelStub

    view.pushEvent("keyup", input, el, "click", {})
  })

  test("pushEvent as checkbox not checked", function() {
    expect.assertions(1)

    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let input = el.querySelector(`input[type="checkbox"]`)

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.value).toEqual({})
        return {
          receive(){ return this }
        }
      }
    }
    view.channel = channelStub

    view.pushEvent("click", input, el, "toggle_me", {})
  })

  test("pushEvent as checkbox when checked", function() {
    expect.assertions(1)

    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let input = el.querySelector(`input[type="checkbox"]`)
    input.checked = true

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.value).toEqual({"value": "on"})
        return {
          receive(){ return this }
        }
      }
    }
    view.channel = channelStub

    view.pushEvent("click", input, el, "toggle_me", {})
  })

  test("pushEvent as checkbox with value", function() {
    expect.assertions(1)

    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let input = el.querySelector(`input[type="checkbox"]`)
    input.value = "1"
    input.checked = true

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.value).toEqual({"value": "1"})
        return {
          receive(){ return this }
        }
      }
    }
    view.channel = channelStub

    view.pushEvent("click", input, el, "toggle_me", {})
  })

  test("pushKey", function() {
    expect.assertions(3)

    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let input = el.querySelector("input")

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.type).toBe("keydown")
        expect(payload.event).toBeDefined()
        expect(payload.value).toEqual({"key": "A", "value": "1"})
        return {
          receive(){ return this }
        }
      }
    }
    view.channel = channelStub

    view.pushKey(input, el, "keydown", "move", {key: "A"})
  })

  test("pushInput", function() {
    expect.assertions(3)

    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let input = el.querySelector("input")

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.type).toBe("form")
        expect(payload.event).toBeDefined()
        expect(payload.value).toBe("increment=1&note=2&_target=increment")
        return {
          receive(){ return this }
        }
      }
    }
    view.channel = channelStub

    view.pushInput(input, el, "validate", input)
  })

  test("formsForRecovery", function() {
    let view, html, liveSocket = new LiveSocket("/live", Socket)

    html = `<form phx-change="cg"><input name="foo"></form>`
    view = new View(liveViewDOM(html), liveSocket)
    expect(view.joinCount).toBe(0)
    expect(view.formsForRecovery(html).length).toBe(0)

    view.joinCount++
    expect(view.formsForRecovery(html).length).toBe(1)

    view.joinCount++
    expect(view.formsForRecovery(html).length).toBe(1)

    html = `<form phx-change="cg" phx-auto-recover="ignore"><input name="foo"></form>`
    view = new View(liveViewDOM(html), liveSocket)
    view.joinCount = 2
    expect(view.formsForRecovery().length).toBe(0)

    html = `<form><input name="foo"></form>`
    view = new View(liveViewDOM(html), liveSocket)
    view.joinCount = 2
    expect(view.formsForRecovery().length).toBe(0)

    html = `<form phx-change="cg"></form>`
    view = new View(liveViewDOM(html), liveSocket)
    view.joinCount = 2
    expect(view.formsForRecovery().length).toBe(0)
  })

  describe("submitForm", function() {
    test("submits payload", function() {
      expect.assertions(3)

      let liveSocket = new LiveSocket("/live", Socket)
      let el = liveViewDOM()
      let form = el.querySelector("form")

      let view = new View(el, liveSocket)
      let channelStub = {
        push(evt, payload, timeout) {
          expect(payload.type).toBe("form")
          expect(payload.event).toBeDefined()
          expect(payload.value).toBe("increment=1&note=2")
          return {
            receive(){ return this }
          }
        }
      }
      view.channel = channelStub
      view.submitForm(form, form, { target: form })
    })

    test("disables elements after submission", function() {
      let liveSocket = new LiveSocket("/live", Socket)
      let el = liveViewDOM()
      let form = el.querySelector("form")

      let view = new View(el, liveSocket)
      stubChannel(view)

      view.submitForm(form, form, { target: form })
      expect(DOM.private(form, "phx-has-submitted")).toBeTruthy()
      expect(form.classList.contains("phx-submit-loading")).toBeTruthy()
      expect(form.querySelector("button").dataset.phxDisabled).toBeTruthy()
      expect(form.querySelector("input").dataset.phxReadonly).toBeTruthy()
      expect(form.querySelector("textarea").dataset.phxReadonly).toBeTruthy()
    })

    test("disables elements outside form", function() {
      let liveSocket = new LiveSocket("/live", Socket)
      let el = liveViewDOM(`
      <form id="my-form">
      </form>
      <label for="plus">Plus</label>
      <input id="plus" value="1" name="increment" form="my-form"/>
      <textarea id="note" name="note" form="my-form">2</textarea>
      <input type="checkbox" phx-click="toggle_me" form="my-form"/>
      <button phx-click="inc_temperature" form="my-form">Inc Temperature</button>
      `)
      let form = el.querySelector("form")

      let view = new View(el, liveSocket)
      stubChannel(view)

      view.submitForm(form, form, { target: form })
      expect(DOM.private(form, "phx-has-submitted")).toBeTruthy()
      expect(form.classList.contains("phx-submit-loading")).toBeTruthy()
      expect(el.querySelector("button").dataset.phxDisabled).toBeTruthy()
      expect(el.querySelector("input").dataset.phxReadonly).toBeTruthy()
      expect(el.querySelector("textarea").dataset.phxReadonly).toBeTruthy()
    })
  })

  describe("phx-trigger-action", () => {
    test("triggers external submit on updated DOM el", (done) => {
      let liveSocket = new LiveSocket("/live", Socket)
      let el = liveViewDOM()
      let view = new View(el, liveSocket)
      let html = `<form id="form" phx-submit="submit"><input type="text"></form>`

      stubChannel(view)
      view.onJoin({rendered: {s: [html], fingerprint: 123}})
      expect(view.el.innerHTML).toBe(html)

      let formEl = document.getElementById("form")
      formEl.submit = () => done()
      let updatedHtml = `<form id="form" phx-submit="submit" phx-trigger-action><input type="text"></form>`
      view.update({s: [updatedHtml]}, [])

      expect(liveSocket.socket.closeWasClean).toBe(true)
      expect(view.el.innerHTML).toBe("<form id=\"form\" phx-submit=\"submit\" phx-trigger-action=\"\"><input type=\"text\"></form>")
    })

    test("triggers external submit on added DOM el", (done) => {
      let liveSocket = new LiveSocket("/live", Socket)
      let el = liveViewDOM()
      let view = new View(el, liveSocket)
      let html = `<div>not a form</div>`
      HTMLFormElement.prototype.submit = done

      stubChannel(view)
      view.onJoin({rendered: {s: [html], fingerprint: 123}})
      expect(view.el.innerHTML).toBe(html)

      let updatedHtml = `<form id="form" phx-submit="submit" phx-trigger-action><input type="text"></form>`
      view.update({s: [updatedHtml]}, [])

      expect(liveSocket.socket.closeWasClean).toBe(true)
      expect(view.el.innerHTML).toBe("<form id=\"form\" phx-submit=\"submit\" phx-trigger-action=\"\"><input type=\"text\"></form>")
    })
  })

  describe("phx-update", function() {
    let childIds = () => Array.from(document.getElementById("list").children).map(child => parseInt(child.id))
    let countChildNodes = () => document.getElementById("list").childNodes.length

    let createView = (updateType, initialDynamics) => {
      let liveSocket = new LiveSocket("/live", Socket)
      let el = liveViewDOM()
      let view = new View(el, liveSocket)

      stubChannel(view)

      let joinDiff = {
        "0": {"d": initialDynamics, "s": [`\n<div id="`, `">`, `</div>\n`]},
        "s": [`<div id="list" phx-update="${updateType}">`, `</div>`]
      }

      view.onJoin({rendered: joinDiff})

      return view
    }

    let updateDynamics = (view, dynamics) => {
      let updateDiff = {
        "0": {
          "d": dynamics
        }
      }

      view.update(updateDiff, [])
    }

    test("replace", async () => {
      let view = createView("replace", [["1", "1"]])
      expect(childIds()).toEqual([1])

      updateDynamics(view,
        [["2", "2"], ["3", "3"]]
      )
      expect(childIds()).toEqual([2,3])
    })

    test("append", async () => {
      let view = createView("append", [["1", "1"]])
      expect(childIds()).toEqual([1])

      // Append two elements
      updateDynamics(view,
        [["2", "2"], ["3", "3"]]
      )
      expect(childIds()).toEqual([1,2,3])

      // Update the last element
      updateDynamics(view,
        [["3", "3"]]
      )
      expect(childIds()).toEqual([1,2,3])

      // Update the first element
      updateDynamics(view,
        [["1", "1"]]
      )
      expect(childIds()).toEqual([1,2,3])

      // Update before new elements
      updateDynamics(view,
         [["4", "4"], ["5", "5"]]
      )
      expect(childIds()).toEqual([1,2,3,4,5])

      // Update after new elements
      updateDynamics(view,
         [["6", "6"], ["7", "7"], ["5", "modified"]]
      )
      expect(childIds()).toEqual([1,2,3,4,5,6,7])

      // Sandwich an update between two new elements
      updateDynamics(view,
        [["8", "8"], ["7", "modified"],  ["9", "9"]]
      )
      expect(childIds()).toEqual([1,2,3,4,5,6,7,8,9])

      // Update all elements in reverse order
      updateDynamics(view,
        [["9", "9"], ["8", "8"],  ["7", "7"], ["6", "6"], ["5", "5"], ["4", "4"], ["3", "3"], ["2", "2"], ["1", "1"]]
      )
      expect(childIds()).toEqual([1,2,3,4,5,6,7,8,9])

      // Make sure we don't have a memory leak when doing updates
      let initalCount = countChildNodes()
      updateDynamics(view,
        [["1", "1"], ["2", "2"],  ["3", "3"]]
      )
      updateDynamics(view,
        [["1", "1"], ["2", "2"],  ["3", "3"]]
      )
      updateDynamics(view,
        [["1", "1"], ["2", "2"],  ["3", "3"]]
      )
      updateDynamics(view,
        [["1", "1"], ["2", "2"],  ["3", "3"]]
      )

      expect(countChildNodes()).toBe(initalCount)
    })

    test("prepend", async () => {
      let view = createView("prepend", [["1", "1"]])
      expect(childIds()).toEqual([1])

      // Append two elements
      updateDynamics(view,
        [["2", "2"], ["3", "3"]]
      )
      expect(childIds()).toEqual([2,3,1])

      // Update the last element
      updateDynamics(view,
        [["3", "3"]]
      )
      expect(childIds()).toEqual([2,3,1])

      // Update the first element
      updateDynamics(view,
        [["1", "1"]]
      )
      expect(childIds()).toEqual([2,3,1])

      // Update before new elements
      updateDynamics(view,
         [["4", "4"], ["5", "5"]]
      )
      expect(childIds()).toEqual([4,5,2,3,1])

      // Update after new elements
      updateDynamics(view,
         [["6", "6"], ["7", "7"], ["5", "modified"]]
      )
      expect(childIds()).toEqual([6,7,4,5,2,3,1])

      // Sandwich an update between two new elements
      updateDynamics(view,
        [["8", "8"], ["7", "modified"],  ["9", "9"]]
      )
      expect(childIds()).toEqual([8,9,6,7,4,5,2,3,1])

      // Update all elements in reverse order
      updateDynamics(view,
        [["1", "1"], ["3", "3"],  ["2", "2"], ["5", "5"], ["4", "4"], ["7", "7"], ["6", "6"], ["9", "9"], ["8", "8"]]
      )
      expect(childIds()).toEqual([8,9,6,7,4,5,2,3,1])

      // Make sure we don't have a memory leak when doing updates
      let initalCount = countChildNodes()
      updateDynamics(view,
        [["1", "1"], ["2", "2"],  ["3", "3"]]
      )
      updateDynamics(view,
        [["1", "1"], ["2", "2"],  ["3", "3"]]
      )
      updateDynamics(view,
        [["1", "1"], ["2", "2"],  ["3", "3"]]
      )
      updateDynamics(view,
        [["1", "1"], ["2", "2"],  ["3", "3"]]
      )

      expect(countChildNodes()).toBe(initalCount)
    })

    test("ignore", async () => {
      let view = createView("ignore", [["1", "1"]])
      expect(childIds()).toEqual([1])

      // Append two elements
      updateDynamics(view,
        [["2", "2"], ["3", "3"]]
      )
      expect(childIds()).toEqual([1])
    })
  })
})

let submitBefore
describe("View", function() {
  beforeEach(() => {
    submitBefore = HTMLFormElement.prototype.submit
    global.Phoenix = { Socket }
    global.document.body.innerHTML = liveViewDOM().outerHTML
  })

  afterEach(() => {
    HTMLFormElement.prototype.submit = submitBefore
  })

  afterAll(() => {
    global.document.body.innerHTML = ""
  })

  test("sets defaults", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)
    expect(view.liveSocket).toBe(liveSocket)
    expect(view.parent).toBeUndefined()
    expect(view.el).toBe(el)
    expect(view.id).toEqual("container")
    expect(view.view).toEqual("User.Form")
    expect(view.channel).toBeDefined()
    expect(view.loaderTimer).toBeDefined()
  })

  test("binding", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)
    expect(view.binding("submit")).toEqual("phx-submit")
  })

  test("getSession", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)
    expect(view.getSession()).toEqual("abc123")
  })

  test("getStatic", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)
    expect(view.getStatic()).toEqual(null)

    el.setAttribute("data-phx-static", "foo")
    view = new View(el, liveSocket)
    expect(view.getStatic()).toEqual("foo")
  })

  test("showLoader and hideLoader", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = document.querySelector("[data-phx-view]")

    let view = new View(el, liveSocket)
    view.showLoader()
    expect(el.classList.contains("phx-disconnected")).toBeTruthy()
    expect(el.classList.contains("phx-connected")).toBeFalsy()
    expect(el.classList.contains("user-implemented-class")).toBeTruthy()

    view.hideLoader()
    expect(el.classList.contains("phx-disconnected")).toBeFalsy()
    expect(el.classList.contains("phx-connected")).toBeTruthy()
  })

  test("displayError", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let loader = document.createElement("span")
    let phxView = document.querySelector("[data-phx-view]")
    phxView.parentNode.insertBefore(loader, phxView.nextSibling)
    let el = document.querySelector("[data-phx-view]")

    let view = new View(el, liveSocket)
    view.displayError()
    expect(el.classList.contains("phx-disconnected")).toBeTruthy()
    expect(el.classList.contains("phx-error")).toBeTruthy()
    expect(el.classList.contains("phx-connected")).toBeFalsy()
    expect(el.classList.contains("user-implemented-class")).toBeTruthy()
  })

  test("join", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)

    // view.join()
    // still need a few tests
  })

  test("sends _track_static and _mounts on params", () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)
    stubChannel(view)

    expect(view.channel.params()).toEqual({
      "flash": undefined, "params": {"_mounts": 0}, "session": "abc123", "static": null, "url": undefined}
    )

    el.innerHTML += `<link rel="stylesheet" href="/css/app-123.css?vsn=d" phx-track-static="">`
    el.innerHTML += `<link rel="stylesheet" href="/css/nontracked.css">`
    el.innerHTML += `<img src="/img/tracked.png" phx-track-static>`
    el.innerHTML += `<img src="/img/untracked.png">`

    expect(view.channel.params()).toEqual({
      "flash": undefined, "session": "abc123", "static": null, "url": undefined,
      "params": {
        "_mounts": 0,
        "_track_static": [
          "http://localhost/css/app-123.css?vsn=d",
          "http://localhost/img/tracked.png",
        ]
      }
    })
  })
})

describe("View Hooks", function() {
  beforeEach(() => {
    global.document.body.innerHTML = liveViewDOM().outerHTML
  })

  afterAll(() => {
    global.document.body.innerHTML = ""
  })

  test("hooks", async () => {
    let upcaseWasDestroyed = false
    let upcaseBeforeUpdate = false
    let Hooks = {
      Upcase: {
        mounted(){ this.el.innerHTML = this.el.innerHTML.toUpperCase() },
        beforeUpdate(){ upcaseBeforeUpdate = true },
        updated(){ this.el.innerHTML = this.el.innerHTML + " updated" },
        disconnected(){ this.el.innerHTML = "disconnected" },
        reconnected(){ this.el.innerHTML = "connected" },
        destroyed(){ upcaseWasDestroyed = true },
      }
    }
    let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks})
    let el = liveViewDOM()

    let view = new View(el, liveSocket)

    view.onJoin({rendered: {
      s: [`<h2 id="up" phx-hook="Upcase">test mount</h2>`],
      fingerprint: 123
    }})
    expect(view.el.firstChild.innerHTML).toBe("TEST MOUNT")

    view.update({
      s: [`<h2 id="up" phx-hook="Upcase">test update</h2>`],
      fingerprint: 123
    }, [])
    expect(upcaseBeforeUpdate).toBe(true)
    expect(view.el.firstChild.innerHTML).toBe("test update updated")

    view.showLoader()
    expect(view.el.firstChild.innerHTML).toBe("disconnected")

    view.triggerReconnected()
    expect(view.el.firstChild.innerHTML).toBe("connected")

    view.update({s: ["<div></div>"], fingerprint: 123}, [])
    expect(upcaseWasDestroyed).toBe(true)
  })

  test("view destroyed", async () => {
    let values = []
    let Hooks = {
      Check: {
        destroyed(){ values.push("destroyed") },
      }
    }
    let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks})
    let el = liveViewDOM()

    let view = new View(el, liveSocket)

    view.onJoin({rendered: {
      s: [`<h2 id="check" phx-hook="Check">test mount</h2>`],
      fingerprint: 123
    }})
    expect(view.el.firstChild.innerHTML).toBe("test mount")

    view.destroy()

    expect(values).toEqual(["destroyed"])
  })

  test("view reconnected", async () => {
    let values = []
    let Hooks = {
      Check: {
        mounted(){ values.push("mounted") },
        disconnected(){ values.push("disconnected") },
        reconnected(){ values.push("reconnected") },
      }
    }
    let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks})
    let el = liveViewDOM()

    let view = new View(el, liveSocket)

    view.onJoin({rendered: {
      s: [`<h2 id="check" phx-hook="Check"></h2>`],
      fingerprint: 123
    }})
    expect(values).toEqual(["mounted"])

    view.triggerReconnected()
    // The hook hasn't disconnected, so it shouldn't receive "reconnected" message
    expect(values).toEqual(["mounted"])

    view.showLoader()
    expect(values).toEqual(["mounted", "disconnected"])

    view.triggerReconnected()
    expect(values).toEqual(["mounted", "disconnected", "reconnected"])
  })

  test("dom hooks", async () => {
    let fromHTML, toHTML = null
    let liveSocket = new LiveSocket("/live", Socket, {dom: {
      onBeforeElUpdated(from, to){ fromHTML = from.innerHTML; toHTML = to.innerHTML }
    }})
    let el = liveViewDOM()
    let view = new View(el, liveSocket)

    view.onJoin({rendered: {s: [`<div>initial</div>`], fingerprint: 123}})
    expect(view.el.firstChild.innerHTML).toBe("initial")

    view.update({s: [`<div>updated</div>`], fingerprint: 123}, [])
    expect(fromHTML).toBe("initial")
    expect(toHTML).toBe("updated")
    expect(view.el.firstChild.innerHTML).toBe("updated")
  })
})

function liveViewComponent() {
  const div = document.createElement("div")
  div.setAttribute("data-phx-view", "User.Form")
  div.setAttribute("data-phx-session", "abc123")
  div.setAttribute("id", "container")
  div.setAttribute("class", "user-implemented-class")
  div.innerHTML = `
    <article class="form-wrapper" data-phx-component="0">
      <form>
        <label for="plus">Plus</label>
        <input id="plus" value="1" name="increment" phx-target=".form-wrapper" />
        <input type="checkbox" phx-click="toggle_me" phx-target=".form-wrapper" />
        <button phx-click="inc_temperature">Inc Temperature</button>
      </form>
    </article>
  `
  return div
}

describe("View + Component", function() {
  beforeEach(() => {
    global.Phoenix = { Socket }
    global.document.body.innerHTML = liveViewComponent().outerHTML
  })

  afterAll(() => {
    global.document.body.innerHTML = ""
  })

  test("targetComponentID", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewComponent()
    let view = new View(el, liveSocket)
    let form = el.querySelector(`input[type="checkbox"]`)
    let targetCtx = el.querySelector(".form-wrapper")
    expect(view.targetComponentID(el, targetCtx)).toBe(null)
    expect(view.targetComponentID(form, targetCtx)).toBe(0)
  })

  test("pushEvent", function() {
    expect.assertions(4)

    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewComponent()
    let targetCtx = el.querySelector(".form-wrapper")
    let input = el.querySelector("input")

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.type).toBe("keyup")
        expect(payload.event).toBeDefined()
        expect(payload.value).toEqual({"value": "1"})
        expect(payload.cid).toEqual(0)
        return {
          receive(){ return this }
        }
      }
    }
    view.channel = channelStub

    view.pushEvent("keyup", input, targetCtx, "click", {})
  })

  test("pushInput", function() {
    expect.assertions(6)
    let html =
    `<form id="form" phx-change="validate">
      <label for="first_name">First Name</label>
      <input id="first_name" value="" name="user[first_name]" />

      <label for="last_name">Last Name</label>
      <input id="last_name" value="" name="user[last_name]" />
    </form>`
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM(html)
    let view = new View(el, liveSocket)
    view.onJoin({rendered: {s: [html], fingerprint: 123}})
    let channelStub = {
      validate: "",
      nextValidate(payload) {
        this.validate = Object.entries(payload)
          .map(([key, value]) => `${encodeURIComponent(key)}=${value ? encodeURIComponent(value) : ""}`)
          .join("&")
      },
      push(evt, payload, timeout) {
        expect(payload.value).toBe(this.validate)
        return {
          receive(status, cb) {
            if (status === "ok") {
              let diff = {
                s: [`
                <form id="form" phx-change="validate">
                  <label for="first_name">First Name</label>
                  <input id="first_name" value="" name="user[first_name]" />
                  <span class="feedback" phx-feedback-for="user[first_name]">can't be blank</span>

                  <label for="last_name">Last Name</label>
                  <input id="last_name" value="" name="user[last_name]" />
                  <span class="feedback" phx-feedback-for="user[last_name]">can't be blank</span>
                </form>
                `],
                fingerprint: 345
              }
              cb({diff: diff})
              return this
            } else {
              return this
            }
          }
        }
      }
    }
    view.channel = channelStub

    let first_name = view.el.querySelector("#first_name")
    let last_name = view.el.querySelector("#last_name")
    view.channel.nextValidate({"user[first_name]": null, "user[last_name]": null, "_target": "user[first_name]"})
    // we have to set this manually since it's set by a change event that would require more plumbing with the liveSocket in the test to hook up
    DOM.putPrivate(first_name, "phx-has-focused", true)
    view.pushInput(first_name, el, "validate", first_name)
    expect(el.querySelector(`[phx-feedback-for="${first_name.name}"`).classList.contains("phx-no-feedback")).toBeFalsy()
    expect(el.querySelector(`[phx-feedback-for="${last_name.name}"`).classList.contains("phx-no-feedback")).toBeTruthy()

    view.channel.nextValidate({"user[first_name]": null, "user[last_name]": null, "_target": "user[last_name]"})
    DOM.putPrivate(last_name, "phx-has-focused", true)
    view.pushInput(last_name, el, "validate", last_name)
    expect(el.querySelector(`[phx-feedback-for="${first_name.name}"`).classList.contains("phx-no-feedback")).toBeFalsy()
    expect(el.querySelector(`[phx-feedback-for="${last_name.name}"`).classList.contains("phx-no-feedback")).toBeFalsy()
  })

  test("adds auto ID to prevent teardown/re-add", () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)

    stubChannel(view)

    let joinDiff = {
      "0": {"0": "", "1": 0, "s": ["", "", "<h2>2</h2>\n"]},
      "c": {
        "0": {"s": ["<div phx-click=\"show-rect\">Menu</div>\n"]}
      },
      "s": ["", ""]
    }

    let updateDiff = {
      "0": {
        "0": {"s": ["  <h1>1</h1>\n"]}
      }
    }

    view.onJoin({rendered: joinDiff})
    expect(view.el.innerHTML.trim()).toBe(`<div phx-click=\"show-rect\" data-phx-component=\"0\" id=\"container-0-0\">Menu</div><h2>2</h2>`)

    view.update(updateDiff, [])
    expect(view.el.innerHTML.trim().replace("\n", "")).toBe(`<h1>1</h1><div phx-click=\"show-rect\" data-phx-component=\"0\" id=\"container-0-0\">Menu</div><h2>2</h2>`)
  })

  test("respects nested components", () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)

    stubChannel(view)

    let joinDiff = {
      "0": 0,
      "c": {
        "0": {"0": 1, "s": ["<div>Hello</div>", ""]},
        "1": {"s": ["<div>World</div>"]}
      },
      "s": ["", ""]
    }

    view.onJoin({rendered: joinDiff})
    expect(view.el.innerHTML.trim()).toBe(`<div data-phx-component="0" id="container-0-0">Hello</div><div data-phx-component="1" id="container-1-0">World</div>`)
  })

  test("wraps non-empty text nodes in span tags", () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)

    stubChannel(view)

    let joinDiff = {
      "0": 0,
      "c": {"0": {"s": ["Hello<div>World</div>\n"]}},
      "s": ["", ""]
    }

    jest.spyOn(console, 'error').mockImplementation(() => {});
    view.onJoin({rendered: joinDiff})
    expect(view.el.innerHTML.trim()).toBe(`<span data-phx-component="0"></span><div data-phx-component="0" id="container-0-1">World</div>`)
  })

  test("wraps empty component in a single span tag", () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)

    stubChannel(view)

    let joinDiff = {
      "0": 0,
      "c": {"0": {"s": ["\n"]}},
      "s": ["", ""]
    }

    jest.spyOn(console, 'error').mockImplementation(() => {});
    view.onJoin({rendered: joinDiff})
    expect(view.el.innerHTML.trim()).toBe(`<span data-phx-component="0"></span>`)
  })

  test("destroys children when they are removed by an update", () => {
    let id = "root"
    let childHTML = `<div data-phx-parent-id="${id}" data-phx-session="" data-phx-static="" data-phx-view="BarLive" id="bar" data-phx-root-id="${id}"></div>`
    let newChildHTML =`<div data-phx-parent-id="${id}" data-phx-session="" data-phx-static="" data-phx-view="BazLive" id="baz" data-phx-root-id="${id}"></div>`
    let el = document.createElement("div")
    el.setAttribute("data-phx-view", "Root")
    el.setAttribute("data-phx-session", "abc123")
    el.setAttribute("id", id)
    document.body.appendChild(el)

    let liveSocket = new LiveSocket("/live", Socket)

    let view = simulateJoinedView(el, liveSocket)

    let joinDiff = {"s": [childHTML]}

    let updateDiff = {"s": [newChildHTML]}

    view.onJoin({rendered: joinDiff})
    expect(view.el.innerHTML.trim()).toEqual(childHTML)
    expect(view.getChildById("bar")).toBeDefined()

    view.update(updateDiff, [])
    expect(view.el.innerHTML.trim()).toEqual(newChildHTML)
    expect(view.getChildById("baz")).toBeDefined()
    expect(view.getChildById("bar")).toBeUndefined()
  })

  describe("undoRefs", () => {
    test("restores phx specific attributes awaiting a ref", () => {
      let content = `
        <span data-phx-ref="1"></span>
        <form phx-change="suggest" phx-submit="search" phx-page-loading="" class="phx-submit-loading" data-phx-ref="38">
          <input type="text" name="q" value="ddsdsd" placeholder="Live dependency search" list="results" autocomplete="off" data-phx-readonly="false" readonly="" class="phx-submit-loading" data-phx-ref="38">
          <datalist id="results">
          </datalist>
          <button type="submit" phx-disable-with="Searching..." data-phx-disabled="false" disabled="" class="phx-submit-loading" data-phx-ref="38" data-phx-disable-with-restore="GO TO HEXDOCS">Searching...</button>
        </form>
      `.trim()
      let liveSocket = new LiveSocket("/live", Socket)
      let el = tag("div", {}, content)
      let view = new View(el, liveSocket)

      view.undoRefs(1)
      expect(el.innerHTML).toBe(`
        <span></span>
        <form phx-change="suggest" phx-submit="search" phx-page-loading="" class="phx-submit-loading" data-phx-ref="38">
          <input type="text" name="q" value="ddsdsd" placeholder="Live dependency search" list="results" autocomplete="off" data-phx-readonly="false" readonly="" class="phx-submit-loading" data-phx-ref="38">
          <datalist id="results">
          </datalist>
          <button type="submit" phx-disable-with="Searching..." data-phx-disabled="false" disabled="" class="phx-submit-loading" data-phx-ref="38" data-phx-disable-with-restore="GO TO HEXDOCS">Searching...</button>
        </form>
      `.trim())

      view.undoRefs(38)
      expect(el.innerHTML).toBe(`
        <span></span>
        <form phx-change="suggest" phx-submit="search" phx-page-loading="">
          <input type="text" name="q" value="ddsdsd" placeholder="Live dependency search" list="results" autocomplete="off">
          <datalist id="results">
          </datalist>
          <button type="submit" phx-disable-with="Searching...">Searching...</button>
        </form>
      `.trim())
    })

    test("replaces any previous applied component", () => {
      let liveSocket = new LiveSocket("/live", Socket)
      let el = tag("div", {}, "")
      let view = new View(el, liveSocket)

      let fromEl = tag("span", {"data-phx-ref": "1"}, "hello")
      let toEl = tag("span", {"class": "new"}, "world")

      DOM.putPrivate(fromEl, "data-phx-ref", toEl)
      el.appendChild(fromEl)

      view.undoRefs(1)
      expect(el.innerHTML).toBe(`<span class="new">world</span>`)
    })

    test("triggers beforeUpdate and updated hooks", () => {
      global.document.body.innerHTML = ""
      let beforeUpdate = false
      let updated = false
      let Hooks = {
        MyHook: {
          beforeUpdate(){ beforeUpdate = true },
          updated(){ updated = true},
        }
      }
      let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks})
      let el = liveViewDOM()
      let view = new View(el, liveSocket)
      stubChannel(view)
      view.onJoin({rendered: {s: [`<span id="myhook" phx-hook="MyHook">Hello</span>`]}})
      view.update({s: [`<span id="myhook" data-phx-ref="1" phx-hook="MyHook">Hello</span>`]}, [])

      let toEl = tag("span", {"id": "myhook", "phx-hook": "MyHook"}, "world")
      DOM.putPrivate(el.querySelector("#myhook"), "data-phx-ref", toEl)

      view.undoRefs(1)

      expect(el.querySelector("#myhook").outerHTML).toBe(`<span id="myhook" phx-hook="MyHook">world</span>`)
      expect(beforeUpdate).toBe(true)
      expect(updated).toBe(true)
    })
  })
})

describe("DOM", function() {
  it("mergeAttrs attributes", function() {
    const target = document.createElement("target")
    target.type = "checkbox"
    target.id = "foo"
    target.setAttribute("checked", "true")

    const source = document.createElement("source")
    source.type = "checkbox"
    source.id = "bar"

    expect(target.getAttribute("checked")).toEqual("true")
    expect(target.id).toEqual("foo")

    DOM.mergeAttrs(target, source)

    expect(target.getAttribute("checked")).toEqual(null)
    expect(target.id).toEqual("bar")
  })

  it("mergeAttrs with properties", function() {
    const target = document.createElement("target")
    target.type = "checkbox"
    target.id = "foo"
    target.checked = true

    const source = document.createElement("source")
    source.type = "checkbox"
    source.id = "bar"

    expect(target.checked).toEqual(true)
    expect(target.id).toEqual("foo")

    DOM.mergeAttrs(target, source)

    expect(target.checked).toEqual(true)
    expect(target.id).toEqual("bar")
  })
})

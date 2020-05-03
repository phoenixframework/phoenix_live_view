import {Socket} from "phoenix"
import LiveSocket, {View, DOM} from "../js/phoenix_live_view"

let simulateJoinedView = (el, liveSocket) => {
  let view = new View(el, liveSocket)
  view.onJoin({rendered: {s: []}})
  return view
}

let stubChannel = view => {
  let fakePush = {
    receives: [],
    receive(kind, cb){ this.receives.push([kind, cb])}
  }
  view.channel.push = () => fakePush
}

function liveViewDOM() {
  const div = document.createElement("div")
  div.setAttribute("data-phx-view", "User.Form")
  div.setAttribute("data-phx-session", "abc123")
  div.setAttribute("id", "container")
  div.setAttribute("class", "user-implemented-class")
  div.innerHTML = `
    <form>
      <label for="plus">Plus</label>
      <input id="plus" value="1" name="increment" />
      <input type="checkbox" phx-click="toggle_me" />
      <button phx-click="inc_temperature">Inc Temperature</button>
    </form>
  `
  const button = div.querySelector("button")
  const input = div.querySelector("input")
  button.addEventListener("click", () => {
    setTimeout(() => {
      input.value += 1
    }, 200)
  })

  document.body.appendChild(div)
  return div
}

describe("View + DOM", function() {
  test("update", async () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let updateDiff = {
      s: ["<h2>", "</h2>"],
      fingerprint: 123
    }

    let view = simulateJoinedView(el, liveSocket)
    view.update(updateDiff)

    expect(view.el.firstChild.tagName).toBe("H2")
    expect(view.rendered.get()).toBe(updateDiff)
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
          receive() {}
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
      push(evt, payload, timeout) {
        expect(payload.value).toBe("increment=1")
        return {
          receive(status, cb) {
            let diff = {
              s: ["<h2>", "</h2>"],
              fingerprint: 123
            }
            cb(diff)
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
          receive() {}
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
          receive() {}
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
          receive() {}
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
          receive() {}
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
          receive() {}
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
        expect(payload.value).toBe("increment=1&_target=increment")
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.pushInput(input, el, "validate", input)
  })

  test("submitForm", function() {
    expect.assertions(7)

    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let form = el.querySelector("form")

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.type).toBe("form")
        expect(payload.event).toBeDefined()
        expect(payload.value).toBe("increment=1")
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.submitForm(form, form, { target: form })
    expect(DOM.private(form, "phx-has-submitted")).toBeTruthy()
    expect(form.classList.contains("phx-submit-loading")).toBeTruthy()
    expect(form.querySelector("button").dataset.phxDisabled).toBeTruthy()
    expect(form.querySelector("input").dataset.phxReadonly).toBeTruthy()
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
    let upcaseBeforeDestroy = false
    let Hooks = {
      Upcase: {
        mounted(){ this.el.innerHTML = this.el.innerHTML.toUpperCase() },
        beforeUpdate(){ upcaseBeforeUpdate = true },
        updated(){ this.el.innerHTML = this.el.innerHTML + " updated" },
        disconnected(){ this.el.innerHTML = "disconnected" },
        reconnected(){ this.el.innerHTML = "connected" },
        beforeDestroy(){ upcaseBeforeDestroy = true },
        destroyed(){ upcaseWasDestroyed = true },
      }
    }
    let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks})
    let el = liveViewDOM()

    let view = new View(el, liveSocket)

    view.onJoin({rendered: {
      s: [`<h2 phx-hook="Upcase">test mount</h2>`],
      fingerprint: 123
    }})
    expect(view.el.firstChild.innerHTML).toBe("TEST MOUNT")

    view.update({
      s: [`<h2 phx-hook="Upcase">test update</h2>`],
      fingerprint: 123
    })
    expect(upcaseBeforeUpdate).toBe(true)
    expect(view.el.firstChild.innerHTML).toBe("test update updated")

    view.showLoader()
    expect(view.el.firstChild.innerHTML).toBe("disconnected")

    view.triggerReconnected()
    expect(view.el.firstChild.innerHTML).toBe("connected")

    view.update({s: ["<div></div>"], fingerprint: 123})
    expect(upcaseBeforeDestroy).toBe(true)
    expect(upcaseWasDestroyed).toBe(true)
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
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.pushEvent("keyup", input, targetCtx, "click", {})
  })

  test("empty diff undoes refs and pending attributes", () => {
    let liveSocket = new LiveSocket("/live", Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)
    let ref = 456
    let html = `<form phx-submit="submit" phx-page-loading=""><input type="text"></form>`

    stubChannel(view)
    view.onJoin({rendered: {
      s: [html],
      fingerprint: 123
    }})
    expect(view.el.innerHTML).toBe(html)

    let form = view.el.querySelector("form")
    view.pushFormSubmit(form, null, "submit", function(){})

    expect(view.el.innerHTML).toBe(`<form phx-submit="submit" phx-page-loading="" class="phx-submit-loading" data-phx-ref="0"><input type="text" data-phx-readonly="false" readonly="" class="phx-submit-loading" data-phx-ref="0"></form>`)

    view.update({}, null, ref) // empty diff update

    expect(view.el.innerHTML).toBe(html)
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
      view.update({s: [updatedHtml]}, null, null)

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
      view.update({s: [updatedHtml]}, null, null)

      expect(view.el.innerHTML).toBe("<form id=\"form\" phx-submit=\"submit\" phx-trigger-action=\"\"><input type=\"text\"></form>")
    })

    test("new DOM component sibling uses auto ID to prevent teardown/re-add", () => {
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

      view.update(updateDiff, null, null)

      expect(view.el.innerHTML.trim().replace("\n", "")).toBe(`<h1>1</h1><div phx-click=\"show-rect\" data-phx-component=\"0\" id=\"container-0-0\">Menu</div><h2>2</h2>`)
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

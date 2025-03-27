import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view/live_socket"
import JS from "phoenix_live_view/js"
import ViewHook from "phoenix_live_view/view_hook"
import {simulateJoinedView, simulateVisibility, liveViewDOM} from "./test_helpers"

let setupView = (content) => {
  let el = liveViewDOM(content)
  global.document.body.appendChild(el)
  let liveSocket = new LiveSocket("/live", Socket)
  return simulateJoinedView(el, liveSocket)
}

let event = new CustomEvent("phx:exec")

describe("JS", () => {
  beforeEach(() => {
    global.document.body.innerHTML = ""
    jest.useFakeTimers()
    setStartSystemTime()
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  describe("hook.js()", () => {
    let js, view, modal
    beforeEach(() => {
      view = setupView("<div id=\"modal\">modal</div>")
      modal = view.el.querySelector("#modal")
      let hook = new ViewHook(view, view.el, {})
      js = hook.js()
    })

    test("exec", done => {
      simulateVisibility(modal)
      expect(modal.style.display).toBe("")
      js.exec("[[\"toggle\", {\"to\": \"#modal\"}]]")
      jest.advanceTimersByTime(100)
      expect(modal.style.display).toBe("none")
      done()
    })

    test("show and hide", done => {
      simulateVisibility(modal)
      expect(modal.style.display).toBe("")
      js.hide(modal)
      jest.advanceTimersByTime(100)
      expect(modal.style.display).toBe("none")
      js.show(modal)
      jest.advanceTimersByTime(100)
      expect(modal.style.display).toBe("block")
      done()
    })

    test("toggle", done => {
      simulateVisibility(modal)
      expect(modal.style.display).toBe("")
      js.toggle(modal)
      jest.advanceTimersByTime(100)
      expect(modal.style.display).toBe("none")
      js.toggle(modal)
      jest.advanceTimersByTime(100)
      expect(modal.style.display).toBe("block")
      done()
    })

    test("addClass and removeClass", done => {
      expect(Array.from(modal.classList)).toEqual([])
      js.addClass(modal, "class1 class2")
      jest.advanceTimersByTime(100)
      expect(Array.from(modal.classList)).toEqual(["class1", "class2"])
      jest.advanceTimersByTime(100)
      js.removeClass(modal, "class1")
      jest.advanceTimersByTime(100)
      expect(Array.from(modal.classList)).toEqual(["class2"])
      js.addClass(modal, ["class3", "class4"])
      jest.advanceTimersByTime(100)
      expect(Array.from(modal.classList)).toEqual(["class2", "class3", "class4"])
      js.removeClass(modal, ["class3", "class4"])
      jest.advanceTimersByTime(100)
      expect(Array.from(modal.classList)).toEqual(["class2"])
      done()
    })

    test("toggleClass", done => {
      expect(Array.from(modal.classList)).toEqual([])
      js.toggleClass(modal, "class1 class2")
      jest.advanceTimersByTime(100)
      expect(Array.from(modal.classList)).toEqual(["class1", "class2"])
      js.toggleClass(modal, ["class1"])
      jest.advanceTimersByTime(100)
      expect(Array.from(modal.classList)).toEqual(["class2"])
      done()
    })

    test("transition", done => {
      js.transition(modal, "shake", {time: 150})
      jest.advanceTimersByTime(100)
      expect(Array.from(modal.classList)).toEqual(["shake"])
      jest.advanceTimersByTime(100)
      expect(Array.from(modal.classList)).toEqual([])
      js.transition(modal, ["shake", "opacity-50", "opacity-100"], {time: 150})
      jest.advanceTimersByTime(10)
      expect(Array.from(modal.classList)).toEqual(["opacity-50"])
      jest.advanceTimersByTime(200)
      expect(Array.from(modal.classList)).toEqual(["opacity-100"])
      done()
    })

    test("setAttribute and removeAttribute", done => {
      js.removeAttribute(modal, "works")
      js.setAttribute(modal, "works", "123")
      expect(modal.getAttribute("works")).toBe("123")
      js.removeAttribute(modal, "works")
      expect(modal.getAttribute("works")).toBe(null)
      done()
    })

    test("toggleAttr", done => {
      js.toggleAttribute(modal, "works", "on", "off")
      expect(modal.getAttribute("works")).toBe("on")
      js.toggleAttribute(modal, "works", "on", "off")
      expect(modal.getAttribute("works")).toBe("off")
      js.toggleAttribute(modal, "works", "on", "off")
      expect(modal.getAttribute("works")).toBe("on")
      done()
    })
  })

  describe("exec_toggle", () => {
    test("with defaults", done => {
      let view = setupView(`
      <div id="modal">modal</div>
      <div id="click" phx-click='[["toggle", {"to": "#modal"}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let click = document.querySelector("#click")
      let showEndCalled = false
      let hideEndCalled = false
      let showStartCalled = false
      let hideStartCalled = false
      modal.addEventListener("phx:show-end", () => showEndCalled = true)
      modal.addEventListener("phx:hide-end", () => hideEndCalled = true)
      modal.addEventListener("phx:show-start", () => showStartCalled = true)
      modal.addEventListener("phx:hide-start", () => hideStartCalled = true)

      expect(modal.style.display).toEqual("")
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      jest.runAllTimers()

      expect(modal.style.display).toEqual("none")

      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      jest.runAllTimers()

      expect(modal.style.display).toEqual("block")
      expect(showEndCalled).toBe(true)
      expect(hideEndCalled).toBe(true)
      expect(showStartCalled).toBe(true)
      expect(hideStartCalled).toBe(true)

      done()
    })

    test("with display", done => {
      let view = setupView(`
      <div id="modal">modal</div>
      <div id="click" phx-click='[["toggle", {"to": "#modal", "display": "inline-block"}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let click = document.querySelector("#click")
      let showEndCalled = false
      let hideEndCalled = false
      let showStartCalled = false
      let hideStartCalled = false
      modal.addEventListener("phx:show-end", () => showEndCalled = true)
      modal.addEventListener("phx:hide-end", () => hideEndCalled = true)
      modal.addEventListener("phx:show-start", () => showStartCalled = true)
      modal.addEventListener("phx:hide-start", () => hideStartCalled = true)

      expect(modal.style.display).toEqual("")
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      jest.runAllTimers()

      expect(modal.style.display).toEqual("none")

      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      jest.runAllTimers()

      expect(modal.style.display).toEqual("inline-block")
      expect(showEndCalled).toBe(true)
      expect(hideEndCalled).toBe(true)
      expect(showStartCalled).toBe(true)
      expect(hideStartCalled).toBe(true)
      done()
    })

    test("with in and out classes", async () => {
      let view = setupView(`
      <div id="modal">modal</div>
      <div id="click" phx-click='[["toggle", {"to": "#modal", "ins": [["fade-in"],["fade-in-start"],["fade-in-end"]], "outs": [["fade-out"],["fade-out-start"],["fade-out-end"]]}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let click = document.querySelector("#click")
      let showEndCalled = false
      let hideEndCalled = false
      let showStartCalled = false
      let hideStartCalled = false
      modal.addEventListener("phx:show-end", () => showEndCalled = true)
      modal.addEventListener("phx:hide-end", () => hideEndCalled = true)
      modal.addEventListener("phx:show-start", () => showStartCalled = true)
      modal.addEventListener("phx:hide-start", () => hideStartCalled = true)

      expect(modal.style.display).toEqual("")
      expect(modal.classList.contains("fade-out")).toBe(false)
      expect(modal.classList.contains("fade-in")).toBe(false)

      // toggle out
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      expect(hideStartCalled).toBe(true)
      // first tick: waiting for start classes to be set
      advanceTimersToNextFrame()
      expect(modal.classList.contains("fade-out-start")).toBe(true)
      expect(modal.classList.contains("fade-out")).toBe(false)
      // second tick: waiting for out classes to be set
      advanceTimersToNextFrame()
      expect(modal.classList.contains("fade-out-start")).toBe(true)
      expect(modal.classList.contains("fade-out")).toBe(true)
      // third tick: waiting for outEndClasses
      advanceTimersToNextFrame()
      expect(modal.classList.contains("fade-out-start")).toBe(false)
      expect(modal.classList.contains("fade-out")).toBe(true)
      expect(modal.classList.contains("fade-out-end")).toBe(true)
      // wait for onEnd
      jest.runAllTimers()
      advanceTimersToNextFrame()
      // fifth tick: display: none
      advanceTimersToNextFrame()
      expect(hideEndCalled).toBe(true)
      expect(modal.style.display).toEqual("none")
      // sixth tick, removed end classes
      advanceTimersToNextFrame()
      expect(modal.classList.contains("fade-out-start")).toBe(false)
      expect(modal.classList.contains("fade-out")).toBe(false)
      expect(modal.classList.contains("fade-out-end")).toBe(false)

      // toggle in
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      expect(showStartCalled).toBe(true)
      // first tick: waiting for start classes to be set
      advanceTimersToNextFrame()
      expect(modal.classList.contains("fade-in-start")).toBe(true)
      expect(modal.classList.contains("fade-in")).toBe(false)
      expect(modal.style.display).toEqual("none")
      // second tick: waiting for in classes to be set
      advanceTimersToNextFrame()
      expect(modal.classList.contains("fade-in-start")).toBe(true)
      expect(modal.classList.contains("fade-in")).toBe(true)
      expect(modal.classList.contains("fade-in-end")).toBe(false)
      expect(modal.style.display).toEqual("block")
      // third tick: waiting for inEndClasses
      advanceTimersToNextFrame()
      expect(modal.classList.contains("fade-in-start")).toBe(false)
      expect(modal.classList.contains("fade-in")).toBe(true)
      expect(modal.classList.contains("fade-in-end")).toBe(true)
      // wait for onEnd
      jest.runAllTimers()
      advanceTimersToNextFrame()
      expect(showEndCalled).toBe(true)
      // sixth tick, removed end classes
      expect(modal.classList.contains("fade-in-start")).toBe(false)
      expect(modal.classList.contains("fade-in")).toBe(false)
      expect(modal.classList.contains("fade-in-end")).toBe(false)
    })
  })

  describe("exec_transition", () => {
    test("with defaults", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="click" phx-click='[["transition", {"to": "#modal", "transition": [["fade-out"],[],[]]}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let click = document.querySelector("#click")

      expect(Array.from(modal.classList)).toEqual(["modal"])

      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      jest.advanceTimersByTime(100)

      expect(Array.from(modal.classList)).toEqual(["modal", "fade-out"])
      jest.runAllTimers()

      expect(Array.from(modal.classList)).toEqual(["modal"])
      done()
    })

    test("with multiple selector", done => {
      let view = setupView(`
      <div id="modal1" class="modal">modal</div>
      <div id="modal2" class="modal">modal</div>
      <div id="click" phx-click='[["transition", {"to": "#modal1, #modal2", "transition": [["fade-out"],[],[]]}]]'></div>
      `)
      let modal1 = document.querySelector("#modal1")
      let modal2 = document.querySelector("#modal2")
      let click = document.querySelector("#click")

      expect(Array.from(modal1.classList)).toEqual(["modal"])
      expect(Array.from(modal2.classList)).toEqual(["modal"])

      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      jest.advanceTimersByTime(100)

      expect(Array.from(modal1.classList)).toEqual(["modal", "fade-out"])
      expect(Array.from(modal2.classList)).toEqual(["modal", "fade-out"])

      jest.runAllTimers()

      expect(Array.from(modal1.classList)).toEqual(["modal"])
      expect(Array.from(modal2.classList)).toEqual(["modal"])

      done()
    })
  })

  describe("exec_dispatch", () => {
    test("with defaults", done => {
      let view = setupView(`
      <div id="modal">modal</div>
      <div id="click" phx-click='[["dispatch", {"to": "#modal", "event": "click"}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let click = document.querySelector("#click")

      modal.addEventListener("click", () => {
        done()
      })
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
    })

    test("with to scope inner", done => {
      let view = setupView(`
      <div id="click" phx-click='[["dispatch", {"to": {"inner": ".modal"}, "event": "click"}]]'>
        <div class="modal">modal</div>
      </div>
      `)
      let modal = simulateVisibility(document.querySelector(".modal"))
      let click = document.querySelector("#click")

      modal.addEventListener("click", () => done())
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
    })

    test("with to scope closest", done => {
      let view = setupView(`
      <div class="modal">
        <div>
          <div id="click" phx-click='[["dispatch", {"to": {"closest": ".modal"}, "event": "click"}]]'></div>
        </div>
      </div>
      `)
      let modal = simulateVisibility(document.querySelector(".modal"))
      let click = document.querySelector("#click")

      modal.addEventListener("click", () => done())
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
    })
    test("with details", done => {
      let view = setupView(`
      <div id="modal">modal</div>
      <div id="click" phx-click='[["dispatch", {"to": "#modal", "event": "click"}]]'></div>
      <div id="close" phx-click='[["dispatch", {"to": "#modal", "event": "close", "detail": {"id": 1}}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let click = document.querySelector("#click")
      let close = document.querySelector("#close")

      modal.addEventListener("close", e => {
        expect(e.detail).toEqual({id: 1, dispatcher: close})
        modal.addEventListener("click", e => {
          expect(e.detail).toEqual(0)
          done()
        })
        JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      })
      JS.exec(event, "close", close.getAttribute("phx-click"), view, close)
    })

    test("with multiple selector", done => {
      let view = setupView(`
      <div id="modal1" class="modal">modal1</div>
      <div id="modal2" class="modal">modal2</div>
      <div id="close" phx-click='[["dispatch", {"to": ".modal", "event": "close", "detail": {"id": 123}}]]'></div>
      `)
      let modal1Clicked = false
      let modal1 = document.querySelector("#modal1")
      let modal2 = document.querySelector("#modal2")
      let close = document.querySelector("#close")

      modal1.addEventListener("close", (e) => {
        modal1Clicked = true
        expect(e.detail).toEqual({id: 123, dispatcher: close})
      })

      modal2.addEventListener("close", (e) => {
        expect(modal1Clicked).toBe(true)
        expect(e.detail).toEqual({id: 123, dispatcher: close})
        done()
      })

      JS.exec(event, "close", close.getAttribute("phx-click"), view, close)
    })

    test("blocking blocks DOM updates until done", done => {
      let view = setupView(`
      <div id="modal">modal</div>
      <div id="click" phx-click='[["dispatch", {"to": "#modal", "event": "custom", "blocking": true}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let click = document.querySelector("#click")
      let doneCalled = false

      modal.addEventListener("custom", (e) => {
        expect(e.detail).toEqual({done: expect.any(Function), dispatcher: click})
        expect(view.liveSocket.transitions.size()).toBe(1)
        view.liveSocket.requestDOMUpdate(() => {
          expect(doneCalled).toBe(true)
          done()
        })
        // now we unblock the transition
        e.detail.done()
        doneCalled = true
      })
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
    })
  })

  describe("exec_add_class and exec_remove_class", () => {
    test("with defaults", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="add" phx-click='[["add_class", {"to": "#modal", "names": ["class1"]}]]'></div>
      <div id="remove" phx-click='[["remove_class", {"to": "#modal", "names": ["class1"]}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let add = document.querySelector("#add")
      let remove = document.querySelector("#remove")

      JS.exec(event, "click", add.getAttribute("phx-click"), view, add)
      JS.exec(event, "click", add.getAttribute("phx-click"), view, add)
      JS.exec(event, "click", add.getAttribute("phx-click"), view, add)
      jest.runAllTimers()

      expect(Array.from(modal.classList)).toEqual(["modal", "class1"])

      JS.exec(event, "click", remove.getAttribute("phx-click"), view, remove)
      jest.runAllTimers()

      expect(Array.from(modal.classList)).toEqual(["modal"])
      done()
    })

    test("with multiple selector", done => {
      let view = setupView(`
      <div id="modal1" class="modal">modal</div>
      <div id="modal2" class="modal">modal</div>
      <div id="add" phx-click='[["add_class", {"to": "#modal1, #modal2", "names": ["class1"]}]]'></div>
      <div id="remove" phx-click='[["remove_class", {"to": "#modal1, #modal2", "names": ["class1"]}]]'></div>
      `)
      let modal1 = document.querySelector("#modal1")
      let modal2 = document.querySelector("#modal2")
      let add = document.querySelector("#add")
      let remove = document.querySelector("#remove")

      JS.exec(event, "click", add.getAttribute("phx-click"), view, add)
      jest.runAllTimers()

      expect(Array.from(modal1.classList)).toEqual(["modal", "class1"])
      expect(Array.from(modal2.classList)).toEqual(["modal", "class1"])

      JS.exec(event, "click", remove.getAttribute("phx-click"), view, remove)
      jest.runAllTimers()

      expect(Array.from(modal1.classList)).toEqual(["modal"])
      expect(Array.from(modal2.classList)).toEqual(["modal"])
      done()
    })
  })

  describe("exec_toggle_class", () => {
    test("with defaults", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="toggle" phx-click='[["toggle_class", {"to": "#modal", "names": ["class1"]}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let toggle = document.querySelector("#toggle")

      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      jest.runAllTimers()

      expect(Array.from(modal.classList)).toEqual(["modal", "class1"])

      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      jest.runAllTimers()

      expect(Array.from(modal.classList)).toEqual(["modal"])
      done()
    })

    test("with multiple selector", done => {
      let view = setupView(`
      <div id="modal1" class="modal">modal</div>
      <div id="modal2" class="modal">modal</div>
      <div id="toggle" phx-click='[["toggle_class", {"to": "#modal1, #modal2", "names": ["class1"]}]]'></div>
      `)
      let modal1 = document.querySelector("#modal1")
      let modal2 = document.querySelector("#modal2")
      let toggle = document.querySelector("#toggle")

      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      jest.runAllTimers()

      expect(Array.from(modal1.classList)).toEqual(["modal", "class1"])
      expect(Array.from(modal2.classList)).toEqual(["modal", "class1"])
      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      jest.runAllTimers()

      expect(Array.from(modal1.classList)).toEqual(["modal"])
      expect(Array.from(modal2.classList)).toEqual(["modal"])
      done()
    })

    test("with transition", done => {
      let view = setupView(`
      <button phx-click='[["toggle_class",{"names":["t"],"transition":[["a"],["b"],["c"]]}]]'></button>
      `)
      let button = document.querySelector("button")

      expect(Array.from(button.classList)).toEqual([])

      JS.exec(event, "click", button.getAttribute("phx-click"), view, button)

      jest.advanceTimersByTime(100)
      expect(Array.from(button.classList)).toEqual(["a", "c"])

      jest.runAllTimers()
      expect(Array.from(button.classList)).toEqual(["c", "t"])

      done()
    })
  })

  describe("push", () => {
    test("regular event", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="click" phx-click='[["push", {"event": "clicked"}]]'></div>
      `)
      let click = document.querySelector("#click")
      view.pushEvent = (eventType, sourceEl, targetCtx, event, meta) => {
        expect(eventType).toBe("click")
        expect(event).toBe("clicked")
        expect(meta).toBeUndefined()
        done()
      }
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
    })

    test("form change event with JS command", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form" phx-change='[["push", {"event": "validate", "_target": "username"}]]' phx-submit="submit">
        <input type="text" name="username" id="username" phx-click=''></div>
      </form>
      `)
      let form = document.querySelector("#my-form")
      let input = document.querySelector("#username")
      view.pushInput = (sourceEl, targetCtx, newCid, phxEvent, {_target}, _callback) => {
        expect(phxEvent).toBe("validate")
        expect(sourceEl.isSameNode(input)).toBe(true)
        expect(_target).toBe(input.name)
        done()
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec(event, "change", form.getAttribute("phx-change"), view, input, args)
    })

    test("form change event with phx-value and JS command value", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form"
        phx-change='[["push", {"event": "validate", "_target": "username", "value": {"command_value": "command","nested":{"array":[1,2]}}}]]'
        phx-submit="submit"
        phx-value-attribute_value="attribute"
      >
        <input type="text" name="username" id="username" phx-click=''></div>
      </form>
      `)
      let form = document.querySelector("#my-form")
      let input = document.querySelector("#username")
      view.pushWithReply = (refGen, event, payload) => {
        expect(payload).toEqual({
          "cid": null,
          "event": "validate",
          "type": "form",
          "value": "_unused_username=&username=",
          "meta": {
            "_target": "username",
            "command_value": "command",
            "nested": {
              "array": [1, 2]
            },
            "attribute_value": "attribute"
          },
          "uploads": {}
        })
        return Promise.resolve({resp: done()})
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec(event, "change", form.getAttribute("phx-change"), view, input, args)
    })

    test("form change event prefers JS.push value over phx-value-* over input value", (done) => {
      let view = setupView(`
        <form id="my-form" phx-value-name="value from phx-value param" phx-change="[[&quot;push&quot;,{&quot;value&quot;:{&quot;name&quot;:&quot;value from push opts&quot;},&quot;event&quot;:&quot;change&quot;}]]">
          <input id="textField" name="name" value="input value" />
        </form>
      `)
      let form = document.querySelector("#my-form")
      let input = document.querySelector("#textField")
      view.pushWithReply = (refGen, event, payload) => {
        expect(payload).toEqual({
          "cid": null,
          "event": "change",
          "type": "form",
          "value": "_unused_name=&name=input+value",
          "meta": {
            "_target": "name",
            "name": "value from push opts"
          },
          "uploads": {}
        })
        return Promise.resolve({resp: done()})
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec(event, "change", form.getAttribute("phx-change"), view, input, args)
    })
  
    test("form change event prefers phx-value-* over input value", (done) => {
      let view = setupView(`
        <form id="my-form" phx-value-name="value from phx-value param" phx-change="change">
          <input id="textField" name="name" value="input value" />
        </form>
      `)
      let form = document.querySelector("#my-form")
      let input = document.querySelector("#textField")
      view.pushWithReply = (refGen, event, payload) => {
        expect(payload).toEqual({
          "cid": null,
          "event": "change",
          "type": "form",
          "value": "_unused_name=&name=input+value",
          "meta": {
            "_target": "name",
            "name": "value from phx-value param"
          },
          "uploads": {}
        })
        return Promise.resolve({resp: done()})
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec(event, "change", form.getAttribute("phx-change"), view, input, args)
    })

    test("form change event with string event", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form" phx-change='validate' phx-submit="submit">
        <input type="text" name="username" id="username" />
        <input type="text" name="other" id="other" phx-change="other_changed" />
      </form>
      `)
      let form = document.querySelector("#my-form")
      let input = document.querySelector("#username")
      let oldPush = view.pushInput.bind(view)
      view.pushInput = (sourceEl, targetCtx, newCid, phxEvent, opts, callback) => {
        let {_target} = opts
        expect(phxEvent).toBe("validate")
        expect(sourceEl.isSameNode(input)).toBe(true)
        expect(_target).toBe(input.name)
        oldPush(sourceEl, targetCtx, newCid, phxEvent, opts, callback)
      }
      view.pushWithReply = (refGen, event, payload) => {
        expect(payload).toEqual({
          cid: null,
          event: "validate",
          type: "form",
          uploads: {},
          value: "_unused_username=&username=&_unused_other=&other=",
          meta: {"_target": "username"}
        })
        return Promise.resolve({resp: done()})
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec(event, "change", form.getAttribute("phx-change"), view, input, args)
    })

    test("input change event with JS command", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form" phx-change='validate' phx-submit="submit">
        <input type="text" name="username" id="username1" phx-change='[["push", {"event": "username_changed", "_target": "username"}]]'/>
        <input type="text" name="other" id="other" />
      </form>
      `)
      let input = document.querySelector("#username1")
      let oldPush = view.pushInput.bind(view)
      view.pushInput = (sourceEl, targetCtx, newCid, phxEvent, opts, callback) => {
        let {_target} = opts
        expect(phxEvent).toBe("username_changed")
        expect(sourceEl.isSameNode(input)).toBe(true)
        expect(_target).toBe(input.name)
        oldPush(sourceEl, targetCtx, newCid, phxEvent, opts, callback)
      }
      view.pushWithReply = (refGen, event, payload) => {
        expect(payload).toEqual({
          cid: null,
          event: "username_changed",
          type: "form",
          uploads: {},
          value: "_unused_username=&username=",
          meta: {"_target": "username"}
        })
        return Promise.resolve({resp: done()})
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec(event, "change", input.getAttribute("phx-change"), view, input, args)
    })

    test("input change event with string event", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form" phx-change='validate' phx-submit="submit">
        <input type="text" name="username" id="username" phx-change='username_changed' />
        <input type="text" name="other" id="other" />
      </form>
      `)
      let input = document.querySelector("#username")
      let oldPush = view.pushInput.bind(view)
      view.pushInput = (sourceEl, targetCtx, newCid, phxEvent, opts, callback) => {
        let {_target} = opts
        expect(phxEvent).toBe("username_changed")
        expect(sourceEl.isSameNode(input)).toBe(true)
        expect(_target).toBe(input.name)
        oldPush(sourceEl, targetCtx, newCid, phxEvent, opts, callback)
      }
      view.pushWithReply = (refGen, event, payload) => {
        expect(payload).toEqual({
          cid: null,
          event: "username_changed",
          type: "form",
          uploads: {},
          value: "_unused_username=&username=",
          meta: {"_target": "username"}
        })
        return Promise.resolve({resp: done()})
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec(event, "change", input.getAttribute("phx-change"), view, input, args)
    })

    test("submit event", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form" phx-change="validate" phx-submit='[["push", {"event": "save"}]]'>
        <input type="text" name="username" id="username" />
        <input type="text" name="desc" id="desc" phx-change="desc_changed" />
      </form>
      `)
      let form = document.querySelector("#my-form")

      view.pushWithReply = (refGen, event, payload) => {
        expect(payload).toEqual({
          "cid": null,
          "event": "save",
          "type": "form",
          "value": "username=&desc=",
          "meta": {}
        })
        return Promise.resolve({resp: done()})
      }
      JS.exec(event, "submit", form.getAttribute("phx-submit"), view, form, ["push", {}])
    })

    test("submit event with phx-value and JS command value", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form"
            phx-change="validate"
            phx-submit='[["push", {"event": "save", "value": {"command_value": "command","nested":{"array":[1,2]}}}]]'
            phx-value-attribute_value="attribute"
      >
        <input type="text" name="username" id="username" />
        <input type="text" name="desc" id="desc" phx-change="desc_changed" />
      </form>
      `)
      let form = document.querySelector("#my-form")

      view.pushWithReply = (refGen, event, payload) => {
        expect(payload).toEqual({
          "cid": null,
          "event": "save",
          "type": "form",
          "value": "username=&desc=",
          "meta": {
            "command_value": "command",
            "nested": {
              "array": [1, 2]
            },
            "attribute_value": "attribute"
          }
        })
        return Promise.resolve({resp: done()})
      }
      JS.exec(event, "submit", form.getAttribute("phx-submit"), view, form, ["push", {}])
    })

    test("page_loading", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="click" phx-click='[["push", {"event": "clicked", "page_loading": true}]]'></div>
      `)
      let click = document.querySelector("#click")
      view.pushEvent = (eventType, sourceEl, targetCtx, event, meta, opts) => {
        expect(opts).toEqual({page_loading: true})
        done()
      }
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
    })

    test("loading", () => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="click" phx-click='[["push", {"event": "clicked", "loading": "#modal"}]]'></div>
      `)
      let click = document.querySelector("#click")
      let modal = document.getElementById("modal")
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      expect(Array.from(modal.classList)).toEqual(["modal", "phx-click-loading"])
      expect(Array.from(click.classList)).toEqual(["phx-click-loading"])
    })

    test("value", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="click" phx-value-three="3" phx-click='[["push", {"event": "clicked", "value": {"one": 1, "two": 2}}]]'></div>
      `)
      let click = document.querySelector("#click")

      view.pushWithReply = (refGenerator, event, payload, _onReply) => {
        expect(payload.value).toEqual({"one": 1, "two": 2, "three": "3"})
        return Promise.resolve({resp: done()})
      }
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
    })
  })

  describe("multiple instructions", () => {
    test("push and toggle", done => {
      let view = setupView(`
      <div id="modal">modal</div>
      <div id="click" phx-click='[["push", {"event": "clicked"}], ["toggle", {"to": "#modal"}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let click = document.querySelector("#click")

      view.pushEvent = (eventType, sourceEl, targetCtx, event, _data) => {
        expect(event).toEqual("clicked")
        done()
      }

      expect(modal.style.display).toEqual("")
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      jest.runAllTimers()

      expect(modal.style.display).toEqual("none")
    })
  })

  describe("exec_set_attr and exec_remove_attr", () => {
    test("with defaults", () => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="set" phx-click='[["set_attr", {"to": "#modal", "attr": ["aria-expanded", "true"]}]]'></div>
      <div id="remove" phx-click='[["remove_attr", {"to": "#modal", "attr": "aria-expanded"}]]'></div>
      `)
      let modal = document.querySelector("#modal")
      let set = document.querySelector("#set")
      let remove = document.querySelector("#remove")

      expect(modal.getAttribute("aria-expanded")).toEqual(null)
      JS.exec(event, "click", set.getAttribute("phx-click"), view, set)
      expect(modal.getAttribute("aria-expanded")).toEqual("true")

      JS.exec(event, "click", remove.getAttribute("phx-click"), view, remove)
      expect(modal.getAttribute("aria-expanded")).toEqual(null)
    })

    test("with no selector", () => {
      let view = setupView(`
      <div id="set" phx-click='[["set_attr", {"to": null, "attr": ["aria-expanded", "true"]}]]'></div>
      <div id="remove" class="here" phx-click='[["remove_attr", {"to": null, "attr": "class"}]]'></div>
      `)
      let set = document.querySelector("#set")
      let remove = document.querySelector("#remove")

      expect(set.getAttribute("aria-expanded")).toEqual(null)
      JS.exec(event, "click", set.getAttribute("phx-click"), view, set)
      expect(set.getAttribute("aria-expanded")).toEqual("true")

      expect(remove.getAttribute("class")).toEqual("here")
      JS.exec(event, "click", remove.getAttribute("phx-click"), view, remove)
      expect(remove.getAttribute("class")).toEqual(null)
    })

    test("setting a pre-existing attribute updates its value", () => {
      let view = setupView(`
      <div id="modal" class="modal" aria-expanded="false">modal</div>
      <div id="set" phx-click='[["set_attr", {"to": "#modal", "attr": ["aria-expanded", "true"]}]]'></div>
      `)
      let set = document.querySelector("#set")
      let modal = document.querySelector("#modal")

      expect(modal.getAttribute("aria-expanded")).toEqual("false")
      JS.exec(event, "click", set.getAttribute("phx-click"), view, set)
      expect(modal.getAttribute("aria-expanded")).toEqual("true")
    })

    test("setting a dynamically added attribute updates its value", () => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="set-false" phx-click='[["set_attr", {"to": "#modal", "attr": ["aria-expanded", "false"]}]]'></div>
      <div id="set-true" phx-click='[["set_attr", {"to": "#modal", "attr": ["aria-expanded", "true"]}]]'></div>
      `)
      let setFalse = document.querySelector("#set-false")
      let setTrue = document.querySelector("#set-true")
      let modal = document.querySelector("#modal")

      expect(modal.getAttribute("aria-expanded")).toEqual(null)
      JS.exec(event, "click", setFalse.getAttribute("phx-click"), view, setFalse)
      expect(modal.getAttribute("aria-expanded")).toEqual("false")
      JS.exec(event, "click", setTrue.getAttribute("phx-click"), view, setTrue)
      expect(modal.getAttribute("aria-expanded")).toEqual("true")
    })
  })

  describe("exec", () => {
    test("executes command", done => {
      let view = setupView(`
      <div id="modal" phx-remove='[["push", {"event": "clicked"}]]'>modal</div>
      <div id="click" phx-click='[["exec",{"attr": "phx-remove", "to": "#modal"}]]'></div>
      `)
      let click = document.querySelector("#click")
      view.pushEvent = (eventType, sourceEl, targetCtx, event, _meta) => {
        expect(eventType).toBe("exec")
        expect(event).toBe("clicked")
        done()
      }
      JS.exec(event, "exec", click.getAttribute("phx-click"), view, click)
    })

    test("with no selector", () => {
      let view = setupView(`
      <div
        id="click"
        phx-click='[["exec", {"attr": "data-toggle"}]]''
        data-toggle='[["toggle_attr", {"attr": ["open", "true"]}]]'
      ></div>
      `)
      let click = document.querySelector("#click")

      expect(click.getAttribute("open")).toEqual(null)
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      expect(click.getAttribute("open")).toEqual("true")
    })

    test("with to scope inner", () => {
      let view = setupView(`
      <div id="click" phx-click='[["exec",{"attr": "data-toggle", "to": {"inner": "#modal"}}]]'>
        <div id="modal" data-toggle='[["toggle_attr", {"attr": ["open", "true"]}]]'>modal</div>
      </div>
      `)
      let modal = document.querySelector("#modal")
      let click = document.querySelector("#click")

      expect(modal.getAttribute("open")).toEqual(null)
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      expect(modal.getAttribute("open")).toEqual("true")
    })

    test("with to scope closest", () => {
      let view = setupView(`
      <div id="modal" data-toggle='[["toggle_attr", {"attr": ["open", "true"]}]]'>
        <div id="click" phx-click='[["exec",{"attr": "data-toggle", "to": {"closest": "#modal"}}]]'></div>
      </div>
      `)
      let modal = document.querySelector("#modal")
      let click = document.querySelector("#click")

      expect(modal.getAttribute("open")).toEqual(null)
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      expect(modal.getAttribute("open")).toEqual("true")
    })

    test("with multiple selector", () => {
      let view = setupView(`
      <div id="modal1" data-toggle='[["toggle_attr", {"attr": ["open", "true"]}]]'>modal</div>
      <div id="modal2" data-toggle='[["toggle_attr", {"attr": ["open", "true"]}]]' open='true'>modal</div>
      <div id="click" phx-click='[["exec", {"attr": "data-toggle", "to": "#modal1, #modal2"}]]'></div>
      `)
      let modal1 = document.querySelector("#modal1")
      let modal2 = document.querySelector("#modal2")
      let click = document.querySelector("#click")

      expect(modal1.getAttribute("open")).toEqual(null)
      expect(modal2.getAttribute("open")).toEqual("true")
      JS.exec(event, "click", click.getAttribute("phx-click"), view, click)
      expect(modal1.getAttribute("open")).toEqual("true")
      expect(modal2.getAttribute("open")).toEqual(null)
    })
  })

  describe("exec_toggle_attr", () => {
    test("with defaults", () => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="toggle" phx-click='[["toggle_attr", {"to": "#modal", "attr": ["open", "true"]}]]'></div>
      `)
      let modal = document.querySelector("#modal")
      let toggle = document.querySelector("#toggle")

      expect(modal.getAttribute("open")).toEqual(null)
      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      expect(modal.getAttribute("open")).toEqual("true")

      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      expect(modal.getAttribute("open")).toEqual(null)
    })

    test("with no selector", () => {
      let view = setupView(`
      <div id="toggle" phx-click='[["toggle_attr", {"to": null, "attr": ["open", "true"]}]]'></div>
      `)
      let toggle = document.querySelector("#toggle")

      expect(toggle.getAttribute("open")).toEqual(null)
      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      expect(toggle.getAttribute("open")).toEqual("true")
    })

    test("with multiple selector", () => {
      let view = setupView(`
      <div id="modal1">modal</div>
      <div id="modal2" open="true">modal</div>
      <div id="toggle" phx-click='[["toggle_attr", {"to": "#modal1, #modal2", "attr": ["open", "true"]}]]'></div>
      `)
      let modal1 = document.querySelector("#modal1")
      let modal2 = document.querySelector("#modal2")
      let toggle = document.querySelector("#toggle")

      expect(modal1.getAttribute("open")).toEqual(null)
      expect(modal2.getAttribute("open")).toEqual("true")
      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      expect(modal1.getAttribute("open")).toEqual("true")
      expect(modal2.getAttribute("open")).toEqual(null)
    })

    test("toggling a pre-existing attribute updates its value", () => {
      let view = setupView(`
      <div id="modal" class="modal" open="true">modal</div>
      <div id="toggle" phx-click='[["toggle_attr", {"to": "#modal", "attr": ["open", "true"]}]]'></div>
      `)
      let toggle = document.querySelector("#toggle")
      let modal = document.querySelector("#modal")

      expect(modal.getAttribute("open")).toEqual("true")
      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      expect(modal.getAttribute("open")).toEqual(null)
    })

    test("toggling a dynamically added attribute updates its value", () => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="toggle1" phx-click='[["toggle_attr", {"to": "#modal", "attr": ["open", "true"]}]]'></div>
      <div id="toggle2" phx-click='[["toggle_attr", {"to": "#modal", "attr": ["open", "true"]}]]'></div>
      `)
      let toggle1 = document.querySelector("#toggle1")
      let toggle2 = document.querySelector("#toggle2")
      let modal = document.querySelector("#modal")

      expect(modal.getAttribute("open")).toEqual(null)
      JS.exec(event, "click", toggle1.getAttribute("phx-click"), view, toggle1)
      expect(modal.getAttribute("open")).toEqual("true")
      JS.exec(event, "click", toggle2.getAttribute("phx-click"), view, toggle2)
      expect(modal.getAttribute("open")).toEqual(null)
    })

    test("toggling between two values", () => {
      let view = setupView(`
      <div id="toggle" phx-click='[["toggle_attr", {"to": null, "attr": ["aria-expanded", "true", "false"]}]]'></div>
      `)
      let toggle = document.querySelector("#toggle")

      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      expect(toggle.getAttribute("aria-expanded")).toEqual("true")
      JS.exec(event, "click", toggle.getAttribute("phx-click"), view, toggle)
      expect(toggle.getAttribute("aria-expanded")).toEqual("false")
    })
  })

  describe("focus", () => {
    test("works like a stack", () => {
      let view = setupView(`
      <div id="modal1" tabindex="0" class="modal">modal 1</div>
      <div id="modal2" tabindex="0" class="modal">modal 2</div>
      <div id="push1" phx-click='[["push_focus", {"to": "#modal1"}]]'></div>
      <div id="push2" phx-click='[["push_focus", {"to": "#modal2"}]]'></div>
      <div id="pop" phx-click='[["pop_focus", {}]]'></div>
      `)
      let modal1 = document.querySelector("#modal1")
      let modal2 = document.querySelector("#modal2")
      let push1 = document.querySelector("#push1")
      let push2 = document.querySelector("#push2")
      let pop = document.querySelector("#pop")

      JS.exec(event, "click", push1.getAttribute("phx-click"), view, push1)
      JS.exec(event, "click", push2.getAttribute("phx-click"), view, push2)

      JS.exec(event, "click", pop.getAttribute("phx-click"), view, pop)
      jest.runAllTimers()
      expect(document.activeElement).toBe(modal2)

      JS.exec(event, "click", pop.getAttribute("phx-click"), view, pop)
      jest.runAllTimers()
      expect(document.activeElement).toBe(modal1)
    })
  })
})

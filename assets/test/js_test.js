import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view/live_socket"
import JS from "phoenix_live_view/js"
import {simulateJoinedView, simulateVisibility, liveViewDOM} from "./test_helpers"

let setupView = (content) => {
  let el = liveViewDOM(content)
  global.document.body.appendChild(el)
  let liveSocket = new LiveSocket("/live", Socket)
  return simulateJoinedView(el, liveSocket)
}

describe("JS", () => {
  beforeEach(() => {
    global.document.body.innerHTML = ""
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
      JS.exec("click", click.getAttribute("phx-click"), view, click)
      window.requestAnimationFrame(() => {
        expect(modal.style.display).toEqual("none")

        JS.exec("click", click.getAttribute("phx-click"), view, click)
        window.requestAnimationFrame(() => {
          expect(modal.style.display).toEqual("block")
          expect(showEndCalled).toBe(true)
          expect(hideEndCalled).toBe(true)
          expect(showStartCalled).toBe(true)
          expect(hideStartCalled).toBe(true)
          done()
        })
      })
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
      JS.exec("click", click.getAttribute("phx-click"), view, click)
      window.requestAnimationFrame(() => {
        expect(modal.style.display).toEqual("none")

        JS.exec("click", click.getAttribute("phx-click"), view, click)
        window.requestAnimationFrame(() => {
          expect(modal.style.display).toEqual("inline-block")
          expect(showEndCalled).toBe(true)
          expect(hideEndCalled).toBe(true)
          expect(showStartCalled).toBe(true)
          expect(hideStartCalled).toBe(true)
          done()
        })
      })
    })

    test("with in and out classes", done => {
      let view = setupView(`
      <div id="modal">modal</div>
      <div id="click" phx-click='[["toggle", {"to": "#modal", "ins": [["fade-in"],[],[]], "outs": [["fade-out"],[],[]]}]]'></div>
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
      JS.exec("click", click.getAttribute("phx-click"), view, click)
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
          window.requestAnimationFrame(() => {
            expect(modal.classList.contains("fade-out")).toBe(true)
            expect(modal.classList.contains("fade-in")).toBe(false)

            JS.exec("click", click.getAttribute("phx-click"), view, click)
            window.requestAnimationFrame(() => {
              window.requestAnimationFrame(() => {
                window.requestAnimationFrame(() => {
                  expect(modal.classList.contains("fade-out")).toBe(false)
                  expect(modal.classList.contains("fade-in")).toBe(true)
                  expect(showEndCalled).toBe(true)
                  expect(hideEndCalled).toBe(true)
                  expect(showStartCalled).toBe(true)
                  expect(hideStartCalled).toBe(true)
                  done()
                })
              })
            })
          })
        })
      })
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
      JS.exec("click", click.getAttribute("phx-click"), view, click)
      window.requestAnimationFrame(() => {
        expect(Array.from(modal.classList)).toEqual(["modal", "fade-out"])
        done()
      })
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
      JS.exec("click", click.getAttribute("phx-click"), view, click)
      window.requestAnimationFrame(() => {
        expect(Array.from(modal1.classList)).toEqual(["modal", "fade-out"])
        expect(Array.from(modal2.classList)).toEqual(["modal", "fade-out"])
        done()
      })
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
      JS.exec("click", click.getAttribute("phx-click"), view, click)
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
        JS.exec("click", click.getAttribute("phx-click"), view, click)
      })
      JS.exec("close", close.getAttribute("phx-click"), view, close)
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

      JS.exec("close", close.getAttribute("phx-click"), view, close)
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

      JS.exec("click", add.getAttribute("phx-click"), view, add)
      JS.exec("click", add.getAttribute("phx-click"), view, add)
      JS.exec("click", add.getAttribute("phx-click"), view, add)
      window.requestAnimationFrame(() => {
        expect(Array.from(modal.classList)).toEqual(["modal", "class1"])

        JS.exec("click", remove.getAttribute("phx-click"), view, remove)
        window.requestAnimationFrame(() => {
          expect(Array.from(modal.classList)).toEqual(["modal"])
          done()
        })
      })
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

      JS.exec("click", add.getAttribute("phx-click"), view, add)
      window.requestAnimationFrame(() => {
        expect(Array.from(modal1.classList)).toEqual(["modal", "class1"])
        expect(Array.from(modal2.classList)).toEqual(["modal", "class1"])

        JS.exec("click", remove.getAttribute("phx-click"), view, remove)
        window.requestAnimationFrame(() => {
          expect(Array.from(modal1.classList)).toEqual(["modal"])
          expect(Array.from(modal2.classList)).toEqual(["modal"])
          done()
        })
      })
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
      JS.exec("click", click.getAttribute("phx-click"), view, click)
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
      view.pushInput = (sourceEl, targetCtx, newCid, phxEvent, {_target}, callback) => {
        expect(phxEvent).toBe("validate")
        expect(sourceEl.isSameNode(input)).toBe(true)
        expect(_target).toBe(input.name)
        done()
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec("change", form.getAttribute("phx-change"), view, input, args)
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
          value: "username=&other=&_target=username"
        })
        done()
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec("change", form.getAttribute("phx-change"), view, input, args)
    })

    test("input change event with JS command", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form" phx-change='validate' phx-submit="submit">
        <input type="text" name="username" id="username1" phx-change='[["push", {"event": "username_changed", "_target": "username"}]]'/>
        <input type="text" name="other" id="other" />
      </form>
      `)
      let form = document.querySelector("#my-form")
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
          value: "username=&_target=username"
        })
        done()
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec("change", input.getAttribute("phx-change"), view, input, args)
    })

    test("input change event with string event", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form" phx-change='validate' phx-submit="submit">
        <input type="text" name="username" id="username" phx-change='username_changed' />
        <input type="text" name="other" id="other" />
      </form>
      `)
      let form = document.querySelector("#my-form")
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
          value: "username=&_target=username"
        })
        done()
      }
      let args = ["push", {_target: input.name, dispatcher: input}]
      JS.exec("change", input.getAttribute("phx-change"), view, input, args)
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
      let input = document.querySelector("#username")

      view.pushWithReply = (refGen, event, payload) => {
        expect(payload).toEqual({"cid": null, "event": "save", "type": "form", "value": "username=&desc="})
        done()
      }
      JS.exec("submit", form.getAttribute("phx-submit"), view, form, ["push", {}])
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
      JS.exec("click", click.getAttribute("phx-click"), view, click)
    })

    test("loading", () => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="click" phx-click='[["push", {"event": "clicked", "loading": "#modal"}]]'></div>
      `)
      let click = document.querySelector("#click")
      let modal = document.getElementById("modal")
      JS.exec("click", click.getAttribute("phx-click"), view, click)
      expect(Array.from(modal.classList)).toEqual(["modal", "phx-click-loading"])
      expect(Array.from(click.classList)).toEqual(["phx-click-loading"])
    })

    test("value", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <div id="click" phx-value-three="3" phx-click='[["push", {"event": "clicked", "value": {"one": 1, "two": 2}}]]'></div>
      `)
      let click = document.querySelector("#click")
      let modal = document.getElementById("modal")

      view.pushWithReply = (refGenerator, event, payload, onReply) => {
        expect(payload.value).toEqual({"one": 1, "two": 2, "three": "3"})
        done()
      }
      JS.exec("click", click.getAttribute("phx-click"), view, click)
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

      view.pushEvent = (eventType, sourceEl, targetCtx, event, data) => {
        expect(event).toEqual("clicked")
        done()
      }

      expect(modal.style.display).toEqual("")
      JS.exec("click", click.getAttribute("phx-click"), view, click)
      window.requestAnimationFrame(() => {
        expect(modal.style.display).toEqual("none")
      })
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
      JS.exec("click", set.getAttribute("phx-click"), view, set)
      expect(modal.getAttribute("aria-expanded")).toEqual("true")

      JS.exec("click", remove.getAttribute("phx-click"), view, remove)
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
      JS.exec("click", set.getAttribute("phx-click"), view, set)
      expect(set.getAttribute("aria-expanded")).toEqual("true")

      expect(remove.getAttribute("class")).toEqual("here")
      JS.exec("click", remove.getAttribute("phx-click"), view, remove)
      expect(remove.getAttribute("class")).toEqual(null)
    })

    test("setting a pre-existing attribute updates its value", () => {
      let view = setupView(`
      <div id="modal" class="modal" aria-expanded="false">modal</div>
      <div id="set" phx-click='[["set_attr", {"to": "#modal", "attr": ["aria-expanded", "true"]}]]'></div>
      `)
      let set = document.querySelector("#set")

      expect(modal.getAttribute("aria-expanded")).toEqual("false")
      JS.exec("click", set.getAttribute("phx-click"), view, set)
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

      expect(modal.getAttribute("aria-expanded")).toEqual(null)
      JS.exec("click", setFalse.getAttribute("phx-click"), view, setFalse)
      expect(modal.getAttribute("aria-expanded")).toEqual("false")
      JS.exec("click", setTrue.getAttribute("phx-click"), view, setTrue)
      expect(modal.getAttribute("aria-expanded")).toEqual("true")
    })
  })

  describe("exec", () => {
    test("executes command", done => {
      let view = setupView(`
      <div id="modal" phx-remove='[["push", {"event": "clicked"}]]'>modal</div>
      <div id="click" phx-click='[["exec",["phx-remove","#modal"]]]'></div>
      `)
      let click = document.querySelector("#click")
      view.pushEvent = (eventType, sourceEl, targetCtx, event, meta) => {
        expect(eventType).toBe("exec")
        expect(event).toBe("clicked")
        done()
      }
      JS.exec("exec", click.getAttribute("phx-click"), view, click)
    })
  })

})

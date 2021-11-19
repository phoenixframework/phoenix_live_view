import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view/live_socket"
import JS from "phoenix_live_view/js"
import {simulateJoinedView, liveViewDOM} from "./test_helpers"

let setupView = (content) => {
  let el = liveViewDOM(content)
  global.document.body.appendChild(el)
  let liveSocket = new LiveSocket("/live", Socket)
  return simulateJoinedView(el, liveSocket)
}

let simulateVisibility = el => {
  el.getClientRects = () => [1]
  return el
}

describe("JS", () => {
  beforeEach(() => {
    global.document.body.innerHTML = ""
  })

  describe("exec_toggle", () => {
    test("with defaults", () => {
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
      expect(modal.style.display).toEqual("none")

      JS.exec("click", click.getAttribute("phx-click"), view, click)
      expect(modal.style.display).toEqual("block")
      expect(showEndCalled).toBe(true)
      expect(hideEndCalled).toBe(true)
      expect(showStartCalled).toBe(true)
      expect(hideStartCalled).toBe(true)
    })

    test("with display", () => {
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
      expect(modal.style.display).toEqual("none")

      JS.exec("click", click.getAttribute("phx-click"), view, click)
      expect(modal.style.display).toEqual("inline-block")
      expect(showEndCalled).toBe(true)
      expect(hideEndCalled).toBe(true)
      expect(showStartCalled).toBe(true)
      expect(hideStartCalled).toBe(true)
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
      <div id="click" phx-click='[["dispatch", {"to": "#modal", "event": "click", "detail": {"id": 123}}]]'></div>
      `)
      let modal = simulateVisibility(document.querySelector("#modal"))
      let click = document.querySelector("#click")

      modal.addEventListener("click", (e) => {
        expect(e.detail).toEqual({id: 123})
        done()
      })
      JS.exec("click", click.getAttribute("phx-click"), view, click)
    })

    test("with multiple selector", done => {
      let view = setupView(`
      <div id="modal1" class="modal">modal1</div>
      <div id="modal2" class="modal">modal2</div>
      <div id="click" phx-click='[["dispatch", {"to": ".modal", "event": "click", "detail": {"id": 123}}]]'></div>
      `)
      let modal1Clicked = false
      let modal1 = document.querySelector("#modal1")
      let modal2 = document.querySelector("#modal2")
      let click = document.querySelector("#click")

      modal1.addEventListener("click", (e) => {
       modal1Clicked = true
        expect(e.detail).toEqual({id: 123})
      })

      modal2.addEventListener("click", (e) => {
        expect(modal1Clicked).toBe(true)
        expect(e.detail).toEqual({id: 123})
        done()
      })

      JS.exec("click", click.getAttribute("phx-click"), view, click)
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

    test("change event", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form" phx-change='[["push", {"event": "validate", "_target": "username"}]]' phx-submit="submit">
        <input type="text" name="username" id="username" phx-click=''></div>
      </form>
      `)
      let form = document.querySelector("#my-form")
      let input = document.querySelector("#username")
      view.pushInput = (sourceEl, targetCtx, newCid, phxEvent, {_target}, callback) => {
        expect(sourceEl.isSameNode(input)).toBe(true)
        expect(_target).toBe(input.name)
        done()
      }
      JS.exec("change", form.getAttribute("phx-change"), view, input)
    })

    test("submit event", done => {
      let view = setupView(`
      <div id="modal" class="modal">modal</div>
      <form id="my-form" phx-change="validate" phx-submit='[["push", {"event": "save"}]]'>
        <input type="text" name="username" id="username" phx-click=''></div>
      </form>
      `)
      let form = document.querySelector("#my-form")
      let input = document.querySelector("#username")
      view.submitForm = (sourceEl, targetCtx, phxEvent) => {
        expect(sourceEl.isSameNode(input)).toBe(true)
        done()
      }
      JS.exec("submit", form.getAttribute("phx-submit"), view, input, ["push", {}])
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
  })
})


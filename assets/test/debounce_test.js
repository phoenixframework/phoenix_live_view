import {Socket} from "phoenix"
import LiveSocket, {DOM} from '../js/phoenix_live_view'

let after = (time, func) => setTimeout(func, time)

let simulateInput = (input, val) => {
  input.value = val
  DOM.dispatchEvent(input, "input")
}

let simulateKeyDown = (input, val) => {
  input.value = input.value + val;
  DOM.dispatchEvent(input, "keydown")
  DOM.dispatchEvent(input, "input")
}

let container = () => {
  let div = document.createElement("div")
  div.innerHTML = `
  <form phx-change="validate" phx-submit="submit">
    <input type="text" name="blur" phx-debounce="blur" />
    <input type="text" name="debounce-100" phx-debounce="100" />
    <input type="text" name="throttle-100" phx-throttle="100" />
    <button id="throttle-100" phx-throttle="100" />+</button>
  </form>
  `
  return div
}

describe("debounce", function() {
  test("triggers on input blur", async () => {
    let calls = 0
    let el = container().querySelector("input[name=blur]")

    DOM.debounce(el, {}, "phx-debounce", 100, "phx-throttle", 200, () => calls++)
    DOM.dispatchEvent(el, "blur")
    expect(calls).toBe(1)

    DOM.dispatchEvent(el, "blur")
    DOM.dispatchEvent(el, "blur")
    DOM.dispatchEvent(el, "blur")
    expect(calls).toBe(4)
  })

  test("triggers debounce on input blur", async () => {
    let calls = 0
    let el = container().querySelector("input[name=debounce-100]")

    el.addEventListener("input", e => {
      DOM.debounce(el, e, "phx-debounce", 0, "phx-throttle", 0, () => calls++)
    })
    simulateInput(el, "one")
    simulateInput(el, "two")
    simulateInput(el, "three")
    DOM.dispatchEvent(el, "blur")
    expect(calls).toBe(1)
    expect(el.value).toBe("three")
  })

  test("triggers on timeout", done => {
    let calls = 0
    let el = container().querySelector("input[name=debounce-100]")

    el.addEventListener("input", e => {
      DOM.debounce(el, e, "phx-debounce", 100, "phx-throttle", 200, () => calls++)
    })
    simulateKeyDown(el, "1")
    simulateKeyDown(el, "2")
    simulateKeyDown(el, "3")
    after(50, () => {
      expect(calls).toBe(0)
      simulateKeyDown(el, "4")
      after(50, () => {
        expect(calls).toBe(0)
        after(50, () => {
          expect(calls).toBe(1)
          expect(el.value).toBe("1234")
          simulateKeyDown(el, "5")
          simulateKeyDown(el, "6")
          simulateKeyDown(el, "7")
          after(150, () => {
            expect(calls).toBe(2)
            expect(el.value).toBe("1234567")
            done()
          })
        })
      })
    })
  })

  test("uses default when value is blank", done => {
    let calls = 0
    let el = container().querySelector("input[name=debounce-100]")
    el.setAttribute("phx-debounce", "")

    el.addEventListener("input", e => {
      DOM.debounce(el, e, "phx-debounce", 500, "phx-throttle", 200, () => calls++)
    })
    simulateInput(el, "one")
    simulateInput(el, "two")
    simulateInput(el, "three")
    after(100, () => {
      expect(calls).toBe(0)
      expect(el.value).toBe("three")
      simulateInput(el, "four")
      simulateInput(el, "five")
      simulateInput(el, "six")
      after(600, () => {
        expect(calls).toBe(1)
        expect(el.value).toBe("six")
        done()
      })
    })
  })


  test("cancels trigger on phx-change", done => {
    let calls = 0
    let el = container().querySelector("input[name=debounce-100]")

    el.addEventListener("input", e => {
      DOM.debounce(el, e, "phx-debounce", 100, "phx-throttle", 200, () => calls++)
    })
    el.form.addEventListener("phx-change", () => {
      el.value = "phx-changed"
    })
    simulateInput(el, "changed")
    DOM.dispatchEvent(el.form, "phx-change")
    after(100, () => {
      expect(calls).toBe(0)
      expect(el.value).toBe("phx-changed")
      simulateInput(el, "changed again")
      after(100, () => {
        expect(calls).toBe(1)
        expect(el.value).toBe("changed again")
        done()
      })
    })
  })

  test("cancels trigger on submit", done => {
    let calls = 0
    let el = container().querySelector("input[name=debounce-100]")

    el.addEventListener("input", e => {
      DOM.debounce(el, e, "phx-debounce", 100, "phx-throttle", 200, () => calls++)
    })
    el.form.addEventListener("submit", () => {
      el.value = "submitted"
    })
    simulateInput(el, "changed")
    DOM.dispatchEvent(el.form, "submit")
    after(100, () => {
      expect(calls).toBe(0)
      expect(el.value).toBe("submitted")
      simulateInput(el, "changed again")
      after(100, () => {
        expect(calls).toBe(1)
        expect(el.value).toBe("changed again")
        done()
      })
    })
  })
})

describe("throttle", function() {
  test("triggers immediately, then on timeout", done => {
    let calls = 0
    let el = container().querySelector("#throttle-100")

    el.addEventListener("click", e => {
      DOM.debounce(el, e, "phx-debounce", 100, "phx-throttle", 200, () => {
        calls++
        el.innerText = `now:${calls}`
      })
    })
    DOM.dispatchEvent(el, "click")
    DOM.dispatchEvent(el, "click")
    DOM.dispatchEvent(el, "click")
    expect(calls).toBe(1)
    expect(el.innerText).toBe("now:1")
    after(100, () => {
      expect(calls).toBe(1)
      expect(el.innerText).toBe("now:1")
      DOM.dispatchEvent(el, "click")
      DOM.dispatchEvent(el, "click")
      DOM.dispatchEvent(el, "click")
      after(100, () => {
        expect(calls).toBe(2)
        expect(el.innerText).toBe("now:2")
        done()
      })
    })
  })

  test("uses default when value is blank", done => {
    let calls = 0
    let el = container().querySelector("#throttle-100")
    el.setAttribute("phx-throttle", "")

    el.addEventListener("click", e => {
      DOM.debounce(el, e, "phx-debounce", 100, "phx-throttle", 500, () => {
        calls++
        el.innerText = `now:${calls}`
      })
    })
    DOM.dispatchEvent(el, "click")
    DOM.dispatchEvent(el, "click")
    DOM.dispatchEvent(el, "click")
    expect(calls).toBe(1)
    expect(el.innerText).toBe("now:1")
    after(100, () => {
      expect(calls).toBe(1)
      expect(el.innerText).toBe("now:1")
      DOM.dispatchEvent(el, "click")
      DOM.dispatchEvent(el, "click")
      DOM.dispatchEvent(el, "click")
      after(100, () => {
        expect(calls).toBe(1)
        expect(el.innerText).toBe("now:1")
        done()
      })
    })
  })


  test("cancels trigger on phx-change", done => {
    let calls = 0
    let el = container().querySelector("input[name=throttle-100]")
    let otherInput = el.form.querySelector("input[name=debounce-100]")

    el.addEventListener("input", e => {
      DOM.debounce(el, e, "phx-debounce", 100, "phx-throttle", 200, () => calls++)
    })
    el.form.addEventListener("phx-change", () => {
      el.value = "phx-changed"
    })
    simulateInput(el, "changed")
    simulateInput(el, "changed2")
    DOM.dispatchEvent(el.form, "phx-change", {triggeredBy: otherInput})
    expect(calls).toBe(1)
    expect(el.value).toBe("phx-changed")
    simulateInput(el, "changed3")
    after(100, () => {
      expect(calls).toBe(2)
      expect(el.value).toBe("changed3")
      done()
    })
  })

  test("cancels trigger on submit", done => {
    let calls = 0
    let el = container().querySelector("input[name=throttle-100]")

    el.addEventListener("input", e => {
      DOM.debounce(el, e, "phx-debounce", 100, "phx-throttle", 200, () => calls++)
    })
    el.form.addEventListener("submit", () => {
      el.value = "submitted"
    })
    simulateInput(el, "changed")
    simulateInput(el, "changed2")
    DOM.dispatchEvent(el.form, "submit")
    expect(calls).toBe(1)
    expect(el.value).toBe("submitted")
    simulateInput(el, "changed3")
    after(100, () => {
      expect(calls).toBe(2)
      expect(el.value).toBe("changed3")
      done()
    })
  })
})



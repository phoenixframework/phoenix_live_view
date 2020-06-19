import {DOM} from "../js/phoenix_live_view"

let appendTitle = opts => {
  let title = document.createElement("title")
  let {prefix, suffix} = opts
  if(prefix){ title.setAttribute("data-prefix", prefix) }
  if(suffix){ title.setAttribute("data-suffix", suffix) }
  document.head.appendChild(title)
}

let tag = (tagName, attrs, innerHTML) => {
  let el = document.createElement(tagName)
  el.innerHTML = innerHTML
  for(let key in attrs){ el.setAttribute(key, attrs[key]) }
  return el
}

describe("DOM", () => {
  beforeEach(() => {
    let curTitle = document.querySelector("title")
    curTitle && curTitle.remove()
  })

  describe("putTitle", () => {
    test("with no attributes", () => {
      appendTitle({})
      DOM.putTitle("My Title")
      expect(document.title).toBe("My Title")
    })

    test("with prefix", () => {
      appendTitle({prefix: "PRE "})
      DOM.putTitle("My Title")
      expect(document.title).toBe("PRE My Title")
    })

    test("with suffix", () => {
      appendTitle({suffix: " POST"})
      DOM.putTitle("My Title")
      expect(document.title).toBe("My Title POST")
    })

    test("with prefix and suffix", () => {
      appendTitle({prefix: "PRE ", suffix: " POST"})
      DOM.putTitle("My Title")
      expect(document.title).toBe("PRE My Title POST")
    })
  })

  describe("findParentCIDs", () => {
    test("returns only parent cids", () => {
      let view = tag("div", {}, `
        <div data-phx-main="true"
            data-phx-session="123"
            data-phx-static="456"
            data-phx-view="V"
            id="phx-123"
            class="phx-connected"
            data-phx-root-id="phx-FgFpFf-J8Gg-jEnh">
        </div>
      `)
      document.body.appendChild(view)

      expect(DOM.findParentCIDs(view, [1, 2, 3])).toEqual(new Set([1, 2, 3]))

      view.appendChild(tag("div", {"data-phx-component": 1}, `
        <div data-phx-component="2"></div>
      `))
      expect(DOM.findParentCIDs(view, [1, 2, 3])).toEqual(new Set([1, 3]))

      view.appendChild(tag("div", {"data-phx-component": 1}, `
        <div data-phx-component="2">
          <div data-phx-component="3"></div>
        </div>
      `))
      expect(DOM.findParentCIDs(view, [1, 2, 3])).toEqual(new Set([1]))
    })
  })

  describe("findComponentNodeList", () => {
    test("returns nodes with cid ID (except indirect children)", () => {
      let component1 = tag("div", {"data-phx-component": 0}, `Hello`)
      let component2 = tag("div", {"data-phx-component": 0}, `World`)
      let component3 = tag("div", {"data-phx-view": "Example"}, `
        <div data-phx-component="0"></div>
      `)
      document.body.appendChild(component1)
      document.body.appendChild(component2)
      document.body.appendChild(component3)

      expect(DOM.findComponentNodeList(document, 0)).toEqual([component1, component2])
    })

    test("returns empty list with no matching cid", () => {
      expect(DOM.findComponentNodeList(document, 123)).toEqual([])
    })
  })

  test("isNowTriggerFormExternal", () => {
    let form
    form = tag("form", {"phx-trigger-external": ""}, "")
    expect(DOM.isNowTriggerFormExternal(form, "phx-trigger-external")).toBe(true)

    form = tag("form", {}, "")
    expect(DOM.isNowTriggerFormExternal(form, "phx-trigger-external")).toBe(false)
  })

  test("undoRefs restores phx specific attributes awaiting a ref", () => {
    let content = `
      <span data-phx-ref="1"></span>
      <form phx-change="suggest" phx-submit="search" phx-page-loading="" class="phx-submit-loading" data-phx-ref="38">
        <input type="text" name="q" value="ddsdsd" placeholder="Live dependency search" list="results" autocomplete="off" data-phx-readonly="false" readonly="" class="phx-submit-loading" data-phx-ref="38">
        <datalist id="results">
        </datalist>
        <button type="submit" phx-disable-with="Searching..." data-phx-disabled="false" disabled="" class="phx-submit-loading" data-phx-ref="38" data-phx-disable-with-restore="GO TO HEXDOCS">Searching...</button>
      </form>
    `.trim()
    let div = tag("div", {}, content)

    DOM.undoRefs(1, div)
    expect(div.innerHTML).toBe(`
      <span></span>
      <form phx-change="suggest" phx-submit="search" phx-page-loading="" class="phx-submit-loading" data-phx-ref="38">
        <input type="text" name="q" value="ddsdsd" placeholder="Live dependency search" list="results" autocomplete="off" data-phx-readonly="false" readonly="" class="phx-submit-loading" data-phx-ref="38">
        <datalist id="results">
        </datalist>
        <button type="submit" phx-disable-with="Searching..." data-phx-disabled="false" disabled="" class="phx-submit-loading" data-phx-ref="38" data-phx-disable-with-restore="GO TO HEXDOCS">Searching...</button>
      </form>
    `.trim())

    DOM.undoRefs(38, div)
    expect(div.innerHTML).toBe(`
      <span></span>
      <form phx-change="suggest" phx-submit="search" phx-page-loading="">
        <input type="text" name="q" value="ddsdsd" placeholder="Live dependency search" list="results" autocomplete="off">
        <datalist id="results">
        </datalist>
        <button type="submit" phx-disable-with="Searching...">Searching...</button>
      </form>
    `.trim())
  })
})


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

  describe("findFirstComponentNode", () => {
    test("returns the first node with cid ID", () => {
      let component = tag("div", {"data-phx-component": 0}, `
        <div data-phx-component="0"></div>
      `)
      document.body.appendChild(component )

      expect(DOM.findFirstComponentNode(document, 0)).toBe(component)
    })

    test("returns null with no matching cid", () => {
      expect(DOM.findFirstComponentNode(document, 123)).toBe(null)
    })
  })
})


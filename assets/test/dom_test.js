import DOM from "phoenix_live_view/dom"
import {appendTitle, tag} from "./test_helpers"

let e = (href) => {
  let event = {}
  let anchor = document.createElement("a")
  anchor.setAttribute("href", href)
  event.target = anchor
  event.defaultPrevented = false
  return event
}

describe("DOM", () => {
  beforeEach(() => {
    let curTitle = document.querySelector("title")
    curTitle && curTitle.remove()
  })

  describe ("wantsNewTab", () => {
    test("case insensitive target", () => {
      let event = e("https://test.local")
      expect(DOM.wantsNewTab(event)).toBe(false)
      // lowercase
      event.target.setAttribute("target", "_blank")
      expect(DOM.wantsNewTab(event)).toBe(true)
      // uppercase
      event.target.setAttribute("target", "_BLANK")
      expect(DOM.wantsNewTab(event)).toBe(true)
    })
  })

  describe("isNewPageClick", () => {
    test("identical locations", () => {
      let currentLoc
      currentLoc = new URL("https://test.local/foo")
      expect(DOM.isNewPageClick(e("/foo"), currentLoc)).toBe(true)
      expect(DOM.isNewPageClick(e("https://test.local/foo"), currentLoc)).toBe(true)
      expect(DOM.isNewPageClick(e("//test.local/foo"), currentLoc)).toBe(true)
      // with hash
      expect(DOM.isNewPageClick(e("/foo#hash"), currentLoc)).toBe(false)
      expect(DOM.isNewPageClick(e("https://test.local/foo#hash"), currentLoc)).toBe(false)
      expect(DOM.isNewPageClick(e("//test.local/foo#hash"), currentLoc)).toBe(false)
      // different paths
      expect(DOM.isNewPageClick(e("/foo2#hash"), currentLoc)).toBe(true)
      expect(DOM.isNewPageClick(e("https://test.local/foo2#hash"), currentLoc)).toBe(true)
      expect(DOM.isNewPageClick(e("//test.local/foo2#hash"), currentLoc)).toBe(true)
    })

    test("identical locations with query", () => {
      let currentLoc
      currentLoc = new URL("https://test.local/foo?query=1")
      expect(DOM.isNewPageClick(e("/foo"), currentLoc)).toBe(true)
      expect(DOM.isNewPageClick(e("https://test.local/foo?query=1"), currentLoc)).toBe(true)
      expect(DOM.isNewPageClick(e("//test.local/foo?query=1"), currentLoc)).toBe(true)
      // with hash
      expect(DOM.isNewPageClick(e("/foo?query=1#hash"), currentLoc)).toBe(false)
      expect(DOM.isNewPageClick(e("https://test.local/foo?query=1#hash"), currentLoc)).toBe(false)
      expect(DOM.isNewPageClick(e("//test.local/foo?query=1#hash"), currentLoc)).toBe(false)
      // different query
      expect(DOM.isNewPageClick(e("/foo?query=2#hash"), currentLoc)).toBe(true)
      expect(DOM.isNewPageClick(e("https://test.local/foo?query=2#hash"), currentLoc)).toBe(true)
      expect(DOM.isNewPageClick(e("//test.local/foo?query=2#hash"), currentLoc)).toBe(true)
    })

    test("empty hash href", () => {
      let currentLoc = new URL("https://test.local/foo")
      expect(DOM.isNewPageClick(e("#"), currentLoc)).toBe(false)
    })

    test("local hash", () => {
      let currentLoc = new URL("https://test.local/foo")
      expect(DOM.isNewPageClick(e("#foo"), currentLoc)).toBe(false)
    })

    test("with defaultPrevented return sfalse", () => {
      let currentLoc
      currentLoc = new URL("https://test.local/foo")
      let event = e("/foo")
      event.defaultPrevented = true
      expect(DOM.isNewPageClick(e, currentLoc)).toBe(false)
    })
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
      let component1 = tag("div", {"data-phx-component": 0}, "Hello")
      let component2 = tag("div", {"data-phx-component": 0}, "World")
      let component3 = tag("div", {"data-phx-session": "123"}, `
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

  describe("cleanChildNodes", () => {
    test("only cleans when phx-update is append or prepend", () => {
      let content = `
      <div id="1">1</div>
      <div>no id</div>

      some test
      `.trim()

      let div = tag("div", {}, content)
      DOM.cleanChildNodes(div, "phx-update")

      expect(div.innerHTML).toBe(content)
    })

    test("silently removes empty text nodes", () => {
      let content = `
      <div id="1">1</div>


      <div id="2">2</div>
      `.trim()

      let div = tag("div", {"phx-update": "append"}, content)
      DOM.cleanChildNodes(div, "phx-update")

      expect(div.innerHTML).toBe("<div id=\"1\">1</div><div id=\"2\">2</div>")
    })

    test("emits warning when removing elements without id", () => {
      let content = `
      <div id="1">1</div>
      <div>no id</div>

      some test
      `.trim()

      let div = tag("div", {"phx-update": "append"}, content)

      let errorCount = 0
      jest.spyOn(console, "error").mockImplementation(() => errorCount += 1)
      DOM.cleanChildNodes(div, "phx-update")

      expect(div.innerHTML).toBe("<div id=\"1\">1</div>")
      expect(errorCount).toBe(2)
    })
  })
})

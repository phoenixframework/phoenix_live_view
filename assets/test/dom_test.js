import {DOM} from "../js/phoenix_live_view"

let appendTitle = opts => {
  let title = document.createElement("title")
  let {prefix, postfix} = opts
  if(prefix){ title.setAttribute("data-prefix", prefix) }
  if(postfix){ title.setAttribute("data-postfix", postfix) }
  document.head.appendChild(title)
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

    test("with postfix", () => {
      appendTitle({postfix: " POST"})
      DOM.putTitle("My Title")
      expect(document.title).toBe("My Title POST")
    })

    test("with prefix and postfix", () => {
      appendTitle({prefix: "PRE ", postfix: " POST"})
      DOM.putTitle("My Title")
      expect(document.title).toBe("PRE My Title POST")
    })
  })
})


import Rendered from "phoenix_live_view/rendered"

const STATIC = "s"
const DYNAMICS = "d"
const COMPONENTS = "c"
const TEMPLATES = "p"

describe("Rendered", () => {
  describe("mergeDiff", () => {
    test("recursively merges two diffs", () => {
      let simple = new Rendered("123", simpleDiff1)
      simple.mergeDiff(simpleDiff2)
      expect(simple.get()).toEqual({...simpleDiffResult, [COMPONENTS]: {}, newRender: true})

      let deep = new Rendered("123", deepDiff1)
      deep.mergeDiff(deepDiff2)
      expect(deep.get()).toEqual({...deepDiffResult, [COMPONENTS]: {}})
    })

    test("merges the latter diff if it contains a `static` key", () => {
      const diff1 = {0: ["a"], 1: ["b"]}
      const diff2 = {0: ["c"], [STATIC]: ["c"]}
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({...diff2, [COMPONENTS]: {}})
    })

    test("merges the latter diff if it contains a `static` key even when nested", () => {
      const diff1 = {0: {0: ["a"], 1: ["b"]}}
      const diff2 = {0: {0: ["c"], [STATIC]: ["c"]}}
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({...diff2, [COMPONENTS]: {}})
    })

    test("merges components considering links", () => {
      const diff1 = {}
      const diff2 = {[COMPONENTS]: {1: {[STATIC]: ["c"]}, 2: {[STATIC]: 1}}}
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({[COMPONENTS]: {1: {[STATIC]: ["c"]}, 2: {[STATIC]: ["c"]}}})
    })

    test("merges components considering old and new links", () => {
      const diff1 = {[COMPONENTS]: {1: {[STATIC]: ["old"]}}}
      const diff2 = {[COMPONENTS]: {1: {[STATIC]: ["new"]}, 2: {newRender: true, [STATIC]: -1}, 3: {newRender: true, [STATIC]: 1}}}
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({
        [COMPONENTS]: {
          1: {[STATIC]: ["new"]},
          2: {[STATIC]: ["old"]},
          3: {[STATIC]: ["new"]}
        }
      })
    })

    test("merges components whole tree considering old and new links", () => {
      const diff1 = {[COMPONENTS]: {1: {0: {[STATIC]: ["nested"]}, [STATIC]: ["old"]}}}

      const diff2 = {
        [COMPONENTS]: {
          1: {0: {[STATIC]: ["nested"]}, [STATIC]: ["new"]},
          2: {0: {[STATIC]: ["replaced"]}, [STATIC]: -1},
          3: {0: {[STATIC]: ["replaced"]}, [STATIC]: 1},
          4: {[STATIC]: -1},
          5: {[STATIC]: 1}
        }
      }

      let rendered1 = new Rendered("123", diff1)
      rendered1.mergeDiff(diff2)
      expect(rendered1.get()).toEqual({
        [COMPONENTS]: {
          1: {0: {[STATIC]: ["nested"]}, [STATIC]: ["new"]},
          2: {0: {[STATIC]: ["replaced"]}, [STATIC]: ["old"]},
          3: {0: {[STATIC]: ["replaced"]}, [STATIC]: ["new"]},
          4: {0: {[STATIC]: ["nested"]}, [STATIC]: ["old"]},
          5: {0: {[STATIC]: ["nested"]}, [STATIC]: ["new"]},
        }
      })

      const diff3 = {
        [COMPONENTS]: {
          1: {0: {[STATIC]: ["newRender"]}, [STATIC]: ["new"]},
          2: {0: {[STATIC]: ["replaced"]}, [STATIC]: -1},
          3: {0: {[STATIC]: ["replaced"]}, [STATIC]: 1},
          4: {[STATIC]: -1},
          5: {[STATIC]: 1}
        }
      }

      let rendered2 = new Rendered("123", diff1)
      rendered2.mergeDiff(diff3)
      expect(rendered2.get()).toEqual({
        [COMPONENTS]: {
          1: {0: {[STATIC]: ["newRender"]}, [STATIC]: ["new"]},
          2: {0: {[STATIC]: ["replaced"]}, [STATIC]: ["old"]},
          3: {0: {[STATIC]: ["replaced"]}, [STATIC]: ["new"]},
          4: {0: {[STATIC]: ["nested"]}, [STATIC]: ["old"]},
          5: {0: {[STATIC]: ["newRender"]}, [STATIC]: ["new"]},
        }
      })
    })

    test("replaces a string when a map is returned", () => {
      const diff1 = {0: {0: "<button>Press Me</button>", [STATIC]: ""}}
      const diff2 = {0: {0: {0: "val", [STATIC]: ""}, [STATIC]: ""}}
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({...diff2, [COMPONENTS]: {}})
    })

    test("replaces a map when a string is returned", () => {
      const diff1 = {0: {0: {0: "val", [STATIC]: ""}, [STATIC]: ""}}
      const diff2 = {0: {0: "<button>Press Me</button>", [STATIC]: ""}}
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({...diff2, [COMPONENTS]: {}})
    })

    test("expands shared static from cids", () => {
      const mountDiff = {
        "0": "",
        "1": "",
        "2": {
          "0": "new post",
          "1": "",
          "2": {
            "d": [[1], [2]],
            "s": ["", ""]
          },
          "s": ["h1", "h2", "h3", "h4"]
        },
        "c": {
          "1": {
            "0": "1008",
            "1": "chris_mccord",
            "2": "My post",
            "3": "1",
            "4": "0",
            "5": "1",
            "6": "0",
            "7": "edit",
            "8": "delete",
            "s": ["s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9"]
          },
          "2": {
            "0": "1007",
            "1": "chris_mccord",
            "2": "My post",
            "3": "2",
            "4": "0",
            "5": "2",
            "6": "0",
            "7": "edit",
            "8": "delete",
            "s": 1
          }
        },
        "s": ["f1", "f2", "f3", "f4"],
        "title": "Listing Posts"
      }

      const updateDiff = {
        "2": {
          "2": {
            "d": [[3]]
          }
        },
        "c": {
          "3": {
            "0": "1009",
            "1": "chris_mccord",
            "2": "newnewnewnewnewnewnewnew",
            "3": "3",
            "4": "0",
            "5": "3",
            "6": "0",
            "7": "edit",
            "8": "delete",
            "s": -2
          }
        }
      }

      let rendered = new Rendered("123", mountDiff)
      expect(rendered.getComponent(rendered.get(), 1)[STATIC]).toEqual(rendered.getComponent(rendered.get(), 2)[STATIC])
      rendered.mergeDiff(updateDiff)
      let sharedStatic = rendered.getComponent(rendered.get(), 1)[STATIC]

      expect(sharedStatic).toBeTruthy()
      expect(sharedStatic).toEqual(rendered.getComponent(rendered.get(), 2)[STATIC])
      expect(sharedStatic).toEqual(rendered.getComponent(rendered.get(), 3)[STATIC])
    })
  })

  describe("isNewFingerprint", () => {
    test("returns true if `diff.static` is truthy", () => {
      const diff = {[STATIC]: ["<h2>"]}
      let rendered = new Rendered("123", {})
      expect(rendered.isNewFingerprint(diff)).toEqual(true)
    })

    test("returns false if `diff.static` is falsy", () => {
      const diff = {[STATIC]: undefined}
      let rendered = new Rendered("123", {})
      expect(rendered.isNewFingerprint(diff)).toEqual(false)
    })

    test("returns false if `diff` is undefined", () => {
      let rendered = new Rendered("123", {})
      expect(rendered.isNewFingerprint()).toEqual(false)
    })
  })

  describe("toString", () => {
    test("stringifies a diff", () => {
      let rendered = new Rendered("123", simpleDiffResult)
      let [str, streams] = rendered.toString()
      expect(str.trim()).toEqual(
        `<div data-phx-id="123-1" class="thermostat">
  <div class="bar cooling">
    <a href="#" phx-click="toggle-mode">cooling</a>
    <span>07:15:04 PM</span>
  </div>
</div>`.trim())
    })

    test("reuses static in components and comprehensions", () => {
      let rendered = new Rendered("123", staticReuseDiff)
      let [str, streams] = rendered.toString()
      expect(str.trim()).toEqual(
        `<div data-phx-id="123-1">
  <p>
    foo
    <span>0: <b data-phx-id="123-c-1" data-phx-component="1">FROM index_1 world</b></span><span>1: <b data-phx-id="123-c-2" data-phx-component="2">FROM index_2 world</b></span>
  </p>

  <p>
    bar
    <span>0: <b data-phx-id="123-c-3" data-phx-component="3">FROM index_1 world</b></span><span>1: <b data-phx-id="123-c-4" data-phx-component="4">FROM index_2 world</b></span>
  </p>
</div>`.trim())
    })
  })
})

const simpleDiff1 = {
  "0": "cooling",
  "1": "cooling",
  "2": "07:15:03 PM",
  [STATIC]: [
    "<div class=\"thermostat\">\n  <div class=\"bar ",
    "\">\n    <a href=\"#\" phx-click=\"toggle-mode\">",
    "</a>\n    <span>",
    "</span>\n  </div>\n</div>\n",
  ],
  "r": 1
}

const simpleDiff2 = {
  "2": "07:15:04 PM",
}

const simpleDiffResult = {
  "0": "cooling",
  "1": "cooling",
  "2": "07:15:04 PM",
  [STATIC]: [
    "<div class=\"thermostat\">\n  <div class=\"bar ",
    "\">\n    <a href=\"#\" phx-click=\"toggle-mode\">",
    "</a>\n    <span>",
    "</span>\n  </div>\n</div>\n",
  ],
  "r": 1
}

const deepDiff1 = {
  "0": {
    "0": {
      [DYNAMICS]: [["user1058", "1"], ["user99", "1"]],
      [STATIC]: ["        <tr>\n          <td>", " (", ")</td>\n        </tr>\n"],
      "r": 1
    },
    [STATIC]: [
      "  <table>\n    <thead>\n      <tr>\n        <th>Username</th>\n        <th></th>\n      </tr>\n    </thead>\n    <tbody>\n",
      "    </tbody>\n  </table>\n",
    ],
    "r": 1
  },
  "1": {
    [DYNAMICS]: [
      [
        "asdf_asdf",
        "asdf@asdf.com",
        "123-456-7890",
        "<a href=\"/users/1\">Show</a>",
        "<a href=\"/users/1/edit\">Edit</a>",
        "<a href=\"#\" phx-click=\"delete_user\" phx-value=\"1\">Delete</a>",
      ],
    ],
    [STATIC]: [
      "    <tr>\n      <td>",
      "</td>\n      <td>",
      "</td>\n      <td>",
      "</td>\n\n      <td>\n",
      "        ",
      "\n",
      "      </td>\n    </tr>\n",
    ],
    "r": 1
  }
}

const deepDiff2 = {
  "0": {
    "0": {
      [DYNAMICS]: [["user1058", "2"]],
    },
  }
}

const deepDiffResult = {
  "0": {
    "0": {
      newRender: true,
      [DYNAMICS]: [["user1058", "2"]],
      [STATIC]: ["        <tr>\n          <td>", " (", ")</td>\n        </tr>\n"],
      "r": 1
    },
    [STATIC]: [
      "  <table>\n    <thead>\n      <tr>\n        <th>Username</th>\n        <th></th>\n      </tr>\n    </thead>\n    <tbody>\n",
      "    </tbody>\n  </table>\n",
    ],
    newRender: true,
    "r": 1,
  },
  "1": {
    [DYNAMICS]: [
      [
        "asdf_asdf",
        "asdf@asdf.com",
        "123-456-7890",
        "<a href=\"/users/1\">Show</a>",
        "<a href=\"/users/1/edit\">Edit</a>",
        "<a href=\"#\" phx-click=\"delete_user\" phx-value=\"1\">Delete</a>",
      ],
    ],
    [STATIC]: [
      "    <tr>\n      <td>",
      "</td>\n      <td>",
      "</td>\n      <td>",
      "</td>\n\n      <td>\n",
      "        ",
      "\n",
      "      </td>\n    </tr>\n",
    ],
    "r": 1
  }
}

const staticReuseDiff = {
  "0": {
    [DYNAMICS]: [
      ["foo", {[DYNAMICS]: [["0", 1], ["1", 2]], [STATIC]: 0}],
      ["bar", {[DYNAMICS]: [["0", 3], ["1", 4]], [STATIC]: 0}]
    ],
    [STATIC]: ["\n  <p>\n    ", "\n    ", "\n  </p>\n"],
    "r": 1,
    [TEMPLATES]: {"0": ["<span>", ": ", "</span>"]}
  },
  [COMPONENTS]: {
    "1": {"0": "index_1", "1": "world", [STATIC]: ["<b>FROM ", " ", "</b>"], "r": 1},
    "2": {"0": "index_2", "1": "world", [STATIC]: 1, "r": 1},
    "3": {"0": "index_1", "1": "world", [STATIC]: 1, "r": 1},
    "4": {"0": "index_2", "1": "world", [STATIC]: 3, "r": 1}
  },
  [STATIC]: ["<div>", "</div>"],
  "r": 1
}
import { Rendered } from "../js/phoenix_live_view"

const STATIC = "s"
const DYNAMICS = "d"
const COMPONENTS = "c"

describe("Rendered", () => {
  describe("mergeDiff", () => {
    test("recursively merges two diffs", () => {
      let simple = new Rendered("123", simpleDiff1)
      simple.mergeDiff(simpleDiff2)
      expect(simple.get()).toEqual({...simpleDiffResult, [COMPONENTS]: {}})

      let deep = new Rendered("123", deepDiff1)
      deep.mergeDiff(deepDiff2)
      expect(deep.get()).toEqual({...deepDiffResult, [COMPONENTS]: {}})
    })

    test("merges the latter diff if it contains a `static` key", () => {
      const diff1 = { 0: ["a"], 1: ["b"] }
      const diff2 = { 0: ["c"], [STATIC]: ["c"]}
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({...diff2, [COMPONENTS]: {}})
    })

    test("merges the latter diff if it contains a `static` key even when nested", () => {
      const diff1 = { 0: { 0: ["a"], 1: ["b"] } }
      const diff2 = { 0: { 0: ["c"], [STATIC]: ["c"]} }
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({...diff2, [COMPONENTS]: {}})
    })

    test("merges components considering links", () => {
      const diff1 = { }
      const diff2 = { [COMPONENTS]: { 1: { [STATIC]: ["c"] }, 2: { [STATIC]: 1 } } }
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({ [COMPONENTS]: { 1: { [STATIC]: ["c"] }, 2: { [STATIC]: ["c"] } } })
    })

    test("merges components considering old and new links", () => {
      const diff1 = { [COMPONENTS]: { 1: { [STATIC]: ["old"] } } }
      const diff2 = { [COMPONENTS]: { 1: { [STATIC]: ["new"] }, 2: { [STATIC]: -1 }, 3: { [STATIC]: 1 } } }
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({ [COMPONENTS]: {
        1: { [STATIC]: ["new"] },
        2: { [STATIC]: ["old"] },
        3: { [STATIC]: ["new"] }
      } })
    })

    test("merges components whole tree considering old and new links", () => {
      const diff1 = { [COMPONENTS]: { 1: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["old"] } } }

      const diff2 = {
        [COMPONENTS]: {
          1: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["new"] },
          2: { 0: { [STATIC]: ["replaced"] }, [STATIC]: -1 },
          3: { 0: { [STATIC]: ["replaced"] }, [STATIC]: 1 },
          4: { [STATIC]: -1 },
          5: { [STATIC]: 1 }
        }
      }

      let rendered1 = new Rendered("123", diff1)
      rendered1.mergeDiff(diff2)
      expect(rendered1.get()).toEqual({ [COMPONENTS]: {
        1: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["new"] },
        2: { 0: { [STATIC]: ["replaced"] }, [STATIC]: ["old"] },
        3: { 0: { [STATIC]: ["replaced"] }, [STATIC]: ["new"] },
        4: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["old"] },
        5: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["new"] },
      } })

      const diff3 = {
        [COMPONENTS]: {
          1: { 0: { [STATIC]: ["changed"] }, [STATIC]: ["new"] },
          2: { 0: { [STATIC]: ["replaced"] }, [STATIC]: -1 },
          3: { 0: { [STATIC]: ["replaced"] }, [STATIC]: 1 },
          4: { [STATIC]: -1 },
          5: { [STATIC]: 1 }
        }
      }

      let rendered2 = new Rendered("123", diff1)
      rendered2.mergeDiff(diff3)
      expect(rendered2.get()).toEqual({ [COMPONENTS]: {
        1: { 0: { [STATIC]: ["changed"] }, [STATIC]: ["new"] },
        2: { 0: { [STATIC]: ["replaced"] }, [STATIC]: ["old"] },
        3: { 0: { [STATIC]: ["replaced"] }, [STATIC]: ["new"] },
        4: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["old"] },
        5: { 0: { [STATIC]: ["changed"] }, [STATIC]: ["new"] },
      } })
    })

    test("replaces a string when a map is returned", () => {
      const diff1 = { 0: { 0: "<button>Press Me</button>", [STATIC]: "" } }
      const diff2 = { 0: { 0: { 0: "val", [STATIC]: "" }, [STATIC]: ""} }
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({...diff2, [COMPONENTS]: {}})
    })

    test("replaces a map when a string is returned", () => {
      const diff1 = { 0: { 0: { 0: "val", [STATIC]: "" }, [STATIC]: "" } }
      const diff2 = { 0: { 0: "<button>Press Me</button>", [STATIC]: ""} }
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual({...diff2, [COMPONENTS]: {}})
    })

    test("expands shared static from cids", () => {
      const mountDiff = {
        "0": "",
        "1": "",
        "2": {
          "0": "<a data-phx-link=\"patch\" data-phx-link-state=\"push\" href=\"/posts/new\">New Post</a>",
          "1": "",
          "2": {
            "d": [[1], [2]],
            "s": ["", ""]
          },
          "s": [
            "<h1>Timeline</h1>\n\n<span>",
            "</span>\n\n",
            "\n<div id=\"posts\" phx-update=\"prepend\">\n",
            "</div>\n\n"
          ]
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
            "7": "<a data-phx-link=\"patch\" data-phx-link-state=\"push\" href=\"/posts/1008/edit\">\n        Edit\n      </a>",
            "8": "<a data-confirm=\"Are you sure?\" href=\"#\" phx-click=\"delete\" phx-value-id=\"1008\">\n        <i class=\"far fa-trash-alt\"></i>\n      </a>",
            "s": [
              "<div id=\"post-",
              "\" class=\"post\">\n  <div class=\"row\">\n    <div class=\"column column-10\">\n      <div class=\"post-avatar\"></div>\n    </div>\n    <div class=\"column column-90 post-body\">\n      <b>@",
              "</b>\n      <br/>\n      ",
              "\n    </div>\n  </div>\n\n  <div class=\"row\">\n    <div class=\"column\">\n      <a href=\"#\" phx-click=\"like\" phx-target=\"",
              "\">\n        <i class=\"far fa-heart\"></i> ",
              "\n      </a>\n    </div>\n    <div class=\"column\">\n      <a href=\"#\" phx-click=\"repost\" phx-target=\"",
              "\">\n        <i class=\"far fa-retweet\"></i> ",
              "\n      </a>\n    </div>\n    <div class=\"column\">\n      ",
              "\n      ",
              "\n    </div>\n  </div>\n</div>\n"
            ]
          },
          "2": {
            "0": "1007",
            "1": "chris_mccord",
            "2": "My post",
            "3": "2",
            "4": "0",
            "5": "2",
            "6": "0",
            "7": "<a data-phx-link=\"patch\" data-phx-link-state=\"push\" href=\"/posts/1007/edit\">\n        Edit\n      </a>",
            "8": "<a data-confirm=\"Are you sure?\" href=\"#\" phx-click=\"delete\" phx-value-id=\"1007\">\n        <i class=\"far fa-trash-alt\"></i>\n      </a>",
            "s": 1
          }
        },
        "s": [
          "<main role=\"main\" class=\"container\">\n  <p class=\"alert alert-info\" role=\"alert\"\n    phx-click=\"lv:clear-flash\"\n    phx-value-key=\"info\">",
          "</p>\n\n  <p class=\"alert alert-danger\" role=\"alert\"\n    phx-click=\"lv:clear-flash\"\n    phx-value-key=\"error\">",
          "</p>\n\n",
          "</main>\n"
        ],
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
            "7": "<a data-phx-link=\"patch\" data-phx-link-state=\"push\" href=\"/posts/1009/edit\">\n        Edit\n      </a>",
            "8": "<a data-confirm=\"Are you sure?\" href=\"#\" phx-click=\"delete\" phx-value-id=\"1009\">\n        <i class=\"far fa-trash-alt\"></i>\n      </a>",
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
      const diff = { [STATIC]: ["<h2>"] }
      let rendered = new Rendered("123", {})
      expect(rendered.isNewFingerprint(diff)).toEqual(true)
    })

    test("returns false if `diff.static` is falsy", () => {
      const diff = { [STATIC]: undefined }
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
      expect(rendered.toString().trim()).toEqual(
`<div class="thermostat">
  <div class="bar cooling">
    <a href="#" phx-click="toggle-mode">cooling</a>
    <span>07:15:04 PM</span>
  </div>
</div>`.trim())
    })
  })
})

const simpleDiff1 = {
  '0': 'cooling',
  '1': 'cooling',
  '2': '07:15:03 PM',
  [STATIC]: [
    '<div class="thermostat">\n  <div class="bar ',
    '">\n    <a href="#" phx-click="toggle-mode">',
    '</a>\n    <span>',
    '</span>\n  </div>\n</div>\n',
  ]
};

const simpleDiff2 = {
  '2': '07:15:04 PM',
};

const simpleDiffResult = {
  '0': 'cooling',
  '1': 'cooling',
  '2': '07:15:04 PM',
  [STATIC]: [
    '<div class="thermostat">\n  <div class="bar ',
    '">\n    <a href="#" phx-click="toggle-mode">',
    '</a>\n    <span>',
    '</span>\n  </div>\n</div>\n',
  ]
};

const deepDiff1 = {
  '0': {
    '0': {
      [DYNAMICS]: [['user1058', '1'], ['user99', '1']],
      [STATIC]: ['        <tr>\n          <td>', ' (', ')</td>\n        </tr>\n'],
    },
    [STATIC]: [
      '  <table>\n    <thead>\n      <tr>\n        <th>Username</th>\n        <th></th>\n      </tr>\n    </thead>\n    <tbody>\n',
      '    </tbody>\n  </table>\n',
    ],
  },
  '1': {
    [DYNAMICS]: [
      [
        'asdf_asdf',
        'asdf@asdf.com',
        '123-456-7890',
        '<a href="/users/1">Show</a>',
        '<a href="/users/1/edit">Edit</a>',
        '<a href="#" phx-click="delete_user" phx-value="1">Delete</a>',
      ],
    ],
    [STATIC]: [
      '    <tr>\n      <td>',
      '</td>\n      <td>',
      '</td>\n      <td>',
      '</td>\n\n      <td>\n',
      '        ',
      '\n',
      '      </td>\n    </tr>\n',
    ],
  }
};

const deepDiff2 = {
  '0': {
    '0': {
      [DYNAMICS]: [['user1058', '2']],
    },
  }
};

const deepDiffResult = {
  '0': {
    '0': {
      [DYNAMICS]: [['user1058', '2']],
      [STATIC]: ['        <tr>\n          <td>', ' (', ')</td>\n        </tr>\n'],
    },
    [STATIC]: [
      '  <table>\n    <thead>\n      <tr>\n        <th>Username</th>\n        <th></th>\n      </tr>\n    </thead>\n    <tbody>\n',
      '    </tbody>\n  </table>\n',
    ],
  },
  '1': {
    [DYNAMICS]: [
      [
        'asdf_asdf',
        'asdf@asdf.com',
        '123-456-7890',
        '<a href="/users/1">Show</a>',
        '<a href="/users/1/edit">Edit</a>',
        '<a href="#" phx-click="delete_user" phx-value="1">Delete</a>',
      ],
    ],
    [STATIC]: [
      '    <tr>\n      <td>',
      '</td>\n      <td>',
      '</td>\n      <td>',
      '</td>\n\n      <td>\n',
      '        ',
      '\n',
      '      </td>\n    </tr>\n',
    ],
  }
};
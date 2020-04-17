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
      const diff2 = { 0: ["c"], [STATIC]: "c"}
      let rendered = new Rendered("123", diff1)
      rendered.mergeDiff(diff2)
      expect(rendered.get()).toEqual(diff2)
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
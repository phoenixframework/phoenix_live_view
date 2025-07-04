import Rendered from "phoenix_live_view/rendered";
import {
  STATIC,
  COMPONENTS,
  KEYED,
  KEYED_COUNT,
  TEMPLATES,
} from "phoenix_live_view/constants";

describe("Rendered", () => {
  describe("mergeDiff", () => {
    test("recursively merges two diffs", () => {
      const simple = new Rendered("123", simpleDiff1);
      simple.mergeDiff(simpleDiff2);
      expect(simple.get()).toEqual({
        ...simpleDiffResult,
        [COMPONENTS]: {},
        newRender: true,
      });

      const deep = new Rendered("123", deepDiff1);
      deep.mergeDiff(deepDiff2);
      expect(deep.get()).toEqual({ ...deepDiffResult, [COMPONENTS]: {} });
    });

    test("merges the latter diff if it contains a `static` key", () => {
      const diff1 = { 0: ["a"], 1: ["b"] };
      const diff2 = { 0: ["c"], [STATIC]: ["c"] };
      const rendered = new Rendered("123", diff1);
      rendered.mergeDiff(diff2);
      expect(rendered.get()).toEqual({ ...diff2, [COMPONENTS]: {} });
    });

    test("merges the latter diff if it contains a `static` key even when nested", () => {
      const diff1 = { 0: { 0: ["a"], 1: ["b"] } };
      const diff2 = { 0: { 0: ["c"], [STATIC]: ["c"] } };
      const rendered = new Rendered("123", diff1);
      rendered.mergeDiff(diff2);
      expect(rendered.get()).toEqual({ ...diff2, [COMPONENTS]: {} });
    });

    test("merges components considering links", () => {
      const diff1 = {};
      const diff2 = {
        [COMPONENTS]: { 1: { [STATIC]: ["c"] }, 2: { [STATIC]: 1 } },
      };
      const rendered = new Rendered("123", diff1);
      rendered.mergeDiff(diff2);
      expect(rendered.get()).toEqual({
        [COMPONENTS]: { 1: { [STATIC]: ["c"] }, 2: { [STATIC]: ["c"] } },
      });
    });

    test("merges components considering old and new links", () => {
      const diff1 = { [COMPONENTS]: { 1: { [STATIC]: ["old"] } } };
      const diff2 = {
        [COMPONENTS]: {
          1: { [STATIC]: ["new"] },
          2: { newRender: true, [STATIC]: -1 },
          3: { newRender: true, [STATIC]: 1 },
        },
      };
      const rendered = new Rendered("123", diff1);
      rendered.mergeDiff(diff2);
      expect(rendered.get()).toEqual({
        [COMPONENTS]: {
          1: { [STATIC]: ["new"] },
          2: { [STATIC]: ["old"] },
          3: { [STATIC]: ["new"] },
        },
      });
    });

    test("merges components whole tree considering old and new links", () => {
      const diff1 = {
        [COMPONENTS]: { 1: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["old"] } },
      };

      const diff2 = {
        [COMPONENTS]: {
          1: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["new"] },
          2: { 0: { [STATIC]: ["replaced"] }, [STATIC]: -1 },
          3: { 0: { [STATIC]: ["replaced"] }, [STATIC]: 1 },
          4: { [STATIC]: -1 },
          5: { [STATIC]: 1 },
        },
      };

      const rendered1 = new Rendered("123", diff1);
      rendered1.mergeDiff(diff2);
      expect(rendered1.get()).toEqual({
        [COMPONENTS]: {
          1: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["new"] },
          2: { 0: { [STATIC]: ["replaced"] }, [STATIC]: ["old"] },
          3: { 0: { [STATIC]: ["replaced"] }, [STATIC]: ["new"] },
          4: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["old"] },
          5: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["new"] },
        },
      });

      const diff3 = {
        [COMPONENTS]: {
          1: { 0: { [STATIC]: ["newRender"] }, [STATIC]: ["new"] },
          2: { 0: { [STATIC]: ["replaced"] }, [STATIC]: -1 },
          3: { 0: { [STATIC]: ["replaced"] }, [STATIC]: 1 },
          4: { [STATIC]: -1 },
          5: { [STATIC]: 1 },
        },
      };

      const rendered2 = new Rendered("123", diff1);
      rendered2.mergeDiff(diff3);
      expect(rendered2.get()).toEqual({
        [COMPONENTS]: {
          1: { 0: { [STATIC]: ["newRender"] }, [STATIC]: ["new"] },
          2: { 0: { [STATIC]: ["replaced"] }, [STATIC]: ["old"] },
          3: { 0: { [STATIC]: ["replaced"] }, [STATIC]: ["new"] },
          4: { 0: { [STATIC]: ["nested"] }, [STATIC]: ["old"] },
          5: { 0: { [STATIC]: ["newRender"] }, [STATIC]: ["new"] },
        },
      });
    });

    test("replaces a string when a map is returned", () => {
      const diff1 = { 0: { 0: "<button>Press Me</button>", [STATIC]: "" } };
      const diff2 = { 0: { 0: { 0: "val", [STATIC]: "" }, [STATIC]: "" } };
      const rendered = new Rendered("123", diff1);
      rendered.mergeDiff(diff2);
      expect(rendered.get()).toEqual({ ...diff2, [COMPONENTS]: {} });
    });

    test("replaces a map when a string is returned", () => {
      const diff1 = { 0: { 0: { 0: "val", [STATIC]: "" }, [STATIC]: "" } };
      const diff2 = { 0: { 0: "<button>Press Me</button>", [STATIC]: "" } };
      const rendered = new Rendered("123", diff1);
      rendered.mergeDiff(diff2);
      expect(rendered.get()).toEqual({ ...diff2, [COMPONENTS]: {} });
    });

    test("expands shared static from cids", () => {
      const mountDiff = {
        "0": "",
        "1": "",
        "2": {
          "0": "new post",
          "1": "",
          "2": {
            d: [[1], [2]],
            s: ["", ""],
          },
          s: ["h1", "h2", "h3", "h4"],
        },
        c: {
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
            s: ["s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9"],
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
            s: 1,
          },
        },
        s: ["f1", "f2", "f3", "f4"],
        title: "Listing Posts",
      };

      const updateDiff = {
        "2": {
          "2": {
            d: [[3]],
          },
        },
        c: {
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
            s: -2,
          },
        },
      };

      const rendered = new Rendered("123", mountDiff);
      expect(rendered.getComponent(rendered.get(), 1)[STATIC]).toEqual(
        rendered.getComponent(rendered.get(), 2)[STATIC],
      );
      rendered.mergeDiff(updateDiff);
      const sharedStatic = rendered.getComponent(rendered.get(), 1)[STATIC];

      expect(sharedStatic).toBeTruthy();
      expect(sharedStatic).toEqual(
        rendered.getComponent(rendered.get(), 2)[STATIC],
      );
      expect(sharedStatic).toEqual(
        rendered.getComponent(rendered.get(), 3)[STATIC],
      );
    });
  });

  describe("isNewFingerprint", () => {
    test("returns true if `diff.static` is truthy", () => {
      const diff = { [STATIC]: ["<h2>"] };
      const rendered = new Rendered("123", {});
      expect(rendered.isNewFingerprint(diff)).toEqual(true);
    });

    test("returns false if `diff.static` is falsy", () => {
      const diff = { [STATIC]: undefined };
      const rendered = new Rendered("123", {});
      expect(rendered.isNewFingerprint(diff)).toEqual(false);
    });

    test("returns false if `diff` is undefined", () => {
      const rendered = new Rendered("123", {});
      expect(rendered.isNewFingerprint()).toEqual(false);
    });
  });

  describe("toString", () => {
    test("stringifies a diff", () => {
      const rendered = new Rendered("123", simpleDiffResult);
      const { buffer: str } = rendered.toString();
      expect(str.trim()).toEqual(
        `<div data-phx-id="m1-123" class="thermostat">
  <div class="bar cooling">
    <a href="#" phx-click="toggle-mode">cooling</a>
    <span>07:15:04 PM</span>
  </div>
</div>`.trim(),
      );
    });

    test("reuses static in components and comprehensions", () => {
      const rendered = new Rendered("123", staticReuseDiff);
      const { buffer: str } = rendered.toString();
      expect(str.trim()).toEqual(
        `<div data-phx-id="m1-123">
  <p>
    foo
    <span>0: <b data-phx-id="c1-123" data-phx-component="1" data-phx-view="123">FROM index_1 world</b></span><span>1: <b data-phx-id="c2-123" data-phx-component="2" data-phx-view="123">FROM index_2 world</b></span>
  </p>

  <p>
    bar
    <span>0: <b data-phx-id="c3-123" data-phx-component="3" data-phx-view="123">FROM index_1 world</b></span><span>1: <b data-phx-id="c4-123" data-phx-component="4" data-phx-view="123">FROM index_2 world</b></span>
  </p>
</div>`.trim(),
      );
    });
  });
});

const simpleDiff1 = {
  "0": "cooling",
  "1": "cooling",
  "2": "07:15:03 PM",
  [STATIC]: [
    '<div class="thermostat">\n  <div class="bar ',
    '">\n    <a href="#" phx-click="toggle-mode">',
    "</a>\n    <span>",
    "</span>\n  </div>\n</div>\n",
  ],
  r: 1,
};

const simpleDiff2 = {
  "2": "07:15:04 PM",
};

const simpleDiffResult = {
  "0": "cooling",
  "1": "cooling",
  "2": "07:15:04 PM",
  [STATIC]: [
    '<div class="thermostat">\n  <div class="bar ',
    '">\n    <a href="#" phx-click="toggle-mode">',
    "</a>\n    <span>",
    "</span>\n  </div>\n</div>\n",
  ],
  r: 1,
};

const deepDiff1 = {
  "0": {
    "0": {
      [KEYED]: {
        0: { 0: "user1058", 1: "1" },
        1: { 0: "user99", 1: "1" },
        [KEYED_COUNT]: 2,
      },
      [STATIC]: [
        "        <tr>\n          <td>",
        " (",
        ")</td>\n        </tr>\n",
      ],
      r: 1,
    },
    [STATIC]: [
      "  <table>\n    <thead>\n      <tr>\n        <th>Username</th>\n        <th></th>\n      </tr>\n    </thead>\n    <tbody>\n",
      "    </tbody>\n  </table>\n",
    ],
    r: 1,
  },
  "1": {
    [KEYED]: {
      0: {
        0: "asdf_asdf",
        1: "asdf@asdf.com",
        2: "123-456-7890",
        3: '<a href="/users/1">Show</a>',
        4: '<a href="/users/1/edit">Edit</a>',
        5: '<a href="#" phx-click="delete_user" phx-value="1">Delete</a>',
      },
      [KEYED_COUNT]: 1,
    },
    [STATIC]: [
      "    <tr>\n      <td>",
      "</td>\n      <td>",
      "</td>\n      <td>",
      "</td>\n\n      <td>\n",
      "        ",
      "\n",
      "      </td>\n    </tr>\n",
    ],
    r: 1,
  },
};

const deepDiff2 = {
  "0": {
    "0": {
      [KEYED]: { 0: { 0: "user1058", 1: "2" }, [KEYED_COUNT]: 1 },
    },
  },
};

const deepDiffResult = {
  "0": {
    "0": {
      newRender: true,
      [KEYED]: {
        0: { 0: "user1058", 1: "2" },
        [KEYED_COUNT]: 1,
      },
      [STATIC]: [
        "        <tr>\n          <td>",
        " (",
        ")</td>\n        </tr>\n",
      ],
      r: 1,
    },
    [STATIC]: [
      "  <table>\n    <thead>\n      <tr>\n        <th>Username</th>\n        <th></th>\n      </tr>\n    </thead>\n    <tbody>\n",
      "    </tbody>\n  </table>\n",
    ],
    newRender: true,
    r: 1,
  },
  "1": {
    [KEYED]: {
      0: {
        0: "asdf_asdf",
        1: "asdf@asdf.com",
        2: "123-456-7890",
        3: '<a href="/users/1">Show</a>',
        4: '<a href="/users/1/edit">Edit</a>',
        5: '<a href="#" phx-click="delete_user" phx-value="1">Delete</a>',
      },
      [KEYED_COUNT]: 1,
    },
    [STATIC]: [
      "    <tr>\n      <td>",
      "</td>\n      <td>",
      "</td>\n      <td>",
      "</td>\n\n      <td>\n",
      "        ",
      "\n",
      "      </td>\n    </tr>\n",
    ],
    r: 1,
  },
};

const staticReuseDiff = {
  "0": {
    [KEYED]: {
      [KEYED_COUNT]: 2,
      0: {
        0: "foo",
        1: {
          [KEYED]: {
            [KEYED_COUNT]: 2,
            0: { 0: "0", 1: 1 },
            1: { 0: "1", 1: 2 },
          },
          [STATIC]: 0,
        },
      },
      1: {
        0: "bar",
        1: {
          [KEYED]: {
            [KEYED_COUNT]: 2,
            0: { 0: "0", 1: 3 },
            1: { 0: "1", 1: 4 },
          },
          [STATIC]: 0,
        },
      },
    },
    [STATIC]: ["\n  <p>\n    ", "\n    ", "\n  </p>\n"],
    r: 1,
    [TEMPLATES]: { "0": ["<span>", ": ", "</span>"] },
  },
  [COMPONENTS]: {
    "1": {
      "0": "index_1",
      "1": "world",
      [STATIC]: ["<b>FROM ", " ", "</b>"],
      r: 1,
    },
    "2": { "0": "index_2", "1": "world", [STATIC]: 1, r: 1 },
    "3": { "0": "index_1", "1": "world", [STATIC]: 1, r: 1 },
    "4": { "0": "index_2", "1": "world", [STATIC]: 3, r: 1 },
  },
  [STATIC]: ["<div>", "</div>"],
  r: 1,
};

import Rendered, { StringSink, SINK_STATE } from "phoenix_live_view/rendered";
import {
  STATIC,
  COMPONENTS,
  KEYED,
  KEYED_COUNT,
  KEYED_MOVED,
  TEMPLATES,
} from "phoenix_live_view/constants";

describe("Rendered", () => {
  describe("mergeDiff", () => {
    test("merges a diff into the rendered tree", () => {
      const simple = new Rendered("123", simpleDiff1);
      simple.mergeDiff(simpleDiff2);
      expect(simple.get()).toEqual({
        ...simpleDiffResult,
        [COMPONENTS]: {},
        newRender: true,
      });
    });

    test("merges stable-position keyed updates without cloning", () => {
      const deep = new Rendered("123", deepDiff1);
      const clone = jest.spyOn(deep, "clone");
      deep.mergeDiff(deepDiff2);
      expect(clone).not.toHaveBeenCalled();
      expect(deep.get()).toEqual({ ...deepDiffResult, [COMPONENTS]: {} });
    });

    test("clones before moving entries so later moves use pre-merge positions", () => {
      const rendered = new Rendered("123", {
        [KEYED]: {
          0: { 0: "first", 1: "unchanged" },
          1: { 0: "second", 1: "old" },
          [KEYED_COUNT]: 2,
        },
        [STATIC]: ["", "", ""],
      });
      const before = (rendered.get() as any)[KEYED];
      const first = before[0];
      const second = before[1];
      const clone = jest.spyOn(rendered, "clone");

      rendered.mergeDiff({
        [KEYED]: {
          0: [1, { 1: "updated" }],
          1: 0,
          [KEYED_COUNT]: 2,
          [KEYED_MOVED]: true,
        },
      });

      expect(clone).toHaveBeenCalledTimes(1);
      expect((rendered.get() as any)[KEYED]).toEqual({
        0: { 0: "second", 1: "updated" },
        1: { 0: "first", 1: "unchanged" },
        [KEYED_COUNT]: 2,
      });
      expect(first).toEqual({ 0: "first", 1: "unchanged" });
      expect(second).toEqual({ 0: "second", 1: "old" });
    });

    test("clones only a moved nested keyed subtree", () => {
      const rendered = new Rendered("123", {
        [KEYED]: {
          0: {
            0: "outer",
            1: {
              [KEYED]: {
                0: { 0: "first" },
                1: { 0: "second" },
                [KEYED_COUNT]: 2,
              },
              [STATIC]: ["", ""],
            },
          },
          [KEYED_COUNT]: 1,
        },
        [STATIC]: ["", "", ""],
      });
      const outer = (rendered.get() as any)[KEYED][0];
      const nested = outer[1];
      const clone = jest.spyOn(rendered, "clone");

      rendered.mergeDiff({
        [KEYED]: {
          0: {
            1: {
              [KEYED]: {
                0: 1,
                1: 0,
                [KEYED_COUNT]: 2,
                [KEYED_MOVED]: true,
              },
            },
          },
          [KEYED_COUNT]: 1,
        },
      });

      expect(clone).toHaveBeenCalledTimes(1);
      expect(clone.mock.calls[0][0]).toBe(nested);
      expect((rendered.get() as any)[KEYED][0]).toBe(outer);
      expect(nested[KEYED]).toEqual({
        0: { 0: "second" },
        1: { 0: "first" },
        [KEYED_COUNT]: 2,
      });
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

    test("leaves call sites alone unless a sink asks for them", () => {
      const diff = {
        0: { [STATIC]: ["<span>child</span>"] },
        [STATIC]: [callerAnnotation, ""],
      };

      // Default sink: statics are emitted verbatim, nothing is tracked.
      const plain = new Rendered("123", diff);
      expect(plain.toString().buffer).toEqual(
        `${callerAnnotation}<span>child</span>`,
      );
      expect(plain.observed).toBe(false);
    });

    test("hands each call site to the sink, which owns the marker format", () => {
      const rendered = new Rendered(
        "123",
        {
          0: { [STATIC]: ["<span>child</span>"] },
          [STATIC]: [callerAnnotation, ""],
        },
        markingSink(),
      );
      const { buffer } = rendered.toString();
      const [callerId] = callerIDs(buffer);

      expect(callerId).toBeTruthy();
      // Multi-root component, so the sink chose the comment form.
      expect(buffer).toEqual(
        `${callerAnnotation}<!-- ${DEBUG_ATTR}-${callerId} -->` +
          `<span>child</span><!-- /${DEBUG_ATTR}-${callerId.split(":")[0]} -->`,
      );
      // The statics themselves are never mutated.
      expect(rendered.get()[STATIC][0]).toEqual(callerAnnotation);
    });

    test("marks a single-root component with an attribute", () => {
      const rendered = new Rendered(
        "123",
        {
          0: { 0: "one", [STATIC]: ["<span>", "</span>"], r: 1 },
          [STATIC]: [callerAnnotation, ""],
        },
        markingSink(),
      );
      const { buffer } = rendered.toString();
      const [callerId] = callerIDs(buffer);

      expect(buffer).toContain(`${DEBUG_ATTR}="${callerId}"`);
      expect(buffer).not.toContain("<!-- phx-debug-id");
    });

    test.each([
      ["single-root", true],
      ["multi-root", false],
    ])(
      "keeps the caller ID for an unchanged %s function component",
      (_name, root) => {
        const child = {
          0: "one",
          [STATIC]: ["<span>", "</span><span>constant</span>"],
          ...(root ? { r: 1 } : {}),
        };
        const rendered = new Rendered(
          "123",
          {
            0: child,
            1: "first",
            [STATIC]: [callerAnnotation, "|", ""],
          },
          markingSink(),
        );

        const [initialCallerId] = callerIDs(rendered.toString().buffer);
        const stable = initialCallerId.split(":")[0];

        rendered.mergeDiff({ 1: "second" });
        const [unchangedCallerId] = callerIDs(rendered.toString().buffer);
        expect(unchangedCallerId).toEqual(initialCallerId);

        // The server sent a non-empty child diff, even though its value is equal.
        rendered.mergeDiff({ 0: { 0: "one" } });
        // The stable half is the sink's own state, kept on the node that
        // holds the dynamic and resolved while rendering, not while merging.
        expect((rendered.get() as any)[SINK_STATE][0]).toEqual(stable);
        const [changedCallerId] = callerIDs(rendered.toString().buffer);
        expect(changedCallerId).not.toEqual(initialCallerId);
        expect(changedCallerId.split(":")[0]).toEqual(stable);
      },
    );

    test("only rotates the deepest function components that changed", () => {
      const inner = {
        0: "inner",
        [STATIC]: ["<span>", "</span>"],
      };
      const transparentWrapper = {
        0: inner,
        [STATIC]: [`<section>${callerAnnotation}`, "</section>"],
      };
      const outer = {
        0: "outer",
        1: transparentWrapper,
        [STATIC]: ["<div>", "|", "</div>"],
      };
      const rendered = new Rendered(
        "123",
        {
          0: outer,
          [STATIC]: [callerAnnotation, ""],
        },
        markingSink(),
      );

      const [initialOuterId, initialInnerId] = callerIDs(
        rendered.toString().buffer,
      );

      rendered.mergeDiff({
        0: { 1: { 0: { 0: "inner" } } },
      });
      const [unchangedOuterId, changedInnerId] = callerIDs(
        rendered.toString().buffer,
      );

      expect(unchangedOuterId).toEqual(initialOuterId);
      expect(changedInnerId).not.toEqual(initialInnerId);

      rendered.mergeDiff({
        0: { 0: "outer", 1: { 0: { 0: "inner" } } },
      });
      const [changedOuterId, changedInnerIdAgain] = callerIDs(
        rendered.toString().buffer,
      );

      expect(changedOuterId).not.toEqual(initialOuterId);
      expect(changedInnerIdAgain).not.toEqual(changedInnerId);
    });

    test("tracks caller IDs independently in keyed comprehensions", () => {
      const rendered = new Rendered(
        "123",
        {
          [KEYED]: {
            0: {
              0: { 0: "one", [STATIC]: ["<span>", "</span>"] },
            },
            1: {
              0: { 0: "two", [STATIC]: ["<span>", "</span>"] },
            },
            [KEYED_COUNT]: 2,
          },
          [STATIC]: [callerAnnotation, ""],
        },
        markingSink(),
      );

      const initialCallerIds = callerIDs(rendered.toString().buffer);
      expect(initialCallerIds).toHaveLength(2);
      expect(initialCallerIds[0]).not.toEqual(initialCallerIds[1]);

      rendered.mergeDiff({
        [KEYED]: {
          0: { 0: { 0: "updated" } },
          [KEYED_COUNT]: 2,
        },
      });

      const changedCallerIds = callerIDs(rendered.toString().buffer);
      expect(changedCallerIds[0]).not.toEqual(initialCallerIds[0]);
      expect(changedCallerIds[1]).toEqual(initialCallerIds[1]);
    });

    test.each([
      ["shrinks", { [KEYED]: { [KEYED_COUNT]: 1 } }],
      [
        "reorders without entry diffs",
        { [KEYED]: { 0: 1, 1: 0, [KEYED_MOVED]: true, [KEYED_COUNT]: 2 } },
      ],
    ])(
      "rotates a function component whose comprehension only %s",
      (_name, keyedDiff) => {
        const rendered = new Rendered(
          "123",
          {
            0: {
              [KEYED]: {
                0: { 0: "one" },
                1: { 0: "two" },
                [KEYED_COUNT]: 2,
              },
              [STATIC]: ["<span>", "</span>"],
            },
            [STATIC]: [callerAnnotation, ""],
          },
          markingSink(),
        );

        const [initialCallerId] = callerIDs(rendered.toString().buffer);

        // No surviving entry carries a diff of its own, so the change is only
        // visible on the comprehension.
        rendered.mergeDiff({ 0: keyedDiff });
        const [changedCallerId] = callerIDs(rendered.toString().buffer);

        expect(changedCallerId).not.toEqual(initialCallerId);
      },
    );

    test("does not touch the diff when debugging is disabled", () => {
      const rendered = new Rendered("123", {
        0: { 0: "one", [STATIC]: ["<span>", "</span>"] },
        [STATIC]: [callerAnnotation, ""],
      });
      const clone = jest.spyOn(rendered, "clone");

      const diff = { 0: { 0: "two" } };
      rendered.mergeDiff(diff);

      expect(clone).not.toHaveBeenCalled();
      expect(diff).toEqual({ 0: { 0: "two" } });
    });

    test("preserves caller IDs across unrelated LiveComponent diffs", () => {
      const rendered = new Rendered(
        "123",
        {
          0: 1,
          [COMPONENTS]: {
            1: {
              0: { 0: "one", [STATIC]: ["<span>", "</span>"] },
              1: "first",
              [STATIC]: [`<div>${callerAnnotation}`, "|", "</div>"],
              r: 1,
            },
          },
          [STATIC]: ["", ""],
        },
        markingSink(),
      );

      const [initialCallerId] = callerIDs(rendered.toString().buffer);

      rendered.mergeDiff({
        [COMPONENTS]: { 1: { 1: "second" } },
      });
      const [unchangedCallerId] = callerIDs(
        rendered.componentToString(1).buffer,
      );
      expect(unchangedCallerId).toEqual(initialCallerId);

      rendered.mergeDiff({
        [COMPONENTS]: { 1: { 0: { 0: "updated" } } },
      });
      const [changedCallerId] = callerIDs(rendered.componentToString(1).buffer);
      expect(changedCallerId).not.toEqual(initialCallerId);
    });

    test("does not copy caller IDs when components share statics", () => {
      const rendered = new Rendered(
        "123",
        {
          0: 1,
          [COMPONENTS]: {
            1: {
              0: { [STATIC]: ["<span>child</span>"] },
              [STATIC]: [`<div>${callerAnnotation}`, "</div>"],
              r: 1,
            },
          },
          [STATIC]: ["", ""],
        },
        markingSink(),
      );

      const [firstCallerId] = callerIDs(rendered.toString().buffer);
      rendered.mergeDiff({
        [COMPONENTS]: { 2: { [STATIC]: -1 } },
      });
      const [secondCallerId] = callerIDs(rendered.componentToString(2).buffer);

      expect(secondCallerId).not.toEqual(firstCallerId);
    });

    test("does not copy caller IDs in keyed trees sharing statics", () => {
      const rendered = new Rendered(
        "123",
        {
          0: 1,
          [COMPONENTS]: {
            1: {
              0: {
                [KEYED]: {
                  0: {
                    0: { [STATIC]: ["<span>child</span>"] },
                  },
                  [KEYED_COUNT]: 1,
                },
                [STATIC]: [callerAnnotation, ""],
              },
              [STATIC]: ["<div>", "</div>"],
              r: 1,
            },
          },
          [STATIC]: ["", ""],
        },
        markingSink(),
      );

      const [firstCallerId] = callerIDs(rendered.toString().buffer);
      rendered.mergeDiff({
        [COMPONENTS]: {
          2: {
            0: { [KEYED]: { [KEYED_COUNT]: 1 } },
            [STATIC]: -1,
          },
        },
      });
      const [secondCallerId] = callerIDs(rendered.componentToString(2).buffer);

      expect(secondCallerId).not.toEqual(firstCallerId);
    });
  });
});

// A HEEx `@caller` annotation, which the server emits before a function
// component call when compiled with debug_heex_annotations.
const callerAnnotation = "<!-- @caller example.ex:1 (app) -->";

const DEBUG_ATTR = "phx-debug-id";
const CALL_SITE = /<!-- @caller [^>]* -->$/;

interface Span {
  node: any;
  index: number;
  callSite: boolean;
  start: number;
  // Children whose subtree the diff touched, and how many of those changed on
  // their own rather than only through a nested call site.
  changedChildren: number;
  contributingChildren: number;
}

// Reference sink, in the shape a debug tool would take. Core reports every
// dynamic and whether the diff touched it; recognising which of those are
// function component call sites, which spans are single elements, how to
// attribute a change and how to mark it are all decided here.
//
// Marks each call site with a two part id: the stable half identifies the call
// site instance for as long as it lives, the volatile half is bumped whenever
// it re-rendered with changes. Single element components carry it as an
// attribute, so they can be found with querySelector; anything else is
// bracketed with comments.
class MarkingSink extends StringSink {
  state: { nextId: number; bumps: Map<string, number> };
  stack: Span[] = [];
  // Deferred, so positions recorded while building stay valid.
  edits: { at: number; text: string }[] = [];
  // Spans endRoot told us are a single element: start -> end.
  roots = new Map<number, number>();
  rootStack: number[] = [];

  constructor(state: { nextId: number; bumps: Map<string, number> }) {
    super();
    this.state = state;
  }

  enter(node: any, index: number, statics: string[]) {
    this.stack.push({
      node,
      index,
      callSite: CALL_SITE.test(statics[index]),
      start: this.length,
      changedChildren: 0,
      contributingChildren: 0,
    });
  }

  exit(changed: boolean) {
    const span = this.stack.pop()!;
    // Core reports a change at every level on the way up. Attribute it to the
    // innermost call site: this span only counts as changed on its own if
    // nothing below it changed (so the change is its own dynamics, its
    // statics, or its comprehension), or if at least one child changed for a
    // reason other than a nested call site.
    const ownChange =
      changed && (span.changedChildren === 0 || span.contributingChildren > 0);

    const parent = this.stack[this.stack.length - 1];
    if (parent) {
      if (changed) parent.changedChildren++;
      // A call site absorbs its own change rather than passing it on.
      if (ownChange && !span.callSite) parent.contributingChildren++;
    }
    // Every call site carries a marker on every render; only the volatile
    // half moves, and only when this component itself re-rendered.
    if (span.callSite) this.mark(span, ownChange);
  }

  // Brackets a span that is a single element, which is how this sink knows an
  // attribute will land somewhere sensible. `length` stays continuous across
  // the pair, so recorded positions only need rebasing for what endRoot
  // rewrites.
  beginRoot() {
    this.rootStack.push(this.length);
    super.beginRoot();
  }

  endRoot(attrs: any, clearInnerHTML: boolean) {
    const start = this.rootStack.pop()!;
    const lengthBefore = this.length;
    super.endRoot(attrs, clearInnerHTML);
    this.roots.set(start, this.length);

    // Anything inside a cleared root went away with the content.
    if (clearInnerHTML) {
      this.edits = this.edits.filter(
        (e) => e.at <= start || e.at >= lengthBefore,
      );
    }
    const delta = this.length - lengthBefore;
    this.edits.forEach((e) => {
      if (e.at > start) e.at += delta;
    });
    this.stack.forEach((s) => {
      if (s.start > start) s.start += delta;
    });
  }

  toString(): string {
    let html = this.html;
    // Right to left, so the offsets still to be applied stay valid.
    [...this.edits]
      .sort((a, b) => b.at - a.at)
      .forEach(({ at, text }) => {
        html = html.slice(0, at) + text + html.slice(at);
      });
    return html;
  }

  private mark(span: Span, changed: boolean) {
    const id = this.idFor(span);
    const previous = this.state.bumps.get(id);
    const bump = previous === undefined ? 0 : changed ? previous + 1 : previous;
    this.state.bumps.set(id, bump);
    const value = `${id}:${bump}`;

    const tagNameEnd =
      this.roots.get(span.start) === this.length
        ? this.tagNameEnd(span.start)
        : -1;
    if (tagNameEnd !== -1) {
      this.edits.push({ at: tagNameEnd, text: ` ${DEBUG_ATTR}="${value}"` });
    } else {
      this.edits.push({
        at: span.start,
        text: `<!-- ${DEBUG_ATTR}-${value} -->`,
      });
      this.edits.push({
        at: this.length,
        text: `<!-- /${DEBUG_ATTR}-${id} -->`,
      });
    }
  }

  // Offset just past the start tag's name, skipping any leading comments.
  private tagNameEnd(from: number): number {
    const html = this.html;
    let i = from;
    while (i < html.length) {
      if (html.startsWith("<!--", i)) {
        const close = html.indexOf("-->", i);
        if (close === -1) return -1;
        i = close + 3;
      } else if (html[i] === "<") {
        i++;
        while (i < html.length && !/[\s/>]/.test(html[i])) i++;
        return i;
      } else if (/\s/.test(html[i])) {
        i++;
      } else {
        return -1;
      }
    }
    return -1;
  }

  private idFor(span: Span): string {
    const state = (span.node[SINK_STATE] = span.node[SINK_STATE] || {});
    if (!state[span.index]) {
      state[span.index] = `c${++this.state.nextId}`;
    }
    return state[span.index];
  }
}

// One id counter and bump table per Rendered, shared by the sinks it creates.
const markingSink = () => {
  const state = { nextId: 0, bumps: new Map<string, number>() };
  return () => new MarkingSink(state);
};

// Both forms: `phx-debug-id="c1:0"` and `<!-- phx-debug-id-c1:0 -->`, skipping
// the closing `<!-- /phx-debug-id-c1 -->`.
const callerIDs = (html: string): string[] =>
  Array.from(
    html.matchAll(new RegExp(`(?<!/)${DEBUG_ATTR}[-=]"?([^"\\s]+)`, "g")),
    (match) => match[1],
  );

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

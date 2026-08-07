import {
  RenderingBuffer,
  ReportingBuffer,
  type BufferFrame,
} from "phoenix_live_view/rendered/buffer";
import {
  STATIC,
  KEYED,
  KEYED_COUNT,
  COMPONENTS,
} from "phoenix_live_view/constants";

// Drives a buffer the way the renderer does, so these test the contract the
// renderer relies on rather than the renderer itself.
class RecordingBuffer extends ReportingBuffer {
  seen: BufferFrame[] = [];

  onExit(frame: BufferFrame) {
    this.seen.push(frame);
  }
}

// A buffer for one subtree, built the way the renderer builds it once `diff`
// has merged. No diff at all is a join, or a class installed since the last
// merge: either way there is nothing to compare the render against.
const recording = (diff?: any, cid: number | null = null): RecordingBuffer =>
  new RecordingBuffer(
    diff === undefined ? undefined : RecordingBuffer.preMerge(diff),
    cid,
  );

const enterExit = (
  buffer: ReportingBuffer,
  node: any,
  index: number,
  statics: string[] = ["", ""],
) => {
  buffer.enter(node, index, statics);
  buffer.exit();
};

// Whether the buffer reported the dynamic at `index` as touched by the patch.
const changedAt = (buffer: RecordingBuffer, index: number): boolean => {
  enterExit(buffer, { [index]: "value" }, index);
  return buffer.seen[buffer.seen.length - 1].changed;
};

describe("RenderingBuffer", () => {
  test("keeps nothing of a merge, so the renderer never copies a diff", () => {
    // The renderer only calls preMerge where a class defines one, which is
    // what keeps the default free of the clone ReportingBuffer pays for.
    expect(RenderingBuffer.preMerge).toBeUndefined();
  });

  test("accumulates writes", () => {
    const buffer = new RenderingBuffer(undefined, null);
    buffer.write("<div>");
    buffer.write("body");
    buffer.write("</div>");

    expect(buffer.toString()).toEqual("<div>body</div>");
    expect(buffer.length).toEqual("<div>body</div>".length);
  });

  test("adds attributes to the start tag of a bracketed root", () => {
    const buffer = new RenderingBuffer(undefined, null);
    buffer.write("before");
    buffer.beginRoot();
    buffer.write("<div class='x'>body</div>");
    buffer.endRoot({ "data-phx-id": "m1" });

    expect(buffer.toString()).toEqual(
      `before<div data-phx-id="m1" class='x'>body</div>`,
    );
  });

  test("discards the contents of a cleared root, keeping its id", () => {
    const buffer = new RenderingBuffer(undefined, null);
    buffer.beginRoot();
    buffer.write(`<div id="keep" class="x">body</div>`);
    buffer.endRoot({ "data-phx-skip": true }, true);

    expect(buffer.toString()).toEqual(`<div id="keep" data-phx-skip></div>`);
  });

  test("keeps length continuous across a root, including nested ones", () => {
    const buffer = new RenderingBuffer(undefined, null);
    buffer.write("ab");
    expect(buffer.length).toEqual(2);

    buffer.beginRoot();
    buffer.write("<div>");
    // Everything written so far counts, not just the pending root.
    expect(buffer.length).toEqual(2 + "<div>".length);

    buffer.beginRoot();
    buffer.write("<span>x</span>");
    buffer.endRoot({});
    buffer.write("</div>");
    buffer.endRoot({});

    expect(buffer.length).toEqual(buffer.toString().length);
    expect(buffer.toString()).toEqual("ab<div><span>x</span></div>");
  });

  test("takes the bracketing calls and does nothing with them", () => {
    // The renderer makes them where a buffer reports changes; the plain buffer
    // has nothing to report to.
    const buffer = new RenderingBuffer(undefined, null);
    buffer.beginKeyedEntry(0);
    buffer.enter({ 0: "a" }, 0, ["", ""]);
    buffer.exit();
    buffer.endKeyedEntry();

    expect(buffer.toString()).toEqual("");
  });
});

describe("ReportingBuffer", () => {
  describe("preMerge", () => {
    test("a subclass inherits it without restating it", () => {
      // The class is the only identity a buffer has, so what the renderer
      // reads off it has to survive subclassing.
      class MyBuffer extends ReportingBuffer {}
      expect(MyBuffer.preMerge({ 0: "a" })).toEqual({ 0: "a" });
    });

    test("keeps the diff whole, components and all", () => {
      const diff = { 0: "root", [COMPONENTS]: { 1: { 0: "component" } } };
      expect(ReportingBuffer.preMerge(diff)).toEqual(diff);
    });

    test("copies deeply, since the merge adopts and then mutates the diff", () => {
      const diff: any = { 0: { 1: "before" } };
      const preMerge = ReportingBuffer.preMerge(diff);

      diff[0][1] = "after";
      delete diff[0];

      expect(preMerge).toEqual({ 0: { 1: "before" } });
    });

    test("leaves the diff itself untouched, components included", () => {
      // The merge reads COMPONENTS off the diff after this runs.
      const diff: any = { 0: "root", [COMPONENTS]: { 1: { 0: "component" } } };
      ReportingBuffer.preMerge(diff);

      expect(diff).toEqual({
        0: "root",
        [COMPONENTS]: { 1: { 0: "component" } },
      });
    });
  });

  describe("cursors", () => {
    test("starts each buffer at the subtree it renders", () => {
      const preMerge = ReportingBuffer.preMerge({
        0: "root",
        [COMPONENTS]: { 1: { 1: "component" } },
      });

      const root = new RecordingBuffer(preMerge, null);
      const component = new RecordingBuffer(preMerge, 1);

      // Each buffer sees only its own subtree of the diff: the root diff
      // touched dynamic 0, the component diff dynamic 1.
      expect([changedAt(root, 0), changedAt(root, 1)]).toEqual([true, false]);
      expect([changedAt(component, 0), changedAt(component, 1)]).toEqual([
        false,
        true,
      ]);
    });

    test("hands every buffer of one merge the same components", () => {
      // One render builds a buffer per subtree from a single preMerge result,
      // so a buffer may not consume what it is given: the component buffer
      // here is built after the root one and still has to find its diff.
      const preMerge = ReportingBuffer.preMerge({
        [COMPONENTS]: { 1: { 0: "component" } },
      });

      new RecordingBuffer(preMerge, null);
      const second = new RecordingBuffer(preMerge, 1);

      expect(changedAt(second, 0)).toBe(true);
    });

    test("has no cursor for a component the diff did not carry", () => {
      const preMerge = ReportingBuffer.preMerge({ 0: "root" });
      expect(changedAt(new RecordingBuffer(preMerge, 2), 0)).toBe(false);
    });
  });

  describe("frames", () => {
    test("carries the node, index and statics of the dynamic", () => {
      const buffer = recording({ 1: "changed" });
      const node = { 0: "a", 1: "b" };
      const statics = ["<i>", "|", "</i>"];

      enterExit(buffer, node, 1, statics);

      expect(buffer.seen).toHaveLength(1);
      expect(buffer.seen[0]).toMatchObject({ node, index: 1, statics });
    });

    test("reports changed only where the diff carried something", () => {
      const buffer = recording({ 1: "changed" });
      const node = { 0: "a", 1: "b" };

      enterExit(buffer, node, 0);
      enterExit(buffer, node, 1);

      expect(buffer.seen.map((f) => f.changed)).toEqual([false, true]);
    });

    test("reports nothing as changed when there is no diff", () => {
      const buffer = recording();
      enterExit(buffer, { 0: "a" }, 0);
      expect(buffer.seen[0].changed).toBe(false);
    });

    test("reports a falsy but present diff value as changed", () => {
      const buffer = recording({ 0: "" });
      enterExit(buffer, { 0: "a" }, 0);
      expect(buffer.seen[0].changed).toBe(true);
    });

    test("descends the diff alongside the tree", () => {
      const buffer = recording({ 0: { 1: "changed" } });
      const node = { 0: { 0: "a", 1: "b" } };

      buffer.enter(node, 0, ["", ""]);
      enterExit(buffer, node[0], 0);
      enterExit(buffer, node[0], 1);
      buffer.exit();

      // Only the dynamic the diff named, and the one containing it. Innermost
      // exits first, so the enclosing dynamic is reported last.
      expect(buffer.seen.map((f) => f.changed)).toEqual([false, true, true]);
    });

    test("treats a subtree with new statics as changed throughout", () => {
      const replaced = { [STATIC]: ["<div>", "</div>"], 0: "x" };
      const buffer = recording({ 0: replaced });

      // Everything below a static replacement is new, so every position
      // counts as changed even though the diff names none of them.
      buffer.enter({ 0: replaced }, 0, ["", ""]);
      enterExit(buffer, replaced, 0);
      enterExit(buffer, replaced, 1);
      buffer.exit();

      expect(buffer.seen.map((f) => f.changed)).toEqual([true, true, true]);
    });

    test("state a subclass hangs on a frame survives to onExit", () => {
      class Stateful extends ReportingBuffer {
        depths: number[] = [];
        onEnter(frame: BufferFrame) {
          frame.mark = this.frames.length;
        }
        onExit(frame: BufferFrame) {
          this.depths.push(frame.mark);
        }
      }
      const buffer = new Stateful(undefined, null);
      const node = { 0: "a" };

      buffer.enter(node, 0, ["", ""]);
      buffer.enter(node, 0, ["", ""]);
      buffer.exit();
      buffer.exit();

      // Innermost exits first, and each frame kept its own depth.
      expect(buffer.depths).toEqual([2, 1]);
    });
  });

  describe("keyed entries", () => {
    const comprehension = (entries: any) => ({ [KEYED]: entries });

    // Opens entry `index` of a comprehension at the root of the buffer and
    // reports whether its first dynamic was touched.
    const entryChanged = (buffer: RecordingBuffer, index: number): boolean => {
      buffer.beginKeyedEntry(index);
      enterExit(buffer, { 0: "a" }, 0);
      buffer.endKeyedEntry();
      return buffer.seen[buffer.seen.length - 1].changed;
    };

    test("descends into the diff of an entry at a stable position", () => {
      const buffer = recording(
        comprehension({ 0: { 0: "updated" }, [KEYED_COUNT]: 2 }),
      );
      expect([entryChanged(buffer, 0), entryChanged(buffer, 1)]).toEqual([
        true,
        false,
      ]);
    });

    test("unwraps the diff of an entry that moved with one", () => {
      const buffer = recording(comprehension({ 0: [1, { 0: "updated" }] }));
      expect(entryChanged(buffer, 0)).toBe(true);
    });

    test("reports no content change for an entry that only moved", () => {
      // A bare index means "moved from there, unchanged"; the move itself is a
      // change of the comprehension, not of anything inside the entry.
      const buffer = recording(comprehension({ 0: 1 }));
      expect(entryChanged(buffer, 0)).toBe(false);
    });

    test("reports no change for an untouched comprehension", () => {
      const buffer = recording();
      expect(entryChanged(buffer, 0)).toBe(false);
    });

    test("treats every entry of a restatic'd comprehension as new", () => {
      const buffer = recording({ [STATIC]: ["<li>", "</li>"], [KEYED]: {} });
      expect(entryChanged(buffer, 0)).toBe(true);
    });

    test("leaves the surrounding cursor intact", () => {
      const buffer = recording({
        0: { [KEYED]: { 0: { 0: "x" } } },
        1: "also",
      });
      const node = { 0: {}, 1: "b" };

      buffer.enter(node, 0, ["", ""]);
      expect(entryChanged(buffer, 0)).toBe(true);
      buffer.exit();
      // Back out at the level above, where dynamic 1 also changed.
      enterExit(buffer, node, 1);

      expect(buffer.seen[buffer.seen.length - 1].changed).toBe(true);
    });
  });
});

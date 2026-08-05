import {
  Sink,
  OutputBuffer,
  ReportingSink,
  ReportingOutputBuffer,
  SINK_STATE,
  type SinkFrame,
} from "phoenix_live_view/rendered/sink";
import {
  STATIC,
  KEYED,
  KEYED_COUNT,
  COMPONENTS,
} from "phoenix_live_view/constants";

describe("Sink", () => {
  test("reports no changes, so the renderer skips that machinery", () => {
    expect(new Sink().reportsChanges).toBe(false);
  });

  test("keeps nothing from a merge and hands out plain buffers", () => {
    const sink = new Sink();
    sink.preMerge({ 0: "a" });

    expect(sink.cursorFor(null)).toBeUndefined();
    expect(sink.cursorFor(1)).toBeUndefined();
    expect(sink.new(null)).toBeInstanceOf(OutputBuffer);
  });
});

describe("OutputBuffer", () => {
  test("accumulates writes", () => {
    const buffer = new OutputBuffer();
    buffer.write("<div>");
    buffer.write("body");
    buffer.write("</div>");

    expect(buffer.toString()).toEqual("<div>body</div>");
    expect(buffer.length).toEqual("<div>body</div>".length);
  });

  test("adds attributes to the start tag of a bracketed root", () => {
    const buffer = new OutputBuffer();
    buffer.write("before");
    buffer.beginRoot();
    buffer.write("<div class='x'>body</div>");
    buffer.endRoot({ "data-phx-id": "m1" });

    expect(buffer.toString()).toEqual(
      `before<div data-phx-id="m1" class='x'>body</div>`,
    );
  });

  test("discards the contents of a cleared root, keeping its id", () => {
    const buffer = new OutputBuffer();
    buffer.beginRoot();
    buffer.write(`<div id="keep" class="x">body</div>`);
    buffer.endRoot({ "data-phx-skip": true }, true);

    expect(buffer.toString()).toEqual(`<div id="keep" data-phx-skip></div>`);
  });

  test("keeps length continuous across a root, including nested ones", () => {
    const buffer = new OutputBuffer();
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

  test("reports nothing to a sink that does not ask for it", () => {
    const buffer = new OutputBuffer();
    expect(buffer.enter(undefined, {}, 0, ["", ""])).toBeUndefined();
    expect(buffer.keyedEntry(undefined, 0)).toBeUndefined();
    expect(() => buffer.exit()).not.toThrow();
  });
});

describe("ReportingSink", () => {
  test("reports changes, unlike the plain sink", () => {
    expect(new ReportingSink().reportsChanges).toBe(true);
  });

  test("is not shadowed by the base class declaring it", () => {
    // Sink declares reportsChanges too. Were it a field rather than a getter it
    // would define an own property on construction and shadow this one,
    // silently turning reporting off for every sink.
    expect(
      Object.prototype.hasOwnProperty.call(
        new ReportingSink(),
        "reportsChanges",
      ),
    ).toBe(false);
  });

  test("has no cursor before the first merge", () => {
    // A join, or a sink attached to a tree that is already rendered: there is
    // nothing to compare the next render against.
    const sink = new ReportingSink();
    expect(sink.cursorFor(null)).toBeUndefined();
    expect(sink.cursorFor(1)).toBeUndefined();
  });

  test("keeps a copy of the merged diff, split by component", () => {
    const sink = new ReportingSink();
    sink.preMerge({ 0: "root", [COMPONENTS]: { 1: { 0: "component" } } });

    expect(sink.cursorFor(null)).toEqual({ 0: "root" });
    expect(sink.cursorFor(1)).toEqual({ 0: "component" });
    expect(sink.cursorFor(2)).toBeUndefined();
  });

  test("copies deeply, since the merge adopts and then mutates the diff", () => {
    const sink = new ReportingSink();
    const diff: any = { 0: { 1: "before" } };
    sink.preMerge(diff);

    diff[0][1] = "after";
    delete diff[0];

    expect(sink.cursorFor(null)).toEqual({ 0: { 1: "before" } });
  });

  test("replaces the cursor on every merge", () => {
    const sink = new ReportingSink();
    sink.preMerge({ 0: "first" });
    sink.preMerge({ 1: "second" });

    expect(sink.cursorFor(null)).toEqual({ 1: "second" });
  });

  test("hands each buffer the cursor for the subtree it renders", () => {
    const sink = new ReportingSink();
    sink.preMerge({ 0: "root", [COMPONENTS]: { 1: { 0: "component" } } });

    const root = sink.new(null);
    const component = sink.new(1);

    expect(root).toBeInstanceOf(ReportingOutputBuffer);
    expect(root.sink).toBe(sink);
    // The cursor decides what the buffer reports as changed.
    expect(root.enter(sink.cursorFor(null), {}, 0, ["", ""])).toEqual("root");
    expect(component.enter(sink.cursorFor(1), {}, 0, ["", ""])).toEqual(
      "component",
    );
  });
});

describe("ReportingOutputBuffer", () => {
  // Drives a buffer the way the renderer does, so these test the contract the
  // renderer relies on rather than the renderer itself.
  class RecordingBuffer extends ReportingOutputBuffer {
    seen: SinkFrame[] = [];

    onExit(frame: SinkFrame) {
      this.seen.push(frame);
    }
  }

  const recording = () => new RecordingBuffer(new ReportingSink(), null);
  const reporting = () => new ReportingOutputBuffer(new ReportingSink(), null);

  const enterExit = (
    buffer: ReportingOutputBuffer,
    parentDiff: any,
    node: any,
    index: number,
    statics: string[] = ["", ""],
  ) => {
    const childDiff = buffer.enter(parentDiff, node, index, statics);
    buffer.exit();
    return childDiff;
  };

  describe("frames", () => {
    test("carries the node, index and statics of the dynamic", () => {
      const buffer = recording();
      const node = { 0: "a", 1: "b" };
      const statics = ["<i>", "|", "</i>"];

      enterExit(buffer, { 1: "changed" }, node, 1, statics);

      expect(buffer.seen).toHaveLength(1);
      expect(buffer.seen[0]).toMatchObject({ node, index: 1, statics });
    });

    test("reports changed only where the diff carried something", () => {
      const buffer = recording();
      const node = { 0: "a", 1: "b" };

      enterExit(buffer, { 1: "changed" }, node, 0);
      enterExit(buffer, { 1: "changed" }, node, 1);

      expect(buffer.seen.map((f) => f.changed)).toEqual([false, true]);
    });

    test("reports nothing as changed when there is no diff", () => {
      const buffer = recording();
      enterExit(buffer, undefined, { 0: "a" }, 0);
      expect(buffer.seen[0].changed).toBe(false);
    });

    test("reports a falsy but present diff value as changed", () => {
      const buffer = recording();
      enterExit(buffer, { 0: "" }, { 0: "a" }, 0);
      expect(buffer.seen[0].changed).toBe(true);
    });

    test("treats a subtree with new statics as changed throughout", () => {
      const buffer = recording();
      const replaced = { [STATIC]: ["<div>", "</div>"], 0: "x" };

      // Everything below a static replacement is new, so every position
      // counts as changed even though the diff names none of them.
      const child = buffer.enter({ 0: replaced }, { 0: replaced }, 0, ["", ""]);
      enterExit(buffer, child, replaced, 0);
      enterExit(buffer, child, replaced, 1);
      buffer.exit();

      expect(buffer.seen.map((f) => f.changed)).toEqual([true, true, true]);
    });

    test("state a subclass hangs on a frame survives to onExit", () => {
      class Stateful extends ReportingOutputBuffer {
        depths: number[] = [];
        onEnter(frame: SinkFrame) {
          frame.mark = this.frames.length;
        }
        onExit(frame: SinkFrame) {
          this.depths.push(frame.mark);
        }
      }
      const buffer = new Stateful(new ReportingSink(), null);
      const node = { 0: "a" };

      buffer.enter(undefined, node, 0, ["", ""]);
      buffer.enter(undefined, node, 0, ["", ""]);
      buffer.exit();
      buffer.exit();

      // Innermost exits first, and each frame kept its own depth.
      expect(buffer.depths).toEqual([2, 1]);
    });
  });

  describe("keyedEntry", () => {
    const comprehension = (entries: any) => ({ [KEYED]: entries });

    test("returns the diff of an entry at a stable position", () => {
      const buffer = reporting();
      const diff = comprehension({ 0: { 0: "updated" }, [KEYED_COUNT]: 2 });
      expect(buffer.keyedEntry(diff, 0)).toEqual({ 0: "updated" });
    });

    test("unwraps the diff of an entry that moved with one", () => {
      const buffer = reporting();
      const diff = comprehension({ 0: [1, { 0: "updated" }] });
      expect(buffer.keyedEntry(diff, 0)).toEqual({ 0: "updated" });
    });

    test("reports no content change for an entry that only moved", () => {
      const buffer = reporting();
      // A bare index means "moved from there, unchanged"; the move itself is a
      // change of the comprehension, not of anything inside the entry.
      expect(buffer.keyedEntry(comprehension({ 0: 1 }), 0)).toBeUndefined();
    });

    test("reports no change for an untouched entry or comprehension", () => {
      const buffer = reporting();
      expect(
        buffer.keyedEntry(comprehension({ 1: { 0: "x" } }), 0),
      ).toBeUndefined();
      expect(buffer.keyedEntry(undefined, 0)).toBeUndefined();
    });

    test("treats every entry of a restatic'd comprehension as new", () => {
      const buffer = recording();
      const diff = { [STATIC]: ["<li>", "</li>"], [KEYED]: {} };

      const entry = buffer.keyedEntry(diff, 0);
      enterExit(buffer, entry, { 0: "a" }, 0);

      expect(buffer.seen[0].changed).toBe(true);
    });
  });

  test("SINK_STATE is the key reserved for per-node state", () => {
    const node: any = {};
    node[SINK_STATE] = { 0: "id" };
    expect(node.sinkState).toEqual({ 0: "id" });
  });
});

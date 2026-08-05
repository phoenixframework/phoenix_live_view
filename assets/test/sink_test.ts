import {
  ReportingSink,
  StringSink,
  SINK_STATE,
  type SinkFrame,
} from "phoenix_live_view/rendered/sink";
import { STATIC, KEYED, KEYED_COUNT } from "phoenix_live_view/constants";

describe("StringSink", () => {
  test("reports no changes, so the renderer skips that machinery", () => {
    expect(new StringSink().reportsChanges).toBe(false);
  });

  test("accumulates writes", () => {
    const sink = new StringSink();
    sink.write("<div>");
    sink.write("body");
    sink.write("</div>");

    expect(sink.toString()).toEqual("<div>body</div>");
    expect(sink.length).toEqual("<div>body</div>".length);
  });

  test("adds attributes to the start tag of a bracketed root", () => {
    const sink = new StringSink();
    sink.write("before");
    sink.beginRoot();
    sink.write("<div class='x'>body</div>");
    sink.endRoot({ "data-phx-id": "m1" });

    expect(sink.toString()).toEqual(
      `before<div data-phx-id="m1" class='x'>body</div>`,
    );
  });

  test("discards the contents of a cleared root, keeping its id", () => {
    const sink = new StringSink();
    sink.beginRoot();
    sink.write(`<div id="keep" class="x">body</div>`);
    sink.endRoot({ "data-phx-skip": true }, true);

    expect(sink.toString()).toEqual(`<div id="keep" data-phx-skip></div>`);
  });

  test("keeps length continuous across a root, including nested ones", () => {
    const sink = new StringSink();
    sink.write("ab");
    expect(sink.length).toEqual(2);

    sink.beginRoot();
    sink.write("<div>");
    // Everything written so far counts, not just the pending root.
    expect(sink.length).toEqual(2 + "<div>".length);

    sink.beginRoot();
    sink.write("<span>x</span>");
    sink.endRoot({});
    sink.write("</div>");
    sink.endRoot({});

    expect(sink.length).toEqual(sink.toString().length);
    expect(sink.toString()).toEqual("ab<div><span>x</span></div>");
  });
});

describe("ReportingSink", () => {
  // Drives a sink the way the renderer does, so these test the contract the
  // renderer relies on rather than the renderer itself.
  class RecordingSink extends ReportingSink {
    seen: SinkFrame[] = [];

    onExit(frame: SinkFrame) {
      this.seen.push(frame);
    }
  }

  const enterExit = (
    sink: ReportingSink,
    parentDiff: any,
    node: any,
    index: number,
    statics: string[] = ["", ""],
  ) => {
    const childDiff = sink.enter(parentDiff, node, index, statics);
    sink.exit();
    return childDiff;
  };

  describe("reportsChanges", () => {
    test("is false when neither hook is overridden", () => {
      expect(new ReportingSink().reportsChanges).toBe(false);
      class Passive extends ReportingSink {}
      expect(new Passive().reportsChanges).toBe(false);
    });

    test("is not shadowed by the base class declaring it", () => {
      // StringSink declares reportsChanges too. Were it a field rather than a
      // getter it would define an own property on construction and shadow this
      // one, silently turning reporting off for every sink.
      class Reporting extends ReportingSink {
        onExit(_frame: SinkFrame) {}
      }
      expect(
        Object.prototype.hasOwnProperty.call(new Reporting(), "reportsChanges"),
      ).toBe(false);
      expect(new Reporting().reportsChanges).toBe(true);
    });

    test("is true when either hook is overridden", () => {
      class OnlyEnter extends ReportingSink {
        onEnter(_frame: SinkFrame) {}
      }
      class OnlyExit extends ReportingSink {
        onExit(_frame: SinkFrame) {}
      }
      expect(new OnlyEnter().reportsChanges).toBe(true);
      expect(new OnlyExit().reportsChanges).toBe(true);
    });

    test("is true for a hook assigned on the instance", () => {
      const sink = new ReportingSink();
      expect(sink.reportsChanges).toBe(false);
      sink.onExit = () => {};
      expect(sink.reportsChanges).toBe(true);
    });
  });

  describe("frames", () => {
    test("carries the node, index and statics of the dynamic", () => {
      const sink = new RecordingSink();
      const node = { 0: "a", 1: "b" };
      const statics = ["<i>", "|", "</i>"];

      enterExit(sink, { 1: "changed" }, node, 1, statics);

      expect(sink.seen).toHaveLength(1);
      expect(sink.seen[0]).toMatchObject({ node, index: 1, statics });
    });

    test("reports changed only where the diff carried something", () => {
      const sink = new RecordingSink();
      const node = { 0: "a", 1: "b" };

      enterExit(sink, { 1: "changed" }, node, 0);
      enterExit(sink, { 1: "changed" }, node, 1);

      expect(sink.seen.map((f) => f.changed)).toEqual([false, true]);
    });

    test("reports nothing as changed when there is no diff", () => {
      const sink = new RecordingSink();
      enterExit(sink, undefined, { 0: "a" }, 0);
      expect(sink.seen[0].changed).toBe(false);
    });

    test("reports a falsy but present diff value as changed", () => {
      const sink = new RecordingSink();
      enterExit(sink, { 0: "" }, { 0: "a" }, 0);
      expect(sink.seen[0].changed).toBe(true);
    });

    test("treats a subtree with new statics as changed throughout", () => {
      const sink = new RecordingSink();
      const replaced = { [STATIC]: ["<div>", "</div>"], 0: "x" };

      // Everything below a static replacement is new, so every position
      // counts as changed even though the diff names none of them.
      const child = sink.enter({ 0: replaced }, { 0: replaced }, 0, ["", ""]);
      enterExit(sink, child, replaced, 0);
      enterExit(sink, child, replaced, 1);
      sink.exit();

      expect(sink.seen.map((f) => f.changed)).toEqual([true, true, true]);
    });

    test("state a subclass hangs on a frame survives to onExit", () => {
      class Stateful extends ReportingSink {
        depths: number[] = [];
        onEnter(frame: SinkFrame) {
          frame.mark = this.frames.length;
        }
        onExit(frame: SinkFrame) {
          this.depths.push(frame.mark);
        }
      }
      const sink = new Stateful();
      const node = { 0: "a" };

      sink.enter(undefined, node, 0, ["", ""]);
      sink.enter(undefined, node, 0, ["", ""]);
      sink.exit();
      sink.exit();

      // Innermost exits first, and each frame kept its own depth.
      expect(sink.depths).toEqual([2, 1]);
    });
  });

  describe("keyedEntry", () => {
    const comprehension = (entries: any) => ({ [KEYED]: entries });

    test("returns the diff of an entry at a stable position", () => {
      const sink = new ReportingSink();
      const diff = comprehension({ 0: { 0: "updated" }, [KEYED_COUNT]: 2 });
      expect(sink.keyedEntry(diff, 0)).toEqual({ 0: "updated" });
    });

    test("unwraps the diff of an entry that moved with one", () => {
      const sink = new ReportingSink();
      const diff = comprehension({ 0: [1, { 0: "updated" }] });
      expect(sink.keyedEntry(diff, 0)).toEqual({ 0: "updated" });
    });

    test("reports no content change for an entry that only moved", () => {
      const sink = new ReportingSink();
      // A bare index means "moved from there, unchanged"; the move itself is a
      // change of the comprehension, not of anything inside the entry.
      expect(sink.keyedEntry(comprehension({ 0: 1 }), 0)).toBeUndefined();
    });

    test("reports no change for an untouched entry or comprehension", () => {
      const sink = new ReportingSink();
      expect(
        sink.keyedEntry(comprehension({ 1: { 0: "x" } }), 0),
      ).toBeUndefined();
      expect(sink.keyedEntry(undefined, 0)).toBeUndefined();
    });

    test("treats every entry of a restatic'd comprehension as new", () => {
      const sink = new RecordingSink();
      const diff = { [STATIC]: ["<li>", "</li>"], [KEYED]: {} };

      const entry = sink.keyedEntry(diff, 0);
      enterExit(sink, entry, { 0: "a" }, 0);

      expect(sink.seen[0].changed).toBe(true);
    });
  });

  test("storeDiff is how a render announces its cursor", () => {
    const seen: any[] = [];
    class Resetting extends ReportingSink {
      storeDiff(diff: any) {
        seen.push(diff);
        super.storeDiff(diff);
      }
      onExit(_frame: SinkFrame) {}
    }
    const sink = new Resetting();
    sink.storeDiff(undefined);
    sink.storeDiff({ 0: "a" });

    // undefined means a render with nothing to compare against: a join, or the
    // first render after this sink was attached.
    expect(seen).toEqual([undefined, { 0: "a" }]);
  });

  test("SINK_STATE is the key reserved for per-node state", () => {
    const node: any = {};
    node[SINK_STATE] = { 0: "id" };
    expect(node.sinkState).toEqual({ 0: "id" });
  });
});

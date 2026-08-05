import { Socket } from "phoenix";
import Rendered from "phoenix_live_view/rendered";
import LiveSocket from "phoenix_live_view/live_socket";
import View from "phoenix_live_view/view";
import {
  ReportingSink,
  ReportingOutputBuffer,
  SINK_STATE,
} from "phoenix_live_view/rendered/sink";
import {
  STATIC,
  COMPONENTS,
  KEYED,
  KEYED_COUNT,
  KEYED_MOVED,
} from "phoenix_live_view/constants";
import { version as liveview_version } from "../../../package.json";
import { liveViewDOM, stubChannel } from "../test_helpers";

describe("MarkingSink", () => {
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

  test("rotates the caller ID for a static-only subtree replacement", () => {
    const rendered = new Rendered(
      "123",
      {
        0: { [STATIC]: ["<span>old</span>"] },
        [STATIC]: [callerAnnotation, ""],
      },
      markingSink(),
    );

    const [initialCallerId] = callerIDs(rendered.toString().buffer);

    rendered.mergeDiff({
      0: { [STATIC]: ["<div>new</div>"] },
    });
    const { buffer } = rendered.toString();
    const [changedCallerId] = callerIDs(buffer);

    expect(buffer).toContain("<div>new</div>");
    expect(changedCallerId).not.toEqual(initialCallerId);
    expect(changedCallerId.split(":")[0]).toEqual(
      initialCallerId.split(":")[0],
    );
  });

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

  test("drops markers recorded inside a root that was then skipped", () => {
    // A single root function component with a call site inside it. Once it has
    // rendered, a patch that leaves it alone lets LiveView skip it: the
    // subtree is still walked, but the result is thrown away and the DOM keeps
    // what it has. Anything the sink recorded during that walk points at
    // content that never ships.
    const rendered = new Rendered(
      "123",
      {
        0: {
          0: { 0: "inner", [STATIC]: ["<em>", "</em>"] },
          [STATIC]: [`<div id="o">${callerAnnotation}`, "</div>"],
          r: 1,
        },
        [STATIC]: ["", ""],
      },
      markingSink(),
    );

    const first = rendered.toString().buffer;
    expect(first).toContain("<em>inner</em>");
    expect(callerIDs(first)).toHaveLength(1);

    const second = rendered.toString().buffer;

    expect(second).toContain("data-phx-skip");
    expect(second).not.toContain("<em>");
    // The marker for the call site inside went with the discarded content,
    // rather than being emitted at an offset that no longer means anything.
    expect(callerIDs(second)).toEqual([]);
    expect(second).not.toContain(DEBUG_ATTR);
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
    const [unchangedCallerId] = callerIDs(rendered.componentToString(1).buffer);
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

describe("MarkingSink in the DOM", () => {
  let liveSocket;

  afterEach(() => {
    liveSocket?.destroyAllViews();
  });

  test("marks function components on the elements they rendered", () => {
    liveSocket = new LiveSocket("/live", Socket);
    // attachDebugSink is a debug API and requires debugging to be on.
    liveSocket.enableDebug();
    const consoleLog = jest.spyOn(console, "log").mockImplementation(() => {});

    const view = new View(liveViewDOM(), liveSocket, null, null, null);
    stubChannel(view);
    liveSocket.roots[view.id] = view;
    view.isConnected = () => true;

    view.onJoin({
      rendered: {
        0: { 0: "child", s: ["<span>", "</span>"], r: 1 },
        1: "first",
        s: [callerAnnotation, "|", ""],
      },
      liveview_version,
    });

    const debugId = () =>
      view.el.querySelector(`[${DEBUG_ATTR}]`)?.getAttribute(DEBUG_ATTR);

    // Nothing is marked until a sink is attached.
    expect(debugId()).toBeUndefined();

    // Attaching re-renders the mounted view in full, so the sink sees all of
    // it rather than only what changes next.
    liveSocket.attachDebugSink(markingSink());
    const initial = debugId();
    expect(initial).toMatch(/:0$/);

    view.update({ 1: "second" }, []);
    expect(debugId()).toEqual(initial);

    // A non-empty child diff bumps the counter even when the value is equal,
    // while the stable half is preserved.
    view.update({ 0: { 0: "child" } }, []);
    expect(debugId()).not.toEqual(initial);
    expect(debugId()!.split(":")[0]).toEqual(initial!.split(":")[0]);

    // Clearing re-renders too, dropping what the sink had added.
    liveSocket.clearDebugSink();
    expect(debugId()).toBeUndefined();
    expect(view.el.innerHTML).toContain("child");

    consoleLog.mockRestore();
    liveSocket.disableDebug();
  });
});

// A HEEx `@caller` annotation, which the server emits before a function
// component call when compiled with debug_heex_annotations.
const callerAnnotation = "<!-- @caller example.ex:1 (app) -->";

const DEBUG_ATTR = "phx-debug-id";
const CALL_SITE = /<!-- @caller [^>]* -->$/;

// Reference sink, in the shape a debug tool would take. The base classes report
// every dynamic and whether the patch touched it; recognising which of those
// are function component call sites, which spans are single elements, how to
// attribute a change and how to mark it are all decided here.
//
// Marks each call site with a two part id: the stable half identifies the call
// site instance for as long as it lives, the volatile half is bumped whenever
// it re-rendered with changes. Single element components carry it as an
// attribute, so they can be found with querySelector; anything else is
// bracketed with comments.
//
// The sink is installed once per tree, so it holds everything that has to
// outlive a single render; the buffer it hands out per render holds the rest.
class MarkingSink extends ReportingSink {
  nextId = 0;
  bumps = new Map<string, number>();

  new(cid: number | null): MarkingBuffer {
    return new MarkingBuffer(this, cid);
  }
}

class MarkingBuffer extends ReportingOutputBuffer {
  declare readonly sink: MarkingSink;
  // Deferred, so positions recorded while building stay valid.
  edits: { at: number; text: string }[] = [];
  // Spans endRoot told us are a single element: start -> end.
  roots = new Map<number, number>();
  rootStack: number[] = [];

  onEnter(frame: any) {
    frame.callSite = CALL_SITE.test(frame.statics[frame.index]);
    frame.start = this.length;
    // Children whose subtree the patch touched, and how many of those changed
    // on their own rather than only through a nested call site.
    frame.changedChildren = 0;
    frame.contributingChildren = 0;
  }

  onExit(frame: any) {
    // A change is reported at every level on the way up. Attribute it to the
    // innermost call site: this span only counts as changed on its own if
    // nothing below it changed (so the change is its own dynamics, its
    // statics, or its comprehension), or if at least one child changed for a
    // reason other than a nested call site.
    const ownChange =
      frame.changed &&
      (frame.changedChildren === 0 || frame.contributingChildren > 0);

    const parent = this.frames[this.frames.length - 1] as any;
    if (parent) {
      if (frame.changed) parent.changedChildren++;
      // A call site absorbs its own change rather than passing it on.
      if (ownChange && !frame.callSite) parent.contributingChildren++;
    }
    // Every call site carries a marker on every render; only the volatile half
    // moves, and only when this component itself re-rendered.
    if (frame.callSite) this.mark(frame, ownChange);
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

    // The base rewrote the span [start, lengthBefore) in place, so every
    // position recorded inside it has moved. Two shapes, with real numbers:
    //
    //   attributes added to the start tag
    //     before  '<main><div>hi</div>'                start=6, end=19
    //     after   '<main><div data-phx-id="m1">hi</div>'      length=36
    //     'hi' was at 11, is now at 28: delta = 36 - 19 = +17, and every
    //     position past the root's start moves by it.
    //
    //   contents discarded too, when a root did not change and the DOM keeps
    //   what it already has
    //     before  '<main><div id="x">hi</div>'         start=6, end=26
    //     after   '<main><div id="x" data-phx-skip></div>'    length=38
    //     'hi' is gone. An edit pointing into it has nothing left to attach
    //     to, so it is dropped rather than shifted; only edits at or before
    //     the start, or at or after the old end, survive into the shift.
    if (clearInnerHTML) {
      this.edits = this.edits.filter(
        (e) => e.at <= start || e.at >= lengthBefore,
      );
    }
    const delta = this.length - lengthBefore;
    this.edits.forEach((e) => {
      // `> start`, not `>=`: an edit sitting exactly at the root's start goes
      // before the element and stays put.
      if (e.at > start) e.at += delta;
    });
    // Open frames need no rebasing. beginRoot/endRoot bracket the whole of
    // toOutputBuffer, so every frame opened inside this root has already
    // exited by now, and the frame that encloses the root recorded the same
    // offset `start` did.
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

  private mark(frame: any, changed: boolean) {
    const id = this.idFor(frame);
    const previous = this.sink.bumps.get(id);
    const bump = previous === undefined ? 0 : changed ? previous + 1 : previous;
    this.sink.bumps.set(id, bump);
    const value = `${id}:${bump}`;

    const tagNameEnd =
      this.roots.get(frame.start) === this.length
        ? this.tagNameEnd(frame.start)
        : -1;
    if (tagNameEnd !== -1) {
      this.edits.push({ at: tagNameEnd, text: ` ${DEBUG_ATTR}="${value}"` });
    } else {
      this.edits.push({
        at: frame.start,
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

  private idFor(frame: any): string {
    const state = (frame.node[SINK_STATE] = frame.node[SINK_STATE] || {});
    if (!state[frame.index]) {
      state[frame.index] = `c${++this.sink.nextId}`;
    }
    return state[frame.index];
  }
}

const markingSink = () => () => new MarkingSink();

// Both forms: `phx-debug-id="c1:0"` and `<!-- phx-debug-id-c1:0 -->`, skipping
// the closing `<!-- /phx-debug-id-c1 -->`.
const callerIDs = (html: string): string[] =>
  Array.from(
    html.matchAll(new RegExp(`(?<!/)${DEBUG_ATTR}[-=]"?([^"\\s]+)`, "g")),
    (match) => match[1],
  );

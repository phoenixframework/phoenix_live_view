import { COMPONENTS, KEYED, STATIC } from "../constants";
import { deepClone } from "../utils";
import { modifyRoot, type RootAttrs } from "./modify_root";

// Key reserved on rendered nodes for a sink to hang its own state on. It rides
// along with the node through diff merges.
export const SINK_STATE = "sinkState";

// A position in the diff the renderer is walking. Opaque: the renderer carries
// it from one `enter` back into the next without ever inspecting it, and only
// the reporting pair knows what is inside.
export type DiffCursor = any;

/**
 * What the renderer writes HTML through, for the life of a mounted view.
 *
 * A sink is installed once per {@link Rendered}. It is shown every diff before
 * it merges, and it hands out one {@link OutputBuffer} per subtree render — so
 * it is also where a sink keeps state that has to outlive a single render.
 * The sink itself is never written to.
 *
 * The default does nothing at all and buffers into a string. A tool can install
 * its own with `liveSocket.attachDebugSink` to observe or annotate the output;
 * to be told which parts of the page a patch touched, extend
 * {@link ReportingSink} rather than this class.
 *
 * @internal
 */
export class Sink {
  /**
   * Whether the renderer should report which parts of the page a patch
   * touched. False here, since a plain buffer has nothing to report it to;
   * {@link ReportingSink} overrides it.
   */
  get reportsChanges(): boolean {
    return false;
  }

  /**
   * Called before each diff merges into the rendered tree. Anything a sink
   * wants to keep from the diff has to be copied here: the merge adopts diff
   * subtrees into the tree and then mutates them.
   *
   * Not called for the join, which has no previous render to compare against.
   */
  preMerge(_diff: any): void {}

  /**
   * The cursor into the last diff for one subtree, where `cid` is null for the
   * root tree and a component id otherwise.
   */
  cursorFor(_cid: number | null): DiffCursor {
    return undefined;
  }

  /** A buffer for one subtree render. Same `cid` as {@link cursorFor}. */
  new(_cid: number | null): OutputBuffer {
    return new OutputBuffer();
  }
}

/**
 * The buffer one subtree render writes through. Created by {@link Sink.new},
 * written to by the renderer, and discarded once its HTML has been taken.
 *
 * @internal
 */
export class OutputBuffer {
  protected html = "";
  private pending: string[] = [];
  private base = 0;

  /**
   * Characters written so far. A sink that records positions brackets spans
   * with this.
   */
  get length(): number {
    return this.base + this.html.length;
  }

  write(str: string): void {
    this.html += str;
  }

  toString(): string {
    return this.html;
  }

  /**
   * Brackets a root element: everything written in between is a single
   * element, `attrs` are added to its start tag, and `clearInnerHTML`
   * additionally discards its contents (LiveView skips re-rendering a root
   * that did not change and reuses what is already in the DOM).
   *
   * The default isolates the element so it can rewrite it without touching
   * what came before. A buffer that records positions overrides both, keeping
   * it continuous and applying its edits at the end instead; `length` stays
   * continuous across the pair either way.
   */
  beginRoot(): void {
    this.pending.push(this.html);
    this.base += this.html.length;
    this.html = "";
  }

  endRoot(attrs: RootAttrs, clearInnerHTML?: boolean): void {
    const [root, before, after] = modifyRoot(this.html, attrs, clearInnerHTML);
    const prefix = this.pending.pop()!;
    this.base -= prefix.length;
    this.html = prefix + before + root + after;
  }

  /**
   * Brackets the dynamic at `statics[index]` of `node`, returning the cursor
   * for that dynamic, which the renderer passes back down. Only called when
   * the sink reports changes; see {@link ReportingOutputBuffer}.
   */
  enter(
    _parentDiff: DiffCursor,
    _node: any,
    _index: number,
    _statics: string[],
  ): DiffCursor {
    return undefined;
  }

  exit(): void {}

  /** The cursor for one entry of a keyed comprehension. */
  keyedEntry(_diffNode: DiffCursor, _index: number): DiffCursor {
    return undefined;
  }
}

// Sentinel cursor meaning "everything below here is new", used when a subtree
// arrives with fresh statics so there is nothing to compare it against.
const ALL_CHANGED = Symbol("all changed");

/**
 * What a sink is told about one dynamic of the rendered tree.
 *
 * Subclasses may hang their own state on a frame in `onEnter` and read it back
 * in `onExit`, which is why it carries an index signature.
 */
export interface SinkFrame {
  /** The rendered node holding the dynamic. */
  node: any;
  /** Which dynamic of that node, i.e. the gap after `statics[index]`. */
  index: number;
  /** The node's static segments, already resolved from any template. */
  statics: string[];
  /** Whether this patch touched anything at or below this dynamic. */
  changed: boolean;
  [key: string]: any;
}

/**
 * The sink half of the pair that reports which parts of the page a patch
 * touched. It keeps a copy of the last diff and hands each buffer the cursor
 * into it for the subtree that buffer renders.
 *
 * Subclasses override the hooks on {@link ReportingOutputBuffer} and point
 * {@link new} at their own buffer class. State that has to survive a render
 * belongs here, on the sink.
 *
 * @internal
 */
export class ReportingSink extends Sink {
  private rootDiff: DiffCursor = undefined;
  private componentDiffs: any = undefined;

  get reportsChanges(): boolean {
    return true;
  }

  // Cloning is not optional: the merge adopts diff subtrees into the rendered
  // tree and then mutates them. Components are split off so each buffer can be
  // handed only the cursor for the subtree it renders.
  preMerge(diff: any): void {
    const cloned = deepClone(diff);
    this.componentDiffs = cloned[COMPONENTS];
    delete cloned[COMPONENTS];
    this.rootDiff = cloned;
  }

  cursorFor(cid: number | null): DiffCursor {
    if (cid === null) {
      return this.rootDiff;
    }
    return this.componentDiffs && this.componentDiffs[cid];
  }

  new(cid: number | null): ReportingOutputBuffer {
    return new ReportingOutputBuffer(this, cid);
  }
}

/**
 * Base class for the buffers of a {@link ReportingSink}. Subclasses override
 * `onEnter`/`onExit`; everything else here is the plumbing the renderer talks
 * to.
 *
 * The renderer hands over an opaque cursor into the diff and this class walks
 * it alongside the tree, so no knowledge of the diff format is needed to write
 * a sink.
 *
 * @internal
 */
export class ReportingOutputBuffer extends OutputBuffer {
  protected frames: SinkFrame[] = [];
  /** The cursor for the subtree this buffer renders. */
  protected diff: DiffCursor;

  constructor(
    /** The sink that made this buffer, and the home of its lasting state. */
    readonly sink: ReportingSink,
    cid: number | null,
  ) {
    super();
    this.diff = sink.cursorFor(cid);
  }

  /**
   * Called around every dynamic in the tree. A change is reported at every
   * level, so a dynamic containing a changed one is itself reported as
   * changed; a sink that wants to attribute a change to the innermost thing
   * that changed applies that policy itself, walking `frames`.
   */
  onEnter(_frame: SinkFrame): void {}
  onExit(_frame: SinkFrame): void {}

  enter(
    parentDiff: DiffCursor,
    node: any,
    index: number,
    statics: string[],
  ): DiffCursor {
    const diff = this.diffFor(parentDiff, index);
    // The diff mirrors the tree, so the server having sent anything at this
    // position means this patch touched something at or below it.
    const frame: SinkFrame = {
      node,
      index,
      statics,
      changed: diff !== undefined,
    };
    this.frames.push(frame);
    this.onEnter(frame);
    return diff;
  }

  exit(): void {
    this.onExit(this.frames.pop()!);
  }

  /**
   * Entries are not bracketed by enter/exit, so the renderer asks for theirs
   * directly.
   */
  keyedEntry(diffNode: DiffCursor, index: number): DiffCursor {
    const keyed = this.diffFor(diffNode, KEYED);
    if (keyed === ALL_CHANGED || keyed === undefined) {
      return keyed;
    }
    const entry = keyed[index];
    if (Array.isArray(entry)) {
      // [old_idx, diff] - moved, with a diff of its own
      return entry[1];
    } else if (typeof entry === "number") {
      // moved without a diff; the move is a change of the comprehension, not
      // of anything inside the entry
      return undefined;
    } else {
      return entry;
    }
  }

  protected diffFor(diffNode: DiffCursor, key: string | number): DiffCursor {
    if (diffNode === undefined || diffNode === null) {
      return undefined;
    } else if (diffNode === ALL_CHANGED || diffNode[STATIC] !== undefined) {
      return ALL_CHANGED;
    } else {
      return diffNode[key];
    }
  }
}

import { KEYED, STATIC } from "../constants";
import { modifyRoot, type RootAttrs } from "./modify_root";

// Key reserved on rendered nodes for a sink to hang its own state on. It rides
// along with the node through diff merges.
export const SINK_STATE = "sinkState";

// A position in the diff the renderer is walking. Opaque: the renderer carries
// it from one `enter` back into the next without ever inspecting it, and only
// ReportingSink knows what is inside.
export type DiffCursor = any;

/**
 * The buffer the renderer writes HTML through.
 *
 * The default is a plain string accumulator. A tool can install its own with
 * `liveSocket.attachDebugSink` to observe or annotate the output; to be told
 * which parts of the page a patch touched, extend {@link ReportingSink} rather
 * than this class.
 *
 * @internal
 */
export class StringSink {
  protected html = "";
  private pending: string[] = [];
  private base = 0;

  /**
   * Whether the renderer should report which parts of the page a patch
   * touched. False here, since a plain buffer has nothing to report it to;
   * {@link ReportingSink} overrides it.
   *
   * Must stay a getter rather than a field: a field on this class would define
   * an own property on every instance and silently shadow a subclass's getter.
   */
  get reportsChanges(): boolean {
    return false;
  }

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
   * what came before. A sink that records positions overrides both, keeping
   * the buffer continuous and applying its edits at the end instead; `length`
   * stays continuous across the pair either way.
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
 * Base class for sinks that want to be told which parts of the page a patch
 * touched. Subclasses override `onEnter`/`onExit`; everything else here is the
 * plumbing the renderer talks to.
 *
 * The renderer hands over an opaque cursor into the diff and this class walks
 * it alongside the tree, so no knowledge of the diff format is needed to write
 * a sink.
 *
 * @internal
 */
export class ReportingSink extends StringSink {
  protected frames: SinkFrame[] = [];
  protected diff: DiffCursor = undefined;

  /**
   * Called around every dynamic in the tree. A change is reported at every
   * level, so a dynamic containing a changed one is itself reported as
   * changed; a sink that wants to attribute a change to the innermost thing
   * that changed applies that policy itself, walking `frames`.
   */
  onEnter(_frame: SinkFrame): void {}
  onExit(_frame: SinkFrame): void {}

  /**
   * Extending this class without overriding either hook makes the rendered
   * skips the extra work.
   */
  get reportsChanges(): boolean {
    const base = ReportingSink.prototype;
    return this.onEnter !== base.onEnter || this.onExit !== base.onExit;
  }

  /**
   * Called once before the render with its diff cursor, which is undefined for
   * a render with no diff to compare against - a join, or the first render
   * after this sink was attached. Subclasses may override to reset state.
   */
  storeDiff(diff: DiffCursor): void {
    this.diff = diff;
  }

  /**
   * Brackets the dynamic at `statics[index]` of `node`. Returns the cursor for
   * that dynamic, which the renderer passes back down.
   */
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
   * The cursor for one entry of a keyed comprehension. Entries are not
   * bracketed by enter/exit, so the renderer asks for theirs directly.
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

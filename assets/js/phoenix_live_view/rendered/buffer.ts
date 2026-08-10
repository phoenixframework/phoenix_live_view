import { COMPONENTS, KEYED, STATIC } from "../constants";
import { deepClone } from "../utils";
import { modifyRoot, type RootAttrs } from "./modify_root";

// A position in the diff the renderer is walking. Opaque: the renderer carries
// it from one `enter` back into the next without ever inspecting it, and only
// {@link ReportingBuffer} knows what is inside.
export type DiffCursor = any;

/**
 * What the renderer writes HTML through.
 *
 * One buffer is constructed per subtree render and discarded once its HTML has
 * been taken, so a buffer class — not a buffer instance — is what gets
 * installed, with `liveSocket.attachDebugBuffer`. A tool can subclass this to
 * observe or annotate the output; to be told which parts of the page a patch
 * touched, extend {@link ReportingBuffer} rather than this class.
 *
 * The default does nothing at all and buffers into a string.
 *
 * @internal
 */
export class RenderingBuffer {
  /**
   * Called before each diff merges into the rendered tree, and skipped
   * entirely by a class that does not define it. Whatever it returns is handed
   * to the constructor of every buffer that renders from that diff.
   *
   * Anything a class wants to keep from the diff has to be copied here: the
   * merge adopts diff subtrees into the tree and then mutates them.
   *
   * Not called for the join, which has no previous render to compare against.
   */
  static preMerge?(diff: any): unknown;

  protected html = "";
  private pending: string[] = [];

  constructor(
    /**
     * What this class's {@link preMerge} returned for the diff that last
     * merged, or undefined if it defines none — or if nothing has merged since
     * the class was installed, which includes the join.
     */
    _preMerge: unknown,
    /**
     * The subtree being rendered: null for the root tree, a component id
     * otherwise.
     */
    _cid: number | null,
  ) {}

  /**
   * Characters written so far, counting what an open root was split off from.
   * A buffer that records positions brackets spans with this.
   *
   * Summed on read rather than tracked on write: only a buffer that records
   * positions ever asks, and tracking it charged every render that never does.
   * Roots nest shallowly, so the walk is short.
   */
  get length(): number {
    let total = this.html.length;
    for (let i = 0; i < this.pending.length; i++) {
      total += this.pending[i].length;
    }
    return total;
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
    this.html = "";
  }

  endRoot(attrs: RootAttrs, clearInnerHTML?: boolean): void {
    const [root, before, after] = modifyRoot(this.html, attrs, clearInnerHTML);
    this.html = this.pending.pop()! + before + root + after;
  }

  /**
   * Brackets the dynamic at `statics[index]` of `node`. Called around every
   * dynamic of every render, so the default has to be cheap; see
   * {@link ReportingBuffer} for what a buffer can do with it.
   */
  enter(_node: any, _index: number, _statics: string[]): void {}

  exit(): void {}

  /**
   * Brackets one entry of a keyed comprehension. Entries hold dynamics without
   * being one themselves, so they are opened separately from `enter`.
   */
  beginKeyedEntry(_index: number): void {}

  endKeyedEntry(): void {}
}

// Sentinel cursor meaning "everything below here is new", used when a subtree
// arrives with fresh statics so there is nothing to compare it against.
const ALL_CHANGED = Symbol("all changed");

/**
 * What a buffer is told about one dynamic of the rendered tree.
 *
 * Subclasses may hang their own state on a frame in `onEnter` and read it back
 * in `onExit`, which is why it carries an index signature.
 */
export interface BufferFrame {
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
 * The buffer that reports which parts of the page a patch touched. It keeps a
 * copy of each diff before it merges and walks it alongside the tree, so a
 * subclass needs no knowledge of the diff format: it overrides `onEnter` and
 * `onExit` and reads {@link BufferFrame.changed}.
 *
 * @internal
 */
export class ReportingBuffer extends RenderingBuffer {
  // Cloning is not optional: the merge adopts diff subtrees into the rendered
  // tree and then mutates them. The copy is shared by every buffer of the
  // render that follows, so nothing here may consume it.
  static preMerge(diff: any): DiffCursor {
    return deepClone(diff);
  }

  protected frames: BufferFrame[] = [];
  /** The cursor for the subtree this buffer renders. */
  protected diff: DiffCursor;
  // Cursors for the dynamics and comprehension entries currently open, so the
  // renderer only has to say when one begins and ends. Kept apart from
  // `frames`: entries carry a cursor without being a dynamic themselves, and
  // reporting a change for one would mean reporting it twice.
  private cursors: DiffCursor[] = [];

  constructor(preMerge: DiffCursor, cid: number | null) {
    super(preMerge, cid);
    // Off the subclass, so overriding `cursorFor` alongside `preMerge` is
    // enough to keep something other than a diff in there.
    this.diff = this.cursorFor(preMerge, cid);
  }

  private cursorFor(preMerge: DiffCursor, cid: number | null): DiffCursor {
    if (!preMerge) {
      return undefined;
    } else if (cid === null) {
      return preMerge;
    } else {
      return preMerge[COMPONENTS] && preMerge[COMPONENTS][cid];
    }
  }

  /**
   * Called around every dynamic in the tree. A change is reported at every
   * level, so a dynamic containing a changed one is itself reported as
   * changed; a buffer that wants to attribute a change to the innermost thing
   * that changed applies that policy itself, walking `frames`.
   */
  onEnter(_frame: BufferFrame): void {}
  onExit(_frame: BufferFrame): void {}

  /** Where in the diff the renderer currently is. */
  protected currentDiff(): DiffCursor {
    return this.cursors.length > 0
      ? this.cursors[this.cursors.length - 1]
      : this.diff;
  }

  enter(node: any, index: number, statics: string[]): void {
    const diff = this.diffFor(this.currentDiff(), index);
    // The diff mirrors the tree, so the server having sent anything at this
    // position means this patch touched something at or below it.
    const frame: BufferFrame = {
      node,
      index,
      statics,
      changed: diff !== undefined,
    };
    this.cursors.push(diff);
    this.frames.push(frame);
    this.onEnter(frame);
  }

  exit(): void {
    this.cursors.pop();
    this.onExit(this.frames.pop()!);
  }

  beginKeyedEntry(index: number): void {
    this.cursors.push(this.keyedEntry(this.currentDiff(), index));
  }

  endKeyedEntry(): void {
    this.cursors.pop();
  }

  protected keyedEntry(diffNode: DiffCursor, index: number): DiffCursor {
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

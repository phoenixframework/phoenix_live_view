import { type RootAttrs } from "./modify_root";
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
export declare class RenderingBuffer {
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
    protected html: string;
    private pending;
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
    _cid: number | null);
    /**
     * Characters written so far, counting what an open root was split off from.
     * A buffer that records positions brackets spans with this.
     *
     * Summed on read rather than tracked on write: only a buffer that records
     * positions ever asks, and tracking it charged every render that never does.
     * Roots nest shallowly, so the walk is short.
     */
    get length(): number;
    write(str: string): void;
    toString(): string;
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
    beginRoot(): void;
    endRoot(attrs: RootAttrs, clearInnerHTML?: boolean): void;
    /**
     * Brackets the dynamic at `statics[index]` of `node`. Called around every
     * dynamic of every render, so the default has to be cheap; see
     * {@link ReportingBuffer} for what a buffer can do with it.
     */
    enter(_node: any, _index: number, _statics: string[]): void;
    exit(): void;
    /**
     * Brackets one entry of a keyed comprehension. Entries hold dynamics without
     * being one themselves, so they are opened separately from `enter`.
     */
    beginKeyedEntry(_index: number): void;
    endKeyedEntry(): void;
}
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
export declare class ReportingBuffer extends RenderingBuffer {
    static preMerge(diff: any): DiffCursor;
    protected frames: BufferFrame[];
    /** The cursor for the subtree this buffer renders. */
    protected diff: DiffCursor;
    private cursors;
    constructor(preMerge: DiffCursor, cid: number | null);
    private cursorFor;
    /**
     * Called around every dynamic in the tree. A change is reported at every
     * level, so a dynamic containing a changed one is itself reported as
     * changed; a buffer that wants to attribute a change to the innermost thing
     * that changed applies that policy itself, walking `frames`.
     */
    onEnter(_frame: BufferFrame): void;
    onExit(_frame: BufferFrame): void;
    /** Where in the diff the renderer currently is. */
    protected currentDiff(): DiffCursor;
    enter(node: any, index: number, statics: string[]): void;
    exit(): void;
    beginKeyedEntry(index: number): void;
    endKeyedEntry(): void;
    protected keyedEntry(diffNode: DiffCursor, index: number): DiffCursor;
    protected diffFor(diffNode: DiffCursor, key: string | number): DiffCursor;
}

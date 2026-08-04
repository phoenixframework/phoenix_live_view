import {
  COMPONENTS,
  TEMPLATES,
  EVENTS,
  PHX_COMPONENT,
  PHX_VIEW_REF,
  PHX_SKIP,
  PHX_MAGIC_ID,
  REPLY,
  STATIC,
  TITLE,
  STREAM,
  ROOT,
  KEYED,
  KEYED_COUNT,
  KEYED_MOVED,
} from "./constants";

import { isObject, isCid } from "./utils";
import { logError } from "./diagnostics";

const VOID_TAGS = new Set([
  "area",
  "base",
  "br",
  "col",
  "command",
  "embed",
  "hr",
  "img",
  "input",
  "keygen",
  "link",
  "meta",
  "param",
  "source",
  "track",
  "wbr",
]);
const quoteChars = new Set(["'", '"']);

// Diff cursor sentinel meaning "everything below here is new". Used when a
// subtree arrives with fresh statics, so there is nothing to compare against.
const ALL_CHANGED = Symbol("all changed");

// Descends the diff cursor alongside the rendered tree. `undefined` means the
// server sent nothing for this position, i.e. it did not change.
const diffFor = (diffNode, key) => {
  if (diffNode === undefined || diffNode === null) {
    return undefined;
  } else if (diffNode === ALL_CHANGED || diffNode[STATIC] !== undefined) {
    return ALL_CHANGED;
  } else {
    return diffNode[key];
  }
};

// Key reserved on rendered nodes for a sink to hang its own state on. It rides
// along with the node through diff merges, and is dropped when a node is
// rebuilt from another component's statics - which is exactly the lifetime a
// sink needs for anything identifying that node.
export const SINK_STATE = "sinkState";

// The buffer the render pass writes HTML through. The default is a plain
// string accumulator; a page can install its own via the LiveSocket `sink`
// option to observe or annotate the output.
/** @internal */
export class StringSink {
  constructor() {
    this.html = "";
    this.pending = [];
    this.base = 0;
  }

  // Characters written so far. A sink that records positions brackets spans
  // with this; see `enter` below.
  get length() {
    return this.base + this.html.length;
  }

  write(str) {
    this.html += str;
  }

  toString() {
    return this.html;
  }

  // Brackets a root element: everything written in between is a single
  // element, `attrs` are added to its start tag, and `clearInnerHTML`
  // additionally discards its contents (LiveView skips re-rendering a root
  // that did not change and reuses what is already in the DOM).
  //
  // The default isolates the element so it can rewrite it without touching
  // what came before. A sink that records positions overrides both, keeping
  // the buffer continuous and applying the edits at the end instead.
  beginRoot() {
    this.pending.push(this.html);
    this.base += this.html.length;
    this.html = "";
  }

  endRoot(attrs, clearInnerHTML) {
    // Resolves to the free function below, not to a method.
    const [root, before, after] = modifyRoot(this.html, attrs, clearInnerHTML);
    const prefix = this.pending.pop();
    this.base -= prefix.length;
    this.html = prefix + before + root + after;
  }

  // A sink may additionally implement:
  //
  //   enter(node, index, statics)   before the dynamic at statics[index]
  //   exit(changed)                 after it, with whether the diff touched it
  //
  // Implementing `enter` opts into change tracking, which is otherwise skipped
  // entirely. Between the two calls the sink can read `length` to bracket that
  // dynamic's output, and it may keep per-node state under SINK_STATE.
  //
  // `changed` is reported at every level, so a dynamic containing a changed
  // one is itself reported as changed. A sink that wants to attribute a change
  // to the innermost thing that changed applies that policy itself.
  //
  // A HEEx function component call site is a static ending in a
  // `<!-- @caller file:line (app) -->` annotation, emitted when the server is
  // compiled with `debug_heex_annotations`. Recognising those, and the source
  // location they carry, is left to the sink.
}

export const modifyRoot = (html, attrs, clearInnerHTML) => {
  let i;
  let insideComment;
  let beforeTag, afterTag, tag, tagNameEndsAt, id, newHTML;

  const lookahead = html.match(/^(\s*(?:<!--.*?-->\s*)*)<([^\s\/>]+)/);
  if (lookahead === null) {
    throw new Error(`malformed html ${html}`);
  }

  i = lookahead[0].length;
  beforeTag = lookahead[1];
  tag = lookahead[2];
  tagNameEndsAt = i;

  // Scan the opening tag for id, if there is any
  for (i; i < html.length; i++) {
    if (html.charAt(i) === ">") {
      break;
    }
    if (html.charAt(i) === "=") {
      const isId = html.slice(i - 3, i) === " id";
      i++;
      const char = html.charAt(i);
      if (quoteChars.has(char)) {
        const attrStartsAt = i;
        i++;
        for (i; i < html.length; i++) {
          if (html.charAt(i) === char) {
            break;
          }
        }
        if (isId) {
          id = html.slice(attrStartsAt + 1, i);
          break;
        }
      }
    }
  }

  let closeAt = html.length - 1;
  insideComment = false;
  while (closeAt >= beforeTag.length + tag.length) {
    const char = html.charAt(closeAt);
    if (insideComment) {
      if (char === "-" && html.slice(closeAt - 3, closeAt) === "<!-") {
        insideComment = false;
        closeAt -= 4;
      } else {
        closeAt -= 1;
      }
    } else if (char === ">" && html.slice(closeAt - 2, closeAt) === "--") {
      insideComment = true;
      closeAt -= 3;
    } else if (char === ">") {
      break;
    } else {
      closeAt -= 1;
    }
  }
  afterTag = html.slice(closeAt + 1, html.length);

  const attrsStr = Object.keys(attrs)
    .map((attr) => (attrs[attr] === true ? attr : `${attr}="${attrs[attr]}"`))
    .join(" ");

  if (clearInnerHTML) {
    // Keep the id if any
    const idAttrStr = id ? ` id="${id}"` : "";
    if (VOID_TAGS.has(tag)) {
      newHTML = `<${tag}${idAttrStr}${attrsStr === "" ? "" : " "}${attrsStr}/>`;
    } else {
      newHTML = `<${tag}${idAttrStr}${attrsStr === "" ? "" : " "}${attrsStr}></${tag}>`;
    }
  } else {
    const rest = html.slice(tagNameEndsAt, closeAt + 1);
    newHTML = `<${tag}${attrsStr === "" ? "" : " "}${attrsStr}${rest}`;
  }

  return [newHTML, beforeTag, afterTag];
};

/** @internal */
export default class Rendered {
  static extract(diff) {
    const { [REPLY]: reply, [EVENTS]: events, [TITLE]: title } = diff;
    delete diff[REPLY];
    delete diff[EVENTS];
    delete diff[TITLE];
    return { diff, title, reply: reply || null, events: events || [] };
  }

  constructor(viewId, rendered, createSink = () => new StringSink()) {
    this.viewId = viewId;
    this.rendered = {};
    this.magicId = 0;
    this.useSink(createSink);
    // The first merge is the join: everything is new, nothing is a change.
    this.initialMerge = true;
    this.mergeDiff(rendered);
    this.initialMerge = false;
  }

  useSink(createSink) {
    this.createSink = createSink;
    // Change tracking is only paid for when the installed sink asks for it.
    const probe = /** @type {{enter?: unknown}} */ (createSink());
    this.observed = typeof probe.enter === "function";
    // diffCursor/componentDiffs hold a clone of the last diff, which the
    // render pass walks alongside the tree to tell the sink which dynamics
    // this patch touched; see captureDiffCursor.
    this.diffCursor = undefined;
    this.componentDiffs = undefined;
  }

  // Swaps the sink on a tree that has already been rendered. State the
  // previous sink kept on the tree is dropped, since it means nothing to its
  // replacement, and every component is marked for a full re-render so the new
  // sink is shown the whole tree rather than only what changes next.
  setSink(createSink) {
    this.useSink(createSink);
    this.clearSinkState(this.rendered);
    const components = this.rendered[COMPONENTS] || {};
    for (const cid in components) {
      components[cid].reset = true;
    }
  }

  clearSinkState(node) {
    delete node[SINK_STATE];
    for (const key in node) {
      if (isObject(node[key])) {
        this.clearSinkState(node[key]);
      }
    }
  }

  parentViewId() {
    return this.viewId;
  }

  // changeTracking false forces every root to be re-rendered instead of
  // reusing what is already in the DOM; see the PHX_SKIP optimization.
  toString(onlyCids, changeTracking = true) {
    const { buffer: str, streams: streams } = this.recursiveToString(
      this.rendered,
      this.rendered[COMPONENTS],
      onlyCids,
      changeTracking,
      {},
      this.diffCursor,
    );
    return { buffer: str, streams: streams };
  }

  recursiveToString(
    rendered,
    components = rendered[COMPONENTS],
    onlyCids,
    changeTracking,
    rootAttrs,
    diffNode,
  ) {
    onlyCids = onlyCids ? new Set(onlyCids) : null;
    const output = {
      sink: this.createSink(),
      components: components,
      onlyCids: onlyCids,
      streams: new Set(),
      observed: this.observed,
    };
    this.toOutputBuffer(
      rendered,
      diffNode,
      null,
      output,
      changeTracking,
      rootAttrs,
    );
    return { buffer: output.sink.toString(), streams: output.streams };
  }

  componentCIDs(diff) {
    return Object.keys(diff[COMPONENTS] || {}).map((i) => parseInt(i));
  }

  isComponentOnlyDiff(diff) {
    if (!diff[COMPONENTS]) {
      return false;
    }
    return Object.keys(diff).length === 1;
  }

  getComponent(diff, cid) {
    return diff[COMPONENTS][cid];
  }

  resetRender(cid) {
    // we are racing a component destroy, it could not exist, so
    // make sure that we don't try to set reset on undefined
    if (this.rendered[COMPONENTS][cid]) {
      this.rendered[COMPONENTS][cid].reset = true;
    }
  }

  mergeDiff(diff) {
    this.captureDiffCursor(diff);
    const newc = diff[COMPONENTS];
    const cache = {};
    delete diff[COMPONENTS];
    this.rendered = this.mutableMerge(this.rendered, diff);
    this.rendered[COMPONENTS] = this.rendered[COMPONENTS] || {};

    if (newc) {
      const oldc = this.rendered[COMPONENTS];

      for (const cid in newc) {
        newc[cid] = this.cachedFindComponent(cid, newc[cid], oldc, newc, cache);
      }

      for (const cid in newc) {
        oldc[cid] = newc[cid];
      }
      diff[COMPONENTS] = newc;
    }
  }

  // Keeps a deep copy of the incoming diff so the render pass can walk it
  // alongside the tree. Cloning is not optional: the merge adopts diff
  // subtrees into the rendered tree and then mutates them.
  captureDiffCursor(diff) {
    if (!this.observed || this.initialMerge) {
      this.diffCursor = undefined;
      this.componentDiffs = undefined;
      return;
    }
    const cloned = this.clone(diff);
    this.componentDiffs = cloned[COMPONENTS];
    delete cloned[COMPONENTS];
    this.diffCursor = cloned;
  }

  cachedFindComponent(cid, cdiff, oldc, newc, cache) {
    if (cache[cid]) {
      return cache[cid];
    } else {
      let ndiff,
        stat,
        scid = cdiff[STATIC];

      if (isCid(scid)) {
        let tdiff;

        // @ts-expect-error: isCid also allows strings, but the diff always uses numbers
        // TODO: revisit isCid and consider differentiating cid strings from DOM and cid numbers from diffs / internal usage
        if (scid > 0) {
          tdiff = this.cachedFindComponent(scid, newc[scid], oldc, newc, cache);
        } else {
          tdiff = oldc[-scid];
        }

        stat = tdiff[STATIC];
        ndiff = this.cloneMerge(tdiff, cdiff, true);
        ndiff[STATIC] = stat;
      } else {
        ndiff =
          cdiff[STATIC] !== undefined || oldc[cid] === undefined
            ? cdiff
            : this.cloneMerge(oldc[cid], cdiff, false);
      }

      cache[cid] = ndiff;
      return ndiff;
    }
  }

  mutableMerge(target, source) {
    if (source[STATIC] !== undefined) {
      return source;
    } else {
      this.doMutableMerge(target, source);
      return target;
    }
  }

  doMutableMerge(target, source) {
    if (source[KEYED]) {
      this.mergeKeyed(target, source);
    } else {
      for (const key in source) {
        const val = source[key];
        const targetVal = target[key];
        const isObjVal = isObject(val);
        if (isObjVal && val[STATIC] === undefined && isObject(targetVal)) {
          this.doMutableMerge(targetVal, val);
        } else {
          target[key] = val;
        }
      }
    }
    if (target[ROOT]) {
      target.newRender = true;
    }
  }

  clone(diff) {
    if ("structuredClone" in window) {
      return structuredClone(diff);
    } else {
      // fallback for jest
      return JSON.parse(JSON.stringify(diff));
    }
  }

  // keyed comprehensions
  mergeKeyed(target, source) {
    // Moves read entries from their old positions. Clone before applying any
    // entries so an earlier mutation cannot overwrite a position needed later.
    // Stable-position updates never read from another position.
    const clonedTarget = source[KEYED][KEYED_MOVED] && this.clone(target);
    Object.entries(source[KEYED]).forEach(([i, entry]) => {
      if (i === KEYED_COUNT || i === KEYED_MOVED) {
        return;
      }
      if (Array.isArray(entry)) {
        // [old_idx, diff]
        // moved with diff
        const [old_idx, diff] = entry;
        target[KEYED][i] = clonedTarget[KEYED][old_idx];
        this.doMutableMerge(target[KEYED][i], diff);
      } else if (typeof entry === "number") {
        // moved without diff
        const old_idx = entry;
        target[KEYED][i] = clonedTarget[KEYED][old_idx];
      } else if (typeof entry === "object") {
        // diff, same position
        if (!target[KEYED][i]) {
          target[KEYED][i] = {};
        }
        this.doMutableMerge(target[KEYED][i], entry);
      }
    });
    // drop extra entries
    if (source[KEYED][KEYED_COUNT] < target[KEYED][KEYED_COUNT]) {
      for (
        let i = source[KEYED][KEYED_COUNT];
        i < target[KEYED][KEYED_COUNT];
        i++
      ) {
        delete target[KEYED][i];
      }
    }
    target[KEYED][KEYED_COUNT] = source[KEYED][KEYED_COUNT];
    if (source[STREAM]) {
      target[STREAM] = source[STREAM];
    }
    if (source[TEMPLATES]) {
      target[TEMPLATES] = source[TEMPLATES];
    }
  }

  // Merges cid trees together, copying statics from source tree.
  //
  // The `pruneMagicId` is passed to control pruning the magicId of the
  // target. We must always prune the magicId when we are sharing statics
  // from another component. If not pruning, we replicate the logic from
  // mutableMerge, where we set newRender to true if there is a root
  // (effectively forcing the new version to be rendered instead of skipped)
  //
  cloneMerge(target, source, pruneMagicId) {
    let merged;
    if (source[KEYED]) {
      merged = this.clone(target);
      this.mergeKeyed(merged, source);
      // The non-keyed branch below prunes as it recurses; the keyed clone has
      // to be walked separately.
      if (pruneMagicId) {
        this.pruneInternalIds(merged);
      }
    } else {
      merged = { ...target, ...source };
      for (const key in merged) {
        const val = source[key];
        const targetVal = target[key];
        if (isObject(val) && val[STATIC] === undefined && isObject(targetVal)) {
          merged[key] = this.cloneMerge(targetVal, val, pruneMagicId);
        } else if (val === undefined && isObject(targetVal)) {
          merged[key] = this.cloneMerge(targetVal, {}, pruneMagicId);
        }
      }
    }
    if (pruneMagicId) {
      this.deleteInternalIds(merged);
    } else if (target[ROOT]) {
      merged.newRender = true;
    }
    return merged;
  }

  // A component sharing statics with another cid is cloned from that cid's
  // tree, which would otherwise carry that cid's magic IDs and sink state
  // along. Both identify the node they came from, so a duplicate would be
  // wrong for as long as the clone lives.
  pruneInternalIds(rendered) {
    for (const key in rendered) {
      if (isObject(rendered[key])) {
        this.pruneInternalIds(rendered[key]);
      }
    }
    this.deleteInternalIds(rendered);
  }

  deleteInternalIds(rendered) {
    delete rendered.magicId;
    delete rendered.newRender;
    delete rendered[SINK_STATE];
    delete rendered.keyedCount;
  }

  componentToString(cid) {
    const { buffer: str, streams } = this.recursiveCIDToString(
      this.rendered[COMPONENTS],
      cid,
      null,
    );
    const [strippedHTML, _before, _after] = modifyRoot(str, {});
    return { buffer: strippedHTML, streams: streams };
  }

  pruneCIDs(cids) {
    cids.forEach((cid) => delete this.rendered[COMPONENTS][cid]);
  }

  // private

  get() {
    return this.rendered;
  }

  isNewFingerprint(diff = {}) {
    return !!diff[STATIC];
  }

  templateStatic(part, templates) {
    if (typeof part === "number") {
      return templates[part];
    } else {
      return part;
    }
  }

  nextMagicID() {
    this.magicId++;
    return `m${this.magicId}-${this.parentViewId()}`;
  }

  // Converts rendered tree to output buffer.
  //
  // changeTracking controls if we can apply the PHX_SKIP optimization.
  //
  // diffNode is the debug-only cursor into the last diff (see
  // captureDiffCursor). The return value says whether this node changed in
  // that diff, *excluding* changes that belong to a nested function component:
  // those are reported against their own caller ID instead, so only the
  // deepest component that actually changed gets named.
  toOutputBuffer(
    rendered,
    diffNode,
    templates,
    output,
    changeTracking,
    rootAttrs = {},
  ) {
    if (rendered[KEYED]) {
      return this.comprehensionToBuffer(
        rendered,
        diffNode,
        templates,
        output,
        changeTracking,
      );
    }

    // Templates are a way of sharing statics between multiple rendered structs.
    // Since LiveView 1.1, those can also appear at the root - for example if one renders
    // two comprehensions that can share statics.
    // Whenever we find templates, we need to use them recursively. Also, templates can
    // be sent for each diff, not only for the initial one. We don't want to merge them
    // though, so we always resolve them and remove them from the rendered object.
    if (rendered[TEMPLATES]) {
      templates = rendered[TEMPLATES];
      delete rendered[TEMPLATES];
    }

    let { [STATIC]: statics } = rendered;
    statics = this.templateStatic(statics, templates);
    rendered[STATIC] = statics;
    const isRoot = rendered[ROOT];
    if (isRoot) {
      output.sink.beginRoot();
    }

    // this condition is called when first rendering an optimizable function component.
    // LC have their magicId previously set
    if (changeTracking && isRoot && !rendered.magicId) {
      rendered.newRender = true;
      rendered.magicId = this.nextMagicID();
    }

    const changed = this.dynamicsToBuffer(
      rendered,
      diffNode,
      statics,
      templates,
      output,
      changeTracking,
    );

    // Applies the root tag "skip" optimization if supported, which clears
    // the root tag attributes and innerHTML, and only maintains the magicId.
    // We can only skip when changeTracking is supported,
    // and when the root element hasn't experienced an unrendered merge (newRender true).
    if (isRoot) {
      let skip = false;
      let attrs;
      // When a LC is re-added to the page, we need to re-render the entire LC tree,
      // therefore changeTracking is false; however, we need to keep all the magicIds
      // from any function component so the next time the LC is updated, we can apply
      // the skip optimization
      if (changeTracking || rendered.magicId) {
        skip = changeTracking && !rendered.newRender;
        attrs = { [PHX_MAGIC_ID]: rendered.magicId, ...rootAttrs };
      } else {
        attrs = rootAttrs;
      }
      if (skip) {
        attrs[PHX_SKIP] = true;
      }
      output.sink.endRoot(attrs, skip);
      rendered.newRender = false;
    }
    return changed;
  }

  // Emits `statics` interleaved with the dynamics held on `node`, which is
  // either a rendered struct or a single entry of a keyed comprehension.
  //
  // Unless the sink implements `enter` this is the plain interleave: no diff
  // cursor is consulted and the sink is not called, so change tracking costs
  // nothing when nobody asked for it.
  dynamicsToBuffer(node, diffNode, statics, templates, output, changeTracking) {
    const sink = output.sink;
    if (!output.observed) {
      sink.write(statics[0]);
      for (let i = 1; i < statics.length; i++) {
        this.dynamicToBuffer(
          node[i - 1],
          undefined,
          templates,
          output,
          changeTracking,
        );
        sink.write(statics[i]);
      }
      return false;
    }

    let changed = diffNode === ALL_CHANGED;
    for (let i = 0; i < statics.length - 1; i++) {
      sink.write(statics[i]);
      sink.enter(node, i, statics);
      const dynamicChanged = this.dynamicToBuffer(
        node[i],
        diffFor(diffNode, i),
        templates,
        output,
        changeTracking,
      );
      sink.exit(dynamicChanged);
      changed = dynamicChanged || changed;
    }
    sink.write(statics[statics.length - 1]);
    return changed;
  }

  comprehensionToBuffer(rendered, diffNode, templates, output, changeTracking) {
    const keyedTemplates = templates || rendered[TEMPLATES];
    const statics = this.templateStatic(rendered[STATIC], templates);
    rendered[STATIC] = statics;
    delete rendered[TEMPLATES];
    const count = rendered[KEYED][KEYED_COUNT];

    let changed = false;
    let keyedDiff;
    if (output.observed) {
      keyedDiff = diffFor(diffNode, KEYED);
      // Reordering or dropping entries changes the comprehension itself even
      // when no surviving entry carries a diff. The old count is not
      // recoverable from the merged tree, so the last render records it.
      changed =
        keyedDiff === ALL_CHANGED ||
        !!(keyedDiff && keyedDiff[KEYED_MOVED]) ||
        (rendered.keyedCount !== undefined && rendered.keyedCount !== count);
      rendered.keyedCount = count;
    }

    for (let i = 0; i < count; i++) {
      changed =
        this.dynamicsToBuffer(
          rendered[KEYED][i],
          this.keyedEntryDiff(keyedDiff, i),
          statics,
          keyedTemplates,
          output,
          changeTracking,
        ) || changed;
    }
    // we don't need to store the rendered tree for streams
    if (rendered[STREAM]) {
      const stream = rendered[STREAM];
      const [_ref, _inserts, deleteIds, reset] = stream || [null, {}, [], null];
      if (
        stream !== undefined &&
        (rendered[KEYED][KEYED_COUNT] > 0 || deleteIds.length > 0 || reset)
      ) {
        delete rendered[STREAM];
        rendered[KEYED] = {
          [KEYED_COUNT]: 0,
        };
        output.streams.add(stream);
        changed = changed || diffNode !== undefined;
      }
    }
    return changed;
  }

  keyedEntryDiff(keyedDiff, i) {
    if (keyedDiff === ALL_CHANGED) {
      return ALL_CHANGED;
    } else if (keyedDiff === undefined) {
      return undefined;
    }
    const entry = keyedDiff[i];
    if (Array.isArray(entry)) {
      // [old_idx, diff] - moved with diff
      return entry[1];
    } else if (typeof entry === "number") {
      // moved without diff; the move itself is reported on the comprehension
      return undefined;
    } else {
      return entry;
    }
  }

  dynamicToBuffer(rendered, diffNode, templates, output, changeTracking) {
    if (typeof rendered === "number") {
      const { buffer: str, streams } = this.recursiveCIDToString(
        output.components,
        rendered,
        output.onlyCids,
      );
      output.sink.write(str);
      output.streams = new Set([...output.streams, ...streams]);
      // Only true when the cid reference itself changed; the component's own
      // content is reported while rendering that component.
      return diffNode !== undefined;
    } else if (isObject(rendered)) {
      return this.toOutputBuffer(
        rendered,
        diffNode,
        templates,
        output,
        changeTracking,
        {},
      );
    } else {
      output.sink.write(rendered);
      return diffNode !== undefined;
    }
  }

  // A component whose diff carries statics was either created or rebuilt from
  // another cid's tree, so nothing in it can be compared against a previous
  // render.
  componentDiffCursor(cid) {
    const cdiff = this.componentDiffs && this.componentDiffs[cid];
    if (cdiff === undefined || cdiff === null) {
      return undefined;
    } else {
      return cdiff[STATIC] !== undefined ? ALL_CHANGED : cdiff;
    }
  }

  recursiveCIDToString(components, cid, onlyCids) {
    if (components[cid]) {
      const component = components[cid];

      const attrs = { [PHX_COMPONENT]: cid, [PHX_VIEW_REF]: this.viewId };
      const skip = onlyCids && !onlyCids.has(cid);
      // Two optimization paths apply here:
      //
      //   1. The onlyCids optimization works by the server diff telling us only specific
      //     cid's have changed. This allows us to skip rendering any component that hasn't changed,
      //     which ultimately sets PHX_SKIP root attribute and avoids rendering the innerHTML.
      //
      //   2. The root PHX_SKIP optimization generalizes to all HEEx function components, and
      //     works in the same PHX_SKIP attribute fashion as 1, but the newRender tracking is done
      //     at the general diff merge level. If we merge a diff with new dynamics, we necessarily have
      //     experienced a change which must be a newRender, and thus we can't skip the render.
      //
      // Both optimization flows apply here. newRender is set based on the onlyCids optimization, and
      // we track a deterministic magicId based on the cid.
      //
      // changeTracking is about the entire tree
      // newRender is about the current root in the tree
      //
      // By default changeTracking is enabled, but we special case the flow where the client is pruning
      // cids and the server adds the component back. In such cases, we explicitly disable changeTracking
      // with resetRender for this cid, then re-enable it after the recursive call to skip the optimization
      // for the entire component tree.
      component.newRender = !skip;
      component.magicId = `c${cid}-${this.parentViewId()}`;
      // enable change tracking as long as the component hasn't been reset
      const changeTracking = !component.reset;
      const { buffer: html, streams } = this.recursiveToString(
        component,
        components,
        onlyCids,
        changeTracking,
        attrs,
        this.componentDiffCursor(cid),
      );
      // disable reset after we've rendered
      delete component.reset;

      return { buffer: html, streams: streams };
    } else {
      logError(
        "render.missing-component",
        `no component for CID ${cid}`,
        {
          cid,
          components,
        },
        { viewId: this.viewId, attribution: "internal" },
      );
      throw new Error(
        "Cannot continue render due to missing component: " + cid,
      );
    }
  }
}

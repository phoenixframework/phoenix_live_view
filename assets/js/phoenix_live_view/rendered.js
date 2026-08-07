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

import { isObject, isCid, deepClone } from "./utils";
import { RenderingBuffer } from "./rendered/buffer";
import { modifyRoot } from "./rendered/modify_root";
import { logError } from "./diagnostics";

/** @internal */
export default class Rendered {
  static extract(diff) {
    const { [REPLY]: reply, [EVENTS]: events, [TITLE]: title } = diff;
    delete diff[REPLY];
    delete diff[EVENTS];
    delete diff[TITLE];
    return { diff, title, reply: reply || null, events: events || [] };
  }

  // The buffer class is read afresh on every merge and every render rather
  // than held, so one installed after this tree mounted still takes effect —
  // for the parts of the page the next patch renders, and no sooner.
  constructor(viewId, rendered, bufferClass = () => RenderingBuffer) {
    this.viewId = viewId;
    this.rendered = {};
    this.magicId = 0;
    this.bufferClass = bufferClass;
    // The first merge is the join: everything is new, nothing is a change.
    this.initialMerge = true;
    this.mergeDiff(rendered);
    this.initialMerge = false;
  }

  parentViewId() {
    return this.viewId;
  }

  toString(onlyCids) {
    const { buffer: str, streams: streams } = this.recursiveToString(
      this.rendered,
      this.rendered[COMPONENTS],
      onlyCids,
      true,
      {},
      null,
    );
    return { buffer: str, streams: streams };
  }

  // cid identifies the subtree being rendered to the buffer: null for the root
  // tree, a component id otherwise.
  recursiveToString(
    rendered,
    components = rendered[COMPONENTS],
    onlyCids,
    changeTracking,
    rootAttrs,
    cid,
  ) {
    onlyCids = onlyCids ? new Set(onlyCids) : null;
    const bufferClass = this.bufferClass();
    // Only what the class installed right now kept for itself: a class
    // installed since the last merge has nothing of that diff to be handed.
    const [mergedBy, preMerge] = this.bufferPreMerge;
    const buffer = new bufferClass(
      mergedBy === bufferClass ? preMerge : undefined,
      cid,
    );
    const output = {
      buffer,
      components: components,
      onlyCids: onlyCids,
      streams: new Set(),
    };
    this.toOutputBuffer(rendered, null, output, changeTracking, rootAttrs);
    return { buffer: buffer.toString(), streams: output.streams };
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
    // Anything the buffer class wants to keep of this diff it has to copy now,
    // before the merge below adopts diff subtrees into the tree and mutates
    // them. What it keeps is tagged with the class that kept it, so a class
    // installed afterwards is never handed the previous one's data. The join
    // is skipped: there is no previous render to compare against.
    const bufferClass = this.bufferClass();
    this.bufferPreMerge = [
      bufferClass,
      !this.initialMerge && bufferClass.preMerge
        ? bufferClass.preMerge(diff)
        : undefined,
    ];
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
    return deepClone(diff);
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
  // tree, which would otherwise carry that cid's magic IDs along. They identify
  // the node they came from, so a duplicate would be wrong for as long as the
  // clone lives.
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
  toOutputBuffer(rendered, templates, output, changeTracking, rootAttrs = {}) {
    if (rendered[KEYED]) {
      return this.comprehensionToBuffer(
        rendered,
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
      output.buffer.beginRoot();
    }

    // this condition is called when first rendering an optimizable function component.
    // LC have their magicId previously set
    if (changeTracking && isRoot && !rendered.magicId) {
      rendered.newRender = true;
      rendered.magicId = this.nextMagicID();
    }

    this.dynamicsToBuffer(rendered, statics, templates, output, changeTracking);

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
      output.buffer.endRoot(attrs, skip);
      rendered.newRender = false;
    }
  }

  // Emits `statics` interleaved with the dynamics held on `node`, which is
  // either a rendered struct or a single entry of a keyed comprehension.
  //
  // Every dynamic is opened and closed on the buffer, whether or not the buffer
  // does anything with it. Skipping that for buffers that do not care was worth
  // ~4-6% of render on component-heavy trees and nothing on any other shape,
  // which is under 1% of a patch once the DOM work around it is counted — not
  // worth a capability flag a buffer can forget to set.
  dynamicsToBuffer(node, statics, templates, output, changeTracking) {
    const buffer = output.buffer;
    for (let i = 0; i < statics.length - 1; i++) {
      buffer.write(statics[i]);
      buffer.enter(node, i, statics);
      this.dynamicToBuffer(node[i], templates, output, changeTracking);
      buffer.exit();
    }
    buffer.write(statics[statics.length - 1]);
  }

  comprehensionToBuffer(rendered, templates, output, changeTracking) {
    const keyedTemplates = templates || rendered[TEMPLATES];
    const statics = this.templateStatic(rendered[STATIC], templates);
    rendered[STATIC] = statics;
    delete rendered[TEMPLATES];

    // Entries are not bracketed by enter/exit, so they are opened explicitly
    // for the buffer to descend into the right part of the diff.
    for (let i = 0; i < rendered[KEYED][KEYED_COUNT]; i++) {
      output.buffer.beginKeyedEntry(i);
      this.dynamicsToBuffer(
        rendered[KEYED][i],
        statics,
        keyedTemplates,
        output,
        changeTracking,
      );
      output.buffer.endKeyedEntry();
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
      }
    }
  }

  dynamicToBuffer(rendered, templates, output, changeTracking) {
    if (typeof rendered === "number") {
      const { buffer: str, streams } = this.recursiveCIDToString(
        output.components,
        rendered,
        output.onlyCids,
      );
      output.buffer.write(str);
      output.streams = new Set([...output.streams, ...streams]);
    } else if (isObject(rendered)) {
      this.toOutputBuffer(rendered, templates, output, changeTracking, {});
    } else {
      output.buffer.write(rendered);
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
        cid,
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

/** @internal */
export default class Rendered {
    static extract(diff: any): {
        diff: any;
        title: any;
        reply: any;
        events: any;
    };
    constructor(viewId: any, rendered: any, bufferClass?: () => typeof RenderingBuffer);
    viewId: any;
    rendered: {};
    magicId: number;
    bufferClass: () => typeof RenderingBuffer;
    initialMerge: boolean;
    parentViewId(): any;
    toString(onlyCids: any): {
        buffer: string;
        streams: Set<any>;
    };
    recursiveToString(rendered: any, components: any, onlyCids: any, changeTracking: any, rootAttrs: any, cid: any): {
        buffer: string;
        streams: Set<any>;
    };
    componentCIDs(diff: any): number[];
    isComponentOnlyDiff(diff: any): boolean;
    getComponent(diff: any, cid: any): any;
    resetRender(cid: any): void;
    mergeDiff(diff: any): void;
    bufferPreMerge: unknown[];
    cachedFindComponent(cid: any, cdiff: any, oldc: any, newc: any, cache: any): any;
    mutableMerge(target: any, source: any): any;
    doMutableMerge(target: any, source: any): void;
    clone(diff: any): any;
    mergeKeyed(target: any, source: any): void;
    cloneMerge(target: any, source: any, pruneMagicId: any): any;
    pruneInternalIds(rendered: any): void;
    deleteInternalIds(rendered: any): void;
    componentToString(cid: any): {
        buffer: string;
        streams: Set<any>;
    };
    pruneCIDs(cids: any): void;
    get(): {};
    isNewFingerprint(diff?: {}): boolean;
    templateStatic(part: any, templates: any): any;
    nextMagicID(): string;
    toOutputBuffer(rendered: any, templates: any, output: any, changeTracking: any, rootAttrs?: {}): void;
    dynamicsToBuffer(node: any, statics: any, templates: any, output: any, changeTracking: any): void;
    comprehensionToBuffer(rendered: any, templates: any, output: any, changeTracking: any): void;
    dynamicToBuffer(rendered: any, templates: any, output: any, changeTracking: any): void;
    recursiveCIDToString(components: any, cid: any, onlyCids: any): {
        buffer: string;
        streams: Set<any>;
    };
}
import { RenderingBuffer } from "./rendered/buffer";

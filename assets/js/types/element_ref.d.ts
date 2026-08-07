export default class ElementRef {
    static onUnlock(el: any, callback: any): any;
    private el;
    private loadingRef;
    private lockRef;
    constructor(el: Element);
    maybeUndo(ref: any, phxEvent: any, eachCloneCallback: any): void;
    private isWithin;
    private undoLocks;
    private undoLoading;
    private isLoadingUndoneBy;
    /** @internal */
    isLockUndoneBy(ref: any): boolean;
    private isFullyResolvedBy;
    private canUndoLoading;
}

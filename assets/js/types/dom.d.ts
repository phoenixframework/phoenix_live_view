import { type LogError } from "./diagnostics";
export type FormInputLike = HTMLElement & {
    readonly form?: HTMLFormElement | null;
    readonly type?: string;
    readonly validity?: ValidityState;
    readonly name?: string;
};
export type QueryableNode = Element | Document | DocumentFragment;
declare const DOM: {
    byId(id: any): void | HTMLElement;
    elementFromTarget(target: EventTarget): Element | null;
    removeClass(el: any, className: any): void;
    all(node: QueryableNode | null, query: string, callback?: (el: Element) => void): Element[];
    childNodeLength(html: any): number;
    isUploadInput(el: any): el is HTMLInputElement;
    isAutoUpload(inputEl: any): any;
    findUploadInputs(node: any): HTMLInputElement[];
    findComponent(viewId: string, cid: string | number, doc?: QueryableNode): Element | null;
    getComponent(viewId: string, cid: number, doc?: QueryableNode): Element;
    isPhxDestroyed(node: any): boolean;
    wantsNewTab(e: any): any;
    isUnloadableFormSubmit(e: any): boolean;
    isNewPageClick(e: any, currentLocation: any): any;
    markPhxChildDestroyed(el: any): void;
    findPhxChildrenInFragment(html: any, parentId: any): any;
    isIgnored(el: any, phxUpdate: any): boolean;
    isPhxUpdate(el: any, phxUpdate: any, updateTypes: any): boolean;
    findPhxSticky(el: any): any;
    findPhxChildren(el: any, parentId: any): any;
    findExistingParentCIDs(viewId: any, cids: any): Set<unknown>;
    private(el: any, key: any): any;
    deletePrivate(el: any, key: any): void;
    putPrivate(el: any, key: any, value: any): void;
    updatePrivate(el: any, key: any, defaultVal: any, updateFunc: any): void;
    syncPendingAttrs(fromEl: any, toEl: any): void;
    copyPrivates(target: any, source: any): void;
    putTitle(str: any): void;
    debounce(el: any, event: any, phxDebounce: any, defaultDebounce: any, phxThrottle: any, defaultThrottle: any, asyncFilter: any, callback: any): any;
    triggerCycle(el: any, key: any, currentCycle?: any): void;
    once(el: any, key: any): boolean;
    incCycle(el: any, key: any, trigger?: () => void): any;
    maintainPrivateHooks(fromEl: any, toEl: any, phxViewportTop: any, phxViewportBottom: any): void;
    putCustomElHook(el: any, hook: any): void;
    getCustomElHook(el: any): any;
    isUsedInput(el: any): any;
    resetForm(form: any): void;
    isPhxChild(node: any): any;
    isPhxSticky(node: any): boolean;
    isChildOfAny(el: any, parents: any): boolean;
    firstPhxChild(el: any): any;
    isPortalTemplate(el: any): el is HTMLTemplateElement;
    closestViewEl(el: any): any;
    dispatchEvent(target: any, name: any, opts?: {
        bubbles?: boolean;
        detail?: any;
    }): any;
    cloneNode(node: any, html: any): any;
    mergeAttrs(target: any, source: any, opts?: {
        exclude?: string[];
        isIgnored?: boolean;
    }): void;
    mergeFocusedInput(target: any, source: any): void;
    hasSelectionRange(el: any): el is HTMLInputElement | HTMLTextAreaElement;
    restoreFocus(focused: any, selectionStart: any, selectionEnd: any): void;
    /**
     * Returns true if the element is an input that can be focused and edited by the user,
     * so we can skip patching it if it has focus.
     */
    isEditableInput(el: Element | EventTarget | null): el is FormInputLike;
    isFormAssociated(el: Element | EventTarget | null): el is FormInputLike;
    syncAttrsToProps(el: any): void;
    isTextualInput(el: any): boolean;
    isNowTriggerFormExternal(el: any, phxTriggerExternal: any): boolean;
    cleanChildNodes(container: Element, phxUpdate: string, reportError?: LogError): void;
    replaceRootContainer(container: Element, tagName: string, attrs: Record<string, string>): Element;
    getSticky(el: any, name: any, defaultVal: any): any;
    deleteSticky(el: any, name: any): void;
    putSticky(el: any, name: any, op: any): void;
    applyStickyOperations(el: any): void;
    isLocked(el: any): any;
    attributeIgnored(attribute: any, ignoredAttributes: any): any;
};
export default DOM;

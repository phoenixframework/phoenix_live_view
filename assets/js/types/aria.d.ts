declare const ARIA: {
    anyOf(instance: unknown, classes: (new (...args: any[]) => unknown)[]): boolean;
    isFocusable(el: Element, interactiveOnly?: boolean): boolean;
    attemptFocus(el: Element, interactiveOnly?: boolean): boolean;
    focusFirstInteractive(el: Element): boolean;
    focusFirst(el: Element): boolean;
    focusLast(el: Element): boolean;
};
export default ARIA;

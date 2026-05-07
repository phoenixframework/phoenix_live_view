const ARIA = {
  anyOf(instance: unknown, classes: (new (...args: any[]) => unknown)[]): boolean {
    return classes.some((name) => instance instanceof name);
  },

  isFocusable(el: Element, interactiveOnly = false): boolean {
    return (
      (el instanceof HTMLAnchorElement && el.rel !== "ignore") ||
      (el instanceof HTMLAreaElement && el.href !== undefined) ||
      (!("disabled" in el && el.disabled) &&
        this.anyOf(el, [
          HTMLInputElement,
          HTMLSelectElement,
          HTMLTextAreaElement,
          HTMLButtonElement,
        ])) ||
      el instanceof HTMLIFrameElement ||
      (el instanceof HTMLElement &&
        el.tabIndex >= 0 &&
        el.getAttribute("aria-hidden") !== "true") ||
      (!interactiveOnly &&
        el.getAttribute("tabindex") !== null &&
        el.getAttribute("aria-hidden") !== "true")
    );
  },

  attemptFocus(el: Element, interactiveOnly = false): boolean {
    if (this.isFocusable(el, interactiveOnly)) {
      try {
        (el as HTMLElement).focus();
      } catch {
        // that's fine
      }
    }
    return !!document.activeElement && document.activeElement.isSameNode(el);
  },

  focusFirstInteractive(el: Element): boolean {
    let child = el.firstElementChild;
    while (child) {
      if (this.attemptFocus(child, true) || this.focusFirstInteractive(child)) {
        return true;
      }
      child = child.nextElementSibling;
    }
    return false;
  },

  focusFirst(el: Element): boolean {
    let child = el.firstElementChild;
    while (child) {
      if (this.attemptFocus(child) || this.focusFirst(child)) {
        return true;
      }
      child = child.nextElementSibling;
    }
    return false;
  },

  focusLast(el: Element): boolean {
    let child = el.lastElementChild;
    while (child) {
      if (this.attemptFocus(child) || this.focusLast(child)) {
        return true;
      }
      child = child.previousElementSibling;
    }
    return false;
  },
};
export default ARIA;

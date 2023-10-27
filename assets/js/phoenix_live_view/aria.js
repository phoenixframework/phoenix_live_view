/**
 * Utilities for accessibility behaviors and affordances
 */
let ARIA = {
  /**
   * Focus a main element of the page
   */
  focusMain(){
    let target = document.querySelector("main h1, main, h1")
    if(target){
      let origTabIndex = target.tabIndex
      target.tabIndex = -1
      target.focus()
      target.tabIndex = origTabIndex
    }
  },

  /**
   * Find the first class in the collection that the given object is an instance of.
   * @param {object} instance 
   * @param {object[]} classes 
   * @returns {object | null}
   */
  anyOf(instance, classes){ return classes.find(name => instance instanceof name) },

  /**
   * Can the element be focused?
   * @param {Element} el 
   * @param {boolean} [interactiveOnly] 
   * @returns {boolean}
   */
  isFocusable(el, interactiveOnly){
    return (
      (el instanceof HTMLAnchorElement && el.rel !== "ignore") ||
      (el instanceof HTMLAreaElement && el.href !== undefined) ||
      (!el.disabled && (this.anyOf(el, [HTMLInputElement, HTMLSelectElement, HTMLTextAreaElement, HTMLButtonElement]))) ||
      (el instanceof HTMLIFrameElement) ||
      (el.tabIndex > 0 || (!interactiveOnly && el.tabIndex === 0 && el.getAttribute("tabindex") !== null && el.getAttribute("aria-hidden") !== "true"))
    )
  },

  /**
   * Focus the given element, reporting the result.
   * @param {Element} el 
   * @param {boolean} [interactiveOnly] 
   * @returns {boolean} Is the given element now focused?
   */
  attemptFocus(el, interactiveOnly){
    /* eslint-disable-next-line no-empty */
    if(this.isFocusable(el, interactiveOnly)){ try { el.focus() } catch (e){} }
    return !!document.activeElement && document.activeElement.isSameNode(el)
  },

  /**
   * Focus the first interactive child element; depth-first search
   * @param {Element} el 
   * @returns {boolean}
   */
  focusFirstInteractive(el){
    let child = el.firstElementChild
    while(child){
      if(this.attemptFocus(child, true) || this.focusFirstInteractive(child, true)){
        return true
      }
      child = child.nextElementSibling
    }
  },

  /**
   * Focus the first child element; depth-first search
   * @param {Element} el 
   * @returns {boolean} Is the given element now focused?
   */
  focusFirst(el){
    let child = el.firstElementChild
    while(child){
      if(this.attemptFocus(child) || this.focusFirst(child)){
        return true
      }
      child = child.nextElementSibling
    }
  },

  /**
   * Focus the last child; depth-first search
   * @param {Element} el 
   * @returns {boolean} Is the given element now focused?
   */
  focusLast(el){
    let child = el.lastElementChild
    while(child){
      if(this.attemptFocus(child) || this.focusLast(child)){
        return true
      }
      child = child.previousElementSibling
    }
  }
}

export default ARIA

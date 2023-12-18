let ARIA = {
  focusMain(){
    let target = document.querySelector("main h1, main, h1")
    if(target){
      let origTabIndex = target.tabIndex
      target.tabIndex = -1
      target.focus()
      target.tabIndex = origTabIndex
    }
  },

  anyOf(instance, classes){ return classes.find(name => instance instanceof name) },

  isFocusable(el, interactiveOnly){
    return(
      (el instanceof HTMLAnchorElement && el.rel !== "ignore") ||
      (el instanceof HTMLAreaElement && el.href !== undefined) ||
      (!el.disabled && (this.anyOf(el, [HTMLInputElement, HTMLSelectElement, HTMLTextAreaElement, HTMLButtonElement]))) ||
      (el instanceof HTMLIFrameElement) ||
      (el.tabIndex > 0 || (!interactiveOnly && el.getAttribute("tabindex") !== null && el.getAttribute("aria-hidden") !== "true"))
    )
  },

  attemptFocus(el, interactiveOnly){
    if(this.isFocusable(el, interactiveOnly)){ try{ el.focus() } catch(e){} }
    return !!document.activeElement && document.activeElement.isSameNode(el)
  },

  focusFirstInteractive(el){
    let child = el.firstElementChild
    while(child){
      if(this.attemptFocus(child, true) || this.focusFirstInteractive(child, true)){
        return true
      }
      child = child.nextElementSibling
    }
  },

  focusFirst(el){
    let child = el.firstElementChild
    while(child){
      if(this.attemptFocus(child) || this.focusFirst(child)){
        return true
      }
      child = child.nextElementSibling
    }
  },

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
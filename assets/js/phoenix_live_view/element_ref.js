import {
  PHX_REF_LOADING,
  PHX_REF_LOCK,
  PHX_REF_SRC,
  PHX_EVENT_CLASSES,
  PHX_DISABLED,
  PHX_READONLY,
  PHX_DISABLE_WITH_RESTORE
} from "./constants"

import DOM from "./dom"

export default class ElementRef {
  constructor(el){
    this.el = el
    this.loadingRef = el.hasAttribute(PHX_REF_LOADING) ? parseInt(el.getAttribute(PHX_REF_LOADING), 10) : null
    this.lockRef = el.hasAttribute(PHX_REF_LOCK) ? parseInt(el.getAttribute(PHX_REF_LOCK), 10) : null
  }

  // public

  maybeUndo(ref, eachCloneCallback){
    if(!this.isWithin(ref)){ return }

    // undo locks and apply clones
    this.undoLocks(ref, eachCloneCallback)

    // undo loading states
    this.undoLoading(ref)

    // clean up if fully resolved
    if(this.isFullyResolvedBy(ref)){ this.el.removeAttribute(PHX_REF_SRC) }
  }

  // private

  isWithin(ref){
    return !((this.loadingRef !== null && this.loadingRef > ref) && (this.lockRef !== null && this.lockRef > ref))
  }

  // Check for cloned PHX_REF_LOCK element that has been morphed behind
  // the scenes while this element was locked in the DOM.
  // When we apply the cloned tree to the active DOM element, we must
  //
  //   1. execute pending mounted hooks for nodes now in the DOM
  //   2. undo any ref inside the cloned tree that has since been ack'd
  undoLocks(ref, eachCloneCallback){
    if(!this.isLockUndoneBy(ref)){ return }

    let clonedTree = DOM.private(this.el, PHX_REF_LOCK)
    if(clonedTree){
      eachCloneCallback(clonedTree)
      DOM.deletePrivate(this.el, PHX_REF_LOCK)
    }
    this.el.removeAttribute(PHX_REF_LOCK)
    this.el.dispatchEvent(new CustomEvent("phx:unlock", {bubbles: true, cancelable: false}))
  }

  undoLoading(ref){
    if(!this.isLoadingUndoneBy(ref)){
      if(this.canUndoLoading(ref) && this.el.classList.contains("phx-submit-loading")){
        this.el.classList.remove("phx-change-loading")
      }
      return
    }

    if(this.canUndoLoading(ref)){
      this.el.removeAttribute(PHX_REF_LOADING)
      let disabledVal = this.el.getAttribute(PHX_DISABLED)
      let readOnlyVal = this.el.getAttribute(PHX_READONLY)
      // restore inputs
      if(readOnlyVal !== null){
        this.el.readOnly = readOnlyVal === "true" ? true : false
        this.el.removeAttribute(PHX_READONLY)
      }
      if(disabledVal !== null){
        this.el.disabled = disabledVal === "true" ? true : false
        this.el.removeAttribute(PHX_DISABLED)
      }
      // restore disables
      let disableRestore = this.el.getAttribute(PHX_DISABLE_WITH_RESTORE)
      if(disableRestore !== null){
        this.el.innerText = disableRestore
        this.el.removeAttribute(PHX_DISABLE_WITH_RESTORE)
      }
    }
    // remove classes
    PHX_EVENT_CLASSES.forEach(name => {
      if(name !== "phx-submit-loading" || this.canUndoLoading(ref)){
        DOM.removeClass(this.el, name)
      }
    })
  }

  isLoadingUndoneBy(ref){ return this.loadingRef === null ? false : this.loadingRef <= ref }
  isLockUndoneBy(ref){ return this.lockRef === null ? false : this.lockRef <= ref }

  isFullyResolvedBy(ref){
    return (this.loadingRef === null || this.loadingRef <= ref) && (this.lockRef === null || this.lockRef <= ref)
  }

  // only remove the phx-submit-loading class if we are not locked
  canUndoLoading(ref){ return this.lockRef === null || this.lockRef <= ref }
}
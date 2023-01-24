import {
  PHX_ACTIVE_ENTRY_REFS,
  PHX_LIVE_FILE_UPDATED,
  PHX_PREFLIGHTED_REFS,
  PHX_UPLOAD_REF
} from "./constants"

import LiveUploader from "./live_uploader"
import ARIA from "./aria"

let Hooks = {
  LiveFileUpload: {
    activeRefs(){ return this.el.getAttribute(PHX_ACTIVE_ENTRY_REFS) },

    preflightedRefs(){ return this.el.getAttribute(PHX_PREFLIGHTED_REFS) },

    mounted(){ this.preflightedWas = this.preflightedRefs() },

    updated(){
      let newPreflights = this.preflightedRefs()
      if(this.preflightedWas !== newPreflights){
        this.preflightedWas = newPreflights
        if(newPreflights === ""){
          this.__view.cancelSubmit(this.el.form)
        }
      }

      if(this.activeRefs() === ""){ this.el.value = null }
      this.el.dispatchEvent(new CustomEvent(PHX_LIVE_FILE_UPDATED))
    }
  },

  LiveImgPreview: {
    mounted(){
      this.ref = this.el.getAttribute("data-phx-entry-ref")
      this.inputEl = document.getElementById(this.el.getAttribute(PHX_UPLOAD_REF))
      LiveUploader.getEntryDataURL(this.inputEl, this.ref, url => {
        this.url = url
        this.el.src = url
      })
    },
    destroyed(){
      URL.revokeObjectURL(this.url)
    }
  },
  FocusWrap: {
    mounted(){
      this.focusStart = this.el.firstElementChild
      this.focusEnd = this.el.lastElementChild
      this.focusStart.addEventListener("focus", () => ARIA.focusLast(this.el))
      this.focusEnd.addEventListener("focus", () => ARIA.focusFirst(this.el))
      this.el.addEventListener("phx:show-end", () => this.el.focus())
      if(window.getComputedStyle(this.el).display !== "none"){
        ARIA.focusFirst(this.el)
      }
    }
  }
}

export default Hooks

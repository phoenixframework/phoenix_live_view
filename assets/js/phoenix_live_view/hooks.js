import {
  PHX_PREFLIGHTED_REFS,
  PHX_UPLOAD_REF
} from "./constants"

import LiveUploader from "./live_uploader"

let Hooks = {
  LiveFileUpload: {
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
    }
  },

  LiveImgPreview: {
    mounted(){
      this.ref = this.el.getAttribute("data-phx-entry-ref")
      this.inputEl = document.getElementById(this.el.getAttribute(PHX_UPLOAD_REF))
      LiveUploader.getEntryDataURL(this.inputEl, this.ref, url => {
        this.url = url
        let img = document.createElement("img")
        this.el.insertBefore(img, this.el.querySelector("figcaption") || null)
        img.src = url
      })
    },
    destroyed(){
      URL.revokeObjectURL(this.url)
    }
  }
}

export default Hooks

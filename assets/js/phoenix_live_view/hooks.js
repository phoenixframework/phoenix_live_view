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

let scrollTop = () => document.documentElement.scrollTop || document.body.scrollTop
let winHeight = () => window.innerHeight || document.documentElement.clientHeight

let isAtViewportTop = (el) => {
  let rect = el.getBoundingClientRect()
  return rect.top >= 0 && rect.left >= 0 && rect.top <= winHeight()
}

let isAtViewportBottom = (el) => {
  let rect = el.getBoundingClientRect()
  return rect.right >= 0 && rect.bottom <= winHeight()
}

Hooks.InfiniteScroll = {
  mounted(){
    let scrollBefore = scrollTop()
    let onPendingScroll
    this.onScroll = (e) => {
      let scrollNow = scrollTop()

      if(onPendingScroll){
        scrollBefore = scrollNow
        onPendingScroll && onPendingScroll()
      }

      let topEvent = this.el.getAttribute(this.liveSocket.binding("viewport-top"))
      let bottomEvent = this.el.getAttribute(this.liveSocket.binding("viewport-bottom"))
      let lastChild = this.el.lastElementChild
      let firstChild = this.el.firstElementChild
      if(topEvent && scrollNow < scrollBefore && isAtViewportTop(firstChild)){
        this.throttle(e, () => {
          onPendingScroll = () => firstChild.scrollIntoView(true)
          this.liveSocket.execJSHookPush(this.el, topEvent, {id: firstChild.id}, () => {
            onPendingScroll = null
            firstChild.scrollIntoView({block: "center", inline: "nearest"})
          })
        })
      } else if(bottomEvent && scrollNow > scrollBefore && isAtViewportBottom(lastChild)){
        this.throttle(e, () => {
          onPendingScroll = () => true
          this.liveSocket.execJSHookPush(this.el, bottomEvent, {id: lastChild.id}, () => {
            onPendingScroll = null
            lastChild.scrollIntoView({block: "center"})
          })
        })
      }
      scrollBefore = scrollNow
    }
    window.addEventListener("scroll", this.onScroll)
  },
  destroyed(){ window.removeEventListener("scroll", this.onScroll) },

  throttle(e, callback){
    let attr = this.liveSocket.binding("throttle")
    if(!this.el.hasAttribute(attr)){ this.el.setAttribute(attr, 250) }
    this.liveSocket.debounce(this.el, e, "scroll", callback)
  }
}
export default Hooks

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
  return rect.right >= 0 && rect.left >= 0 && rect.bottom <= winHeight()
}

let isWithinViewport = (el) => {
  let rect = el.getBoundingClientRect()
  return rect.top >= 0 && rect.left >= 0 && rect.top <= winHeight()
}

Hooks.InfiniteScroll = {
  mounted(){
    let scrollBefore = scrollTop()
    let topOverran = false
    let throttleInterval = 500
    let pendingOp = null

    let onTopOverrun = this.throttle(throttleInterval, (topEvent, firstChild) => {
      pendingOp = () => true
      this.liveSocket.execJSHookPush(this.el, topEvent, {id: firstChild.id, _overran: true}, () => {
        pendingOp = null
      })
    })

    let onFirstChildAtTop = this.throttle(throttleInterval, (topEvent, firstChild) => {
      pendingOp = () => firstChild.scrollIntoView({block: "start"})
      this.liveSocket.execJSHookPush(this.el, topEvent, {id: firstChild.id}, () => {
        pendingOp = null
        if(!isWithinViewport(firstChild)){ firstChild.scrollIntoView({block: "start"}) }
      })
    })

    let onLastChildAtBottom = this.throttle(throttleInterval, (bottomEvent, lastChild) => {
      pendingOp = () => lastChild.scrollIntoView({block: "end"})
      this.liveSocket.execJSHookPush(this.el, bottomEvent, {id: lastChild.id}, () => {
        pendingOp = null
        if(!isWithinViewport(lastChild)){ lastChild.scrollIntoView({block: "end"}) }
      })
    })

    this.onScroll = (e) => {
      let scrollNow = scrollTop()

      if(pendingOp){
        scrollBefore = scrollNow
        return pendingOp()
      }
      let rect = this.el.getBoundingClientRect()
      let topEvent = this.el.getAttribute(this.liveSocket.binding("viewport-top"))
      let bottomEvent = this.el.getAttribute(this.liveSocket.binding("viewport-bottom"))
      let lastChild = this.el.lastElementChild
      let firstChild = this.el.firstElementChild
      let isScrollingUp = scrollNow < scrollBefore
      let isScrollingDown = scrollNow > scrollBefore

      // el overran while scrolling up
      if(isScrollingUp && topEvent && !topOverran && rect.top >= 0){
        topOverran = true
        onTopOverrun(topEvent, firstChild)
      } else if(isScrollingDown && topOverran && rect.top <= 0){
        topOverran = false
      }

      if(topEvent && isScrollingUp && isAtViewportTop(firstChild)){
        onFirstChildAtTop(topEvent, firstChild)
      } else if(bottomEvent && isScrollingDown && isAtViewportBottom(lastChild)){
        onLastChildAtBottom(bottomEvent, lastChild)
      }
      scrollBefore = scrollNow
    }
    window.addEventListener("scroll", this.onScroll)
  },
  destroyed(){ window.removeEventListener("scroll", this.onScroll) },

  throttle(interval, callback){
    let lastCallAt = 0
    let timer

    return (...args) => {
      let now = Date.now()
      let remainingTime = interval - (now - lastCallAt)

      if(remainingTime <= 0 || remainingTime > interval){
        if(timer) {
          clearTimeout(timer)
          timer = null
        }
        lastCallAt = now
        callback(...args)
      } else if(!timer){
        timer = setTimeout(() => {
          lastCallAt = Date.now()
          timer = null
          callback(...args)
        }, remainingTime)
      }
    }
  }
}
export default Hooks

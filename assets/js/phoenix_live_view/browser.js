import {
  LINK_HEADER,
  PUSH_TIMEOUT,
  RESPONSE_URL_HEADER
} from "phoenix_live_view/constants"

import {
  maybe
} from "phoenix_live_view/utils"

let Browser = {
  canPushState(){ return (typeof (history.pushState) !== "undefined") },

  dropLocal(localStorage, namespace, subkey){
    return localStorage.removeItem(this.localKey(namespace, subkey))
  },

  updateLocal(localStorage, namespace, subkey, initial, func){
    let current = this.getLocal(localStorage, namespace, subkey)
    let key = this.localKey(namespace, subkey)
    let newVal = current === null ? initial : func(current)
    localStorage.setItem(key, JSON.stringify(newVal))
    return newVal
  },

  getLocal(localStorage, namespace, subkey){
    return JSON.parse(localStorage.getItem(this.localKey(namespace, subkey)))
  },

  fetchPage(href, callback){
    let req = new XMLHttpRequest()
    req.open("GET", href, true)
    req.timeout = PUSH_TIMEOUT
    req.setRequestHeader("content-type", "text/html")
    req.setRequestHeader("cache-control", "max-age=0, no-cache, no-store, must-revalidate, post-check=0, pre-check=0")
    req.setRequestHeader(LINK_HEADER, "live-link")
    req.onerror = () => callback(400)
    req.ontimeout = () => callback(504)
    req.onreadystatechange = () => {
      if(req.readyState !== 4){ return }
      let requestURL = new URL(href)
      let requestPath = requestURL.pathname + requestURL.search
      let responseURL = maybe(req.getResponseHeader(RESPONSE_URL_HEADER) || req.responseURL, url => new URL(url))
      let responsePath = responseURL ? responseURL.pathname + responseURL.search : null
      if(req.getResponseHeader(LINK_HEADER) !== "live-link"){
        return callback(400)
      } else if(responseURL === null || responsePath != requestPath){
        return callback(302)
      } else if(req.status !== 200){
        return callback(req.status)
      } else {
        callback(200, req.responseText)
      }
    }
    req.send()
  },

  updateCurrentState(callback){
    if(!this.canPushState()){ return }
    history.replaceState(callback(history.state || {}), "", window.location.href)
  },

  pushState(kind, meta, to){
    if(this.canPushState()){
      if(to !== window.location.href){
        if(meta.type == "redirect" && meta.scroll){
          // If we're redirecting store the current scrollY for the current history state.
          let currentState = history.state || {}
          currentState.scroll = meta.scroll
          history.replaceState(currentState, "", window.location.href)
        }

        delete meta.scroll // Only store the scroll in the redirect case.
        history[kind + "State"](meta, "", to || null) // IE will coerce undefined to string
        let hashEl = this.getHashTargetEl(window.location.hash)

        if(hashEl){
          hashEl.scrollIntoView()
        } else if(meta.type === "redirect"){
          window.scroll(0, 0)
        }
      }
    } else {
      this.redirect(to)
    }
  },

  setCookie(name, value){
    document.cookie = `${name}=${value}`
  },

  getCookie(name){
    return document.cookie.replace(new RegExp(`(?:(?:^|.*;\s*)${name}\s*\=\s*([^;]*).*$)|^.*$`), "$1")
  },

  redirect(toURL, flash){
    if(flash){ Browser.setCookie("__phoenix_flash__", flash + "; max-age=60000; path=/") }
    window.location = toURL
  },

  localKey(namespace, subkey){ return `${namespace}-${subkey}` },

  getHashTargetEl(maybeHash){
    let hash = maybeHash.toString().substring(1)
    if(hash === ""){ return }
    return document.getElementById(hash) || document.querySelector(`a[name="${hash}"]`)
  }
}

export default Browser
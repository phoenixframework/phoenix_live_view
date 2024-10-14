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

        // when using navigate, we'd call pushState immediately before patching the DOM,
        // jumping back to the top of the page, effectively ignoring the scrollIntoView;
        // therefore we wait for the next frame (after the DOM patch) and only then try
        // to scroll to the hashEl
        window.requestAnimationFrame(() => {
          let hashEl = this.getHashTargetEl(window.location.hash)
  
          if(hashEl){
            hashEl.scrollIntoView()
          } else if(meta.type === "redirect"){
            window.scroll(0, 0)
          }
        })
      }
    } else {
      this.redirect(to)
    }
  },

  setCookie(name, value, maxAgeSeconds){
    let expires = typeof(maxAgeSeconds) === "number" ? ` max-age=${maxAgeSeconds};` : ""
    document.cookie = `${name}=${value};${expires} path=/`
  },

  getCookie(name){
    return document.cookie.replace(new RegExp(`(?:(?:^|.*;\s*)${name}\s*\=\s*([^;]*).*$)|^.*$`), "$1")
  },

  deleteCookie(name){
    document.cookie = `${name}=; max-age=-1; path=/`
  },

  redirect(toURL, flash){
    if(flash){ this.setCookie("__phoenix_flash__", flash, 60) }
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

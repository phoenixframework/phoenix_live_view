let Browser = {
  /**
   * Does browser support pushState feature of the History API?
   * @returns {boolean}
   */
  canPushState(){ return (typeof (history.pushState) !== "undefined") },

  /**
   * Remove item from local storage
   * @param {Storage} localStorage 
   * @param {string} namespace 
   * @param {string} subkey 
   */
  dropLocal(localStorage, namespace, subkey){
    return localStorage.removeItem(this.localKey(namespace, subkey))
  },

  /**
   * Update item in local storage
   * @template T
   * @param {Storage} localStorage 
   * @param {string} namespace 
   * @param {string} subkey 
   * @param {T} initial - value to set if first save
   * @param {(current: T) => T} func - updating function; receives current, JSON-parsed value of store item and saves the JSON-stringified return value;
   * @returns {T}
   */
  updateLocal(localStorage, namespace, subkey, initial, func){
    let current = this.getLocal(localStorage, namespace, subkey)
    let key = this.localKey(namespace, subkey)
    let newVal = current === null ? initial : func(current)
    localStorage.setItem(key, JSON.stringify(newVal))
    return newVal
  },

  /**
   * Read item from local storage. NOTE: will parse as JSON; might throw
   * @param {Storage} localStorage 
   * @param {string} namespace 
   * @param {string} subkey 
   * @returns {any}
   */
  getLocal(localStorage, namespace, subkey){
    return JSON.parse(localStorage.getItem(this.localKey(namespace, subkey)))
  },

  /**
   * Replace current history state data without navigating 
   * @param {(currentState: any) => any} callback 
   */
  updateCurrentState(callback){
    if(!this.canPushState()){ return }
    history.replaceState(callback(history.state || {}), "", window.location.href)
  },

  /**
   * Perform history state change to URL
   * @param {("push"|"replace")} kind 
   * @param {{type: string, scroll: number|undefined, root: boolean, id: string}} meta 
   * @param {string} to - URL of destination
   */
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

  /**
   * Set document cookie value
   * @param {string} name 
   * @param {string} value 
   */
  setCookie(name, value){
    document.cookie = `${name}=${value}`
  },

  /**
   * Get value from cookie
   * @param {string} name 
   * @returns {string}
   */
  getCookie(name){
    return document.cookie.replace(new RegExp(`(?:(?:^|.*;\s*)${name}\s*\=\s*([^;]*).*$)|^.*$`), "$1")
  },

  /**
   * Redirect to URL and set flash message if given
   * @param {string} toURL 
   * @param {string} [flash] 
   */
  redirect(toURL, flash){
    if(flash){ Browser.setCookie("__phoenix_flash__", flash + "; max-age=60000; path=/") }
    window.location = toURL
  },

  /**
   * Get the namespaced key for use in browser Storage API
   * @param {string} namespace 
   * @param {string} subkey 
   * @returns {string}
   */
  localKey(namespace, subkey){ return `${namespace}-${subkey}` },

  /**
   * Find element target of the URL hash segment, if it exists
   * @param {string} maybeHash 
   * @returns {HTMLElement|null}
   */
  getHashTargetEl(maybeHash){
    let hash = maybeHash.toString().substring(1)
    if(hash === ""){ return }
    return document.getElementById(hash) || document.querySelector(`a[name="${hash}"]`)
  }
}

export default Browser

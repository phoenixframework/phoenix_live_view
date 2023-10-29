import {
  CHECKABLE_INPUTS,
  DEBOUNCE_PREV_KEY,
  DEBOUNCE_TRIGGER,
  FOCUSABLE_INPUTS,
  PHX_COMPONENT,
  PHX_EVENT_CLASSES,
  PHX_HAS_FOCUSED,
  PHX_HAS_SUBMITTED,
  PHX_MAIN,
  PHX_NO_FEEDBACK_CLASS,
  PHX_PARENT_ID,
  PHX_PRIVATE,
  PHX_REF,
  PHX_REF_SRC,
  PHX_ROOT_ID,
  PHX_SESSION,
  PHX_STATIC,
  PHX_UPLOAD_REF,
  PHX_VIEW_SELECTOR,
  PHX_STICKY,
  THROTTLED
} from "./constants"

import {
  logError
} from "./utils"

/**
 * Wrappers around common DOM APIs for traversal and mutation
 */
let DOM = {
  /**
   * Find Element by ID
   * @param {string} id 
   * @returns {HTMLElement|null}
   */
  byId(id){ return document.getElementById(id) || logError(`no id found for ${id}`) },

  /**
   * Remove class from element
   * @param {HTMLElement} el 
   * @param {string} className 
   */
  removeClass(el, className){
    el.classList.remove(className)
    if(el.classList.length === 0){ el.removeAttribute("class") }
  },

  /**
   * @typedef {(value: Element, index: number, array: Element[])=>void} ElementCallback
   */

  /**
   * Execute callback for each child of node matching CSS selector
   * 
   * @template {ElementCallback|undefined} T
   * @param {ParentNode} node - a DOM node to search underneath
   * @param {string} query - a CSS selector
   * @param {T} callback - the callback to operate
   * @returns {[T] extends [ElementCallback] ? undefined : HTMLElement[] }
   */
  all(node, query, callback){
    if(!node){ return [] }
    let array = Array.from(node.querySelectorAll(query))
    return callback ? array.forEach(callback) : array
  },

  /**
   * Count the child nodes of HTML fragment
   * @param {string} html - HTML fragment
   * @returns {number}
   */
  childNodeLength(html){
    let template = document.createElement("template")
    template.innerHTML = html
    return template.content.childElementCount
  },

  /**
   * Is this input a tracked file upload input?
   * @param {HTMLInputElement} el 
   * @returns {boolean}
   */
  isUploadInput(el){ return el.type === "file" && el.getAttribute(PHX_UPLOAD_REF) !== null },

  /**
   * Is this input a phoenix auto-uploading input?
   * @param {HTMLInputElement} inputEl 
   * @returns {boolean}
   */
  isAutoUpload(inputEl){ return inputEl.hasAttribute("data-phx-auto-upload") },

  /**
   * Select all child nodes that are file inputs
   * @param {HTMLElement} node 
   * @returns {HTMLInputElement[]}
   */
  findUploadInputs(node){ return this.all(node, `input[type="file"][${PHX_UPLOAD_REF}]`) },

  /**
   * Find nodes within component
   * @param {HTMLElement} node 
   * @param {number|string} cid 
   * @returns {HTMLElement[]}
   */
  findComponentNodeList(node, cid){
    return this.filterWithinSameLiveView(this.all(node, `[${PHX_COMPONENT}="${cid}"]`), node)
  },

  /**
   * Has this node been marked by phoenix as destroyed?
   * @param {HTMLElement} node 
   * @returns {boolean}
   */
  isPhxDestroyed(node){
    return node.id && DOM.private(node, "destroyed") ? true : false
  },

  /**
   * Did the user perform a well-known gesture to open a link in a new tab?
   * @param {Event} e 
   * @returns {boolean}
   */
  wantsNewTab(e){
    let wantsNewTab = e.ctrlKey || e.shiftKey || e.metaKey || (e.button && e.button === 1)
    let isDownload = (e.target instanceof HTMLAnchorElement && e.target.hasAttribute("download"))
    let isTargetBlank = e.target.hasAttribute("target") && e.target.getAttribute("target").toLowerCase() === "_blank"
    return wantsNewTab || isTargetBlank || isDownload
  },

  /**
   * Did the user submit a form that is unloadable?
   * @param {Event} e 
   * @returns {boolean}
   */
  isUnloadableFormSubmit(e){
    // Ignore form submissions intended to close a native <dialog> element
    // https://developer.mozilla.org/en-US/docs/Web/HTML/Element/dialog#usage_notes
    let isDialogSubmit = (e.target && e.target.getAttribute("method") === "dialog") ||
      (e.submitter && e.submitter.getAttribute("formmethod") === "dialog")

    if(isDialogSubmit){
      return false
    } else {
      return !e.defaultPrevented && !this.wantsNewTab(e)
    }
  },

  /**
   * Did the user click a link that navigates somewhere else?
   * @param {Event} e 
   * @param {Location} currentLocation 
   * @returns {boolean}
   */
  isNewPageClick(e, currentLocation){
    let href = e.target instanceof HTMLAnchorElement ? e.target.getAttribute("href") : null
    let url

    if(e.defaultPrevented || href === null || this.wantsNewTab(e)){ return false }
    if(href.startsWith("mailto:") || href.startsWith("tel:")){ return false }
    if(e.target.isContentEditable){ return false }

    try {
      url = new URL(href)
    } catch (e){
      try {
        url = new URL(href, currentLocation)
      } catch (e){
        // bad URL, fallback to let browser try it as external
        return true
      }
    }

    if(url.host === currentLocation.host && url.protocol === currentLocation.protocol){
      if(url.pathname === currentLocation.pathname && url.search === currentLocation.search){
        return url.hash === "" && !url.href.endsWith("#")
      }
    }
    return url.protocol.startsWith("http")
  },

  /**
   * Mark element as phoenix destroyed
   * @param {HTMLElement} el 
   */
  markPhxChildDestroyed(el){
    if(this.isPhxChild(el)){ el.setAttribute(PHX_SESSION, "") }
    this.putPrivate(el, "destroyed", true)
  },

  /**
   * Find all children of a specific phoenix view in the given HTML fragment
   * @param {string} html 
   * @param {string} parentId 
   * @returns 
   */
  findPhxChildrenInFragment(html, parentId){
    let template = document.createElement("template")
    template.innerHTML = html
    return this.findPhxChildren(template.content, parentId)
  },

  /**
   * Is this node ignored from phoenix updates?
   * @param {HTMLElement} el 
   * @param {string} phxUpdate 
   * @returns {boolean}
   */
  isIgnored(el, phxUpdate){
    return (el.getAttribute(phxUpdate) || el.getAttribute("data-phx-update")) === "ignore"
  },

  /**
   * Is this node marked for phoenix updates?
   * @param {HTMLElement} el 
   * @param {string} phxUpdate 
   * @param {string[]} updateTypes 
   * @returns 
   */
  isPhxUpdate(el, phxUpdate, updateTypes){
    return el.getAttribute && updateTypes.indexOf(el.getAttribute(phxUpdate)) >= 0
  },

  /**
   * Find child elements marked as phx-sticky
   * @param {HTMLElement} el 
   * @returns {HTMLElement[]}
   */
  findPhxSticky(el){ return this.all(el, `[${PHX_STICKY}]`) },

  /**
   * Find all children of a given phoenix view's element
   * @param {HTMLElement} el 
   * @param {string} parentId 
   * @returns {HTMLElement[]}
   */
  findPhxChildren(el, parentId){
    return this.all(el, `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${parentId}"]`)
  },

  /**
   * Find all IDs for parent components of this node
   * @param {parentNode} node 
   * @param {(string|number)[]} cids 
   * @returns {Set<string|number>}
   */
  findParentCIDs(node, cids){
    let initial = new Set(cids)
    let parentCids =
      cids.reduce((acc, cid) => {
        let selector = `[${PHX_COMPONENT}="${cid}"] [${PHX_COMPONENT}]`

        this.filterWithinSameLiveView(this.all(node, selector), node)
          .map(el => parseInt(el.getAttribute(PHX_COMPONENT)))
          .forEach(childCID => acc.delete(childCID))

        return acc
      }, initial)

    return parentCids.size === 0 ? new Set(cids) : parentCids
  },

  /**
   * Filter the given element nodes to only those within the given parent
   * @param {HTMLElement[]} nodes 
   * @param {HTMLElement} parent 
   * @returns {HTMLElement[]}
   */
  filterWithinSameLiveView(nodes, parent){
    if(parent.querySelector(PHX_VIEW_SELECTOR)){
      return nodes.filter(el => this.withinSameLiveView(el, parent))
    } else {
      return nodes
    }
  },

  /**
   * Is given node within the given parent?
   * @param {HTMLElement} node 
   * @param {HTMLElement} parent 
   * @returns {boolean}
   */
  withinSameLiveView(node, parent){
    while(node = node.parentNode){
      if(node.isSameNode(parent)){ return true }
      if(node.getAttribute(PHX_SESSION) !== null){ return false }
    }
  },

  /**
   * Get the value stored in the phoenix private data on the DOM node
   * @param {HTMLElement} el 
   * @param {string} key 
   * @returns {any}
   */
  private(el, key){ return el[PHX_PRIVATE] && el[PHX_PRIVATE][key] },

  /**
   * Delete the value stored in the phoenix private data on the DOM node
   * @param {HTMLElement} el 
   * @param {string} key 
   * @returns {any}
   */
  deletePrivate(el, key){ el[PHX_PRIVATE] && delete (el[PHX_PRIVATE][key]) },

  /**
   * Set the value at key in the phoenix private data on the DOM node
   * @param {HTMLElement} el 
   * @param {string} key 
   * @param {any} value 
   */
  putPrivate(el, key, value){
    if(!el[PHX_PRIVATE]){ el[PHX_PRIVATE] = {} }
    el[PHX_PRIVATE][key] = value
  },

  /**
   * Update the value at key in the phoenix private data on the DOM node with a function
   * @param {HTMLElement} el 
   * @param {string} key 
   * @param {any} defaultVal 
   * @param {function} updateFunc 
   */
  updatePrivate(el, key, defaultVal, updateFunc){
    let existing = this.private(el, key)
    if(existing === undefined){
      this.putPrivate(el, key, updateFunc(defaultVal))
    } else {
      this.putPrivate(el, key, updateFunc(existing))
    }
  },

  /**
   * Copy private phoenix data bag from one element to another
   * @param {HTMLElement} target 
   * @param {HTMLElement} source 
   */
  copyPrivates(target, source){
    if(source[PHX_PRIVATE]){
      target[PHX_PRIVATE] = source[PHX_PRIVATE]
    }
  },

  /**
   * Update the document title
   * @param {string} str 
   */
  putTitle(str){
    let titleEl = document.querySelector("title")
    if(titleEl){
      let {prefix, suffix} = titleEl.dataset
      document.title = `${prefix || ""}${str}${suffix || ""}`
    } else {
      document.title = str
    }
  },

  /**
   * Apply an event debounce and/or throttle for callback
   * @param {HTMLElement} el 
   * @param {Event} event 
   * @param {string} phxDebounce 
   * @param {number} defaultDebounce 
   * @param {string} phxThrottle 
   * @param {number} defaultThrottle 
   * @param {function} asyncFilter 
   * @param {function} callback 
   */
  debounce(el, event, phxDebounce, defaultDebounce, phxThrottle, defaultThrottle, asyncFilter, callback){
    let debounce = el.getAttribute(phxDebounce)
    let throttle = el.getAttribute(phxThrottle)

    if(debounce === ""){ debounce = defaultDebounce }
    if(throttle === ""){ throttle = defaultThrottle }
    let value = debounce || throttle
    switch(value){
      case null: return callback()

      case "blur":
        if(this.once(el, "debounce-blur")){
          el.addEventListener("blur", () => callback())
        }
        return

      default:
        let timeout = parseInt(value)
        let trigger = () => throttle ? this.deletePrivate(el, THROTTLED) : callback()
        let currentCycle = this.incCycle(el, DEBOUNCE_TRIGGER, trigger)
        if(isNaN(timeout)){ return logError(`invalid throttle/debounce value: ${value}`) }
        if(throttle){
          let newKeyDown = false
          if(event.type === "keydown"){
            let prevKey = this.private(el, DEBOUNCE_PREV_KEY)
            this.putPrivate(el, DEBOUNCE_PREV_KEY, event.key)
            newKeyDown = prevKey !== event.key
          }

          if(!newKeyDown && this.private(el, THROTTLED)){
            return false
          } else {
            callback()
            this.putPrivate(el, THROTTLED, true)
            setTimeout(() => {
              if(asyncFilter()){ this.triggerCycle(el, DEBOUNCE_TRIGGER) }
            }, timeout)
          }
        } else {
          setTimeout(() => {
            if(asyncFilter()){ this.triggerCycle(el, DEBOUNCE_TRIGGER, currentCycle) }
          }, timeout)
        }

        let form = el.form
        if(form && this.once(form, "bind-debounce")){
          form.addEventListener("submit", () => {
            Array.from((new FormData(form)).entries(), ([name]) => {
              let input = form.querySelector(`[name="${name}"]`)
              this.incCycle(input, DEBOUNCE_TRIGGER)
              this.deletePrivate(input, THROTTLED)
            })
          })
        }
        if(this.once(el, "bind-debounce")){
          el.addEventListener("blur", () => this.triggerCycle(el, DEBOUNCE_TRIGGER))
        }
    }
  },

  /**
   * @param {HTMLElement} el 
   * @param {string} key 
   * @param {any} currentCycle 
   */
  triggerCycle(el, key, currentCycle){
    let [cycle, trigger] = this.private(el, key)
    if(!currentCycle){ currentCycle = cycle }
    if(currentCycle === cycle){
      this.incCycle(el, key)
      trigger()
    }
  },

  /**
   * Set element private data key to true
   * @param {HTMLElement} el 
   * @param {string} key 
   * @returns {boolean} - false if was already set; true if key was unset
   */
  once(el, key){
    if(this.private(el, key) === true){ return false }
    this.putPrivate(el, key, true)
    return true
  },

  /**
   * @param {HTMLElement} el 
   * @param {string} key 
   * @param {function} trigger 
   * @returns {any}
   */
  incCycle(el, key, trigger = function (){ }){
    let [currentCycle] = this.private(el, key) || [0, trigger]
    currentCycle++
    this.putPrivate(el, key, [currentCycle, trigger])
    return currentCycle
  },

  /**
   * Add private hooks if element attributes dictate
   * @param {HTMLElement} el 
   * @param {string} phxViewportTop 
   * @param {string} phxViewportBottom 
   */
  maybeAddPrivateHooks(el, phxViewportTop, phxViewportBottom){
    if(el.hasAttribute && (el.hasAttribute(phxViewportTop) || el.hasAttribute(phxViewportBottom))){
      el.setAttribute("data-phx-hook", "Phoenix.InfiniteScroll")
    }
  },

  /**
   * Hide input feedback nodes if appropriate
   * @param {HTMLElement} container 
   * @param {HTMLInputElement} input 
   * @param {string} phxFeedbackFor 
   */
  maybeHideFeedback(container, input, phxFeedbackFor){
    if(!(this.private(input, PHX_HAS_FOCUSED) || this.private(input, PHX_HAS_SUBMITTED))){
      let feedbacks = [input.name]
      if(input.name.endsWith("[]")){ feedbacks.push(input.name.slice(0, -2)) }
      let selector = feedbacks.map(f => `[${phxFeedbackFor}="${f}"]`).join(", ")
      DOM.all(container, selector, el => el.classList.add(PHX_NO_FEEDBACK_CLASS))
    }
  },

  /**
   * Reset phoenix data (focus, submission state, feedback, etc.) of the given form's inputs
   * @param {HTMLFormElement} form 
   * @param {string} phxFeedbackFor 
   */
  resetForm(form, phxFeedbackFor){
    Array.from(form.elements).forEach(input => {
      let query = `[${phxFeedbackFor}="${input.id}"],
                   [${phxFeedbackFor}="${input.name}"],
                   [${phxFeedbackFor}="${input.name.replace(/\[\]$/, "")}"]`

      this.deletePrivate(input, PHX_HAS_FOCUSED)
      this.deletePrivate(input, PHX_HAS_SUBMITTED)
      this.all(document, query, feedbackEl => {
        feedbackEl.classList.add(PHX_NO_FEEDBACK_CLASS)
      })
    })
  },

  /**
   * Unhide feedback elements for this input
   * @param {HTMLElement} inputEl 
   * @param {string} phxFeedbackFor 
   */
  showError(inputEl, phxFeedbackFor){
    if(inputEl.id || inputEl.name){
      this.all(inputEl.form, `[${phxFeedbackFor}="${inputEl.id}"], [${phxFeedbackFor}="${inputEl.name}"]`, (el) => {
        this.removeClass(el, PHX_NO_FEEDBACK_CLASS)
      })
    }
  },

  /**
   * @param {HTMLElement} node 
   * @returns {boolean}
   */
  isPhxChild(node){
    return node.getAttribute && node.getAttribute(PHX_PARENT_ID)
  },

  /**
   * @param {HTMLElement} node 
   * @returns {boolean}
   */
  isPhxSticky(node){
    return node.getAttribute && node.getAttribute(PHX_STICKY) !== null
  },

  /**
   * @param {HTMLElement} el 
   * @returns {HTMLElement|null}
   */
  firstPhxChild(el){
    return this.isPhxChild(el) ? el : this.all(el, `[${PHX_PARENT_ID}]`)[0]
  },

  /**
   * Create and dispatch a custom event to the target element
   * 
   * Options:
   *   - bubbles: does the event bubble? Defaults to true (NOTE: this is different from standard CustomEvent behavior)
   *   - detail: a value associated with the event that can be accessed by the handler
   * 
   * @param {HTMLElement} target 
   * @param {string} name 
   * @param {{bubbles?: boolean, detail?: object}} [opts] 
   */
  dispatchEvent(target, name, opts = {}){
    let bubbles = opts.bubbles === undefined ? true : !!opts.bubbles
    let eventOpts = {bubbles: bubbles, cancelable: true, detail: opts.detail || {}}
    let event = name === "click" ? new MouseEvent("click", eventOpts) : new CustomEvent(name, eventOpts)
    target.dispatchEvent(event)
  },

  /**
   * Clone node and optionally replace inner HTML with given HTML fragment
   * @param {Node} node 
   * @param {string} [html] 
   * @returns {Node}
   */
  cloneNode(node, html){
    if(typeof (html) === "undefined"){
      return node.cloneNode(true)
    } else {
      let cloned = node.cloneNode(false)
      cloned.innerHTML = html
      return cloned
    }
  },

  /**
   * Copy attributes from source to target, deleting attributes on target not
   * found in source.
   * 
   * Options:
   *   - exclude: List of attribute names on source to skip
   *   - isIgnored: Only remove extra attributes on target if they start with 'data-
   * 
   * @param {HTMLElement} target 
   * @param {HTMLElement} source 
   * @param {{exclude?: string[], isIgnored?: boolean}} [opts] 
   */
  mergeAttrs(target, source, opts = {}){
    let exclude = opts.exclude || []
    let isIgnored = opts.isIgnored
    let sourceAttrs = source.attributes
    for(let i = sourceAttrs.length - 1; i >= 0; i--){
      let name = sourceAttrs[i].name
      if(exclude.indexOf(name) < 0){ target.setAttribute(name, source.getAttribute(name)) }
    }

    let targetAttrs = target.attributes
    for(let i = targetAttrs.length - 1; i >= 0; i--){
      let name = targetAttrs[i].name
      if(isIgnored){
        if(name.startsWith("data-") && !source.hasAttribute(name)){ target.removeAttribute(name) }
      } else {
        if(!source.hasAttribute(name)){ target.removeAttribute(name) }
      }
    }
  },

  /**
   * Copy attributes from focusable input source to target
   * @param {HTMLElement} target 
   * @param {HTMLElement} source 
   */
  mergeFocusedInput(target, source){
    // skip selects because FF will reset highlighted index for any setAttribute
    if(!(target instanceof HTMLSelectElement)){ DOM.mergeAttrs(target, source, {exclude: ["value"]}) }
    if(source.readOnly){
      target.setAttribute("readonly", true)
    } else {
      target.removeAttribute("readonly")
    }
  },

  /**
   * Does element have a selection range?
   * @param {HTMLElement} el 
   * @returns {boolean}
   */
  hasSelectionRange(el){
    return el.setSelectionRange && (el.type === "text" || el.type === "textarea")
  },

  /**
   * Restore focus to the element, along with any selection range
   * @param {HTMLElement} focused
   * @param {number} [selectionStart] 
   * @param {number} [selectionEnd] 
   */
  restoreFocus(focused, selectionStart, selectionEnd){
    if(!DOM.isTextualInput(focused)){ return }
    let wasFocused = focused.matches(":focus")
    if(focused.readOnly){ focused.blur() }
    if(!wasFocused){ focused.focus() }
    if(this.hasSelectionRange(focused)){
      focused.setSelectionRange(selectionStart, selectionEnd)
    }
  },

  /**
   * Is the element a form input?
   * @param {HTMLElement} el 
   * @returns {boolean}
   */
  isFormInput(el){ return /^(?:input|select|textarea)$/i.test(el.tagName) && el.type !== "button" },

  /**
   * Copy checkable input elements "checked" attributes to "checked" property
   * @param {HTMLElement} el 
   */
  syncAttrsToProps(el){
    if(el instanceof HTMLInputElement && CHECKABLE_INPUTS.indexOf(el.type.toLocaleLowerCase()) >= 0){
      el.checked = el.getAttribute("checked") !== null
    }
  },

  /**
   * Is the element one of the focusable textual input elements?
   * @param {HTMLElement} el 
   * @returns {boolean}
   */
  isTextualInput(el){ return FOCUSABLE_INPUTS.indexOf(el.type) >= 0 },

  /**
   * @param {HTMLElement} el 
   * @param {string} phxTriggerExternal 
   * @returns {boolean}
   */
  isNowTriggerFormExternal(el, phxTriggerExternal){
    return el.getAttribute && el.getAttribute(phxTriggerExternal) !== null
  },

  /**
   * @param {HTMLElement} fromEl 
   * @param {HTMLElement} toEl 
   * @param {string} disableWith 
   * @returns {boolean}
   */
  syncPendingRef(fromEl, toEl, disableWith){
    let ref = fromEl.getAttribute(PHX_REF)
    if(ref === null){ return true }
    let refSrc = fromEl.getAttribute(PHX_REF_SRC)

    if(DOM.isFormInput(fromEl) || fromEl.getAttribute(disableWith) !== null){
      if(DOM.isUploadInput(fromEl)){ DOM.mergeAttrs(fromEl, toEl, {isIgnored: true}) }
      DOM.putPrivate(fromEl, PHX_REF, toEl)
      return false
    } else {
      PHX_EVENT_CLASSES.forEach(className => {
        fromEl.classList.contains(className) && toEl.classList.add(className)
      })
      toEl.setAttribute(PHX_REF, ref)
      toEl.setAttribute(PHX_REF_SRC, refSrc)
      return true
    }
  },

  /**
   * Remove child nodes missing ID's.
   * @param {HTMLElement} container 
   * @param {string} phxUpdate 
   */
  cleanChildNodes(container, phxUpdate){
    if(DOM.isPhxUpdate(container, phxUpdate, ["append", "prepend"])){
      let toRemove = []
      container.childNodes.forEach(childNode => {
        if(!childNode.id){
          // Skip warning if it's an empty text node (e.g. a new-line)
          let isEmptyTextNode = childNode.nodeType === Node.TEXT_NODE && childNode.nodeValue.trim() === ""
          if(!isEmptyTextNode){
            logError("only HTML element tags with an id are allowed inside containers with phx-update.\n\n" +
              `removing illegal node: "${(childNode.outerHTML || childNode.nodeValue).trim()}"\n\n`)
          }
          toRemove.push(childNode)
        }
      })
      toRemove.forEach(childNode => childNode.remove())
    }
  },

  /**
   * Replace the root container element and replacing attributes with given set
   * (while stilll retaining phx tracking attributes).
   * @param {HTMLElement} container 
   * @param {string} tagName 
   * @param {object} attrs 
   * @returns {HTMLElement}
   */
  replaceRootContainer(container, tagName, attrs){
    let retainedAttrs = new Set(["id", PHX_SESSION, PHX_STATIC, PHX_MAIN, PHX_ROOT_ID])
    if(container.tagName.toLowerCase() === tagName.toLowerCase()){
      Array.from(container.attributes)
        .filter(attr => !retainedAttrs.has(attr.name.toLowerCase()))
        .forEach(attr => container.removeAttribute(attr.name))

      Object.keys(attrs)
        .filter(name => !retainedAttrs.has(name.toLowerCase()))
        .forEach(attr => container.setAttribute(attr, attrs[attr]))

      return container

    } else {
      let newContainer = document.createElement(tagName)
      Object.keys(attrs).forEach(attr => newContainer.setAttribute(attr, attrs[attr]))
      retainedAttrs.forEach(attr => newContainer.setAttribute(attr, container.getAttribute(attr)))
      newContainer.innerHTML = container.innerHTML
      container.replaceWith(newContainer)
      return newContainer
    }
  },

  /**
   * Get the stashed result for the element's private "sticky" operation matching given name; if not found, return default value
   * @param {HTMLElement} el 
   * @param {string} name - name of sticky op to search for
   * @param {any} defaultVal - if function, it will be called and result returned
   * @returns {any} stashed result of op or defaultVal
   */
  getSticky(el, name, defaultVal){
    let op = (DOM.private(el, "sticky") || []).find(([existingName]) => name === existingName)
    if(op){
      let [_name, _op, stashedResult] = op
      return stashedResult
    } else {
      return typeof(defaultVal) === "function" ? defaultVal() : defaultVal
    }
  },

  /**
   * Delete the named "sticky" operation from element's private data
   * @param {HTMLElement} el 
   * @param {string} name 
   */
  deleteSticky(el, name){
    this.updatePrivate(el, "sticky", [], ops => {
      return ops.filter(([existingName, _]) => existingName !== name)
    })
  },

  /**
   * Store a named "sticky" operation and its result to the element's private data
   * @param {HTMLElement} el 
   * @param {string} name 
   * @param {function} op 
   */
  putSticky(el, name, op){
    let stashedResult = op(el)
    this.updatePrivate(el, "sticky", [], ops => {
      let existingIndex = ops.findIndex(([existingName]) => name === existingName)
      if(existingIndex >= 0){
        ops[existingIndex] = [name, op, stashedResult]
      } else {
        ops.push([name, op, stashedResult])
      }
      return ops
    })
  },

  /**
   * Re-run all sticky operations for this element and store latest stashed results
   * @param {HTMLElement} el 
   */
  applyStickyOperations(el){
    let ops = DOM.private(el, "sticky")
    if(!ops){ return }

    ops.forEach(([name, op, _stashed]) => this.putSticky(el, name, op))
  }
}

export default DOM

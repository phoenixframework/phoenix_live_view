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

let DOM = {
  byId(id){ return document.getElementById(id) || logError(`no id found for ${id}`) },

  removeClass(el, className){
    el.classList.remove(className)
    if(el.classList.length === 0){ el.removeAttribute("class") }
  },

  all(node, query, callback){
    if(!node){ return [] }
    let array = Array.from(node.querySelectorAll(query))
    return callback ? array.forEach(callback) : array
  },

  childNodeLength(html){
    let template = document.createElement("template")
    template.innerHTML = html
    return template.content.childElementCount
  },

  isUploadInput(el){ return el.type === "file" && el.getAttribute(PHX_UPLOAD_REF) !== null },

  findUploadInputs(node){ return this.all(node, `input[type="file"][${PHX_UPLOAD_REF}]`) },

  findComponentNodeList(node, cid){
    return this.filterWithinSameLiveView(this.all(node, `[${PHX_COMPONENT}="${cid}"]`), node)
  },

  isPhxDestroyed(node){
    return node.id && DOM.private(node, "destroyed") ? true : false
  },

  markPhxChildDestroyed(el){
    if(this.isPhxChild(el)){ el.setAttribute(PHX_SESSION, "") }
    this.putPrivate(el, "destroyed", true)
  },

  findPhxChildrenInFragment(html, parentId){
    let template = document.createElement("template")
    template.innerHTML = html
    return this.findPhxChildren(template.content, parentId)
  },

  isIgnored(el, phxUpdate){
    return (el.getAttribute(phxUpdate) || el.getAttribute("data-phx-update")) === "ignore"
  },

  isPhxUpdate(el, phxUpdate, updateTypes){
    return el.getAttribute && updateTypes.indexOf(el.getAttribute(phxUpdate)) >= 0
  },

  findPhxSticky(el){ return this.all(el, `[${PHX_STICKY}]`) },

  findPhxChildren(el, parentId){
    return this.all(el, `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${parentId}"]`)
  },

  findParentCIDs(node, cids){
    let initial = new Set(cids)
    return cids.reduce((acc, cid) => {
      let selector = `[${PHX_COMPONENT}="${cid}"] [${PHX_COMPONENT}]`

      this.filterWithinSameLiveView(this.all(node, selector), node)
        .map(el => parseInt(el.getAttribute(PHX_COMPONENT)))
        .forEach(childCID => acc.delete(childCID))

      return acc
    }, initial)
  },

  filterWithinSameLiveView(nodes, parent){
    if(parent.querySelector(PHX_VIEW_SELECTOR)){
      return nodes.filter(el => this.withinSameLiveView(el, parent))
    } else {
      return nodes
    }
  },

  withinSameLiveView(node, parent){
    while(node = node.parentNode){
      if(node.isSameNode(parent)){ return true }
      if(node.getAttribute(PHX_SESSION) !== null){ return false }
    }
  },

  private(el, key){ return el[PHX_PRIVATE] && el[PHX_PRIVATE][key] },

  deletePrivate(el, key){ el[PHX_PRIVATE] && delete (el[PHX_PRIVATE][key]) },

  putPrivate(el, key, value){
    if(!el[PHX_PRIVATE]){ el[PHX_PRIVATE] = {} }
    el[PHX_PRIVATE][key] = value
  },

  updatePrivate(el, key, defaultVal, updateFunc){
    let existing = this.private(el, key)
    if(existing === undefined){
      this.putPrivate(el, key, updateFunc(defaultVal))
    } else {
      this.putPrivate(el, key, updateFunc(existing))
    }
  },

  copyPrivates(target, source){
    if(source[PHX_PRIVATE]){
      target[PHX_PRIVATE] = source[PHX_PRIVATE]
    }
  },

  putTitle(str){
    let titleEl = document.querySelector("title")
    let {prefix, suffix} = titleEl.dataset
    document.title = `${prefix || ""}${str}${suffix || ""}`
  },

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

  triggerCycle(el, key, currentCycle){
    let [cycle, trigger] = this.private(el, key)
    if(!currentCycle){ currentCycle = cycle }
    if(currentCycle === cycle){
      this.incCycle(el, key)
      trigger()
    }
  },

  once(el, key){
    if(this.private(el, key) === true){ return false }
    this.putPrivate(el, key, true)
    return true
  },

  incCycle(el, key, trigger = function (){ }){
    let [currentCycle] = this.private(el, key) || [0, trigger]
    currentCycle++
    this.putPrivate(el, key, [currentCycle, trigger])
    return currentCycle
  },

  discardError(container, el, phxFeedbackFor){
    let field = el.getAttribute && el.getAttribute(phxFeedbackFor)
    // TODO: Remove id lookup after we update Phoenix to use input_name instead of input_id
    let input = field && container.querySelector(`[id="${field}"], [name="${field}"]`)
    if(!input){ return }

    if(!(this.private(input, PHX_HAS_FOCUSED) || this.private(input.form, PHX_HAS_SUBMITTED))){
      el.classList.add(PHX_NO_FEEDBACK_CLASS)
    }
  },

  showError(inputEl, phxFeedbackFor){
    if(inputEl.id || inputEl.name){
      this.all(inputEl.form, `[${phxFeedbackFor}="${inputEl.id}"], [${phxFeedbackFor}="${inputEl.name}"]`, (el) => {
        this.removeClass(el, PHX_NO_FEEDBACK_CLASS)
      })
    }
  },

  isPhxChild(node){
    return node.getAttribute && node.getAttribute(PHX_PARENT_ID)
  },

  isPhxSticky(node){
    return node.getAttribute && node.getAttribute(PHX_STICKY) !== null
  },

  firstPhxChild(el){
    return this.isPhxChild(el) ? el : this.all(el, `[${PHX_PARENT_ID}]`)[0]
  },

  dispatchEvent(target, name, opts = {}){
    let bubbles = opts.bubbles === undefined ? true : !!opts.bubbles
    let eventOpts = {bubbles: bubbles, cancelable: true, detail: opts.detail || {}}
    let event = name === "click" ? new MouseEvent("click", eventOpts) : new CustomEvent(name, eventOpts)
    target.dispatchEvent(event)
  },

  cloneNode(node, html){
    if(typeof (html) === "undefined"){
      return node.cloneNode(true)
    } else {
      let cloned = node.cloneNode(false)
      cloned.innerHTML = html
      return cloned
    }
  },

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

  mergeFocusedInput(target, source){
    // skip selects because FF will reset highlighted index for any setAttribute
    if(!(target instanceof HTMLSelectElement)){ DOM.mergeAttrs(target, source, {exclude: ["value"]}) }
    if(source.readOnly){
      target.setAttribute("readonly", true)
    } else {
      target.removeAttribute("readonly")
    }
  },

  hasSelectionRange(el){
    return el.setSelectionRange && (el.type === "text" || el.type === "textarea")
  },

  restoreFocus(focused, selectionStart, selectionEnd){
    if(!DOM.isTextualInput(focused)){ return }
    let wasFocused = focused.matches(":focus")
    if(focused.readOnly){ focused.blur() }
    if(!wasFocused){ focused.focus() }
    if(this.hasSelectionRange(focused)){
      focused.setSelectionRange(selectionStart, selectionEnd)
    }
  },

  isFormInput(el){ return /^(?:input|select|textarea)$/i.test(el.tagName) && el.type !== "button" },

  syncAttrsToProps(el){
    if(el instanceof HTMLInputElement && CHECKABLE_INPUTS.indexOf(el.type.toLocaleLowerCase()) >= 0){
      el.checked = el.getAttribute("checked") !== null
    }
  },

  isTextualInput(el){ return FOCUSABLE_INPUTS.indexOf(el.type) >= 0 },

  isNowTriggerFormExternal(el, phxTriggerExternal){
    return el.getAttribute && el.getAttribute(phxTriggerExternal) !== null
  },

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

  getSticky(el, name, defaultVal){
    let op = (DOM.private(el, "sticky") || []).find(([existingName, ]) => name === existingName)
    if(op){
      let [_name, _op, stashedResult] = op
      return stashedResult
    } else {
      return typeof(defaultVal) === "function" ? defaultVal() : defaultVal
    }
  },

  deleteSticky(el, name){
    this.updatePrivate(el, "sticky", [], ops => {
      return ops.filter(([existingName, _]) => existingName !== name)
    })
  },

  putSticky(el, name, op){
    let stashedResult = op(el)
    this.updatePrivate(el, "sticky", [], ops => {
      let existingIndex = ops.findIndex(([existingName, ]) => name === existingName)
      if(existingIndex >= 0){
        ops[existingIndex] = [name, op, stashedResult]
      } else {
        ops.push([name, op, stashedResult])
      }
      return ops
    })
  },

  applyStickyOperations(el){
    let ops = DOM.private(el, "sticky")
    if(!ops){ return }

    ops.forEach(([name, op, _stashed]) => this.putSticky(el, name, op))
  }
}

export default DOM

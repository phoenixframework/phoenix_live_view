import DOM from "./dom"
import ARIA from "./aria"

/**
 * @typedef {import('./view.js').default} View
 */

let focusStack = null

let JS = {
  /**
   * Execute JS command - main entrypoint
   * @param {string|null} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {HTMLElement} sourceEl 
   * @param {[defaultKind: string, defaultArgs: any]} [defaults] 
   */
  exec(eventType, phxEvent, view, sourceEl, defaults){
    let [defaultKind, defaultArgs] = defaults || [null, {callback: defaults && defaults.callback}]
    let commands = phxEvent.charAt(0) === "[" ?
      JSON.parse(phxEvent) : [[defaultKind, defaultArgs]]



    commands.forEach(([kind, args]) => {
      if(kind === defaultKind && defaultArgs.data){
        args.data = Object.assign(args.data || {}, defaultArgs.data)
        args.callback = args.callback || defaultArgs.callback
      }
      this.filterToEls(sourceEl, args).forEach(el => {
        this[`exec_${kind}`](eventType, phxEvent, view, sourceEl, el, args)
      })
    })
  },

  /**
   * Is element visible and not scrolled off-screen?
   * @param {Element} el 
   * @returns {boolean}
   */
  isVisible(el){
    return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length > 0)
  },

  // private

  // commands

  /**
   * Exec JS command for all targeted DOM nodes
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   * @param {[attrWithCommand: string, toTargetsSelector: string]} args 
   */
  exec_exec(eventType, phxEvent, view, sourceEl, el, [attr, to]){
    let nodes = to ? DOM.all(document, to) : [sourceEl]
    nodes.forEach(node => {
      let encodedJS = node.getAttribute(attr)
      if(!encodedJS){ throw new Error(`expected ${attr} to contain JS command on "${to}"`) }
      view.liveSocket.execJS(node, encodedJS, eventType)
    })
  },

  /**
   * Exec dispatch command for event
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   * @param {object} args 
   * @param {string} [args.to]
   * @param {string} [args.event] 
   * @param {boolean} [args.bubbles] 
   * @param {object} [args.detail]
   */
  // eslint-disable-next-line no-unused-vars
  exec_dispatch(eventType, phxEvent, view, sourceEl, el, {to, event, detail, bubbles}){
    detail = detail || {}
    detail.dispatcher = sourceEl
    DOM.dispatchEvent(el, event, {detail, bubbles})
  },

  /**
   * Push an event over LiveSocket
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   * @param {object} args 
   * @param {string} [args.event]
   * @param {any} [args.submitter]
   * @param {string|number|Element} [args.target]
   * @param {boolean} [args.page_loading]
   * @param {any} [args.loading]
   * @param {any} [args.value]
   * @param {Element} [args.dispatcher]
   * @param {function} [args.callback]
   * @param {string|number} [args.newCid]
   * @param {string} [args._target]
   */
  exec_push(eventType, phxEvent, view, sourceEl, el, args){
    if(!view.isConnected()){ return }

    let {event, data, target, page_loading, loading, value, dispatcher, callback} = args
    let pushOpts = {loading, value, target, page_loading: !!page_loading}
    let targetSrc = eventType === "change" && dispatcher ? dispatcher : sourceEl
    let phxTarget = target || targetSrc.getAttribute(view.binding("target")) || targetSrc
    view.withinTargets(phxTarget, (targetView, targetCtx) => {
      if(eventType === "change"){
        let {newCid, _target} = args
        _target = _target || (DOM.isFormInput(sourceEl) ? sourceEl.name : undefined)
        if(_target){ pushOpts._target = _target }
        targetView.pushInput(sourceEl, targetCtx, newCid, event || phxEvent, pushOpts, callback)
      } else if(eventType === "submit"){
        let {submitter} = args
        targetView.submitForm(sourceEl, targetCtx, event || phxEvent, submitter, pushOpts, callback)
      } else {
        targetView.pushEvent(eventType, sourceEl, targetCtx, event || phxEvent, data, pushOpts, callback)
      }
    })
  },

  /**
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   * @param {{href: string, replace?: boolean}} args 
   */
  exec_navigate(eventType, phxEvent, view, sourceEl, el, {href, replace}){
    view.liveSocket.historyRedirect(href, replace ? "replace" : "push")
  },

  /**
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   * @param {{href: string, replace: boolean}} args 
   */
  exec_patch(eventType, phxEvent, view, sourceEl, el, {href, replace}){
    view.liveSocket.pushHistoryPatch(href, replace ? "replace" : "push", sourceEl)
  },


  /**
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   */
  exec_focus(eventType, phxEvent, view, sourceEl, el){
    window.requestAnimationFrame(() => ARIA.attemptFocus(el))
  },

  /**
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   */
  exec_focus_first(eventType, phxEvent, view, sourceEl, el){
    window.requestAnimationFrame(() => ARIA.focusFirstInteractive(el) || ARIA.focusFirst(el))
  },

  /**
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   */
  exec_push_focus(eventType, phxEvent, view, sourceEl, el){
    window.requestAnimationFrame(() => focusStack = el || sourceEl)
  },

  /**
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   */
  // eslint-disable-next-line no-unused-vars
  exec_pop_focus(eventType, phxEvent, view, sourceEl, el){
    window.requestAnimationFrame(() => {
      if(focusStack){ focusStack.focus() }
      focusStack = null
    })
  },

  /**
   * @private
   * @param {string} eventType 
   * @param {string} phxEvent 
   * @param {View} view 
   * @param {Element} sourceEl 
   * @param {Element} el 
   * @param {object} args
   * @param {object} args.names
   * @param {object} args.transition
   * @param {object} args.time
   */
  exec_add_class(eventType, phxEvent, view, sourceEl, el, {names, transition, time}){
    this.addOrRemoveClasses(el, names, [], transition, time, view)
  },

  exec_remove_class(eventType, phxEvent, view, sourceEl, el, {names, transition, time}){
    this.addOrRemoveClasses(el, [], names, transition, time, view)
  },

  exec_transition(eventType, phxEvent, view, sourceEl, el, {time, transition}){
    this.addOrRemoveClasses(el, [], [], transition, time, view)
  },

  exec_toggle(eventType, phxEvent, view, sourceEl, el, {display, ins, outs, time}){
    this.toggle(eventType, view, el, display, ins, outs, time)
  },

  exec_show(eventType, phxEvent, view, sourceEl, el, {display, transition, time}){
    this.show(eventType, view, el, display, transition, time)
  },

  exec_hide(eventType, phxEvent, view, sourceEl, el, {display, transition, time}){
    this.hide(eventType, view, el, display, transition, time)
  },

  exec_set_attr(eventType, phxEvent, view, sourceEl, el, {attr: [attr, val]}){
    this.setOrRemoveAttrs(el, [[attr, val]], [])
  },

  exec_remove_attr(eventType, phxEvent, view, sourceEl, el, {attr}){
    this.setOrRemoveAttrs(el, [], [attr])
  },

  // utils for commands

  show(eventType, view, el, display, transition, time){
    if(!this.isVisible(el)){
      this.toggle(eventType, view, el, display, transition, null, time)
    }
  },

  hide(eventType, view, el, display, transition, time){
    if(this.isVisible(el)){
      this.toggle(eventType, view, el, display, null, transition, time)
    }
  },

  toggle(eventType, view, el, display, ins, outs, time){
    let [inClasses, inStartClasses, inEndClasses] = ins || [[], [], []]
    let [outClasses, outStartClasses, outEndClasses] = outs || [[], [], []]
    if(inClasses.length > 0 || outClasses.length > 0){
      if(this.isVisible(el)){
        let onStart = () => {
          this.addOrRemoveClasses(el, outStartClasses, inClasses.concat(inStartClasses).concat(inEndClasses))
          window.requestAnimationFrame(() => {
            this.addOrRemoveClasses(el, outClasses, [])
            window.requestAnimationFrame(() => this.addOrRemoveClasses(el, outEndClasses, outStartClasses))
          })
        }
        el.dispatchEvent(new Event("phx:hide-start"))
        view.transition(time, onStart, () => {
          this.addOrRemoveClasses(el, [], outClasses.concat(outEndClasses))
          DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = "none")
          el.dispatchEvent(new Event("phx:hide-end"))
        })
      } else {
        if(eventType === "remove"){ return }
        let onStart = () => {
          this.addOrRemoveClasses(el, inStartClasses, outClasses.concat(outStartClasses).concat(outEndClasses))
          let stickyDisplay = display || this.defaultDisplay(el)
          DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = stickyDisplay)
          window.requestAnimationFrame(() => {
            this.addOrRemoveClasses(el, inClasses, [])
            window.requestAnimationFrame(() => this.addOrRemoveClasses(el, inEndClasses, inStartClasses))
          })
        }
        el.dispatchEvent(new Event("phx:show-start"))
        view.transition(time, onStart, () => {
          this.addOrRemoveClasses(el, [], inClasses.concat(inEndClasses))
          el.dispatchEvent(new Event("phx:show-end"))
        })
      }
    } else {
      if(this.isVisible(el)){
        window.requestAnimationFrame(() => {
          el.dispatchEvent(new Event("phx:hide-start"))
          DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = "none")
          el.dispatchEvent(new Event("phx:hide-end"))
        })
      } else {
        window.requestAnimationFrame(() => {
          el.dispatchEvent(new Event("phx:show-start"))
          let stickyDisplay = display || this.defaultDisplay(el)
          DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = stickyDisplay)
          el.dispatchEvent(new Event("phx:show-end"))
        })
      }
    }
  },

  /**
   * @param {Element} el 
   * @param {string[]} adds 
   * @param {string[]} removes 
   * @param {[runs: string[], starts: string[], ends: string[]]} [transition] 
   * @param {number} time 
   * @param {View} view 
   * @returns 
   */
  addOrRemoveClasses(el, adds, removes, transition, time, view){
    let [transitionRun, transitionStart, transitionEnd] = transition || [[], [], []]
    if(transitionRun.length > 0){
      let onStart = () => {
        this.addOrRemoveClasses(el, transitionStart, [].concat(transitionRun).concat(transitionEnd))
        window.requestAnimationFrame(() => {
          this.addOrRemoveClasses(el, transitionRun, [])
          window.requestAnimationFrame(() => this.addOrRemoveClasses(el, transitionEnd, transitionStart))
        })
      }
      let onDone = () => this.addOrRemoveClasses(el, adds.concat(transitionEnd), removes.concat(transitionRun).concat(transitionStart))
      return view.transition(time, onStart, onDone)
    }

    window.requestAnimationFrame(() => {
      /** @type {[string[], string[]]} */
      let [prevAdds, prevRemoves] = DOM.getSticky(el, "classes", [[], []])
      let keepAdds = adds.filter(name => prevAdds.indexOf(name) < 0 && !el.classList.contains(name))
      let keepRemoves = removes.filter(name => prevRemoves.indexOf(name) < 0 && el.classList.contains(name))
      let newAdds = prevAdds.filter(name => removes.indexOf(name) < 0).concat(keepAdds)
      let newRemoves = prevRemoves.filter(name => adds.indexOf(name) < 0).concat(keepRemoves)

      DOM.putSticky(el, "classes", currentEl => {
        currentEl.classList.remove(...newRemoves)
        currentEl.classList.add(...newAdds)
        return [newAdds, newRemoves]
      })
    })
  },

  /**
   * @param {Element} el 
   * @param {[attr: string, val: string][]} sets 
   * @param {string[]} removes 
   */
  setOrRemoveAttrs(el, sets, removes){
    /** @type {[[attr: string, val: string], string[]]} */
    let [prevSets, prevRemoves] = DOM.getSticky(el, "attrs", [[], []])

    let alteredAttrs = sets.map(([attr, _val]) => attr).concat(removes);
    let newSets = prevSets.filter(([attr, _val]) => !alteredAttrs.includes(attr)).concat(sets);
    let newRemoves = prevRemoves.filter((attr) => !alteredAttrs.includes(attr)).concat(removes);

    DOM.putSticky(el, "attrs", currentEl => {
      newRemoves.forEach(attr => currentEl.removeAttribute(attr))
      newSets.forEach(([attr, val]) => currentEl.setAttribute(attr, val))
      return [newSets, newRemoves]
    })
  },

  /**
   * @param {HTMLElement} el 
   * @param {string[]} classes 
   * @returns {boolean}
   */
  hasAllClasses(el, classes){ return classes.every(name => el.classList.contains(name)) },

  /**
   * @param {HTMLElement} el 
   * @param {string[]} outClasses 
   * @returns {boolean}
   */
  isToggledOut(el, outClasses){
    return !this.isVisible(el) || this.hasAllClasses(el, outClasses)
  },

  /**
   * @private
   * @param {HTMLElement} sourceEl 
   * @param {{to?: string}} args 
   * @returns 
   */
  filterToEls(sourceEl, {to}){
    return to ? DOM.all(document, to) : [sourceEl]
  },

  /**
   * @private
   * @param {HTMLElement} el 
   * @returns {"table-row"|"table-cell"|"block"}
   */
  defaultDisplay(el){
    return {tr: "table-row", td: "table-cell"}[el.tagName.toLowerCase()] || "block"
  }
}

export default JS

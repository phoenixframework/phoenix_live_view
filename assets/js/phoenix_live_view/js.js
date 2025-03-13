import DOM from "./dom"
import ARIA from "./aria"

let focusStack = []
let default_transition_time = 200

let JS = {
  // private
  exec(e, eventType, phxEvent, view, sourceEl, defaults){
    let [defaultKind, defaultArgs] = defaults || [null, {callback: defaults && defaults.callback}]
    let commands = phxEvent.charAt(0) === "[" ?
      JSON.parse(phxEvent) : [[defaultKind, defaultArgs]]

    commands.forEach(([kind, args]) => {
      if(kind === defaultKind){
        // always prefer the args, but keep existing keys from the defaultArgs
        args = {...defaultArgs, ...args}
        args.callback = args.callback || defaultArgs.callback
      }
      this.filterToEls(view.liveSocket, sourceEl, args).forEach(el => {
        this[`exec_${kind}`](e, eventType, phxEvent, view, sourceEl, el, args)
      })
    })
  },

  isVisible(el){
    return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length > 0)
  },

  // returns true if any part of the element is inside the viewport
  isInViewport(el){
    const rect = el.getBoundingClientRect()
    const windowHeight = window.innerHeight || document.documentElement.clientHeight
    const windowWidth = window.innerWidth || document.documentElement.clientWidth

    return (
      rect.right > 0 &&
      rect.bottom > 0 &&
      rect.left < windowWidth &&
      rect.top < windowHeight
    )
  },

  // private

  // commands

  exec_exec(e, eventType, phxEvent, view, sourceEl, el, {attr, to}){
    let encodedJS = el.getAttribute(attr)
    if(!encodedJS){ throw new Error(`expected ${attr} to contain JS command on "${to}"`) }
    view.liveSocket.execJS(el, encodedJS, eventType)
  },

  exec_dispatch(e, eventType, phxEvent, view, sourceEl, el, {event, detail, bubbles, blocking}){
    detail = detail || {}
    detail.dispatcher = sourceEl
    if(blocking){
      const promise = new Promise((resolve, _reject) => {
        detail.done = resolve
      })
      view.liveSocket.asyncTransition(promise)
    }
    DOM.dispatchEvent(el, event, {detail, bubbles})
  },

  exec_push(e, eventType, phxEvent, view, sourceEl, el, args){
    let {event, data, target, page_loading, loading, value, dispatcher, callback} = args
    let pushOpts = {loading, value, target, page_loading: !!page_loading}
    let targetSrc = eventType === "change" && dispatcher ? dispatcher : sourceEl
    let phxTarget = target || targetSrc.getAttribute(view.binding("target")) || targetSrc
    const handler = (targetView, targetCtx) => {
      if(!targetView.isConnected()){ return }
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
    }
    // in case of formRecovery, targetView and targetCtx are passed as argument
    // as they are looked up in a template element, not the real DOM
    if(args.targetView && args.targetCtx){
      handler(args.targetView, args.targetCtx)
    } else {
      view.withinTargets(phxTarget, handler)
    }
  },

  exec_navigate(e, eventType, phxEvent, view, sourceEl, el, {href, replace}){
    view.liveSocket.historyRedirect(e, href, replace ? "replace" : "push", null, sourceEl)
  },

  exec_patch(e, eventType, phxEvent, view, sourceEl, el, {href, replace}){
    view.liveSocket.pushHistoryPatch(e, href, replace ? "replace" : "push", sourceEl)
  },

  exec_focus(e, eventType, phxEvent, view, sourceEl, el){
    ARIA.attemptFocus(el)
    // in case the JS.focus command is in a JS.show/hide/toggle chain, for show we need
    // to wait for JS.show to have updated the element's display property (see exec_toggle)
    // but that run in nested animation frames, therefore we need to use them here as well
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => ARIA.attemptFocus(el))
    })
  },

  exec_focus_first(e, eventType, phxEvent, view, sourceEl, el){
    ARIA.focusFirstInteractive(el) || ARIA.focusFirst(el)
    // if you wonder about the nested animation frames, see exec_focus
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => ARIA.focusFirstInteractive(el) || ARIA.focusFirst(el))
    })
  },

  exec_push_focus(e, eventType, phxEvent, view, sourceEl, el){
    focusStack.push(el || sourceEl)
  },

  exec_pop_focus(_e, _eventType, _phxEvent, _view, _sourceEl, _el){
    const el = focusStack.pop()
    if(el){
      el.focus()
      // if you wonder about the nested animation frames, see exec_focus
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => el.focus())
      })
    }
  },

  exec_add_class(e, eventType, phxEvent, view, sourceEl, el, {names, transition, time, blocking}){
    this.addOrRemoveClasses(el, names, [], transition, time, view, blocking)
  },

  exec_remove_class(e, eventType, phxEvent, view, sourceEl, el, {names, transition, time, blocking}){
    this.addOrRemoveClasses(el, [], names, transition, time, view, blocking)
  },

  exec_toggle_class(e, eventType, phxEvent, view, sourceEl, el, {names, transition, time, blocking}){
    this.toggleClasses(el, names, transition, time, view, blocking)
  },

  exec_toggle_attr(e, eventType, phxEvent, view, sourceEl, el, {attr: [attr, val1, val2]}){
    this.toggleAttr(el, attr, val1, val2)
  },

  exec_transition(e, eventType, phxEvent, view, sourceEl, el, {time, transition, blocking}){
    this.addOrRemoveClasses(el, [], [], transition, time, view, blocking)
  },

  exec_toggle(e, eventType, phxEvent, view, sourceEl, el, {display, ins, outs, time, blocking}){
    this.toggle(eventType, view, el, display, ins, outs, time, blocking)
  },

  exec_show(e, eventType, phxEvent, view, sourceEl, el, {display, transition, time, blocking}){
    this.show(eventType, view, el, display, transition, time, blocking)
  },

  exec_hide(e, eventType, phxEvent, view, sourceEl, el, {display, transition, time, blocking}){
    this.hide(eventType, view, el, display, transition, time, blocking)
  },

  exec_set_attr(e, eventType, phxEvent, view, sourceEl, el, {attr: [attr, val]}){
    this.setOrRemoveAttrs(el, [[attr, val]], [])
  },

  exec_remove_attr(e, eventType, phxEvent, view, sourceEl, el, {attr}){
    this.setOrRemoveAttrs(el, [], [attr])
  },

  // utils for commands

  show(eventType, view, el, display, transition, time, blocking){
    if(!this.isVisible(el)){
      this.toggle(eventType, view, el, display, transition, null, time, blocking)
    }
  },

  hide(eventType, view, el, display, transition, time, blocking){
    if(this.isVisible(el)){
      this.toggle(eventType, view, el, display, null, transition, time, blocking)
    }
  },

  toggle(eventType, view, el, display, ins, outs, time, blocking){
    time = time || default_transition_time
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
        let onEnd = () => {
          this.addOrRemoveClasses(el, [], outClasses.concat(outEndClasses))
          DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = "none")
          el.dispatchEvent(new Event("phx:hide-end"))
        }
        el.dispatchEvent(new Event("phx:hide-start"))
        if(blocking === false){
          onStart()
          setTimeout(onEnd, time)
        } else {
          view.transition(time, onStart, onEnd)
        }
      } else {
        if(eventType === "remove"){ return }
        let onStart = () => {
          this.addOrRemoveClasses(el, inStartClasses, outClasses.concat(outStartClasses).concat(outEndClasses))
          const stickyDisplay = display || this.defaultDisplay(el)
          window.requestAnimationFrame(() => {
            // first add the starting + active class, THEN make the element visible
            // otherwise if we toggled the visibility earlier css animations
            // would flicker, as the element becomes visible before the active animation
            // class is set (see https://github.com/phoenixframework/phoenix_live_view/issues/3456)
            this.addOrRemoveClasses(el, inClasses, [])
            // addOrRemoveClasses uses a requestAnimationFrame itself, therefore we need to move the putSticky
            // into the next requestAnimationFrame...
            window.requestAnimationFrame(() => {
              DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = stickyDisplay)
              this.addOrRemoveClasses(el, inEndClasses, inStartClasses)
            })
          })
        }
        let onEnd = () => {
          this.addOrRemoveClasses(el, [], inClasses.concat(inEndClasses))
          el.dispatchEvent(new Event("phx:show-end"))
        }
        el.dispatchEvent(new Event("phx:show-start"))
        if(blocking === false){
          onStart()
          setTimeout(onEnd, time)
        } else {
          view.transition(time, onStart, onEnd)
        }
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

  toggleClasses(el, classes, transition, time, view, blocking){
    window.requestAnimationFrame(() => {
      let [prevAdds, prevRemoves] = DOM.getSticky(el, "classes", [[], []])
      let newAdds = classes.filter(name => prevAdds.indexOf(name) < 0 && !el.classList.contains(name))
      let newRemoves = classes.filter(name => prevRemoves.indexOf(name) < 0 && el.classList.contains(name))
      this.addOrRemoveClasses(el, newAdds, newRemoves, transition, time, view, blocking)
    })
  },

  toggleAttr(el, attr, val1, val2){
    if(el.hasAttribute(attr)){
      if(val2 !== undefined){
        // toggle between val1 and val2
        if(el.getAttribute(attr) === val1){
          this.setOrRemoveAttrs(el, [[attr, val2]], [])
        } else {
          this.setOrRemoveAttrs(el, [[attr, val1]], [])
        }
      } else {
        // remove attr
        this.setOrRemoveAttrs(el, [], [attr])
      }
    } else {
      this.setOrRemoveAttrs(el, [[attr, val1]], [])
    }
  },

  addOrRemoveClasses(el, adds, removes, transition, time, view, blocking){
    time = time || default_transition_time
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
      if(blocking === false){
        onStart()
        setTimeout(onDone, time)
      } else {
        view.transition(time, onStart, onDone)
      }
      return
    }

    window.requestAnimationFrame(() => {
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

  setOrRemoveAttrs(el, sets, removes){
    let [prevSets, prevRemoves] = DOM.getSticky(el, "attrs", [[], []])

    let alteredAttrs = sets.map(([attr, _val]) => attr).concat(removes)
    let newSets = prevSets.filter(([attr, _val]) => !alteredAttrs.includes(attr)).concat(sets)
    let newRemoves = prevRemoves.filter((attr) => !alteredAttrs.includes(attr)).concat(removes)

    DOM.putSticky(el, "attrs", currentEl => {
      newRemoves.forEach(attr => currentEl.removeAttribute(attr))
      newSets.forEach(([attr, val]) => currentEl.setAttribute(attr, val))
      return [newSets, newRemoves]
    })
  },

  hasAllClasses(el, classes){ return classes.every(name => el.classList.contains(name)) },

  isToggledOut(el, outClasses){
    return !this.isVisible(el) || this.hasAllClasses(el, outClasses)
  },

  filterToEls(liveSocket, sourceEl, {to}){
    let defaultQuery = () => {
      if(typeof(to) === "string"){
        return document.querySelectorAll(to)
      } else if(to.closest){
        let toEl = sourceEl.closest(to.closest)
        return toEl ? [toEl] : []
      } else if(to.inner){
        return sourceEl.querySelectorAll(to.inner)
      }
    }
    return to ? liveSocket.jsQuerySelectorAll(sourceEl, to, defaultQuery) : [sourceEl]
  },

  defaultDisplay(el){
    return {tr: "table-row", td: "table-cell"}[el.tagName.toLowerCase()] || "block"
  },

  transitionClasses(val){
    if(!val){ return null }

    let [trans, tStart, tEnd] = Array.isArray(val) ? val : [val.split(" "), [], []]
    trans = Array.isArray(trans) ? trans : trans.split(" ")
    tStart = Array.isArray(tStart) ? tStart : tStart.split(" ")
    tEnd = Array.isArray(tEnd) ? tEnd : tEnd.split(" ")
    return [trans, tStart, tEnd]
  }
}

export default JS

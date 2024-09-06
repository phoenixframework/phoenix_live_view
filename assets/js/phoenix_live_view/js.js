import DOM from "./dom"
import ARIA from "./aria"

let focusStack = []
let default_transition_time = 200

let JS = {
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

  exec_exec(eventType, phxEvent, view, sourceEl, el, {attr, to}){
    let nodes = to ? DOM.all(document, to) : [sourceEl]
    nodes.forEach(node => {
      let encodedJS = node.getAttribute(attr)
      if(!encodedJS){ throw new Error(`expected ${attr} to contain JS command on "${to}"`) }
      view.liveSocket.execJS(node, encodedJS, eventType)
    })
  },

  exec_dispatch(eventType, phxEvent, view, sourceEl, el, {to, event, detail, bubbles}){
    detail = detail || {}
    detail.dispatcher = sourceEl
    DOM.dispatchEvent(el, event, {detail, bubbles})
  },

  exec_push(eventType, phxEvent, view, sourceEl, el, args){
    let {event, data, target, page_loading, loading, value, dispatcher, callback} = args
    let pushOpts = {loading, value, target, page_loading: !!page_loading}
    let targetSrc = eventType === "change" && dispatcher ? dispatcher : sourceEl
    let phxTarget = target || targetSrc.getAttribute(view.binding("target")) || targetSrc
    view.withinTargets(phxTarget, (targetView, targetCtx) => {
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
    })
  },

  exec_navigate(eventType, phxEvent, view, sourceEl, el, {href, replace}){
    view.liveSocket.historyRedirect(href, replace ? "replace" : "push")
  },

  exec_patch(eventType, phxEvent, view, sourceEl, el, {href, replace}){
    view.liveSocket.pushHistoryPatch(href, replace ? "replace" : "push", sourceEl)
  },

  exec_focus(eventType, phxEvent, view, sourceEl, el){
    window.requestAnimationFrame(() => ARIA.attemptFocus(el))
  },

  exec_focus_first(eventType, phxEvent, view, sourceEl, el){
    window.requestAnimationFrame(() => ARIA.focusFirstInteractive(el) || ARIA.focusFirst(el))
  },

  exec_push_focus(eventType, phxEvent, view, sourceEl, el){
    window.requestAnimationFrame(() => focusStack.push(el || sourceEl))
  },

  exec_pop_focus(eventType, phxEvent, view, sourceEl, el){
    window.requestAnimationFrame(() => {
      const el = focusStack.pop()
      if(el){ el.focus() }
    })
  },

  exec_add_class(eventType, phxEvent, view, sourceEl, el, {names, transition, time, blocking}){
    this.addOrRemoveClasses(el, names, [], transition, time, view, blocking)
  },

  exec_remove_class(eventType, phxEvent, view, sourceEl, el, {names, transition, time, blocking}){
    this.addOrRemoveClasses(el, [], names, transition, time, view, blocking)
  },

  exec_toggle_class(eventType, phxEvent, view, sourceEl, el, {to, names, transition, time, blocking}){
    this.toggleClasses(el, names, transition, time, view, blocking)
  },

  exec_toggle_attr(eventType, phxEvent, view, sourceEl, el, {attr: [attr, val1, val2]}){
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

  exec_transition(eventType, phxEvent, view, sourceEl, el, {time, transition, blocking}){
    this.addOrRemoveClasses(el, [], [], transition, time, view, blocking)
  },

  exec_toggle(eventType, phxEvent, view, sourceEl, el, {display, ins, outs, time, blocking}){
    this.toggle(eventType, view, el, display, ins, outs, time, blocking)
  },

  exec_show(eventType, phxEvent, view, sourceEl, el, {display, transition, time, blocking}){
    this.show(eventType, view, el, display, transition, time, blocking)
  },

  exec_hide(eventType, phxEvent, view, sourceEl, el, {display, transition, time, blocking}){
    this.hide(eventType, view, el, display, transition, time, blocking)
  },

  exec_set_attr(eventType, phxEvent, view, sourceEl, el, {attr: [attr, val]}){
    this.setOrRemoveAttrs(el, [[attr, val]], [])
  },

  exec_remove_attr(eventType, phxEvent, view, sourceEl, el, {attr}){
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
          let stickyDisplay = display || this.defaultDisplay(el)
          DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = stickyDisplay)
          window.requestAnimationFrame(() => {
            this.addOrRemoveClasses(el, inClasses, [])
            window.requestAnimationFrame(() => this.addOrRemoveClasses(el, inEndClasses, inStartClasses))
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

  toggleClasses(el, classes, transition, time, view){
    window.requestAnimationFrame(() => {
      let [prevAdds, prevRemoves] = DOM.getSticky(el, "classes", [[], []])
      let newAdds = classes.filter(name => prevAdds.indexOf(name) < 0 && !el.classList.contains(name))
      let newRemoves = classes.filter(name => prevRemoves.indexOf(name) < 0 && el.classList.contains(name))
      this.addOrRemoveClasses(el, newAdds, newRemoves, transition, time, view)
    })
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

  filterToEls(sourceEl, {to}){
    return to ? DOM.all(document, to) : [sourceEl]
  },

  defaultDisplay(el){
    return {tr: "table-row", td: "table-cell"}[el.tagName.toLowerCase()] || "block"
  }
}

export default JS
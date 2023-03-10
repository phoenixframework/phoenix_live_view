import DOM from "./dom"
import ARIA from "./aria"

let focusStack = null

let JS = {
  exec(eventType, phxEvent, view, sourceEl, defaults){
    let [defaultKind, defaultArgs] = defaults || [null, {}]
    let commands = phxEvent.charAt(0) === "[" ?
      JSON.parse(phxEvent) : [[defaultKind, defaultArgs]]

    commands.forEach(([kind, args]) => {
      if(kind === defaultKind && defaultArgs.data){
        args.data = Object.assign(args.data || {}, defaultArgs.data)
      }
      this.filterToEls(sourceEl, args).forEach(el => {
        this[`exec_${kind}`](eventType, phxEvent, view, sourceEl, el, args)
      })
    })
  },

  isVisible(el){
    return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length > 0)
  },

  // private

  // commands

  exec_exec(eventType, phxEvent, view, sourceEl, el, [attr, to]){
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
    if(!view.isConnected()){ return }

    let {event, data, target, page_loading, loading, value, dispatcher} = args
    let pushOpts = {loading, value, target, page_loading: !!page_loading}
    let targetSrc = eventType === "change" && dispatcher ? dispatcher : sourceEl
    let phxTarget = target || targetSrc.getAttribute(view.binding("target")) || targetSrc
    view.withinTargets(phxTarget, (targetView, targetCtx) => {
      if(eventType === "change"){
        let {newCid, _target, callback} = args
        _target = _target || (DOM.isFormInput(sourceEl) ? sourceEl.name : undefined)
        if(_target){ pushOpts._target = _target }
        targetView.pushInput(sourceEl, targetCtx, newCid, event || phxEvent, pushOpts, callback)
      } else if(eventType === "submit"){
        let {submitter} = args
        targetView.submitForm(sourceEl, targetCtx, event || phxEvent, submitter, pushOpts)
      } else {
        targetView.pushEvent(eventType, sourceEl, targetCtx, event || phxEvent, data, pushOpts)
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
    window.requestAnimationFrame(() => focusStack = el || sourceEl)
  },

  exec_pop_focus(eventType, phxEvent, view, sourceEl, el){
    window.requestAnimationFrame(() => {
      if(focusStack){ focusStack.focus() }
      focusStack = null
    })
  },

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

  addOrRemoveClasses(el, adds, removes, transition, time, view){
    let [transition_run, transition_start, transition_end] = transition || [[], [], []]
    if(transition_run.length > 0){
      let onStart = () => this.addOrRemoveClasses(el, transition_start.concat(transition_run), [])
      let onDone = () => this.addOrRemoveClasses(el, adds.concat(transition_end), removes.concat(transition_run).concat(transition_start))
      return view.transition(time, onStart, onDone)
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

    let alteredAttrs = sets.map(([attr, _val]) => attr).concat(removes);
    let newSets = prevSets.filter(([attr, _val]) => !alteredAttrs.includes(attr)).concat(sets);
    let newRemoves = prevRemoves.filter((attr) => !alteredAttrs.includes(attr)).concat(removes);

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

import DOM from "./dom"

let JS = {
  exec(eventType, phxEvent, view, el, defaults){
    let [defaultKind, defaultArgs] = defaults || [null, {}]
    let commands = phxEvent.charAt(0) === "[" ?
      JSON.parse(phxEvent) : [[defaultKind, defaultArgs]]

    commands.forEach(([kind, args]) => {
      if(kind === defaultKind && defaultArgs.data){
        args.data = Object.assign(args.data || {}, defaultArgs.data)
      }
      this[`exec_${kind}`](eventType, phxEvent, view, el, args)
    })
  },

  isVisible(el){
    let style = window.getComputedStyle(el)
    return !(style.opacity === 0 || style.display === "none")
  },

  // private

  // commands

  exec_dispatch(eventType, phxEvent, view, sourceEl, {to, event, detail}){
    if(to){
      DOM.all(document, to, el => DOM.dispatchEvent(el, event, detail))
    } else {
      DOM.dispatchEvent(sourceEl, event, detail)
    }
  },

  exec_push(eventType, phxEvent, view, sourceEl, args){
    let {event, data, target, page_loading, loading, value} = args
    let pushOpts = {page_loading: !!page_loading, loading: loading, value: value}
    let targetSrc = eventType === "change" ? sourceEl.form : sourceEl
    let phxTarget = target || targetSrc.getAttribute(view.binding("target")) || targetSrc
    view.withinTargets(phxTarget, (targetView, targetCtx) => {
      if(eventType === "change"){
        let {newCid, _target, callback} = args
        if(_target){ pushOpts._target = _target }
        targetView.pushInput(sourceEl, targetCtx, newCid, event || phxEvent, pushOpts, callback)
      } else if(eventType === "submit"){
        targetView.submitForm(sourceEl, targetCtx, event || phxEvent, pushOpts)
      } else {
        targetView.pushEvent(eventType, sourceEl, targetCtx, event || phxEvent, data, pushOpts)
      }
    })
  },

  exec_add_class(eventType, phxEvent, view, sourceEl, {to, names, transition, time}){
    if(to){
      DOM.all(document, to, el => this.addOrRemoveClasses(el, names, [], transition, time, view))
    } else {
      this.addOrRemoveClasses(sourceEl, names, [], transition, view)
    }
  },

  exec_remove_class(eventType, phxEvent, view, sourceEl, {to, names, transition, time}){
    if(to){
      DOM.all(document, to, el => this.addOrRemoveClasses(el, [], names, transition, time, view))
    } else {
      this.addOrRemoveClasses(sourceEl, [], names, transition, time, view)
    }
  },

  exec_transition(eventType, phxEvent, view, sourceEl, {time, to, transition}){
    let els = to ? DOM.all(document, to) : [sourceEl]
    let [transition_start, running, transition_end] = transition
    els.forEach(el => {
      let onStart = () => this.addOrRemoveClasses(el, transition_start.concat(running), [])
      let onDone = () => this.addOrRemoveClasses(el, transition_end, transition_start.concat(running))
      view.transition(time, onStart, onDone)
    })
  },

  exec_toggle(eventType, phxEvent, view, sourceEl, {to, display, ins, outs, time}){
    if(to){
      DOM.all(document, to, el => this.toggle(eventType, view, el, display, ins, outs, time))
    } else {
      this.toggle(eventType, view, sourceEl, display, ins, outs, time)
    }
  },

  exec_show(eventType, phxEvent, view, sourceEl, {to, display, transition, time}){
    if(to){
      DOM.all(document, to, el => this.show(eventType, view, el, display, transition, time))
    } else {
      this.show(eventType, view, sourceEl, transition, time)
    }
  },

  exec_hide(eventType, phxEvent, view, sourceEl, {to, display, transition, time}){
    if(to){
      DOM.all(document, to, el => this.hide(eventType, view, el, display, transition, time))
    } else {
      this.hide(eventType, view, sourceEl, display, transition, time)
    }
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
        view.transition(time, onStart, () => {
          this.addOrRemoveClasses(el, [], outClasses.concat(outEndClasses))
          DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = "none")
        })
      } else {
        if(eventType === "remove"){ return }
        let onStart = () => {
          this.addOrRemoveClasses(el, inStartClasses, outClasses.concat(outStartClasses).concat(outEndClasses))
          DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = (display || "block"))
          window.requestAnimationFrame(() => {
            this.addOrRemoveClasses(el, inClasses, [])
            window.requestAnimationFrame(() => this.addOrRemoveClasses(el, inEndClasses, inStartClasses))
          })
        }
        view.transition(time, onStart, () => {
          this.addOrRemoveClasses(el, [], inClasses.concat(inEndClasses))
        })
      }
    } else {
      let newDisplay = this.isVisible(el) ? "none" : (display || "block")
      DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = newDisplay)
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

  hasAllClasses(el, classes){ return classes.every(name => el.classList.contains(name)) },

  isToggledOut(el, outClasses){
    return !this.isVisible(el) || this.hasAllClasses(el, outClasses)
  }
}

export default JS

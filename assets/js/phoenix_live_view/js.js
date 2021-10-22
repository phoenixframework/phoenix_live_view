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

  exec_transition(eventType, phxEvent, view, sourceEl, {time, to, names}){
    let els = to ? DOM.all(document, to) : [sourceEl]
    els.forEach(el => {
      this.addOrRemoveClasses(el, names, [])
      view.transition(time, () => this.addOrRemoveClasses(el, [], names))
    })
  },

  exec_toggle(eventType, phxEvent, view, sourceEl, {to, display, ins, outs, time}){
    if(to){
      DOM.all(document, to, el => this.toggle(eventType, view, el, display, ins || [], outs || [], time))
    } else {
      this.toggle(eventType, view, sourceEl, display, ins || [], outs || [], time)
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
    let isVisible = this.isVisible(el)
    if(transition.length > 0 && !isVisible){
      this.toggle(eventType, view, el, display, transition, [], time)
    } else if(!isVisible){
      this.toggle(eventType, view, el, display, [], [], null)
    }
  },

  hide(eventType, view, el, display, transition, time){
    let isVisible = this.isVisible(el)
    if(transition.length > 0 && isVisible){
      this.toggle(eventType, view, el, display, [], transition, time)
    } else if(isVisible){
      this.toggle(eventType, view, el, display, [], [], time)
    }
  },

  toggle(eventType, view, el, display, in_classes, out_classes, time){
    if(in_classes.length > 0 || out_classes.length > 0){
      if(this.isVisible(el)){
        this.addOrRemoveClasses(el, out_classes, in_classes)
        view.transition(time, () => {
          DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = "none")
          this.addOrRemoveClasses(el, [], out_classes)
        })
      } else {
        if(eventType === "remove"){ return }
        this.addOrRemoveClasses(el, in_classes, out_classes)
        DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = (display || "block"))
        view.transition(time, () => {
          this.addOrRemoveClasses(el, [], in_classes)
        })
      }
    } else {
      let newDisplay = this.isVisible(el) ? "none" : (display || "block")
      DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = newDisplay)
    }
  },

  addOrRemoveClasses(el, adds, removes, transition, time, view){
    if(transition && transition.length > 0){
      this.addOrRemoveClasses(el, transition, [])
      return view.transition(time, () => this.addOrRemoveClasses(el, adds, removes.concat(transition)))
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

  isVisible(el){
    let style = window.getComputedStyle(el)
    return !(style.opacity === 0 || style.display === "none")
  },

  isToggledOut(el, out_classes){
    return !this.isVisible(el) || this.hasAllClasses(el, out_classes)
  }
}

export default JS

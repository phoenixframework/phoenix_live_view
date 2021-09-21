import DOM from "./dom"

let Cmd = {
	exec(eventType, phxEvent, view, el, [defaultKind, defaultArgs]){
		let commands = phxEvent.charAt(0) === "{" ?
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
		DOM.all(document, to, el => DOM.dispatchEvent(el, event, detail))
	},

	exec_push(eventType, phxEvent, view, sourceEl, {event, data, target} = meta){
		let phxTarget = target || sourceEl.getAttribute(view.binding("target")) || sourceEl
		view.withinTargets(phxTarget, (targetView, targetCtx) => {
			if(eventType === "click"){
        targetView.pushClick(sourceEl, event || phxEvent, targetCtx, data)
			} else if(eventType === "change"){
				let {newCid, _target} = meta
		  	targetView.pushInput(sourceEl, targetCtx, newCid, phxEvent || event, _target)
			} else if(eventType === "submit"){
        targetView.submitForm(sourceEl, targetCtx, phxEvent || event)
			} else {
			  targetView.pushEvent(eventType, sourceEl, targetCtx, event || phxEvent, data)
			}
		})
	},

	exec_add_class(eventType, phxEvent, view, sourceEl, {to, names}){
		if(to){
			DOM.all(document, to, el => this.addOrRemoveClasses(el, names, []))
		} else {
			this.addOrRemoveClasses(sourceEl, names, [])
		}
	},

	exec_remove_class(eventType, phxEvent, view, sourceEl, {to, names}){
		if(to){
			DOM.all(document, to, el => this.addOrRemoveClasses(el, [], names))
		} else {
      this.addOrRemoveClasses(sourceEl, [], names)
		}
	},

	exec_toggle(eventType, phxEvent, view, sourceEl, {to}){
		if(to){
		  DOM.all(document, to, el => this.toggle(el, "inline-block"))
		} else {
			this.toggle(sourceEl, "inline-block")
		}
	},

	// utils for commands

  toggle(el, defaultDisplay){
    let newDisplay = el.style.display === "none" ? defaultDisplay : "none"
    DOM.putSticky(el, "toggle", currentEl => currentEl.style.display = newDisplay)
  },

  addOrRemoveClasses(el, addClasses, removeClasses){
		let [prevAdds, prevRemoves] = DOM.getSticky(el, "classes", [[], []])
		let newAdds = prevAdds.filter(name => removeClasses.indexOf(name) >= 0).concat(addClasses)
		let newRemoves = prevRemoves.filter(name => addClasses.indexOf(name) >= 0).concat(removeClasses)

    DOM.putSticky(el, "classes", currentEl => {
      newAdds.forEach(name => currentEl.classList.add(name))
      newRemoves.forEach(name => currentEl.classList.remove(name))
			return [newAdds, newRemoves]
    })
  }
}

export default Cmd
import JS from "./js"

export default (liveSocket, eventType) => {
  return {
    /**
     * Executes encoded JavaScript in the context of the element.
     *
     * @param {string} encodedJS - The encoded JavaScript string to execute.
     */
    exec(el, encodedJS){
      liveSocket.execJS(el, encodedJS, eventType)
    },

    /**
     * Shows an element.
     *
     * @param {HTMLElement} el - The element to show.
     * @param {Object} [opts={}] - Optional settings.
     * @param {string} [opts.display] - The CSS display value to set. Defaults "block".
     * @param {string} [opts.transition] - The CSS transition classes to set when showing.
     * @param {number} [opts.time] - The transition duration in milliseconds. Defaults 200.
     * @param {boolean} [opts.blocking] - The boolean flag to block the UI during the transition.
     *  Defaults `true`.
     */
    show(el, opts = {}){
      let owner = liveSocket.owner(el)
      JS.show(eventType, owner, el, opts.display, opts.transition, opts.time, opts.blocking)
    },

    /**
     * Hides an element.
     *
     * @param {HTMLElement} el - The element to hide.
     * @param {Object} [opts={}] - Optional settings.
     * @param {string} [opts.transition] - The CSS transition classes to set when hiding.
     * @param {number} [opts.time] - The transition duration in milliseconds. Defaults 200.
     * @param {boolean} [opts.blocking] - The boolean flag to block the UI during the transition.
     *   Defaults `true`.
     */
    hide(el, opts = {}){
      let owner = liveSocket.owner(el)
      JS.hide(eventType, owner, el, null, opts.transition, opts.time, opts.blocking)
    },

    /**
     * Toggles the visibility of an element.
     *
     * @param {HTMLElement} el - The element to toggle.
     * @param {Object} [opts={}] - Optional settings.
     * @param {string} [opts.display] - The CSS display value to set. Defaults "block".
     * @param {string} [opts.in] - The CSS transition classes for showing.
     *   Accepts either the string of classes to apply when toggling in, or
     *   a 3-tuple containing the transition class, the class to apply
     *   to start the transition, and the ending transition class, such as:
     *
     *       ["ease-out duration-300", "opacity-0", "opacity-100"]
     *
     * @param {string} [opts.out] - The CSS transition classes for hiding.
     *   Accepts either string of classes to apply when toggling out, or
     *   a 3-tuple containing the transition class, the class to apply
     *   to start the transition, and the ending transition class, such as:
     *
     *       ["ease-out duration-300", "opacity-100", "opacity-0"]
     *
     * @param {number} [opts.time] - The transition duration in milliseconds.
     *
     * @param {boolean} [opts.blocking] - The boolean flag to block the UI during the transition.
     *   Defaults `true`.
     */
    toggle(el, opts = {}){
      let owner = liveSocket.owner(el)
      opts.in = JS.transitionClasses(opts.in)
      opts.out = JS.transitionClasses(opts.out)
      JS.toggle(eventType, owner, el, opts.display, opts.in, opts.out, opts.time, opts.blocking)
    },

    /**
     * Adds CSS classes to an element.
     *
     * @param {HTMLElement} el - The element to add classes to.
     * @param {string|string[]} names - The class name(s) to add.
     * @param {Object} [opts={}] - Optional settings.
     * @param {string} [opts.transition] - The CSS transition property to set.
     *   Accepts a string of classes to apply when adding classes or
     *   a 3-tuple containing the transition class, the class to apply
     *   to start the transition, and the ending transition class, such as:
     *
     *       ["ease-out duration-300", "opacity-0", "opacity-100"]
     *
     * @param {number} [opts.time] - The transition duration in milliseconds.
     * @param {boolean} [opts.blocking] - The boolean flag to block the UI during the transition.
     *   Defaults `true`.
     */
    addClass(el, names, opts = {}){
      names = Array.isArray(names) ? names : names.split(" ")
      let owner = liveSocket.owner(el)
      JS.addOrRemoveClasses(el, names, [], opts.transition, opts.time, owner, opts.blocking)
    },

    /**
     * Removes CSS classes from an element.
     *
     * @param {HTMLElement} el - The element to remove classes from.
     * @param {string|string[]} names - The class name(s) to remove.
     * @param {Object} [opts={}] - Optional settings.
     * @param {string} [opts.transition] - The CSS transition classes to set.
     *   Accepts a string of classes to apply when removing classes or
     *   a 3-tuple containing the transition class, the class to apply
     *   to start the transition, and the ending transition class, such as:
     *
     *       ["ease-out duration-300", "opacity-100", "opacity-0"]
     *
     * @param {number} [opts.time] - The transition duration in milliseconds.
     * @param {boolean} [opts.blocking] - The boolean flag to block the UI during the transition.
     *   Defaults `true`.
     */
    removeClass(el, names, opts = {}){
      opts.transition = JS.transitionClasses(opts.transition)
      names = Array.isArray(names) ? names : names.split(" ")
      let owner = liveSocket.owner(el)
      JS.addOrRemoveClasses(el, [], names, opts.transition, opts.time, owner, opts.blocking)
    },

    /**
     * Toggles CSS classes on an element.
     *
     * @param {HTMLElement} el - The element to toggle classes on.
     * @param {string|string[]} names - The class name(s) to toggle.
     * @param {Object} [opts={}] - Optional settings.
     * @param {string} [opts.transition] - The CSS transition classes to set.
     *   Accepts a string of classes to apply when toggling classes or
     *   a 3-tuple containing the transition class, the class to apply
     *   to start the transition, and the ending transition class, such as:
     *
     *       ["ease-out duration-300", "opacity-100", "opacity-0"]
     *
     * @param {number} [opts.time] - The transition duration in milliseconds.
     * @param {boolean} [opts.blocking] - The boolean flag to block the UI during the transition.
     *   Defaults `true`.
     */
    toggleClass(el, names, opts = {}){
      opts.transition = JS.transitionClasses(opts.transition)
      names = Array.isArray(names) ? names : names.split(" ")
      let owner = liveSocket.owner(el)
      JS.toggleClasses(el, names, opts.transition, opts.time, owner, opts.blocking)
    },

    /**
     * Applies a CSS transition to an element.
     *
     * @param {HTMLElement} el - The element to apply the transition to.
     * @param {string|string[]} transition - The transition class(es) to apply.
     *   Accepts a string of classes to apply when transitioning or
     *   a 3-tuple containing the transition class, the class to apply
     *   to start the transition, and the ending transition class, such as:
     *
     *       ["ease-out duration-300", "opacity-100", "opacity-0"]
     *
     * @param {Object} [opts={}] - Optional settings.
     * @param {number} [opts.time] - The transition duration in milliseconds.
     * @param {boolean} [opts.blocking] - The boolean flag to block the UI during the transition.
     *   Defaults `true`.
     */
    transition(el, transition, opts = {}){
      let owner = liveSocket.owner(el)
      JS.addOrRemoveClasses(el, [], [], JS.transitionClasses(transition), opts.time, owner, opts.blocking)
    },

    /**
     * Sets an attribute on an element.
     *
     * @param {HTMLElement} el - The element to set the attribute on.
     * @param {string} attr - The attribute name to set.
     * @param {string} val - The value to set for the attribute.
     */
    setAttribute(el, attr, val){ JS.setOrRemoveAttrs(el, [[attr, val]], []) },

    /**
     * Removes an attribute from an element.
     *
     * @param {HTMLElement} el - The element to remove the attribute from.
     * @param {string} attr - The attribute name to remove.
     */
    removeAttribute(el, attr){ JS.setOrRemoveAttrs(el, [], [attr]) },

    /**
     * Toggles an attribute on an element between two values.
     *
     * @param {HTMLElement} el - The element to toggle the attribute on.
     * @param {string} attr - The attribute name to toggle.
     * @param {string} val1 - The first value to toggle between.
     * @param {string} val2 - The second value to toggle between.
     */
    toggleAttribute(el, attr, val1, val2){ JS.toggleAttr(el, attr, val1, val2) },

    /**
     * Pushes an event to the server.
     * 
     * @param {(HTMLElement|number)} el - An element that belongs to the target LiveView.
     *   To target a LiveComponent by its ID, pass a separate `target` in the options.
     * @param {string} type - The string event name to push.
     * @param {Object} [opts={}] - Optional settings.
     */
    push(el, type, opts = {}){
      liveSocket.withinOwners(el, view => {
        const data = opts.value || {}
        delete opts.value
        let e = new CustomEvent("phx:exec", {detail: {sourceElement: el}})
        JS.exec(e, eventType, type, view, el, ["push", {data, ...opts}])
      })
    },

    /**
     * Sends a navigation event to the server and updates the browser's pushState history.
     * 
     * @param {string} href - The URL to navigate to.
     * @param {Object} [opts={}] - Optional settings.
     */
    navigate(href, opts = {}){
      let e = new CustomEvent("phx:exec")
      liveSocket.historyRedirect(e, href, opts.replace ? "replace" : "push", null, null)
    },

    /**
     * Sends a patch event to the server and updates the browser's pushState history.
     * 
     * @param {string} href - The URL to patch to.
     * @param {Object} [opts={}] - Optional settings.
     */
    patch(href, opts = {}){
      let e = new CustomEvent("phx:exec")
      liveSocket.pushHistoryPatch(e, href, opts.replace ? "replace" : "push", null)
    },

    /**
     * Mark attributes as ignored, skipping them when patching the DOM.
     * 
     * @param {HTMLElement} el - The element to toggle the attribute on.
     * @param {Array<string>|string} attrs - The attribute name or names to ignore.
     */
    ignoreAttributes(el, attrs){ JS.ignoreAttrs(el, attrs) }
  }
}

import JS from "./js"
import DOM from "./dom"

const HOOK_ID = "hookId"

let viewHookID = 1
export default class ViewHook {
  static makeID(){ return viewHookID++ }
  static elementID(el){ return DOM.private(el, HOOK_ID) }

  constructor(view, el, callbacks){
    this.el = el
    this.__attachView(view)
    this.__callbacks = callbacks
    this.__listeners = new Set()
    this.__isDisconnected = false
    DOM.putPrivate(this.el, HOOK_ID, this.constructor.makeID())
    for(let key in this.__callbacks){ this[key] = this.__callbacks[key] }
  }

  __attachView(view){
    if(view){
      this.__view = () => view
      this.liveSocket = view.liveSocket
    } else {
      this.__view = () => {
        throw new Error(`hook not yet attached to a live view: ${this.el.outerHTML}`)
      }
      this.liveSocket = null
    }
  }

  __mounted(){ this.mounted && this.mounted() }
  __updated(){ this.updated && this.updated() }
  __beforeUpdate(){ this.beforeUpdate && this.beforeUpdate() }
  __destroyed(){ this.destroyed && this.destroyed() }
  __reconnected(){
    if(this.__isDisconnected){
      this.__isDisconnected = false
      this.reconnected && this.reconnected()
    }
  }
  __disconnected(){
    this.__isDisconnected = true
    this.disconnected && this.disconnected()
  }

  /**
   * Binds the hook to JS commands.
   *
   * @param {ViewHook} hook - The ViewHook instance to bind.
   *
   * @returns {Object} An object with methods to manipulate the DOM and execute JavaScript.
   */
  js(){
    let hook = this

    return {
      /**
       * Executes encoded JavaScript in the context of the hook element.
       *
       * @param {string} encodedJS - The encoded JavaScript string to execute.
       */
      exec(encodedJS){
        hook.__view().liveSocket.execJS(hook.el, encodedJS, "hook")
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
        let owner = hook.__view().liveSocket.owner(el)
        JS.show("hook", owner, el, opts.display, opts.transition, opts.time, opts.blocking)
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
        let owner = hook.__view().liveSocket.owner(el)
        JS.hide("hook", owner, el, null, opts.transition, opts.time, opts.blocking)
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
        let owner = hook.__view().liveSocket.owner(el)
        opts.in = JS.transitionClasses(opts.in)
        opts.out = JS.transitionClasses(opts.out)
        JS.toggle("hook", owner, el, opts.display, opts.in, opts.out, opts.time, opts.blocking)
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
        let owner = hook.__view().liveSocket.owner(el)
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
        let owner = hook.__view().liveSocket.owner(el)
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
        let owner = hook.__view().liveSocket.owner(el)
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
        let owner = hook.__view().liveSocket.owner(el)
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
    }
  }

  pushEvent(event, payload = {}, onReply = function (){ }){
    return this.__view().pushHookEvent(this.el, null, event, payload, onReply)
  }

  pushEventTo(phxTarget, event, payload = {}, onReply = function (){ }){
    return this.__view().withinTargets(phxTarget, (view, targetCtx) => {
      return view.pushHookEvent(this.el, targetCtx, event, payload, onReply)
    })
  }

  handleEvent(event, callback){
    let callbackRef = (customEvent, bypass) => bypass ? event : callback(customEvent.detail)
    window.addEventListener(`phx:${event}`, callbackRef)
    this.__listeners.add(callbackRef)
    return callbackRef
  }

  removeHandleEvent(callbackRef){
    let event = callbackRef(null, true)
    window.removeEventListener(`phx:${event}`, callbackRef)
    this.__listeners.delete(callbackRef)
  }

  upload(name, files){
    return this.__view().dispatchUploads(null, name, files)
  }

  uploadTo(phxTarget, name, files){
    return this.__view().withinTargets(phxTarget, (view, targetCtx) => {
      view.dispatchUploads(targetCtx, name, files)
    })
  }

  __cleanup__(){
    this.__listeners.forEach(callbackRef => this.removeHandleEvent(callbackRef))
  }
}
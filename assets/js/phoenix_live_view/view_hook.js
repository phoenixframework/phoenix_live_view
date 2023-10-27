/**
 * @typedef {object} HookCallbacks - The type interface of user-defined hook callback objects
 * @property {(this: ViewHook) => void} [mounted] - Called when the element has been added to the DOM and its server LiveView has finished mounting.
 * @property {(this: ViewHook) => void} [destroyed] - Called when element has been removed from the page (either parent update or parent removal).
 * @property {(this: ViewHook) => void} [beforeDestroy] - Called when the element is about to be removed from the DOM.
 * @property {(this: ViewHook) => void} [updated] - Called when the element has been updated in the DOM.
 * @property {(this: ViewHook) => void} [beforeUpdate] - Called when the element is about to be updated in the DOM.
 * @property {(this: ViewHook) => void} [disconnected] - Called when the element's parent view has disconnected from the server.
 * @property {(this: ViewHook) => void} [reconnected] - Called when the element's parent view has reconnected to the server.
 */

let viewHookID = 1

export default class ViewHook {
  /**
   * Create a hook ID
   * @returns {number} ID unique to this browser tab
   */
  static makeID(){ return viewHookID++ }

  /**
   * Get ID for the hook bound to this element
   * @param {Element} el 
   * @returns {number|undefined}
   */
  static elementID(el){ return el.phxHookId }

  /**
   * Constructor - Wraps user-defined hook callbacks with a consistent interface.
   *
   * The callbacks will run with the scope of an instance of this class: thus,
   * all methods and attributes on ViewHook will be availble to the user-defined
   * callbacks.
   * @param {import('./view.js').default} view 
   * @param {Element} el - attribute referencing the bound DOM node
   * @param {HookCallbacks} callbacks 
   */
  constructor(view, el, callbacks){
    this.__view = view
    this.liveSocket = view.liveSocket
    this.__callbacks = callbacks
    this.__listeners = new Set()
    this.__isDisconnected = false
    this.el = el
    this.el.phxHookId = this.constructor.makeID()
    for(let key in this.__callbacks){ this[key] = this.__callbacks[key] }
  }

  /**
   * Call the user-provided mounted() callback, if defined
   * @public
   */
  __mounted(){ this.mounted && this.mounted() }

  /**
   * Call the user-provided updated() callback, if defined
   * @public
   */
  __updated(){ this.updated && this.updated() }

  /**
   * Call the user-provided beforeUpdate() callback, if defined
   * @public
   */
  __beforeUpdate(){ this.beforeUpdate && this.beforeUpdate() }

  /**
   * Call the user-provided destroyed() callback, if defined
   * @public
   */
  __destroyed(){ this.destroyed && this.destroyed() }

  /**
   * Call the user-provided reconnected() callback, if defined
   * @public
   */
  __reconnected(){
    if(this.__isDisconnected){
      this.__isDisconnected = false
      this.reconnected && this.reconnected()
    }
  }

  /**
   * Call the user-provided disconnected() callback, if defined
   * @public
   */
  __disconnected(){
    this.__isDisconnected = true
    this.disconnected && this.disconnected()
  }

  /**
   * Push an event to the server
   * @public
   * @param {string} event 
   * @param {any} payload 
   * @param {(reply: any, ref: number) => void} [onReply] 
   * @returns {number} ref
   */
  pushEvent(event, payload = {}, onReply = function (){ }){
    return this.__view.pushHookEvent(this.el, null, event, payload, onReply)
  }

  /**
   * Push targeted events from the client to LiveViews and LiveComponents. It
   * sends the event to the LiveComponent or LiveView the phxTarget is defined
   * in, where its value can be either a query selector or an actual DOM
   * element. 
   *
   * NOTE: If the query selector returns more than one element it will send the
   * event to all of them, even if all the elements are in the same
   * LiveComponent or LiveView.
   * @public
   * @param {string|Element} phxTarget 
   * @param {string} event 
   * @param {any} payload 
   * @param {(reply: any, ref: number) => void} [onReply] 
   * @returns 
   */
  pushEventTo(phxTarget, event, payload = {}, onReply = function (){ }){
    return this.__view.withinTargets(phxTarget, (view, targetCtx) => {
      return view.pushHookEvent(this.el, targetCtx, event, payload, onReply)
    })
  }

  /**
   * Register callback to handle phoenix events
   * @public
   * @param {string} event 
   * @param {(payload: any) => void} callback - receives as payload the CustomEvent's detail
   * @returns {(payload: any, bypass?: boolean) => string|void} the registered callback reference; can be used to remove the event
   */
  handleEvent(event, callback){
    let callbackRef = (customEvent, bypass) => bypass ? event : callback(customEvent.detail)
    window.addEventListener(`phx:${event}`, callbackRef)
    this.__listeners.add(callbackRef)
    return callbackRef
  }

  /**
   * Remove a registered phoenix event callback
   * @public
   * @param {(payload: any, bypass?: boolean) => string|void} callbackRef 
   */
  removeHandleEvent(callbackRef){
    let event = callbackRef(null, true)
    window.removeEventListener(`phx:${event}`, callbackRef)
    this.__listeners.delete(callbackRef)
  }

  /**
   * Inject a list of file-like objects into the uploader.
   * @public
   * @param {string} name 
   * @param {File[]} files 
   */
  upload(name, files){
    return this.__view.dispatchUploads(null, name, files)
  }

  /**
   * Inject a list of file-like objects into an uploader. The hook
   * will send the files to the uploader with name defined by allow_upload/3 on
   * the server-side. Dispatching new uploads triggers an input change event
   * which will be sent to the LiveComponent or LiveView the phxTarget is
   * defined in, where its value can be either a query selector or an actual DOM
   * element. 
   * 
   * NOTE: If the query selector returns more than one live file input, an
   * error will be logged.
   * @public
   * @param {string|Element} phxTarget 
   * @param {string} name 
   * @param {File[]} files 
   */
  uploadTo(phxTarget, name, files){
    return this.__view.withinTargets(phxTarget, (view, targetCtx) => {
      view.dispatchUploads(targetCtx, name, files)
    })
  }

  /**
   * Teardown resources for hook and callbacks
   * @public
   */
  __cleanup__(){
    this.__listeners.forEach(callbackRef => this.removeHandleEvent(callbackRef))
  }
}

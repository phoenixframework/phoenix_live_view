import jsCommands from "./js_commands"
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
  __beforeUpdate(fromEl, toEl){ this.beforeUpdate && this.beforeUpdate(fromEl, toEl) }
  __destroyed(){
    this.destroyed && this.destroyed()
    DOM.deletePrivate(this.el, HOOK_ID) // https://github.com/phoenixframework/phoenix_live_view/issues/3496
  }
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
   * @returns {Object} An object with methods to manipulate the DOM and execute JavaScript.
   */
  js(){
    let hook = this

    return {
      ...jsCommands(hook.__view().liveSocket, "hook"),
      /**
       * Executes encoded JavaScript in the context of the element.
       *
       * @param {string} encodedJS - The encoded JavaScript string to execute.
       */
      exec(encodedJS){
        hook.__view().liveSocket.execJS(hook.el, encodedJS, "hook")
      }
    }
  }

  pushEvent(event, payload = {}, onReply){
    if(onReply === undefined){
      return new Promise((resolve, reject) => {
        try {
          const ref = this.__view().pushHookEvent(this.el, null, event, payload, (reply, _ref) => resolve(reply))
          if(ref === false){
            reject(new Error("unable to push hook event. LiveView not connected"))
          }
        } catch (error){
          reject(error)
        }
      })
    }
    return this.__view().pushHookEvent(this.el, null, event, payload, onReply)
  }

  pushEventTo(phxTarget, event, payload = {}, onReply){
    if(onReply === undefined){
      return new Promise((resolve, reject) => {
        try {
          this.__view().withinTargets(phxTarget, (view, targetCtx) => {
            const ref = view.pushHookEvent(this.el, targetCtx, event, payload, (reply, _ref) => resolve(reply))
            if(ref === false){
              reject(new Error("unable to push hook event. LiveView not connected"))
            }
          })
        } catch (error){
          reject(error)
        }
      })
    }
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

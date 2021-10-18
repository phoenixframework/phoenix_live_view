let viewHookID = 1
export default class ViewHook {
  static makeID(){ return viewHookID++ }
  static elementID(el){ return el.phxHookId }

  constructor(view, el, callbacks){
    this.__view = view
    this.__liveSocket = view.liveSocket
    this.__callbacks = callbacks
    this.__listeners = new Set()
    this.__isDisconnected = false
    this.el = el
    this.el.phxHookId = this.constructor.makeID()
    for(let key in this.__callbacks){ this[key] = this.__callbacks[key] }
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

  pushEvent(event, payload = {}, onReply = function (){ }){
    return this.__view.pushHookEvent(null, event, payload, onReply)
  }

  pushEventTo(phxTarget, event, payload = {}, onReply = function (){ }){
    return this.__view.withinTargets(phxTarget, (view, targetCtx) => {
      return view.pushHookEvent(targetCtx, event, payload, onReply)
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
    return this.__view.dispatchUploads(name, files)
  }

  uploadTo(phxTarget, name, files){
    return this.__view.withinTargets(phxTarget, view => view.dispatchUploads(name, files))
  }

  __cleanup__(){
    this.__listeners.forEach(callbackRef => this.removeHandleEvent(callbackRef))
  }
}

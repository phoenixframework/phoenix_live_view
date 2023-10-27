/**
 * General utility functions.
 * 
 * Module Type Dependencies:
 * @typedef {import('./view.js').default} View
 * @typedef {import('./live_socket.js').default} LiveSocket
 * @typedef {import('./upload_entry').default} UploadEntry
 */

import {
  PHX_VIEW_SELECTOR
} from "./constants"

import EntryUploader from "./entry_uploader"


/**
 * Write string to browser error console
 * @param {string} msg 
 * @param {object} obj 
 * @returns 
 */
export let logError = (msg, obj) => console.error && console.error(msg, obj)

/**
 * Is the value a component ID? e.g. "0", "1", 32, "543", 8
 * @param {string | number} cid 
 * @returns {boolean}
 */
export let isCid = (cid) => {
  let type = typeof(cid)
  return type === "number" || (type === "string" && /^(0|[1-9]\d*)$/.test(cid))
}

/**
 * Check all Element IDs for any duplicates and log a warning if found.
 */
export function detectDuplicateIds(){
  let ids = new Set()
  let elems = document.querySelectorAll("*[id]")
  for(let i = 0, len = elems.length; i < len; i++){
    if(ids.has(elems[i].id)){
      console.error(`Multiple IDs detected: ${elems[i].id}. Ensure unique element ids.`)
    } else {
      ids.add(elems[i].id)
    }
  }
}


/**
 * If debug is enabled, log debug messages.
 * @param {View} view 
 * @param {string} kind
 * @param {string} msg 
 * @param {object} obj 
 */
export let debug = (view, kind, msg, obj) => {
  if(view.liveSocket.isDebugEnabled()){
    console.log(`${view.id} ${kind}: ${msg} - `, obj)
  }
}

/**
 * Wrap given value in closure or returns closure
 * @param {any} val 
 * @returns {function}
 */
export let closure = (val) => typeof val === "function" ? val : function (){ return val }

/**
 * Deep-clone a given object.
 * @template T
 * @param {T} obj 
 * @returns {T} cloned obj
 */
export let clone = (obj) => { return JSON.parse(JSON.stringify(obj)) }

/**
 * Lookup the closest element with the given phoenix binding attribute
 * @param {HTMLElement} el 
 * @param {string} binding 
 * @param {HTMLElement} [borderEl]
 * @returns {HTMLElement | null}
 */
export let closestPhxBinding = (el, binding, borderEl) => {
  do {
    if(el.matches(`[${binding}]`) && !el.disabled){ return el }
    el = el.parentElement || el.parentNode
  } while(el !== null && el.nodeType === 1 && !((borderEl && borderEl.isSameNode(el)) || el.matches(PHX_VIEW_SELECTOR)))
  return null
}

/**
 * Is the given value an object (but not an array)?
 * @param {any} obj 
 * @returns {boolean}
 */
export let isObject = (obj) => {
  return obj !== null && typeof obj === "object" && !(obj instanceof Array)
}

/**
 * Deep equality check
 * @param {any} obj1 
 * @param {any} obj2 
 * @returns {boolean}
 */
export let isEqualObj = (obj1, obj2) => JSON.stringify(obj1) === JSON.stringify(obj2)

/**
 * Is object/array empty?
 * @param {object|array} obj 
 * @returns {boolean}
 */
export let isEmpty = (obj) => {
  for(let x in obj){ return false }
  return true
}

/**
 * If given value is truthy, call the callback with that value
 * @template T, V
 * @param {T} el 
 * @param {(el: T) => V} callback
 * @returns {V}
 */
export let maybe = (el, callback) => el && callback(el)

/**
 * Create and run an uploader for all given upload entries
 * @param {UploadEntry[]} entries 
 * @param {function} onError 
 * @param {object} resp
 * @param {LiveSocket} liveSocket 
 */
export let channelUploader = function (entries, onError, resp, liveSocket){
  entries.forEach(entry => {
    let entryUploader = new EntryUploader(entry, resp.config.chunk_size, liveSocket)
    entryUploader.upload()
  })
}

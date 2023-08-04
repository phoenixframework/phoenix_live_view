import {
  PHX_VIEW_SELECTOR
} from "./constants"

import EntryUploader from "./entry_uploader"

export let logError = (msg, obj) => console.error && console.error(msg, obj)

export let isCid = (cid) => {
  let type = typeof(cid)
  return type === "number" || (type === "string" && /^(0|[1-9]\d*)$/.test(cid))
}

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

export let debug = (view, kind, msg, obj) => {
  if(view.liveSocket.isDebugEnabled()){
    console.log(`${view.id} ${kind}: ${msg} - `, obj)
  }
}

// wraps value in closure or returns closure
export let closure = (val) => typeof val === "function" ? val : function (){ return val }

export let clone = (obj) => { return JSON.parse(JSON.stringify(obj)) }

export let closestPhxBinding = (el, binding, borderEl) => {
  do {
    if(el.matches(`[${binding}]`) && !el.disabled){ return el }
    el = el.parentElement || el.parentNode
  } while(el !== null && el.nodeType === 1 && !((borderEl && borderEl.isSameNode(el)) || el.matches(PHX_VIEW_SELECTOR)))
  return null
}

export let isObject = (obj) => {
  return obj !== null && typeof obj === "object" && !(obj instanceof Array)
}

export let isEqualObj = (obj1, obj2) => JSON.stringify(obj1) === JSON.stringify(obj2)

export let isEmpty = (obj) => {
  for(let x in obj){ return false }
  return true
}

export let maybe = (el, callback) => el && callback(el)

export let channelUploader = function (entries, onError, resp, liveSocket){
  entries.forEach(entry => {
    let entryUploader = new EntryUploader(entry, resp.config.chunk_size, liveSocket)
    entryUploader.upload()
  })
}

export let parsePhxKey = (key) => {
  if(!key){ return [] }
  return key.match(/[^.\]]+(?=[^\]]*$)/g) || []
}

// Thanks to Alpine.js https://github.com/alpinejs/alpine/blob/main/packages/alpinejs/src/utils/on.js#L108 
export let hasSpecificKeyBeenPressed = (e, keys) => {

  // If no key is defined, its a press
  if (keys.length === 0) return true

  // If one is passed, AND it matches the key pressed, we'll call it a press.
  if (keys.length === 1 && keyToModifiers(e.key).includes(keys[0])) return true

  // The user is listening for key combinations.
  const systemKeyModifiers = ['ctrl', 'shift', 'alt', 'meta', 'cmd', 'super']
  const selectedSystemKeyModifiers = systemKeyModifiers.filter(modifier => keys.includes(modifier))

  keys = keys.filter(i => ! selectedSystemKeyModifiers.includes(i))
  if (selectedSystemKeyModifiers.length > 0) {
      const activelyPressedKeyModifiers = selectedSystemKeyModifiers.filter(modifier => {
          // Alias "cmd" and "super" to "meta"
          if (modifier === 'cmd' || modifier === 'super') modifier = 'meta'

          return e[`${modifier}Key`]
      })

      // If all the modifiers selected are pressed, ...
      if (activelyPressedKeyModifiers.length === selectedSystemKeyModifiers.length) {
          // AND the remaining key is pressed as well. It's a press.
          if (keyToModifiers(e.key).includes(keys[0])) return true
      }
  }

  return false
}

function kebabCase(subject) {
  if ([' ','_'].includes(subject)) return subject
  return subject.replace(/([a-z])([A-Z])/g, '$1-$2').replace(/[_\s]/, '-').toLowerCase()
}

// Thanks to Alpine.js https://github.com/alpinejs/alpine/blob/main/packages/alpinejs/src/utils/on.js#L154
export let keyToModifiers = (key) => {
  if (!key) return []
  key = kebabCase(key)
  let modifierToKeyMap = {
      'ctrl': 'control',
      'slash': '/',
      'space': ' ',
      'spacebar': ' ',
      'cmd': 'meta',
      'esc': 'escape',
      'up': 'arrow-up',
      'down': 'arrow-down',
      'left': 'arrow-left',
      'right': 'arrow-right',
      'period': '.',
      'equal': '=',
      'minus': '-',
      'underscore': '_',
  }

  modifierToKeyMap[key] = key

  return Object.keys(modifierToKeyMap).map(modifier => {
      if (modifierToKeyMap[modifier] === key) return modifier
  }).filter(modifier => modifier)
}

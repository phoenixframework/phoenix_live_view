export let debug = (view, kind, msg, obj) => {
  console.log(`${view.id} ${kind}: ${msg} - `, obj)
}

export let isObject = obj => {
  return typeof obj === 'object' && !(obj instanceof Array)
}

export let isEmpty = obj => {
  return Object.keys(obj).length === 0
}

export let maybe = (el, key) => {
  if (el) {
    return el[key]
  } else {
    return null
  }
}

export let recursiveMerge = (target, source) => {
  for (let key in source) {
    let val = source[key]
    if (isObject(val) && target[key]) {
      recursiveMerge(target[key], val)
    } else {
      target[key] = val
    }
  }
}

import {
  COMPONENTS,
  DYNAMICS,
  TEMPLATES,
  EVENTS,
  PHX_COMPONENT,
  PHX_SKIP,
  REPLY,
  STATIC,
  TITLE,
  STREAM,
} from "./constants"

import {
  isObject,
  logError,
  isCid,
} from "./utils"

export let stripRootComments = (html) => {
  let tagNameMatch = html.match(/<([a-zA-Z][^>\s]*)/)
  if(!tagNameMatch) return [html, null, null]

  let tagName = tagNameMatch[1]
  let regex = new RegExp(`(?:<!--[\\s\\S]*?-->)|(?:<${tagName}[\\s\\S]*?>.*<\\/${tagName}>[\\s\\S]*?)`, "g")

  let cleanedHTML = html.match(regex)
  if(!cleanedHTML){ return [html, null, null] }

  return cleanedHTML.reduce(([html, start, end], commentOrTag) => {
    let isComment = commentOrTag.startsWith("<!--")
    if(!isComment){
      return [commentOrTag, start, end]
    } else if(!html && !start){
      return [html, commentOrTag, end]
    } else if(!html && start && !end){
      return [html, start + commentOrTag, end]
    } else if(!end){
      return [html, start, commentOrTag]
    } else if(isComment){
      return [html, start, end + commentOrTag]
    } else {
      return [html, start, end]
    }
  }, [null, null, null])
}

export let modifyRoot = (html, attrs, innerHTML) => {
  html = html.trim()
  let rootEndsAt = html.indexOf(">")
  let isSelfClosing = html.charAt(rootEndsAt - 1) === "/"
  let rootContent = html.slice(0, isSelfClosing ? rootEndsAt - 1: rootEndsAt)
  let newAttrs = []
  Object.keys(attrs).forEach(attr => {
    if(!rootContent.includes(`${attr}="`)){ newAttrs.push([attr, attrs[attr]]) }
  })
  if(newAttrs.length === 0){ return html }

  let rootTag = rootContent.slice(1, rootContent.indexOf(" "))
  let rest
  if(isSelfClosing){
    rest = "/>"
  } else {
    if(typeof(innerHTML) === "string"){
      rest = ">" + innerHTML + `</${rootTag}>`
    } else {
      rest = ">" + html.slice(rootEndsAt + 1)
    }
  }

  return `${rootContent} ${newAttrs.map(([attr, val]) => `${attr}="${val}"`).join(" ")}${rest}`
}

export default class Rendered {
  static extract(diff){
    let {[REPLY]: reply, [EVENTS]: events, [TITLE]: title} = diff
    delete diff[REPLY]
    delete diff[EVENTS]
    delete diff[TITLE]
    return {diff, title, reply: reply || null, events: events || []}
  }

  constructor(viewId, rendered){
    this.viewId = viewId
    this.rendered = {}
    this.mergeDiff(rendered)
  }

  parentViewId(){ return this.viewId }

  toString(onlyCids){
    let [str, streams] = this.recursiveToString(this.rendered, this.rendered[COMPONENTS], onlyCids)
    return [str, streams]
  }

  recursiveToString(rendered, components = rendered[COMPONENTS], onlyCids){
    onlyCids = onlyCids ? new Set(onlyCids) : null
    let output = {buffer: "", components: components, onlyCids: onlyCids, streams: new Set()}
    this.toOutputBuffer(rendered, null, output)
    return [output.buffer, output.streams]
  }

  componentCIDs(diff){ return Object.keys(diff[COMPONENTS] || {}).map(i => parseInt(i)) }

  isComponentOnlyDiff(diff){
    if(!diff[COMPONENTS]){ return false }
    return Object.keys(diff).length === 1
  }

  getComponent(diff, cid){ return diff[COMPONENTS][cid] }

  mergeDiff(diff){
    let newc = diff[COMPONENTS]
    let cache = {}
    delete diff[COMPONENTS]
    this.rendered = this.mutableMerge(this.rendered, diff)
    this.rendered[COMPONENTS] = this.rendered[COMPONENTS] || {}

    if(newc){
      let oldc = this.rendered[COMPONENTS]

      for(let cid in newc){
        newc[cid] = this.cachedFindComponent(cid, newc[cid], oldc, newc, cache)
      }

      for(let cid in newc){ oldc[cid] = newc[cid] }
      diff[COMPONENTS] = newc
    }
  }

  cachedFindComponent(cid, cdiff, oldc, newc, cache){
    if(cache[cid]){
      return cache[cid]
    } else {
      let ndiff, stat, scid = cdiff[STATIC]

      if(isCid(scid)){
        let tdiff

        if(scid > 0){
          tdiff = this.cachedFindComponent(scid, newc[scid], oldc, newc, cache)
        } else {
          tdiff = oldc[-scid]
        }

        stat = tdiff[STATIC]
        ndiff = this.cloneMerge(tdiff, cdiff)
        ndiff[STATIC] = stat
      } else {
        ndiff = cdiff[STATIC] !== undefined ? cdiff : this.cloneMerge(oldc[cid] || {}, cdiff)
      }

      cache[cid] = ndiff
      return ndiff
    }
  }

  mutableMerge(target, source){
    if(source[STATIC] !== undefined){
      return source
    } else {
      this.doMutableMerge(target, source)
      return target
    }
  }

  doMutableMerge(target, source){
    for(let key in source){
      let val = source[key]
      let targetVal = target[key]
      let isObjVal = isObject(val)
      if(isObjVal && val[STATIC] === undefined && isObject(targetVal)){
        this.doMutableMerge(targetVal, val)
      } else {
        target[key] = val
      }
    }
  }

  cloneMerge(target, source){
    let merged = {...target, ...source}
    for(let key in merged){
      let val = source[key]
      let targetVal = target[key]
      if(isObject(val) && val[STATIC] === undefined && isObject(targetVal)){
        merged[key] = this.cloneMerge(targetVal, val)
      }
    }
    return merged
  }

  componentToString(cid){
    let [str, streams] = this.recursiveCIDToString(this.rendered[COMPONENTS], cid, null, false)
    return [str, streams]
  }

  pruneCIDs(cids){
    cids.forEach(cid => delete this.rendered[COMPONENTS][cid])
  }

  // private

  get(){ return this.rendered }

  isNewFingerprint(diff = {}){ return !!diff[STATIC] }

  templateStatic(part, templates){
    if(typeof (part) === "number") {
      return templates[part]
    } else {
      return part
    }
  }

  toOutputBuffer(rendered, templates, output){
    if(rendered[DYNAMICS]){ return this.comprehensionToBuffer(rendered, templates, output) }
    let {[STATIC]: statics} = rendered
    statics = this.templateStatic(statics, templates)

    output.buffer += statics[0]
    for(let i = 1; i < statics.length; i++){
      this.dynamicToBuffer(rendered[i - 1], templates, output)
      output.buffer += statics[i]
    }
  }

  comprehensionToBuffer(rendered, templates, output){
    let {[DYNAMICS]: dynamics, [STATIC]: statics, [STREAM]: stream} = rendered
    let [_ref, _inserts, deleteIds, reset] = stream || [null, {}, [], null]
    statics = this.templateStatic(statics, templates)
    let compTemplates = templates || rendered[TEMPLATES]
    for(let d = 0; d < dynamics.length; d++){
      let dynamic = dynamics[d]
      output.buffer += statics[0]
      for(let i = 1; i < statics.length; i++){
        this.dynamicToBuffer(dynamic[i - 1], compTemplates, output)
        output.buffer += statics[i]
      }
    }

    if(stream !== undefined && (rendered[DYNAMICS].length > 0 || deleteIds.length > 0 || reset)){
      delete rendered[STREAM]
      rendered[DYNAMICS] = []
      output.streams.add(stream)
    }
  }

  dynamicToBuffer(rendered, templates, output){
    if(typeof (rendered) === "number"){
      let [str, streams] = this.recursiveCIDToString(output.components, rendered, output.onlyCids)
      output.buffer += str
      output.streams = new Set([...output.streams, ...streams])
    } else if(isObject(rendered)){
      this.toOutputBuffer(rendered, templates, output)
    } else {
      output.buffer += rendered
    }
  }

  recursiveCIDToString(components, cid, onlyCids, allowRootComments = true){
    let component = components[cid] || logError(`no component for CID ${cid}`, components)
    let [html, streams] = this.recursiveToString(component, components, onlyCids)
    let skip = onlyCids && !onlyCids.has(cid)
    let [strippedHTML, commentBefore, commentAfter] = stripRootComments(html)
    let attrs = {[PHX_COMPONENT]: cid, id: `${this.parentViewId()}-${cid}`}
    if(skip){ attrs[PHX_SKIP] = ""}
    let newHTML = modifyRoot(strippedHTML, attrs, skip ? "" : null)
    if(allowRootComments){ newHTML = `${commentBefore || ""}${newHTML}${commentAfter || ""}` }

    return [newHTML, streams]
  }

  createSpan(text, cid){
    let span = document.createElement("span")
    span.innerText = text
    span.setAttribute(PHX_COMPONENT, cid)
    return span
  }
}
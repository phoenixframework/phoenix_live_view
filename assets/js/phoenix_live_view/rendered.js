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
  ROOT,
} from "./constants"

import {
  isObject,
  logError,
  isCid,
} from "./utils"

export let modifyRoot = (html, attrs, innerHTML) => {
  html = html.trim()
  let tagStartsAt = null
  let pos = 0
  while(pos < html.length){
    let maybeStart = html.indexOf("<", pos)
    if(maybeStart === -1){ break }
    if(maybeStart >= 0 && html.charAt(maybeStart + 1) !== "!"){
      tagStartsAt = maybeStart
      break
    }
    pos += html.indexOf("-->", pos)
  }

  let commentBefore = tagStartsAt === 0 ? null : html.slice(0, tagStartsAt).trim()
  let contentAfter = null
  html = html.slice(tagStartsAt).trimStart()
  let tagNamesEndsAt = html.length
  for(let i = 1; i < html.length; i++){
    let char = html.charAt(i)
    if([">", " ", "\n", "\t", "\r"].indexOf(char) >= 0 || (char === "!" && html.charAt(i + 1) === ">")){
      tagNamesEndsAt = i
      break
    }
  }

  let tag = html.slice(1, tagNamesEndsAt)
  let tagOpenEndsAt = html.indexOf(">")
  let isUnclosed = tagOpenEndsAt === -1
  if(isUnclosed){ tagOpenEndsAt = html.length }

  let tagInnerHTML
  let closingTag
  let isVoid = html.charAt(tagOpenEndsAt - 1) === "/"
  let tagOpenContent = isVoid ? html.slice(tagNamesEndsAt, tagOpenEndsAt - 1) : html.slice(tagNamesEndsAt, tagOpenEndsAt)

  if(isVoid){
    contentAfter = html.slice(tagOpenEndsAt + 1) || null
  } else if(!isUnclosed){
    closingTag = `</${tag}>`
    let tagInnerEndsAt = html.lastIndexOf(closingTag)
    tagInnerHTML = html.slice(tagOpenEndsAt + 1, tagInnerEndsAt)
    contentAfter = html.slice(tagInnerEndsAt + closingTag.length)
  }

  let attrsStr =
    Object.keys(attrs)
    .filter(attr => tagOpenContent.indexOf(`${attr}=`) === -1)
    .map(attr => attrs[attr] === true ? attr : `${attr}="${attrs[attr]}"`)
    .join(" ")

  if(innerHTML === ""){
    tagOpenContent = ` ${attrsStr}`
  } else {
    tagOpenContent = ` ${attrsStr}${tagOpenContent}`
  }

  if(isUnclosed){
    return [`<${tag}${tagOpenContent}`, commentBefore || "", ""]
  } else if(tagOpenEndsAt === html.length - 1){
    return [`<${tag}${tagOpenContent}${isVoid ? "/" : ""}>`, commentBefore || "", ""]
  }

  let closingContent
  if(isVoid){
    closingContent = "/>"
  } else {
    closingContent = `>${typeof(innerHTML) === "string" ? innerHTML : tagInnerHTML}${closingTag}`
  }
  let newHTML = `<${tag}` + tagOpenContent + closingContent
  let commentAfter = contentAfter && contentAfter.indexOf("<!--") >= 0 ? contentAfter.trim() : null
  return [newHTML, commentBefore || "", commentAfter || ""]
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
    this.magicId = 0
    this.mergeDiff(rendered)
  }

  parentViewId(){ return this.viewId }

  toString(onlyCids){
    let [str, streams] = this.recursiveToString(this.rendered, this.rendered[COMPONENTS], onlyCids, false)
    return [str, streams]
  }

  recursiveToString(rendered, components = rendered[COMPONENTS], onlyCids, insideComponent){
    onlyCids = onlyCids ? new Set(onlyCids) : null
    let output = {buffer: "", components: components, onlyCids: onlyCids, streams: new Set(), insideComponent}
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
    if(target[ROOT]){
      target.changed = true
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

  nextMagicID(){
    this.magicId++
    return this.magicId
  }

  toOutputBuffer(rendered, templates, output){
    if(rendered[DYNAMICS]){ return this.comprehensionToBuffer(rendered, templates, output) }
    let {[STATIC]: statics} = rendered
    statics = this.templateStatic(statics, templates)
    let currentOut = {
      buffer: "",
      components: output.components,
      onlyCids: output.onlyCids,
      streams: output.streams,
      insideComponent: output.insideComponent
    }
    let firstRootRender = false
    let isRoot = rendered[ROOT] && !output.insideComponent

    if(isRoot && !rendered.magicId){
      firstRootRender = true
      rendered.magicId = this.nextMagicID()
    }

    // output.buffer += statics[0]
    currentOut.buffer += statics[0]
    for(let i = 1; i < statics.length; i++){
      this.dynamicToBuffer(rendered[i - 1], templates, currentOut)
      currentOut.buffer += statics[i]
    }

    if(isRoot){
      let skip = !rendered.changed && !firstRootRender && currentOut.streams.size === output.streams.size
      let attrs = {"phx-id": rendered.magicId}
      if(skip){ attrs[PHX_SKIP] = true }
      let [newRoot, commentBefore, commentAfter] = modifyRoot(currentOut.buffer, attrs, skip ? "" : null)
      rendered.changed = false
      currentOut.buffer = `${commentBefore}${newRoot}${commentAfter}`
    }

    output.buffer += currentOut.buffer
    output.components = currentOut.components
    output.insideComponent = currentOut.insideComponent
    output.onlyCids = currentOut.onlyCids
    output.streams = currentOut.streams
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
    let [html, streams] = this.recursiveToString(component, components, onlyCids, true)
    let skip = onlyCids && !onlyCids.has(cid)
    let attrs = {[PHX_COMPONENT]: cid, id: `${this.parentViewId()}-${cid}`}
    if(skip){ attrs[PHX_SKIP] = ""}
    let [newHTML, commentBefore, commentAfter] = modifyRoot(html, attrs, skip ? "" : null)
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
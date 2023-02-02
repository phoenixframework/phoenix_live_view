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
    let [str, streams] = this.recursiveCIDToString(this.rendered[COMPONENTS], cid)
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
    let [_inserts, deleteIds] = stream || [{}, []]
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

    if(stream !== undefined && (rendered[DYNAMICS].length > 0 || deleteIds.length > 0)){
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

  recursiveCIDToString(components, cid, onlyCids){
    let component = components[cid] || logError(`no component for CID ${cid}`, components)
    let template = document.createElement("template")
    let [html, streams] = this.recursiveToString(component, components, onlyCids)
    template.innerHTML = html
    let container = template.content
    let skip = onlyCids && !onlyCids.has(cid)

    let [hasChildNodes, hasChildComponents] =
      Array.from(container.childNodes).reduce(([hasNodes, hasComponents], child, i) => {
        if(child.nodeType === Node.ELEMENT_NODE){
          if(child.getAttribute(PHX_COMPONENT)){
            return [hasNodes, true]
          }
          child.setAttribute(PHX_COMPONENT, cid)
          if(!child.id){ child.id = `${this.parentViewId()}-${cid}-${i}` }
          if(skip){
            child.setAttribute(PHX_SKIP, "")
            child.innerHTML = ""
          }
          return [true, hasComponents]
        } else {
          if(child.nodeValue.trim() !== ""){
            logError("only HTML element tags are allowed at the root of components.\n\n" +
              `got: "${child.nodeValue.trim()}"\n\n` +
              "within:\n", template.innerHTML.trim())
            child.replaceWith(this.createSpan(child.nodeValue, cid))
            return [true, hasComponents]
          } else {
            child.remove()
            return [hasNodes, hasComponents]
          }
        }
      }, [false, false])

    if(!hasChildNodes && !hasChildComponents){
      logError("expected at least one HTML element tag inside a component, but the component is empty:\n",
        template.innerHTML.trim())
      return [this.createSpan("", cid).outerHTML, streams]
    } else if(!hasChildNodes && hasChildComponents){
      logError("expected at least one HTML element tag directly inside a component, but only subcomponents were found. A component must render at least one HTML tag directly inside itself.",
        template.innerHTML.trim())
      return [template.innerHTML, streams]
    } else {
      return [template.innerHTML, streams]
    }
  }

  createSpan(text, cid){
    let span = document.createElement("span")
    span.innerText = text
    span.setAttribute(PHX_COMPONENT, cid)
    return span
  }
}

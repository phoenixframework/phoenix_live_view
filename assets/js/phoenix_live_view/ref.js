import {
  PHX_REF,
  PHX_REF_SRC,
} from "./constants"

import DOM from "./dom"
const REF_CLONES = "ref-clones"

export default class Ref {
  constructor(el){
    this._el = el
    if(!el.hasAttribute(PHX_REF)){
      throw new Error(`no phx-ref for element: ${el.outerHTML}`)
    }
  }

  isAckedBy(refInt){ return refInt >= this.val() }

  el(){ return this._el }
  val(){ return parseInt(this.el().getAttribute(PHX_REF), 10) }
  src(){ return this.el().getAttribute(PHX_REF_SRC) }

  clones(){ return DOM.private(this.el(), REF_CLONES) || [] }

  stashClone(){
    // TODO do not stash clone for forms that are phx-submit
    let clones = this.clones()
    let lastClone = clones[clones.length - 1]
    let clone = lastClone ? lastClone.clone.cloneNode(true) : this.el().cloneNode(true)
    clone.setAttribute(PHX_REF, this.val())
    clone.setAttribute(PHX_REF_SRC, this.src())
    if(DOM.isFormInput(this.el())){ clone.value = this.el().value }
    DOM.putPrivate(this.el(), REF_CLONES, clones.concat([{clone, ref: this.val()}]))
    return clone
  }

  deleteClone(ref){
    let newClones = this.clones().filter(({clone, ref: cloneRef}) => cloneRef !== ref)
    DOM.putPrivate(this.el(), REF_CLONES, newClones)
  }
}
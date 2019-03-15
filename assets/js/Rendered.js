import { recursiveMerge, isObject } from './utilities'

export let Rendered = {
  mergeDiff(source, diff) {
    if (this.isNewFingerprint(diff)) {
      return diff
    } else {
      recursiveMerge(source, diff)
      return source
    }
  },
  isNewFingerprint(diff) {
    return diff.static
  },
  toString(rendered) {
    let output = { buffer: '' }
    this.toOutputBuffer(rendered, output)
    return output.buffer
  },
  toOutputBuffer(rendered, output) {
    if (rendered.dynamics) {
      return this.comprehensionToBuffer(rendered, output)
    }
    let { static: statics } = rendered
    output.buffer += statics[0]
    for (let i = 1; i < statics.length; i++) {
      this.dynamicToBuffer(rendered[i - 1], output)
      output.buffer += statics[i]
    }
  },
  comprehensionToBuffer(rendered, output) {
    let { dynamics: dynamics, static: statics } = rendered
    for (let d = 0; d < dynamics.length; d++) {
      let dynamic = dynamics[d]
      output.buffer += statics[0]
      for (let i = 1; i < statics.length; i++) {
        this.dynamicToBuffer(dynamic[i - 1], output)
        output.buffer += statics[i]
      }
    }
  },
  dynamicToBuffer(rendered, output) {
    if (isObject(rendered)) {
      this.toOutputBuffer(rendered, output)
    } else {
      output.buffer += rendered
    }
  },
}

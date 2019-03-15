import morphdom from 'morphdom'
import {
  PHX_PARENT_ID,
  PHX_DISABLE_WITH,
  PHX_DISABLED,
  PHX_READONLY,
  PHX_ERROR_FOR,
  PHX_HAS_FOCUSED,
  PHX_HAS_SUBMITTED,
  FOCUSABLE_INPUTS,
} from './constants'

export let DOM = {
  disableForm(form, prefix) {
    let disableWith = `${prefix}${PHX_DISABLE_WITH}`
    form.querySelectorAll(`[${disableWith}]`).forEach(el => {
      let value = el.getAttribute(disableWith)
      el.setAttribute(`${disableWith}-restore`, el.innerText)
      el.innerText = value
    })
    form.querySelectorAll('button').forEach(button => {
      button.setAttribute(PHX_DISABLED, button.disabled)
      button.disabled = true
    })
    form.querySelectorAll('input').forEach(input => {
      input.setAttribute(PHX_READONLY, input.readOnly)
      input.readOnly = true
    })
  },
  restoreDisabledForm(form, prefix) {
    let disableWith = `${prefix}${PHX_DISABLE_WITH}`
    form.querySelectorAll(`[${disableWith}]`).forEach(el => {
      let value = el.getAttribute(`${disableWith}-restore`)
      if (value) {
        el.innerText = value
        el.removeAttribute(`${disableWith}-restore`)
      }
    })
    form.querySelectorAll('button').forEach(button => {
      let prev = button.getAttribute(PHX_DISABLED)
      if (prev) {
        button.disabled = prev === 'true'
        button.removeAttribute(PHX_DISABLED)
      }
    })
    form.querySelectorAll('input').forEach(input => {
      let prev = input.getAttribute(PHX_READONLY)
      if (prev) {
        input.readOnly = prev === 'true'
        input.removeAttribute(PHX_READONLY)
      }
    })
  },
  discardError(el) {
    let field = el.getAttribute && el.getAttribute(PHX_ERROR_FOR)
    if (!field) {
      return
    }
    let input = document.getElementById(field)
    if (
      field &&
      !(
        input.getAttribute(PHX_HAS_FOCUSED) ||
        input.form.getAttribute(PHX_HAS_SUBMITTED)
      )
    ) {
      el.style.display = 'none'
    }
  },
  isPhxChild(node) {
    return node.getAttribute && node.getAttribute(PHX_PARENT_ID)
  },
  patch(view, container, id, html) {
    let focused = view.liveSocket.getActiveElement()
    let selectionStart = null
    let selectionEnd = null
    if (DOM.isTextualInput(focused)) {
      selectionStart = focused.selectionStart
      selectionEnd = focused.selectionEnd
    }
    morphdom(container, `<div>${html}</div>`, {
      childrenOnly: true,
      onBeforeNodeAdded: function(el) {
        //input handling
        DOM.discardError(el)
        return el
      },
      onNodeAdded: function(el) {
        // nested view handling
        if (DOM.isPhxChild(el) && view.ownsElement(el)) {
          view.onNewChildAdded(el)
          return true
        }
        view.maybeBindAddedNode(el)
      },
      onBeforeNodeDiscarded: function(el) {
        // nested view handling
        if (DOM.isPhxChild(el)) {
          view.liveSocket.destroyViewById(el.id)
          return true
        }
      },
      onBeforeElUpdated: function(fromEl, toEl) {
        // nested view handling
        if (DOM.isPhxChild(toEl)) {
          DOM.mergeAttrs(fromEl, toEl)
          return false
        }
        // input handling
        if (fromEl.getAttribute && fromEl.getAttribute(PHX_HAS_SUBMITTED)) {
          toEl.setAttribute(PHX_HAS_SUBMITTED, true)
        }
        if (fromEl.getAttribute && fromEl.getAttribute(PHX_HAS_FOCUSED)) {
          toEl.setAttribute(PHX_HAS_FOCUSED, true)
        }
        DOM.discardError(toEl)
        if (DOM.isTextualInput(fromEl) && fromEl === focused) {
          DOM.mergeInputs(fromEl, toEl)
          return false
        } else {
          return true
        }
      },
    })
    DOM.restoreFocus(focused, selectionStart, selectionEnd)
    document.dispatchEvent(new Event('phx:update'))
  },
  mergeAttrs(target, source) {
    source.getAttributeNames().forEach(name => {
      let value = source.getAttribute(name)
      target.setAttribute(name, value)
    })
  },
  mergeInputs(target, source) {
    DOM.mergeAttrs(target, source)
    target.readOnly = source.readOnly
  },
  restoreFocus(focused, selectionStart, selectionEnd) {
    if (!DOM.isTextualInput(focused)) {
      return
    }
    if (focused.value === '' || focused.readOnly) {
      focused.blur()
    }
    focused.focus()
    if (
      (focused.setSelectionRange && focused.type === 'text') ||
      focused.type === 'textarea'
    ) {
      focused.setSelectionRange(selectionStart, selectionEnd)
    }
  },
  isTextualInput(el) {
    return FOCUSABLE_INPUTS.indexOf(el.type) >= 0
  },
}

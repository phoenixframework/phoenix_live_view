import {
  PHX_VIEW_SELECTOR,
  PHX_PARENT_ID,
  PHX_HAS_FOCUSED,
  PHX_HAS_SUBMITTED,
  PHX_VIEW,
  LOADER_TIMEOUT,
  PHX_SESSION,
  PHX_DISCONNECTED_CLASS,
  LOADER_ZOOM,
  PHX_CONNECTED_CLASS,
  PHX_ERROR_CLASS,
  PUSH_TIMEOUT,
  PHX_BOUND,
} from './constants'
import { isEmpty, maybe } from './utilities'
import { Rendered } from './Rendered'
import { Browser } from './Browser'
import { DOM } from './DOM'

export class View {
  constructor(el, liveSocket, parentView) {
    this.liveSocket = liveSocket
    this.parent = parentView
    this.newChildrenAdded = false
    this.gracefullyClosed = false
    this.el = el
    this.prevKey = null
    this.bindingPrefix = liveSocket.getBindingPrefix()
    this.loader = this.el.nextElementSibling
    this.id = this.el.id
    this.view = this.el.getAttribute(PHX_VIEW)
    this.hasBoundUI = false
    this.channel = this.liveSocket.channel(`lv:${this.id}`, () => {
      return { session: this.getSession() }
    })
    this.loaderTimer = setTimeout(() => this.showLoader(), LOADER_TIMEOUT)
    this.bindChannel()
  }
  getSession() {
    return this.el.getAttribute(PHX_SESSION) || this.parent.getSession()
  }
  destroy(callback = function() {}) {
    if (this.hasGracefullyClosed()) {
      this.log('destroyed', () => ['the server view has gracefully closed'])
      callback()
    } else {
      this.log('destroyed', () => [
        'the child has been removed from the parent',
      ])
      this.channel
        .leave()
        .receive('ok', callback)
        .receive('error', callback)
        .receive('timeout', callback)
    }
  }
  hideLoader() {
    clearTimeout(this.loaderTimer)
    this.loader.style.display = 'none'
  }
  showLoader() {
    clearTimeout(this.loaderTimer)
    this.el.classList = PHX_DISCONNECTED_CLASS
    this.loader.style.display = 'block'
    let middle = Math.floor(this.el.clientHeight / LOADER_ZOOM)
    this.loader.style.top = `-${middle}px`
  }
  log(kind, msgCallback) {
    this.liveSocket.log(this, kind, msgCallback)
  }
  onJoin({ rendered }) {
    this.log('join', () => ['', JSON.stringify(rendered)])
    this.rendered = rendered
    this.hideLoader()
    this.el.classList = PHX_CONNECTED_CLASS
    DOM.patch(this, this.el, this.id, Rendered.toString(this.rendered))
    if (!this.hasBoundUI) {
      this.bindUI()
    }
    this.hasBoundUI = true
    this.joinNewChildren()
  }
  joinNewChildren() {
    let selector = `${PHX_VIEW_SELECTOR}[${PHX_PARENT_ID}="${this.id}"]`
    document.querySelectorAll(selector).forEach(childEl => {
      let child = this.liveSocket.getViewById(childEl.id)
      if (!child) {
        this.liveSocket.joinView(childEl, this)
      }
    })
  }
  update(diff) {
    if (isEmpty(diff)) {
      return
    }
    this.log('update', () => ['', JSON.stringify(diff)])
    this.rendered = Rendered.mergeDiff(this.rendered, diff)
    let html = Rendered.toString(this.rendered)
    this.newChildrenAdded = false
    DOM.patch(this, this.el, this.id, html)
    if (this.newChildrenAdded) {
      this.joinNewChildren()
    }
  }
  onNewChildAdded(el) {
    this.newChildrenAdded = true
  }
  bindChannel() {
    this.channel.on('render', diff => this.update(diff))
    this.channel.on('redirect', ({ to, flash }) => Browser.redirect(to, flash))
    this.channel.on('session', ({ token }) =>
      this.el.setAttribute(PHX_SESSION, token)
    )
    this.channel.onError(reason => this.onError(reason))
    this.channel.onClose(() => this.onGracefulClose())
  }
  onGracefulClose() {
    this.gracefullyClosed = true
    this.liveSocket.destroyViewById(this.id)
  }
  hasGracefullyClosed() {
    return this.gracefullyClosed
  }
  join() {
    if (this.parent) {
      this.parent.channel.onError(() => this.channel.leave())
    }
    this.channel
      .join()
      .receive('ok', data => this.onJoin(data))
      .receive('error', resp => this.onJoinError(resp))
  }
  onJoinError(resp) {
    this.displayError()
    this.log('error', () => ['unable to join', resp])
  }
  onError(reason) {
    this.log('error', () => ['view crashed', reason])
    this.liveSocket.onViewError(this)
    document.activeElement.blur()
    this.displayError()
  }
  displayError() {
    this.showLoader()
    this.el.classList = `${PHX_DISCONNECTED_CLASS} ${PHX_ERROR_CLASS}`
  }
  pushWithReply(event, payload, onReply = function() {}) {
    this.channel.push(event, payload, PUSH_TIMEOUT).receive('ok', diff => {
      this.update(diff)
      onReply()
    })
  }
  pushClick(clickedEl, event, phxEvent) {
    event.preventDefault()
    let val =
      clickedEl.getAttribute(this.binding('value')) || clickedEl.value || ''
    this.pushWithReply('event', {
      type: 'click',
      event: phxEvent,
      id: clickedEl.id,
      value: val,
    })
  }
  pushKey(keyElement, kind, event, phxEvent) {
    if (this.prevKey === event.key) {
      return
    }
    this.prevKey = event.key
    this.pushWithReply('event', {
      type: `key${kind}`,
      event: phxEvent,
      id: event.target.id,
      value: keyElement.value || event.key,
    })
  }
  pushInput(inputEl, event, phxEvent) {
    this.pushWithReply('event', {
      type: 'form',
      event: phxEvent,
      id: event.target.id,
      value: this.serializeForm(inputEl.form),
    })
  }
  pushFormSubmit(formEl, event, phxEvent, onReply) {
    if (event) {
      event.target.disabled = true
    }
    this.pushWithReply(
      'event',
      {
        type: 'form',
        event: phxEvent,
        id: (event && event.target.id) || null,
        value: this.serializeForm(formEl),
      },
      onReply
    )
  }
  eachChild(selector, each) {
    return this.el.querySelectorAll(selector).forEach(child => {
      if (this.ownsElement(child)) {
        each(child)
      }
    })
  }
  ownsElement(element) {
    return (
      element.getAttribute(PHX_PARENT_ID) === this.id ||
      maybe(element.closest(PHX_VIEW_SELECTOR), 'id') === this.id
    )
  }
  bindUI() {
    this.bindForms()
    this.eachChild(`[${this.binding('click')}]`, el => this.bindClick(el))
    this.eachChild(`[${this.binding('keyup')}]`, el => this.bindKey(el, 'up'))
    this.eachChild(`[${this.binding('keydown')}]`, el =>
      this.bindKey(el, 'down')
    )
    this.eachChild(`[${this.binding('keypress')}]`, el =>
      this.bindKey(el, 'press')
    )
  }
  bindClick(el) {
    this.bindOwnAddedNode(el, el, this.binding('click'), phxEvent => {
      el.addEventListener('click', e => this.pushClick(el, e, phxEvent))
    })
  }
  bindKey(el, kind) {
    let event = `key${kind}`
    this.bindOwnAddedNode(el, el, this.binding(event), phxEvent => {
      let phxTarget = this.target(el)
      phxTarget.addEventListener(event, e => {
        this.pushKey(el, kind, e, phxEvent)
      })
    })
  }
  bindForms() {
    let change = this.binding('change')
    this.eachChild(`form[${change}] input`, input => {
      this.bindChange(input)
    })
    this.eachChild(`form[${change}] select`, input => {
      this.bindChange(input)
    })
    this.eachChild(`form[${change}] textarea`, textarea => {
      this.bindChange(textarea)
    })
    let submit = this.binding('submit')
    this.eachChild(`form[${submit}]`, form => {
      this.bindSubmit(form)
    })
  }
  bindChange(input) {
    this.onInput(input, (phxEvent, e) => {
      if (DOM.isTextualInput(input)) {
        input.setAttribute(PHX_HAS_FOCUSED, true)
      } else {
        this.liveSocket.setActiveElement(e.target)
      }
      this.pushInput(input, e, phxEvent)
    })
  }
  bindSubmit(form) {
    this.bindOwnAddedNode(form, form, this.binding('submit'), phxEvent => {
      form.addEventListener('submit', e => {
        e.preventDefault()
        this.submitForm(form, phxEvent, e)
      })
      this.scheduleSubmit(form, phxEvent)
    })
  }
  submitForm(form, phxEvent, e) {
    form.setAttribute(PHX_HAS_SUBMITTED, 'true')
    DOM.disableForm(form, this.bindingPrefix)
    this.liveSocket.blurActiveElement(this)
    this.pushFormSubmit(form, e, phxEvent, () => {
      DOM.restoreDisabledForm(form, this.bindingPrefix)
      this.liveSocket.restorePreviouslyActiveFocus()
    })
  }
  scheduleSubmit(form, phxEvent) {
    let everyMs = parseInt(form.getAttribute(this.binding('submit-every')))
    if (everyMs && this.el.contains(form)) {
      setTimeout(() => {
        this.submitForm(form, phxEvent)
        this.scheduleSubmit(form, phxEvent)
      }, everyMs)
    }
  }
  maybeBindAddedNode(el) {
    if (!el.getAttribute || !this.ownsElement(el)) {
      return
    }
    this.bindClick(el)
    this.bindSubmit(el)
    this.bindChange(el)
    this.bindKey(el, 'up')
    this.bindKey(el, 'down')
    this.bindKey(el, 'press')
  }
  binding(kind) {
    return `${this.bindingPrefix}${kind}`
  }
  // private
  serializeForm(form) {
    return new URLSearchParams(new FormData(form)).toString()
  }
  bindOwnAddedNode(el, targetEl, event, callback) {
    if (targetEl && !targetEl.getAttribute) {
      return
    }
    let phxEvent = targetEl.getAttribute(event)
    if (phxEvent && !el.getAttribute(PHX_BOUND) && this.ownsElement(el)) {
      el.setAttribute(PHX_BOUND, true)
      callback(phxEvent)
    }
  }
  onInput(input, callback) {
    if (!input.form) {
      return
    }
    this.bindOwnAddedNode(
      input,
      input.form,
      this.binding('change'),
      phxEvent => {
        let event = input.type === 'radio' ? 'change' : 'input'
        input.addEventListener(event, e => callback(phxEvent, e))
      }
    )
  }
  target(el) {
    let target = el.getAttribute(this.binding('target'))
    if (target === 'window') {
      return window
    } else if (target === 'document') {
      return document
    } else if (target) {
      return document.getElementById(target)
    } else {
      return el
    }
  }
}

import {Socket} from "phoenix"
import LiveSocket, {View, DOM} from '../js/phoenix_live_view'

function liveViewDOM() {
  const div = document.createElement('div')
  div.setAttribute('data-phx-view', '')
  div.setAttribute('data-phx-session', 'abc123')
  div.setAttribute('id', 'container')
  div.setAttribute('class', 'user-implemented-class')
  div.innerHTML = `
    <form>
      <label for="plus">Plus</label>
      <input id="plus" value="1" name="increment" />
      <input type="checkbox" phx-click="toggle_me" />
      <button phx-click="inc_temperature">Inc Temperature</button>
    </form>
  `
  const button = div.querySelector('button')
  const input = div.querySelector('input')
  button.addEventListener('click', () => {
    setTimeout(() => {
      input.value += 1
    }, 200)
  })

  return div
}

describe('View + DOM', function() {
  test('update', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let updatedEl = {
      s: ['<h2>', '</h2>'],
      fingerprint: 123
    }

    let view = new View(el, liveSocket)

    view.update(updatedEl)

    expect(view.el.firstChild.tagName).toBe('H2')
    expect(view.rendered).toBe(updatedEl)
  })

  test('pushWithReply', function() {
    expect.assertions(1)

    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.value).toBe('increment=1')
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.pushWithReply({ target: el.querySelector('form') }, { value: 'increment=1' })
  })

  test('pushWithReply with update', function() {
    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.value).toBe('increment=1')
        return {
          receive(status, cb) {
            let diff = {
              s: ['<h2>', '</h2>'],
              fingerprint: 123
            }
            cb(diff)
          }
        }
      }
    }
    view.channel = channelStub

    view.pushWithReply({ target: el.querySelector('form') }, { value: 'increment=1' })

    expect(view.el.querySelector('form')).toBeTruthy()
  })

  test('pushEvent', function() {
    expect.assertions(3)

    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let input = el.querySelector('input')

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.type).toBe('keyup')
        expect(payload.event).toBeDefined()
        expect(payload.value).toEqual({"value": "1"})
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.pushEvent('keyup', input, "click", {})
  })

  test('pushEvent as checkbox not checked', function() {
    expect.assertions(1)

    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let input = el.querySelector('input[type="checkbox"]')

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.value).toEqual({})
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.pushEvent('click', input, "toggle_me", {})
  })

  test('pushEvent as checkbox when checked', function() {
    expect.assertions(1)

    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let input = el.querySelector('input[type="checkbox"]')
    input.checked = true

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.value).toEqual({"value": "on"})
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.pushEvent('click', input, "toggle_me", {})
  })

  test('pushEvent as checkbox with value', function() {
    expect.assertions(1)

    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let input = el.querySelector('input[type="checkbox"]')
    input.value = "1"
    input.checked = true

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.value).toEqual({"value": "1"})
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.pushEvent('click', input, "toggle_me", {})
  })

  test('pushKey', function() {
    expect.assertions(3)

    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let input = el.querySelector('input')

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.type).toBe('keydown')
        expect(payload.event).toBeDefined()
        expect(payload.value).toEqual({"key": "A", "value": "1"})
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.pushKey(input, 'keydown', 'move', {key: "A"})
  })

  test('pushInput', function() {
    expect.assertions(3)

    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let input = el.querySelector('input')

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.type).toBe('form')
        expect(payload.event).toBeDefined()
        expect(payload.value).toBe('increment=1&_target=increment')
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.pushInput(input, 'validate', { target: input })
  })

  test('submitForm', function() {
    expect.assertions(7)

    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let form = el.querySelector('form')

    let view = new View(el, liveSocket)
    let channelStub = {
      push(evt, payload, timeout) {
        expect(payload.type).toBe('form')
        expect(payload.event).toBeDefined()
        expect(payload.value).toBe('increment=1')
        return {
          receive() {}
        }
      }
    }
    view.channel = channelStub

    view.submitForm(form, { target: form })
    expect(DOM.private(form, 'phx-has-submitted')).toBeTruthy()
    expect(form.classList.contains('phx-loading')).toBeTruthy()
    expect(form.querySelector('button').dataset.phxDisabled).toBeTruthy()
    expect(form.querySelector('input').dataset.phxReadonly).toBeTruthy()
  })
})

describe('View', function() {
  beforeEach(() => {
    global.Phoenix = { Socket }
    global.document.body.innerHTML = liveViewDOM().outerHTML
  })

  afterAll(() => {
    global.document.body.innerHTML = ''
  })

  test('sets defaults', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)
    expect(view.liveSocket).toBe(liveSocket)
    expect(view.gracefullyClosed).toEqual(false)
    expect(view.parent).toBeUndefined()
    expect(view.el).toBe(el)
    expect(view.id).toEqual('container')
    expect(view.view).toEqual('')
    expect(view.channel).toBeDefined()
    expect(view.loaderTimer).toBeDefined()
  })

  test('binding', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)
    expect(view.binding('submit')).toEqual('phx-submit')
  })

  test('getSession', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)
    expect(view.getSession()).toEqual('abc123')
  })

  test('showLoader and hideLoader', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    let el = document.querySelector('[data-phx-view]')

    let view = new View(el, liveSocket)
    view.showLoader()
    expect(el.classList.contains('phx-disconnected')).toBeTruthy()
    expect(el.classList.contains('phx-connected')).toBeFalsy()
    expect(el.classList.contains('user-implemented-class')).toBeTruthy()

    view.hideLoader()
    expect(el.classList.contains('phx-disconnected')).toBeFalsy()
    expect(el.classList.contains('phx-connected')).toBeTruthy()
  })

  test('displayError', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    let loader = document.createElement('span')
    let phxView = document.querySelector('[data-phx-view]')
    phxView.parentNode.insertBefore(loader, phxView.nextSibling)
    let el = document.querySelector('[data-phx-view]')

    let view = new View(el, liveSocket)
    view.displayError()
    expect(el.classList.contains('phx-disconnected')).toBeTruthy()
    expect(el.classList.contains('phx-error')).toBeTruthy()
    expect(el.classList.contains('phx-connected')).toBeFalsy()
    expect(el.classList.contains('user-implemented-class')).toBeTruthy()
  })

  test('join', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    let el = liveViewDOM()
    let view = new View(el, liveSocket)

    // view.join()
    // still need a few tests
  })
})

describe('View Hooks', function() {
  beforeEach(() => {
    global.document.body.innerHTML = liveViewDOM().outerHTML
  })

  afterAll(() => {
    global.document.body.innerHTML = ''
  })

  test('hooks', async () => {
    let upcaseWasDestroyed = false
    let Hooks = {
      Upcase: {
        mounted(){ this.el.innerHTML = this.el.innerHTML.toUpperCase() },
        updated(){ this.el.innerHTML = this.el.innerHTML + ' updated' },
        disconnected(){ this.el.innerHTML = 'disconnected' },
        reconnected(){ this.el.innerHTML = 'connected' },
        destroyed(){ upcaseWasDestroyed = true },
      }
    }
    let liveSocket = new LiveSocket('/live', Socket, {hooks: Hooks})
    let el = liveViewDOM()

    let view = new View(el, liveSocket)

    view.onJoin({rendered: {
      s: ['<h2 phx-hook="Upcase">test mount</h2>'],
      fingerprint: 123
    }})
    expect(view.el.firstChild.innerHTML).toBe('TEST MOUNT')

    view.update({
      s: ['<h2 phx-hook="Upcase">test update</h2>'],
      fingerprint: 123
    })
    expect(view.el.firstChild.innerHTML).toBe('test update updated')

    view.showLoader()
    expect(view.el.firstChild.innerHTML).toBe('disconnected')

    view.hideLoader()
    expect(view.el.firstChild.innerHTML).toBe('connected')

    view.update({s: ['<div></div>'], fingerprint: 123})
    expect(upcaseWasDestroyed).toBe(true)
  })
})

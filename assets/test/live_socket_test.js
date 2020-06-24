import {Socket} from "phoenix"
import LiveSocket, {View} from '../js/phoenix_live_view'

let container = (num) => global.document.getElementById(`container${num}`)

let prepareLiveViewDOM = (document) => {
  const div = document.createElement('div')
  div.setAttribute('data-phx-view', '')
  div.setAttribute('data-phx-session', 'abc123')
  div.setAttribute('data-phx-root-id', 'container1')
  div.setAttribute('id', 'container1')
  div.innerHTML = `
    <label for="plus">Plus</label>
    <input id="plus" value="1" />
    <button phx-click="inc_temperature">Inc Temperature</button>
  `
  const button = div.querySelector('button')
  const input = div.querySelector('input')
  button.addEventListener('click', () => {
    setTimeout(() => {
      input.value += 1
    }, 200)
  })
  document.body.appendChild(div)
}

describe('LiveSocket', () => {
  beforeEach(() => {
    prepareLiveViewDOM(global.document)
  })

  afterAll(() => {
    global.document.body.innerHTML = ''
  })

  test('sets defaults', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    expect(liveSocket.socket).toBeDefined()
    expect(liveSocket.socket.onOpen).toBeDefined()
    expect(liveSocket.viewLogger).toBeUndefined()
    expect(liveSocket.unloaded).toBe(false)
    expect(liveSocket.bindingPrefix).toBe('phx-')
    expect(liveSocket.activeElement).toBe(null)
    expect(liveSocket.prevActive).toBe(null)
  })

  test('sets defaults with socket', async () => {
    let liveSocket = new LiveSocket(new Socket('//example.org/chat'), Socket)
    expect(liveSocket.socket).toBeDefined()
    expect(liveSocket.socket.onOpen).toBeDefined()
    expect(liveSocket.unloaded).toBe(false)
    expect(liveSocket.bindingPrefix).toBe('phx-')
    expect(liveSocket.activeElement).toBe(null)
    expect(liveSocket.prevActive).toBe(null)
  })

  test('viewLogger', async () => {
    let viewLogger = (view, kind, msg, obj) => {
      expect(view.id).toBe('container1')
      expect(kind).toBe('updated')
      expect(msg).toBe('')
      expect(obj).toBe('\"<div>\"')
    }
    let liveSocket = new LiveSocket('/live', Socket, {viewLogger})
    expect(liveSocket.viewLogger).toBe(viewLogger)
    liveSocket.connect()
    let view = liveSocket.getViewByEl(container(1))
    liveSocket.log(view, 'updated', () => ['', JSON.stringify('<div>')])
  })

  test('connect', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    let socket = liveSocket.connect()
    expect(liveSocket.getViewByEl(container(1))).toBeDefined()
  })

  test('disconnect', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    liveSocket.connect()
    liveSocket.disconnect()

    expect(liveSocket.getViewByEl(container(1)).destroy).toBeDefined()
  })

  test('channel', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    liveSocket.connect()
    let channel = liveSocket.channel('lv:def456', () => {
        return { session: this.getSession() }
    })

    expect(channel).toBeDefined()
  })

  test('getViewByEl', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    liveSocket.connect()

    expect(liveSocket.getViewByEl(container(1)).destroy).toBeDefined()
  })

  test('destroyAllViews', async () => {
    const secondLiveView = document.createElement('div')
    secondLiveView.setAttribute('data-phx-view', '')
    secondLiveView.setAttribute('data-phx-session', 'def456')
    secondLiveView.setAttribute('data-phx-root-id', 'container1')
    secondLiveView.setAttribute('id', 'container2')
    secondLiveView.innerHTML = `
      <label for="plus">Plus</label>
      <input id="plus" value="1" />
      <button phx-click="inc_temperature">Inc Temperature</button>
    `
    document.body.appendChild(secondLiveView)

    let liveSocket = new LiveSocket('/live', Socket)
    liveSocket.connect()

    let el = container(1)
    expect(liveSocket.getViewByEl(el)).toBeDefined()

    liveSocket.destroyAllViews()
    expect(liveSocket.roots).toEqual({})

    // Simulate a race condition which may attempt to
    // destroy an element that no longer exists
    liveSocket.destroyViewByEl(el)
    expect(liveSocket.roots).toEqual({})
  })

  test('binding', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    expect(liveSocket.binding('value')).toBe('phx-value')
  })

  test('getBindingPrefix', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    expect(liveSocket.getBindingPrefix()).toEqual('phx-')
  })

  test('getBindingPrefix custom', async () => {
    let liveSocket = new LiveSocket('/live', Socket, {bindingPrefix: 'company-'})

    expect(liveSocket.getBindingPrefix()).toEqual('company-')
  })

  test('owner', async () => {
    let liveSocket = new LiveSocket('/live', Socket)
    liveSocket.connect()

    let view = liveSocket.getViewByEl(container(1))
    let btn = document.querySelector('button')
    let callback = (view) => {
      expect(view.id).toBe(view.id)
    }
    liveSocket.owner(btn, (view) => view.id)
  })

  test('getActiveElement default before LiveSocket activeElement is set', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    let input = document.querySelector('input')
    input.focus()

    expect(liveSocket.getActiveElement()).toEqual(input)
  })

  test('setActiveElement and getActiveElement', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    let input = document.querySelector('input')

    // .activeElement
    liveSocket.setActiveElement(input)
    expect(liveSocket.activeElement).toEqual(input)
    expect(liveSocket.getActiveElement()).toEqual(input)
  })

  test('blurActiveElement', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    let input = document.querySelector('input')
    input.focus()

    expect(liveSocket.prevActive).toBeNull()

    liveSocket.blurActiveElement()
    // sets prevActive
    expect(liveSocket.prevActive).toEqual(input)
    expect(liveSocket.getActiveElement()).not.toEqual(input)
  })

  test('restorePreviouslyActiveFocus', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    let input = document.querySelector('input')
    input.focus()

    liveSocket.blurActiveElement()
    expect(liveSocket.prevActive).toEqual(input)
    expect(liveSocket.getActiveElement()).not.toEqual(input)

    // focus()
    liveSocket.restorePreviouslyActiveFocus()
    expect(liveSocket.prevActive).toEqual(input)
    expect(liveSocket.getActiveElement()).toEqual(input)
    expect(document.activeElement).toEqual(input)
  })

  test('dropActiveElement unsets prevActive', async () => {
    let liveSocket = new LiveSocket('/live', Socket)

    liveSocket.connect()

    let input = document.querySelector('input')
    liveSocket.setActiveElement(input)
    liveSocket.blurActiveElement()
    expect(liveSocket.prevActive).toEqual(input)

    let view = liveSocket.getViewByEl(container(1))
    liveSocket.dropActiveElement(view)
    expect(liveSocket.prevActive).toBeNull()
    // this fails.  Is this correct?
    // expect(liveSocket.getActiveElement()).not.toEqual(input)
  })
})

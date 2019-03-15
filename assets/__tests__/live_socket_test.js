import '@babel/polyfill';
import LiveSocket, { View } from '../js/phoenix_live_view';
import waitForExpect from 'wait-for-expect';
import jsdom from 'jsdom';
const { JSDOM } = jsdom;

function wait(callback = () => {}, {timeout = 4500, interval = 50} = {}) {
  return waitForExpect(callback, timeout, interval)
}

function liveViewDOM() {
  const div = document.createElement('div')
  div.setAttribute('data-phx-view', '');
  div.setAttribute('data-phx-session', 'abc123');
  div.setAttribute('id', 'container');
  div.innerHTML = `
    <label for="plus">Plus</label>
    <input id="plus" value="1" />
    <button phx-click="inc_temperature">Inc Temperature</button>
  `
  const button = div.querySelector('button')
  const input = div.querySelector('input')
  button.addEventListener('click', () => {
    setTimeout(() => {
      input.value += 1;
    }, 200);
  });

  return div;
}

function dom() {
  return new JSDOM(`<!DOCTYPE html>${liveViewDOM().outerHTML}`);
}

test('sets defaults', async () => {
  let opts = { viewLogger: 'foo' };
  let liveSocket = new LiveSocket('/live', opts);
  expect(liveSocket.socket).toBeDefined();
  expect(liveSocket.socket.onOpen).toBeDefined();
  expect(liveSocket.opts.reconnectAfterMs).toBeDefined();
  expect(liveSocket.opts.viewLogger).toBe('foo');
  expect(liveSocket.viewLogger).toBe('foo');
  expect(liveSocket.unloaded).toBe(false);
  expect(liveSocket.bindingPrefix).toBe('phx-');
  expect(liveSocket.activeElement).toBe(null);
  expect(liveSocket.prevActive).toBe(null);
});

test('can log with viewLogger', async () => {
  let viewLogger = (view, kind, msg, obj) => {
    expect(view.id).toBe('container');
    expect(kind).toBe('updated');
    expect(msg).toBe('');
    expect(obj).toBe('\"<div>\"');
  }
  let liveSocket = new LiveSocket('/live', { viewLogger });
  let view = new View(liveViewDOM(), liveSocket);
  liveSocket.log(view, 'updated', () => ['', JSON.stringify('<div>')]);
});

test('can connect', async () => {
  let liveSocket = new LiveSocket('/live');
  liveSocket.document = dom().window.document;

  liveSocket.connect();

  expect(liveSocket.views['container']).toBeDefined();
});


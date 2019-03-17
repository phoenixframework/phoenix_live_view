import LiveSocket, { View } from '../js/phoenix_live_view';
import { JSDOM } from 'jsdom'

function liveViewDOM() {
  const div = document.createElement('div')
  div.setAttribute('data-phx-view', '')
  div.setAttribute('data-phx-session', 'abc123')
  div.setAttribute('id', 'container')
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

  return div
}

function dom() {
  return new JSDOM(`<!DOCTYPE html><body>${liveViewDOM().outerHTML}</body>`)
}

test('sets defaults', async () => {
  let liveSocket = new LiveSocket('/live');
  let el = liveViewDOM();
  let view = new View(el, liveSocket);
  expect(view.liveSocket).toBe(liveSocket);
  expect(view.newChildrenAdded).toEqual(false);
  expect(view.gracefullyClosed).toEqual(false);
  expect(view.hasBoundUI).toEqual(false);
  expect(view.prevKey).toEqual(null);
  expect(view.parent).toBeUndefined();
  expect(view.el).toBe(el);
  expect(view.id).toEqual('container');
  expect(view.view).toEqual('');
  expect(view.bindingPrefix).toEqual('phx-');
});

test('binding', async () => {
  let liveSocket = new LiveSocket('/live');
  let el = liveViewDOM();
  let view = new View(el, liveSocket);
  expect(view.binding('submit')).toEqual('phx-submit');
});

test('target', async () => {
  let liveSocket = new LiveSocket('/live');
  let el = liveViewDOM();
  let view = new View(el, liveSocket);
  expect(view.target(el)).toEqual(el);
});

test('getSession', async () => {
  let liveSocket = new LiveSocket('/live');
  let el = liveViewDOM();
  let view = new View(el, liveSocket);
  expect(view.getSession()).toEqual('abc123');
});

test('showLoader and hideLoader', async () => {
  let liveSocket = new LiveSocket('/live');
  liveSocket.document = dom().window.document;
  let loader = liveSocket.document.createElement('span');
  loader.style.display = 'none';
  let phxView = liveSocket.document.querySelector('[data-phx-view]');
  phxView.parentNode.insertBefore(loader, phxView.nextSibling);
  let el = liveSocket.document.querySelector('[data-phx-view]');

  let view = new View(el, liveSocket);
  view.showLoader();
  expect(el.classList.contains('phx-disconnected')).toBeTruthy();
  expect(loader.style.display).toEqual('block');

  view.hideLoader();
  expect(loader.style.display).toEqual('none');
});

test('displayError', async () => {
  let liveSocket = new LiveSocket('/live');
  liveSocket.document = dom().window.document;
  let loader = liveSocket.document.createElement('span');
  let phxView = liveSocket.document.querySelector('[data-phx-view]');
  phxView.parentNode.insertBefore(loader, phxView.nextSibling);
  let el = liveSocket.document.querySelector('[data-phx-view]');

  let view = new View(el, liveSocket);
  view.displayError();
  expect(el.classList.contains('phx-disconnected')).toBeTruthy();
  expect(el.classList.contains('phx-error')).toBeTruthy();
  expect(loader.style.display).toEqual('block');
});

test('update', async () => {
  let liveSocket = new LiveSocket('/live');
  liveSocket.document = dom().window.document;
  let el = liveViewDOM();
  let updatedEl = {
    static: ['<h2>'],
    fingerprint: 123
  };

  let view = new View(el, liveSocket);

  view.update(updatedEl);

  expect(view.el.firstChild.tagName).toBe('H2');
  expect(view.newChildrenAdded).toBe(false);
  expect(view.rendered).toBe(updatedEl);
});

test('join', async () => {
  let liveSocket = new LiveSocket('/live');
  liveSocket.document = dom().window.document;
  let el = liveViewDOM();
  let view = new View(el, liveSocket);

  view.join();
  // still need a few tests
});

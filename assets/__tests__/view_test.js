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

test('getSession', async () => {
  let liveSocket = new LiveSocket('/live');
  let el = liveViewDOM();
  let view = new View(el, liveSocket);
  expect(view.getSession()).toEqual('abc123');
});

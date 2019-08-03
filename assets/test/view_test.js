import LiveSocket, { View } from '../js/phoenix_live_view';

function liveViewDOM() {
  const div = document.createElement('div')
  div.setAttribute('data-phx-view', '');
  div.setAttribute('data-phx-session', 'abc123');
  div.setAttribute('id', 'container');
  div.setAttribute('class', 'user-implemented-class');
  div.innerHTML = `
    <label for="plus">Plus</label>
    <input id="plus" value="1" />
    <button phx-click="inc_temperature">Inc Temperature</button>
  `;
  const button = div.querySelector('button')
  const input = div.querySelector('input')
  button.addEventListener('click', () => {
    setTimeout(() => {
      input.value += 1;
    }, 200);
  });

  return div;
}

describe('View + DOM', function() {
  test('update', async () => {
    let liveSocket = new LiveSocket('/live');
    let el = liveViewDOM();
    let updatedEl = {
      static: ['<h2>', '</h2>'],
      fingerprint: 123
    };

    let view = new View(el, liveSocket);

    view.update(updatedEl);

    expect(view.el.firstChild.tagName).toBe('H2');
    expect(view.newChildrenAdded).toBe(false);
    expect(view.rendered).toBe(updatedEl);
  });
});

describe('View', function() {
  beforeEach(() => {
    global.document.body.innerHTML = liveViewDOM().outerHTML;
  });

  afterAll(() => {
    global.document.body.innerHTML = '';
  });

  test('sets defaults', async () => {
    let liveSocket = new LiveSocket('/live');
    let el = liveViewDOM();
    let view = new View(el, liveSocket);
    expect(view.liveSocket).toBe(liveSocket);
    expect(view.newChildrenAdded).toEqual(false);
    expect(view.gracefullyClosed).toEqual(false);
    expect(view.parent).toBeUndefined();
    expect(view.el).toBe(el);
    expect(view.id).toEqual('container');
    expect(view.view).toEqual('');
  });

  test('binding', async () => {
    let liveSocket = new LiveSocket('/live');
    let el = liveViewDOM();
    let view = new View(el, liveSocket);
    expect(view.binding('submit')).toEqual('phx-submit');
  });

  test('getSession', async () => {
    let liveSocket = new LiveSocket('/live');
    let el = liveViewDOM();
    let view = new View(el, liveSocket);
    expect(view.getSession()).toEqual('abc123');
  });

  test('showLoader and hideLoader', async () => {
    let liveSocket = new LiveSocket('/live');
    let el = document.querySelector('[data-phx-view]');

    let view = new View(el, liveSocket);
    view.showLoader();
    expect(el.classList.contains('phx-disconnected')).toBeTruthy();
    expect(el.classList.contains('phx-connected')).toBeFalsy();
    expect(el.classList.contains('user-implemented-class')).toBeTruthy();

    view.hideLoader();
    expect(el.classList.contains('phx-disconnected')).toBeFalsy();
    expect(el.classList.contains('phx-connected')).toBeTruthy();
  });

  test('displayError', async () => {
    let liveSocket = new LiveSocket('/live');
    let loader = document.createElement('span');
    let phxView = document.querySelector('[data-phx-view]');
    phxView.parentNode.insertBefore(loader, phxView.nextSibling);
    let el = document.querySelector('[data-phx-view]');

    let view = new View(el, liveSocket);
    view.displayError();
    expect(el.classList.contains('phx-disconnected')).toBeTruthy();
    expect(el.classList.contains('phx-error')).toBeTruthy();
    expect(el.classList.contains('phx-connected')).toBeFalsy();
    expect(el.classList.contains('user-implemented-class')).toBeTruthy();
  });

  test('join', async () => {
    let liveSocket = new LiveSocket('/live');
    let el = liveViewDOM();
    let view = new View(el, liveSocket);

    // view.join();
    // still need a few tests
  });
});

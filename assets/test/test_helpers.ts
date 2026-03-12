import View from "phoenix_live_view/view";
import { version as liveview_version } from "../../package.json";

export const appendTitle = (opts, innerHTML?: string) => {
  Array.from(document.head.querySelectorAll("title")).forEach((el) =>
    el.remove(),
  );
  const title = document.createElement("title");
  const { prefix, suffix, default: defaultTitle } = opts;
  if (prefix) {
    title.setAttribute("data-prefix", prefix);
  }
  if (suffix) {
    title.setAttribute("data-suffix", suffix);
  }
  if (defaultTitle) {
    title.setAttribute("data-default", defaultTitle);
  } else {
    title.removeAttribute("data-default");
  }
  if (innerHTML) {
    title.innerHTML = innerHTML;
  }
  document.head.appendChild(title);
};

export const rootContainer = (content) => {
  const div = tag("div", { id: "root" }, content);
  document.body.appendChild(div);
  return div;
};

export const tag = (tagName, attrs, innerHTML) => {
  const el = document.createElement(tagName);
  el.innerHTML = innerHTML;
  for (const key in attrs) {
    el.setAttribute(key, attrs[key]);
  }
  return el;
};

export const simulateJoinedView = (el, liveSocket) => {
  const view = new View(el, liveSocket);
  stubChannel(view);
  liveSocket.roots[view.id] = view;
  view.isConnected = () => true;
  view.onJoin({ rendered: { s: [el.innerHTML] }, liveview_version });
  return view;
};

export const simulateVisibility = (el) => {
  el.getClientRects = () => {
    const style = window.getComputedStyle(el);
    const visible = !(style.opacity === "0" || style.display === "none");
    return visible ? { length: 1 } : { length: 0 };
  };
  return el;
};

export const stubChannel = (view: View) => {
  const fakePush = {
    // eslint-disable-next-line @typescript-eslint/no-unsafe-function-type
    receives: [] as [string, Function][],
    // eslint-disable-next-line @typescript-eslint/no-unsafe-function-type
    receive(kind: string, cb: Function) {
      this.receives.push([kind, cb]);
      return this;
    },
  };
  view.channel.push = () => fakePush;
  view.channel.leave = () => ({
    receive(kind, cb) {
      if (kind === "ok") {
        cb();
      }
      return this;
    },
  });
};

export function liveViewDOM(content?: string) {
  const div = document.createElement("div");
  div.setAttribute("data-phx-view", "User.Form");
  div.setAttribute("data-phx-session", "abc123");
  div.setAttribute("data-phx-main", "");
  div.setAttribute("id", "container");
  div.setAttribute("class", "user-implemented-class");
  div.innerHTML =
    content ||
    `
    <form id="my-form">
      <label for="plus">Plus</label>
      <input id="plus" value="1" name="increment" />
      <textarea id="note" name="note">2</textarea>
      <input type="checkbox" phx-click="toggle_me" />
      <button phx-click="inc_temperature">Inc Temperature</button>
      <div
        id="status"
        phx-disconnected='[["show",{"display":null,"time":200,"to":null,"transition":[[],[],[]]}]]'
        phx-connected='[["hide",{"time":200,"to":null,"transition":[[],[],[]]}]]'
        style="display:  none;"
      >
        disconnected!
      </div>
    </form>
  `;
  document.body.innerHTML = "";
  document.body.appendChild(div);
  return div;
}

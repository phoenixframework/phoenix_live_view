import { PHX_REF_LOCK } from "phoenix_live_view/constants";
import ElementRef from "phoenix_live_view/element_ref";

const unlock = (el: Element) => {
  const ref = el.getAttribute(PHX_REF_LOCK);
  el.removeAttribute(PHX_REF_LOCK);
  el.dispatchEvent(new CustomEvent(`phx:undo-lock:${ref}`, { bubbles: true }));
};

describe("ElementRef", () => {
  test("onUnlock waits for the entire locked ancestor chain", () => {
    document.body.innerHTML = `
      <div id="outer" ${PHX_REF_LOCK}="1">
        <div id="inner" ${PHX_REF_LOCK}="2">
          <input id="input" />
        </div>
      </div>
    `;
    const outer = document.querySelector("#outer")!;
    const inner = document.querySelector("#inner")!;
    const input = document.querySelector("#input")!;
    const callback = jest.fn();

    ElementRef.onUnlock(input, callback);
    unlock(inner);

    expect(callback).not.toHaveBeenCalled();

    unlock(outer);

    expect(callback).toHaveBeenCalledTimes(1);
  });

  test("onUnlock ignores a descendant's bubbling unlock event", () => {
    document.body.innerHTML = `
      <div id="outer" ${PHX_REF_LOCK}="1">
        <div id="inner" ${PHX_REF_LOCK}="1">
          <input id="input" />
        </div>
      </div>
    `;
    const outer = document.querySelector("#outer")!;
    const inner = document.querySelector("#inner")!;
    const input = document.querySelector("#input")!;
    const callback = jest.fn();

    ElementRef.onUnlock(input, callback);
    unlock(inner);

    expect(callback).not.toHaveBeenCalled();

    unlock(outer);

    expect(callback).toHaveBeenCalledTimes(1);
  });
});

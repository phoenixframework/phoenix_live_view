const { expect } = require("@playwright/test");
const Crypto = require("crypto");

const randomString = (size = 21) => Crypto.randomBytes(size).toString("base64").slice(0, size);

// a helper function to wait until the LV has no pending events
const syncLV = async (page) => {
  const promises = [
    expect(page.locator(".phx-connected").first()).toBeVisible(),
    expect(page.locator(".phx-change-loading")).toHaveCount(0),
    expect(page.locator(".phx-click-loading")).toHaveCount(0),
    expect(page.locator(".phx-submit-loading")).toHaveCount(0),
  ];
  return Promise.all(promises);
};

// this function executes the given code inside the liveview that is responsible
// for the given selector; it uses private phoenix live view js functions, so it could
// break in the future
// we handle the evaluation in a LV hook
const evalLV = async (page, code, selector="[data-phx-main]") => await page.evaluate(([code, selector]) => {
  window.liveSocket.main.withinTargets(selector, (targetView, targetCtx) => {
    targetView.pushEvent("event", document.body, targetCtx, "sandbox:eval", { value: code })
  });
}, [code, selector]);

const attributeMutations = (page, selector) => {
  // this is a bit of a hack, basically we create a MutationObserver on the page
  // that will record any changes to a selector until the promise is awaited
  //
  // we use a random id to store the resolve function in the window object
  const id = randomString(24);
  // this promise resolves to the mutation list
  const promise = page.locator(selector).evaluate((target, id) => {
    return new Promise((resolve) => {
      const mutations = [];
      let observer;
      window[id] = () => {
        if (observer) observer.disconnect();
        resolve(mutations);
        delete window[id];
      };
      // https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver
      observer = new MutationObserver((mutationsList, _observer) => {
        mutationsList.forEach(mutation => {
          if (mutation.type === "attributes") {
            mutations.push({
              attr: mutation.attributeName,
              oldValue: mutation.oldValue,
              newValue: mutation.target.getAttribute(mutation.attributeName)
            });
          }
        });
      }).observe(target, { attributes: true, attributeOldValue: true });
    });
  }, id);

  return () => {
    // we want to stop observing!
    page.locator(selector).evaluate((_target, id) => window[id](), id);
    // return the result of the initial promise
    return promise;
  };
}

module.exports = { randomString, syncLV, evalLV, attributeMutations };

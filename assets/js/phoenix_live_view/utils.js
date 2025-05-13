import { PHX_VIEW_SELECTOR } from "./constants";

import EntryUploader from "./entry_uploader";

export const logError = (msg, obj) => console.error && console.error(msg, obj);

export const isCid = (cid) => {
  const type = typeof cid;
  return type === "number" || (type === "string" && /^(0|[1-9]\d*)$/.test(cid));
};

export function detectDuplicateIds() {
  const ids = new Set();
  const elems = document.querySelectorAll("*[id]");
  for (let i = 0, len = elems.length; i < len; i++) {
    if (ids.has(elems[i].id)) {
      console.error(
        `Multiple IDs detected: ${elems[i].id}. Ensure unique element ids.`,
      );
    } else {
      ids.add(elems[i].id);
    }
  }
}

export function detectInvalidStreamInserts(inserts) {
  const errors = new Set();
  Object.keys(inserts).forEach((id) => {
    const streamEl = document.getElementById(id);
    if (
      streamEl &&
      streamEl.parentElement &&
      streamEl.parentElement.getAttribute("phx-update") !== "stream"
    ) {
      errors.add(
        `The stream container with id "${streamEl.parentElement.id}" is missing the phx-update="stream" attribute. Ensure it is set for streams to work properly.`,
      );
    }
  });
  errors.forEach((error) => console.error(error));
}

export const debug = (view, kind, msg, obj) => {
  if (view.liveSocket.isDebugEnabled()) {
    console.log(`${view.id} ${kind}: ${msg} - `, obj);
  }
};

// wraps value in closure or returns closure
export const closure = (val) =>
  typeof val === "function"
    ? val
    : function () {
        return val;
      };

export const clone = (obj) => {
  return JSON.parse(JSON.stringify(obj));
};

export const closestPhxBinding = (el, binding, borderEl) => {
  do {
    if (el.matches(`[${binding}]`) && !el.disabled) {
      return el;
    }
    el = el.parentElement || el.parentNode;
  } while (
    el !== null &&
    el.nodeType === 1 &&
    !((borderEl && borderEl.isSameNode(el)) || el.matches(PHX_VIEW_SELECTOR))
  );
  return null;
};

export const isObject = (obj) => {
  return obj !== null && typeof obj === "object" && !(obj instanceof Array);
};

export const isEqualObj = (obj1, obj2) =>
  JSON.stringify(obj1) === JSON.stringify(obj2);

export const isEmpty = (obj) => {
  for (const x in obj) {
    return false;
  }
  return true;
};

export const maybe = (el, callback) => el && callback(el);

export const channelUploader = function (entries, onError, resp, liveSocket) {
  entries.forEach((entry) => {
    const entryUploader = new EntryUploader(entry, resp.config, liveSocket);
    entryUploader.upload();
  });
};

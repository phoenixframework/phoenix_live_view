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

export const eventContainsFiles = (e) => {
  if (e.dataTransfer.types) {
    for (let i = 0; i < e.dataTransfer.types.length; i++) {
      if (e.dataTransfer.types[i] === "Files") {
        return true;
      }
    }
  }
  return false;
};

/** Warning: Mutates the `params` argument in-place
  * Private function intended only to limit duplicatation.
  * Do not export.
  * @param {URLSearchParams} params
  * @param {import("./js_commands").QueryKV[]} instructions
  */
const addQueryOp = (params, instructions) => {
  for (const [k, v] of instructions) {
    if (Array.isArray(v)) {
      for (const val of v) {
        params.append(k, val);
      }
    } else {
      params.append(k, v)
    }
  }
};

/**
  * Normalize an href string to a full URL.
  * @param {string} href
  */
export const normalizeHref = (href) => {
  if (href.startsWith("/")) {
    return `${location.protocol}//${location.host}${href}`;
  } else if (href.startsWith("?")) {
    return `${location.protocol}//${location.host}${location.pathname}${href}`;
  }
};

/**
  * Parse the `query` patches from an encoded JS command.
  * @param {string} href
  * @param {import("./js_commands").QueryOperation[]} queryOps
  */
export const parseQueryOps = (href, queryOps) => {
  // Note:
  // If-else is used intentionally in this function instead of switch-case
  // because switch-case in javascript is very error-prone due to its
  // fallthrough and scoping rules.

  const baseParams = href.includes("?") ? href.split("?")[1] : location.search;
  const baseUrl = normalizeHref(href);

  // Warning: This variable is mutated in-place in the following for loops.
  const params = new URLSearchParams(baseParams);

  for (const [op, instructions] of queryOps) {
    if (op === "set") {
      params.forEach((_v, k) => params.delete(k));
      addQueryOp(params, instructions);
    } else if (op === "merge") {
      for (const [k, v] of instructions) {
        if (Array.isArray(v)) {
          const [first, ...rest] = v;
          params.set(k, first);
          for (const val of rest) {
            params.append(k, val);
          }
        } else {
          params.set(k, v)
        }
      }
    } else if (op === "toggle") {
      for (const [k, v] of instructions) {
        if (Array.isArray(v)) {
          for (const val of v) {
            if (params.has(k, val)) {
              params.delete(k, val);
            } else {
              params.append(k, val);
            }
          }
        } else {
          if (params.has(k, v)) {
            params.delete(k, v);
          } else {
            params.append(k, v);
          }
        }
      }
    } else if (op === "add") {
      addQueryOp(params, instructions);
    } else if (op === "remove") {
      for (const args of instructions) {
        if (Array.isArray(args)) {
          const [k, v] = args;
          if (Array.isArray(v)) {
            for (const val of v) {
              params.delete(k, val);
            }
          } else {
            params.delete(k, v)
          }
        } else {
          params.delete(args)
        }
      }
    }
  }

  const paramStr = params.toString();
  const hrefStr = baseUrl.split("?")[0];
  if (paramStr === "") {
    return hrefStr;
  } else {
    return [hrefStr, paramStr].join("?");
  }
};

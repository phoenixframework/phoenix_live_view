import { PHX_VIEW_SELECTOR } from "./constants";

import EntryUploader from "./entry_uploader";
import { logError, type LogError } from "./diagnostics";

// Live navigation can only stay within the current origin, as it joins the
// target over the existing socket. A full URL to a different origin (or a
// non-http(s) scheme, which resolves to an opaque "null" origin) is a
// programming error, so we fail loudly instead of attempting a broken join.
export const ensureSameOrigin = (
  href: string,
  kind: "patch" | "navigate",
): void => {
  let url: URL;
  try {
    url = new URL(href, window.location.href);
  } catch {
    throw new Error(
      `expected ${kind} destination to be a valid URL, got: ${href}`,
    );
  }
  if (url.origin !== window.location.origin) {
    throw new Error(
      `cannot ${kind} to "${href}" because its origin does not match the ` +
        `current origin "${window.location.origin}". Use window.location directly for cross-origin navigation.`,
    );
  }
};

export const isCid = (cid): cid is number | string => {
  const type = typeof cid;
  return type === "number" || (type === "string" && /^(0|[1-9]\d*)$/.test(cid));
};

export function detectDuplicateIds(reportError: LogError = logError) {
  const ids = new Map<string, Element>();
  const elems = document.querySelectorAll("*[id]");
  for (let i = 0, len = elems.length; i < len; i++) {
    const id = elems[i].id;
    const existing = ids.get(id);
    if (existing) {
      reportError(
        "dom.duplicate-id",
        `Multiple IDs detected: ${id}. Ensure unique element ids.`,
        { id, elements: [existing, elems[i]] },
      );
    } else {
      ids.set(id, elems[i]);
    }
  }
}

export function detectInvalidStreamInserts(
  inserts,
  reportError: LogError = logError,
) {
  const invalidContainers = new Set<Element>();
  Object.keys(inserts).forEach((id) => {
    const streamEl = document.getElementById(id);
    if (
      streamEl &&
      streamEl.parentElement &&
      streamEl.parentElement.getAttribute("phx-update") !== "stream"
    ) {
      invalidContainers.add(streamEl.parentElement);
    }
  });
  invalidContainers.forEach((container) => {
    const id = container.id;
    reportError(
      "dom.invalid-stream-container",
      `The stream container with id "${id}" is missing the phx-update="stream" attribute. Ensure it is set for streams to work properly.`,
      { id, container },
    );
  });
}

export const debug = (view, kind, msg, obj) => {
  if (view.liveSocket.isDebugEnabled()) {
    console.log(`${view.id} ${kind}: ${msg} - `, obj);
  }
};

// wraps value in closure or returns closure
export const closure = (val?) =>
  typeof val === "function"
    ? val
    : function () {
        return val;
      };

export const clone = (obj) => {
  return JSON.parse(JSON.stringify(obj));
};

export const closestPhxBinding = (
  startEl: Element,
  binding: string,
  borderEl?: Element,
) => {
  let el: Element | null = startEl;
  do {
    if (el.matches(`[${binding}]`) && !("disabled" in el && el.disabled)) {
      return el;
    }
    el = el.parentElement;
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

// Rewrites the start tag of a rendered root element. Used for the magic ID optimization.

/** Attributes to add to a root element; `true` renders as a bare attribute. */
export type RootAttrs = Record<string, string | number | boolean>;

const VOID_TAGS = new Set([
  "area",
  "base",
  "br",
  "col",
  "command",
  "embed",
  "hr",
  "img",
  "input",
  "keygen",
  "link",
  "meta",
  "param",
  "source",
  "track",
  "wbr",
]);
const quoteChars = new Set(["'", '"']);

export const modifyRoot = (
  html: string,
  attrs: RootAttrs,
  clearInnerHTML?: boolean,
): [string, string, string] => {
  let i: number;
  let insideComment: boolean;
  let beforeTag: string,
    afterTag: string,
    tag: string,
    tagNameEndsAt: number,
    id: string | undefined,
    newHTML: string;

  const lookahead = html.match(/^(\s*(?:<!--.*?-->\s*)*)<([^\s\/>]+)/);
  if (lookahead === null) {
    throw new Error(`malformed html ${html}`);
  }

  i = lookahead[0].length;
  beforeTag = lookahead[1];
  tag = lookahead[2];
  tagNameEndsAt = i;

  // Scan the opening tag for id, if there is any
  for (i; i < html.length; i++) {
    if (html.charAt(i) === ">") {
      break;
    }
    if (html.charAt(i) === "=") {
      const isId = html.slice(i - 3, i) === " id";
      i++;
      const char = html.charAt(i);
      if (quoteChars.has(char)) {
        const attrStartsAt = i;
        i++;
        for (i; i < html.length; i++) {
          if (html.charAt(i) === char) {
            break;
          }
        }
        if (isId) {
          id = html.slice(attrStartsAt + 1, i);
          break;
        }
      }
    }
  }

  let closeAt = html.length - 1;
  insideComment = false;
  while (closeAt >= beforeTag.length + tag.length) {
    const char = html.charAt(closeAt);
    if (insideComment) {
      if (char === "-" && html.slice(closeAt - 3, closeAt) === "<!-") {
        insideComment = false;
        closeAt -= 4;
      } else {
        closeAt -= 1;
      }
    } else if (char === ">" && html.slice(closeAt - 2, closeAt) === "--") {
      insideComment = true;
      closeAt -= 3;
    } else if (char === ">") {
      break;
    } else {
      closeAt -= 1;
    }
  }
  afterTag = html.slice(closeAt + 1, html.length);

  const attrsStr = Object.keys(attrs)
    .map((attr) => (attrs[attr] === true ? attr : `${attr}="${attrs[attr]}"`))
    .join(" ");

  if (clearInnerHTML) {
    // Keep the id if any
    const idAttrStr = id ? ` id="${id}"` : "";
    if (VOID_TAGS.has(tag)) {
      newHTML = `<${tag}${idAttrStr}${attrsStr === "" ? "" : " "}${attrsStr}/>`;
    } else {
      newHTML = `<${tag}${idAttrStr}${attrsStr === "" ? "" : " "}${attrsStr}></${tag}>`;
    }
  } else {
    const rest = html.slice(tagNameEndsAt, closeAt + 1);
    newHTML = `<${tag}${attrsStr === "" ? "" : " "}${attrsStr}${rest}`;
  }

  return [newHTML, beforeTag, afterTag];
};

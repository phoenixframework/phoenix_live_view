/** Attributes to add to a root element; `true` renders as a bare attribute. */
export type RootAttrs = Record<string, string | number | boolean>;
export declare const modifyRoot: (html: string, attrs: RootAttrs, clearInnerHTML?: boolean) => [string, string, string];

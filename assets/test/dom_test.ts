import DOM from "phoenix_live_view/dom";
import { appendTitle, tag } from "./test_helpers";

const e = (href: string) => {
  const anchor = document.createElement("a");
  anchor.setAttribute("href", href);
  const event = {
    target: anchor,
    defaultPrevented: false,
  } as unknown as Event & { target: HTMLAnchorElement };
  return event;
};

describe("DOM", () => {
  beforeEach(() => {
    const curTitle = document.querySelector("title");
    curTitle && curTitle.remove();
  });

  describe("wantsNewTab", () => {
    test("case insensitive target", () => {
      const event = e("https://test.local");
      expect(DOM.wantsNewTab(event)).toBe(false);
      // lowercase
      event.target.setAttribute("target", "_blank");
      expect(DOM.wantsNewTab(event)).toBe(true);
      // uppercase
      event.target.setAttribute("target", "_BLANK");
      expect(DOM.wantsNewTab(event)).toBe(true);
    });
  });

  describe("isNewPageClick", () => {
    test("identical locations", () => {
      let currentLoc;
      currentLoc = new URL("https://test.local/foo");
      expect(DOM.isNewPageClick(e("/foo"), currentLoc)).toBe(true);
      expect(DOM.isNewPageClick(e("https://test.local/foo"), currentLoc)).toBe(
        true,
      );
      expect(DOM.isNewPageClick(e("//test.local/foo"), currentLoc)).toBe(true);
      // with hash
      expect(DOM.isNewPageClick(e("/foo#hash"), currentLoc)).toBe(false);
      expect(
        DOM.isNewPageClick(e("https://test.local/foo#hash"), currentLoc),
      ).toBe(false);
      expect(DOM.isNewPageClick(e("//test.local/foo#hash"), currentLoc)).toBe(
        false,
      );
      // different paths
      expect(DOM.isNewPageClick(e("/foo2#hash"), currentLoc)).toBe(true);
      expect(
        DOM.isNewPageClick(e("https://test.local/foo2#hash"), currentLoc),
      ).toBe(true);
      expect(DOM.isNewPageClick(e("//test.local/foo2#hash"), currentLoc)).toBe(
        true,
      );
    });

    test("identical locations with query", () => {
      let currentLoc;
      currentLoc = new URL("https://test.local/foo?query=1");
      expect(DOM.isNewPageClick(e("/foo"), currentLoc)).toBe(true);
      expect(
        DOM.isNewPageClick(e("https://test.local/foo?query=1"), currentLoc),
      ).toBe(true);
      expect(
        DOM.isNewPageClick(e("//test.local/foo?query=1"), currentLoc),
      ).toBe(true);
      // with hash
      expect(DOM.isNewPageClick(e("/foo?query=1#hash"), currentLoc)).toBe(
        false,
      );
      expect(
        DOM.isNewPageClick(
          e("https://test.local/foo?query=1#hash"),
          currentLoc,
        ),
      ).toBe(false);
      expect(
        DOM.isNewPageClick(e("//test.local/foo?query=1#hash"), currentLoc),
      ).toBe(false);
      // different query
      expect(DOM.isNewPageClick(e("/foo?query=2#hash"), currentLoc)).toBe(true);
      expect(
        DOM.isNewPageClick(
          e("https://test.local/foo?query=2#hash"),
          currentLoc,
        ),
      ).toBe(true);
      expect(
        DOM.isNewPageClick(e("//test.local/foo?query=2#hash"), currentLoc),
      ).toBe(true);
    });

    test("empty hash href", () => {
      const currentLoc = new URL("https://test.local/foo");
      expect(DOM.isNewPageClick(e("#"), currentLoc)).toBe(false);
    });

    test("local hash", () => {
      const currentLoc = new URL("https://test.local/foo");
      expect(DOM.isNewPageClick(e("#foo"), currentLoc)).toBe(false);
    });

    test("with defaultPrevented return sfalse", () => {
      let currentLoc;
      currentLoc = new URL("https://test.local/foo");
      const event = e("/foo");
      (event as any).defaultPrevented = true;
      expect(DOM.isNewPageClick(event, currentLoc)).toBe(false);
    });

    test("ignores mailto and tel links", () => {
      expect(
        DOM.isNewPageClick(e("mailto:foo"), new URL("https://test.local/foo")),
      ).toBe(false);
      expect(
        DOM.isNewPageClick(e("tel:1234"), new URL("https://test.local/foo")),
      ).toBe(false);
    });

    test("ignores contenteditable", () => {
      let currentLoc;
      currentLoc = new URL("https://test.local/foo");
      const event = e("/bar");
      (event.target as any).isContentEditable = true;
      expect(DOM.isNewPageClick(event, currentLoc)).toBe(false);
    });
  });

  describe("putTitle", () => {
    test("with no attributes", () => {
      appendTitle({});
      DOM.putTitle("My Title");
      expect(document.title).toBe("My Title");
    });

    test("with prefix", () => {
      appendTitle({ prefix: "PRE " });
      DOM.putTitle("My Title");
      expect(document.title).toBe("PRE My Title");
    });

    test("with suffix", () => {
      appendTitle({ suffix: " POST" });
      DOM.putTitle("My Title");
      expect(document.title).toBe("My Title POST");
    });

    test("with prefix and suffix", () => {
      appendTitle({ prefix: "PRE ", suffix: " POST" });
      DOM.putTitle("My Title");
      expect(document.title).toBe("PRE My Title POST");
    });

    test("with default", () => {
      appendTitle({ default: "DEFAULT", prefix: "PRE ", suffix: " POST" });
      DOM.putTitle(null);
      expect(document.title).toBe("PRE DEFAULT POST");

      DOM.putTitle(undefined);
      expect(document.title).toBe("PRE DEFAULT POST");

      DOM.putTitle("");
      expect(document.title).toBe("PRE DEFAULT POST");
    });
  });

  describe("findExistingParentCIDs", () => {
    test("returns only parent cids", () => {
      const view = tag(
        "div",
        {},
        `
        <div id="foo" data-phx-main="true"
            data-phx-session="123"
            data-phx-static="456"
            class="phx-connected"
            data-phx-root-id="phx-FgFpFf-J8Gg-jEnh">
        </div>
      `,
      );
      document.body.appendChild(view);

      view.appendChild(
        tag(
          "div",
          { "data-phx-component": 1, "data-phx-view": "foo" },
          `
        <div data-phx-component="2" data-phx-view="foo"></div>
      `,
        ),
      );
      expect(DOM.findExistingParentCIDs("foo", [1, 2])).toEqual(new Set([1]));

      view.appendChild(
        tag(
          "div",
          { "data-phx-component": 1, "data-phx-view": "foo" },
          `
        <div data-phx-component="2" data-phx-view="foo">
          <div data-phx-component="3" data-phx-view="foo"></div>
        </div>
      `,
        ),
      );
      expect(DOM.findExistingParentCIDs("foo", [1, 2, 3])).toEqual(
        new Set([1]),
      );
    });

    test("ignores elements in child LiveViews #3626", () => {
      const view = tag(
        "div",
        {},
        `
        <div data-phx-main="true"
            data-phx-session="123"
            data-phx-static="456"
            id="phx-123"
            class="phx-connected"
            data-phx-root-id="phx-FgFpFf-J8Gg-jEnh">
        </div>
      `,
      );
      document.body.appendChild(view);

      view.appendChild(
        tag(
          "div",
          { "data-phx-component": 1, "data-phx-view": "phx-123" },
          `
        <div data-phx-session="123" data-phx-static="456" data-phx-parent="phx-123" id="phx-child-view">
          <div data-phx-component="1" data-phx-view="phx-child-view"></div>
        </div>
      `,
        ),
      );
      expect(DOM.findExistingParentCIDs("phx-123", [1])).toEqual(new Set([1]));
    });
  });

  describe("findComponentNodeList", () => {
    test("returns nodes with cid ID (except indirect children)", () => {
      const view = tag("div", { id: "foo" }, "");
      let component1 = tag(
        "div",
        { "data-phx-component": 0, "data-phx-view": "foo" },
        "Hello",
      );
      let component2 = tag(
        "div",
        { "data-phx-component": 0, "data-phx-view": "foo" },
        "World",
      );
      let component3 = tag(
        "div",
        { "data-phx-session": "123" },
        `
        <div data-phx-component="0" data-phx-view="123"></div>
      `,
      );
      document.body.appendChild(view);
      view.appendChild(component1);
      view.appendChild(component2);
      view.appendChild(component3);

      expect(DOM.findComponentNodeList("foo", 0, document)).toEqual([
        component1,
        component2,
      ]);
    });

    test("returns empty list with no matching cid", () => {
      const view = tag("div", { id: "foo" }, "");
      let component1 = tag(
        "div",
        { "data-phx-component": 0, "data-phx-view": "foo" },
        "Hello",
      );
      document.body.appendChild(view);
      view.appendChild(component1);
      expect(DOM.findComponentNodeList("bar", 123)).toEqual([]);
    });
  });

  test("isNowTriggerFormExternal", () => {
    let form;
    form = tag("form", { "phx-trigger-external": "" }, "");
    document.body.appendChild(form);
    expect(DOM.isNowTriggerFormExternal(form, "phx-trigger-external")).toBe(
      true,
    );

    form = tag("form", {}, "");
    document.body.appendChild(form);
    expect(DOM.isNowTriggerFormExternal(form, "phx-trigger-external")).toBe(
      false,
    );

    // not in the DOM -> false
    form = tag("form", { "phx-trigger-external": "" }, "");
    expect(DOM.isNowTriggerFormExternal(form, "phx-trigger-external")).toBe(
      false,
    );
  });

  describe("cleanChildNodes", () => {
    test("only cleans when phx-update is append or prepend", () => {
      const content = `
      <div id="1">1</div>
      <div>no id</div>

      some test
      `.trim();

      const div = tag("div", {}, content);
      DOM.cleanChildNodes(div, "phx-update");

      expect(div.innerHTML).toBe(content);
    });

    test("silently removes empty text nodes", () => {
      const content = `
      <div id="1">1</div>


      <div id="2">2</div>
      `.trim();

      const div = tag("div", { "phx-update": "append" }, content);
      DOM.cleanChildNodes(div, "phx-update");

      expect(div.innerHTML).toBe('<div id="1">1</div><div id="2">2</div>');
    });

    test("emits warning when removing elements without id", () => {
      const content = `
      <div id="1">1</div>
      <div>no id</div>

      some test
      `.trim();

      const div = tag("div", { "phx-update": "append" }, content);

      let errorCount = 0;
      jest.spyOn(console, "error").mockImplementation(() => (errorCount += 1));
      DOM.cleanChildNodes(div, "phx-update");

      expect(div.innerHTML).toBe('<div id="1">1</div>');
      expect(errorCount).toBe(2);
    });
  });

  describe("isFormInput", () => {
    test("identifies all inputs except for buttons as form inputs", () => {
      [
        "checkbox",
        "color",
        "date",
        "datetime-local",
        "email",
        "file",
        "hidden",
        "image",
        "month",
        "number",
        "password",
        "radio",
        "range",
        "reset",
        "search",
        "submit",
        "tel",
        "text",
        "time",
        "url",
        "week",
      ].forEach((inputType) => {
        const input = tag("input", { type: inputType }, "");
        expect(DOM.isFormInput(input)).toBeTruthy();
      });

      const input = tag("input", { type: "button" }, "");
      expect(DOM.isFormInput(input)).toBeFalsy();
    });

    test("identifies selects as form inputs", () => {
      const select = tag("select", {}, "");
      expect(DOM.isFormInput(select)).toBeTruthy();
    });

    test("identifies textareas as form inputs", () => {
      const textarea = tag("textarea", {}, "");
      expect(DOM.isFormInput(textarea)).toBeTruthy();
    });

    test("identifies form associated custom elements as form inputs", () => {
      class CustomFormInput extends HTMLElement {
        static formAssociated = true;

        constructor() {
          super();
        }
      }
      customElements.define("custom-form-input", CustomFormInput);
      const customFormInput = tag("custom-form-input", {}, "");
      expect(DOM.isFormInput(customFormInput)).toBeTruthy();

      class CustomNotFormInput extends HTMLElement {
        constructor() {
          super();
        }
      }

      customElements.define("custom-not-form-input", CustomNotFormInput);
      const customNotFormInput = tag("custom-not-form-input", {}, "");
      expect(DOM.isFormInput(customNotFormInput)).toBeFalsy();
    });
  });
});

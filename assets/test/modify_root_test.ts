import { modifyRoot } from "phoenix_live_view/rendered";

describe("modifyRoot stripping comments", () => {
  test("starting comments", () => {
    // starting comments
    const html = `
    <!-- start -->
    <!-- start2 -->
    <div class="px-51"><!-- MENU --><div id="menu">MENU</div></div>
    `;
    const [strippedHTML, commentBefore, commentAfter] = modifyRoot(html, {});
    expect(strippedHTML).toEqual(
      '<div class="px-51"><!-- MENU --><div id="menu">MENU</div></div>',
    );
    expect(commentBefore).toEqual(`
    <!-- start -->
    <!-- start2 -->
    `);
    expect(commentAfter).toEqual(`
    `);
  });

  test("ending comments", () => {
    const html = `
    <div class="px-52"><!-- MENU --><div id="menu">MENU</div></div>
    <!-- ending -->
    `;
    const [strippedHTML, commentBefore, commentAfter] = modifyRoot(html, {});
    expect(strippedHTML).toEqual(
      '<div class="px-52"><!-- MENU --><div id="menu">MENU</div></div>',
    );
    expect(commentBefore).toEqual(`
    `);
    expect(commentAfter).toEqual(`
    <!-- ending -->
    `);
  });

  test("starting and ending comments", () => {
    const html = `
    <!-- starting -->
    <div class="px-53"><!-- MENU --><div id="menu">MENU</div></div>
    <!-- ending -->
    `;
    const [strippedHTML, commentBefore, commentAfter] = modifyRoot(html, {});
    expect(strippedHTML).toEqual(
      '<div class="px-53"><!-- MENU --><div id="menu">MENU</div></div>',
    );
    expect(commentBefore).toEqual(`
    <!-- starting -->
    `);
    expect(commentAfter).toEqual(`
    <!-- ending -->
    `);
  });

  test("merges new attrs", () => {
    const html = `
    <div class="px-5"><div id="menu">MENU</div></div>
    `;
    expect(modifyRoot(html, { id: 123 })[0]).toEqual(
      '<div id="123" class="px-5"><div id="menu">MENU</div></div>',
    );
    expect(modifyRoot(html, { id: 123, another: "" })[0]).toEqual(
      '<div id="123" another="" class="px-5"><div id="menu">MENU</div></div>',
    );
    // clearing innerHTML
    expect(modifyRoot(html, { id: 123, another: "" }, true)[0]).toEqual(
      '<div id="123" another=""></div>',
    );
    // self closing
    const selfClose = `
    <input class="px-5"/>
    `;
    expect(modifyRoot(selfClose, { id: 123, another: "" })[0]).toEqual(
      '<input id="123" another="" class="px-5"/>',
    );
  });

  test("mixed whitespace", () => {
    const html = `
    <div
${"\t"}class="px-5"><div id="menu">MENU</div></div>
    `;
    expect(modifyRoot(html, { id: 123 })[0]).toEqual(`<div id="123"
${"\t"}class="px-5"><div id="menu">MENU</div></div>`);
    expect(modifyRoot(html, { id: 123, another: "" })[0])
      .toEqual(`<div id="123" another=""
${"\t"}class="px-5"><div id="menu">MENU</div></div>`);
    // clearing innerHTML
    expect(modifyRoot(html, { id: 123, another: "" }, true)[0]).toEqual(
      '<div id="123" another=""></div>',
    );
  });

  test("self closed", () => {
    let html = `<input${"\t\r\n"}class="px-5"/>`;
    expect(modifyRoot(html, { id: 123, another: "" })[0]).toEqual(
      `<input id="123" another=""${"\t\r\n"}class="px-5"/>`,
    );

    html = '<input class="text-sm"/>';
    expect(modifyRoot(html, { id: 123 })[0]).toEqual(
      '<input id="123" class="text-sm"/>',
    );

    html = "<img/>";
    expect(modifyRoot(html, { id: 123 })[0]).toEqual('<img id="123"/>');

    html = "<img>";
    expect(modifyRoot(html, { id: 123 })[0]).toEqual('<img id="123">');

    html = '<!-- before --><!-- <> --><input class="text-sm"/><!-- after -->';
    let result = modifyRoot(html, { id: 123 });
    expect(result[0]).toEqual('<input id="123" class="text-sm"/>');
    expect(result[1]).toEqual("<!-- before --><!-- <> -->");
    expect(result[2]).toEqual("<!-- after -->");

    // unclosed self closed
    html = '<img class="px-5">';
    expect(modifyRoot(html, { id: 123 })[0]).toEqual(
      '<img id="123" class="px-5">',
    );

    html =
      '<!-- <before> --><img class="px-5"><!-- <after> --><!-- <after2> -->';
    result = modifyRoot(html, { id: 123 });
    expect(result[0]).toEqual('<img id="123" class="px-5">');
    expect(result[1]).toEqual("<!-- <before> -->");
    expect(result[2]).toEqual("<!-- <after> --><!-- <after2> -->");
  });

  test("does not extract id from inner element", () => {
    const html =
      '<div>\n  <div id="verify-payment-data-component" data-phx-id="phx-F6AZf4FwSR4R50pB-39" data-phx-skip></div>\n</div>';
    const attrs = {
      "data-phx-id": "c3-phx-F6AZf4FwSR4R50pB",
      "data-phx-component": 3,
      "data-phx-skip": true,
    };

    const [strippedHTML, _commentBefore, _commentAfter] = modifyRoot(
      html,
      attrs,
      true,
    );

    expect(strippedHTML).toEqual(
      '<div data-phx-id="c3-phx-F6AZf4FwSR4R50pB" data-phx-component="3" data-phx-skip></div>',
    );
  });
});

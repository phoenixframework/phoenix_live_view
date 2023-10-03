import {modifyRoot} from "phoenix_live_view/rendered"

describe("modifyRoot stripping comments", () => {
  test("starting comments", () => {
    // starting comments
    let html = `
<!-- start -->
<!-- start2 -->
<div class="px-51"><!-- MENU --><div id="menu">MENU</div></div>
`
    let [strippedHTML, commentBefore, commentAfter] = modifyRoot(html, {})
    expect(strippedHTML).toEqual("<div class=\"px-51\"><!-- MENU --><div id=\"menu\">MENU</div></div>")
    expect(commentBefore).toEqual(`<!-- start -->
<!-- start2 -->`)
    expect(commentAfter).toEqual("")
  })

  test("ending comments", () => {
    let html = `
<div class="px-52"><!-- MENU --><div id="menu">MENU</div></div>
<!-- ending -->
`
    let [strippedHTML, commentBefore, commentAfter] = modifyRoot(html, {})
    expect(strippedHTML).toEqual("<div class=\"px-52\"><!-- MENU --><div id=\"menu\">MENU</div></div>")
    expect(commentBefore).toEqual("")
    expect(commentAfter).toEqual("<!-- ending -->")
  })

  test("staring and ending comments", () => {
    let html = `
<!-- starting -->
<div class="px-53"><!-- MENU --><div id="menu">MENU</div></div>
<!-- ending -->
`
    let [strippedHTML, commentBefore, commentAfter] = modifyRoot(html, {})
    expect(strippedHTML).toEqual("<div class=\"px-53\"><!-- MENU --><div id=\"menu\">MENU</div></div>")
    expect(commentBefore).toEqual(`<!-- starting -->`)
    expect(commentAfter).toEqual(`<!-- ending -->`)
  })

  test("merges new attrs", () => {
    let html = `
    <div class="px-5"><div id="menu">MENU</div></div>
    `
    expect(modifyRoot(html, {id: 123})[0]).toEqual(`<div id="123" class="px-5"><div id="menu">MENU</div></div>`)
    expect(modifyRoot(html, {id: 123, class: ""})[0]).toEqual(`<div id="123" class="px-5"><div id="menu">MENU</div></div>`)
    expect(modifyRoot(html, {id: 123, another: ""})[0]).toEqual(`<div id="123" another="" class="px-5"><div id="menu">MENU</div></div>`)
    // clearing innerHTML
    expect(modifyRoot(html, {id: 123, another: ""}, "")[0]).toEqual(`<div id="123" another=""></div>`)
    // self closing
    let selfClose = `
    <input class="px-5"/>
    `
    expect(modifyRoot(selfClose, {id: 123, another: ""})[0]).toEqual(`<input id="123" another="" class="px-5"/>`)
  })

  test("mixed whitespace", () => {
    let html = `
    <div
${"\t"}class="px-5"><div id="menu">MENU</div></div>
    `
    expect(modifyRoot(html, {id: 123})[0]).toEqual(`<div id="123"
${"\t"}class="px-5"><div id="menu">MENU</div></div>`)
    expect(modifyRoot(html, {id: 123, class: ""})[0]).toEqual(`<div id="123"
${"\t"}class="px-5"><div id="menu">MENU</div></div>`)
    expect(modifyRoot(html, {id: 123, another: ""})[0]).toEqual(`<div id="123" another=""
${"\t"}class="px-5"><div id="menu">MENU</div></div>`)
    // clearing innerHTML
    expect(modifyRoot(html, {id: 123, another: ""}, "")[0]).toEqual(`<div id="123" another=""></div>`)
    // self closing
    let selfClose = `<input${"\t\r\n"}class="px-5"/>`
    expect(modifyRoot(selfClose, {id: 123, another: ""})[0]).toEqual(`<input id="123" another=""${"\t\r\n"}class="px-5"/>`)
  })

  test("unclosed or self closed", () => {
    let html = `<a`
    expect(modifyRoot(html, {id: 123})[0]).toEqual(`<a id="123"`)

    html = `<div class="`
    expect(modifyRoot(html, {id: 123})[0]).toEqual(`<div id="123" class="`)

    let [newHTML, commentBefore, commentAfter] = modifyRoot('<!-- <comment> --><div class="', {id: 123})
    expect(newHTML).toEqual(`<div id="123" class="`)
    expect(commentBefore).toEqual(`<!-- <comment> -->`)

    html = `<div>`
    expect(modifyRoot(html, {id: 123})[0]).toEqual(`<div id="123">`)

    let [newHTML2, commentBefore2, commentAfter2] = modifyRoot('<!-- <comment> --><div>', {id: 123})
    expect(newHTML2).toEqual(`<div id="123">`)
    expect(commentBefore2).toEqual(`<!-- <comment> -->`)

    html = `<!-- <comment> --><div>`
    expect(modifyRoot(html, {id: 123})[0]).toEqual(`<div id="123">`)

    html = `<input class="text-sm"/>`
    expect(modifyRoot(html, {id: 123})[0]).toEqual(`<input id="123" class="text-sm"/>`)

    html = `<div id="flash-group">\n `
    expect(modifyRoot(html, {})[0]).toEqual(`<div id="flash-group">`)
  })
})

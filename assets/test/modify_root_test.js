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
    expect(commentAfter).toEqual(null)
  })

  test("ending comments", () => {
    let html = `
<div class="px-52"><!-- MENU --><div id="menu">MENU</div></div>
<!-- ending -->
`
    let [strippedHTML, commentBefore, commentAfter] = modifyRoot(html, {})
    expect(strippedHTML).toEqual("<div class=\"px-52\"><!-- MENU --><div id=\"menu\">MENU</div></div>")
    expect(commentBefore).toEqual(null)
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
    expect(modifyRoot(html, {id: 123})[0]).toEqual(`<div class="px-5" id="123"><div id="menu">MENU</div></div>`)
    expect(modifyRoot(html, {id: 123, class: ""})[0]).toEqual(`<div class="px-5" id="123"><div id="menu">MENU</div></div>`)
    expect(modifyRoot(html, {id: 123, another: ""})[0]).toEqual(`<div class="px-5" id="123" another=""><div id="menu">MENU</div></div>`)
    // clearing innerHTML
    expect(modifyRoot(html, {id: 123, another: ""}, "")[0]).toEqual(`<div class="px-5" id="123" another=""></div>`)
    // self closing
    let selfClose = `
    <input class="px-5"/>
    `
    expect(modifyRoot(selfClose, {id: 123, another: ""})[0]).toEqual(`<input class="px-5" id="123" another=""/>`)
  })
  test("mixed whitespace", () => {
    let html = `
    <div
${"\t"}class="px-5"><div id="menu">MENU</div></div>
    `
    expect(modifyRoot(html, {id: 123})[0]).toEqual(`<div
${"\t"}class="px-5" id="123"><div id="menu">MENU</div></div>`)
    expect(modifyRoot(html, {id: 123, class: ""})[0]).toEqual(`<div
${"\t"}class="px-5" id="123"><div id="menu">MENU</div></div>`)
    expect(modifyRoot(html, {id: 123, another: ""})[0]).toEqual(`<div
${"\t"}class="px-5" id="123" another=""><div id="menu">MENU</div></div>`)
    // clearing innerHTML
    expect(modifyRoot(html, {id: 123, another: ""}, "")[0]).toEqual(`<div
${"\t"}class="px-5" id="123" another=""></div>`)
    // self closing
    let selfClose = `<input${"\t\r\n"}class="px-5"/>`
    expect(modifyRoot(selfClose, {id: 123, another: ""})[0]).toEqual(`<input${"\t\r\n"}class="px-5" id="123" another=""/>`)
  })
})

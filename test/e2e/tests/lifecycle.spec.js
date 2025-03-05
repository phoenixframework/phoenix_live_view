const {test, expect} = require("../test-fixtures")
const {syncLV} = require("../utils")

test.describe("auto_connect", () => {
  let webSocketEvents = []
  let networkEvents = []
  let consoleMessages = []

  test.beforeEach(async ({page}) => {
    networkEvents = []
    webSocketEvents = []
    consoleMessages = []

    page.on("request", request => networkEvents.push({method: request.method(), url: request.url()}))

    page.on("websocket", ws => {
      ws.on("framesent", event => webSocketEvents.push({type: "sent", payload: event.payload}))
      ws.on("framereceived", event => webSocketEvents.push({type: "received", payload: event.payload}))
      ws.on("close", () => webSocketEvents.push({type: "close"}))
    })

    page.on("console", msg => consoleMessages.push(msg.text()))
  })

  test("connects by default", async ({page}) => {
    await page.goto("/lifecycle")
    await syncLV(page)

    expect(webSocketEvents).toHaveLength(2)
  })

  test("does not connect when auto_connect is false", async ({page}) => {
    await page.goto("/lifecycle?auto_connect=false")
    // eslint-disable-next-line playwright/no-networkidle
    await page.waitForLoadState("networkidle")
    expect(webSocketEvents).toHaveLength(0)
  })

  test("connects when navigating to a view with auto_connect=true", async ({page}) => {
    await page.goto("/lifecycle?auto_connect=false")
    // eslint-disable-next-line playwright/no-networkidle
    await page.waitForLoadState("networkidle")
    expect(webSocketEvents).toHaveLength(0)
    await page.getByRole("link", {name: "Navigate to self (auto_connect=true)"}).click()
    await syncLV(page)
    expect(webSocketEvents).toHaveLength(2)
  })
  
  test("stays connected when navigating to a view with auto_connect=false", async ({page}) => {
    await page.goto("/lifecycle")
    await syncLV(page)
    expect(webSocketEvents.filter(e => e.payload.includes("phx_join"))).toHaveLength(1)
    await page.getByRole("link", {name: "Navigate to self (auto_connect=false)"}).click()
    await syncLV(page)
    expect(webSocketEvents.filter(e => e.payload.includes("phx_join"))).toHaveLength(2)
  })
})

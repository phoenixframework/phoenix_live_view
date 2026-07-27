import { test, expect } from "../test-fixtures";
import { syncLV } from "../utils";

let webSocketEvents = [];
let networkEvents = [];

test.beforeEach(async ({ page }) => {
  networkEvents = [];
  webSocketEvents = [];

  page.on("request", (request) =>
    networkEvents.push({ method: request.method(), url: request.url() }),
  );

  page.on("websocket", (ws) => {
    ws.on("framesent", (event) =>
      webSocketEvents.push({ type: "sent", payload: event.payload }),
    );
    ws.on("framereceived", (event) =>
      webSocketEvents.push({ type: "received", payload: event.payload }),
    );
    ws.on("close", () => webSocketEvents.push({ type: "close" }));
  });
});

test("can prevent live navigation and beforeunload", async ({ page }) => {
  await page.goto("/form-unsaved");
  await syncLV(page);

  expect(await page.evaluate(() => window.unsavedEvents)).toEqual([]);

  await page.locator("#unsaved-note").fill("draft");
  await syncLV(page);
  await expect(page.locator("#unsaved-value")).toHaveText(
    "Unsaved value: draft",
  );

  networkEvents = [];
  webSocketEvents = [];

  const confirmPromise = page.waitForEvent("dialog");
  const clickPromise = page.getByRole("link", { name: "Leave form" }).click();
  const confirmDialog = await confirmPromise;
  expect(confirmDialog.type()).toBe("confirm");
  expect(confirmDialog.message()).toBe(
    "You have unsaved changes. Leave without saving?",
  );
  await confirmDialog.dismiss();
  await clickPromise;

  await expect(page).toHaveURL("/form-unsaved");
  expect(networkEvents).toEqual([]);
  expect(webSocketEvents).toEqual([]);
  expect(await page.evaluate(() => window.unsavedEvents)).toEqual([
    {
      type: "phx",
      detail: {
        href: "http://localhost:4004/form-unsaved/target",
        patch: false,
        pop: false,
        direction: "forward",
      },
    },
  ]);

  await page.locator("#unsaved-note").fill("draft after live nav cancel");
  await syncLV(page);
  await expect(page.locator("#unsaved-value")).toHaveText(
    "Unsaved value: draft after live nav cancel",
  );

  const dialogPromise = page.waitForEvent("dialog");
  const closePromise = page.close({ runBeforeUnload: true });
  const dialog = await dialogPromise;
  expect(dialog.type()).toBe("beforeunload");
  await dialog.dismiss();
  await closePromise;

  expect(page.isClosed()).toBe(false);
  await expect(page).toHaveURL("/form-unsaved");
  await expect(page.locator("#unsaved-note")).toHaveValue(
    "draft after live nav cancel",
  );
  expect(await page.evaluate(() => window.unsavedEvents)).toEqual([
    {
      type: "phx",
      detail: {
        href: "http://localhost:4004/form-unsaved/target",
        patch: false,
        pop: false,
        direction: "forward",
      },
    },
    { type: "beforeunload" },
  ]);
  expect(
    await page.evaluate(() => ({
      connected: window.liveSocket.isConnected(),
      unloaded: window.liveSocket.isUnloaded(),
    })),
  ).toEqual({ connected: true, unloaded: false });

  await page.locator("#unsaved-note").fill("draft after beforeunload cancel");
  await syncLV(page);
  await expect(page.locator("#unsaved-value")).toHaveText(
    "Unsaved value: draft after beforeunload cancel",
  );
});

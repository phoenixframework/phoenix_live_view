import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/3931
test("dynamic attributes reset __changed__ and properly re-render", async ({
  page,
}) => {
  let webSocketEvents = [];
  page.on("websocket", (ws) => {
    ws.on("framesent", (event) =>
      webSocketEvents.push({ type: "sent", payload: event.payload }),
    );
    ws.on("framereceived", (event) =>
      webSocketEvents.push({ type: "received", payload: event.payload }),
    );
    ws.on("close", () => webSocketEvents.push({ type: "close" }));
  });

  await page.goto("/issues/3931");
  await syncLV(page);

  // it should be updated asynchronously
  await expect(page.locator("#async")).toContainText(
    "This was loaded asynchronously!",
  );

  expect(webSocketEvents).toEqual(
    expect.arrayContaining([
      { type: "sent", payload: expect.stringContaining("phx_join") },
      { type: "received", payload: expect.stringContaining("phx_reply") },
      { type: "received", payload: expect.stringContaining("diff") },
    ]),
  );
});

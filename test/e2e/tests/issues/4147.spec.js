import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4147
test("hook outside of liveview does works when reconnecting", async ({
  page,
}) => {
  const logs = [];
  page.on("console", (msg) => {
    logs.push(msg.text());
  });

  const errors = [];
  page.on("pageerror", (err) => {
    errors.push(err);
  });

  await page.goto("/issues/4147");
  await syncLV(page);

  await page.evaluate(
    () => new Promise((resolve) => window.liveSocket.disconnect(resolve)),
  );
  await expect(page.locator(".phx-loading")).toHaveCount(1);

  await page.evaluate(() => window.liveSocket.connect());
  await syncLV(page);

  expect(errors).toHaveLength(0);
  // Hook was mounted once
  expect(
    logs.filter((log) => log.includes("HookOutside mounted")),
  ).toHaveLength(1);
});

import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4212
//
// stream_insert(..., at: idx) used to call insertBefore() inside
// maybeReOrderStream, which detaches and re-attaches the moved DOM node and
// fires extra disconnectedCallback / connectedCallback cycles on custom
// elements. The fix routes the reorder through the atomic moveBefore() API
// when the runtime supports it. We assert that connectedMoveCallback fires
// (direct evidence that moveBefore was used) and that no spurious
// disconnect happened on the just-inserted element.
test("stream_insert with :at uses atomic moveBefore for the reorder", async ({
  page,
}) => {
  await page.goto("/issues/4212");
  await syncLV(page);

  const moveBeforeSupported = await page.evaluate(
    () => typeof Element.prototype.moveBefore === "function",
  );
  if (!moveBeforeSupported) {
    // eslint-disable-next-line playwright/no-skipped-test
    test.skip();
  }

  // wait for the SSR'd custom elements to be observable; we don't make a
  // strict assertion on the initial-mount log because morphdom's join-time
  // reconciliation can produce extra disconnect/connect cycles outside the
  // maybeReOrderStream path covered by this fix.
  await expect
    .poll(async () =>
      await page.evaluate(
        () =>
          window.__lvCustomElLog.filter((e) => e.type === "connected").length,
      ),
    )
    .toBeGreaterThanOrEqual(3);

  await page.evaluate(() => (window.__lvCustomElLog = []));

  await page.locator("#insert-at-1").click();
  await syncLV(page);

  // The new element is added by morphdom's addChild (-> connectedCallback),
  // and then maybeReOrderStream moves it to the at: 1 position. With the
  // moveBefore fix, that reorder must produce a connectedMoveCallback and
  // must NOT produce a disconnect on the just-inserted element.
  const log = await page.evaluate(() => window.__lvCustomElLog);
  const newEvents = log.filter((e) => e.id === "el-new1");

  expect(newEvents).toEqual(
    expect.arrayContaining([
      { type: "connected", id: "el-new1" },
      { type: "moved", id: "el-new1" },
    ]),
  );
  expect(newEvents.filter((e) => e.type === "disconnected")).toEqual([]);
});

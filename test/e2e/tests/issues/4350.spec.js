import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4350
//
// A component that is used again between cids_will_destroy and cids_destroyed must
// revive its whole subtree. Children that change tracking skips are the interesting
// case: the parent comes back, but nothing re-renders the child, so it stays marked
// and is deleted while its DOM is still on the page.
//
// The window between the two messages is a single round trip, so we hold
// cids_destroyed in flight and bring the component back while it is delayed.
test("reviving a component also revives children skipped by change tracking", async ({
  page,
}) => {
  // cids_destroyed is held until the test releases it, so the ordering is
  // explicit rather than timing dependent
  let onDestroyedSent, releaseDestroyed, onDestroyedHandled;
  const destroyedSent = new Promise((resolve) => (onDestroyedSent = resolve));
  const destroyedReleased = new Promise(
    (resolve) => (releaseDestroyed = resolve),
  );
  const destroyedHandled = new Promise(
    (resolve) => (onDestroyedHandled = resolve),
  );

  await page.routeWebSocket(/.*live.*/, (ws) => {
    const server = ws.connectToServer();
    // [join_ref, ref, topic, event, payload]
    let destroyedRef = null;

    ws.onMessage(async (message) => {
      if (typeof message === "string" && message.includes("cids_destroyed")) {
        destroyedRef = JSON.parse(message)[1];
        onDestroyedSent();
        await destroyedReleased;
      }

      server.send(message);
    });

    server.onMessage((message) => {
      if (destroyedRef !== null && typeof message === "string") {
        const [, ref] = JSON.parse(message);
        if (ref === destroyedRef) {
          onDestroyedHandled();
        }
      }

      ws.send(message);
    });
  });

  await page.goto("/issues/4350");
  await syncLV(page);

  await page.locator("#bump").click();
  await expect(page.locator("#leaf-count")).toHaveText("1");

  // re-render the branch so the dynamic holding the leaf is change-tracked away
  await page.locator("#tick").click();
  await syncLV(page);
  await expect(page.locator("#branch")).toContainText("tick: 1");

  const leafCid = await page
    .locator("#leaf")
    .getAttribute("data-phx-component");

  // remove the subtree; the client reports both cids as destroyed
  await page.locator("#hide").click();
  await expect(page.locator("#wrapper")).toHaveCount(0);

  // cids_destroyed is held in flight - bring the component back before it lands.
  // The subtree being back means the server has already re-rendered it.
  await destroyedSent;
  await page.locator("#show").click();
  await expect(page.locator("#wrapper")).toHaveCount(1);
  await syncLV(page);

  // only now let the destroy through, and wait for the server to answer it
  releaseDestroyed();
  await destroyedHandled;

  // the leaf is the same component and is still wired to the server
  await expect(page.locator("#leaf")).toHaveAttribute(
    "data-phx-component",
    leafCid,
  );

  await page.locator("#bump").click();
  await expect(page.locator("#leaf-count")).toHaveText("2");
});

import { test, expect } from "../test-fixtures";
import { syncLV, evalLV } from "../utils";

test("renders modal inside portal location", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  await expect(page.locator("#my-modal")).toHaveCount(1);
  await expect(page.locator("#my-modal-content")).toBeHidden();
  // no modal inside the main element (rendered in the layout)
  await expect(page.locator("main #my-modal")).toHaveCount(0);

  await page.getByRole("button", { name: "Open modal" }).click();
  await expect(page.locator("#my-modal-content")).toBeVisible();

  await expect(page.locator("#my-modal-content")).toContainText(
    "DOM patching works as expected: 0",
  );
  await evalLV(page, "send(self(), :tick)");
  await expect(page.locator("#my-modal-content")).toContainText(
    "DOM patching works as expected: 1",
  );
});

test("teleported element is removed properly", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  await expect(
    page.locator("[data-phx-teleported-src=portal-source]"),
  ).toHaveCount(1);
  await page.getByRole("button", { name: "Toggle modal render" }).click();
  await expect(
    page.locator("[data-phx-teleported-src=portal-source]"),
  ).toHaveCount(0);
  await expect(page.locator("#my-modal")).toHaveCount(0);

  // other modal still exists
  await expect(
    page.locator("[data-phx-teleported-src=portal-source-2]"),
  ).toHaveCount(1);

  // now toggle it again
  await page.getByRole("button", { name: "Toggle modal render" }).click();
  await expect(
    page.locator("[data-phx-teleported-src=portal-source]"),
  ).toHaveCount(1);

  // now navigate to another page
  await page.getByRole("button", { name: "Live navigate" }).click();
  await syncLV(page);
  // all teleported elements should be gone
  await expect(page.locator("[data-phx-teleported-src]")).toHaveCount(0);
});

test("events are routed to correct LiveView", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  await expect(page.locator("#nested-event-count")).toHaveText("0");
  await page
    .getByRole("button", { name: "Trigger event in nested LV", exact: true })
    .click();
  await expect(page.locator("#nested-event-count")).toHaveText("1");
  await page
    .getByRole("button", {
      name: "Trigger event in nested LV (from teleported button)",
    })
    .click();
  await expect(page.locator("#nested-event-count")).toHaveText("2");
});

test("streams work in teleported LiveComponent", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  expect(
    await page.evaluate(
      () => document.querySelector("#stream-in-lc").children.length,
    ),
  ).toEqual(2);
  await page.getByRole("button", { name: "Prepend item" }).click();
  await syncLV(page);
  expect(
    await page.evaluate(
      () => document.querySelector("#stream-in-lc").children.length,
    ),
  ).toEqual(3);
});

test("tooltip example", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  await expect(page.locator("#tooltip-example-portal")).toBeHidden();
  await expect(page.locator("#tooltip-example-no-portal")).toBeHidden();

  await page.getByRole("button", { name: "Hover me", exact: true }).hover();
  await expect(page.locator("#tooltip-example-portal")).toBeVisible();
  await expect(page.locator("#tooltip-example-no-portal")).toBeHidden();

  await page.getByRole("button", { name: "Hover me (no portal)" }).hover();
  await expect(page.locator("#tooltip-example-portal")).toBeHidden();
  await expect(page.locator("#tooltip-example-no-portal")).toBeVisible();
});

test("teleported hook works correctly", async ({ page }) => {
  // https://github.com/phoenixframework/phoenix_live_view/issues/3950
  await page.goto("/portal?tick=false");
  await syncLV(page);

  await expect(page.locator("#hook-test")).toHaveAttribute(
    "data-portalhook-mounted",
    "true",
  );
});

test("nested portals render and work correctly", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  // Verify outer portal is teleported
  await expect(
    page.locator("[data-phx-teleported-src=nested-portal-source]"),
  ).toHaveCount(1);
  await expect(page.locator("#outer-portal")).toHaveCount(1);

  // Verify inner portal is teleported
  await expect(
    page.locator("[data-phx-teleported-src=inner-portal-source]"),
  ).toHaveCount(1);
  await expect(page.locator("#inner-portal")).toHaveCount(1);

  // Test that events work in nested portals
  await expect(page.locator("#nested-portal-count")).toHaveText("0");
  await page
    .getByRole("button", { name: "Click nested portal button" })
    .click();
  await expect(page.locator("#nested-portal-count")).toHaveText("1");

  // Test DOM patching works in nested portals
  await expect(page.locator("#nested-portal-content")).toContainText(
    "Tick count: 0",
  );
  await evalLV(page, "send(self(), :tick)");
  await expect(page.locator("#nested-portal-content")).toContainText(
    "Tick count: 1",
  );
});

test("nested portals cleanup and re-render correctly", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  // Verify initial state
  await expect(page.locator("#outer-portal")).toHaveCount(1);
  await expect(page.locator("#inner-portal")).toHaveCount(1);

  // Toggle off - both portals should be removed
  await page.getByRole("button", { name: "Toggle nested portals" }).click();
  await expect(
    page.locator("[data-phx-teleported-src=nested-portal-source]"),
  ).toHaveCount(0);
  await expect(
    page.locator("[data-phx-teleported-src=inner-portal-source]"),
  ).toHaveCount(0);
  await expect(page.locator("#outer-portal")).toHaveCount(0);
  await expect(page.locator("#inner-portal")).toHaveCount(0);

  // Toggle back on - both portals should reappear with correct nesting
  await page.getByRole("button", { name: "Toggle nested portals" }).click();
  await expect(
    page.locator("[data-phx-teleported-src=nested-portal-source]"),
  ).toHaveCount(1);
  await expect(
    page.locator("[data-phx-teleported-src=inner-portal-source]"),
  ).toHaveCount(1);
  await expect(page.locator("#outer-portal")).toHaveCount(1);
  await expect(page.locator("#inner-portal")).toHaveCount(1);
});

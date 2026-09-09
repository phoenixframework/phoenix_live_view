import { test, expect } from "@playwright/test";
import { syncLV } from "../utils";

const nested = (page) => page.locator("#embed-slot [data-app=embedded]");

const outside = (page) =>
  page.locator("[data-app=embedded]:not(#embed-slot *)");

const connectAll = async (page) => {
  await page.goto("/multi-socket");
  await syncLV(page);
  await expect(page.locator("[data-phx-session].phx-connected")).toHaveCount(3);
};

test("each socket joins exactly its own roots", async ({ page }) => {
  await connectAll(page);

  const mainIds = await page.evaluate(() =>
    Object.values(window.mainLiveSocket.roots).map((view) =>
      view.el.getAttribute("data-app"),
    ),
  );
  expect(mainIds).toEqual(["main"]);

  const embeddedApps = await page.evaluate(() =>
    Object.values(window.embeddedLiveSocket.roots).map((view) =>
      view.el.getAttribute("data-app"),
    ),
  );
  expect(embeddedApps).toEqual(["embedded", "embedded"]);
  // one embedded root lives inside the host view's ignore slot
  const nestedJoined = await page.evaluate(() =>
    Object.values(window.embeddedLiveSocket.roots).map(
      (view) => !!view.el.closest("#embed-slot"),
    ),
  );
  expect(nestedJoined.sort()).toEqual([false, true]);
});

test("clicks are handled only by the owning socket", async ({ page }) => {
  await connectAll(page);

  await page.locator("#main-click").click();
  await syncLV(page);
  await expect(page.locator("#main-clicks")).toHaveText("1");
  await expect(nested(page).locator("[data-role=clicks]")).toHaveText("0");
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("0");

  await nested(page).locator("[data-role=click]").click();
  await syncLV(page);
  await expect(nested(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("0");
  await expect(page.locator("#main-clicks")).toHaveText("1");

  await outside(page).locator("[data-role=click]").click();
  await syncLV(page);
  await expect(outside(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(nested(page).locator("[data-role=clicks]")).toHaveText("1");
  await expect(page.locator("#main-clicks")).toHaveText("1");
});

test("window bindings fire once per socket for a single event", async ({
  page,
}) => {
  await connectAll(page);

  await page.locator("body").press("Escape");
  await syncLV(page);
  await expect(page.locator("#main-keys")).toHaveText("1");
  await expect(nested(page).locator("[data-role=keys]")).toHaveText("1");
  await expect(outside(page).locator("[data-role=keys]")).toHaveText("1");

  await nested(page).locator("[data-role=click]").press("Escape");
  await syncLV(page);
  await expect(page.locator("#main-keys")).toHaveText("2");
  await expect(nested(page).locator("[data-role=keys]")).toHaveText("2");
  await expect(outside(page).locator("[data-role=keys]")).toHaveText("2");
});

test("form input is dispatched only to the owning socket", async ({ page }) => {
  await connectAll(page);

  await nested(page).locator("input[name=text]").fill("hello");
  await expect(nested(page).locator("[data-role=text]")).toHaveText("hello");
  await expect(outside(page).locator("[data-role=text]")).toBeEmpty();
  await expect(page.locator("#main-text")).toBeEmpty();

  await page.locator("#main-input").fill("world");
  await expect(page.locator("#main-text")).toHaveText("world");
  await expect(nested(page).locator("[data-role=text]")).toHaveText("hello");
  await expect(outside(page).locator("[data-role=text]")).toBeEmpty();
});

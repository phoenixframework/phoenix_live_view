const { test, expect } = require("@playwright/test");
const { syncLV } = require("../../utils");

test("LiveComponent is re-rendered when racing destory", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (err) => {
    errors.push(err);
  });

  await page.goto("/issues/3026");
  await syncLV(page);

  await expect(page.locator("input[name='name']")).toHaveValue("John");

  // submitting the form unloads the LiveComponent, but it is re-added shortly after
  await page.locator("button").click();
  await syncLV(page);

  // the form elements inside the LC should still be visible
  await expect(page.locator("input[name='name']")).toBeVisible();
  await expect(page.locator("input[name='name']")).toHaveValue("John");

  // quickly toggle status
  for (let i = 0; i < 5; i++) {
    await page.locator("select[name='status']").selectOption("connecting");
    await syncLV(page);
    // now the form is not rendered as status is connecting
    await expect(page.locator("input[name='name']")).not.toBeVisible();

    // set back to loading
    await page.locator("select[name='status']").selectOption("loaded");
    await syncLV(page);
    // now the form is not rendered as status is connecting
    await expect(page.locator("input[name='name']")).toBeVisible();
  }

  // no js errors should be thrown
  await expect(errors).toEqual([]);
});

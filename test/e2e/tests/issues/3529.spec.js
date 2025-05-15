import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

const pageText = async (page) =>
  await page.evaluate(() => document.querySelector("h1").innerText);

// https://github.com/phoenixframework/phoenix_live_view/issues/3529
// https://github.com/phoenixframework/phoenix_live_view/pull/3625
test("forward and backward navigation is handled properly (replaceRootHistory)", async ({
  page,
}) => {
  await page.goto("/issues/3529");
  await syncLV(page);

  let text = await pageText(page);
  await page.getByRole("link", { name: "Navigate" }).click();
  await syncLV(page);

  // navigate remounts and changes the text
  expect(await pageText(page)).not.toBe(text);
  text = await pageText(page);

  await page.getByRole("link", { name: "Patch" }).click();
  await syncLV(page);
  // patch does not remount
  expect(await pageText(page)).toBe(text);

  // now we go back (should be patch again)
  await page.goBack();
  await syncLV(page);
  expect(await pageText(page)).toBe(text);

  // and then we back to the initial page and use back/forward
  // this should be a navigate -> remount!
  await page.goBack();
  await syncLV(page);
  expect(await pageText(page)).not.toBe(text);

  // navigate
  await page.goForward();
  await syncLV(page);
  text = await pageText(page);

  // now back again (navigate)
  await page.goBack();
  await syncLV(page);
  expect(await pageText(page)).not.toBe(text);
});

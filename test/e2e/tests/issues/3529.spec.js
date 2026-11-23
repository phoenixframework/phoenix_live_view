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

// https://github.com/phoenixframework/phoenix_live_view/issues/4507
for (const entry of ["initial", "Patch", "Navigate"]) {
  for (const back of ["browser", "history.back()"]) {
    test(`reload of ${entry} entry preserves patch navigation with ${back}`, async ({
      page,
    }) => {
      await page.goto("/issues/3529");
      await syncLV(page);
      if (entry !== "initial") {
        await page.getByRole("link", { name: entry, exact: true }).click();
        await syncLV(page);
      }

      const url = page.url();
      const originalId = await page
        .locator("[data-phx-main]")
        .getAttribute("id");
      const state = await page.evaluate(() => history.state);
      await page.reload();
      await syncLV(page);
      await expect(page.locator("[data-phx-main]")).not.toHaveAttribute(
        "id",
        originalId,
      );
      const id = await page.locator("[data-phx-main]").getAttribute("id");
      expect(await page.evaluate(() => history.state)).toEqual({
        ...state,
        id,
      });
      const mounted = await pageText(page);

      await page.getByRole("link", { name: "Patch", exact: true }).click();
      await syncLV(page);
      const patchedURL = page.url();
      expect(patchedURL).not.toBe(url);
      expect(await pageText(page)).toBe(mounted);

      if (back === "browser") {
        await page.goBack();
      } else {
        await page.evaluate(() => history.back());
      }
      await expect(page).toHaveURL(url);
      await expect(page.locator("#current-param")).toHaveText(
        new URL(url).searchParams.get("param") || "",
      );
      await syncLV(page);
      expect(await pageText(page)).toBe(mounted);

      await page.goForward();
      await expect(page).toHaveURL(patchedURL);
      await expect(page.locator("#current-param")).toHaveText(
        new URL(patchedURL).searchParams.get("param"),
      );
      await syncLV(page);
      expect(await pageText(page)).toBe(mounted);
    });
  }
}

// #3508 and #3536: URLs sharing a LiveView must remount across navigate,
// while patches on either side must keep the current mount.
test("mixed patches and navigations restore content loaded in mount", async ({
  page,
}) => {
  await page.goto("/issues/3529");
  await syncLV(page);
  const entries = [page.url()];
  for (const link of ["Patch", "Navigate", "Patch"]) {
    await page.getByRole("link", { name: link, exact: true }).click();
    await syncLV(page);
    entries.push(page.url());
  }

  const traverse = async (index, remount, direction) => {
    const mounted = await pageText(page);
    const mountedParam = await page.locator("#mounted-param").textContent();
    await page[direction]();
    const url = entries[index];
    await expect(page).toHaveURL(url);
    await expect(page.locator("#current-param")).toHaveText(
      new URL(url).searchParams.get("param") || "",
    );
    await syncLV(page);
    await expect(page.locator("#mounted-param")).toHaveText(
      remount ? new URL(url).searchParams.get("param") || "" : mountedParam,
    );
    if (remount) {
      expect(await pageText(page)).not.toBe(mounted);
    } else {
      expect(await pageText(page)).toBe(mounted);
    }
  };

  await traverse(2, false, "goBack");
  await traverse(1, true, "goBack");
  await traverse(0, false, "goBack");
  await traverse(1, false, "goForward");
  await traverse(2, true, "goForward");
  await traverse(3, false, "goForward");
});

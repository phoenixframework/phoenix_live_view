const { test, expect } = require("@playwright/test");
const { syncLV } = require("../utils");

const usersInDom = async (page, parent) => {
  return await page.locator(`#${parent} > *`)
    .evaluateAll(list => list.map(el => ({ id: el.id, text: el.childNodes[0].nodeValue.trim() })));
}

test("renders properly", async ({ page }) => {
  await page.goto("/stream");
  await syncLV(page);

  await expect(await usersInDom(page, "users")).toEqual([
    { id: "users-1", text: "chris" },
    { id: "users-2", text: "callan" }
  ]);
  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "c_users-1", text: "chris" },
    { id: "c_users-2", text: "callan" }
  ]);
  await expect(await usersInDom(page, "admins")).toEqual([
    { id: "admins-1", text: "chris-admin" },
    { id: "admins-2", text: "callan-admin" }
  ]);
});

test("elements can be updated and deleted (LV)", async ({ page }) => {
  await page.goto("/stream");
  await syncLV(page);

  await page.locator("#users-1").getByRole("button", { name: "update" }).click();
  await syncLV(page);

  await expect(await usersInDom(page, "users")).toEqual([
    { id: "users-1", text: "updated" },
    { id: "users-2", text: "callan" }
  ]);
  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "c_users-1", text: "chris" },
    { id: "c_users-2", text: "callan" }
  ]);
  await expect(await usersInDom(page, "admins")).toEqual([
    { id: "admins-1", text: "chris-admin" },
    { id: "admins-2", text: "callan-admin" }
  ]);

  await page.locator("#users-2").getByRole("button", { name: "update" }).click();
  await syncLV(page);

  await expect(await usersInDom(page, "users")).toEqual([
    { id: "users-1", text: "updated" },
    { id: "users-2", text: "updated" }
  ]);
  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "c_users-1", text: "chris" },
    { id: "c_users-2", text: "callan" }
  ]);
  await expect(await usersInDom(page, "admins")).toEqual([
    { id: "admins-1", text: "chris-admin" },
    { id: "admins-2", text: "callan-admin" }
  ]);

  await page.locator("#users-1").getByRole("button", { name: "delete" }).click();
  await syncLV(page);

  await expect(await usersInDom(page, "users")).toEqual([
    { id: "users-2", text: "updated" }
  ]);
});

test("elements can be updated and deleted (LC)", async ({ page }) => {
  await page.goto("/stream");
  await syncLV(page);

  await page.locator("#c_users-1").getByRole("button", { name: "update" }).click();
  await syncLV(page);

  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "c_users-1", text: "updated" },
    { id: "c_users-2", text: "callan" }
  ]);
  await expect(await usersInDom(page, "users")).toEqual([
    { id: "users-1", text: "chris" },
    { id: "users-2", text: "callan" }
  ]);
  await expect(await usersInDom(page, "admins")).toEqual([
    { id: "admins-1", text: "chris-admin" },
    { id: "admins-2", text: "callan-admin" }
  ]);

  await page.locator("#c_users-2").getByRole("button", { name: "update" }).click();
  await syncLV(page);

  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "c_users-1", text: "updated" },
    { id: "c_users-2", text: "updated" }
  ]);
  await expect(await usersInDom(page, "users")).toEqual([
    { id: "users-1", text: "chris" },
    { id: "users-2", text: "callan" }
  ]);
  await expect(await usersInDom(page, "admins")).toEqual([
    { id: "admins-1", text: "chris-admin" },
    { id: "admins-2", text: "callan-admin" }
  ]);

  await page.locator("#c_users-1").getByRole("button", { name: "delete" }).click();
  await syncLV(page);

  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "c_users-2", text: "updated" }
  ]);
});

test("move-to-first moves the second element to the first position (LV)", async ({ page }) => {
  test.fail("currently broken");

  await page.goto("/stream");
  await syncLV(page);

  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "users-1", text: "chris" },
    { id: "users-2", text: "callan" }
  ]);

  await page.locator("#users-2").getByRole("button", { name: "make first" }).click();
  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "users-2", text: "updated" },
    { id: "users-1", text: "chris" }
  ]);
});

test("stream reset removes items", async ({ page }) => {
  await page.goto("/stream");
  await syncLV(page);

  await expect(await usersInDom(page, "users")).toEqual([{ id: "users-1", text: "chris" }, { id: "users-2", text: "callan" }]);

  await page.getByRole("button", { name: "Reset" }).click();
  await syncLV(page);

  await expect(await usersInDom(page, "users")).toEqual([]);
});

test("stream reset properly reorders items", async ({ page }) => {
  await page.goto("/stream");
  await syncLV(page);

  await expect(await usersInDom(page, "users")).toEqual([
    { id: "users-1", text: "chris" },
    { id: "users-2", text: "callan" }
  ]);

  await page.getByRole("button", { name: "Reorder" }).click();
  await syncLV(page);

  await expect(await usersInDom(page, "users")).toEqual([
    { id: "users-3", text: "peter" },
    { id: "users-1", text: "chris" },
    { id: "users-4", text: "mona" }
  ]);
});

test.describe("Issue #2656", () => {
  test("stream reset works when patching", async ({ page }) => {
    await page.goto("/healthy/fruits");
    await syncLV(page);

    await expect(page.locator("h1")).toContainText("Fruits");
    await expect(page.locator("ul")).toContainText("Apples");
    await expect(page.locator("ul")).toContainText("Oranges");

    await page.getByRole("link", { name: "Switch" }).click();
    await expect(page).toHaveURL("/healthy/veggies");
    await syncLV(page);

    await expect(page.locator("h1")).toContainText("Veggies");

    await expect(page.locator("ul")).toContainText("Carrots");
    await expect(page.locator("ul")).toContainText("Tomatoes");
    await expect(page.locator("ul")).not.toContainText("Apples");
    await expect(page.locator("ul")).not.toContainText("Oranges");

    await page.getByRole("link", { name: "Switch" }).click();
    await expect(page).toHaveURL("/healthy/fruits");
    await syncLV(page);

    await expect(page.locator("ul")).not.toContainText("Carrots");
    await expect(page.locator("ul")).not.toContainText("Tomatoes");
    await expect(page.locator("ul")).toContainText("Apples");
    await expect(page.locator("ul")).toContainText("Oranges");
  });
});

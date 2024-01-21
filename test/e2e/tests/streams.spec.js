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

  await page.goto("/stream");
  await syncLV(page);

  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "c_users-1", text: "chris" },
    { id: "c_users-2", text: "callan" }
  ]);

  await page.locator("#c_users-2").getByRole("button", { name: "make first" }).click();
  await expect(await usersInDom(page, "c_users")).toEqual([
    { id: "c_users-2", text: "updated" },
    { id: "c_users-1", text: "chris" }
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

test.describe("Issue #2994", () => {
  const listItems = async (page) => page.locator("ul > li").evaluateAll(list => list.map(el => el.id));

  test("can filter and reset a stream", async ({ page }) => {
    await page.goto("/stream/reset");
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-a", "items-b", "items-c", "items-d"]);

    await page.getByRole("button", { name: "Filter" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-b", "items-c", "items-d"]);

    await page.getByRole("button", { name: "Reset" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-a", "items-b", "items-c", "items-d"]);
  });

  test("can reorder stream", async ({ page }) => {
    await page.goto("/stream/reset");
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-a", "items-b", "items-c", "items-d"]);

    await page.getByRole("button", { name: "Reorder" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-b", "items-a", "items-c", "items-d"]);
  });

  test("can filter and then prepend / append stream", async ({ page }) => {
    await page.goto("/stream/reset");
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-a", "items-b", "items-c", "items-d"]);

    await page.getByRole("button", { name: "Filter" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-b", "items-c", "items-d"]);

    await page.getByRole("button", { name: "Prepend" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      expect.stringMatching(/items-a-.*/),
      "items-b",
      "items-c",
      "items-d"
    ]);

    await page.getByRole("button", { name: "Reset" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-a", "items-b", "items-c", "items-d"]);

    await page.getByRole("button", { name: "Append" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-a",
      "items-b",
      "items-c",
      "items-d",
      expect.stringMatching(/items-a-.*/),
    ]);
  });
});

test.describe("Issue #2982", () => {
  const listItems = async (page) => page.locator("ul > li").evaluateAll(list => list.map(el => el.id));

  test("can reorder a stream with LiveComponents as direct stream children", async ({ page }) => {
    await page.goto("/stream/reset-lc");
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-a", "items-b", "items-c", "items-d"]);

    await page.getByRole("button", { name: "Reorder" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-e", "items-a", "items-f", "items-g"]);
  });
});

test.describe("Issue #3023", () => {
  const listItems = async (page) => page.locator("ul > li").evaluateAll(list => list.map(el => el.id));

  test("can bulk insert items at a specific index", async ({ page }) => {
    await page.goto("/stream/reset");
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-a", "items-b", "items-c", "items-d"]);

    await page.getByRole("button", { name: "Bulk insert" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual(["items-a", "items-e", "items-f", "items-g", "items-b", "items-c", "items-d"]);
  });
});

test.describe("stream limit - issue #2686", () => {
  const listItems = async (page) => page.locator("ul > li").evaluateAll(list => list.map(el => el.id));

  test("limit is enforced on mount, but not dead render", async ({ page, request }) => {
    const html = await (request.get("/stream/limit").then(r => r.text()));
    for (let i = 1; i <= 10; i++) {
      await expect(html).toContain(`id="items-${i}"`);
    }

    await page.goto("/stream/limit");
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-6",
      "items-7",
      "items-8",
      "items-9",
      "items-10"
    ]);
  });

  test("removes item at front when appending and limit is negative", async ({ page }) => {
    await page.goto("/stream/limit");
    await syncLV(page);

    // these are the defaults in the LV
    await expect(page.locator("input[name='at']")).toHaveValue("-1");
    await expect(page.locator("input[name='limit']")).toHaveValue("-5");

    await page.getByRole("button", { name: "add 1", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-7",
      "items-8",
      "items-9",
      "items-10",
      "items-11"
    ]);

    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-17",
      "items-18",
      "items-19",
      "items-20",
      "items-21"
    ]);
  });

  test("removes item at back when prepending and limit is positive", async ({ page }) => {
    await page.goto("/stream/limit");
    await syncLV(page);

    await page.locator("input[name='at']").fill("0");
    await page.locator("input[name='limit']").fill("5");
    await page.getByRole("button", { name: "recreate stream" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-10",
      "items-9",
      "items-8",
      "items-7",
      "items-6"
    ]);

    await page.getByRole("button", { name: "add 1", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-11",
      "items-10",
      "items-9",
      "items-8",
      "items-7"
    ]);

    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-21",
      "items-20",
      "items-19",
      "items-18",
      "items-17"
    ]);
  });

  test("does nothing if appending and positive limit is reached", async ({ page }) => {
    await page.goto("/stream/limit");
    await syncLV(page);

    await page.locator("input[name='at']").fill("-1");
    await page.locator("input[name='limit']").fill("5");
    await page.getByRole("button", { name: "recreate stream" }).click();
    await syncLV(page);

    await page.getByRole("button", { name: "clear" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([]);

    const items = [];
    for (let i = 1; i <= 5; i++) {
      await page.getByRole("button", { name: "add 1", exact: true }).click();
      await syncLV(page);
      items.push(`items-${i}`);
      await expect(await listItems(page)).toEqual(items);
    }

    // now adding new items should do nothing, as the limit is reached
    await page.getByRole("button", { name: "add 1", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-1",
      "items-2",
      "items-3",
      "items-4",
      "items-5"
    ]);

    // same when bulk inserting
    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-1",
      "items-2",
      "items-3",
      "items-4",
      "items-5"
    ]);
  });

  test("does nothing if prepending and negative limit is reached", async ({ page }) => {
    await page.goto("/stream/limit");
    await syncLV(page);

    await page.locator("input[name='at']").fill("0");
    await page.locator("input[name='limit']").fill("-5");
    await page.getByRole("button", { name: "recreate stream" }).click();
    await syncLV(page);

    await page.getByRole("button", { name: "clear" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([]);

    const items = [];
    for (let i = 1; i <= 5; i++) {
      await page.getByRole("button", { name: "add 1", exact: true }).click();
      await syncLV(page);
      items.unshift(`items-${i}`);
      await expect(await listItems(page)).toEqual(items);
    }

    // now adding new items should do nothing, as the limit is reached
    await page.getByRole("button", { name: "add 1", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-5",
      "items-4",
      "items-3",
      "items-2",
      "items-1"
    ]);

    // same when bulk inserting
    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      "items-5",
      "items-4",
      "items-3",
      "items-2",
      "items-1"
    ]);
  });

  test("arbitrary index", async ({ page }) => {
    await page.goto("/stream/limit");
    await syncLV(page);

    await page.locator("input[name='at']").fill("1");
    await page.locator("input[name='limit']").fill("5");
    await page.getByRole("button", { name: "recreate stream" }).click();
    await syncLV(page);

    // we tried to insert 10 items
    await expect(await listItems(page)).toEqual([
      "items-1",
      "items-10",
      "items-9",
      "items-8",
      "items-7"
    ]);

    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);
    await expect(await listItems(page)).toEqual([
      "items-1",
      "items-20",
      "items-19",
      "items-18",
      "items-17"
    ]);

    await page.locator("input[name='at']").fill("1");
    await page.locator("input[name='limit']").fill("-5");
    await page.getByRole("button", { name: "recreate stream" }).click();
    await syncLV(page);

    // we tried to insert 10 items
    await expect(await listItems(page)).toEqual([
      "items-10",
      "items-5",
      "items-4",
      "items-3",
      "items-2"
    ]);

    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);
    await expect(await listItems(page)).toEqual([
      "items-20",
      "items-5",
      "items-4",
      "items-3",
      "items-2"
    ]);
  });
});

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

// helper function used below
const listItems = async (page) => page.locator("ul > li").evaluateAll(list => list.map(el => ({ id: el.id, text: el.innerText })));

test.describe("Issue #2994", () => {
  test("can filter and reset a stream", async ({ page }) => {
    await page.goto("/stream/reset");
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-a", text: "A" },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);

    await page.getByRole("button", { name: "Filter" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);

    await page.getByRole("button", { name: "Reset" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-a", text: "A" },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);
  });

  test("can reorder stream", async ({ page }) => {
    await page.goto("/stream/reset");
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-a", text: "A" },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);

    await page.getByRole("button", { name: "Reorder" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-b", text: "B" },
      { id: "items-a", text: "A" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);
  });

  test("can filter and then prepend / append stream", async ({ page }) => {
    await page.goto("/stream/reset");
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-a", text: "A" },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);

    await page.getByRole("button", { name: "Filter" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);

    await page.getByRole("button", { name: "Prepend", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: expect.stringMatching(/items-a-.*/), text: expect.any(String) },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);

    await page.getByRole("button", { name: "Reset" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-a", text: "A" },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);

    await page.getByRole("button", { name: "Append", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-a", text: "A" },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" },
      { id: expect.stringMatching(/items-a-.*/), text: expect.any(String) }
    ]);
  });
});

test.describe("Issue #2982", () => {
  test("can reorder a stream with LiveComponents as direct stream children", async ({ page }) => {
    await page.goto("/stream/reset-lc");
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-a", text: "A" },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);

    await page.getByRole("button", { name: "Reorder" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-e", text: "E" },
      { id: "items-a", text: "A" },
      { id: "items-f", text: "F" },
      { id: "items-g", text: "G" },
    ]);
  });
});

test.describe("Issue #3023", () => {
  test("can bulk insert items at a specific index", async ({ page }) => {
    await page.goto("/stream/reset");
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-a", text: "A" },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);

    await page.getByRole("button", { name: "Bulk insert" }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-a", text: "A" },
      { id: "items-e", text: "E" },
      { id: "items-f", text: "F" },
      { id: "items-g", text: "G" },
      { id: "items-b", text: "B" },
      { id: "items-c", text: "C" },
      { id: "items-d", text: "D" }
    ]);
  });
});

test.describe("stream limit - issue #2686", () => {
  test("limit is enforced on mount, but not dead render", async ({ page, request }) => {
    const html = await (request.get("/stream/limit").then(r => r.text()));
    for (let i = 1; i <= 10; i++) {
      await expect(html).toContain(`id="items-${i}"`);
    }

    await page.goto("/stream/limit");
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-6", text: "6" },
      { id: "items-7", text: "7" },
      { id: "items-8", text: "8" },
      { id: "items-9", text: "9" },
      { id: "items-10", text: "10" }
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
      { id: "items-7", text: "7" },
      { id: "items-8", text: "8" },
      { id: "items-9", text: "9" },
      { id: "items-10", text: "10" },
      { id: "items-11", text: "11" }
    ]);
    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-17", text: "17" },
      { id: "items-18", text: "18" },
      { id: "items-19", text: "19" },
      { id: "items-20", text: "20" },
      { id: "items-21", text: "21" }
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
      { id: "items-10", text: "10" },
      { id: "items-9", text: "9" },
      { id: "items-8", text: "8" },
      { id: "items-7", text: "7" },
      { id: "items-6", text: "6" }
    ]);

    await page.getByRole("button", { name: "add 1", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-11", text: "11" },
      { id: "items-10", text: "10" },
      { id: "items-9", text: "9" },
      { id: "items-8", text: "8" },
      { id: "items-7", text: "7" }
    ]);

    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-21", text: "21" },
      { id: "items-20", text: "20" },
      { id: "items-19", text: "19" },
      { id: "items-18", text: "18" },
      { id: "items-17", text: "17" }
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
      items.push({ id: `items-${i}`, text: i.toString() });
      await expect(await listItems(page)).toEqual(items);
    }

    // now adding new items should do nothing, as the limit is reached
    await page.getByRole("button", { name: "add 1", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-1", text: "1" },
      { id: "items-2", text: "2" },
      { id: "items-3", text: "3" },
      { id: "items-4", text: "4" },
      { id: "items-5", text: "5" }
    ]);

    // same when bulk inserting
    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-1", text: "1" },
      { id: "items-2", text: "2" },
      { id: "items-3", text: "3" },
      { id: "items-4", text: "4" },
      { id: "items-5", text: "5" }
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
      items.unshift({ id: `items-${i}`, text: i.toString() });
      await expect(await listItems(page)).toEqual(items);
    }

    // now adding new items should do nothing, as the limit is reached
    await page.getByRole("button", { name: "add 1", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-5", text: "5" },
      { id: "items-4", text: "4" },
      { id: "items-3", text: "3" },
      { id: "items-2", text: "2" },
      { id: "items-1", text: "1" }
    ]);

    // same when bulk inserting
    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);

    await expect(await listItems(page)).toEqual([
      { id: "items-5", text: "5" },
      { id: "items-4", text: "4" },
      { id: "items-3", text: "3" },
      { id: "items-2", text: "2" },
      { id: "items-1", text: "1" }
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
      { id: "items-1", text: "1" },
      { id: "items-10", text: "10" },
      { id: "items-9", text: "9" },
      { id: "items-8", text: "8" },
      { id: "items-7", text: "7" }
    ]);

    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);
    await expect(await listItems(page)).toEqual([
      { id: "items-1", text: "1" },
      { id: "items-20", text: "20" },
      { id: "items-19", text: "19" },
      { id: "items-18", text: "18" },
      { id: "items-17", text: "17" }
    ]);

    await page.locator("input[name='at']").fill("1");
    await page.locator("input[name='limit']").fill("-5");
    await page.getByRole("button", { name: "recreate stream" }).click();
    await syncLV(page);

    // we tried to insert 10 items
    await expect(await listItems(page)).toEqual([
      { id: "items-10", text: "10" },
      { id: "items-5", text: "5" },
      { id: "items-4", text: "4" },
      { id: "items-3", text: "3" },
      { id: "items-2", text: "2" }
    ]);

    await page.getByRole("button", { name: "add 10", exact: true }).click();
    await syncLV(page);
    await expect(await listItems(page)).toEqual([
      { id: "items-20", text: "20" },
      { id: "items-5", text: "5" },
      { id: "items-4", text: "4" },
      { id: "items-3", text: "3" },
      { id: "items-2", text: "2" }
    ]);
  });
});

test("any stream insert for elements already in the DOM does not reorder", async ({ page }) => {
  await page.goto("/stream/reset");
  await syncLV(page);

  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: "A" },
    { id: "items-b", text: "B" },
    { id: "items-c", text: "C" },
    { id: "items-d", text: "D" }
  ]);

  await page.getByRole("button", { name: "Prepend C" }).click();
  await syncLV(page);
  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: "A" },
    { id: "items-b", text: "B" },
    { id: "items-c", text: "C" },
    { id: "items-d", text: "D" }
  ]);

  await page.getByRole("button", { name: "Append C" }).click();
  await syncLV(page);
  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: "A" },
    { id: "items-b", text: "B" },
    { id: "items-c", text: "C" },
    { id: "items-d", text: "D" }
  ]);

  await page.getByRole("button", { name: "Insert C at 1" }).click();
  await syncLV(page);
  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: "A" },
    { id: "items-b", text: "B" },
    { id: "items-c", text: "C" },
    { id: "items-d", text: "D" }
  ]);

  await page.getByRole("button", { name: "Insert at 1", exact: true }).click();
  await syncLV(page);
  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: "A" },
    { id: expect.stringMatching(/items-a-.*/), text: expect.any(String) },
    { id: "items-b", text: "B" },
    { id: "items-c", text: "C" },
    { id: "items-d", text: "D" }
  ]);

  await page.getByRole("button", { name: "Reset" }).click();
  await syncLV(page);
  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: "A" },
    { id: "items-b", text: "B" },
    { id: "items-c", text: "C" },
    { id: "items-d", text: "D" }
  ]);

  await page.getByRole("button", { name: "Delete C and insert at 1" }).click();
  await syncLV(page);
  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: "A" },
    { id: "items-c", text: "C" },
    { id: "items-b", text: "B" },
    { id: "items-d", text: "D" }
  ]);
});

test("stream nested in a LiveComponent is properly restored on reset", async ({ page }) => {
  await page.goto("/stream/nested-component-reset");
  await syncLV(page);

  const childItems = async (page, id) => page.locator(`#${id} div[phx-update=stream] > *`).evaluateAll(div => div.map(el => ({ id: el.id, text: el.innerText })));

  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: expect.stringMatching(/A/) },
    { id: "items-b", text: expect.stringMatching(/B/) },
    { id: "items-c", text: expect.stringMatching(/C/) },
    { id: "items-d", text: expect.stringMatching(/D/) }
  ]);

  for (let id of ["a", "b", "c", "d"]) {
    await expect(await childItems(page, `items-${id}`)).toEqual([
      { id: `nested-items-${id}-a`, text: "N-A" },
      { id: `nested-items-${id}-b`, text: "N-B" },
      { id: `nested-items-${id}-c`, text: "N-C" },
      { id: `nested-items-${id}-d`, text: "N-D" },
    ])
  }

  // now reorder the nested stream of items-a
  await page.locator("#items-a button").click();
  await syncLV(page);

  await expect(await childItems(page, "items-a")).toEqual([
    { id: "nested-items-a-e", text: "N-E" },
    { id: "nested-items-a-a", text: "N-A" },
    { id: "nested-items-a-f", text: "N-F" },
    { id: "nested-items-a-g", text: "N-G" },
  ]);
  // unchanged
  for (let id of ["b", "c", "d"]) {
    await expect(await childItems(page, `items-${id}`)).toEqual([
      { id: `nested-items-${id}-a`, text: "N-A" },
      { id: `nested-items-${id}-b`, text: "N-B" },
      { id: `nested-items-${id}-c`, text: "N-C" },
      { id: `nested-items-${id}-d`, text: "N-D" },
    ])
  }

  // now reorder the parent stream
  await page.locator("#parent-reorder").click();
  await syncLV(page);
  await expect(await listItems(page)).toEqual([
    { id: "items-e", text: expect.stringMatching(/E/) },
    { id: "items-a", text: expect.stringMatching(/A/) },
    { id: "items-f", text: expect.stringMatching(/F/) },
    { id: "items-g", text: expect.stringMatching(/G/) },
  ]);

  // the new children's stream items have the correct order
  for (let id of ["e", "f", "g"]) {
    await expect(await childItems(page, `items-${id}`)).toEqual([
      { id: `nested-items-${id}-a`, text: "N-A" },
      { id: `nested-items-${id}-b`, text: "N-B" },
      { id: `nested-items-${id}-c`, text: "N-C" },
      { id: `nested-items-${id}-d`, text: "N-D" },
    ])
  }

  // Item A has the same children as before, still reordered
  await expect(await childItems(page, "items-a")).toEqual([
    { id: "nested-items-a-e", text: "N-E" },
    { id: "nested-items-a-a", text: "N-A" },
    { id: "nested-items-a-f", text: "N-F" },
    { id: "nested-items-a-g", text: "N-G" },
  ]);
});

test("phx-remove is handled correctly when restoring nodes", async ({ page }) => {
  await page.goto("/stream/reset?phx-remove");
  await syncLV(page);

  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: "A" },
    { id: "items-b", text: "B" },
    { id: "items-c", text: "C" },
    { id: "items-d", text: "D" }
  ]);

  await page.getByRole("button", { name: "Filter" }).click();
  await syncLV(page);

  await expect(await listItems(page)).toEqual([
    { id: "items-b", text: "B" },
    { id: "items-c", text: "C" },
    { id: "items-d", text: "D" }
  ]);

  await page.getByRole("button", { name: "Reset" }).click();
  await syncLV(page);

  await expect(await listItems(page)).toEqual([
    { id: "items-a", text: "A" },
    { id: "items-b", text: "B" },
    { id: "items-c", text: "C" },
    { id: "items-d", text: "D" }
  ]);
});

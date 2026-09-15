import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// A hook in the parent LiveView locks an element that contains a nested LiveView.
// While the lock is active, the parent is patched (which creates the private
// clone of the locked element) and a LiveComponent inside the nested LiveView
// receives a component-only diff. That diff must not be redirected into the
// parent's clone, as the unlock morph never descends into nested LiveViews.
const runLocked = async (page, variant) => {
  await page.goto(`/issues/4444?variant=${variant}`);
  await syncLV(page);
  await expect(page.locator("#child-lv")).toHaveClass(/phx-connected/);
  await expect(page.locator("#child-component-label")).toHaveText("child 0");

  await page.locator("#run").click();
  await expect(page.locator("#locked")).toHaveAttribute(
    "data-phx-ref-lock",
    "1",
  );
  await expect(page.locator("#locked")).not.toHaveAttribute(
    "data-phx-ref-lock",
  );
  await syncLV(page);
};

test("nested LiveView component patch is not lost when locked ancestor is skipped", async ({
  page,
}) => {
  await runLocked(page, "skip");

  await expect(page.locator("#outside-count")).toHaveText("1");
  await expect(page.locator("#child-component-label")).toHaveText("child 1");
});

test("nested LiveView component patch is not lost when locked ancestor is patched", async ({
  page,
}) => {
  await runLocked(page, "root");

  await expect(page.locator("#outside-count")).toHaveText("1");
  await expect(page.locator("#child-component-label")).toHaveText("child 1");
});

test("nested LiveView component patch does not target parent component with same cid", async ({
  page,
}) => {
  await runLocked(page, "collision");

  await expect(page.locator("#child-lv #child-component-label")).toHaveText(
    "child 1",
  );
  await expect(
    page.locator("#locked > #parent-component #parent-component-label"),
  ).toHaveText("parent 0");

  await page.locator("#update-parent").click();
  await expect(page.locator("#parent-component-label")).toHaveText("parent 1");
});

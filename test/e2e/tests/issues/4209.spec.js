import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

test("skipped locked ancestor keeps nested component patches private until unlock", async ({
  page,
}) => {
  // This reproduces an issue where a locked element itself was skipped (data-phx-skip).
  // We have a hook on the skip element, which sends an event to a child LiveView.
  // Because the child LiveView is deliberately slow to process that event, the lock
  // stays active for a while. During that time, the child also sends an update to
  // the parent, which bumps a counter both outside and inside the locked panel.
  // The important regression assertion is that the child label remains "child 0"
  // while #locked-panel is still locked:
  // the "child 1" patch must be written to the private locked clone and only become
  // visible after the lock is acked.
  await page.goto("/issues/4209");
  await syncLV(page);

  await expect(page.locator("#outside-count")).toHaveText("0");
  await expect(page.locator("#locked-child-label")).toHaveText("child 0");

  await page.getByRole("button", { name: "Start locked update" }).click();

  await expect(page.locator("#locked-panel")).toHaveAttribute(
    "data-phx-ref-lock",
    "0",
  );

  await expect(page.locator("#outside-count")).toHaveText("1");

  await page.waitForTimeout(150);
  await expect(page.locator("#locked-panel")).toHaveAttribute(
    "data-phx-ref-lock",
    "0",
  );
  // This assertion would fail previously, because the locked panel was skipped
  // with the magic ID optimization.
  await expect(page.locator("#locked-child-label")).toHaveText("child 0");

  await syncLV(page);

  await expect(page.locator("#locked-child-label")).toHaveText("child 1");
  await expect(page.locator("#locked-panel")).not.toHaveAttribute(
    "data-phx-ref-lock",
    "0",
  );
});

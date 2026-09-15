import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/4442
for (const operation of ["reset", "insert"]) {
  test(`portal added to an existing stream item with ${operation} is teleported with its content`, async ({
    page,
  }) => {
    await page.goto("/issues/4442");
    await syncLV(page);

    const teleported = page.locator("#portal-target #preview-content-1");
    await expect(teleported).toHaveCount(0);

    await page.locator(`#${operation}`).click();
    await syncLV(page);

    await expect(teleported).toHaveText("Ticket details");
    // the portal template in the DOM must keep its content after teleporting
    expect(
      await page
        .locator("#preview-1")
        .evaluate(
          (el) =>
            el.content.querySelector("#preview-content-1")?.textContent ?? null,
        ),
    ).toBe("Ticket details");
  });
}

const { expect } = require("@playwright/test");

// a helper function to wait until the LV has no pending events
const syncLV = async (page) => {
  const promises = [
    expect(page.locator(".phx-connected").first()).toBeVisible(),
    expect(page.locator(".phx-change-loading")).toHaveCount(0),
    expect(page.locator(".phx-click-loading")).toHaveCount(0),
    expect(page.locator(".phx-submit-loading")).toHaveCount(0),
  ];
  return Promise.all(promises);
};

module.exports = { syncLV };

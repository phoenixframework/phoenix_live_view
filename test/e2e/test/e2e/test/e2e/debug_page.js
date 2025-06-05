import { chromium } from "playwright";

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    await page.goto("http://localhost:4004/component-transition");

    console.log("Page title:", await page.title());
    console.log("Page URL:", page.url());

    const pageContent = await page.content();
    console.log("Page content length:", pageContent.length);

    // Look for our specific elements
    const containerExists = await page.locator(".container").count();
    console.log("Container elements found:", containerExists);

    const singleRootExists = await page
      .locator("#single-root-component")
      .count();
    console.log("Single root component found:", singleRootExists);

    const multiRootExists = await page.locator("#multi-root-component").count();
    console.log("Multi root component found:", multiRootExists);

    const buttonExists = await page.locator("button").count();
    console.log("Button elements found:", buttonExists);

    // Get all element IDs on the page
    const allIds = await page.evaluate(() => {
      return Array.from(document.querySelectorAll("[id]")).map((el) => el.id);
    });
    console.log("All element IDs on page:", allIds);

    // Get the body content
    const bodyText = await page.locator("body").textContent();
    console.log("Body text content:", bodyText);
  } catch (error) {
    console.error("Error:", error.message);
  } finally {
    await browser.close();
  }
})();

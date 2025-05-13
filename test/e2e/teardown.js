import { request } from "@playwright/test";

export default async () => {
  try {
    const context = await request.newContext({
      baseURL: "http://localhost:4004",
    });
    // gracefully stops the e2e script to export coverage
    await context.post("/halt");
  } catch {
    // we expect the request to fail because the request
    // actually stops the server
    return;
  }
};

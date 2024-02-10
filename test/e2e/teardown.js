const request = require("@playwright/test").request;

module.exports = async () => {
  const context = await request.newContext({ baseURL: "http://localhost:4000" });
  await context.post("/export-coverage")
};

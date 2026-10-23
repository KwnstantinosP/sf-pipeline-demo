const { defineConfig } = require("@playwright/test");

// Browser journeys against a deployed org. The global setup logs in through the sf CLI,
// so no password is needed and the session link never appears in the report.
module.exports = defineConfig({
  testDir: "tests/ui",
  globalSetup: require.resolve("./tests/ui/global-setup.js"),
  timeout: 120000,
  expect: { timeout: 30000 },
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    storageState: ".auth/state.json",
    viewport: { width: 1440, height: 900 },
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    // No traces: they would record the login session in a downloadable file.
    trace: "off"
  }
});

const { chromium } = require("@playwright/test");
const { execSync } = require("child_process");
const fs = require("fs");

// Opens the org once through a CLI-issued session, saves the browser cookies for the tests
// and passes the Lightning address on as SF_LIGHTNING_URL.
module.exports = async () => {
  const output = execSync("sf org open --url-only --target-org target --json", {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"]
  });
  const { url } = JSON.parse(output).result;

  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto(url);
  await page.waitForURL(/lightning\.force\.com\/lightning\//, {
    timeout: 90000
  });

  fs.mkdirSync(".auth", { recursive: true });
  await page.context().storageState({ path: ".auth/state.json" });
  process.env.SF_LIGHTNING_URL = new URL(page.url()).origin;
  await browser.close();
};

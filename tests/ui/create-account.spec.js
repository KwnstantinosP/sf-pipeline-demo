const { test, expect } = require("@playwright/test");
const { execSync } = require("child_process");

const PREFIX = "REGTEST-UI-";

// Removes every Account this file created, even if a test failed half-way.
test.afterAll(() => {
  execSync("sf apex run --target-org target", {
    input: `delete [SELECT Id FROM Account WHERE Name LIKE '${PREFIX}%'];`,
    stdio: ["pipe", "ignore", "ignore"]
  });
});

test("a user can create an Account from the New Account form", async ({
  page
}) => {
  const name = `${PREFIX}${Date.now()}`;

  await page.goto(`${process.env.SF_LIGHTNING_URL}/lightning/o/Account/new`);
  const form = page.getByRole("dialog");
  await form.getByLabel(/Account Name/).fill(name);
  await form.getByRole("button", { name: "Save", exact: true }).click();

  await expect(page).toHaveURL(/\/lightning\/r\/Account\/001\w+\/view/);
  await expect(page.getByText(name).first()).toBeVisible();
});

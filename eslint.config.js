const lwcConfig = require("@salesforce/eslint-config-lwc");

module.exports = [
  { ignores: ["node_modules/**", ".sf/**", ".sfdx/**", "delta/**"] },
  ...lwcConfig.configs.recommended,
  {
    files: ["**/lwc/**/*.test.js"],
    rules: { "@lwc/lwc/no-unexpected-wire-adapter-usages": "off" }
  }
];

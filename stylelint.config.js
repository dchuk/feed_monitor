module.exports = {
  extends: [ "stylelint-config-standard" ],
  ignoreFiles: [
    "node_modules/**",
    "app/assets/builds/**"
  ],
  rules: {
    "at-rule-no-unknown": null,
    "import-notation": null,
    "selector-class-pattern": null
  }
};

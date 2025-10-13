import js from "@eslint/js";

export default [
  {
    ignores: [
      "node_modules/**",
      "vendor/assets/**",
      "app/assets/builds/**"
    ]
  },
  js.configs.recommended,
  {
    files: [ "app/assets/javascripts/**/*.js" ],
    languageOptions: {
      sourceType: "module",
      globals: {
        window: "readonly",
        document: "readonly",
        CustomEvent: "readonly"
      }
    },
    rules: {
      "no-unused-vars": [ "error", { args: "none", ignoreRestSiblings: true } ],
      "no-console": [ "warn", { allow: [ "warn", "error" ] } ]
    }
  }
];

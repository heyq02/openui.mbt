import { defineConfig } from "@rsbuild/core";

// Project Pages serves the site at https://<user>.github.io/openui.mbt/
const base = "/openui.mbt/";

export default defineConfig({
  server: {
    base,
  },
  output: {
    assetPrefix: base,
  },
  html: {
    template: "./index.html",
    title: "OpenUI Lang",
  },
});

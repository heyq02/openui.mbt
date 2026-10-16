import { defineConfig } from "@rsbuild/core";
import { pluginReact } from "@rsbuild/plugin-react";

// Project Pages serves the site at https://<user>.github.io/openui.mbt/
const base = "/openui.mbt/";

export default defineConfig({
  plugins: [pluginReact()],
  server: {
    base,
  },
  tools: {
    rspack: {
      module: {
        rules: [
          {
            test: /\.openui$/,
            type: "asset/source",
          },
        ],
      },
    },
  },
  output: {
    assetPrefix: base,
  },
  html: {
    template: "./index.html",
    title: "OpenUI Lang",
  },
});

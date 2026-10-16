import { defineConfig } from "@rsbuild/core";
import { pluginReact } from "@rsbuild/plugin-react";

// Same demo source as web/. Two output directories differ only by which
// lang-core dist is installed: official, or official after `oui.mbt patch`.
export default defineConfig({
  plugins: [pluginReact()],
  source: {
    entry: {
      bench: "./src/bench.jsx",
    },
  },
  server: {
    base: "/",
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
    assetPrefix: "/",
    sourceMap: false,
    distPath: {
      root: process.env.BENCH_DIST ?? "dist-bench",
    },
  },
  html: {
    template: "./index.html",
    title: "OpenUI benchmark",
  },
});

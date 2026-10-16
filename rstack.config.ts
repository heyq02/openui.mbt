// Configuration guide: https://rstack.rs/config
import { define } from 'rstack';
import { rstack } from '@heyq02/rstack-config/rstack';
import { resolveRsdoctorPlugin } from '@heyq02/rstack-config/rslib';

// MoonBit stays on `moon`. This preset only covers repo hygiene.
define.extends([
  rstack({
    lib: false,
    lint: false,
    test: false,
    fmt: {
      singleQuote: true,
      sortPackageJson: true,
      ignorePatterns: [
        '.github/**',
        '.cursor/**',
        'docs/**',
        'web/**',
        'parser/**',
        'ffi/**',
        '**/*.md',
        '**/*.mbt',
        'pnpm-lock.yaml',
        '_build/**',
        '.mooncakes/**',
        'js/parser.wasm.js',
      ],
    },
    staged: {
      formatAll: true,
      lintFix: false,
    },
  }),
]);

// Rsdoctor analyzes the npm package @heyq02/openui.mbt, not the demo.
const rsdoctorPlugin = resolveRsdoctorPlugin(true);

define.lib({
  lib: [{ format: 'esm', bundle: true, dts: false }],
  source: {
    entry: {
      index: './js/index.js',
      cli: './js/cli.js',
    },
  },
  output: {
    target: 'node',
  },
  ...(rsdoctorPlugin
    ? {
        tools: {
          rspack: {
            plugins: [rsdoctorPlugin],
          },
        },
      }
    : {}),
});

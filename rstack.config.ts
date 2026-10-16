import { resolveRsdoctorPlugin } from '@heyq02/rstack-config/rslib';
import { rstack } from '@heyq02/rstack-config/rstack';
// Configuration guide: https://rstack.rs/config
import { define } from 'rstack';

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
        'web/**',
        'src/**',
        '**/*.md',
        '**/*.mbt',
        'pnpm-lock.yaml',
        '_build/**',
        '.mooncakes/**',
        'npm/parser.wasm.js',
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
      index: './npm/index.js',
      cli: './npm/cli.js',
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

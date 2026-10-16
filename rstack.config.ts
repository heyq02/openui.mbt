// Configuration guide: https://rstack.rs/config
import { define } from 'rstack';
import { rstack } from '@heyq02/rstack-config/rstack';

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
        'examples/**',
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

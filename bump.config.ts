import { defineConfig } from 'bumpp';

// package.json is the version bumpp reads. moon.mod and js/package.json
// must already contain that same string; bumpp then replaces it in all three.
export default defineConfig({
  files: ['package.json', 'moon.mod', 'js/package.json'],
  commit: 'chore: release v{version}',
  tag: 'v{version}',
});

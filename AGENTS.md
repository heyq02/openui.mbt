# openui

MoonBit parser for OpenUI Lang. Module `heyq02/openui`. The npm package is `@heyq02/openui.mbt`.

## Toolchain

`moon` builds and tests the parser. Node is repo hygiene and the Wasm binding: [`@heyq02/rstack-config`](https://github.com/heyq02/rstack-config) (`rs fmt`, hooks, commitlint), [`automd`](https://automd.unjs.io) for the license block in `README.md`, and [`bumpp`](https://github.com/antfu-collective/bumpp). `package.json` pins `pnpm@12.10.1`.

`moon.mod` `version`, root `package.json` `version`, and `npm/package.json` `version` stay the same string. `pnpm release` updates all three, commits `chore: release v{version}`, tags `v{version}`, and pushes. `pnpm release --no-push` stops after the local commit and tag.

CI installs latest `moon`. Dated CDN pins return 403.

## Layout

| Path | Role |
|------|------|
| `src/` | Lexer, parser, schema, materialize, streaming. Tests stay beside sources. |
| `src/wasm/` | Wasm-GC exports, including the streaming session. `supported_targets = "wasm-gc"`. |
| `npm/` | npm package. Embeds the release Wasm as base64. |
| `web/` | Rsbuild demo. Its own npm install. |
| `docs/schema.md` | JSON Schema contract. |
| `.github/workflows/` | `unit-test.yml`, `coverage.yml`, `commitlint.yml`, `autofix.yml`, `release.yaml`, `release-commit.yml`, `pages.yml`, `rsdoctor.yml`. |
| `bump.config.ts` | Files bumpp rewrites: `package.json`, `moon.mod`, `npm/package.json`. |

Targets: `native`, `wasm`, `wasm-gc`, `js`. Native CI fails if the suite shrinks below `NATIVE_TEST_BASELINE` in `unit-test.yml`. Parser coverage floor is `COVERAGE_FLOOR_PERCENT` in `coverage.yml` (currently 50%). Both floors only rise.

## Commands

```bash
moon check --deny-warn --target native
moon fmt
moon test --deny-warn --target native
moon test --deny-warn --target wasm
moon test --deny-warn --target wasm-gc
moon test --deny-warn --target js
pnpm run build:parser
pnpm test
pnpm run format
```

`pnpm test` is native only. White-box tests live in `src/*_wbtest.mbt`.

`pnpm run build:rsdoctor` bundles `@heyq02/openui.mbt` with `rs lib`. With `RSDOCTOR=true` and `CI` set, the report is `dist/.rsdoctor/rsdoctor-data.json`. The demo in `web/` is not part of that report.

## Release

`release.yaml` runs on a `v*` tag. The tag must match `moon.mod`, the root `package.json`, and `npm/package.json`. It publishes the MoonBit module to mooncakes.io, then `@heyq02/openui.mbt` to npm with provenance.

`release-commit.yml` uses `sxzz/workflows` `release-commit.yml` on every push and pull request. It builds the Wasm package and publishes `./npm` with `pkg-pr-new`. That preview is not an npm release. The parser API is `@heyq02/openui.mbt/parser`. `oui.mbt patch` rewrites installed `@openuidev/lang-core@1.0.1` `dist/index.mjs` and `dist/index.cjs`. `web/` depends on the official package and runs that command after install. Pages runs `node npm/build.mjs` before `npm ci`.

`.moonignore` keeps `web/`, `npm/`, and the repo-hygiene files out of the mooncakes archive. The npm tarball is only the `npm/` `files` list, including the generated `parser.wasm.js`.

`MOONCAKES_TOKEN` is the base64 of `~/.moon/credentials.json` and belongs only on the release job. npm uses a Trusted Publisher for workflow `Release` on `heyq02/openui.mbt`. Do not cache `~/.moon`. Push and pull-request jobs stay offline.

Before pushing parser changes, run `moon fmt` and `moon test --deny-warn` on native, plus wasm-gc when `src/wasm/` changes.

# heyq02/openui

<p>
  <a href="https://mooncakes.io/docs/heyq02/openui/"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fmooncakes.io%2Fapi-new%2Fv0%2Fmanifest%2Fheyq02%2Fopenui&query=%24.latest_version&label=mooncake&style=flat-square&colorA=564341&colorB=EDED91" alt="mooncake" /></a>
  <a href="https://www.npmjs.com/package/@heyq02/openui.mbt"><img src="https://img.shields.io/npm/v/@heyq02/openui.mbt?label=npm&style=flat-square&colorA=564341&colorB=EDED91" alt="npm" /></a>
  <a href="https://github.com/heyq02/openui.mbt/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-EDED91?style=flat-square&colorA=564341" alt="license" /></a>
</p>

MoonBit 实现的 [OpenUI Lang](https://github.com/thesysdev/openui) 解析器。MoonBit 模块发布到 mooncakes，Wasm-GC 绑定发布到 npm。

## MoonBit

```bash
moon add heyq02/openui
```

模块名 `heyq02/openui`。解析、Schema 编译和物化在 `parser` 包，Wasm 导出在 `ffi` 包。Schema 约定见 [`docs/schema.md`](docs/schema.md)。

## npm

```bash
npm install @heyq02/openui.mbt
```

```js
import { parseProgram } from "@heyq02/openui.mbt/parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

把已安装的 OpenUI 解析器换成这个包：

```bash
npm install @heyq02/openui.mbt @openuidev/lang-core
npx oui.mbt patch
```

包入口说明见 [`js/README.md`](js/README.md)。

## 发布

`package.json`、`moon.mod` 和 `js/package.json` 的版本保持同一字符串。`pnpm release` 改这三处，提交 `chore: release v{version}`，打标签 `v{version}` 并推送。标签触发 [`.github/workflows/release.yaml`](.github/workflows/release.yaml)：`moon package` 后发布到 mooncakes.io，再把 Wasm 包发布到 npm。

每次 push 和 pull request 还会触发 [`.github/workflows/release-commit.yml`](.github/workflows/release-commit.yml)，把 `@heyq02/openui.mbt` 发到 [pkg.pr.new](https://pkg.pr.new)。这不是正式版本。演示站安装官方 `@openuidev/lang-core`，再运行 `oui.mbt patch`。

仓库需要两个发布凭据：

- `MOONCAKES_TOKEN`：`~/.moon/credentials.json` 的 base64，只放在 Release 作业。
- npm Trusted Publisher：仓库 `heyq02/openui.mbt`，工作流 `Release`，包 `@heyq02/openui.mbt`。

<!-- automd:contributors license=MIT author="heyq02" github="heyq02/openui.mbt" -->

Published under the [MIT](https://github.com/heyq02/openui.mbt/blob/main/LICENSE) license.
Made by [@heyq02](https://github.com/heyq02) and [community](https://github.com/heyq02/openui.mbt/graphs/contributors) 💛
<br><br>
<a href="https://github.com/heyq02/openui.mbt/graphs/contributors">
<img src="https://contrib.rocks/image?repo=heyq02/openui.mbt" />
</a>

<!-- /automd -->

<!-- automd:with-automd -->

---

_🤖 auto updated with [automd](https://automd.unjs.io)_

<!-- /automd -->

# heyq02/openui

<p>
  <a href="https://mooncakes.io/docs/heyq02/openui/"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fmooncakes.io%2Fapi-new%2Fv0%2Fmanifest%2Fheyq02%2Fopenui&query=%24.latest_version&label=mooncake&style=flat-square&colorA=564341&colorB=EDED91" alt="mooncake" /></a>
  <a href="https://www.npmjs.com/package/@heyq02/openui.mbt"><img src="https://img.shields.io/npm/v/@heyq02/openui.mbt?label=npm&style=flat-square&colorA=564341&colorB=EDED91" alt="npm" /></a>
  <a href="https://github.com/heyq02/openui.mbt/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-EDED91?style=flat-square&colorA=564341" alt="license" /></a>
  <a href="https://github.com/heyq02/openui.mbt/actions/workflows/compatibility.yml"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fheyq02%2Fopenui.mbt%2Fmain%2Fdocs%2Fcompatibility.json" alt="OpenUI compatibility" /></a>
</p>

MoonBit 实现的 [OpenUI Lang](https://github.com/thesysdev/openui) 解析器。MoonBit 模块发布到 mooncakes，Wasm-GC 绑定发布到 npm。

## MoonBit

```bash
moon add heyq02/openui
```

模块名 `heyq02/openui`。解析、Schema 编译和物化在 `src`，Wasm 导出在 `src/wasm`。Schema 约定见 [`docs/schema.md`](docs/schema.md)。

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

包入口说明见 [`npm/README.md`](npm/README.md)。

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

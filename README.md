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

## Benchmark

A 是 `oui.mbt patch` 之后的 `@openuidev/lang-core@1.0.1`，B 是同一个包 patch 之前。`createParser().parse` 在 Wasm 里一次完成解析和物化。流式解析仍把语句交给官方分类和物化。Renderer 仍是官方代码。

```bash
npm ci --prefix web
pnpm run benchmark
```

体积比较官方 `dist/index.mjs` 和 patch 后的同一文件，再加上 A 要带上的 Wasm。解析用同一份 Schema，跑 `web/signup.openui`、50 个字段和 400 个字段，取复用 parser 后 `parse` 的中位数。页面用同一份 `web/src/bench.jsx` 打两个生产包，Headless Chrome 从导航计到注册表单画出后的下一帧，每个包 7 次。过程和完整数字见 [`docs/benchmark.md`](docs/benchmark.md)。

2026-10-16 本机的一次结果。结构指纹一致：根组件、语句数、错误数和 incomplete 相同。

- 体积：`index.mjs` 从 180172 字节增到 181392 字节。demo 生产包原始字节多 87990，逐文件 gzip 之和多 38038。多出来的是 Wasm。
- 解析：复用 parser 的 `parse` 中位数，400 个字段 0.7559 ms 对 0.6315 ms，A 大约快 16%。50 个字段 0.1022 ms 对 0.0896 ms。注册表单 0.0286 ms 对 0.0365 ms，短文档仍更慢。
- 页面：热加载后 6 次都在 165–188 ms。这份表单的解析差落在页面时间里看不见。

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

# heyq02/openui

<p>
  <a href="https://mooncakes.io/docs/heyq02/openui/"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fmooncakes.io%2Fapi-new%2Fv0%2Fmanifest%2Fheyq02%2Fopenui&query=%24.latest_version&label=mooncake&style=flat-square&colorA=564341&colorB=EDED91" alt="mooncake" /></a>
  <a href="https://www.npmjs.com/package/@heyq02/openui.mbt"><img src="https://img.shields.io/npm/v/@heyq02/openui.mbt?label=npm&style=flat-square&colorA=564341&colorB=EDED91" alt="npm" /></a>
  <a href="https://github.com/heyq02/openui.mbt/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-EDED91?style=flat-square&colorA=564341" alt="license" /></a>
  <a href="https://github.com/heyq02/openui.mbt/actions/workflows/compatibility.yml"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fheyq02%2Fopenui.mbt%2Fmain%2Fcompatibility.json" alt="OpenUI compatibility" /></a>
</p>

MoonBit 写的 [OpenUI Lang](https://github.com/thesysdev/openui) 解析器，编译成 Wasm-GC 后从 npm 使用。

`oui.mbt patch` 把已安装的 `@openuidev/lang-core@1.0.1` 里 `createParser().parse` 换成 Wasm 解析和物化。流式解析和 Renderer 仍是官方代码。

## 安装

```bash
npm install @heyq02/openui.mbt
```

```js
import { parseProgram } from "@heyq02/openui.mbt/parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

换成 OpenUI 的解析器：

```bash
npm install @heyq02/openui.mbt @openuidev/lang-core@1.0.1
npx oui.mbt patch
```

版本不是 1.0.1，或这份 1.0.1 的解析调用点和补丁对不上时，命令退出，已安装的文件保持原样。其余入口见 [`npm/README.md`](npm/README.md)。

## Benchmark

2026-10-16 本机一次结果。A 是 `oui.mbt patch` 之后的 `@openuidev/lang-core@1.0.1`，B 是同一个包 patch 之前。两边的结构指纹一致：注册表单 8 条语句、0 个错误，50 个字段 51 条语句，400 个字段 401 条语句。指纹只看根组件、语句数、错误数和 incomplete。

复用 parser 的 `parse` 中位数，单位毫秒：

| 文档 | B | A |
| --- | ---: | ---: |
| 注册表单，516 字节 | 0.0286 | 0.0365 |
| 50 个字段 | 0.1022 | 0.0896 |
| 400 个字段，22085 字节 | 0.7559 | 0.6315 |

400 个字段 A 大约快 16%，50 个字段大约快 12%。注册表单仍是 B 更快。按行推送仍走官方物化，注册表单 0.1376 ms 对 0.2146 ms，50 个字段 1.9704 ms 对 2.3271 ms。页面热加载后 6 次都在 165–188 ms。

| 文件 | 原始 | gzip |
| --- | ---: | ---: |
| B `dist/index.mjs` | 180172 | 48901 |
| A `dist/index.mjs` | 181392 | 49331 |
| A `parser.wasm.js` | 93868 | 38767 |
| 其中的 Wasm 二进制 | 70334 | 28817 |

demo 生产包（html + js + css，source map 不计）：B 3713817 字节（gzip 之和 1336967），A 3801807 字节（gzip 之和 1375005）。入口 `bench.*.js` 从 31609 字节（gzip 17969）变成 125958 字节（gzip 57628）。

```bash
npm ci --prefix web
pnpm run benchmark
```

`--skip-demo` 只测体积和 Node 解析，结果写到 `.bench/report.json`。400 个字段不做流式计时。整库测试的墙钟时间不作为性能结果。

## 对照

```bash
npm ci --prefix web
pnpm run compare
```

同一份组件 Schema 上，比较官方 `@openuidev/lang-core@1.0.1` 和 patch 之后的一次性解析、流式解析。对比根节点、`incomplete`、`unresolved`、`orphaned`、语句数、错误码和 state 声明。错误文案不参与对比。

2026-10-16 这组样例上，7 条流式结果与官方结构一致。一次性解析有 6 处差异：

- 注册表单的子节点没有 `statementId`，动作参数没有 `mappedProps`
- 错误对象没有 `statementId`
- `$name` 没有进入 `stateDeclarations`
- 坏行多一条 `parse-failed`
- 未闭合输入的语句数是 2，官方是 1

先引用后定义的那条一次性解析没有差异。同一次打印：Wasm 70334 字节，gzip 28817 字节，一次性解析中位数 0.0586 ms，流式 0.2124 ms。

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

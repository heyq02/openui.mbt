# heyq02/openui

<p>
  <a href="https://mooncakes.io/docs/heyq02/openui/"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fmooncakes.io%2Fapi-new%2Fv0%2Fmanifest%2Fheyq02%2Fopenui&query=%24.latest_version&label=mooncake&style=flat-square&colorA=564341&colorB=EDED91" alt="mooncake" /></a>
  <a href="https://www.npmjs.com/package/@heyq02/openui.mbt"><img src="https://img.shields.io/npm/v/@heyq02/openui.mbt?label=npm&style=flat-square&colorA=564341&colorB=EDED91" alt="npm" /></a>
  <a href="https://github.com/heyq02/openui.mbt/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-EDED91?style=flat-square&colorA=564341" alt="license" /></a>
  <a href="https://github.com/heyq02/openui.mbt/actions/workflows/compatibility.yml"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fheyq02%2Fopenui.mbt%2Fmain%2Fcompatibility.json" alt="OpenUI compatibility" /></a>
</p>

MoonBit 实现的 [OpenUI Lang](https://github.com/thesysdev/openui) 解析器。MoonBit 模块发布到 mooncakes，Wasm-GC 绑定发布到 npm。

## MoonBit

```bash
moon add heyq02/openui
```

模块名 `heyq02/openui`。解析、Schema 编译和物化在 `src`，Wasm 导出在 `src/wasm`。

## Schema

MoonBit 从这份 JSON 建立组件定义表。它和 `@openuidev/lang-core` 的 `library.toJSONSchema()` 使用同一组字段。属性的书写顺序就是 OpenUI Lang 位置参数的顺序。

| 字段 | 含义 |
| --- | --- |
| `properties` | 组件名。有这个对象时，只有这里列出的名字是组件，顺序即组件表顺序。值通常是 `{ "$ref": "#/$defs/组件名" }`。 |
| `$defs` | 组件 schema，键是组件名。 |
| `$defs.<Name>.properties` | 该组件的参数。键的书写顺序是位置参数顺序。 |
| `$defs.<Name>.required` | 必填参数名，必须出现在 `properties` 里。 |
| `functions` | 库函数。每个值要有 `params`，`params` 的形状和组件 schema 相同。 |
| `actions` | 自定义 action。形状和 `functions` 相同。 |
| `description` | 说明，编译定义表时忽略。 |

没有 `properties` 时，`$defs` 里除 action 数据形状以外的项都是组件。这些名字固定跳过：`ActionExpression`、`OpenUrl`、`ToAssistant`，再加上 `actions` 的键。

每个参数是一个 JSON Schema 对象。类型按下面的优先级读取：

| 字段 | 定义表中的类型 |
| --- | --- |
| `$ref` | `#/$defs/` 后面的名字 |
| `enum` | 非空数组，元素按 JSON 字面量保存 |
| `const` | 单个字面量 |
| `anyOf` / `oneOf` / `allOf` | 子 schema 的并集，只取第一个出现的关键字 |
| `type` | `string`、`number`、`integer`、`boolean`、`object`、`array`、`null`。`integer` 记为 `number`。数组表示并集。 |
| 都没有 | 任意值 |

`default`、`items`、`additionalProperties` 留给后续校验，编译定义表时不改变参数顺序。缺字段和未知类型会记入 `errors`，参数位置仍然保留：未知 `type` 记 `unknown type "..."`；`required` 里的名字不在 `properties` 里记 `"<name>" is not a property`；`properties`、`required`、`$defs`、`functions`、`actions` 形状不对，函数或 action 缺少 `params`，`properties` 点名的组件不在 `$defs` 里，以及文档不是 JSON 对象或无法解析，也记入 `errors`。

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

包入口说明见 [`npm/README.md`](npm/README.md)。`createParser().parse` 在 Wasm 里一次完成解析和物化。流式解析仍把语句交给官方分类和物化。Renderer 仍是官方代码。`patch-source` 只替换语句解析，兼容性流水线走的是那条路径。

## Benchmark

A 是 `oui.mbt patch` 之后的 `@openuidev/lang-core@1.0.1`，B 是同一个包 patch 之前。

```bash
npm ci --prefix web
pnpm run benchmark
```

`--skip-demo` 只跑体积和 Node 解析。结果写到 `.bench/report.json`。体积比较官方 `dist/index.mjs` 和 patch 后的同一文件，再加上 A 要带上的 Wasm。解析用同一份 Schema，跑 `web/signup.openui`、50 个字段和 400 个字段，取复用 parser 后 `parse` 的中位数。页面用同一份 `web/src/bench.jsx` 打两个生产包，Headless Chrome 从导航计到注册表单画出后的下一帧，每个包 7 次。400 个字段不做流式计时。整库 `pnpm test` 的墙钟时间不作为性能结果。

2026-10-16 本机的一次结果。结构指纹一致：注册表单 8 条语句、0 个错误，50 个字段 51 条语句，400 个字段 401 条语句。指纹只看根组件、语句数、错误数和 incomplete。

| 文件 | 原始 | gzip |
| --- | ---: | ---: |
| B `dist/index.mjs` | 180172 | 48901 |
| A `dist/index.mjs` | 181392 | 49331 |
| A `parser.wasm.js` | 93868 | 38767 |
| 其中的 Wasm 二进制 | 70334 | 28817 |

demo 生产包（html + js + css，source map 不计，逐文件 gzip 后相加）：B 3713817 / 1336967，A 3801807 / 1375005，多 87990 / 38038。入口 `bench.*.js` 从 31609 字节（gzip 17969）变成 125958 字节（gzip 57628）。

复用 parser 的 `parse` 中位数，单位毫秒：

| 文档 | B | A |
| --- | ---: | ---: |
| 注册表单，516 字节 | 0.0286 | 0.0365 |
| 50 个字段 | 0.1022 | 0.0896 |
| 400 个字段，22085 字节 | 0.7559 | 0.6315 |

400 个字段 A 大约快 16%，50 个字段大约快 12%。注册表单仍是 B 更快。按行推送仍走官方物化：注册表单 B 0.1376、A 0.2146；50 个字段 B 1.9704、A 2.3271。页面热加载后 6 次都在 165–188 ms，这份表单的解析差落在页面时间里看不见。

## 对照

```bash
npm ci --prefix web
pnpm run compare
```

`node npm/compare.mjs` 下载官方 `@openuidev/lang-core@1.0.1`，复制一份并执行 patch，然后用同一份组件 Schema 跑一次性解析和流式解析。结构对比包含根节点、`incomplete`、`unresolved`、`orphaned`、语句数、错误码和 state 声明。错误文案不参与对比。样例覆盖注册表单用到的组件，再加上未知组件、缺少必填参数、先引用后定义、孤立语句、`$` 状态、非法行和未闭合字符串。

2026-10-16 这组样例上，7 条流式结果与官方没有结构差异。一次性解析有 6 处差异：注册表单的子节点没有 `statementId`，动作参数没有 `mappedProps`；错误对象没有 `statementId`；`$name` 没有进入 `stateDeclarations`；坏行多一条 `parse-failed`；未闭合输入的语句数是 2，官方是 1。先引用后定义那条一次性解析没有差异。同一次打印：Wasm 70334 字节，gzip 28817 字节，一次性解析中位数 0.0586 ms，流式 0.2124 ms。

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

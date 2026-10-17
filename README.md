# heyq02/openui

<p>
  <a href="https://mooncakes.io/docs/heyq02/openui/"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fmooncakes.io%2Fapi-new%2Fv0%2Fmanifest%2Fheyq02%2Fopenui&query=%24.latest_version&label=mooncake&style=flat-square&colorA=564341&colorB=EDED91" alt="mooncake" /></a>
  <a href="https://www.npmjs.com/package/@heyq02/openui.mbt"><img src="https://img.shields.io/npm/v/@heyq02/openui.mbt?label=npm&style=flat-square&colorA=564341&colorB=EDED91" alt="npm" /></a>
  <a href="https://github.com/heyq02/openui.mbt/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-EDED91?style=flat-square&colorA=564341" alt="license" /></a>
  <a href="https://github.com/heyq02/openui.mbt/actions/workflows/compatibility.yml"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fheyq02%2Fopenui.mbt%2Fmain%2Fcompatibility.json" alt="OpenUI compatibility" /></a>
</p>

MoonBit 写的 [OpenUI Lang](https://github.com/thesysdev/openui) 解析器，编译成 Wasm-GC 后从 npm 使用。

```bash
npm install @heyq02/openui.mbt @openuidev/lang-core@1.0.1
npx oui.mbt patch
```

`oui.mbt patch` 把 `@openuidev/lang-core@1.0.1` 里的 `createParser().parse`、`createStreamingParser()`、`parseMessage()`、`buildMessage()`、`parseRules()`、`parseStructuredRules()`、`enrichErrors()`、`mergeStatements()`、`jsonToOpenUI()`、`evaluate()` 和内置字段校验换成 Wasm。`evaluate()` 的求值顺序在 MoonBit 里，`&&`、`||` 和 `?:` 只算会用到的一侧。`Count`、`First`、`Last`、`Sum`、`Avg`、`Min`、`Max`、`Abs`、`Floor`、`Ceil`、`Round` 在 MoonBit 里计算。`Run`、`Set`、`Reset` 的判定在 MoonBit 里，步骤对象仍由宿主按原来的节点组装。`generatePrompt()` 的正文在 MoonBit 里拼装。`generateCloudConfig()` 的库校验在 MoonBit 里，配置块仍由宿主序列化。`generateSystemPrompt()` 的分支在 MoonBit 里判定，遥测仍走官方 JavaScript。`isElementNode()`、`isReactiveAssign()` 和 `isRuntimeExpr()` 也在 MoonBit 里。`walkAST()`、`isASTNode()`、`toLiteralAST()` 和 `literalValue()` 也在 MoonBit 里；`walkAST()` 仍把原来的节点交给访问函数。`OpenUrl` 和 `ToAssistant` 的步骤在 MoonBit 里组装，`context` 仍是宿主上的原值。`substituteRef()` 在 MoonBit 里替换 `Each` 的循环引用，模板求值仍在宿主。`Sort`、`Filter`、`Action`、用户函数和自定义动作仍走官方 JavaScript，值运算留在宿主，以保持 `==` 和对象身份。`url` 与 `pattern` 仍调用宿主的 `URL` 和 `RegExp`。预处理、自动补全、物化、state、query、mutation 的提取，以及 `]]>openui:` 消息的切分和写回都在 MoonBit 里完成。Renderer 仍是官方代码。版本不是 1.0.1，或解析调用点和补丁对不上时，命令退出，已安装的文件保持原样。

```js
import { parseProgram } from "@heyq02/openui.mbt/parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

其余入口见 [`npm/README.md`](npm/README.md)。

## 基准测试

2026-10-16，Linux，Node 22.23.3。同一份组件 Schema，官方 `@openuidev/lang-core@1.0.1` 对 `oui.mbt patch` 之后。复用 parser，取中位数。这些文档的整棵 `ParseResult` 一致。流式最后一次 `push` 的结果和同侧的一次 `parse` 也一致。

一次 `parse`：

| 文档                         |       官方 |   patch 后 |
| ---------------------------- | ---------: | ---------: |
| 注册表单，516 字节           |  0.0704 ms |  0.0692 ms |
| 50 个标量字段，2635 字节     |  0.1293 ms |  0.2123 ms |
| 50 个嵌套字段，5055 字节     |  0.2143 ms |  0.3491 ms |
| 400 个标量字段，22085 字节   |  0.9108 ms |  1.5277 ms |
| 4000 个标量字段，232685 字节 | 11.7927 ms | 18.7098 ms |

流式按行 `push`，最后一行带结束标志：

| 文档            |          官方 |      patch 后 |
| --------------- | ------------: | ------------: |
| 注册表单        |     0.3238 ms |     0.2526 ms |
| 50 个标量字段   |     2.2104 ms |     2.9226 ms |
| 50 个嵌套字段   |     7.6925 ms |    15.4228 ms |
| 400 个标量字段  |   127.7689 ms |   148.6322 ms |
| 4000 个标量字段 | 14250.3740 ms | 16485.5579 ms |

标量字段是 `root = Stack([field…])` 再加 `TextContent` 叶子，已关闭的叶子只编码一次。嵌套字段是 `section = FormControl(…, field)`，引用会离开这条路径，每次 `push` 都完整物化。

注册表单的一次解析与官方持平，流式更快。50 个标量字段、嵌套字段、400 与 4000 个标量字段的一次解析和流式都更慢。整页时间仍由官方 Renderer 主导。

Wasm 二进制 168179 字节，gzip 74284。demo 页面代码 gzip 从 1341307 到 1431667。注册表单整页一次解析的中位数是 229.1 ms 和 235.7 ms。同一页按行流式再绘制的中位数是 228.3 ms 和 232.3 ms。语法树遍历合入后的 Wasm 是 197145 字节，gzip 84428。内置数值调用合入后的 Wasm 是 205419 字节，gzip 87551。提示词拼装合入后的 Wasm 是 230100 字节，gzip 98583。云配置校验合入后的 Wasm 是 236475 字节，gzip 100982。动作步骤合入后的 Wasm 是 237680 字节，gzip 101366。引用替换合入后的 Wasm 是 244881 字节，gzip 104112。系统提示词分支和节点判断合入后的 Wasm 是 245828 字节，gzip 104383。上面的解析和整页时间没有重跑。

```bash
npm ci --prefix web
pnpm run benchmark
```

`--skip-demo` 只测体积和 Node 解析。页面时间含两条：整份文档一次解析，以及按行 `push` 到结束后再绘制。

## License

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

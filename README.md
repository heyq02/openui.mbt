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

`oui.mbt patch` 把 `@openuidev/lang-core@1.0.1` 里的 `createParser().parse`、`createStreamingParser()`、`parseMessage()`、`buildMessage()`、`parseRules()`、`parseStructuredRules()`、`enrichErrors()`、`mergeStatements()`、`jsonToOpenUI()`、`evaluate()` 和内置字段校验换成 Wasm。`evaluate()` 的求值顺序在 MoonBit 里，`&&`、`||` 和 `?:` 只算会用到的一侧。`Count`、`First`、`Last`、`Sum`、`Avg`、`Min`、`Max`、`Abs`、`Floor`、`Ceil`、`Round` 在 MoonBit 里计算。`Run`、`Set`、`Reset` 的判定在 MoonBit 里，步骤对象仍由宿主按原来的节点组装。`generatePrompt()` 的正文在 MoonBit 里拼装。`generateCloudConfig()` 的库校验在 MoonBit 里，配置块仍由宿主序列化。`generateSystemPrompt()` 的分支在 MoonBit 里判定，遥测仍走官方 JavaScript。`isElementNode()`、`isReactiveAssign()` 和 `isRuntimeExpr()` 也在 MoonBit 里。`isActionPlan()` 和 `flattenPlans()` 的分类在 MoonBit 里，步骤对象仍按原来的引用拼回，`ownSteps()` 仍用官方 `WeakSet`。`extractToolResult()` 的内容选择在 MoonBit 里，`structuredContent` 仍返回原值，文本仍由宿主 `JSON.parse`。`stableStringify()` 和 `buildCacheKey()` 在 MoonBit 里生成缓存键，宿主仍调用 `toJSON`，并在循环结构上抛出原来的错误。`resolveField()` 的路径切分和 `toNumber()` 的字符串、布尔值换算在 MoonBit 里，数字仍按原值返回，以保留 `-0` 和 `NaN`。`evaluateRoot()` 的分支在 MoonBit 里判定，命中的元素仍交给 `evaluateElementProps()`。`Each` 的参数个数、数组和循环变量在 MoonBit 里判定，模板仍由宿主求值。`evaluateElementProps()` 的属性分支和运行时错误文案在 MoonBit 里，宿主仍负责递归、求值和读取状态。`createStore()` 的相等判断和初始化写入在 MoonBit 里，状态值和监听仍在宿主。`createQueryManager()` 的快照取值、加载、重新获取和错误列表在 MoonBit 里选择，查询和变更的错误文案也在 MoonBit 里生成。缓存、定时器和 `callTool` 仍在宿主。`resolveStateField()` 和 `stripReactiveAssign()` 的分支在 MoonBit 里选择。宿主仍读取状态、调用 `evaluate()`，并保留原来的 `setValue`。函数和动作参数里，可选参数上的显式 `null` 是否删除、必填参数是否缺少默认值，都在 MoonBit 里判断。参数求值和 schema 上的 `default` 仍由宿主读取。`Sort` 和 `Filter` 在 MoonBit 里选择：不是数组时返回原值还是空数组、按数字还是 `localeCompare` 比较，以及过滤运算符。`localeCompare` 和 `==` 仍在宿主。`evaluateElementInline()` 和 `evaluateElementProps()` 在 MoonBit 里判断 `hasDynamicProps === false`。为假时返回原来的元素，否则宿主仍逐个求值属性。`validate()` 的空值、必填、邮箱、URL、数字、长度和正则分支在 MoonBit 里选择。`URL` 和 `RegExp` 仍由宿主创建。`callFunction()` 的缺参、非法参数、抛错和返回值校验在 MoonBit 里选择。函数本体、schema 上的 `checkValue()` 和 `reportError` 仍由宿主调用。自定义动作的缺参和非法参数在 MoonBit 里判断。命中的步骤仍由宿主登记到原来的 `WeakSet`。`mappedProps` 的状态引用、响应式赋值和子元素在 MoonBit 里选择。宿主仍读取状态、调用 `evaluate()`，并保留原来的元素对象。`getScalarTypeInfo()`、`checkTypeMismatch()` 和 `jsType()` 的枚举、常量、标量类型和数组分支在 MoonBit 里选择。宿主仍读取 schema 字段，并用原来的 `JSON.stringify` 拼枚举文案。`validationMessage()` 的类型、缺参、未知组件、多余参数和根节点文案在 MoonBit 里选择。宿主仍按原来的顺序读取 `issue` 字段，并拼接原来的句子。`validateSchemaValue()`、`validateObjectValue()`、`validateArrayValue()` 和 `validateLeafValue()` 的对象、数组和叶子分支在 MoonBit 里选择。宿主仍保留原来的值，并在缺省值或类型不匹配时复制。`checkValue()` 的严格失败、`evaluateArgs()` 的具名参数和 `pushValidationIssue()` 的警告级别在 MoonBit 里选择。宿主仍按原来的顺序读取 `reportError`、`mappedProps` 和 `issue.code`。`getSchemaDefaultValue()` 的缺省值、`isCompositeSchema()` 的组合键、`refName()` 的引用名和 `buildParamsSignature()` 的参数签名在 MoonBit 里选择。宿主仍按原来的顺序读取 `default`、`$ref` 和 `in`。`evaluatePropCore()` 的动作计划、`evaluateActionCall()` 的 Action 参数和 `isStep()` 的内置步骤在 MoonBit 里选择。宿主仍按原来的顺序读取 `node.name`、`args` 和 `BUILTIN_CALLS`。`tokenize()` 用 MoonBit 词法器切词，再按官方的数字 `t` 和 `JSON.parse` 还原字符串。`autoClose()` 在 MoonBit 里补上未闭合的引号和括号，已经闭合的输入仍返回原来的字符串，字段仍是 `wasIncomplete`。`walkAST()`、`isASTNode()`、`toLiteralAST()` 和 `literalValue()` 也在 MoonBit 里；`walkAST()` 仍把原来的节点交给访问函数。`OpenUrl` 和 `ToAssistant` 的步骤在 MoonBit 里组装，`context` 仍是宿主上的原值。`substituteRef()` 在 MoonBit 里替换 `Each` 的循环引用，模板求值仍在宿主。值运算留在宿主，以保持 `==` 和对象身份。`Action` 的参数求值仍在宿主。`url` 与 `pattern` 仍调用宿主的 `URL` 和 `RegExp`。预处理、自动补全、物化、state、query、mutation 的提取，以及 `]]>openui:` 消息的切分和写回都在 MoonBit 里完成。Renderer 仍是官方代码。版本不是 1.0.1，或解析调用点和补丁对不上时，命令退出，已安装的文件保持原样。

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

Wasm 二进制 168179 字节，gzip 74284。demo 页面代码 gzip 从 1341307 到 1431667。注册表单整页一次解析的中位数是 229.1 ms 和 235.7 ms。同一页按行流式再绘制的中位数是 228.3 ms 和 232.3 ms。语法树遍历合入后的 Wasm 是 197145 字节，gzip 84428。内置数值调用合入后的 Wasm 是 205419 字节，gzip 87551。提示词拼装合入后的 Wasm 是 230100 字节，gzip 98583。云配置校验合入后的 Wasm 是 236475 字节，gzip 100982。动作步骤合入后的 Wasm 是 237680 字节，gzip 101366。引用替换合入后的 Wasm 是 244881 字节，gzip 104112。系统提示词分支和节点判断合入后的 Wasm 是 245828 字节，gzip 104383。计划分类和工具结果合入后的 Wasm 是 247599 字节，gzip 104990。稳定 JSON 合入后的 Wasm 是 249995 字节，gzip 105787。字段路径和数字换算合入后的 Wasm 是 250433 字节，gzip 105897。根节点和 Each 判定合入后的 Wasm 是 251476 字节，gzip 106294。属性求值合入后的 Wasm 是 252936 字节，gzip 106755。状态存储判断合入后的 Wasm 是 254614 字节，gzip 107245。查询快照合入后的 Wasm 是 256176 字节，gzip 107743。状态字段分支合入后的 Wasm 是 256609 字节，gzip 107881。参数判断合入后的 Wasm 是 257121 字节，gzip 107997。排序和过滤合入后的 Wasm 是 258104 字节，gzip 108299。内联元素合入后的 Wasm 是 258329 字节，gzip 108354。字段校验合入后的 Wasm 是 259665 字节，gzip 108747。用户函数分支合入后的 Wasm 是 260232 字节，gzip 108868。自定义动作合入后的 Wasm 是 260676 字节，gzip 108933。映射属性合入后的 Wasm 是 261277 字节，gzip 109057。标量叶子合入后的 Wasm 是 262022 字节，gzip 109233。校验文案合入后的 Wasm 是 262912 字节，gzip 109462。结构校验合入后的 Wasm 是 264773 字节，gzip 110043。参数绑定合入后的 Wasm 是 265240 字节，gzip 110091。引用和签名合入后的 Wasm 是 266367 字节，gzip 110336。属性包装合入后的 Wasm 是 267667 字节，gzip 110687。数字 token 合入后的 Wasm 是 267981 字节，gzip 110770。自动闭合合入后的 Wasm 是 268146 字节，gzip 110891。上面的解析和整页时间没有重跑。

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

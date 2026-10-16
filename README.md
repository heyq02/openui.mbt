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

`oui.mbt patch` 把 `@openuidev/lang-core@1.0.1` 里的 `createParser().parse` 和 `createStreamingParser()` 换成 Wasm 解析和物化。Renderer 仍是官方代码。版本不是 1.0.1，或解析调用点和补丁对不上时，命令退出，已安装的文件保持原样。

```js
import { parseProgram } from "@heyq02/openui.mbt/parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

其余入口见 [`npm/README.md`](npm/README.md)。

## 基准测试

2026-10-16，Linux，Node 22.23.3。同一份组件 Schema，官方 `@openuidev/lang-core@1.0.1` 对 `oui.mbt patch` 之后。复用 parser，取中位数。这些文档的整棵 `ParseResult` 一致。流式最后一次 `push` 的结果和同侧的一次 `parse` 也一致。

一次 `parse`：

| 文档 | 官方 | patch 后 |
| --- | ---: | ---: |
| 注册表单，516 字节 | 0.0745 ms | 0.0626 ms |
| 50 个标量字段，2635 字节 | 0.1385 ms | 0.1800 ms |
| 50 个嵌套字段，5055 字节 | 0.2354 ms | 0.3022 ms |
| 400 个标量字段，22085 字节 | 0.9913 ms | 1.2910 ms |
| 4000 个标量字段，232685 字节 | 11.7253 ms | 16.3780 ms |

流式按行 `push`，最后一行带结束标志：

| 文档 | 官方 | patch 后 |
| --- | ---: | ---: |
| 注册表单 | 0.3378 ms | 0.2626 ms |
| 50 个标量字段 | 2.1797 ms | 2.7088 ms |
| 50 个嵌套字段 | 7.7688 ms | 13.2447 ms |
| 400 个标量字段 | 145.9486 ms | 140.7504 ms |
| 4000 个标量字段 | 16488.2482 ms | 16950.8052 ms |

标量字段是 `root = Stack([field…])` 再加 `TextContent` 叶子，已关闭的叶子只编码一次。嵌套字段是 `section = FormControl(…, field)`，引用会离开这条路径，每次 `push` 都完整物化。

注册表单的一次解析和流式都更快。400 个标量字段的流式略快。50 与 4000 个标量字段的一次解析更慢，4000 个字段的流式中位数接近。嵌套文档的流式更慢。

Wasm 二进制 94565 字节，gzip 37965。demo 页面代码 gzip 从 1341307 到 1388455。注册表单整页一次解析的中位数是 254.6 ms 和 259.7 ms。同一页按行流式再绘制的中位数是 260.7 ms 和 254.8 ms。

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

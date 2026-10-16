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

`oui.mbt patch` 把 `@openuidev/lang-core@1.0.1` 里的 `createParser().parse` 换成 Wasm 解析和物化。流式解析和 Renderer 仍是官方代码。版本不是 1.0.1，或解析调用点和补丁对不上时，命令退出，已安装的文件保持原样。

```js
import { parseProgram } from "@heyq02/openui.mbt/parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

其余入口见 [`npm/README.md`](npm/README.md)。

## 基准测试

```bash
npm ci --prefix web
pnpm run benchmark
```

### 解析

复用 parser 后 `parse` 的中位数。

| 文档                   |      官方 |  patch 后 |
| ---------------------- | --------: | --------: |
| 注册表单，516 字节     | 0.0286 ms | 0.0365 ms |
| 50 个字段              | 0.1022 ms | 0.0896 ms |
| 400 个字段，22085 字节 | 0.7559 ms | 0.6315 ms |

400 个字段快 16%，50 个字段快 12%。注册表单是官方更快。

流式解析仍走官方物化。

| 文档      |      官方 |  patch 后 |
| --------- | --------: | --------: |
| 注册表单  | 0.1376 ms | 0.2146 ms |
| 50 个字段 | 1.9704 ms | 2.3271 ms |

结构指纹只看根组件、语句数、错误数和 incomplete，两边相同：注册表单 8 条语句、0 个错误，50 个字段 51 条语句，400 个字段 401 条语句。

### 体积

| 文件                      |   原始 |  gzip |
| ------------------------- | -----: | ----: |
| 官方 `dist/index.mjs`     | 180172 | 48901 |
| patch 后 `dist/index.mjs` | 181392 | 49331 |
| `parser.wasm.js`          |  93868 | 38767 |
| Wasm 二进制               |  70334 | 28817 |

demo 生产包含 html、js、css，不计 source map。

|                           |    原始 | gzip 之和 |
| ------------------------- | ------: | --------: |
| 官方                      | 3713817 |   1336967 |
| patch 后                  | 3801807 |   1375005 |
| 官方入口 `bench.*.js`     |   31609 |     17969 |
| patch 后入口 `bench.*.js` |  125958 |     57628 |

### 页面

Headless Chrome 从导航计到注册表单画出后的下一帧。热加载后 6 次都在 165–188 ms。

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

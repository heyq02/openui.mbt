# 与官方解析的对照

`oui.mbt patch` 只替换已安装的 `@openuidev/lang-core@1.0.1` 里的语句解析。分类、Schema 物化和 Renderer 仍是官方代码，所以调用方拿到的仍是原来的 `ParseResult`。

重复对照：

```bash
npm ci --prefix web
pnpm run compare
```

`node npm/compare.mjs` 会下载官方 `@openuidev/lang-core@1.0.1`，复制一份并执行 patch，然后用同一份组件 Schema 跑一次性解析和流式解析。结构对比包含根节点、`incomplete`、`unresolved`、`orphaned`、语句数、错误码和 state 声明。错误文案不参与对比。

版本不是 1.0.1 时，patch 直接失败，并且不改已安装的文件。1.0.1 的包里如果语句解析调用点数量变了，同样在写入之前失败。

## 样例

对照库覆盖注册表单用到的组件：`Stack`、`TextContent`、`Form`、`FormControl`、`Input`、`Buttons`、`Button`。样例是 `web/signup.openui`，再加上未知组件、缺少必填参数、先引用后定义、孤立语句、`$` 状态、非法行和未闭合字符串。

这组样例上，patch 之后的一次性解析和流式解析与官方结果没有结构差异。`@openuidev/react-ui` 的其余组件不在这组样例里。

## 一次本机结果

重新运行命令会打印当次数字。下面是 2026-10-16 在本机的一次结果：

| 项 | 值 |
| --- | --- |
| Wasm | 62446 字节 |
| gzip | 25971 字节 |
| 一次性解析中位数 | 0.0972 ms |
| 流式解析中位数 | 0.2444 ms |
| 计时期间的 Node 堆 | 约 21 MB |

耗时是 patch 之后 `createParser().parse` 和按行 `createStreamingParser().push` 的中位数，从源码到官方 `ParseResult`。堆占用是这段循环里的 `heapUsed`，不是单独量出来的 Wasm 线性内存。

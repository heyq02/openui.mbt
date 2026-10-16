# 与官方解析的对照

`oui.mbt patch` 改已安装的 `@openuidev/lang-core@1.0.1`。`createParser().parse` 在 Wasm 里物化，返回官方 `ParseResult` 的形状。流式解析仍把语句交给官方分类和物化。Renderer 仍是官方代码。`patch-source` 只替换语句解析，兼容性流水线走的是那条路径。

重复对照：

```bash
npm ci --prefix web
pnpm run compare
```

`node npm/compare.mjs` 会下载官方 `@openuidev/lang-core@1.0.1`，复制一份并执行 patch，然后用同一份组件 Schema 跑一次性解析和流式解析。结构对比包含根节点、`incomplete`、`unresolved`、`orphaned`、语句数、错误码和 state 声明。错误文案不参与对比。子节点的 `statementId`、`partial: false` 和动作参数上的 `mappedProps` 会计入差异。

版本不是 1.0.1 时，patch 直接失败，并且不改已安装的文件。1.0.1 的包里如果语句解析调用点数量变了，同样在写入之前失败。

## 样例

对照库覆盖注册表单用到的组件：`Stack`、`TextContent`、`Form`、`FormControl`、`Input`、`Buttons`、`Button`。样例是 `web/signup.openui`，再加上未知组件、缺少必填参数、先引用后定义、孤立语句、`$` 状态、非法行和未闭合字符串。

这组样例上，7 条流式结果与官方没有结构差异。一次性解析有 6 处差异：注册表单的子节点没有 `statementId`，动作参数没有 `mappedProps`；错误对象没有 `statementId`；`$name` 没有进入 `stateDeclarations`；坏行多一条 `parse-failed`；未闭合输入的语句数是 2，官方是 1。先引用后定义那条一次性解析没有差异。`@openuidev/react-ui` 的其余组件不在这组样例里。

## 一次本机结果

重新运行命令会打印当次数字。下面是 2026-10-16 在本机的一次结果：

| 项 | 值 |
| --- | --- |
| Wasm | 70334 字节 |
| gzip | 28817 字节 |
| 一次性解析中位数 | 0.0586 ms |
| 流式解析中位数 | 0.2124 ms |
| 计时期间的 Node 堆 | 一次性解析约 16 MB，流式约 20 MB |

耗时是 patch 之后 `createParser().parse` 和按行 `createStreamingParser().push` 的中位数，从源码到官方 `ParseResult`。堆占用是这段循环里的 `heapUsed`，不是单独量出来的 Wasm 线性内存。

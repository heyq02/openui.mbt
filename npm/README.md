# @heyq02/openui.mbt

MoonBit parser for [OpenUI Lang](https://github.com/thesysdev/openui), compiled to Wasm-GC.

`parseProgram` returns JSON whose expression nodes use the same `k` discriminant as `@openuidev/lang-core`. Loading the module instantiates the Wasm module synchronously.

```js
import { parseProgram } from "@heyq02/openui.mbt/parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

`materializeProgram(source, schema, rootName)` returns the element tree plus `errors`, `unresolved`, `orphaned`, and `incomplete`.

`createStream(schema, rootName)` keeps a buffer in Wasm. `push` appends, `set` replaces, and each call returns the latest materialize result. An unfinished line is held back until `finish`, which checks the whole buffer. `dispose` drops that session.

```bash
npm install @heyq02/openui.mbt @openuidev/lang-core
npx oui.mbt patch
```

`oui.mbt patch` rewrites the installed `@openuidev/lang-core`. `createParser().parse` materializes in Wasm and returns the official `ParseResult` shape. Streaming still returns statements for OpenUI classification and materialize. The Renderer stays in OpenUI. The patch matches lang-core 1.0.1. A different version, or a 1.0.1 bundle whose parser call sites have changed, makes the command exit before it writes either file.

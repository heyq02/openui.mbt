# @heyq02/openui.mbt

MoonBit parser for [OpenUI Lang](https://github.com/thesysdev/openui), compiled to Wasm-GC.

`parseProgram` returns JSON whose expression nodes use the same `k` discriminant as `@openuidev/lang-core`. Loading the module instantiates the Wasm module synchronously.

```js
import { parseProgram } from "@heyq02/openui.mbt/parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

`materializeProgram(source, schema, rootName)` returns the element tree plus `errors`, `unresolved`, `orphaned`, and `incomplete`.

`createStream(schema, rootName)` keeps a buffer in Wasm. Closed lines stay parsed. `push` and `set` take an optional `complete` flag and return the official `ParseResult`. An unfinished line is auto-closed for that result and is not committed until it closes. `dispose` drops that session.

```bash
npm install @heyq02/openui.mbt @openuidev/lang-core
npx oui.mbt patch
```

`oui.mbt patch` rewrites the installed `@openuidev/lang-core`. `createParser().parse` and `createStreamingParser()` preprocess, auto-close, materialize, and extract state, query, and mutation statements in Wasm. They return the official `ParseResult` shape. The Renderer stays in OpenUI. The patch matches lang-core 1.0.1. A different version, or a 1.0.1 bundle whose parser call sites have changed, makes the command exit before it writes either file.

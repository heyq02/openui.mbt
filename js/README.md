# @heyq02/openui.mbt

MoonBit parser for [OpenUI Lang](https://github.com/thesysdev/openui), compiled to Wasm-GC.

`parseProgram` returns JSON whose expression nodes use the same `k` discriminant as `@openuidev/lang-core`. Loading the module instantiates the Wasm module synchronously.

```js
import { parseProgram } from "@heyq02/openui.mbt/parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

`materializeProgram(source, schema, rootName)` returns the element tree plus `errors`, `unresolved`, `orphaned`, and `incomplete`.

```bash
npm install @heyq02/openui.mbt @openuidev/lang-core
npx oui.mbt patch
```

`oui.mbt patch` rewrites the installed `@openuidev/lang-core` so `parse` and the streaming parser call `@heyq02/openui.mbt/parser`. Classification, materialize, and the Renderer stay in OpenUI. The patch matches lang-core 1.0.1.

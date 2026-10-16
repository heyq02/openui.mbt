# @heyq02/openui-parser

MoonBit parser for [OpenUI Lang](https://github.com/thesysdev/openui), compiled to Wasm-GC.

`parseProgram` returns JSON whose expression nodes use the same `k` discriminant as `@openuidev/lang-core`. Loading the module instantiates the Wasm module synchronously.

```js
import { parseProgram } from "@heyq02/openui-parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

The package is published as a GitHub Release asset, not to the npm registry.

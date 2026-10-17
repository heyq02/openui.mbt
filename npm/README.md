# @heyq02/openui.mbt

MoonBit parser for [OpenUI Lang](https://github.com/thesysdev/openui), compiled to Wasm-GC.

`parseProgram` returns JSON whose expression nodes use the same `k` discriminant as `@openuidev/lang-core`. Loading the module instantiates the Wasm module synchronously.

```js
import { parseProgram } from "@heyq02/openui.mbt/parser";

const program = parseProgram('root = TextContent("Hello", "large")');
```

`materializeProgram(source, schema, rootName)` returns the element tree plus `errors`, `unresolved`, `orphaned`, and `incomplete`.

`createStream(schema, rootName)` keeps a buffer in Wasm. Closed lines stay parsed. `push` and `set` take an optional `complete` flag and return the official `ParseResult`. An unfinished line is auto-closed for that result and is not committed until it closes. `dispose` drops that session.

`parseMessage(raw, options)` splits an OpenUI `]]>openui:` message. `options.streaming` holds a partial marker. The result is `{ content, context, attributes, end }`. `buildMessage(message)` writes that message back.

```bash
npm install @heyq02/openui.mbt @openuidev/lang-core
npx oui.mbt patch
```

`oui.mbt patch` rewrites the installed `@openuidev/lang-core`. `createParser().parse` and `createStreamingParser()` preprocess, auto-close, materialize, and extract state, query, and mutation statements in Wasm. They return the official `ParseResult` shape. `parseMessage()` and `buildMessage()` split and write `]]>openui:` messages in Wasm. `parseRules()`, `parseStructuredRules()`, `enrichErrors()`, `mergeStatements()`, `jsonToOpenUI()`, `evaluate()`, and the built-in field checks also run in Wasm. `evaluate()` decides which side of `&&`, `||`, and `?:` runs. `Count`, `First`, `Last`, `Sum`, `Avg`, `Min`, `Max`, `Abs`, `Floor`, `Ceil`, and `Round` run in Wasm. `Run`, `Set`, and `Reset` decide in Wasm, and the host rebuilds each step from the original nodes. `generatePrompt()` assembles its text in Wasm. `generateCloudConfig()` checks the library in Wasm, and the host still serializes the config block. `generateSystemPrompt()` chooses its branch in Wasm and still records telemetry in the official JavaScript. `isElementNode()`, `isReactiveAssign()`, and `isRuntimeExpr()` also run in Wasm. `isActionPlan()` and `flattenPlans()` classify in Wasm, and the host copies the original steps before `ownSteps()`. `extractToolResult()` chooses the content in Wasm, and the host still returns `structuredContent` and parses text. `stableStringify()` and `buildCacheKey()` build query cache keys in Wasm. The host still calls `toJSON` and reports cycles. `resolveField()` splits paths in Wasm, and `toNumber()` converts strings and booleans in Wasm. Numbers stay on the host so `-0` and `NaN` keep their values. `evaluateRoot()` chooses its branch in Wasm, and a matching element still goes through `evaluateElementProps()`. `Each` checks its arity, array, and loop variable in Wasm, and the host still evaluates the template. `OpenUrl` and `ToAssistant` build their steps in Wasm, and `context` stays the host value. `substituteRef()` replaces `Each` loop refs in Wasm, and `Each` still evaluates the template on the host. `Sort`, `Filter`, user functions, and custom actions stay in the official JavaScript. `Action` still evaluates its arguments on the host. `walkAST()`, `isASTNode()`, `toLiteralAST()`, and `literalValue()` also run in Wasm. `walkAST()` still hands the live node to the visitor. `url` and `pattern` still use the host `URL` and `RegExp`. The Renderer stays in OpenUI. The patch matches lang-core 1.0.1. A different version, or a 1.0.1 bundle whose parser call sites have changed, makes the command exit before it writes either file.

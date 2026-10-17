import { wasmBase64 } from "./parser.wasm.js";

const compileOptions = {
  builtins: ["js-string"],
  importedStringConstants: "_",
};

function wasmBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

const wasmModule = new WebAssembly.Module(wasmBytes(wasmBase64), compileOptions);

// Node 22 keeps imported string constants as Wasm globals. Node 26 links
// them while compiling, so the import list is empty.
const stringConstants = {};
for (const item of WebAssembly.Module.imports(wasmModule)) {
  if (item.module === "_") stringConstants[item.name] = item.name;
}
const instance = new WebAssembly.Instance(
  wasmModule,
  Object.keys(stringConstants).length > 0 ? { _: stringConstants } : {},
);
const {
  parse_openui: parseOpenui,
  tokenize_openui: tokenizeOpenui,
  materialize_openui: materializeOpenui,
  parse_result: parseResultOpenui,
  stream_open: streamOpen,
  stream_append: streamAppend,
  stream_replace: streamReplace,
  stream_view: streamView,
  stream_finish: streamFinish,
  stream_close: streamClose,
  parse_message: parseMessageOpenui,
  build_message: buildMessageOpenui,
  parse_rules: parseRulesOpenui,
  parse_structured_rules: parseStructuredRulesOpenui,
  builtin_check: builtinCheckOpenui,
  enrich_hints: enrichHintsOpenui,
  merge_statements: mergeStatementsOpenui,
  json_to_openui: jsonToOpenUIOpenui,
  eval_start: evalStartOpenui,
  eval_answer: evalAnswerOpenui,
  eval_cancel: evalCancelOpenui,
  walk_plan: walkPlanOpenui,
  is_ast_kind: isAstKindOpenui,
  to_literal_ast: toLiteralAstOpenui,
  literal_value: literalValueOpenui,
  call_builtin: callBuiltinOpenui,
  lazy_step: lazyStepOpenui,
  eager_step: eagerStepOpenui,
  generate_prompt: generatePromptOpenui,
  cloud_config: cloudConfigOpenui,
  substitute_ref: substituteRefOpenui,
} = instance.exports;

/** Parse a complete OpenUI Lang program. Statement ASTs use the official `k` field. */
export function parseProgram(source) {
  return JSON.parse(parseOpenui(source ?? ""));
}

/** Tokenize OpenUI Lang source. */
export function tokenize(source) {
  return JSON.parse(tokenizeOpenui(source ?? ""));
}

/**
 * Materialize source against a library JSON Schema.
 * Returns the element tree plus errors, unresolved, orphaned, and incomplete.
 */
export function materializeProgram(source, schema, rootName = "") {
  return JSON.parse(materializeOpenui(source ?? "", schema ?? "{}", rootName ?? ""));
}

/** Parse and materialize in one Wasm call. The result uses the official ParseResult shape. */
export function parseResult(source, schema, rootName = "") {
  return JSON.parse(parseResultOpenui(source ?? "", schema ?? "{}", rootName ?? ""));
}

function readResult(json) {
  return JSON.parse(json);
}

/**
 * Streaming parser. Closed lines stay parsed in Wasm.
 * Before finish, an unfinished line is held back.
 * `complete` checks the whole buffer in that call. dispose drops the session.
 * The result uses the official ParseResult shape.
 */
export function createStream(schema, rootName = "") {
  const id = streamOpen(schema ?? "{}", rootName ?? "");
  return {
    push(chunk, complete = false) {
      return readResult(streamAppend(id, chunk ?? "", complete ? 1 : 0));
    },
    set(text, complete = false) {
      return readResult(streamReplace(id, text ?? "", complete ? 1 : 0));
    },
    result(complete = false) {
      return readResult(streamView(id, complete ? 1 : 0));
    },
    finish() {
      return readResult(streamFinish(id));
    },
    dispose() {
      streamClose(id);
    },
  };
}

/** Split an OpenUI `]]>openui:` message. `streaming` holds a partial marker line. */
export function parseMessage(raw, options) {
  return JSON.parse(parseMessageOpenui(raw ?? "", options && options.streaming ? 1 : 0));
}

/** Write an OpenUI `]]>openui:` message. Context objects are JSON-encoded before the marker. */
export function buildMessage(message) {
  const attributes = (message && message.attributes) || {};
  const pairs = [];
  for (const [key, value] of Object.entries(attributes)) {
    pairs.push([String(key), String(value)]);
  }
  const hasContext = !!message && message.context != null;
  const context = hasContext
    ? typeof message.context === "string"
      ? message.context
      : JSON.stringify(message.context)
    : "";
  const content = message && message.content !== undefined ? String(message.content) : "undefined";
  return buildMessageOpenui(
    content,
    context,
    hasContext ? 1 : 0,
    JSON.stringify(pairs),
    message && message.end ? 1 : 0,
  );
}

/** Parse string rules. Numeric min, max, minLength, and maxLength arguments become numbers. */
export function parseRules(rules) {
  if (!Array.isArray(rules)) return [];
  const strings = [];
  for (const rule of rules) {
    if (typeof rule === "string") strings.push(rule);
  }
  const parsed = JSON.parse(parseRulesOpenui(JSON.stringify(strings)));
  return parsed.map((item) => {
    if (item.inf === 1) return { type: item.type, arg: Infinity };
    if (item.inf === -1) return { type: item.type, arg: -Infinity };
    if (Object.prototype.hasOwnProperty.call(item, "arg"))
      return { type: item.type, arg: item.arg };
    return { type: item.type };
  });
}

/** Parse a rules object. `false`, `null`, and `undefined` are dropped. `true` has no argument. */
export function parseStructuredRules(rules) {
  if (!rules || typeof rules !== "object" || Array.isArray(rules)) return [];
  const entries = Object.entries(rules);
  const tagged = entries.map(([key, val]) => [
    key,
    val === false || val === undefined || val === null ? "skip" : val === true ? "true" : "arg",
  ]);
  const plan = JSON.parse(parseStructuredRulesOpenui(JSON.stringify(tagged)));
  const result = [];
  for (const item of plan) {
    if (Object.prototype.hasOwnProperty.call(item, "i"))
      result.push({ type: item.type, arg: entries[item.i][1] });
    else result.push({ type: item.type });
  }
  return result;
}

function encodeBound(arg) {
  const number = Number(arg);
  if (Number.isNaN(number)) return { k: "nan" };
  if (number === Infinity) return { k: "pinf" };
  if (number === -Infinity) return { k: "ninf" };
  return { k: "n", v: number };
}

function tagValue(value) {
  if (value === null) return { t: "null" };
  if (value === undefined) return { t: "u" };
  const kind = typeof value;
  if (kind === "string") return { t: "s", v: value };
  if (kind === "number") return { t: "n", v: encodeBound(value) };
  if (kind === "boolean") return { t: "b", v: value };
  if (kind !== "object") return { t: "other", host: encodeBound(parseFloat(String(value))) };
  if (Array.isArray(value)) {
    return {
      t: "a",
      v: value.map(tagValue),
      host: encodeBound(parseFloat(String(value))),
    };
  }
  const tagged = {
    t: "o",
    vals: Object.keys(value).map((key) => tagValue(value[key])),
    host: encodeBound(parseFloat(String(value))),
  };
  if ("value" in value) tagged.inner = tagValue(value.value);
  return tagged;
}

const builtinMessages = {
  required: "This field is required",
  options: "At least one option is required",
  email: "Please enter a valid email",
  numeric: "Must be a number",
};

/** Run one built-in rule. `url` and `pattern` stay in the host because they use `URL` and `RegExp`. */
export function checkBuiltin(kind, value, arg) {
  const code = builtinCheckOpenui(
    kind,
    JSON.stringify(tagValue(value)),
    JSON.stringify(encodeBound(arg)),
  );
  if (!code) return undefined;
  if (builtinMessages[code]) return builtinMessages[code];
  const number = Number(arg);
  if (code === "min") return `Must be at least ${number}`;
  if (code === "max") return `Must be no more than ${number}`;
  if (code === "minLength") return `Must be at least ${number} characters`;
  if (code === "maxLength") return `Must be no more than ${number} characters`;
  return undefined;
}

/** Attach parser hints. `statementId: undefined` stays on the object. */
export function enrichErrors(validationErrors, schema, componentNames) {
  const items = [];
  let needsNames = false;
  for (const ve of validationErrors) {
    if (ve && ve.code === "unknown-component") needsNames = true;
    const item = {
      code: ve && typeof ve.code === "string" ? ve.code : "",
      component: ve && ve.component != null ? String(ve.component) : "",
    };
    if (ve && (ve.code === "missing-required" || ve.code === "null-required")) {
      const def = schema.$defs?.[ve.component];
      if (def?.properties) {
        item.keys = Object.keys(def.properties);
        const required = [];
        for (const entry of def.required ?? []) {
          if (typeof entry === "string") required.push(entry);
        }
        item.required = required;
      }
    }
    items.push(item);
  }
  const names = needsNames ? componentNames.map((name) => String(name)) : [];
  const hints = JSON.parse(enrichHintsOpenui(JSON.stringify({ names, items })));
  return validationErrors.map((ve, index) => {
    const error = {
      source: "parser",
      code: ve.code,
      message: ve.message,
      component: ve.component,
      path: ve.path || undefined,
      statementId: ve.statementId,
      ...(ve.severity && { severity: ve.severity }),
    };
    const hint = hints[index] || "";
    if (ve.code === "unknown-component") {
      if (hint) error.hint = hint;
    } else if (ve.code === "missing-required" || ve.code === "null-required") {
      error.hint = hint || undefined;
    } else if (ve.code === "inline-reserved" && hint) {
      error.hint = hint;
    }
    return error;
  });
}

function isElementNode(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  return (
    value.type === "element" &&
    typeof value.typeName === "string" &&
    typeof value.props === "object" &&
    value.props !== null &&
    typeof value.partial === "boolean"
  );
}

/** True when `value` is an OpenUI AST node. */
export function isASTNode(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  return typeof value.k === "string" && isAstKindOpenui(value.k) !== 0;
}

function sourceText(value) {
  if (value === undefined) return "undefined";
  if (value === null) return "null";
  return String(value);
}

function encodeValue(value) {
  if (value === null || value === undefined) return ["z"];
  if (typeof value === "string") return ["s", JSON.stringify(value)];
  if (typeof value === "number") return ["n", String(value)];
  if (typeof value === "boolean") return ["b", value ? "true" : "false"];
  if (isElementNode(value)) return encodeElement(value);
  if (isASTNode(value)) return ["ast", encodeAst(value)];
  if (Array.isArray(value)) return ["a", value.map(encodeValue)];
  if (typeof value === "object") {
    return ["o", Object.entries(value).map(([key, item]) => [key, encodeValue(item)])];
  }
  return ["x"];
}

function encodeElement(node) {
  const id = node.statementId ? sourceText(node.statementId) : "";
  return [
    "el",
    node.typeName,
    id,
    Object.entries(node.props).map(([key, item]) => [key, encodeValue(item)]),
  ];
}

function encodeAst(node) {
  const kind = node.k;
  switch (kind) {
    case "Str":
      return ["Str", JSON.stringify(node.v)];
    case "Num":
      return ["Num", String(node.v)];
    case "Bool":
      return ["Bool", node.v ? "true" : "false"];
    case "Null":
      return ["Null"];
    case "Ph":
    case "Ref":
    case "StateRef":
    case "RuntimeRef":
      return [kind, sourceText(node.n)];
    case "Arr":
      return ["Arr", node.els.map(encodeAst)];
    case "Obj":
      return ["Obj", node.entries.map(([key, item]) => [key, encodeAst(item)])];
    case "BinOp":
      return ["BinOp", sourceText(node.op), encodeAst(node.left), encodeAst(node.right)];
    case "UnaryOp":
      return ["UnaryOp", sourceText(node.op), encodeAst(node.operand)];
    case "Ternary":
      return ["Ternary", encodeAst(node.cond), encodeAst(node.then), encodeAst(node.else)];
    case "Member":
      return ["Member", encodeAst(node.obj), sourceText(node.field)];
    case "Index":
      return ["Index", encodeAst(node.obj), encodeAst(node.index)];
    case "Assign":
      return ["Assign", sourceText(node.target), encodeAst(node.value)];
    case "Comp":
      return ["Comp", sourceText(node.name), node.args.map(encodeAst)];
    default:
      return ["Other"];
  }
}

function encodeRoot(json) {
  const typeName = json.typeName;
  const props = Object.entries(json.props);
  const id = json.statementId ? sourceText(json.statementId) : "";
  return [
    "root",
    typeof typeName === "string" ? typeName : null,
    sourceText(typeName),
    id,
    props.map(([key, item]) => [key, encodeValue(item)]),
  ];
}

/** Serialize an element tree to OpenUI Lang source. */
export function jsonToOpenUI(json, library, options) {
  const schema = library.toJSONSchema();
  if (schema == null) schema.properties;
  const state = options?.stateDeclarations;
  const stateJson = state
    ? JSON.stringify(
        Object.entries(state).map(([name, value]) => [
          name,
          value === null ? ["skip"] : encodeValue(value),
        ]),
      )
    : "null";
  return jsonToOpenUIOpenui(JSON.stringify(schema), JSON.stringify(encodeRoot(json)), stateJson);
}

function encodeEvalAst(node, astNodes) {
  const id = astNodes.length;
  astNodes.push(node);
  if (!node || typeof node !== "object") return node.k;
  switch (node.k) {
    case "Str":
    case "Num":
    case "Bool":
      return ["Lit", id];
    case "Null":
    case "Ph":
      return [node.k, id];
    case "StateRef":
      return ["StateRef", id, node.n];
    case "Ref":
    case "RuntimeRef":
      return [node.k, id, node.n];
    case "Arr":
      return ["Arr", id, node.els.map((item) => encodeEvalAst(item, astNodes))];
    case "Obj":
      return ["Obj", id, node.entries.map(([key, item]) => [key, encodeEvalAst(item, astNodes)])];
    case "BinOp":
      return [
        "BinOp",
        id,
        node.op,
        encodeEvalAst(node.left, astNodes),
        encodeEvalAst(node.right, astNodes),
      ];
    case "UnaryOp":
      return ["UnaryOp", id, node.op, encodeEvalAst(node.operand, astNodes)];
    case "Ternary":
      return [
        "Ternary",
        id,
        encodeEvalAst(node.cond, astNodes),
        encodeEvalAst(node.then, astNodes),
        encodeEvalAst(node.else, astNodes),
      ];
    case "Member":
      return ["Member", id, encodeEvalAst(node.obj, astNodes), node.field];
    case "Index":
      return ["Index", id, encodeEvalAst(node.obj, astNodes), encodeEvalAst(node.index, astNodes)];
    case "Assign":
      return ["Assign", id, node.target];
    case "Comp":
      return ["Comp", id];
    default:
      return ["Other", id];
  }
}

function evalToNumber(value) {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const number = Number(value);
    return Number.isNaN(number) ? 0 : number;
  }
  if (typeof value === "boolean") return value ? 1 : 0;
  return 0;
}

function evalMember(obj, field) {
  if (obj == null) return null;
  if (Array.isArray(obj)) {
    if (field === "length") return obj.length;
    return obj.map((item) => item?.[field] ?? null);
  }
  return obj[field];
}

function evalIndex(obj, idx) {
  if (obj == null || idx == null) return null;
  if (Array.isArray(obj)) return obj[evalToNumber(idx)];
  return obj[String(idx)];
}

function evalAdd(left, right) {
  if (typeof left === "string" || typeof right === "string") {
    return String(left ?? "") + String(right ?? "");
  }
  return evalToNumber(left) + evalToNumber(right);
}

function encodeBuiltinValue(value) {
  if (value === null) return { t: "null" };
  if (value === undefined) return { t: "u" };
  if (typeof value === "number") {
    if (Number.isNaN(value)) return { t: "nan" };
    if (value === Infinity) return { t: "pinf" };
    if (value === -Infinity) return { t: "ninf" };
    if (Object.is(value, -0)) return { t: "n0" };
    return { t: "n", v: value };
  }
  if (typeof value === "string") return { t: "s", v: value };
  if (typeof value === "boolean") return { t: "b", v: value };
  if (Array.isArray(value)) {
    const items = [];
    for (let i = 0; i < value.length; i += 1) {
      items.push(i in value ? encodeBuiltinValue(value[i]) : { t: "hole" });
    }
    return { t: "a", v: items };
  }
  if (typeof value === "object") return { t: "o" };
  return { t: "x" };
}

function reviveBuiltin(encoded, args) {
  if (!encoded || encoded.t === "js") return { __useJs: true };
  if (encoded.t === "null") return null;
  if (encoded.t === "index") {
    const array = args?.array;
    return Array.isArray(array) ? (array[encoded.i] ?? null) : null;
  }
  if (encoded.t === "nan") return NaN;
  if (encoded.t === "pinf") return Infinity;
  if (encoded.t === "ninf") return -Infinity;
  if (encoded.t === "n0") return -0;
  if (encoded.t === "n") return encoded.v;
  return null;
}

/** Eager built-in except `Sort` and `Filter`, which return `{ __useJs: true }`. */
export function callBuiltin(name, args) {
  const encoded = {};
  if (args && typeof args === "object") {
    for (const key of Object.keys(args)) encoded[key] = encodeBuiltinValue(args[key]);
  }
  return reviveBuiltin(
    JSON.parse(callBuiltinOpenui(String(name ?? ""), JSON.stringify(encoded))),
    args,
  );
}

function textOf(value) {
  if (value === undefined) return "undefined";
  if (value === null) return "null";
  return String(value);
}

function joinText(value) {
  if (value == null) return "";
  return String(value);
}

function encodeSchema(schema) {
  const encoded = {
    type: typeof schema?.type === "string" ? schema.type : "",
    required: Array.isArray(schema?.required) ? schema.required : [],
    properties: schema?.properties
      ? Object.entries(schema.properties).map(([key, value]) => [key, encodeSchema(value)])
      : [],
  };
  if (Array.isArray(schema?.enum)) encoded.enum = schema.enum;
  if (schema?.items && typeof schema.items === "object") encoded.items = encodeSchema(schema.items);
  return encoded;
}

function encodeComponent(name, comp) {
  const signature = comp.signature;
  return {
    name: String(name),
    sig: signature === undefined ? "u" : signature === null ? "n" : "s",
    signature: typeof signature === "string" ? signature : "",
    description: comp.description ? String(comp.description) : null,
  };
}

function encodeCall(name, value) {
  return {
    name,
    signature: textOf(value.signature),
    description: value.description ? String(value.description) : null,
  };
}

function encodeTool(tool) {
  if (typeof tool === "string") return { k: "s", name: tool };
  const encoded = {
    k: "t",
    name: textOf(tool?.name),
    description: tool?.description ? String(tool.description) : null,
  };
  if (tool?.inputSchema) encoded.input = encodeSchema(tool.inputSchema);
  if (tool?.outputSchema) encoded.output = encodeSchema(tool.outputSchema);
  return encoded;
}

/** Official `generatePrompt` text. Cloud config and telemetry stay outside this call. */
export function generatePrompt(spec) {
  const components = spec.components;
  Object.values(components);
  const tools = spec.tools ?? [];
  const hasTools = tools.length > 0;
  const toolCalls = Boolean(spec.toolCalls ?? hasTools);
  const bindings = Boolean(spec.bindings ?? toolCalls);
  const builtin = Boolean(spec.builtinFunctions ?? (toolCalls || bindings));
  const encoded = {
    root: String(spec.root ?? "Root"),
    components: Object.entries(components).map(([name, comp]) => encodeComponent(name, comp)),
    groups: (spec.componentGroups ?? []).map((group) => ({
      name: textOf(group.name),
      components: group.components.map((name) => String(name)),
      notes: (group.notes ?? []).map((note) => joinText(note)),
    })),
    functions: Object.values(spec.functions ?? {}).map((value) => encodeCall("", value)),
    actions: Object.entries(spec.actions ?? {}).map(([name, value]) => encodeCall(name, value)),
    builtin,
    toolCalls,
    bindings,
    tools: tools.map(encodeTool),
    examples: [...(spec.examples ?? []), ...(spec.toolExamples ?? [])].map((item) =>
      joinText(item),
    ),
    edit: Boolean(spec.editMode),
    inline: Boolean(spec.inlineMode),
    rules: (spec.additionalRules ?? []).map((rule) => textOf(rule)),
  };
  if (spec.preamble != null) encoded.preamble = String(spec.preamble);
  return generatePromptOpenui(JSON.stringify(encoded));
}

function tagCloudValue(value) {
  if (value === null) return { t: "z" };
  if (value === undefined) return { t: "u" };
  const type = typeof value;
  if (type === "string") return { t: "s", v: value };
  if (type === "number") {
    return {
      t: "n",
      v: Object.is(value, -0)
        ? "-0"
        : Number.isNaN(value)
          ? "nan"
          : value === Infinity
            ? "inf"
            : value === -Infinity
              ? "-inf"
              : value,
      j: String(value),
    };
  }
  if (type === "boolean") return { t: "b", v: value };
  if (type === "bigint" || type === "function") return { t: "x", j: String(value) };
  if (type === "symbol") return { t: "x", j: String(value), sym: true };
  if (Array.isArray(value)) {
    const items = [];
    for (let index = 0; index < value.length; index += 1) {
      items.push(
        Object.prototype.hasOwnProperty.call(value, index)
          ? tagCloudValue(value[index])
          : { t: "h" },
      );
    }
    return { t: "a", v: items };
  }
  if (type === "object") {
    const tagged = {
      t: "o",
      v: Object.entries(value).map(([key, item]) => [key, tagCloudValue(item)]),
    };
    if (typeof value.toString === "function" && value.toString !== Object.prototype.toString) {
      try {
        tagged.j = String(value);
      } catch {
        tagged.throw = true;
      }
    }
    return tagged;
  }
  return { t: "x", throw: true };
}

function stringifyGroupComponents(library) {
  const groups = library?.componentGroups ?? [];
  for (const group of groups) {
    if (
      !group ||
      typeof group !== "object" ||
      Array.isArray(group) ||
      typeof group.name !== "string" ||
      !Array.isArray(group.components)
    ) {
      continue;
    }
    for (const comp of group.components) {
      if (typeof comp !== "string") String(comp);
    }
  }
}

/** Official `generateCloudConfig` block. Library checks run in Wasm. */
export function cloudConfig(spec) {
  const library = spec.library;
  const options = spec.promptOptions;
  const encoded = {
    hasLibrary: Boolean(library),
    hasPromptOptions: Boolean(options),
    examples: Boolean(options?.examples),
    preamble: Boolean(options?.preamble),
    rules: Boolean(options?.additionalRules),
    library: library ? tagCloudValue(library) : { t: "u" },
  };
  const decision = JSON.parse(cloudConfigOpenui(JSON.stringify(encoded)));
  if (decision.t === "throw") {
    const componentGroups = library.componentGroups;
    for (const _group of componentGroups ?? []) break;
  }
  if (decision.t === "string") stringifyGroupComponents(library);
  if (decision.t === "err") throw new Error(decision.m);
  let config;
  if (decision.t === "version") {
    config = { libraryVersion: "0.1.0" };
  } else {
    const { components: _components, ...chatLibrary } = library;
    const promptOptions = {};
    for (const key of decision.options ?? []) {
      if (key === "examples") promptOptions.examples = options.examples;
      else if (key === "preamble") promptOptions.preamble = options.preamble;
      else if (key === "additionalRules") promptOptions.additionalRules = options.additionalRules;
    }
    config = {
      chatLibrary,
      ...(Object.keys(promptOptions).length > 0 ? { systemPromptOptions: promptOptions } : {}),
    };
  }
  const block = `]]>openui:config\n${JSON.stringify(config)}`;
  return spec.instructions ? `${block}\n${spec.instructions}` : block;
}

function encodeStepValue(value) {
  if (value === null) return { t: "null" };
  if (value === undefined) return { t: "u" };
  const type = typeof value;
  if (type === "string") return { t: "s", v: value };
  if (type === "number") {
    const tagged = encodeBuiltinValue(value);
    tagged.j = String(value);
    return tagged;
  }
  if (type === "boolean") return { t: "b", v: value };
  if (type === "symbol") return { t: "x", j: String(value), sym: true };
  if (type === "bigint" || type === "function") return { t: "x", j: String(value) };
  if (Array.isArray(value)) {
    const items = [];
    for (let index = 0; index < value.length; index += 1) {
      items.push(index in value ? encodeStepValue(value[index]) : { t: "hole" });
    }
    return { t: "a", v: items };
  }
  if (type === "object") {
    const tagged = { t: "o" };
    if (typeof value.toString === "function" && value.toString !== Object.prototype.toString) {
      try {
        tagged.j = String(value);
      } catch {
        tagged.throw = true;
      }
    }
    return tagged;
  }
  return { t: "x", throw: true };
}

/** `OpenUrl` and `ToAssistant` plans. `context` stays the original value. */
export function eagerStep(name, args) {
  const encoded = {};
  if (args && typeof args === "object") {
    if (Object.prototype.hasOwnProperty.call(args, "url")) encoded.url = encodeStepValue(args.url);
    if (Object.prototype.hasOwnProperty.call(args, "message")) {
      encoded.message = encodeStepValue(args.message);
    }
  }
  const decision = JSON.parse(eagerStepOpenui(String(name ?? ""), JSON.stringify(encoded)));
  if (decision.op === "throw") {
    String(name === "OpenUrl" ? args?.url : args?.message);
  }
  if (decision.op === "open_url") return { steps: [{ type: "open_url", url: decision.url }] };
  if (decision.op === "continue") {
    return {
      steps: [
        {
          type: "continue_conversation",
          message: decision.message,
          context: args?.context ?? undefined,
        },
      ],
    };
  }
  return { steps: [] };
}

/** `Run`, `Set`, and `Reset` decision. `op` is `run`, `set`, `reset`, or `none`. */
export function lazyStep(name, kinds) {
  const list = Array.isArray(kinds)
    ? kinds.map((kind) => (typeof kind === "string" ? kind : ""))
    : [];
  return JSON.parse(lazyStepOpenui(String(name ?? ""), JSON.stringify(list)));
}

/** Walk a pure expression. `evalNode` evaluates a nested call or component. */
export function evaluatePure(node, context, schemaCtx, evalNode) {
  const values = [];
  const astNodes = [];
  const box = (value) => {
    values.push(value);
    return values.length - 1;
  };
  const evalChild = evalNode ?? ((child) => child);
  let req = JSON.parse(evalStartOpenui(JSON.stringify(encodeEvalAst(node, astNodes))));
  try {
    for (;;) {
      if (req.done) return req.id < 0 ? undefined : values[req.id];
      let id = 0;
      if (req.need === "truthy") {
        req = JSON.parse(evalAnswerOpenui(JSON.stringify({ bit: Boolean(values[req.id]) })));
        continue;
      }
      if (req.need === "lit") id = box(astNodes[req.ast].v);
      else if (req.need === "null") id = box(null);
      else if (req.need === "undef") id = box(undefined);
      else if (req.need === "str") id = box(req.v);
      else if (req.need === "num") {
        if (req.k === "nan") id = box(NaN);
        else if (req.k === "inf") id = box(Infinity);
        else if (req.k === "-inf") id = box(-Infinity);
        else if (req.k === "-0") id = box(-0);
        else id = box(req.v);
      } else if (req.need === "bool") id = box(req.v);
      else if (req.need === "state") {
        id = box(context.extraScope?.[req.name] ?? context.getState(req.name));
      } else if (req.need === "ref") id = box(context.resolveRef(req.name));
      else if (req.need === "not") id = box(!values[req.id]);
      else if (req.need === "neg") id = box(-evalToNumber(values[req.id]));
      else if (req.need === "add") id = box(evalAdd(values[req.l], values[req.r]));
      else if (req.need === "sub")
        id = box(evalToNumber(values[req.l]) - evalToNumber(values[req.r]));
      else if (req.need === "mul")
        id = box(evalToNumber(values[req.l]) * evalToNumber(values[req.r]));
      else if (req.need === "div") {
        const right = evalToNumber(values[req.r]);
        id = box(right === 0 ? 0 : evalToNumber(values[req.l]) / right);
      } else if (req.need === "mod") {
        const right = evalToNumber(values[req.r]);
        id = box(right === 0 ? 0 : evalToNumber(values[req.l]) % right);
      } else if (req.need === "eq") id = box(values[req.l] == values[req.r]);
      else if (req.need === "ne") id = box(values[req.l] != values[req.r]);
      else if (req.need === "gt")
        id = box(evalToNumber(values[req.l]) > evalToNumber(values[req.r]));
      else if (req.need === "lt")
        id = box(evalToNumber(values[req.l]) < evalToNumber(values[req.r]));
      else if (req.need === "ge")
        id = box(evalToNumber(values[req.l]) >= evalToNumber(values[req.r]));
      else if (req.need === "le")
        id = box(evalToNumber(values[req.l]) <= evalToNumber(values[req.r]));
      else if (req.need === "member") id = box(evalMember(values[req.id], req.field));
      else if (req.need === "index") id = box(evalIndex(values[req.obj], values[req.idx]));
      else if (req.need === "arr") id = box(req.ids.map((item) => values[item]));
      else if (req.need === "obj") {
        id = box(Object.fromEntries(req.entries.map(([key, item]) => [key, values[item]])));
      } else if (req.need === "assign") {
        const ast = astNodes[req.ast];
        id = box({ __reactive: "assign", target: ast.target, expr: ast.value });
      } else if (req.need === "eval") id = box(evalChild(astNodes[req.ast]));
      else id = box(undefined);
      req = JSON.parse(evalAnswerOpenui(JSON.stringify({ id })));
    }
  } catch (error) {
    evalCancelOpenui();
    throw error;
  }
}

function encodeLiteralInput(value) {
  if (value === null) return ["z"];
  if (value === undefined) return ["u"];
  if (typeof value === "string") return ["s", value];
  if (typeof value === "number") {
    if (Number.isNaN(value)) return ["n", ["nan"]];
    if (value === Infinity) return ["n", ["inf"]];
    if (value === -Infinity) return ["n", ["-inf"]];
    if (Object.is(value, -0)) return ["n", ["-0"]];
    return ["n", ["n", value]];
  }
  if (typeof value === "boolean") return ["b", value];
  if (Array.isArray(value)) {
    const items = [];
    for (let i = 0; i < value.length; i++)
      items.push(i in value ? encodeLiteralInput(value[i]) : ["h"]);
    return ["a", items];
  }
  if (typeof value === "object") {
    return ["o", Object.entries(value).map(([key, item]) => [key, encodeLiteralInput(item)])];
  }
  return ["x"];
}

function reviveNum(tag) {
  if (tag[0] === "nan") return NaN;
  if (tag[0] === "inf") return Infinity;
  if (tag[0] === "-inf") return -Infinity;
  if (tag[0] === "-0") return -0;
  return tag[1];
}

function reviveValue(tag) {
  if (tag[0] === "u") return undefined;
  if (tag[0] === "z" || tag[0] === "x") return null;
  if (tag[0] === "s" || tag[0] === "b") return tag[1];
  if (tag[0] === "n") return reviveNum(tag[1]);
  if (tag[0] === "a") return reviveList(tag[1], reviveValue);
  if (tag[0] === "o")
    return Object.fromEntries(tag[1].map(([key, item]) => [key, reviveValue(item)]));
  return null;
}

function reviveList(items, revive) {
  const out = [];
  for (const item of items) {
    if (item === null) out.length += 1;
    else out.push(revive(item));
  }
  return out;
}

function reviveAst(node) {
  if (node === null) return { k: "Null" };
  if (node[0] === "Null") return { k: "Null" };
  if (node[0] === "Str") return { k: "Str", v: node[1] };
  if (node[0] === "Num") return { k: "Num", v: reviveNum(node[1]) };
  if (node[0] === "Bool") return { k: "Bool", v: node[1] };
  if (node[0] === "Arr") return { k: "Arr", els: reviveList(node[1], reviveAst) };
  if (node[0] === "Obj")
    return {
      k: "Obj",
      entries: node[1].map(([key, item]) => [key, reviveAst(item)]),
    };
  return { k: "Null" };
}

function encodeAstLiteral(node) {
  switch (node.k) {
    case "Str":
    case "Num":
    case "Bool":
      return [node.k, encodeLiteralInput(node.v)];
    case "Null":
      return ["Null"];
    case "Arr":
      return ["Arr", node.els.map((item) => encodeAstLiteral(item))];
    case "Obj":
      return ["Obj", node.entries.map(([key, item]) => [key, encodeAstLiteral(item)])];
    default:
      return ["Other"];
  }
}

/** Convert a JavaScript value into a literal AST node. */
export function toLiteralAST(value) {
  return reviveAst(JSON.parse(toLiteralAstOpenui(JSON.stringify(encodeLiteralInput(value)))));
}

function encodeTree(value, pool, seen) {
  if (value === null) return { t: "z" };
  if (value === undefined) return { t: "u" };
  if (typeof value === "string") return { t: "s", v: value };
  if (typeof value === "number") {
    if (Number.isNaN(value)) return { t: "nan" };
    if (value === Infinity) return { t: "inf" };
    if (value === -Infinity) return { t: "-inf" };
    if (Object.is(value, -0)) return { t: "n0" };
    return { t: "n", v: value };
  }
  if (typeof value === "boolean") return { t: "b", v: value };
  if (typeof value === "object") {
    if (Array.isArray(value)) {
      const items = [];
      for (let index = 0; index < value.length; index += 1) {
        items.push(index in value ? encodeTree(value[index], pool, seen) : { t: "h" });
      }
      return { t: "a", v: items };
    }
    const proto = Object.getPrototypeOf(value);
    if (proto === Object.prototype || proto === null) {
      return {
        t: "o",
        v: Object.entries(value).map(([key, item]) => [key, encodeTree(item, pool, seen)]),
      };
    }
  }
  if (seen.has(value)) return { t: "x", i: seen.get(value) };
  const id = pool.length;
  pool.push(value);
  seen.set(value, id);
  const type = typeof value;
  const label = type === "function" || type === "symbol" || type === "bigint" ? type : "object";
  return { t: "x", i: id, j: label };
}

function decodeTree(node, pool) {
  if (!node || typeof node !== "object") return undefined;
  if (node.t === "z") return null;
  if (node.t === "u") return undefined;
  if (node.t === "s" || node.t === "b" || node.t === "n") return node.v;
  if (node.t === "nan") return NaN;
  if (node.t === "inf") return Infinity;
  if (node.t === "-inf") return -Infinity;
  if (node.t === "n0") return -0;
  if (node.t === "x") return pool[node.i];
  if (node.t === "a") {
    const out = [];
    for (const item of node.v ?? []) {
      if (item && item.t === "h") out.length += 1;
      else out.push(decodeTree(item, pool));
    }
    return out;
  }
  if (node.t === "o") {
    const out = {};
    for (const pair of node.v ?? []) {
      if (Array.isArray(pair)) out[pair[0]] = decodeTree(pair[1], pool);
    }
    return out;
  }
  return undefined;
}

function substThrow(why) {
  if (why === "null") throw new TypeError("Cannot read properties of null (reading 'k')");
  if (why === "undef") throw new TypeError("Cannot read properties of undefined (reading 'k')");
  if (why === "map") throw new TypeError("Cannot read properties of undefined (reading 'map')");
  if (why === "map-null") throw new TypeError("Cannot read properties of null (reading 'map')");
  if (why === "map-fn") throw new TypeError("node.els.map is not a function");
  if (why === "find") throw new TypeError("Cannot read properties of undefined (reading 'find')");
  if (why === "find-null") throw new TypeError("Cannot read properties of null (reading 'find')");
  if (why === "find-fn") throw new TypeError("entries.find is not a function");
  throw new TypeError("is not iterable (cannot read property Symbol(Symbol.iterator))");
}

/** Replace `Ref(varName)` with the literal AST of `value`. */
export function substituteRef(node, varName, value) {
  void node.k;
  const literal = toLiteralAST(value);
  const pool = [];
  const seen = new Map();
  const encoded = JSON.parse(
    substituteRefOpenui(
      JSON.stringify(encodeTree(node, pool, seen)),
      JSON.stringify(encodeTree(varName, pool, seen)),
      JSON.stringify(encodeTree(literal, pool, seen)),
    ),
  );
  if (encoded && encoded.t === "throw") {
    if (encoded.why === "iter") {
      throw new TypeError(
        `${encoded.j} is not iterable (cannot read property Symbol(Symbol.iterator))`,
      );
    }
    substThrow(encoded.why);
  }
  return decodeTree(encoded, pool);
}

/** Read a literal AST node. Returns `{ v }` or `undefined`. */
export function literalValue(node) {
  const encoded = JSON.parse(literalValueOpenui(JSON.stringify(encodeAstLiteral(node))));
  if (encoded[0] !== "ok") return undefined;
  return { v: reviveValue(encoded[1]) };
}

function walkEdge(current, step, walk) {
  if (step === "args" || step === "els" || step === "entries") {
    const items = step === "args" ? current.args : step === "els" ? current.els : current.entries;
    const count = items.length;
    for (let i = 0; i < count; i++) {
      if (!(i in items)) continue;
      walk(step === "entries" ? items[i][1] : items[i]);
    }
    return;
  }
  if (step === "props") {
    for (const value of Object.values(current.mappedProps ?? {})) walk(value);
    return;
  }
  walk(current[step]);
}

/** Visit `node`, then each child in official order. `visit` receives the live node. */
export function walkAST(node, visit) {
  const walk = (current) => {
    visit(current);
    const kind = current.k;
    const steps = typeof kind === "string" ? JSON.parse(walkPlanOpenui(kind)) : [];
    for (const step of steps) walkEdge(current, step, walk);
  };
  walk(node);
}

/** Merge a patch onto an existing program. Unreachable statements are dropped. */
export function mergeStatements(existing, patch, rootId) {
  if (typeof existing !== "string" || typeof patch !== "string") {
    existing.trim();
    patch.trim();
  }
  if (rootId === undefined) return mergeStatementsOpenui(existing, patch, "", 0);
  return mergeStatementsOpenui(existing, patch, String(rootId), 1);
}

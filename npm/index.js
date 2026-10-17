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
    if (Object.prototype.hasOwnProperty.call(item, "arg")) return { type: item.type, arg: item.arg };
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
    if (Object.prototype.hasOwnProperty.call(item, "i")) result.push({ type: item.type, arg: entries[item.i][1] });
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
    return { t: "a", v: value.map(tagValue), host: encodeBound(parseFloat(String(value))) };
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
  const code = builtinCheckOpenui(kind, JSON.stringify(tagValue(value)), JSON.stringify(encodeBound(arg)));
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

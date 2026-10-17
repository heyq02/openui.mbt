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

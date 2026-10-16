import { wasmBase64 } from './parser.wasm.js';

const compileOptions = {
  builtins: ['js-string'],
  importedStringConstants: '_',
};

function wasmBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

const wasmModule = new WebAssembly.Module(
  wasmBytes(wasmBase64),
  compileOptions,
);
const instance = new WebAssembly.Instance(wasmModule);
const {
  parse_openui: parseOpenui,
  tokenize_openui: tokenizeOpenui,
  materialize_openui: materializeOpenui,
  stream_open: streamOpen,
  stream_push: streamPush,
  stream_set: streamSet,
  stream_finish: streamFinish,
  stream_close: streamClose,
} = instance.exports;

/** Parse a complete OpenUI Lang program. Statement ASTs use the official `k` field. */
export function parseProgram(source) {
  return JSON.parse(parseOpenui(source ?? ''));
}

/** Tokenize OpenUI Lang source. */
export function tokenize(source) {
  return JSON.parse(tokenizeOpenui(source ?? ''));
}

/**
 * Materialize source against a library JSON Schema.
 * Returns the element tree plus errors, unresolved, orphaned, and incomplete.
 */
export function materializeProgram(source, schema, rootName = '') {
  return JSON.parse(
    materializeOpenui(source ?? '', schema ?? '{}', rootName ?? ''),
  );
}

function readResult(json) {
  return JSON.parse(json);
}

/**
 * Streaming parser. Each push or set reparses the buffer.
 * Before finish, an unfinished line is held back.
 * finish checks the whole buffer. dispose drops the Wasm session.
 */
export function createStream(schema, rootName = '') {
  const id = streamOpen(schema ?? '{}', rootName ?? '');
  return {
    push(chunk) {
      return readResult(streamPush(id, chunk ?? ''));
    },
    set(text) {
      return readResult(streamSet(id, text ?? ''));
    },
    finish() {
      return readResult(streamFinish(id));
    },
    dispose() {
      streamClose(id);
    },
  };
}

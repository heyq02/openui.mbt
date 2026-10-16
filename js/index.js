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
const instance = new WebAssembly.Instance(wasmModule);
const { parse_openui: parseOpenui, tokenize_openui: tokenizeOpenui } = instance.exports;

/** Parse a complete OpenUI Lang program. Statement ASTs use the official `k` field. */
export function parseProgram(source) {
  return JSON.parse(parseOpenui(source ?? ""));
}

/** Tokenize OpenUI Lang source. */
export function tokenize(source) {
  return JSON.parse(tokenizeOpenui(source ?? ""));
}

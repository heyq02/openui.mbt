import { readFile, writeFile, copyFile } from "node:fs/promises";
import { gzipSync } from "node:zlib";
import { performance } from "node:perf_hooks";

const wasmPath = new URL(
  "../../_build/wasm-gc/release/build/ffi/ffi.wasm",
  import.meta.url,
);
const samplePath = new URL("../signup.openui", import.meta.url);
const bytes = await readFile(wasmPath);
const sample = await readFile(samplePath, "utf8");
const { instance } = await WebAssembly.instantiate(bytes, {}, {
  builtins: ["js-string"],
  importedStringConstants: "_",
});
const { parse_openui } = instance.exports;

const parsed = JSON.parse(parse_openui(sample));
if (parsed.statements.length !== 8 || parsed.errors.length !== 0) {
  throw new Error(
    `signup sample mismatch: ${parsed.statements.length} statements, ${parsed.errors.length} errors`,
  );
}

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
};

const time = (source, iterations) => {
  for (let i = 0; i < 20; i++) parse_openui(source);
  const samples = [];
  for (let i = 0; i < iterations; i++) {
    const start = performance.now();
    parse_openui(source);
    samples.push(performance.now() - start);
  }
  return median(samples);
};

const repeated = Array.from({ length: 50 }, () => sample.trimEnd()).join("\n") + "\n";
const baseline = {
  moon: "0.1.20261012",
  target: "wasm-gc",
  optimize: "release",
  wasmBytes: bytes.length,
  gzipBytes: gzipSync(bytes).length,
  signupStatements: parsed.statements.length,
  signupErrors: parsed.errors.length,
  signupMedianMs: Number(time(sample, 200).toFixed(4)),
  signupRepeated50MedianMs: Number(time(repeated, 50).toFixed(4)),
  host: "node",
  node: process.version,
};

await copyFile(wasmPath, new URL("./parser.wasm", import.meta.url));
await writeFile(
  new URL("./baseline.json", import.meta.url),
  JSON.stringify(baseline, null, 2) + "\n",
);
console.log(JSON.stringify(baseline, null, 2));

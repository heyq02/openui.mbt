import "./index.css";

const base = "/openui.mbt/";
const source = document.querySelector("#source");
const stats = document.querySelector("#stats");
const status = document.querySelector("#status");
const json = document.querySelector("#json");

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
};

const stat = (label, value) => {
  const node = document.createElement("div");
  node.className = "stat";
  node.textContent = `${label} ${value}`;
  return node;
};

const showError = (error) => {
  status.className = "error";
  status.textContent = error instanceof Error ? error.message : String(error);
};

try {
  const wasmResponse = await fetch(`${base}parser.wasm`);
  if (!wasmResponse.ok) {
    throw new Error(`无法加载 parser.wasm（${wasmResponse.status}）`);
  }
  const wasmBytes = new Uint8Array(await wasmResponse.arrayBuffer());
  const gzipStream = new Blob([wasmBytes])
    .stream()
    .pipeThrough(new CompressionStream("gzip"));
  const gzipBytes = (await new Response(gzipStream).arrayBuffer()).byteLength;
  const { instance } = await WebAssembly.instantiate(wasmBytes, {}, {
    builtins: ["js-string"],
    importedStringConstants: "_",
  });
  const { parse_openui } = instance.exports;
  const sampleResponse = await fetch(`${base}signup.openui`);
  source.value = await sampleResponse.text();

  const parseNow = () => {
    const text = source.value;
    for (let i = 0; i < 10; i++) parse_openui(text);
    const samples = [];
    let rendered = "";
    for (let i = 0; i < 100; i++) {
      const start = performance.now();
      rendered = parse_openui(text);
      samples.push(performance.now() - start);
    }
    const result = JSON.parse(rendered);
    json.textContent = rendered;
    stats.replaceChildren(
      stat("语句", String(result.statements.length)),
      stat("错误", String(result.errors.length)),
      stat("中位耗时", `${median(samples).toFixed(3)} ms`),
      stat("Wasm", `${wasmBytes.byteLength} B`),
      stat("gzip", `${gzipBytes} B`),
    );
    status.className = result.errors.length === 0 ? "" : "error";
    status.textContent =
      result.errors.length === 0
        ? `解析完成，入口是 ${result.statements[0]?.id ?? "无"}。`
        : result.errors
            .map((err) => `${err.line}:${err.column} ${err.message}`)
            .join("\n");
  };

  document.querySelector("#run").addEventListener("click", parseNow);
  parseNow();
} catch (error) {
  showError(error);
}

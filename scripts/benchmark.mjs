import { execFileSync, spawn } from "node:child_process";
import {
  cpSync,
  createReadStream,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { dirname, extname, join, resolve } from "node:path";
import { performance } from "node:perf_hooks";
import { fileURLToPath, pathToFileURL } from "node:url";
import { brotliCompressSync, gzipSync } from "node:zlib";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const supported = "1.0.1";
const cache = join(tmpdir(), "openui-mbt-compare");
const tarball = join(cache, "openuidev-lang-core-1.0.1.tgz");
const web = join(repo, "web");
const skipDemo = process.argv.includes("--skip-demo");
const chromePath =
  process.env.CHROME_PATH ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function percentile(values, p) {
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[Math.max(0, index)];
}

function round(value) {
  return Number(value.toFixed(4));
}

function stats(samples) {
  return {
    samples: samples.length,
    medianMs: round(median(samples)),
    p95Ms: round(percentile(samples, 95)),
    minMs: round(Math.min(...samples)),
  };
}

function time(run, warmup, iterations) {
  for (let index = 0; index < warmup; index += 1) run();
  const samples = [];
  for (let index = 0; index < iterations; index += 1) {
    const start = performance.now();
    run();
    samples.push(performance.now() - start);
  }
  return stats(samples);
}

function bytesOf(buf) {
  const raw = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
  return {
    raw: raw.length,
    gzip: gzipSync(raw).length,
    brotli: brotliCompressSync(raw).length,
  };
}

function fileBytes(path) {
  return bytesOf(readFileSync(path));
}

async function ensureOfficialPackage() {
  mkdirSync(cache, { recursive: true });
  if (!existsSync(tarball)) {
    const response = await fetch(
      "https://registry.npmjs.org/@openuidev/lang-core/-/lang-core-1.0.1.tgz",
    );
    if (!response.ok) {
      throw new Error(`failed to download lang-core ${supported}: ${response.status}`);
    }
    writeFileSync(tarball, Buffer.from(await response.arrayBuffer()));
  }
  const extract = join(cache, "package");
  rmSync(extract, { recursive: true, force: true });
  execFileSync("tar", ["-xzf", tarball, "-C", cache]);
  return extract;
}

function linkDependency(tree, name, target) {
  const dest = join(tree, "node_modules", name);
  mkdirSync(dirname(dest), { recursive: true });
  symlinkSync(target, dest, "dir");
}

function prepareTrees(officialPackage) {
  const zod = join(web, "node_modules/zod");
  if (!existsSync(zod)) {
    throw new Error("Missing web/node_modules/zod. Run npm ci in web/ first.");
  }
  const root = mkdtempSync(join(tmpdir(), "openui-bench-"));
  const officialTree = join(root, "official");
  const patchedTree = join(root, "patched");
  for (const tree of [officialTree, patchedTree]) {
    cpSync(officialPackage, join(tree, "node_modules/@openuidev/lang-core"), {
      recursive: true,
    });
    linkDependency(tree, "zod", zod);
  }
  const scoped = join(patchedTree, "node_modules/@heyq02");
  mkdirSync(scoped, { recursive: true });
  symlinkSync(join(repo, "npm"), join(scoped, "openui.mbt"), "dir");
  execFileSync("node", [join(repo, "npm/cli.js"), "patch"], {
    cwd: patchedTree,
    stdio: "inherit",
  });
  return { root, officialTree, patchedTree };
}

async function loadLang(tree) {
  return import(pathToFileURL(join(tree, "node_modules/@openuidev/lang-core/dist/index.mjs")).href);
}

function librarySchema(lang, zod) {
  const { z } = zod;
  const component = (name, shape) =>
    lang.defineComponent({
      name,
      props: z.object(shape),
      description: name,
      component: () => null,
    });
  const any = z.any();
  return lang
    .createLibrary({
      components: [
        component("Stack", { children: z.array(any) }),
        component("TextContent", {
          text: z.string(),
          size: z.string().optional(),
        }),
        component("Form", {
          name: z.string(),
          buttons: any.optional(),
          fields: z.array(any),
        }),
        component("FormControl", {
          label: z.string(),
          control: any.optional(),
        }),
        component("Input", {
          name: z.string().optional(),
          placeholder: z.string().optional(),
          type: z.string().optional(),
          validation: z.record(z.string(), any).optional(),
        }),
        component("Buttons", {
          buttons: z.array(any),
          direction: z.string().optional(),
        }),
        component("Button", {
          label: z.string(),
          action: any.optional(),
          variant: z.string().optional(),
        }),
      ],
    })
    .toJSONSchema();
}

function documentOf(count) {
  const children = [];
  const lines = [];
  for (let index = 0; index < count; index += 1) {
    const id = `field${index}`;
    children.push(id);
    lines.push(`${id} = TextContent("Field ${index}", "medium")`);
  }
  lines.unshift(`root = Stack([${children.join(", ")}])`);
  return `${lines.join("\n")}\n`;
}

function nestedDocumentOf(count) {
  const sections = [];
  const lines = [];
  for (let index = 0; index < count; index += 1) {
    const field = `field${index}`;
    const section = `section${index}`;
    sections.push(section);
    lines.push(`${section} = FormControl("Section ${index}", ${field})`);
    lines.push(`${field} = TextContent("Field ${index}", "medium")`);
  }
  lines.unshift(`root = Stack([${sections.join(", ")}])`);
  return `${lines.join("\n")}\n`;
}

function stream(parser, source) {
  const lines = source.split("\n");
  let result;
  for (let index = 0; index < lines.length; index += 1) {
    const last = index === lines.length - 1;
    const chunk = last ? lines[index] : `${lines[index]}\n`;
    result = parser.push(chunk, last);
  }
  return result;
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    const copy = {};
    for (const key of Object.keys(value).sort()) copy[key] = canonicalize(value[key]);
    return copy;
  }
  return value ?? null;
}

function fingerprint(result) {
  return JSON.stringify(canonicalize(result));
}

function sameFingerprint(actual, expected) {
  return JSON.stringify(actual) === JSON.stringify(expected);
}

function coldLoads(modulePath, runs) {
  const script = join(tmpdir(), "openui-bench-load.mjs");
  writeFileSync(
    script,
    `import { performance } from 'node:perf_hooks';
const started = performance.now();
await import(${JSON.stringify(modulePath)});
console.log(performance.now() - started);
`,
  );
  const samples = [];
  for (let index = 0; index < runs; index += 1) {
    const output = execFileSync(process.execPath, [script], {
      encoding: "utf8",
    });
    samples.push(Number(output.trim()));
  }
  return stats(samples);
}

function packageSizes(officialTree, patchedTree) {
  const officialMjs = fileBytes(
    join(officialTree, "node_modules/@openuidev/lang-core/dist/index.mjs"),
  );
  const officialCjs = fileBytes(
    join(officialTree, "node_modules/@openuidev/lang-core/dist/index.cjs"),
  );
  const patchedMjs = fileBytes(
    join(patchedTree, "node_modules/@openuidev/lang-core/dist/index.mjs"),
  );
  const patchedCjs = fileBytes(
    join(patchedTree, "node_modules/@openuidev/lang-core/dist/index.cjs"),
  );
  const runtimeJs = fileBytes(join(repo, "npm/index.js"));
  const wasmJs = fileBytes(join(repo, "npm/parser.wasm.js"));
  const wasmBase64 = readFileSync(join(repo, "npm/parser.wasm.js"), "utf8").match(
    /export const wasmBase64 = ("(?:\\.|[^"\\])*");/,
  );
  if (!wasmBase64) throw new Error("parser.wasm.js is missing wasmBase64");
  const wasm = Buffer.from(JSON.parse(wasmBase64[1]), "base64");
  return {
    official: { indexMjs: officialMjs, indexCjs: officialCjs },
    patchedLangCore: { indexMjs: patchedMjs, indexCjs: patchedCjs },
    moonbitRuntime: {
      indexJs: runtimeJs,
      parserWasmJs: wasmJs,
      wasmBinary: bytesOf(wasm),
    },
    shippedEsm: {
      official: officialMjs,
      patchedPlusRuntime: bytesOf(
        Buffer.concat([
          readFileSync(join(patchedTree, "node_modules/@openuidev/lang-core/dist/index.mjs")),
          readFileSync(join(repo, "npm/index.js")),
          readFileSync(join(repo, "npm/parser.wasm.js")),
        ]),
      ),
    },
  };
}

function parseBench(official, patched, schema) {
  const signup = readFileSync(join(web, "signup.openui"), "utf8");
  const medium = documentOf(50);
  const large = documentOf(400);
  const cases = [
    {
      name: "signup",
      source: signup,
      warmup: 20,
      iterations: 100,
      streamWarmup: 5,
      streamIterations: 20,
    },
    {
      name: "50-fields",
      source: medium,
      warmup: 10,
      iterations: 40,
      streamWarmup: 3,
      streamIterations: 10,
    },
    {
      name: "50-nested",
      source: nestedDocumentOf(50),
      warmup: 8,
      iterations: 20,
      streamWarmup: 2,
      streamIterations: 8,
    },
    {
      name: "400-fields",
      source: large,
      warmup: 5,
      iterations: 20,
      streamWarmup: 1,
      streamIterations: 5,
    },
    {
      name: "4000-fields",
      source: documentOf(4000),
      warmup: 3,
      iterations: 15,
      streamWarmup: 1,
      streamIterations: 3,
    },
  ];
  const rows = [];
  for (const item of cases) {
    const officialParsed = official.createParser(schema).parse(item.source);
    const patchedParsed = patched.createParser(schema).parse(item.source);
    const officialOnce = fingerprint(officialParsed);
    const patchedOnce = fingerprint(patchedParsed);
    const row = {
      name: item.name,
      bytes: Buffer.byteLength(item.source),
      official: {
        typeName: officialParsed.root?.typeName ?? null,
        statements: officialParsed.meta?.statementCount ?? 0,
        errors: (officialParsed.meta?.errors ?? []).length,
        incomplete: Boolean(officialParsed.meta?.incomplete),
      },
      patched: {
        typeName: patchedParsed.root?.typeName ?? null,
        statements: patchedParsed.meta?.statementCount ?? 0,
        errors: (patchedParsed.meta?.errors ?? []).length,
        incomplete: Boolean(patchedParsed.meta?.incomplete),
      },
      match: sameFingerprint(patchedOnce, officialOnce),
      createAndParse: {
        official: time(
          () => official.createParser(schema).parse(item.source),
          item.warmup,
          item.iterations,
        ),
        patched: time(
          () => patched.createParser(schema).parse(item.source),
          item.warmup,
          item.iterations,
        ),
      },
    };
    const officialParser = official.createParser(schema);
    const patchedParser = patched.createParser(schema);
    row.parseOnly = {
      official: time(() => officialParser.parse(item.source), item.warmup, item.iterations),
      patched: time(() => patchedParser.parse(item.source), item.warmup, item.iterations),
    };
    if (item.streamIterations > 0) {
      const officialStream = fingerprint(
        stream(official.createStreamingParser(schema), item.source),
      );
      const patchedStream = fingerprint(
        stream(patched.createStreamingParser(schema), item.source),
      );
      row.streamMatch = sameFingerprint(patchedStream, officialStream);
      row.streamAgrees = {
        official: sameFingerprint(officialOnce, officialStream),
        patched: sameFingerprint(patchedOnce, patchedStream),
      };
      row.stream = {
        official: time(
          () => stream(official.createStreamingParser(schema), item.source),
          item.streamWarmup,
          item.streamIterations,
        ),
        patched: time(
          () => stream(patched.createStreamingParser(schema), item.source),
          item.streamWarmup,
          item.streamIterations,
        ),
      };
    }
    rows.push(row);
  }
  return rows;
}

function walkAssets(root) {
  const files = [];
  const visit = (dir) => {
    for (const name of readdirSync(dir)) {
      const path = join(dir, name);
      if (statSync(path).isDirectory()) visit(path);
      else files.push(path);
    }
  };
  visit(root);
  const groups = { code: [], map: [], other: [] };
  let codeRaw = 0;
  let codeGzip = 0;
  for (const path of files) {
    const rel = path.slice(root.length + 1);
    const size = fileBytes(path);
    const ext = extname(path);
    const kind =
      ext === ".map"
        ? "map"
        : ext === ".html" || ext === ".js" || ext === ".css"
          ? "code"
          : "other";
    groups[kind].push({ path: rel, ...size });
    if (kind === "code") {
      codeRaw += size.raw;
      codeGzip += size.gzip;
    }
  }
  return {
    files: groups,
    codeRaw,
    codeGzip,
  };
}

function buildDemo(label, distName) {
  const dist = join(repo, ".bench", distName);
  rmSync(dist, { recursive: true, force: true });
  mkdirSync(dist, { recursive: true });
  execFileSync(join(web, "node_modules/.bin/rsbuild"), ["build", "-c", "rsbuild.bench.mjs"], {
    cwd: web,
    env: { ...process.env, BENCH_DIST: dist },
    stdio: "inherit",
  });
  return { label, dist, ...walkAssets(dist) };
}

function installDist(tree) {
  const dest = join(web, "node_modules/@openuidev/lang-core/dist");
  for (const name of ["index.mjs", "index.cjs"]) {
    cpSync(join(tree, "node_modules/@openuidev/lang-core/dist", name), join(dest, name));
  }
}

function serve(root) {
  const types = {
    ".html": "text/html",
    ".js": "text/javascript",
    ".css": "text/css",
    ".svg": "image/svg+xml",
    ".woff2": "font/woff2",
  };
  const server = createServer((request, response) => {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    const relative = decodeURIComponent(url.pathname).replace(/^\/+/, "");
    const path = join(root, relative || "bench.html");
    if (!path.startsWith(root) || !existsSync(path) || statSync(path).isDirectory()) {
      response.writeHead(404);
      response.end("not found");
      return;
    }
    response.writeHead(200, {
      "content-type": types[extname(path)] ?? "application/octet-stream",
      "cache-control": "no-store",
    });
    createReadStream(path).pipe(response);
  });
  return new Promise((resolveServer) => {
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      resolveServer({
        server,
        port: typeof address === "object" && address ? address.port : 0,
      });
    });
  });
}

function cdp(ws, id, method, params = {}) {
  return new Promise((resolveMessage, reject) => {
    const onMessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.id !== id) return;
      ws.removeEventListener("message", onMessage);
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolveMessage(message.result);
    };
    ws.addEventListener("message", onMessage);
    ws.send(JSON.stringify({ id, method, params }));
  });
}

function freePort() {
  return new Promise((resolvePort) => {
    const probe = createServer();
    probe.listen(0, "127.0.0.1", () => {
      const address = probe.address();
      const port = typeof address === "object" && address ? address.port : 0;
      probe.close(() => resolvePort(port));
    });
  });
}

async function pageSamples(url, runs) {
  const debuggingPort = await freePort();
  const chrome = spawn(
    chromePath,
    [
      "--headless=new",
      "--disable-gpu",
      "--no-first-run",
      `--user-data-dir=${join(tmpdir(), `openui-bench-chrome-${process.pid}-${debuggingPort}`)}`,
      `--remote-debugging-port=${debuggingPort}`,
      "about:blank",
    ],
    { stdio: ["ignore", "pipe", "pipe"] },
  );
  const port = await new Promise((resolvePort, reject) => {
    const timer = setTimeout(
      () => reject(new Error("Chrome did not open a debugging port")),
      15000,
    );
    const onData = (chunk) => {
      const match = String(chunk).match(/DevTools listening on ws:\/\/127\.0\.0\.1:(\d+)/);
      if (!match) return;
      clearTimeout(timer);
      resolvePort(Number(match[1]));
    };
    chrome.stderr.on("data", onData);
    chrome.stdout.on("data", onData);
    chrome.on("exit", () => {
      clearTimeout(timer);
      reject(new Error("Chrome exited before opening a debugging port"));
    });
  });
  try {
    const listed = await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: "PUT" });
    const page = await listed.json();
    const ws = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((resolveOpen) => {
      ws.addEventListener("open", resolveOpen, { once: true });
    });
    let messageId = 1;
    await cdp(ws, messageId, "Page.enable");
    messageId += 1;
    await cdp(ws, messageId, "Runtime.enable");
    messageId += 1;
    const samples = [];
    for (let index = 0; index < runs; index += 1) {
      await cdp(ws, messageId, "Page.navigate", { url });
      messageId += 1;
      const started = Date.now();
      let reading = null;
      while (Date.now() - started < 20000) {
        const evaluated = await cdp(ws, messageId, "Runtime.evaluate", {
          expression:
            'document.documentElement.dataset.bench === "ready" ? JSON.stringify({ bench: document.documentElement.dataset.bench, ms: document.documentElement.dataset.benchMs, root: document.documentElement.dataset.benchRoot, statements: document.documentElement.dataset.benchStatements }) : ""',
          returnByValue: true,
        });
        messageId += 1;
        if (evaluated.result?.value) {
          reading = JSON.parse(evaluated.result.value);
          break;
        }
        await new Promise((resolveWait) => setTimeout(resolveWait, 50));
      }
      if (!reading) throw new Error(`page did not finish: ${url}`);
      samples.push(reading);
    }
    ws.close();
    return samples;
  } finally {
    chrome.kill();
  }
}

const officialPackage = await ensureOfficialPackage();
const trees = prepareTrees(officialPackage);
const official = await loadLang(trees.officialTree);
const patched = await loadLang(trees.patchedTree);
const zod = await import(pathToFileURL(join(web, "node_modules/zod/index.js")).href);
const schema = librarySchema(official, zod);

const report = {
  langCore: supported,
  notes: [
    "官方 is @openuidev/lang-core@1.0.1. patch 后 is the same package after oui.mbt patch.",
    "createParser().parse and createStreamingParser() materialize in Wasm. Renderer stays official.",
    "Workspace test wall time is not measured. Most packages never import the parser, and Vitest startup dominates that number.",
    "shippedEsm concatenates files. The demo bundle is the size a page actually downloads.",
    "Page time is navigation start to the frame after the official Renderer commits signup.openui. The parse page sends the whole document once. The stream page feeds it line by line through createStreamingParser, then paints the finished tree. Both include downloading the local bundle, evaluating JavaScript, compiling Wasm, and painting.",
  ],
  sizes: packageSizes(trees.officialTree, trees.patchedTree),
  coldImport: {
    official: coldLoads(
      pathToFileURL(join(trees.officialTree, "node_modules/@openuidev/lang-core/dist/index.mjs"))
        .href,
      5,
    ),
    patched: coldLoads(
      pathToFileURL(join(trees.patchedTree, "node_modules/@openuidev/lang-core/dist/index.mjs"))
        .href,
      5,
    ),
  },
  parse: parseBench(official, patched, schema),
};

if (!skipDemo) {
  if (!existsSync(join(web, "node_modules/.bin/rsbuild"))) {
    throw new Error("Missing web/node_modules. Run npm ci in web/ first.");
  }
  if (!existsSync(chromePath)) {
    report.demo = { skipped: `Chrome not found at ${chromePath}` };
  } else {
    const backup = mkdtempSync(join(tmpdir(), "openui-lang-backup-"));
    const installed = join(web, "node_modules/@openuidev/lang-core/dist");
    for (const name of ["index.mjs", "index.cjs"]) {
      cpSync(join(installed, name), join(backup, name));
    }
    try {
      installDist(trees.officialTree);
      const officialDemo = buildDemo("official", "demo-official");
      installDist(trees.patchedTree);
      const patchedDemo = buildDemo("patched", "demo-patched");
      const officialServer = await serve(officialDemo.dist);
      const patchedServer = await serve(patchedDemo.dist);
      try {
        const notable = (demo) =>
          demo.files.code.filter(
            (file) =>
              file.raw >= 20000 || file.path.endsWith(".html") || file.path.includes("bench."),
          );
        report.demo = {
          official: {
            codeRaw: officialDemo.codeRaw,
            codeGzip: officialDemo.codeGzip,
            files: notable(officialDemo),
          },
          patched: {
            codeRaw: patchedDemo.codeRaw,
            codeGzip: patchedDemo.codeGzip,
            files: notable(patchedDemo),
          },
          page: {
            official: await pageSamples(`http://127.0.0.1:${officialServer.port}/bench.html`, 7),
            patched: await pageSamples(`http://127.0.0.1:${patchedServer.port}/bench.html`, 7),
          },
          pageStream: {
            official: await pageSamples(
              `http://127.0.0.1:${officialServer.port}/bench.html?stream=1`,
              7,
            ),
            patched: await pageSamples(
              `http://127.0.0.1:${patchedServer.port}/bench.html?stream=1`,
              7,
            ),
          },
        };
      } finally {
        officialServer.server.close();
        patchedServer.server.close();
      }
    } finally {
      for (const name of ["index.mjs", "index.cjs"]) {
        cpSync(join(backup, name), join(installed, name));
      }
      rmSync(backup, { recursive: true, force: true });
    }
  }
}

rmSync(trees.root, { recursive: true, force: true });
mkdirSync(join(repo, ".bench"), { recursive: true });
writeFileSync(join(repo, ".bench/report.json"), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
if (
  report.parse.some(
    (row) =>
      !row.match ||
      (row.stream &&
        (!row.streamMatch || !row.streamAgrees.official || !row.streamAgrees.patched)),
  )
) {
  process.exit(1);
}

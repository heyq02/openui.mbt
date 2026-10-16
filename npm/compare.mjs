import { execFileSync } from 'node:child_process';
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { performance } from 'node:perf_hooks';
import { gzipSync } from 'node:zlib';
import { pathToFileURL, fileURLToPath } from 'node:url';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const supported = '1.0.1';
const cache = join(tmpdir(), 'openui-mbt-compare');
const tarball = join(cache, 'openuidev-lang-core-1.0.1.tgz');

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
}

async function ensureOfficialPackage() {
  mkdirSync(cache, { recursive: true });
  if (!existsSync(tarball)) {
    const response = await fetch(
      'https://registry.npmjs.org/@openuidev/lang-core/-/lang-core-1.0.1.tgz',
    );
    if (!response.ok) {
      throw new Error(
        `failed to download lang-core ${supported}: ${response.status}`,
      );
    }
    writeFileSync(tarball, Buffer.from(await response.arrayBuffer()));
  }
  const extract = join(cache, 'package');
  rmSync(extract, { recursive: true, force: true });
  execFileSync('tar', ['-xzf', tarball, '-C', cache]);
  return extract;
}

function linkDependency(tree, name, target) {
  const dest = join(tree, 'node_modules', name);
  mkdirSync(dirname(dest), { recursive: true });
  symlinkSync(target, dest, 'dir');
}

function prepareTrees(officialPackage) {
  const zod = join(repo, 'web/node_modules/zod');
  if (!existsSync(zod)) {
    throw new Error('Missing web/node_modules/zod. Run npm ci in web/ first.');
  }
  const root = mkdtempSync(join(tmpdir(), 'openui-compare-'));
  const officialTree = join(root, 'official');
  const patchedTree = join(root, 'patched');
  cpSync(
    officialPackage,
    join(officialTree, 'node_modules/@openuidev/lang-core'),
    {
      recursive: true,
    },
  );
  cpSync(
    officialPackage,
    join(patchedTree, 'node_modules/@openuidev/lang-core'),
    {
      recursive: true,
    },
  );
  linkDependency(officialTree, 'zod', zod);
  linkDependency(patchedTree, 'zod', zod);
  const scoped = join(patchedTree, 'node_modules/@heyq02');
  mkdirSync(scoped, { recursive: true });
  symlinkSync(join(repo, 'npm'), join(scoped, 'openui.mbt'), 'dir');
  return { root, officialTree, patchedTree };
}

function assertVersionMismatchLeavesFiles(officialPackage) {
  const tree = mkdtempSync(join(tmpdir(), 'openui-mismatch-'));
  const lang = join(tree, 'node_modules/@openuidev/lang-core');
  cpSync(officialPackage, lang, { recursive: true });
  const manifestPath = join(lang, 'package.json');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  manifest.version = '9.9.9';
  writeFileSync(manifestPath, JSON.stringify(manifest));
  const before = readFileSync(join(lang, 'dist/index.mjs'), 'utf8');
  let failed = false;
  try {
    execFileSync('node', [join(repo, 'npm/cli.js'), 'patch'], {
      cwd: tree,
      stdio: 'pipe',
    });
  } catch (error) {
    failed = true;
    const message = error.stderr?.toString() ?? '';
    if (!message.includes('is not supported')) {
      throw new Error(`unexpected patch failure: ${message}`);
    }
  }
  if (!failed)
    throw new Error('patch accepted an unsupported lang-core version');
  const after = readFileSync(join(lang, 'dist/index.mjs'), 'utf8');
  if (after !== before)
    throw new Error('version mismatch modified installed files');
  rmSync(tree, { recursive: true, force: true });
}

async function loadLang(tree) {
  return import(
    pathToFileURL(
      join(tree, 'node_modules/@openuidev/lang-core/dist/index.mjs'),
    ).href
  );
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
  const library = lang.createLibrary({
    components: [
      component('Stack', { children: z.array(any) }),
      component('TextContent', {
        text: z.string(),
        size: z.string().optional(),
      }),
      component('Form', {
        name: z.string(),
        buttons: any.optional(),
        fields: z.array(any),
      }),
      component('FormControl', { label: z.string(), control: any.optional() }),
      component('Input', {
        name: z.string().optional(),
        placeholder: z.string().optional(),
        type: z.string().optional(),
        validation: z.record(z.string(), any).optional(),
      }),
      component('Buttons', {
        buttons: z.array(any),
        direction: z.string().optional(),
      }),
      component('Button', {
        label: z.string(),
        action: any.optional(),
        variant: z.string().optional(),
      }),
    ],
  });
  return library.toJSONSchema();
}

function walk(value) {
  if (Array.isArray(value)) return value.map(walk);
  if (!value || typeof value !== 'object') return value ?? null;
  if (typeof value.typeName === 'string') {
    const props = {};
    for (const key of Object.keys(value.props ?? {}).sort()) {
      props[key] = walk(value.props[key]);
    }
    return {
      typeName: value.typeName,
      statementId: value.statementId ?? null,
      partial: Boolean(value.partial),
      props,
    };
  }
  const copy = {};
  for (const key of Object.keys(value).sort()) copy[key] = walk(value[key]);
  return copy;
}

function summarize(result) {
  const errors = (result.meta?.errors ?? []).map((error) => ({
    code: error.code,
    component: error.component ?? '',
    path: error.path ?? '',
    statementId: error.statementId ?? '',
  }));
  errors.sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
  return {
    root: walk(result.root),
    incomplete: Boolean(result.meta?.incomplete),
    unresolved: [...(result.meta?.unresolved ?? [])].sort(),
    orphaned: [...(result.meta?.orphaned ?? [])].sort(),
    statementCount: result.meta?.statementCount ?? 0,
    errors,
    state: Object.keys(result.stateDeclarations ?? {}).sort(),
  };
}

function stream(parser, source) {
  const lines = source.split('\n');
  let result;
  for (let index = 0; index < lines.length; index += 1) {
    const last = index === lines.length - 1;
    const chunk = last ? lines[index] : `${lines[index]}\n`;
    result = parser.push(chunk, last);
  }
  return result;
}

function same(actual, expected) {
  return JSON.stringify(actual) === JSON.stringify(expected);
}

function time(run, iterations) {
  for (let index = 0; index < 10; index += 1) run();
  const samples = [];
  let peak = 0;
  for (let index = 0; index < iterations; index += 1) {
    const start = performance.now();
    run();
    samples.push(performance.now() - start);
    peak = Math.max(peak, process.memoryUsage().heapUsed);
  }
  return { medianMs: Number(median(samples).toFixed(4)), heapUsed: peak };
}

const signup = readFileSync(join(repo, 'web/signup.openui'), 'utf8');
const cases = [
  { name: 'signup', source: signup },
  { name: 'unknown component', source: 'root = Nope("x")\n' },
  { name: 'missing required', source: 'root = TextContent()\n' },
  {
    name: 'forward ref and orphan',
    source: 'root = Stack([title])\nextra = TextContent("Spare")\n',
  },
  { name: 'state', source: 'root = TextContent($name)\n$name = "Ada"\n' },
  { name: 'bad line', source: 'root = TextContent("Hi")\n!!!\n' },
  {
    name: 'unclosed',
    source: 'root = TextContent("Hi")\nroot = TextContent("',
  },
];

const officialPackage = await ensureOfficialPackage();
assertVersionMismatchLeavesFiles(officialPackage);
const trees = prepareTrees(officialPackage);
execFileSync('node', [join(repo, 'npm/cli.js'), 'patch'], {
  cwd: trees.patchedTree,
  stdio: 'inherit',
});

const official = await loadLang(trees.officialTree);
const patched = await loadLang(trees.patchedTree);
const zod = await import(
  pathToFileURL(join(repo, 'web/node_modules/zod/index.js')).href
);
const schema = librarySchema(official, zod);
const diffs = [];

for (const item of cases) {
  const officialParse = summarize(
    official.createParser(schema).parse(item.source),
  );
  const patchedParse = summarize(
    patched.createParser(schema).parse(item.source),
  );
  if (!same(patchedParse, officialParse)) {
    diffs.push({
      name: `${item.name} parse`,
      official: officialParse,
      patched: patchedParse,
    });
  }
  const officialStream = summarize(
    stream(official.createStreamingParser(schema), item.source),
  );
  const patchedStream = summarize(
    stream(patched.createStreamingParser(schema), item.source),
  );
  if (!same(patchedStream, officialStream)) {
    diffs.push({
      name: `${item.name} stream`,
      official: officialStream,
      patched: patchedStream,
    });
  }
}

const patchedSource = readFileSync(
  join(trees.patchedTree, 'node_modules/@openuidev/lang-core/dist/index.mjs'),
  'utf8',
);
for (const site of [
  'parseMoonbitStatements(text)',
  'parseMoonbitStatements(t)',
  'parseMoonbitStatements(closed)',
  'parseMoonbitStatements(raw)',
]) {
  if (!patchedSource.includes(site)) {
    throw new Error(`patched parser is missing ${site}`);
  }
}

const wasmBase64 = readFileSync(join(repo, 'npm/parser.wasm.js'), 'utf8').match(
  /export const wasmBase64 = ("(?:\\.|[^"\\])*");/,
);
if (!wasmBase64) throw new Error('parser.wasm.js is missing wasmBase64');
const wasm = Buffer.from(JSON.parse(wasmBase64[1]), 'base64');
const speed = time(() => patched.createParser(schema).parse(signup), 200);
const streamSpeed = time(
  () => stream(patched.createStreamingParser(schema), signup),
  50,
);

const report = {
  langCore: supported,
  cases: cases.length,
  structuralDiffs: diffs.length,
  diffs,
  wasmBytes: wasm.length,
  gzipBytes: gzipSync(wasm).length,
  parseMedianMs: speed.medianMs,
  streamMedianMs: streamSpeed.medianMs,
  parseHeapUsed: speed.heapUsed,
  streamHeapUsed: streamSpeed.heapUsed,
};

console.log(JSON.stringify(report, null, 2));
rmSync(trees.root, { recursive: true, force: true });
if (diffs.length > 0) process.exit(1);

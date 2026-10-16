#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

const MARKER = '/* oui.mbt-parser */';
const SUPPORTED = '1.0.1';

const REPLACEMENTS = [
  ['split(tokenize(text))', 'parseMoonbitStatements(text)'],
  ['split(tokenize(closed))', 'parseMoonbitStatements(closed)'],
  ['split(tokenize(raw))[0]', 'parseMoonbitStatements(raw)[0]'],
  ['split(tokenize(t))', 'parseMoonbitStatements(t)'],
  [
    'classifyStatement(s, parseExpression(s.tokens))',
    'classifyStatement(s, s.expr)',
  ],
  ['ast: parseExpression(stmt.tokens)', 'ast: stmt.expr'],
  [
    'function createParser(schema, rootName) {\n\tconst paramMap = compileSchema(schema);\n\treturn { parse(input) {\n\t\tconst telemetry = prepareParserParseTelemetry();\n\t\ttry {\n\t\t\tconst result = parse(input, paramMap, rootName);\n\t\t\tcaptureParserParseResult(telemetry, result);\n\t\t\treturn result;\n\t\t} catch (error) {\n\t\t\tcaptureParserParseException(telemetry);\n\t\t\tthrow error;\n\t\t}\n\t} };\n}\n',
    'function createParser(schema, rootName) {\n\tconst schemaText = JSON.stringify(schema ?? {});\n\tconst root = rootName ?? "";\n\treturn { parse(input) {\n\t\tconst telemetry = prepareParserParseTelemetry();\n\t\ttry {\n\t\t\tconst result = parseMoonbitResult(input, schemaText, root);\n\t\t\tcaptureParserParseResult(telemetry, result);\n\t\t\treturn result;\n\t\t} catch (error) {\n\t\t\tcaptureParserParseException(telemetry);\n\t\t\tthrow error;\n\t\t}\n\t} };\n}\n',
  ],
];

const SHIM = `function parseMoonbitStatements(text) {
  const program = __ouiParseProgram(text);
  const statements = [];
  for (const stmt of program.statements ?? []) {
    const expr = stmt?.expr;
    if (!expr || typeof expr !== 'object' || typeof expr.k !== 'string') continue;
    statements.push({
      id: stmt.id,
      idTokenType: String(stmt.id ?? '').startsWith('$') ? 18 : 16,
      expr,
    });
  }
  return statements;
}
function parseMoonbitResult(input, schemaText, rootName) {
  const source = input ?? '';
  if (
    source.indexOf('\`\`\`') === -1 &&
    source.indexOf('//') === -1 &&
    source.indexOf('#') === -1
  ) {
    const trimmed = source.trim();
    if (!trimmed) return emptyResult();
    return __ouiParseResult(trimmed, schemaText ?? '{}', rootName ?? '');
  }
  const trimmed = preprocess(source);
  if (!trimmed) return emptyResult();
  const { text, wasIncomplete } = autoClose(trimmed);
  const result = __ouiParseResult(text, schemaText ?? '{}', rootName ?? '');
  if (wasIncomplete && result && result.meta) result.meta.incomplete = true;
  return result;
}
`;

function usage() {
  console.log('Usage: oui.mbt patch');
}

function findLangCore(start) {
  let dir = resolve(start);
  for (;;) {
    const manifest = join(
      dir,
      'node_modules',
      '@openuidev',
      'lang-core',
      'package.json',
    );
    if (existsSync(manifest)) return dirname(manifest);
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

function preamble(kind) {
  if (kind === 'mjs') {
    return `${MARKER}
import { parseProgram as __ouiParseProgram, parseResult as __ouiParseResult } from '@heyq02/openui.mbt/parser';
${SHIM}`;
  }
  return `${MARKER}
const { parseProgram: __ouiParseProgram, parseResult: __ouiParseResult } = require('@heyq02/openui.mbt/parser');
${SHIM}`;
}

function transform(source, kind, path) {
  if (source.includes(MARKER)) return { status: 'patched', next: source };
  let next = source;
  let count = 0;
  for (const [from, to] of REPLACEMENTS) {
    const parts = next.split(from);
    count += parts.length - 1;
    next = parts.join(to);
  }
  const expected = 9;
  if (count !== expected) {
    throw new Error(
      `${path} has ${count} parser call sites, expected ${expected}. This build of @openuidev/lang-core is not ${SUPPORTED}.`,
    );
  }
  return { status: 'updated', next: preamble(kind) + next };
}

function patch(cwd) {
  const root = findLangCore(cwd);
  if (!root) {
    throw new Error(
      'Cannot find @openuidev/lang-core. Install it in this project, then run oui.mbt patch.',
    );
  }
  const version = JSON.parse(
    readFileSync(join(root, 'package.json'), 'utf8'),
  ).version;
  if (version !== SUPPORTED) {
    throw new Error(
      `@openuidev/lang-core@${version} is not supported. oui.mbt patch matches ${SUPPORTED} and leaves the installed files unchanged.`,
    );
  }
  const targets = [
    ['dist/index.mjs', 'mjs'],
    ['dist/index.cjs', 'cjs'],
  ];
  const prepared = [];
  for (const [file, kind] of targets) {
    const path = join(root, file);
    if (!existsSync(path)) throw new Error(`Missing ${path}`);
    prepared.push({
      path,
      file,
      ...transform(readFileSync(path, 'utf8'), kind, path),
    });
  }
  for (const item of prepared) {
    if (item.status === 'updated') writeFileSync(item.path, item.next);
  }
  console.log(`Patched @openuidev/lang-core@${version} at ${root}`);
  for (const item of prepared) console.log(`${item.file}: ${item.status}`);
}

const command = process.argv[2];

try {
  if (command === 'patch') {
    patch(process.cwd());
  } else {
    usage();
    process.exit(command ? 1 : 0);
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
}

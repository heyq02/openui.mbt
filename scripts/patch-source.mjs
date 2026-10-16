import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const MARKER = '/* oui.mbt-parser */';

const SOURCE_IMPORT = `${MARKER}
import { parseProgram as __ouiParseProgram } from '@heyq02/openui.mbt/parser';

`;

const SOURCE_FN = `
function parseMoonbitStatements(text: string): any[] {
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
`;

function replaceOnce(source, from, to, label) {
  const parts = source.split(from);
  const count = parts.length - 1;
  if (count !== 1) {
    throw new Error(`${label} appeared ${count} times, expected 1`);
  }
  return parts.join(to);
}

function patchParserSource(source, path) {
  if (source.includes(MARKER)) return { status: 'patched', next: source };
  let next = source;
  next = replaceOnce(
    next,
    'split(tokenize(text))',
    'parseMoonbitStatements(text)',
    `${path} split(tokenize(text))`,
  );
  next = replaceOnce(
    next,
    'split(tokenize(closed))',
    'parseMoonbitStatements(closed)',
    `${path} split(tokenize(closed))`,
  );
  next = replaceOnce(
    next,
    'split(tokenize(t))',
    'parseMoonbitStatements(t)',
    `${path} split(tokenize(t))`,
  );
  const pair =
    /([ \t]*)const expr = parseExpression\(s\.tokens\);\r?\n\1const stmt = classifyStatement\(s, expr\);/g;
  let pairCount = 0;
  next = next.replace(pair, (_match, indent) => {
    pairCount += 1;
    return `${indent}const stmt = classifyStatement(s, s.expr);`;
  });
  if (pairCount !== 3) {
    throw new Error(
      `${path} has ${pairCount} parseExpression(s.tokens) sites, expected 3`,
    );
  }
  next = next.replace('import { parseExpression } from "./expressions";\n', '');
  next = next.replace('import { tokenize } from "./lexer";\n', '');
  next = next.replace(
    'import { autoClose, split, type RawStmt } from "./statements";',
    'import { autoClose, type RawStmt } from "./statements";',
  );
  return { status: 'updated', next: SOURCE_IMPORT + next + SOURCE_FN };
}

function patchMergeSource(source, path) {
  if (source.includes(MARKER)) return { status: 'patched', next: source };
  let next = source;
  next = replaceOnce(
    next,
    'split(tokenize(raw))[0]',
    'parseMoonbitStatements(raw)[0]',
    `${path} split(tokenize(raw))`,
  );
  next = replaceOnce(
    next,
    'ast: parseExpression(stmt.tokens),',
    'ast: stmt.expr,',
    `${path} parseExpression(stmt.tokens)`,
  );
  next = next.replace('import { parseExpression } from "./expressions";\n', '');
  next = next.replace('import { tokenize } from "./lexer";\n', '');
  next = next.replace('import { split } from "./statements";\n', '');
  return { status: 'updated', next: SOURCE_IMPORT + next + SOURCE_FN };
}

function patchSource(checkout) {
  const parserDir = join(checkout, 'packages/lang-core/src/parser');
  const files = [
    ['parser.ts', patchParserSource],
    ['merge.ts', patchMergeSource],
  ];
  const prepared = [];
  for (const [file, transformSource] of files) {
    const path = join(parserDir, file);
    if (!existsSync(path)) throw new Error(`Missing ${path}`);
    prepared.push({
      path,
      file,
      ...transformSource(readFileSync(path, 'utf8'), path),
    });
  }
  for (const item of prepared) {
    if (item.status === 'updated') writeFileSync(item.path, item.next);
  }
  console.log(`Patched OpenUI source at ${parserDir}`);
  for (const item of prepared) console.log(`${item.file}: ${item.status}`);
}

const checkout = process.argv[2];

try {
  if (!checkout) {
    console.log('Usage: node scripts/patch-source.mjs <openui-checkout>');
    process.exit(1);
  }
  patchSource(resolve(checkout));
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
}

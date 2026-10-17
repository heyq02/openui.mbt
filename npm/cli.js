#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const MARKER = "/* oui.mbt-parser */";
const SUPPORTED = "1.0.1";

const REPLACEMENTS = [
  ["split(tokenize(text))", "parseMoonbitStatements(text)"],
  ["split(tokenize(closed))", "parseMoonbitStatements(closed)"],
  ["split(tokenize(raw))[0]", "parseMoonbitStatements(raw)[0]"],
  ["split(tokenize(t))", "parseMoonbitStatements(t)"],
  ["classifyStatement(s, parseExpression(s.tokens))", "classifyStatement(s, s.expr)"],
  ["ast: parseExpression(stmt.tokens)", "ast: stmt.expr"],
  [
    "function createParser(schema, rootName) {\n\tconst paramMap = compileSchema(schema);\n\treturn { parse(input) {\n\t\tconst telemetry = prepareParserParseTelemetry();\n\t\ttry {\n\t\t\tconst result = parse(input, paramMap, rootName);\n\t\t\tcaptureParserParseResult(telemetry, result);\n\t\t\treturn result;\n\t\t} catch (error) {\n\t\t\tcaptureParserParseException(telemetry);\n\t\t\tthrow error;\n\t\t}\n\t} };\n}\n",
    'function createParser(schema, rootName) {\n\tconst schemaText = JSON.stringify(schema ?? {});\n\tconst root = rootName ?? "";\n\treturn { parse(input) {\n\t\tconst telemetry = prepareParserParseTelemetry();\n\t\ttry {\n\t\t\tconst result = parseMoonbitResult(input, schemaText, root);\n\t\t\tcaptureParserParseResult(telemetry, result);\n\t\t\treturn result;\n\t\t} catch (error) {\n\t\t\tcaptureParserParseException(telemetry);\n\t\t\tthrow error;\n\t\t}\n\t} };\n}\n',
  ],
  [
    "function createStreamingParser(schema, rootName) {\n\treturn createStreamParser(compileSchema(schema), rootName);\n}",
    'function createStreamingParser(schema, rootName) {\n\treturn createMoonbitStreamingParser(JSON.stringify(schema ?? {}), rootName ?? "");\n}',
  ],
  [
    'function parseMessage(raw, { streaming } = {}) {\n\tlet text = raw.replace(RETRY, "$1\\n");\n\tconst cut = streaming ? RETRY_CUT.exec(text) : null;\n\tif (cut && `${PREFIX}content`.startsWith(cut[1])) text = text.slice(0, cut.index + 1);\n\tconst lines = text.split("\\n");\n\tconst last = lines[lines.length - 1];\n\tconst held = streaming && last !== "" && (last.startsWith(PREFIX) || PREFIX.startsWith(last));\n\tif (held) lines.pop();\n\tconst sections = [{\n\t\tkind: null,\n\t\tattributes: {},\n\t\tlines: []\n\t}];\n\tconst close = () => {\n\t\tconst body = sections[sections.length - 1].lines;\n\t\tif (body.length) body[body.length - 1] = body[body.length - 1].replace(/\\r$/, "");\n\t};\n\tlet endAt = -1;\n\tfor (const [i, line] of lines.entries()) {\n\t\tconst match = MARKER.exec(line.replace(/\\r$/, ""));\n\t\tif (!match) {\n\t\t\tsections[sections.length - 1].lines.push(line);\n\t\t\tcontinue;\n\t\t}\n\t\tclose();\n\t\tif (match[1] === "end") {\n\t\t\tendAt = sections.length - 1;\n\t\t\tif (i === lines.length - 2 && lines[i + 1] === "") break;\n\t\t\tcontinue;\n\t\t}\n\t\tsections.push({\n\t\t\tkind: match[1],\n\t\t\tattributes: readAttributes(match[2]),\n\t\t\tlines: []\n\t\t});\n\t}\n\tif (held) close();\n\tconst kinds = sections.map((s) => s.kind);\n\tconst win = Math.max(0, kinds.lastIndexOf("content"));\n\tconst ctx = kinds.lastIndexOf("context");\n\tlet context = ctx > win ? sections[ctx].lines.join("\\n") : null;\n\ttry {\n\t\tif (typeof context === "string") context = JSON.parse(context);\n\t} catch {}\n\tconst winner = sections[win];\n\tconst end = endAt >= win;\n\treturn {\n\t\tcontent: winner.lines.join("\\n"),\n\t\tcontext,\n\t\tattributes: winner.attributes,\n\t\tend\n\t};\n}\n',
    "function parseMessage(raw, options) {\n\treturn parseMoonbitMessage(raw, options);\n}\n",
  ],
  [
    'function buildMessage({ content, context, attributes, end }) {\n\tconst query = Object.entries(attributes ?? {}).map(([key, value]) => `${encode(key)}=${encode(value)}`).join("&");\n\tlet out = `${PREFIX}content${query ? `?${query}` : ""}\\n${content}`;\n\tif (context != null) out += `\\n${PREFIX}context\\n${typeof context === "string" ? context : JSON.stringify(context)}`;\n\treturn end ? `${out}\\n${PREFIX}end` : out;\n}\n',
    "function buildMessage(message) {\n\treturn buildMoonbitMessage(message);\n}\n",
  ],
  [
    "function parseRules(rules) {\n\tif (!Array.isArray(rules)) return [];\n\treturn rules.filter((r) => typeof r === \"string\").map(parseRule);\n}\n",
    "function parseRules(rules) {\n\treturn parseMoonbitRules(rules);\n}\n",
  ],
  [
    "function parseStructuredRules(rules) {\n\tif (!rules || typeof rules !== \"object\" || Array.isArray(rules)) return [];\n\tconst obj = rules;\n\tconst result = [];\n\tfor (const [key, val] of Object.entries(obj)) {\n\t\tif (val === false || val === void 0 || val === null) continue;\n\t\tif (val === true) result.push({ type: key });\n\t\telse result.push({\n\t\t\ttype: key,\n\t\t\targ: val\n\t\t});\n\t}\n\treturn result;\n}\n",
    "function parseStructuredRules(rules) {\n\treturn parseMoonbitStructuredRules(rules);\n}\n",
  ],
  [
    "const builtInValidators = {\n\trequired: (value) => {\n\t\tif (isEmpty(value)) return \"This field is required\";\n\t\tif (typeof value === \"object\" && !Array.isArray(value) && value !== null) {\n\t\t\tconst vals = Object.values(value);\n\t\t\tif (vals.length > 0 && vals.every((v) => typeof v === \"boolean\") && !vals.some(Boolean)) return \"At least one option is required\";\n\t\t}\n\t},\n\temail: (value) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== \"string\") return \"Please enter a valid email\";\n\t\treturn /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(value) ? void 0 : \"Please enter a valid email\";\n\t},\n\turl: (value) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== \"string\") return \"Please enter a valid URL\";\n\t\ttry {\n\t\t\tnew URL(value);\n\t\t\treturn;\n\t\t} catch {\n\t\t\treturn \"Please enter a valid URL\";\n\t\t}\n\t},\n\tnumeric: (value) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value === \"number\" && !isNaN(value)) return void 0;\n\t\tif (typeof value === \"string\" && !isNaN(parseFloat(value)) && value.trim() !== \"\") return void 0;\n\t\treturn \"Must be a number\";\n\t},\n\tmin: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tconst n = typeof value === \"number\" ? value : parseFloat(String(value));\n\t\tif (isNaN(n)) return void 0;\n\t\tconst min = Number(arg);\n\t\treturn n >= min ? void 0 : `Must be at least ${min}`;\n\t},\n\tmax: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tconst n = typeof value === \"number\" ? value : parseFloat(String(value));\n\t\tif (isNaN(n)) return void 0;\n\t\tconst max = Number(arg);\n\t\treturn n <= max ? void 0 : `Must be no more than ${max}`;\n\t},\n\tminLength: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== \"string\") return void 0;\n\t\tconst min = Number(arg);\n\t\treturn value.length >= min ? void 0 : `Must be at least ${min} characters`;\n\t},\n\tmaxLength: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== \"string\") return void 0;\n\t\tconst max = Number(arg);\n\t\treturn value.length <= max ? void 0 : `Must be no more than ${max} characters`;\n\t},\n\tpattern: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== \"string\" || typeof arg !== \"string\") return void 0;\n\t\ttry {\n\t\t\treturn new RegExp(arg).test(value) ? void 0 : \"Invalid format\";\n\t\t} catch {\n\t\t\treturn;\n\t\t}\n\t}\n};\n",
    "const builtInValidators = {\n\trequired: (value) => builtinMoonbit(\"required\", value),\n\temail: (value) => builtinMoonbit(\"email\", value),\n\turl: (value) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== \"string\") return \"Please enter a valid URL\";\n\t\ttry {\n\t\t\tnew URL(value);\n\t\t\treturn;\n\t\t} catch {\n\t\t\treturn \"Please enter a valid URL\";\n\t\t}\n\t},\n\tnumeric: (value) => builtinMoonbit(\"numeric\", value),\n\tmin: (value, arg) => builtinMoonbit(\"min\", value, arg),\n\tmax: (value, arg) => builtinMoonbit(\"max\", value, arg),\n\tminLength: (value, arg) => builtinMoonbit(\"minLength\", value, arg),\n\tmaxLength: (value, arg) => builtinMoonbit(\"maxLength\", value, arg),\n\tpattern: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== \"string\" || typeof arg !== \"string\") return void 0;\n\t\ttry {\n\t\t\treturn new RegExp(arg).test(value) ? void 0 : \"Invalid format\";\n\t\t} catch {\n\t\t\treturn;\n\t\t}\n\t}\n};\n",
  ],
  [
    "function enrichErrors(validationErrors, schema, componentNames) {\n\treturn validationErrors.map((ve) => {\n\t\tconst error = {\n\t\t\tsource: \"parser\",\n\t\t\tcode: ve.code,\n\t\t\tmessage: ve.message,\n\t\t\tcomponent: ve.component,\n\t\t\tpath: ve.path || void 0,\n\t\t\tstatementId: ve.statementId,\n\t\t\t...ve.severity && { severity: ve.severity }\n\t\t};\n\t\tif (ve.code === \"unknown-component\" && componentNames.length) error.hint = `Available components: ${componentNames.join(\", \")}`;\n\t\telse if (ve.code === \"missing-required\" || ve.code === \"null-required\") error.hint = buildSignatureHint(ve.component, schema.$defs?.[ve.component]);\n\t\telse if (ve.code === \"inline-reserved\") error.hint = `Declare as a top-level statement: myVar = ${ve.component}(...)`;\n\t\treturn error;\n\t});\n}\n",
    "function enrichErrors(validationErrors, schema, componentNames) {\n\treturn enrichMoonbitErrors(validationErrors, schema, componentNames);\n}\n",
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
  return __ouiParseResult(input ?? "", schemaText ?? "{}", rootName ?? "");
}
function createMoonbitStreamingParser(schemaText, rootName) {
  const session = __ouiCreateStream(schemaText ?? "{}", rootName ?? "");
  return {
    push(chunk, complete) {
      return session.push(chunk ?? "", Boolean(complete));
    },
    set(fullText, complete) {
      return session.set(fullText ?? "", Boolean(complete));
    },
    getResult(complete) {
      return session.result(Boolean(complete));
    },
  };
}
function parseMoonbitMessage(raw, options) {
  return __ouiParseMessage(raw ?? "", options);
}
function buildMoonbitMessage(message) {
  return __ouiBuildMessage(message);
}
function parseMoonbitRules(rules) {
  return __ouiParseRules(rules);
}
function parseMoonbitStructuredRules(rules) {
  return __ouiParseStructuredRules(rules);
}
function builtinMoonbit(kind, value, arg) {
  return __ouiCheckBuiltin(kind, value, arg);
}
function enrichMoonbitErrors(validationErrors, schema, componentNames) {
  return __ouiEnrichErrors(validationErrors, schema, componentNames);
}
`;

function usage() {
  console.log("Usage: oui.mbt patch");
}

function findLangCore(start) {
  let dir = resolve(start);
  for (;;) {
    const manifest = join(dir, "node_modules", "@openuidev", "lang-core", "package.json");
    if (existsSync(manifest)) return dirname(manifest);
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

function preamble(kind) {
  if (kind === "mjs") {
    return `${MARKER}
import { parseProgram as __ouiParseProgram, parseResult as __ouiParseResult, createStream as __ouiCreateStream, parseMessage as __ouiParseMessage, buildMessage as __ouiBuildMessage, parseRules as __ouiParseRules, parseStructuredRules as __ouiParseStructuredRules, checkBuiltin as __ouiCheckBuiltin, enrichErrors as __ouiEnrichErrors } from '@heyq02/openui.mbt/parser';
${SHIM}`;
  }
  return `${MARKER}
const { parseProgram: __ouiParseProgram, parseResult: __ouiParseResult, createStream: __ouiCreateStream, parseMessage: __ouiParseMessage, buildMessage: __ouiBuildMessage, parseRules: __ouiParseRules, parseStructuredRules: __ouiParseStructuredRules, checkBuiltin: __ouiCheckBuiltin, enrichErrors: __ouiEnrichErrors } = require('@heyq02/openui.mbt/parser');
${SHIM}`;
}

function transform(source, kind, path) {
  if (source.includes(MARKER)) return { status: "patched", next: source };
  let next = source;
  let count = 0;
  for (const [from, to] of REPLACEMENTS) {
    const parts = next.split(from);
    count += parts.length - 1;
    next = parts.join(to);
  }
  const expected = 16;
  if (count !== expected) {
    throw new Error(
      `${path} has ${count} parser call sites, expected ${expected}. This build of @openuidev/lang-core is not ${SUPPORTED}.`,
    );
  }
  return { status: "updated", next: preamble(kind) + next };
}

function patch(cwd) {
  const root = findLangCore(cwd);
  if (!root) {
    throw new Error(
      "Cannot find @openuidev/lang-core. Install it in this project, then run oui.mbt patch.",
    );
  }
  const version = JSON.parse(readFileSync(join(root, "package.json"), "utf8")).version;
  if (version !== SUPPORTED) {
    throw new Error(
      `@openuidev/lang-core@${version} is not supported. oui.mbt patch matches ${SUPPORTED} and leaves the installed files unchanged.`,
    );
  }
  const targets = [
    ["dist/index.mjs", "mjs"],
    ["dist/index.cjs", "cjs"],
  ];
  const prepared = [];
  for (const [file, kind] of targets) {
    const path = join(root, file);
    if (!existsSync(path)) throw new Error(`Missing ${path}`);
    prepared.push({
      path,
      file,
      ...transform(readFileSync(path, "utf8"), kind, path),
    });
  }
  for (const item of prepared) {
    if (item.status === "updated") writeFileSync(item.path, item.next);
  }
  console.log(`Patched @openuidev/lang-core@${version} at ${root}`);
  for (const item of prepared) console.log(`${item.file}: ${item.status}`);
}

const command = process.argv[2];

try {
  if (command === "patch") {
    patch(process.cwd());
  } else {
    usage();
    process.exit(command ? 1 : 0);
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
}

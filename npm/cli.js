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
    'function parseRules(rules) {\n\tif (!Array.isArray(rules)) return [];\n\treturn rules.filter((r) => typeof r === "string").map(parseRule);\n}\n',
    "function parseRules(rules) {\n\treturn parseMoonbitRules(rules);\n}\n",
  ],
  [
    'function parseStructuredRules(rules) {\n\tif (!rules || typeof rules !== "object" || Array.isArray(rules)) return [];\n\tconst obj = rules;\n\tconst result = [];\n\tfor (const [key, val] of Object.entries(obj)) {\n\t\tif (val === false || val === void 0 || val === null) continue;\n\t\tif (val === true) result.push({ type: key });\n\t\telse result.push({\n\t\t\ttype: key,\n\t\t\targ: val\n\t\t});\n\t}\n\treturn result;\n}\n',
    "function parseStructuredRules(rules) {\n\treturn parseMoonbitStructuredRules(rules);\n}\n",
  ],
  [
    'const builtInValidators = {\n\trequired: (value) => {\n\t\tif (isEmpty(value)) return "This field is required";\n\t\tif (typeof value === "object" && !Array.isArray(value) && value !== null) {\n\t\t\tconst vals = Object.values(value);\n\t\t\tif (vals.length > 0 && vals.every((v) => typeof v === "boolean") && !vals.some(Boolean)) return "At least one option is required";\n\t\t}\n\t},\n\temail: (value) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== "string") return "Please enter a valid email";\n\t\treturn /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(value) ? void 0 : "Please enter a valid email";\n\t},\n\turl: (value) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== "string") return "Please enter a valid URL";\n\t\ttry {\n\t\t\tnew URL(value);\n\t\t\treturn;\n\t\t} catch {\n\t\t\treturn "Please enter a valid URL";\n\t\t}\n\t},\n\tnumeric: (value) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value === "number" && !isNaN(value)) return void 0;\n\t\tif (typeof value === "string" && !isNaN(parseFloat(value)) && value.trim() !== "") return void 0;\n\t\treturn "Must be a number";\n\t},\n\tmin: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tconst n = typeof value === "number" ? value : parseFloat(String(value));\n\t\tif (isNaN(n)) return void 0;\n\t\tconst min = Number(arg);\n\t\treturn n >= min ? void 0 : `Must be at least ${min}`;\n\t},\n\tmax: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tconst n = typeof value === "number" ? value : parseFloat(String(value));\n\t\tif (isNaN(n)) return void 0;\n\t\tconst max = Number(arg);\n\t\treturn n <= max ? void 0 : `Must be no more than ${max}`;\n\t},\n\tminLength: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== "string") return void 0;\n\t\tconst min = Number(arg);\n\t\treturn value.length >= min ? void 0 : `Must be at least ${min} characters`;\n\t},\n\tmaxLength: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== "string") return void 0;\n\t\tconst max = Number(arg);\n\t\treturn value.length <= max ? void 0 : `Must be no more than ${max} characters`;\n\t},\n\tpattern: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== "string" || typeof arg !== "string") return void 0;\n\t\ttry {\n\t\t\treturn new RegExp(arg).test(value) ? void 0 : "Invalid format";\n\t\t} catch {\n\t\t\treturn;\n\t\t}\n\t}\n};\n',
    "const builtInValidators = {\n\trequired: (value) => requiredMoonbit(value),\n\temail: (value) => emailMoonbit(value),\n\turl: (value) => urlMoonbit(value),\n\tnumeric: (value) => numericMoonbit(value),\n\tmin: (value, arg) => minMoonbit(value, arg),\n\tmax: (value, arg) => maxMoonbit(value, arg),\n\tminLength: (value, arg) => minLengthMoonbit(value, arg),\n\tmaxLength: (value, arg) => maxLengthMoonbit(value, arg),\n\tpattern: (value, arg) => patternMoonbit(value, arg)\n};\n",
  ],
  [
    'function enrichErrors(validationErrors, schema, componentNames) {\n\treturn validationErrors.map((ve) => {\n\t\tconst error = {\n\t\t\tsource: "parser",\n\t\t\tcode: ve.code,\n\t\t\tmessage: ve.message,\n\t\t\tcomponent: ve.component,\n\t\t\tpath: ve.path || void 0,\n\t\t\tstatementId: ve.statementId,\n\t\t\t...ve.severity && { severity: ve.severity }\n\t\t};\n\t\tif (ve.code === "unknown-component" && componentNames.length) error.hint = `Available components: ${componentNames.join(", ")}`;\n\t\telse if (ve.code === "missing-required" || ve.code === "null-required") error.hint = buildSignatureHint(ve.component, schema.$defs?.[ve.component]);\n\t\telse if (ve.code === "inline-reserved") error.hint = `Declare as a top-level statement: myVar = ${ve.component}(...)`;\n\t\treturn error;\n\t});\n}\n',
    "function enrichErrors(validationErrors, schema, componentNames) {\n\treturn enrichMoonbitErrors(validationErrors, schema, componentNames);\n}\n",
  ],
  [
    'function mergeStatements(existing, patch, rootId = "root") {\n\tconst existingStmts = parseStatements(existing);\n\tconst patchStmts = parseStatements(stripFences(patch));\n\tif (!existingStmts.length) return patchStmts.map((stmt) => stmt.raw).join("\\n");\n\tif (!patchStmts.length) return existing;\n\tconst merged = /* @__PURE__ */ new Map();\n\tconst asts = /* @__PURE__ */ new Map();\n\tconst order = [];\n\tfor (const stmt of existingStmts) {\n\t\tmerged.set(stmt.id, stmt.raw);\n\t\tasts.set(stmt.id, stmt.ast);\n\t\torder.push(stmt.id);\n\t}\n\tfor (const stmt of patchStmts) {\n\t\tif (stmt.ast.k === "Null") {\n\t\t\tmerged.delete(stmt.id);\n\t\t\tasts.delete(stmt.id);\n\t\t\tconst idx = order.indexOf(stmt.id);\n\t\t\tif (idx !== -1) order.splice(idx, 1);\n\t\t\tcontinue;\n\t\t}\n\t\tif (!merged.has(stmt.id)) order.push(stmt.id);\n\t\tmerged.set(stmt.id, stmt.raw);\n\t\tasts.set(stmt.id, stmt.ast);\n\t}\n\tgcUnreachable(order, merged, asts, rootId);\n\treturn order.filter((id) => merged.has(id)).map((id) => merged.get(id)).join("\\n");\n}\n',
    'function mergeStatements(existing, patch, rootId = "root") {\n\treturn mergeMoonbitStatements(existing, patch, rootId);\n}\n',
  ],
  [
    'function jsonToOpenUI(json, library, options) {\n\tconst paramMap = compileSchema(library.toJSONSchema());\n\tconst collector = new StatementCollector();\n\tconst rootExpr = serializeElementExpr(json, paramMap, collector);\n\tconst rootId = json.statementId || "root";\n\tconst lines = [];\n\tlines.push(`${rootId} = ${rootExpr}`);\n\tfor (const stmt of collector.getStatements()) {\n\t\tif (stmt.id === rootId) continue;\n\t\tlines.push(stmt.text);\n\t}\n\tif (options?.stateDeclarations) {\n\t\tconst stateLines = serializeStateDeclarations(options.stateDeclarations, paramMap, collector);\n\t\tlines.push(...stateLines);\n\t}\n\treturn lines.join("\\n");\n}\n',
    "function jsonToOpenUI(json, library, options) {\n\treturn jsonToOpenUIMoonbit(json, library, options);\n}\n",
  ],
  [
    'function evaluate(node, context, schemaCtx) {\n\tswitch (node.k) {\n\t\tcase "Str": return node.v;\n\t\tcase "Num": return node.v;\n\t\tcase "Bool": return node.v;\n\t\tcase "Null": return null;\n\t\tcase "Ph": return null;\n\t\tcase "StateRef": return context.extraScope?.[node.n] ?? context.getState(node.n);\n\t\tcase "Ref":\n\t\tcase "RuntimeRef": return context.resolveRef(node.n);\n\t\tcase "Arr": return node.els.map((el) => evaluate(el, context));\n\t\tcase "Obj": return Object.fromEntries(node.entries.map(([k, v]) => [k, evaluate(v, context)]));\n\t\tcase "Comp": {\n\t\t\tconst builtin = BUILTINS[node.name];\n\t\t\tif (builtin) {\n\t\t\t\tif (builtin.lazy) return evaluateLazyBuiltin(node.name, node.args, context, schemaCtx);\n\t\t\t\treturn builtin.fn(evaluateArgs(node, context));\n\t\t\t}\n\t\t\tif (isStep(node.name)) return evaluateActionCall(node, context);\n\t\t\tconst fns = context.functions;\n\t\t\tif (fns && Object.prototype.hasOwnProperty.call(fns, node.name)) return callFunction(node.name, fns[node.name], node, context);\n\t\t\tconst acts = context.actions;\n\t\t\tif (acts && Object.prototype.hasOwnProperty.call(acts, node.name)) {\n\t\t\t\tconst def = acts[node.name];\n\t\t\t\tconst args = callArgs(node, context, def.params);\n\t\t\t\tif (missesRequired(args, def.params)) return { steps: [] };\n\t\t\t\tconst params = checkValue(args, def.params, node.name, "", context, true);\n\t\t\t\tif (params === INVALID) return { steps: [] };\n\t\t\t\tconst step = {\n\t\t\t\t\ttype: "custom_action",\n\t\t\t\t\tname: node.name,\n\t\t\t\t\tparams\n\t\t\t\t};\n\t\t\t\tcustomSteps.add(step);\n\t\t\t\treturn { steps: [step] };\n\t\t\t}\n\t\t\tif (node.mappedProps) {\n\t\t\t\tconst def = schemaCtx?.library.components[node.name];\n\t\t\t\tconst props = {};\n\t\t\t\tfor (const [key, val] of Object.entries(node.mappedProps)) {\n\t\t\t\t\tconst propSchema = def?.props?.shape?.[key];\n\t\t\t\t\tif (val.k === "StateRef" && propSchema && isReactiveSchema(propSchema)) props[key] = {\n\t\t\t\t\t\t__reactive: "assign",\n\t\t\t\t\t\ttarget: val.n,\n\t\t\t\t\t\texpr: {\n\t\t\t\t\t\t\tk: "StateRef",\n\t\t\t\t\t\t\tn: "$value"\n\t\t\t\t\t\t}\n\t\t\t\t\t};\n\t\t\t\t\telse if (val.k === "StateRef") props[key] = schemaCtx ? context.getState(val.n) : val;\n\t\t\t\t\telse props[key] = evaluate(val, context, schemaCtx);\n\t\t\t\t}\n\t\t\t\tconst result = {\n\t\t\t\t\ttype: "element",\n\t\t\t\t\ttypeName: node.name,\n\t\t\t\t\tprops,\n\t\t\t\t\tpartial: false,\n\t\t\t\t\thasDynamicProps: true\n\t\t\t\t};\n\t\t\t\tif (schemaCtx) {\n\t\t\t\t\tfor (const [key, val] of Object.entries(props)) if (isElementNode(val)) props[key] = evaluateElementInline(val, context, schemaCtx);\n\t\t\t\t\telse if (Array.isArray(val)) props[key] = val.map((item) => isElementNode(item) ? evaluateElementInline(item, context, schemaCtx) : item);\n\t\t\t\t}\n\t\t\t\treturn result;\n\t\t\t}\n\t\t\tconsole.warn(`[openui] Unexpected unmapped Comp node: ${node.name}`);\n\t\t\treturn null;\n\t\t}\n\t\tcase "BinOp": {\n\t\t\tif (node.op === "&&") {\n\t\t\t\tconst left = evaluate(node.left, context);\n\t\t\t\treturn left ? evaluate(node.right, context) : left;\n\t\t\t}\n\t\t\tif (node.op === "||") {\n\t\t\t\tconst left = evaluate(node.left, context);\n\t\t\t\treturn left ? left : evaluate(node.right, context);\n\t\t\t}\n\t\t\tconst left = evaluate(node.left, context);\n\t\t\tconst right = evaluate(node.right, context);\n\t\t\tswitch (node.op) {\n\t\t\t\tcase "+":\n\t\t\t\t\tif (typeof left === "string" || typeof right === "string") return String(left ?? "") + String(right ?? "");\n\t\t\t\t\treturn toNumber(left) + toNumber(right);\n\t\t\t\tcase "-": return toNumber(left) - toNumber(right);\n\t\t\t\tcase "*": return toNumber(left) * toNumber(right);\n\t\t\t\tcase "/": return toNumber(right) === 0 ? 0 : toNumber(left) / toNumber(right);\n\t\t\t\tcase "%": return toNumber(right) === 0 ? 0 : toNumber(left) % toNumber(right);\n\t\t\t\tcase "==": return left == right;\n\t\t\t\tcase "!=": return left != right;\n\t\t\t\tcase ">": return toNumber(left) > toNumber(right);\n\t\t\t\tcase "<": return toNumber(left) < toNumber(right);\n\t\t\t\tcase ">=": return toNumber(left) >= toNumber(right);\n\t\t\t\tcase "<=": return toNumber(left) <= toNumber(right);\n\t\t\t\tdefault: return null;\n\t\t\t}\n\t\t}\n\t\tcase "UnaryOp":\n\t\t\tif (node.op === "!") return !evaluate(node.operand, context);\n\t\t\tif (node.op === "-") return -toNumber(evaluate(node.operand, context));\n\t\t\treturn null;\n\t\tcase "Ternary": return evaluate(node.cond, context) ? evaluate(node.then, context) : evaluate(node.else, context);\n\t\tcase "Member": {\n\t\t\tconst obj = evaluate(node.obj, context);\n\t\t\tif (obj == null) return null;\n\t\t\tif (Array.isArray(obj)) {\n\t\t\t\tif (node.field === "length") return obj.length;\n\t\t\t\treturn obj.map((item) => item?.[node.field] ?? null);\n\t\t\t}\n\t\t\treturn obj[node.field];\n\t\t}\n\t\tcase "Index": {\n\t\t\tconst obj = evaluate(node.obj, context);\n\t\t\tconst idx = evaluate(node.index, context);\n\t\t\tif (obj == null || idx == null) return null;\n\t\t\tif (Array.isArray(obj)) return obj[toNumber(idx)];\n\t\t\treturn obj[String(idx)];\n\t\t}\n\t\tcase "Assign": return {\n\t\t\t__reactive: "assign",\n\t\t\ttarget: node.target,\n\t\t\texpr: node.value\n\t\t};\n\t}\n}\n',
    'function evaluate(node, context, schemaCtx) {\n\tif (node.k === "Comp") {\n\t\t\tconst builtin = BUILTINS[node.name];\n\t\t\tif (builtin) {\n\t\t\t\tif (builtin.lazy) return evaluateLazyBuiltin(node.name, node.args, context, schemaCtx);\n\t\t\t\tconst builtinArgs = evaluateArgs(node, context);\n\t\t\t\tconst builtinResult = callBuiltinMoonbit(node.name, builtinArgs);\n\t\t\t\tif (!(builtinResult && builtinResult.__useJs)) return builtinResult;\n\t\t\t\treturn builtin.fn(builtinArgs);\n\t\t\t}\n\t\t\tif (isStep(node.name) && (node.name === "Run" || node.name === "Set" || node.name === "Reset")) return lazyStepMoonbit(node);\n\t\t\tif (isStep(node.name) && (node.name === \"OpenUrl\" || node.name === \"ToAssistant\")) return eagerStepMoonbit(node, context);\n\t\t\tif (isStep(node.name)) return evaluateActionCall(node, context);\n\t\t\tconst fns = context.functions;\n\t\t\tif (fns && Object.prototype.hasOwnProperty.call(fns, node.name)) return callFunction(node.name, fns[node.name], node, context);\n\t\t\tconst action = customActionMoonbit(node, context);\n\t\t\tif (action) return action\n\t\t\treturn mappedCompMoonbit(node, context, schemaCtx);\n\t}\n\treturn evaluateMoonbitPure(node, context, schemaCtx);\n}\n',
  ],
  [
    'function walkAST(node, visit) {\n\tconst walk = (current) => {\n\t\tvisit(current);\n\t\tswitch (current.k) {\n\t\t\tcase "Comp":\n\t\t\t\tcurrent.args.forEach(walk);\n\t\t\t\tObject.values(current.mappedProps ?? {}).forEach(walk);\n\t\t\t\tbreak;\n\t\t\tcase "Arr":\n\t\t\t\tcurrent.els.forEach(walk);\n\t\t\t\tbreak;\n\t\t\tcase "Obj":\n\t\t\t\tcurrent.entries.forEach(([, value]) => walk(value));\n\t\t\t\tbreak;\n\t\t\tcase "BinOp":\n\t\t\t\twalk(current.left);\n\t\t\t\twalk(current.right);\n\t\t\t\tbreak;\n\t\t\tcase "UnaryOp":\n\t\t\t\twalk(current.operand);\n\t\t\t\tbreak;\n\t\t\tcase "Ternary":\n\t\t\t\twalk(current.cond);\n\t\t\t\twalk(current.then);\n\t\t\t\twalk(current.else);\n\t\t\t\tbreak;\n\t\t\tcase "Member":\n\t\t\t\twalk(current.obj);\n\t\t\t\tbreak;\n\t\t\tcase "Index":\n\t\t\t\twalk(current.obj);\n\t\t\t\twalk(current.index);\n\t\t\t\tbreak;\n\t\t\tcase "Assign":\n\t\t\t\twalk(current.value);\n\t\t\t\tbreak;\n\t\t}\n\t};\n\twalk(node);\n}\n',
    "function walkAST(node, visit) {\n\treturn walkASTMoonbit(node, visit);\n}\n",
  ],
  [
    'function isASTNode(value) {\n\tif (!value || typeof value !== "object" || Array.isArray(value)) return false;\n\treturn AST_KINDS.has(value.k);\n}\n',
    "function isASTNode(value) {\n\treturn isASTNodeMoonbit(value);\n}\n",
  ],
  [
    'function toLiteralAST(value) {\n\tif (value === null || value === void 0) return { k: "Null" };\n\tif (typeof value === "string") return {\n\t\tk: "Str",\n\t\tv: value\n\t};\n\tif (typeof value === "number") return {\n\t\tk: "Num",\n\t\tv: value\n\t};\n\tif (typeof value === "boolean") return {\n\t\tk: "Bool",\n\t\tv: value\n\t};\n\tif (Array.isArray(value)) return {\n\t\tk: "Arr",\n\t\tels: value.map(toLiteralAST)\n\t};\n\tif (typeof value === "object") return {\n\t\tk: "Obj",\n\t\tentries: Object.entries(value).map(([k, v]) => [k, toLiteralAST(v)])\n\t};\n\treturn { k: "Null" };\n}\n',
    "function toLiteralAST(value) {\n\treturn toLiteralASTMoonbit(value);\n}\n",
  ],
  [
    'function literalValue(node) {\n\tswitch (node.k) {\n\t\tcase "Str":\n\t\tcase "Num":\n\t\tcase "Bool": return { v: node.v };\n\t\tcase "Null": return { v: null };\n\t\tcase "Arr": {\n\t\t\tconst v = [];\n\t\t\tfor (const e of node.els) {\n\t\t\t\tconst lit = literalValue(e);\n\t\t\t\tif (!lit) return void 0;\n\t\t\t\tv.push(lit.v);\n\t\t\t}\n\t\t\treturn { v };\n\t\t}\n\t\tcase "Obj": {\n\t\t\tconst v = {};\n\t\t\tfor (const [k, e] of node.entries) {\n\t\t\t\tconst lit = literalValue(e);\n\t\t\t\tif (!lit) return void 0;\n\t\t\t\tv[k] = lit.v;\n\t\t\t}\n\t\t\treturn { v };\n\t\t}\n\t\tdefault: return;\n\t}\n}\n',
    "function literalValue(node) {\n\treturn literalValueMoonbit(node);\n}\n",
  ],
  [
    'function generatePrompt(spec) {\n\tconst rootName = spec.root ?? "Root";\n\tconst hasTools = !!spec.tools?.length;\n\tconst toolCalls = spec.toolCalls ?? hasTools;\n\tconst bindings = spec.bindings ?? toolCalls;\n\tconst supportsExpressions = toolCalls || bindings;\n\tconst usesActionExpression = Object.values(spec.components).some((c) => c.signature?.includes("ActionExpression") || RESTRICTED_SLOT.test(c.signature ?? ""));\n\tconst parts = [];\n\tparts.push(spec.preamble ?? PREAMBLE);\n\tparts.push("");\n\tparts.push(syntaxRules(rootName, {\n\t\tsupportsExpressions,\n\t\tbindings\n\t}));\n\tparts.push("");\n\tparts.push(generateComponentSignatures(spec, {\n\t\ttoolCalls,\n\t\tbindings,\n\t\tusesActionExpression\n\t}));\n\tconst customFunctions = Object.values(spec.functions ?? {}).map(functionLine);\n\tif (spec.builtinFunctions ?? supportsExpressions) {\n\t\tparts.push("");\n\t\tparts.push(builtinFunctionsSection(customFunctions, toolCalls));\n\t} else if (customFunctions.length) {\n\t\tparts.push("");\n\t\tparts.push(`## Built-in Functions\\n\\n${customFunctions.join("\\n")}`);\n\t}\n\tif (toolCalls) {\n\t\tparts.push("");\n\t\tparts.push(querySection());\n\t\tparts.push("");\n\t\tparts.push(mutationSection());\n\t}\n\tconst customActions = Object.values(spec.actions ?? {}).map((a) => `- ${functionLine(a)}`);\n\tif (usesActionExpression) {\n\t\tparts.push("");\n\t\tparts.push(actionSection({\n\t\t\ttoolCalls,\n\t\t\tbindings\n\t\t}, customActions));\n\t} else if (customActions.length) {\n\t\tparts.push("");\n\t\tparts.push(`${ACTION_HEADER}\\n\\nPass one step, or Action([...]) with several steps, as a button\'s action.\\n\\nAvailable steps:\\n${customActions.join("\\n")}`);\n\t}\n\tif (toolCalls && bindings) {\n\t\tparts.push("");\n\t\tparts.push(interactiveFiltersSection());\n\t}\n\tif (toolCalls) {\n\t\tparts.push("");\n\t\tparts.push(toolWorkflowSection());\n\t}\n\tif (spec.tools?.length) {\n\t\tparts.push("");\n\t\tparts.push(renderToolsSection(spec.tools));\n\t}\n\tparts.push("");\n\tparts.push(streamingRules(rootName, {\n\t\tsupportsExpressions,\n\t\ttoolCalls\n\t}));\n\tconst allExamples = [...spec.examples ?? [], ...spec.toolExamples ?? []];\n\tif (allExamples.length) {\n\t\tparts.push("");\n\t\tparts.push("## Examples");\n\t\tparts.push("");\n\t\tfor (const ex of allExamples) {\n\t\t\tparts.push(ex);\n\t\t\tparts.push("");\n\t\t}\n\t}\n\tif (spec.editMode) {\n\t\tparts.push("");\n\t\tparts.push(editModeSection());\n\t}\n\tif (spec.inlineMode) {\n\t\tparts.push("");\n\t\tparts.push(inlineModeSection());\n\t}\n\tparts.push(importantRules(rootName, {\n\t\ttoolCalls,\n\t\tbindings\n\t}));\n\tif (spec.additionalRules?.length) {\n\t\tparts.push("");\n\t\tfor (const rule of spec.additionalRules) parts.push(`- ${rule}`);\n\t}\n\treturn parts.join("\\n");\n}\n',
    "function generatePrompt(spec) {\n\treturn generatePromptMoonbit(spec);\n}\n",
  ],
  [
    'function generateCloudConfig(spec) {\n\tlet config;\n\tif (spec.library) {\n\t\tconst issues = validateChatLibrary(spec.library);\n\t\tif (issues.length > 0) throw new Error(`[generateSystemPrompt] Invalid library: ${issues.map((i) => i.message).join(" ")}`);\n\t\tconst { components: _components, ...chatLibrary } = spec.library;\n\t\tconst promptOptions = pickCloudPromptOptions(spec.promptOptions);\n\t\tconfig = {\n\t\t\tchatLibrary,\n\t\t\t...promptOptions ? { systemPromptOptions: promptOptions } : {}\n\t\t};\n\t} else {\n\t\tif (spec.promptOptions && pickCloudPromptOptions(spec.promptOptions)) throw new Error("[generateSystemPrompt] promptOptions requires a library — the built-in library ignores it.");\n\t\tconfig = { libraryVersion: CLOUD_CHAT_LIBRARY_VERSION };\n\t}\n\tconst block = `${CLOUD_CONFIG_MARKER}${JSON.stringify(config)}`;\n\treturn spec.instructions ? `${block}\\n${spec.instructions}` : block;\n}\n',
    "function generateCloudConfig(spec) {\n\treturn generateCloudConfigMoonbit(spec);\n}\n",
  ],
  [
    'function substituteRef(node, varName, value) {\n\tswitch (node.k) {\n\t\tcase "Ref": return node.n === varName ? toLiteralAST(value) : node;\n\t\tcase "Member":\n\t\t\tif (isASTNode(node.obj)) {\n\t\t\t\tconst subObj = substituteRef(node.obj, varName, value);\n\t\t\t\tif (subObj.k === "Obj") {\n\t\t\t\t\tconst entry = subObj.entries.find(([k]) => k === node.field);\n\t\t\t\t\tif (entry) return entry[1];\n\t\t\t\t}\n\t\t\t\treturn {\n\t\t\t\t\t...node,\n\t\t\t\t\tobj: subObj\n\t\t\t\t};\n\t\t\t}\n\t\t\treturn node;\n\t\tcase "Index": return {\n\t\t\t...node,\n\t\t\tobj: isASTNode(node.obj) ? substituteRef(node.obj, varName, value) : node.obj,\n\t\t\tindex: isASTNode(node.index) ? substituteRef(node.index, varName, value) : node.index\n\t\t};\n\t\tcase "BinOp": return {\n\t\t\t...node,\n\t\t\tleft: substituteRef(node.left, varName, value),\n\t\t\tright: substituteRef(node.right, varName, value)\n\t\t};\n\t\tcase "UnaryOp": return {\n\t\t\t...node,\n\t\t\toperand: substituteRef(node.operand, varName, value)\n\t\t};\n\t\tcase "Ternary": return {\n\t\t\t...node,\n\t\t\tcond: substituteRef(node.cond, varName, value),\n\t\t\tthen: substituteRef(node.then, varName, value),\n\t\t\telse: substituteRef(node.else, varName, value)\n\t\t};\n\t\tcase "Arr": return {\n\t\t\t...node,\n\t\t\tels: node.els.map((e) => substituteRef(e, varName, value))\n\t\t};\n\t\tcase "Obj": return {\n\t\t\t...node,\n\t\t\tentries: node.entries.map(([k, v]) => [k, substituteRef(v, varName, value)])\n\t\t};\n\t\tcase "Comp": {\n\t\t\tconst sub = (a) => substituteRef(a, varName, value);\n\t\t\tconst result = {\n\t\t\t\t...node,\n\t\t\t\targs: node.args.map(sub)\n\t\t\t};\n\t\t\tif (node.mappedProps) result.mappedProps = mapValues(node.mappedProps, sub);\n\t\t\treturn result;\n\t\t}\n\t\tcase "Assign": return {\n\t\t\t...node,\n\t\t\tvalue: substituteRef(node.value, varName, value)\n\t\t};\n\t\tdefault: return node;\n\t}\n}\n',
    "function substituteRef(node, varName, value) {\n\treturn substituteRefMoonbit(node, varName, value);\n}\n",
  ],
  [
    'function generateSystemPrompt(spec) {\n\tif (isCloudSpec(spec)) return generateCloudConfig(spec);\n\tif (!isSystemPromptSpec(spec)) {\n\t\tconst prompt = generatePrompt(spec);\n\t\trecordSystemPromptGeneration(spec, "legacy_prompt_spec");\n\t\treturn prompt;\n\t}\n\tconst merged = {\n\t\t...spec.library,\n\t\t...spec.promptOptions\n\t};\n\tconst prompt = generatePrompt(merged);\n\trecordSystemPromptGeneration(merged, "library_spec");\n\treturn prompt;\n}\n',
    "function generateSystemPrompt(spec) {\n\treturn generateSystemPromptMoonbit(spec);\n}\n",
  ],
  [
    'function isElementNode(value) {\n\tif (!value || typeof value !== "object" || Array.isArray(value)) return false;\n\tconst node = value;\n\treturn node.type === "element" && typeof node.typeName === "string" && typeof node.props === "object" && node.props !== null && typeof node.partial === "boolean";\n}\n',
    "function isElementNode(value) {\n\treturn isElementNodeMoonbit(value);\n}\n",
  ],
  [
    'function isRuntimeExpr(node) {\n\tswitch (node.k) {\n\t\tcase "StateRef":\n\t\tcase "RuntimeRef":\n\t\tcase "BinOp":\n\t\tcase "UnaryOp":\n\t\tcase "Ternary":\n\t\tcase "Member":\n\t\tcase "Index":\n\t\tcase "Assign": return true;\n\t\tdefault: return false;\n\t}\n}\n',
    "function isRuntimeExpr(node) {\n\treturn isRuntimeExprMoonbit(node);\n}\n",
  ],
  [
    'function isReactiveAssign(value) {\n\treturn typeof value === "object" && value !== null && value.__reactive === "assign";\n}\n',
    "function isReactiveAssign(value) {\n\treturn isReactiveAssignMoonbit(value);\n}\n",
  ],
  [
    'function isActionPlan(value) {\n\treturn typeof value === "object" && value !== null && Array.isArray(value.steps);\n}\n',
    "function isActionPlan(value) {\n\treturn isActionPlanMoonbit(value);\n}\n",
  ],
  [
    'function flattenPlans(values) {\n\treturn ownSteps({ steps: values.flatMap((v) => {\n\t\tif (isActionPlan(v)) return v.steps;\n\t\treturn v != null && typeof v === "object" && "type" in v ? [v] : [];\n\t}) });\n}\n',
    "function flattenPlans(values) {\n\treturn flattenPlansMoonbit(values);\n}\n",
  ],
  [
    'function extractToolResult(result) {\n\tif (result.isError) {\n\t\tconst errorText = result.content?.filter((c) => c.type === "text").map((c) => c.text).join("\\n");\n\t\tthrow new McpToolError(errorText || "Unknown error");\n\t}\n\tif (result.structuredContent != null) return result.structuredContent;\n\tconst textParts = result.content?.filter((c) => c.type === "text").map((c) => c.text ?? "");\n\tif (textParts?.length) {\n\t\tconst text = textParts.join("");\n\t\ttry {\n\t\t\treturn JSON.parse(text);\n\t\t} catch {\n\t\t\treturn text;\n\t\t}\n\t}\n\treturn null;\n}\n',
    "function extractToolResult(result) {\n\treturn extractToolResultMoonbit(result);\n}\n",
  ],
  [
    'function stableStringify(value) {\n\treturn JSON.stringify(value, (_key, val) => {\n\t\tif (val && typeof val === "object" && !Array.isArray(val)) {\n\t\t\tconst sorted = {};\n\t\t\tfor (const k of Object.keys(val).sort()) sorted[k] = val[k];\n\t\t\treturn sorted;\n\t\t}\n\t\tif (val === void 0) return "__undefined__";\n\t\tif (typeof val === "number") {\n\t\t\tif (Number.isNaN(val)) return "__NaN__";\n\t\t\tif (val === Infinity) return "__Inf__";\n\t\t\tif (val === -Infinity) return "__-Inf__";\n\t\t}\n\t\treturn val;\n\t});\n}\n',
    "function stableStringify(value) {\n\treturn stableStringifyMoonbit(value);\n}\n",
  ],
  [
    'function buildCacheKey(toolName, args, deps) {\n\tconst depsKey = deps != null ? "::" + stableStringify(deps) : "";\n\treturn toolName + "::" + stableStringify(args) + depsKey;\n}\n',
    "function buildCacheKey(toolName, args, deps) {\n\treturn buildCacheKeyMoonbit(toolName, args, deps);\n}\n",
  ],
  [
    'function resolveField(obj, path) {\n\tif (!path || obj == null) return void 0;\n\tif (!path.includes(".")) return obj[path];\n\tlet cur = obj;\n\tfor (const p of path.split(".")) {\n\t\tif (cur == null) return void 0;\n\t\tcur = cur[p];\n\t}\n\treturn cur;\n}\n',
    "function resolveField(obj, path) {\n\treturn resolveFieldMoonbit(obj, path);\n}\n",
  ],
  [
    'function toNumber(val) {\n\tif (typeof val === "number") return val;\n\tif (typeof val === "string") {\n\t\tconst n = Number(val);\n\t\treturn isNaN(n) ? 0 : n;\n\t}\n\tif (typeof val === "boolean") return val ? 1 : 0;\n\treturn 0;\n}\n',
    "function toNumber(val) {\n\treturn toNumberMoonbit(val);\n}\n",
  ],
  [
    'function evaluateRoot(result, evalCtx) {\n\tif (result.root) return evaluateElementProps(result.root, evalCtx);\n\tif (!result.rootExpression) return null;\n\tconst value = evaluate(result.rootExpression, evalCtx.ctx, { library: evalCtx.library });\n\tif (isElementNode(value)) return evaluateElementProps(value, evalCtx);\n\tevalCtx.errors?.push({\n\t\tsource: "runtime",\n\t\tcode: "no-root",\n\t\tstatementId: "root",\n\t\tmessage: "root does not evaluate to a component"\n\t});\n\treturn null;\n}\n',
    "function evaluateRoot(result, evalCtx) {\n\treturn evaluateRootMoonbit(result, evalCtx);\n}\n",
  ],
  [
    'function evaluateLazyBuiltin(name, args, context, schemaCtx) {\n\tif (name === "Each") {\n\t\tif (args.length < 3) return [];\n\t\tconst arr = evaluate(args[0], context);\n\t\tif (!Array.isArray(arr)) return [];\n\t\tconst varName = args[1].k === "Ref" ? args[1].n : args[1].k === "Str" ? args[1].v : null;\n\t\tif (!varName) return [];\n\t\tconst template = args[2];\n\t\treturn arr.map((item, _idx) => {\n\t\t\tconst substituted = substituteRef(template, varName, item);\n\t\t\tconst childCtx = {\n\t\t\t\t...context,\n\t\t\t\tresolveRef: (refName) => {\n\t\t\t\t\tif (refName === varName) return item;\n\t\t\t\t\treturn context.resolveRef(refName);\n\t\t\t\t}\n\t\t\t};\n\t\t\tconst result = evaluate(substituted, childCtx, schemaCtx);\n\t\t\tif (schemaCtx && isElementNode(result)) return evaluateElementInline(result, childCtx, schemaCtx);\n\t\t\treturn result;\n\t\t});\n\t}\n\treturn null;\n}\n',
    "function evaluateLazyBuiltin(name, args, context, schemaCtx) {\n\treturn evaluateLazyBuiltinMoonbit(name, args, context, schemaCtx);\n}\n",
  ],
  [
    'function evaluatePropValue$1(value, context, schemaCtx, reactiveSchema, callbacks) {\n\tif (value == null) return value;\n\tif (typeof value !== "object") return value;\n\tif (isASTNode(value)) {\n\t\tif (value.k === "StateRef" && reactiveSchema && isReactiveSchema(reactiveSchema)) return {\n\t\t\t__reactive: "assign",\n\t\t\ttarget: value.n,\n\t\t\texpr: {\n\t\t\t\tk: "StateRef",\n\t\t\t\tn: "$value"\n\t\t\t}\n\t\t};\n\t\tconst result = evaluate(value, context, schemaCtx);\n\t\tif (isElementNode(result)) return callbacks.recurseElement(result);\n\t\tif (Array.isArray(result)) return result.map((item) => isElementNode(item) ? callbacks.recurseElement(item) : item);\n\t\tif (isReactiveAssign(result) && !(reactiveSchema && isReactiveSchema(reactiveSchema))) return context.getState(result.target) ?? null;\n\t\treturn result;\n\t}\n\tif (typeof value === "string" && reactiveSchema && isReactiveSchema(reactiveSchema)) return value;\n\tif (Array.isArray(value)) return value.map((v) => callbacks.recurse(v, reactiveSchema));\n\tif (isElementNode(value)) return callbacks.recurseElement(value);\n\tif (isActionPlan(value)) return value;\n\tconst obj = value;\n\tlet needsEval = false;\n\tfor (const val of Object.values(obj)) if (typeof val === "object" && val !== null) {\n\t\tneedsEval = true;\n\t\tbreak;\n\t}\n\tif (needsEval) {\n\t\tconst result = {};\n\t\tfor (const [k, v] of Object.entries(obj)) result[k] = callbacks.recurse(v, reactiveSchema);\n\t\treturn result;\n\t}\n\treturn value;\n}\n',
    "function evaluatePropValue$1(value, context, schemaCtx, reactiveSchema, callbacks) {\n\treturn evaluatePropValueMoonbit(value, context, schemaCtx, reactiveSchema, callbacks);\n}\n",
  ],
  [
    'function evaluateElementProps(el, evalCtx) {\n\tif (el.hasDynamicProps === false) return el;\n\tconst schemaCtx = { library: evalCtx.library };\n\tconst def = evalCtx.library.components[el.typeName];\n\tconst evaluated = {};\n\tlet key = "";\n\tconst report = (msg) => {\n\t\tevalCtx.errors?.push({\n\t\t\tsource: "runtime",\n\t\t\tcode: "runtime-error",\n\t\t\tcomponent: el.typeName,\n\t\t\tstatementId: el.statementId,\n\t\t\tmessage: `Evaluating prop "${key}" on ${el.typeName} failed: ${msg}`,\n\t\t\thint: `Check the expression used for prop "${key}"`\n\t\t});\n\t};\n\tconst propCtx = evalCtx.ctx.functions || evalCtx.ctx.actions ? {\n\t\t...evalCtx,\n\t\tctx: {\n\t\t\t...evalCtx.ctx,\n\t\t\treportError: report\n\t\t}\n\t} : evalCtx;\n\tfor (const [propKey, value] of Object.entries(el.props)) {\n\t\tkey = propKey;\n\t\tconst propSchema = def?.props?.shape?.[key];\n\t\ttry {\n\t\t\tevaluated[key] = evaluatePropValue(value, propCtx, schemaCtx, propSchema);\n\t\t} catch (e) {\n\t\t\tevaluated[key] = value;\n\t\t\treport(e instanceof Error ? e.message : String(e));\n\t\t}\n\t}\n\treturn {\n\t\t...el,\n\t\tprops: evaluated\n\t};\n}\n',
    "function evaluateElementProps(el, evalCtx) {\n\treturn evaluateElementPropsMoonbit(el, evalCtx);\n}\n",
  ],
  [
    'function createStore() {\n\tconst state = /* @__PURE__ */ new Map();\n\tconst pristine = /* @__PURE__ */ new Set();\n\tconst listeners = /* @__PURE__ */ new Set();\n\tlet snapshot = {};\n\tfunction notify() {\n\t\tconst currentListeners = [...listeners];\n\t\tfor (const listener of currentListeners) listener();\n\t}\n\tfunction rebuildSnapshot() {\n\t\tsnapshot = Object.fromEntries(state);\n\t}\n\tfunction get(name) {\n\t\treturn state.get(name);\n\t}\n\tfunction set(name, value, options) {\n\t\tif (options?.pristine) pristine.add(name);\n\t\telse pristine.delete(name);\n\t\tconst existing = state.get(name);\n\t\tif (Object.is(existing, value)) return;\n\t\tif (value && existing && typeof value === "object" && typeof existing === "object" && !Array.isArray(value) && !Array.isArray(existing)) {\n\t\t\tconst nk = Object.keys(value);\n\t\t\tconst ok = Object.keys(existing);\n\t\t\tif (nk.length === ok.length && nk.every((k) => Object.is(value[k], existing[k]))) return;\n\t\t}\n\t\tstate.set(name, value);\n\t\trebuildSnapshot();\n\t\tnotify();\n\t}\n\tfunction subscribe(listener) {\n\t\tlisteners.add(listener);\n\t\treturn () => {\n\t\t\tlisteners.delete(listener);\n\t\t};\n\t}\n\tfunction getSnapshot() {\n\t\treturn snapshot;\n\t}\n\tfunction initialize(defaults, persisted) {\n\t\tlet changed = false;\n\t\tfor (const key of Object.keys(persisted)) {\n\t\t\tpristine.delete(key);\n\t\t\tif (!state.has(key) || !Object.is(state.get(key), persisted[key])) {\n\t\t\t\tstate.set(key, persisted[key]);\n\t\t\t\tchanged = true;\n\t\t\t}\n\t\t}\n\t\tfor (const key of Object.keys(defaults)) if (!state.has(key)) {\n\t\t\tstate.set(key, defaults[key]);\n\t\t\tpristine.add(key);\n\t\t\tchanged = true;\n\t\t} else if (pristine.has(key) && !Object.is(state.get(key), defaults[key])) {\n\t\t\tstate.set(key, defaults[key]);\n\t\t\tchanged = true;\n\t\t}\n\t\tif (changed) {\n\t\t\trebuildSnapshot();\n\t\t\tnotify();\n\t\t}\n\t}\n\tfunction dispose() {\n\t\tstate.clear();\n\t\tpristine.clear();\n\t\tlisteners.clear();\n\t\tsnapshot = {};\n\t}\n\treturn {\n\t\tget,\n\t\tset,\n\t\tsubscribe,\n\t\tgetSnapshot,\n\t\tinitialize,\n\t\tdispose\n\t};\n}\n',
    "function createStore() {\n\treturn createStoreMoonbit();\n}\n",
  ],
  [
    'function createQueryManager(toolProvider) {\n\tconst queries = /* @__PURE__ */ new Map();\n\tconst mutations = /* @__PURE__ */ new Map();\n\tconst cache = /* @__PURE__ */ new Map();\n\tconst listeners = /* @__PURE__ */ new Set();\n\tlet snapshot = {\n\t\t__openui_loading: [],\n\t\t__openui_refetching: [],\n\t\t__openui_errors: []\n\t};\n\tlet snapshotJson = JSON.stringify(snapshot);\n\tlet disposed = false;\n\tlet generation = 0;\n\tfunction rebuildSnapshot() {\n\t\tconst out = {\n\t\t\t__openui_loading: [],\n\t\t\t__openui_refetching: [],\n\t\t\t__openui_errors: []\n\t\t};\n\t\tfor (const [sid, q] of queries) {\n\t\t\tconst entry = cache.get(q.cacheKey);\n\t\t\tif (entry && entry.data !== void 0) out[sid] = entry.data;\n\t\t\telse if (q.prevCacheKey) {\n\t\t\t\tconst prev = cache.get(q.prevCacheKey);\n\t\t\t\tif (prev && prev.data !== void 0) out[sid] = prev.data;\n\t\t\t\telse out[sid] = q.defaults;\n\t\t\t} else out[sid] = q.defaults;\n\t\t\tif (q.loading) {\n\t\t\t\tout.__openui_loading.push(sid);\n\t\t\t\tif (q.everFetched) out.__openui_refetching.push(sid);\n\t\t\t}\n\t\t\tif (q.error) out.__openui_errors.push(q.error);\n\t\t}\n\t\tfor (const [sid, m] of mutations) {\n\t\t\tout[sid] = m.result;\n\t\t\tif (m.error) out.__openui_errors.push(m.error);\n\t\t}\n\t\ttry {\n\t\t\tconst outJson = JSON.stringify(out);\n\t\t\tif (outJson === snapshotJson) return false;\n\t\t\tsnapshot = out;\n\t\t\tsnapshotJson = outJson;\n\t\t} catch {\n\t\t\tsnapshot = out;\n\t\t\tsnapshotJson = "";\n\t\t}\n\t\treturn true;\n\t}\n\tfunction notify() {\n\t\tfor (const listener of [...listeners]) listener();\n\t}\n\tasync function executeFetch(cacheKey, statementId) {\n\t\tif (!toolProvider) return;\n\t\tconst q = queries.get(statementId);\n\t\tif (!q) return;\n\t\tconst fetchKey = cacheKey;\n\t\tconst toolName = q.toolName;\n\t\tconst args = q.args;\n\t\tlet entry = cache.get(fetchKey);\n\t\tif (!entry) {\n\t\t\tentry = {\n\t\t\t\tdata: void 0,\n\t\t\t\tinFlight: true\n\t\t\t};\n\t\t\tcache.set(fetchKey, entry);\n\t\t} else entry.inFlight = true;\n\t\tq.loading = true;\n\t\trebuildSnapshot();\n\t\tnotify();\n\t\ttry {\n\t\t\tconst data = await toolProvider.callTool(toolName, args ?? {});\n\t\t\tif (disposed) return;\n\t\t\tconst current = queries.get(statementId);\n\t\t\tif (!current || current.cacheKey !== fetchKey) {\n\t\t\t\tentry.inFlight = false;\n\t\t\t\treturn;\n\t\t\t}\n\t\t\tentry.data = data ?? null;\n\t\t\tcurrent.everFetched = true;\n\t\t\tcurrent.error = void 0;\n\t\t\tif (current.prevCacheKey && current.prevCacheKey !== fetchKey) {\n\t\t\t\tconst prevKey = current.prevCacheKey;\n\t\t\t\tcurrent.prevCacheKey = void 0;\n\t\t\t\tcleanupCacheEntry(prevKey);\n\t\t\t}\n\t\t} catch (err) {\n\t\t\tconst current = queries.get(statementId);\n\t\t\tif (current && current.cacheKey === fetchKey) if (err instanceof ToolNotFoundError) current.error = {\n\t\t\t\tsource: "query",\n\t\t\t\tcode: "tool-not-found",\n\t\t\t\tmessage: `Query tool "${toolName}" not found`,\n\t\t\t\tstatementId,\n\t\t\t\tcomponent: "Query",\n\t\t\t\ttoolName,\n\t\t\t\thint: err.availableTools.length ? `Available tools: ${err.availableTools.join(", ")}` : void 0\n\t\t\t};\n\t\t\telse if (err instanceof McpToolError) current.error = {\n\t\t\t\tsource: "query",\n\t\t\t\tcode: "mcp-error",\n\t\t\t\tmessage: `Query "${toolName}" returned an error: ${err.toolErrorText}`,\n\t\t\t\tstatementId,\n\t\t\t\tcomponent: "Query",\n\t\t\t\ttoolName\n\t\t\t};\n\t\t\telse current.error = {\n\t\t\t\tsource: "query",\n\t\t\t\tcode: "tool-error",\n\t\t\t\tmessage: `Query "${toolName}" failed: ${err instanceof Error ? err.message : String(err)}`,\n\t\t\t\tstatementId,\n\t\t\t\tcomponent: "Query",\n\t\t\t\ttoolName\n\t\t\t};\n\t\t\tconsole.error(`Query "${toolName}" failed:`, err);\n\t\t} finally {\n\t\t\tentry.inFlight = false;\n\t\t\tconst current = queries.get(statementId);\n\t\t\tif (current && current.cacheKey === fetchKey) {\n\t\t\t\tcurrent.loading = false;\n\t\t\t\tif (rebuildSnapshot()) notify();\n\t\t\t\tif (current.needsRefetch) {\n\t\t\t\t\tcurrent.needsRefetch = false;\n\t\t\t\t\texecuteFetch(current.cacheKey, statementId);\n\t\t\t\t}\n\t\t\t} else if (rebuildSnapshot()) notify();\n\t\t}\n\t}\n\t/** Remove a cache entry if no query references it. */\n\tfunction cleanupCacheEntry(cacheKey) {\n\t\tfor (const q of queries.values()) if (q.cacheKey === cacheKey || q.prevCacheKey === cacheKey) return;\n\t\tcache.delete(cacheKey);\n\t}\n\tfunction evaluateQueries(queryNodes) {\n\t\tif (disposed) return;\n\t\tconst activeIds = new Set(queryNodes.map((n) => n.statementId));\n\t\tfor (const [sid, q] of queries) if (!activeIds.has(sid)) {\n\t\t\tif (q.timer) clearInterval(q.timer);\n\t\t\tqueries.delete(sid);\n\t\t\tcleanupCacheEntry(q.cacheKey);\n\t\t\tif (q.prevCacheKey) cleanupCacheEntry(q.prevCacheKey);\n\t\t}\n\t\tfor (const node of queryNodes) {\n\t\t\tif (!node.complete) continue;\n\t\t\tconst cacheKey = buildCacheKey(node.toolName, node.args, node.deps);\n\t\t\tconst existing = queries.get(node.statementId);\n\t\t\tif (existing) {\n\t\t\t\tif (existing.cacheKey !== cacheKey) existing.prevCacheKey = existing.cacheKey;\n\t\t\t\texisting.toolName = node.toolName;\n\t\t\t\texisting.args = node.args;\n\t\t\t\texisting.defaults = node.defaults;\n\t\t\t\texisting.cacheKey = cacheKey;\n\t\t\t} else queries.set(node.statementId, {\n\t\t\t\ttoolName: node.toolName,\n\t\t\t\targs: node.args,\n\t\t\t\tdefaults: node.defaults,\n\t\t\t\tcacheKey,\n\t\t\t\tloading: false,\n\t\t\t\teverFetched: false,\n\t\t\t\trefreshInterval: 0,\n\t\t\t\tneedsRefetch: false\n\t\t\t});\n\t\t\tconst q = queries.get(node.statementId);\n\t\t\tconst entry = cache.get(cacheKey);\n\t\t\tconst hasSettledData = entry && entry.data !== void 0 && !entry.inFlight;\n\t\t\tif (toolProvider && !hasSettledData && !entry?.inFlight) executeFetch(cacheKey, node.statementId);\n\t\t\tconst newInterval = node.refreshInterval ?? 0;\n\t\t\tif (newInterval !== q.refreshInterval) {\n\t\t\t\tif (q.timer) {\n\t\t\t\t\tclearInterval(q.timer);\n\t\t\t\t\tq.timer = void 0;\n\t\t\t\t}\n\t\t\t\tif (newInterval > 0) q.timer = setInterval(() => {\n\t\t\t\t\tif (disposed || !toolProvider) return;\n\t\t\t\t\tif (!cache.get(q.cacheKey)?.inFlight) executeFetch(q.cacheKey, node.statementId);\n\t\t\t\t}, newInterval * 1e3);\n\t\t\t\tq.refreshInterval = newInterval;\n\t\t\t}\n\t\t}\n\t\tif (rebuildSnapshot()) notify();\n\t}\n\tfunction getResult(statementId) {\n\t\tconst q = queries.get(statementId);\n\t\tif (!q) return null;\n\t\tconst entry = cache.get(q.cacheKey);\n\t\tif (entry && entry.data !== void 0) return entry.data;\n\t\tif (q.prevCacheKey) {\n\t\t\tconst prev = cache.get(q.prevCacheKey);\n\t\t\tif (prev && prev.data !== void 0) return prev.data;\n\t\t}\n\t\treturn q.defaults;\n\t}\n\tfunction isLoading(statementId) {\n\t\treturn queries.get(statementId)?.loading ?? false;\n\t}\n\tfunction isAnyLoading() {\n\t\tfor (const q of queries.values()) if (q.loading) return true;\n\t\treturn false;\n\t}\n\tfunction invalidate(statementIds) {\n\t\tif (disposed || !toolProvider) return;\n\t\tconst targets = statementIds?.length ? statementIds.filter((sid) => queries.has(sid)) : [...queries.keys()];\n\t\tfor (const sid of targets) {\n\t\t\tconst q = queries.get(sid);\n\t\t\tif (!q) continue;\n\t\t\tif (cache.get(q.cacheKey)?.inFlight) q.needsRefetch = true;\n\t\t\telse executeFetch(q.cacheKey, sid);\n\t\t}\n\t}\n\tfunction registerMutations(nodes) {\n\t\tconst activeIds = new Set(nodes.map((n) => n.statementId));\n\t\tfor (const sid of mutations.keys()) if (!activeIds.has(sid)) mutations.delete(sid);\n\t\tfor (const node of nodes) {\n\t\t\tconst existing = mutations.get(node.statementId);\n\t\t\tif (existing) {\n\t\t\t\tif (existing.toolName !== node.toolName) {\n\t\t\t\t\texisting.toolName = node.toolName;\n\t\t\t\t\texisting.result = {\n\t\t\t\t\t\tstatus: "idle",\n\t\t\t\t\t\tdata: null,\n\t\t\t\t\t\terror: null\n\t\t\t\t\t};\n\t\t\t\t\texisting.error = void 0;\n\t\t\t\t}\n\t\t\t} else mutations.set(node.statementId, {\n\t\t\t\ttoolName: node.toolName,\n\t\t\t\tresult: { status: "idle" }\n\t\t\t});\n\t\t}\n\t\tif (rebuildSnapshot()) notify();\n\t}\n\tasync function fireMutation(statementId, evaluatedArgs, refreshQueryIds) {\n\t\tif (disposed || !toolProvider) return false;\n\t\tconst m = mutations.get(statementId);\n\t\tif (!m) return false;\n\t\tif (m.result.status === "loading") return false;\n\t\tconst gen = generation;\n\t\tm.result = { status: "loading" };\n\t\trebuildSnapshot();\n\t\tnotify();\n\t\tlet success = false;\n\t\ttry {\n\t\t\tconst data = await toolProvider.callTool(m.toolName, evaluatedArgs);\n\t\t\tif (disposed || gen !== generation) return false;\n\t\t\tm.result = {\n\t\t\t\tstatus: "success",\n\t\t\t\tdata\n\t\t\t};\n\t\t\tm.error = void 0;\n\t\t\tsuccess = true;\n\t\t} catch (err) {\n\t\t\tif (disposed || gen !== generation) return false;\n\t\t\tconst msg = err instanceof Error ? err.message : String(err);\n\t\t\tm.result = {\n\t\t\t\tstatus: "error",\n\t\t\t\terror: msg\n\t\t\t};\n\t\t\tif (err instanceof ToolNotFoundError) m.error = {\n\t\t\t\tsource: "mutation",\n\t\t\t\tcode: "tool-not-found",\n\t\t\t\tmessage: `Mutation tool "${m.toolName}" not found`,\n\t\t\t\tstatementId,\n\t\t\t\tcomponent: "Mutation",\n\t\t\t\ttoolName: m.toolName,\n\t\t\t\thint: err.availableTools.length ? `Available tools: ${err.availableTools.join(", ")}` : void 0\n\t\t\t};\n\t\t\telse if (err instanceof McpToolError) m.error = {\n\t\t\t\tsource: "mutation",\n\t\t\t\tcode: "mcp-error",\n\t\t\t\tmessage: `Mutation "${m.toolName}" returned an error: ${err.toolErrorText}`,\n\t\t\t\tstatementId,\n\t\t\t\tcomponent: "Mutation",\n\t\t\t\ttoolName: m.toolName\n\t\t\t};\n\t\t\telse m.error = {\n\t\t\t\tsource: "mutation",\n\t\t\t\tcode: "tool-error",\n\t\t\t\tmessage: `Mutation "${m.toolName}" failed: ${msg}`,\n\t\t\t\tstatementId,\n\t\t\t\tcomponent: "Mutation",\n\t\t\t\ttoolName: m.toolName\n\t\t\t};\n\t\t}\n\t\trebuildSnapshot();\n\t\tnotify();\n\t\tif (success && refreshQueryIds?.length) invalidate(refreshQueryIds);\n\t\treturn success;\n\t}\n\tfunction getMutationResult(statementId) {\n\t\treturn mutations.get(statementId)?.result ?? null;\n\t}\n\tfunction subscribe(listener) {\n\t\tlisteners.add(listener);\n\t\treturn () => listeners.delete(listener);\n\t}\n\tfunction getSnapshot() {\n\t\treturn snapshot;\n\t}\n\tfunction activate() {\n\t\tdisposed = false;\n\t}\n\tfunction dispose() {\n\t\tdisposed = true;\n\t\tgeneration++;\n\t\tlisteners.clear();\n\t\tfor (const q of queries.values()) {\n\t\t\tif (q.timer) {\n\t\t\t\tclearInterval(q.timer);\n\t\t\t\tq.timer = void 0;\n\t\t\t}\n\t\t\tq.refreshInterval = 0;\n\t\t\tq.loading = false;\n\t\t\tq.needsRefetch = false;\n\t\t}\n\t\tmutations.clear();\n\t}\n\treturn {\n\t\tevaluateQueries,\n\t\tgetResult,\n\t\tisLoading,\n\t\tisAnyLoading,\n\t\tinvalidate,\n\t\tregisterMutations,\n\t\tfireMutation,\n\t\tgetMutationResult,\n\t\tsubscribe,\n\t\tgetSnapshot,\n\t\tactivate,\n\t\tdispose\n\t};\n}\n',
    "function createQueryManager(toolProvider) {\n\treturn createQueryManagerMoonbit(toolProvider);\n}\n",
  ],
  [
    "function stripReactiveAssign(value, context) {\n\tif (!isReactiveAssign(value)) return value;\n\treturn context.getState(value.target) ?? null;\n}\n",
    "function stripReactiveAssign(value, context) {\n\treturn stripReactiveAssignMoonbit(value, context);\n}\n",
  ],
  [
    "function resolveStateField(name, bindingValue, store, evaluationContext, fieldGetter, fieldSetter) {\n\tif (isReactiveAssign(bindingValue) && store && evaluationContext) {\n\t\tconst { target, expr } = bindingValue;\n\t\treturn {\n\t\t\tname,\n\t\t\tvalue: store.get(target),\n\t\t\tsetValue: (value) => {\n\t\t\t\tconst extraScope = { $value: value };\n\t\t\t\tconst nextValue = evaluate(expr, {\n\t\t\t\t\t...evaluationContext,\n\t\t\t\t\textraScope\n\t\t\t\t});\n\t\t\t\tstore.set(target, nextValue);\n\t\t\t},\n\t\t\tisReactive: true\n\t\t};\n\t}\n\treturn {\n\t\tname,\n\t\tvalue: fieldGetter(name) ?? bindingValue,\n\t\tsetValue: (value) => fieldSetter(name, value),\n\t\tisReactive: false\n\t};\n}\n",
    "function resolveStateField(name, bindingValue, store, evaluationContext, fieldGetter, fieldSetter) {\n\treturn resolveStateFieldMoonbit(name, bindingValue, store, evaluationContext, fieldGetter, fieldSetter);\n}\n",
  ],
  [
    "function callArgs(node, context, params) {\n\tconst args = evaluateArgs(node, context, Object.keys(params.properties ?? {}).map((name) => ({\n\t\tname,\n\t\trequired: false\n\t})));\n\tfor (const key in args) if (args[key] === null && !params.required?.includes(key)) delete args[key];\n\treturn args;\n}\n",
    "function callArgs(node, context, params) {\n\treturn callArgsMoonbit(node, context, params);\n}\n",
  ],
  [
    "function missesRequired(args, params) {\n\treturn !!params.required?.some((key) => args[key] == null && getSchemaDefaultValue(params.properties?.[key]) === void 0);\n}\n",
    "function missesRequired(args, params) {\n\treturn missesRequiredMoonbit(args, params);\n}\n",
  ],
  [
    'fn: ({ array, field, direction }) => {\n\t\t\tif (!Array.isArray(array)) return array;\n\t\t\tconst f = String(field ?? "");\n\t\t\tconst desc = String(direction ?? "asc") === "desc";\n\t\t\treturn [...array].sort((a, b) => {\n\t\t\t\tconst av = f ? resolveField(a, f) : a;\n\t\t\t\tconst bv = f ? resolveField(b, f) : b;\n\t\t\t\tconst aIsNumeric = typeof av === "number" || typeof av === "string" && !isNaN(Number(av)) && av !== "";\n\t\t\t\tconst bIsNumeric = typeof bv === "number" || typeof bv === "string" && !isNaN(Number(bv)) && bv !== "";\n\t\t\t\tif (aIsNumeric && bIsNumeric) {\n\t\t\t\t\tconst diff = toNumber(av) - toNumber(bv);\n\t\t\t\t\treturn desc ? -diff : diff;\n\t\t\t\t}\n\t\t\t\tconst cmp = String(av ?? "").localeCompare(String(bv ?? ""));\n\t\t\t\treturn desc ? -cmp : cmp;\n\t\t\t});\n\t\t}',
    "fn: ({ array, field, direction }) => sortArrayMoonbit(array, field, direction)",
  ],
  [
    'fn: ({ array, field, operator, value }) => {\n\t\t\tif (!Array.isArray(array)) return [];\n\t\t\tconst f = String(field ?? "");\n\t\t\tconst o = String(operator ?? "==");\n\t\t\treturn array.filter((item) => {\n\t\t\t\tconst v = f ? resolveField(item, f) : item;\n\t\t\t\tswitch (o) {\n\t\t\t\t\tcase "==": return v == value;\n\t\t\t\t\tcase "!=": return v != value;\n\t\t\t\t\tcase ">": return toNumber(v) > toNumber(value);\n\t\t\t\t\tcase "<": return toNumber(v) < toNumber(value);\n\t\t\t\t\tcase ">=": return toNumber(v) >= toNumber(value);\n\t\t\t\t\tcase "<=": return toNumber(v) <= toNumber(value);\n\t\t\t\t\tcase "contains": return String(v ?? "").includes(String(value ?? ""));\n\t\t\t\t\tdefault: return false;\n\t\t\t\t}\n\t\t\t});\n\t\t}',
    "fn: ({ array, field, operator, value }) => filterArrayMoonbit(array, field, operator, value)",
  ],
  [
    "function evaluateElementInline(el, context, schemaCtx) {\n\tif (el.hasDynamicProps === false) return el;\n\tconst def = schemaCtx.library.components[el.typeName];\n\tconst evaluated = {};\n\tfor (const [key, value] of Object.entries(el.props)) {\n\t\tconst propSchema = def?.props?.shape?.[key];\n\t\tevaluated[key] = evaluatePropInline(value, context, schemaCtx, propSchema);\n\t}\n\treturn {\n\t\t...el,\n\t\tprops: evaluated\n\t};\n}\n",
    "function evaluateElementInline(el, context, schemaCtx) {\n\treturn evaluateElementInlineMoonbit(el, context, schemaCtx);\n}\n",
  ],
  [
    'function isEmpty(value) {\n\tif (value === null || value === void 0 || value === "") return true;\n\tif (Array.isArray(value) && value.length === 0) return true;\n\tif (value && typeof value === "object" && !Array.isArray(value) && "value" in value) return isEmpty(value.value);\n\tif (typeof value === "object" && value !== null && !Array.isArray(value) && Object.keys(value).length === 0) return true;\n\treturn false;\n}\n',
    "function isEmpty(value) {\n\treturn isEmptyMoonbit(value);\n}\n",
  ],
  [
    'function validate(value, rules, customValidators) {\n\tfor (const rule of rules) {\n\t\tconst validator = customValidators?.[rule.type] ?? builtInValidators[rule.type];\n\t\tif (!validator) {\n\t\t\tconsole.warn(`[openui] Unknown validation rule type: "${rule.type}"`);\n\t\t\tcontinue;\n\t\t}\n\t\tconst error = validator(value, rule.arg);\n\t\tif (error) return error;\n\t}\n}\n',
    "function validate(value, rules, customValidators) {\n\treturn validateMoonbit(value, rules, customValidators);\n}\n",
  ],
  [
    'function callFunction(name, def, node, context) {\n\tconst raw = callArgs(node, context, def.params);\n\tif (missesRequired(raw, def.params)) return null;\n\tconst args = checkValue(raw, def.params, name, "", context);\n\tif (args === INVALID) return null;\n\tlet result;\n\ttry {\n\t\tresult = def.fn(args);\n\t} catch (e) {\n\t\tcontext.reportError?.(`@${name} threw: ${e instanceof Error ? e.message : String(e)}`);\n\t\treturn null;\n\t}\n\tif (!def.returns) return result;\n\tconst checked = checkValue(result, def.returns, name, "/returns", context);\n\treturn checked === INVALID ? null : checked ?? null;\n}\n',
    "function callFunction(name, def, node, context) {\n\treturn callFunctionMoonbit(name, def, node, context);\n}\n",
  ],
  [
    'function jsType(value) {\n\treturn Array.isArray(value) ? "array" : typeof value;\n}\n',
    "function jsType(value) {\n\treturn jsTypeMoonbit(value);\n}\n",
  ],
  [
    'function getScalarTypeInfo(s) {\n\tif (Array.isArray(s["enum"])) return { enumValues: s["enum"] };\n\tif ("const" in s) return { enumValues: [s["const"]] };\n\tswitch (s["type"]) {\n\t\tcase "string": return { expectedType: "string" };\n\t\tcase "number":\n\t\tcase "integer": return { expectedType: "number" };\n\t\tcase "boolean": return { expectedType: "boolean" };\n\t\tdefault: return {};\n\t}\n}\n',
    "function getScalarTypeInfo(s) {\n\treturn getScalarTypeInfoMoonbit(s);\n}\n",
  ],
  [
    'function checkTypeMismatch(value, info) {\n\tconst actual = typeof value;\n\tif (info.enumValues) {\n\t\tif (!SCALAR_TYPEOFS.includes(actual)) return null;\n\t\tif (info.enumValues.includes(value)) return null;\n\t\treturn {\n\t\t\texpected: `one of [${info.enumValues.map((v) => JSON.stringify(v)).join(", ")}]`,\n\t\t\tactual: JSON.stringify(value)\n\t\t};\n\t}\n\tif (info.expectedType && info.expectedType !== actual) return {\n\t\texpected: info.expectedType,\n\t\tactual: jsType(value)\n\t};\n\treturn null;\n}\n',
    "function checkTypeMismatch(value, info) {\n\treturn checkTypeMismatchMoonbit(value, info);\n}\n",
  ],
  [
    'function validationMessage(component, path, issue) {\n\tswitch (issue.code) {\n\t\tcase "type-mismatch": return `field "${path}" expects ${issue.expected} but got ${issue.actual}`;\n\t\tcase "missing-required": return `missing required field "${path}"${issue.signature ? ` — signature: ${issue.signature}` : ""}`;\n\t\tcase "null-required": return `required field "${path}" cannot be null${issue.signature ? ` — signature: ${issue.signature}` : ""}`;\n\t\tcase "unknown-component": return `Unknown component "${component}" — not found in catalog or builtins${issue.available?.length ? `. Available components: ${issue.available.join(", ")}` : ""}`;\n\t\tcase "inline-reserved": return `${component}() must be declared as a top-level statement, not used inline as a value`;\n\t\tcase "excess-args": return `${component} takes ${issue.declared} arg(s), got ${issue.got} (${issue.got - issue.declared} excess dropped)`;\n\t\tcase "unknown-function": return `Unknown function "@${component}": not a built-in or action step. The call evaluates to null`;\n\t\tcase "no-root":\n\t\t\tif (issue.reason === "not-component") return "root does not evaluate to a component";\n\t\t\tif (issue.reason === "fallback") return `No root statement. Rendering the first statement that calls the root component ${component}`;\n\t\t\treturn component ? `No root statement, and no statement calls the root component ${component}` : "No root statement";\n\t}\n}\n',
    "function validationMessage(component, path, issue) {\n\treturn validationMessageMoonbit(component, path, issue);\n}\n",
  ],
  [
    "function resolveInvalidValue(required, defaultValue) {\n\tif (defaultValue !== void 0) return defaultValue;\n\treturn required ? INVALID : void 0;\n}\n",
    "function resolveInvalidValue(required, defaultValue) {\n\treturn resolveInvalidValueMoonbit(required, defaultValue);\n}\n",
  ],
  [
    'function validateElementPosition(element, s, component, path, ctx) {\n\tif (isCompositeSchema(s)) return false;\n\tif (typeof s["type"] === "string" || Array.isArray(s["enum"]) || "const" in s) {\n\t\tpushValidationIssue(ctx, component, path, {\n\t\t\tcode: "type-mismatch",\n\t\t\texpected: typeof s["type"] === "string" ? s["type"] : "a literal value",\n\t\t\tactual: `component "${element.typeName}"`\n\t\t});\n\t\treturn true;\n\t}\n\treturn false;\n}\n',
    "function validateElementPosition(element, s, component, path, ctx) {\n\treturn validateElementPositionMoonbit(element, s, component, path, ctx);\n}\n",
  ],
  [
    'function validateObjectValue(value, s, component, path, ctx) {\n\tif (typeof value !== "object" || Array.isArray(value)) {\n\t\tpushValidationIssue(ctx, component, path, {\n\t\t\tcode: "type-mismatch",\n\t\t\texpected: "object",\n\t\t\tactual: jsType(value)\n\t\t});\n\t\treturn INVALID;\n\t}\n\tconst obj = value;\n\tlet out;\n\tconst props = s["properties"] && typeof s["properties"] === "object" ? s["properties"] : NO_PROPS;\n\tconst required = Array.isArray(s["required"]) ? s["required"] : NO_REQUIRED;\n\tlet invalid = false;\n\tif (!ctx.partial) for (const key of required) {\n\t\tconst present = key in obj;\n\t\tif (!present || obj[key] == null) {\n\t\t\tconst fallback = getSchemaDefaultValue(props[key]);\n\t\t\tif (fallback !== void 0) {\n\t\t\t\t(out ??= { ...obj })[key] = fallback;\n\t\t\t\tcontinue;\n\t\t\t}\n\t\t\tpushValidationIssue(ctx, component, `${path}/${key}`, { code: present ? "null-required" : "missing-required" });\n\t\t\tinvalid = true;\n\t\t}\n\t}\n\tfor (const key of Object.keys(props)) {\n\t\tif (!(key in obj)) continue;\n\t\tconst sub = props[key];\n\t\tlet next = validateSchemaValue(obj[key], sub, component, `${path}/${key}`, ctx);\n\t\tif (next === INVALID) {\n\t\t\tnext = resolveInvalidValue(required.includes(key), getSchemaDefaultValue(sub));\n\t\t\tif (next === INVALID) {\n\t\t\t\tinvalid = true;\n\t\t\t\tcontinue;\n\t\t\t}\n\t\t}\n\t\tif (next === obj[key]) continue;\n\t\tout ??= { ...obj };\n\t\tif (next === void 0) delete out[key];\n\t\telse out[key] = next;\n\t}\n\treturn invalid ? INVALID : out ?? obj;\n}\n',
    "function validateObjectValue(value, s, component, path, ctx) {\n\treturn validateObjectValueMoonbit(value, s, component, path, ctx);\n}\n",
  ],
  [
    'function validateArrayValue(value, s, component, path, ctx) {\n\tif (!Array.isArray(value)) {\n\t\tpushValidationIssue(ctx, component, path, {\n\t\t\tcode: "type-mismatch",\n\t\t\texpected: "array",\n\t\t\tactual: jsType(value)\n\t\t});\n\t\treturn INVALID;\n\t}\n\tconst items = s["items"];\n\tif (!items || typeof items !== "object" || Array.isArray(items)) return value;\n\tlet out;\n\tfor (let i = 0; i < value.length; i++) {\n\t\tconst next = validateSchemaValue(value[i], items, component, `${path}/${i}`, ctx);\n\t\tif (next !== value[i] && !out) out = value.slice(0, i);\n\t\tif (out && next !== INVALID) out.push(next);\n\t}\n\treturn out ?? value;\n}\n',
    "function validateArrayValue(value, s, component, path, ctx) {\n\treturn validateArrayValueMoonbit(value, s, component, path, ctx);\n}\n",
  ],
  [
    'function validateLeafValue(value, s, component, path, ctx) {\n\tconst leaf = getScalarTypeInfo(s);\n\tif (leaf.expectedType == null && leaf.enumValues == null) return false;\n\tif (leaf.enumValues && ctx.partial) return false;\n\tconst mismatch = checkTypeMismatch(value, leaf);\n\tif (mismatch) {\n\t\tpushValidationIssue(ctx, component, path, {\n\t\t\tcode: "type-mismatch",\n\t\t\t...mismatch\n\t\t});\n\t\treturn true;\n\t}\n\treturn false;\n}\n',
    "function validateLeafValue(value, s, component, path, ctx) {\n\treturn validateLeafValueMoonbit(value, s, component, path, ctx);\n}\n",
  ],
  [
    'function validateSchemaValue(value, schema, component, path, ctx) {\n\tif (!schema || typeof schema !== "object" || Array.isArray(schema)) return value;\n\tconst s = schema;\n\tif (value == null) return value;\n\tif (isASTNode(value)) return value;\n\tif (isElementNode(value)) return validateElementPosition(value, s, component, path, ctx) ? INVALID : value;\n\tif (isCompositeSchema(s)) {\n\t\tif (!isOnlyComponentSlot(s, ctx)) return value;\n\t\tpushValidationIssue(ctx, component, path, {\n\t\t\tcode: "type-mismatch",\n\t\t\texpected: slotRefNames(s).join(" | "),\n\t\t\tactual: Array.isArray(value) ? "array" : typeof value === "object" ? "plain object" : typeof value\n\t\t});\n\t\treturn INVALID;\n\t}\n\tconst type = s["type"];\n\tif (type === "object") return validateObjectValue(value, s, component, path, ctx);\n\tif (type === "array") return validateArrayValue(value, s, component, path, ctx);\n\treturn validateLeafValue(value, s, component, path, ctx) ? INVALID : value;\n}\n',
    "function validateSchemaValue(value, schema, component, path, ctx) {\n\treturn validateSchemaValueMoonbit(value, schema, component, path, ctx);\n}\n",
  ],
  [
    "function checkValue(value, schema, name, path, context, strict = false) {\n\tconst ctx = {\n\t\terrors: [],\n\t\tpartial: false\n\t};\n\tconst checked = validateSchemaValue(value, schema, name, path, ctx);\n\tfor (const e of ctx.errors) context.reportError?.(`@${name}: ${e.message}`);\n\treturn strict && ctx.errors.length > 0 ? INVALID : checked;\n}\n",
    "function checkValue(value, schema, name, path, context, strict = false) {\n\treturn checkValueMoonbit(value, schema, name, path, context, strict);\n}\n",
  ],
  [
    "function evaluateArgs(node, context, params = BUILTIN_CALLS.get(node.name)?.params ?? []) {\n\tconst named = node.mappedProps ?? nameArgs(node.args, params);\n\tconst args = {};\n\tfor (const key in named) args[key] = evaluate(named[key], context);\n\treturn args;\n}\n",
    "function evaluateArgs(node, context, params = BUILTIN_CALLS.get(node.name)?.params ?? []) {\n\treturn evaluateArgsMoonbit(node, context, params);\n}\n",
  ],
  [
    "function nameArgs(args, params) {\n\tconst named = {};\n\tfor (let i = 0; i < params.length && i < args.length; i++) named[params[i].name] = args[i];\n\treturn named;\n}\n",
    "function nameArgs(args, params) {\n\treturn nameArgsMoonbit(args, params);\n}\n",
  ],
  [
    'function pushValidationIssue(ctx, component, path, issue) {\n\tctx.errors.push({\n\t\tcode: issue.code,\n\t\tcomponent,\n\t\tpath,\n\t\tmessage: validationMessage(component, path, issue),\n\t\tstatementId: ctx.currentStatementId,\n\t\t...issue.code === "no-root" && issue.reason === "fallback" && { severity: "warning" }\n\t});\n}\n',
    "function pushValidationIssue(ctx, component, path, issue) {\n\treturn pushValidationIssueMoonbit(ctx, component, path, issue);\n}\n",
  ],
  [
    'function refName(s) {\n\treturn typeof s["$ref"] === "string" ? s["$ref"].split("/").pop() : void 0;\n}\n',
    "function refName(s) {\n\treturn refNameMoonbit(s);\n}\n",
  ],
  [
    'function isCompositeSchema(s) {\n\treturn "$ref" in s || "anyOf" in s || "oneOf" in s || "allOf" in s;\n}\n',
    "function isCompositeSchema(s) {\n\treturn isCompositeSchemaMoonbit(s);\n}\n",
  ],
  [
    'function getSchemaDefaultValue(property) {\n\tif (!property || typeof property !== "object" || Array.isArray(property)) return;\n\treturn property.default;\n}\n',
    "function getSchemaDefaultValue(property) {\n\treturn getSchemaDefaultValueMoonbit(property);\n}\n",
  ],
  [
    'function getTypeFromSchema(property) {\n\tif (!property || typeof property !== "object" || Array.isArray(property)) return;\n\tconst p = property;\n\tconst ref = refName(p);\n\tif (ref) return ref;\n\tconst leaf = getScalarTypeInfo(p);\n\tif (leaf.enumValues) return leaf.enumValues.map((v) => JSON.stringify(v)).join("|");\n\tif (leaf.expectedType) return leaf.expectedType;\n\treturn typeof p.type === "string" ? p.type : void 0;\n}\n',
    "function getTypeFromSchema(property) {\n\treturn getTypeFromSchemaMoonbit(property);\n}\n",
  ],
  [
    'function buildParamsSignature(component, params) {\n\treturn `${component}(${params.map((p) => {\n\t\tconst type = getTypeFromSchema(p.schema);\n\t\tconst marked = p.required ? `${p.name}*` : p.name;\n\t\treturn type ? `${marked}: ${type}` : marked;\n\t}).join(", ")})`;\n}\n',
    "function buildParamsSignature(component, params) {\n\treturn buildParamsSignatureMoonbit(component, params);\n}\n",
  ],
  [
    'function slotRefNames(s) {\n\treturn (s["anyOf"] ?? s["oneOf"] ?? [s]).map(refName);\n}\n',
    "function slotRefNames(s) {\n\treturn slotRefNamesMoonbit(s);\n}\n",
  ],
  [
    "function isOnlyComponentSlot(s, ctx) {\n\tconst names = slotRefNames(s);\n\treturn names.length > 0 && names.every((n) => n !== void 0 && ctx.cat?.has(n));\n}\n",
    "function isOnlyComponentSlot(s, ctx) {\n\treturn isOnlyComponentSlotMoonbit(s, ctx);\n}\n",
  ],
  [
    "function evaluatePropInline(value, context, schemaCtx, reactiveSchema) {\n\treturn evaluatePropCore(value, context, schemaCtx, reactiveSchema, {\n\t\trecurseElement: (el) => evaluateElementInline(el, context, schemaCtx),\n\t\trecurse: (v, rs) => evaluatePropInline(v, context, schemaCtx, rs)\n\t});\n}\n",
    "function evaluatePropInline(value, context, schemaCtx, reactiveSchema) {\n\treturn evaluatePropInlineMoonbit(value, context, schemaCtx, reactiveSchema);\n}\n",
  ],
  [
    "function evaluatePropCore(value, context, schemaCtx, reactiveSchema, callbacks) {\n\tconst result = evaluatePropValue$1(value, context, schemaCtx, reactiveSchema, callbacks);\n\treturn isActionPlan(result) ? ownSteps(result) : result;\n}\n",
    "function evaluatePropCore(value, context, schemaCtx, reactiveSchema, callbacks) {\n\treturn evaluatePropCoreMoonbit(value, context, schemaCtx, reactiveSchema, callbacks);\n}\n",
  ],
  [
    "function evaluatePropValue(value, evalCtx, schemaCtx, reactiveSchema) {\n\treturn evaluatePropCore(value, evalCtx.ctx, schemaCtx, reactiveSchema, {\n\t\trecurseElement: (el) => evaluateElementProps(el, evalCtx),\n\t\trecurse: (v, rs) => evaluatePropValue(v, evalCtx, schemaCtx, rs)\n\t});\n}\n",
    "function evaluatePropValue(value, evalCtx, schemaCtx, reactiveSchema) {\n\treturn evaluatePropTreeMoonbit(value, evalCtx, schemaCtx, reactiveSchema);\n}\n",
  ],
  [
    'function evaluateActionCall(node, context) {\n\tconst { name, args } = node;\n\tif (name === "Action") {\n\t\tconst list = args.length > 0 ? evaluate(args[0], context) : [];\n\t\treturn flattenPlans(Array.isArray(list) ? list : []);\n\t}\n\tconst def = BUILTIN_STEPS[name];\n\tconst step = def.step ? def.step(evaluateArgs(node, context)) : evaluateLazyStep(name, args);\n\treturn { steps: step ? [step] : [] };\n}\n',
    "function evaluateActionCall(node, context) {\n\treturn evaluateActionCallMoonbit(node, context);\n}\n",
  ],
  [
    'function evaluateLazyStep(name, args) {\n\tswitch (name) {\n\t\tcase "Run": {\n\t\t\tconst refNode = args[0];\n\t\t\tif (refNode?.k !== "RuntimeRef") return null;\n\t\t\treturn {\n\t\t\t\ttype: ACTION_STEPS.Run,\n\t\t\t\tstatementId: refNode.n,\n\t\t\t\trefType: refNode.refType\n\t\t\t};\n\t\t}\n\t\tcase "Set":\n\t\t\tif (args.length < 2 || args[0].k !== "StateRef") return null;\n\t\t\treturn {\n\t\t\t\ttype: ACTION_STEPS.Set,\n\t\t\t\ttarget: args[0].n,\n\t\t\t\tvalueAST: args[1]\n\t\t\t};\n\t\tcase "Reset": {\n\t\t\tconst targets = args.filter((a) => a.k === "StateRef").map((a) => a.n);\n\t\t\tif (targets.length === 0) return null;\n\t\t\treturn {\n\t\t\t\ttype: ACTION_STEPS.Reset,\n\t\t\t\ttargets\n\t\t\t};\n\t\t}\n\t\tdefault: return null;\n\t}\n}\n',
    "function evaluateLazyStep(name, args) {\n\treturn evaluateLazyStepMoonbit(name, args);\n}\n",
  ],
  [
    "function isBuiltin(name) {\n\treturn BUILTIN_CALLS.has(name);\n}\n",
    "function isBuiltin(name) {\n\treturn isBuiltinMoonbit(name);\n}\n",
  ],
  [
    'function isStep(name, actions) {\n\treturn BUILTIN_CALLS.get(name)?.kind === "action" || !!actions && Object.prototype.hasOwnProperty.call(actions, name);\n}\n',
    "function isStep(name, actions) {\n\treturn isStepMoonbit(name, actions);\n}\n",
  ],
  [
    "function isReservedCall(name) {\n\treturn name in RESERVED_CALLS;\n}\n",
    "function isReservedCall(name) {\n\treturn isReservedCallMoonbit(name);\n}\n",
  ],
  [
    "function getCallDefs(cat) {\n\treturn cat?.callDefs ?? BUILTIN_CALLS;\n}\n",
    "function getCallDefs(cat) {\n\treturn getCallDefsMoonbit(cat);\n}\n",
  ],
  [
    'function tokenize(src) {\n\tconst tokens = [];\n\tlet i = 0;\n\tconst n = src.length;\n\twhile (i < n) {\n\t\twhile (i < n && (src[i] === " " || src[i] === "\t" || src[i] === "\\r")) i++;\n\t\tif (i >= n) break;\n\t\tconst c = src[i];\n\t\tif (c === "\\n") {\n\t\t\ttokens.push({ t: 0 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "(") {\n\t\t\ttokens.push({ t: 1 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === ")") {\n\t\t\ttokens.push({ t: 2 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "[") {\n\t\t\ttokens.push({ t: 3 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "]") {\n\t\t\ttokens.push({ t: 4 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "{") {\n\t\t\ttokens.push({ t: 5 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "}") {\n\t\t\ttokens.push({ t: 6 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === ",") {\n\t\t\ttokens.push({ t: 7 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === ":") {\n\t\t\ttokens.push({ t: 8 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "=") {\n\t\t\tif (i + 1 < n && src[i + 1] === "=") {\n\t\t\t\ttokens.push({ t: 25 });\n\t\t\t\ti += 2;\n\t\t\t} else {\n\t\t\t\ttokens.push({ t: 9 });\n\t\t\t\ti++;\n\t\t\t}\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "!") {\n\t\t\tif (i + 1 < n && src[i + 1] === "=") {\n\t\t\t\ttokens.push({ t: 26 });\n\t\t\t\ti += 2;\n\t\t\t} else {\n\t\t\t\ttokens.push({ t: 33 });\n\t\t\t\ti++;\n\t\t\t}\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === ">") {\n\t\t\tif (i + 1 < n && src[i + 1] === "=") {\n\t\t\t\ttokens.push({ t: 29 });\n\t\t\t\ti += 2;\n\t\t\t} else {\n\t\t\t\ttokens.push({ t: 27 });\n\t\t\t\ti++;\n\t\t\t}\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "<") {\n\t\t\tif (i + 1 < n && src[i + 1] === "=") {\n\t\t\t\ttokens.push({ t: 30 });\n\t\t\t\ti += 2;\n\t\t\t} else {\n\t\t\t\ttokens.push({ t: 28 });\n\t\t\t\ti++;\n\t\t\t}\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "&") {\n\t\t\tif (i + 1 < n && src[i + 1] === "&") {\n\t\t\t\ttokens.push({ t: 31 });\n\t\t\t\ti += 2;\n\t\t\t} else {\n\t\t\t\ttokens.push({ t: 31 });\n\t\t\t\ti++;\n\t\t\t}\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "|") {\n\t\t\tif (i + 1 < n && src[i + 1] === "|") {\n\t\t\t\ttokens.push({ t: 32 });\n\t\t\t\ti += 2;\n\t\t\t} else {\n\t\t\t\ttokens.push({ t: 32 });\n\t\t\t\ti++;\n\t\t\t}\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === ".") {\n\t\t\ttokens.push({ t: 19 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "?") {\n\t\t\ttokens.push({ t: 34 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "+") {\n\t\t\ttokens.push({ t: 20 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "*") {\n\t\t\ttokens.push({ t: 22 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "/") {\n\t\t\ttokens.push({ t: 23 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "%") {\n\t\t\ttokens.push({ t: 24 });\n\t\t\ti++;\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "\\"") {\n\t\t\tconst start = i;\n\t\t\ti++;\n\t\t\tlet isClosed = false;\n\t\t\twhile (i < n) if (src[i] === "\\\\") i += 2;\n\t\t\telse if (src[i] === "\\"") {\n\t\t\t\ti++;\n\t\t\t\tisClosed = true;\n\t\t\t\tbreak;\n\t\t\t} else i++;\n\t\t\tconst rawString = src.slice(start, i);\n\t\t\ttry {\n\t\t\t\tconst validJsonString = isClosed ? rawString : rawString + "\\"";\n\t\t\t\ttokens.push({\n\t\t\t\t\tt: 14,\n\t\t\t\t\tv: JSON.parse(validJsonString)\n\t\t\t\t});\n\t\t\t} catch {\n\t\t\t\tconst stripped = rawString.replace(/^"|"$/g, "");\n\t\t\t\ttokens.push({\n\t\t\t\t\tt: 14,\n\t\t\t\t\tv: stripped\n\t\t\t\t});\n\t\t\t}\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "\'") {\n\t\t\ti++;\n\t\t\tlet result = "";\n\t\t\twhile (i < n) if (src[i] === "\\\\") {\n\t\t\t\ti++;\n\t\t\t\tif (i < n) {\n\t\t\t\t\tconst esc = src[i];\n\t\t\t\t\tif (esc === "\'") result += "\'";\n\t\t\t\t\telse if (esc === "\\\\") result += "\\\\";\n\t\t\t\t\telse if (esc === "n") result += "\\n";\n\t\t\t\t\telse if (esc === "t") result += "\t";\n\t\t\t\t\telse result += esc;\n\t\t\t\t\ti++;\n\t\t\t\t}\n\t\t\t} else if (src[i] === "\'") {\n\t\t\t\ti++;\n\t\t\t\tbreak;\n\t\t\t} else {\n\t\t\t\tresult += src[i];\n\t\t\t\ti++;\n\t\t\t}\n\t\t\ttokens.push({\n\t\t\t\tt: 14,\n\t\t\t\tv: result\n\t\t\t});\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "-") {\n\t\t\tconst prev = tokens.length > 0 ? tokens[tokens.length - 1] : null;\n\t\t\tif (!(prev != null && (prev.t === 15 || prev.t === 14 || prev.t === 16 || prev.t === 17 || prev.t === 2 || prev.t === 4 || prev.t === 10 || prev.t === 11 || prev.t === 12 || prev.t === 18 || prev.t === 35)) && i + 1 < n && src[i + 1] >= "0" && src[i + 1] <= "9") {} else {\n\t\t\t\ttokens.push({ t: 21 });\n\t\t\t\ti++;\n\t\t\t\tcontinue;\n\t\t\t}\n\t\t}\n\t\tconst isDigit = c >= "0" && c <= "9";\n\t\tconst isNegDigit = c === "-" && i + 1 < n && src[i + 1] >= "0" && src[i + 1] <= "9";\n\t\tif (isDigit || isNegDigit) {\n\t\t\tconst start = i;\n\t\t\tif (src[i] === "-") i++;\n\t\t\twhile (i < n && src[i] >= "0" && src[i] <= "9") i++;\n\t\t\tif (i < n && src[i] === "." && i + 1 < n && src[i + 1] >= "0" && src[i + 1] <= "9") {\n\t\t\t\ti++;\n\t\t\t\twhile (i < n && src[i] >= "0" && src[i] <= "9") i++;\n\t\t\t}\n\t\t\tif (i < n && (src[i] === "e" || src[i] === "E")) {\n\t\t\t\ti++;\n\t\t\t\tif (i < n && (src[i] === "+" || src[i] === "-")) i++;\n\t\t\t\twhile (i < n && src[i] >= "0" && src[i] <= "9") i++;\n\t\t\t}\n\t\t\ttokens.push({\n\t\t\t\tt: 15,\n\t\t\t\tv: +src.slice(start, i)\n\t\t\t});\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "$" && i + 1 < n && (src[i + 1] >= "a" && src[i + 1] <= "z" || src[i + 1] >= "A" && src[i + 1] <= "Z" || src[i + 1] === "_")) {\n\t\t\tconst start = i;\n\t\t\ti++;\n\t\t\twhile (i < n && (src[i] >= "a" && src[i] <= "z" || src[i] >= "A" && src[i] <= "Z" || src[i] >= "0" && src[i] <= "9" || src[i] === "_")) i++;\n\t\t\ttokens.push({\n\t\t\t\tt: 18,\n\t\t\t\tv: src.slice(start, i)\n\t\t\t});\n\t\t\tcontinue;\n\t\t}\n\t\tif (c >= "a" && c <= "z" || c >= "A" && c <= "Z" || c === "_") {\n\t\t\tconst start = i;\n\t\t\twhile (i < n && (src[i] >= "a" && src[i] <= "z" || src[i] >= "A" && src[i] <= "Z" || src[i] >= "0" && src[i] <= "9" || src[i] === "_")) i++;\n\t\t\tconst word = src.slice(start, i);\n\t\t\tif (word === "true") {\n\t\t\t\ttokens.push({ t: 10 });\n\t\t\t\tcontinue;\n\t\t\t}\n\t\t\tif (word === "false") {\n\t\t\t\ttokens.push({ t: 11 });\n\t\t\t\tcontinue;\n\t\t\t}\n\t\t\tif (word === "null") {\n\t\t\t\ttokens.push({ t: 12 });\n\t\t\t\tcontinue;\n\t\t\t}\n\t\t\tconst kind = c >= "A" && c <= "Z" ? 17 : 16;\n\t\t\ttokens.push({\n\t\t\t\tt: kind,\n\t\t\t\tv: word\n\t\t\t});\n\t\t\tcontinue;\n\t\t}\n\t\tif (c === "@" && i + 1 < n && (src[i + 1] >= "a" && src[i + 1] <= "z" || src[i + 1] >= "A" && src[i + 1] <= "Z" || src[i + 1] === "_")) {\n\t\t\ti++;\n\t\t\tconst start = i;\n\t\t\twhile (i < n && (src[i] >= "a" && src[i] <= "z" || src[i] >= "A" && src[i] <= "Z" || src[i] >= "0" && src[i] <= "9" || src[i] === "_")) i++;\n\t\t\ttokens.push({\n\t\t\t\tt: 35,\n\t\t\t\tv: src.slice(start, i)\n\t\t\t});\n\t\t\tcontinue;\n\t\t}\n\t\ti++;\n\t}\n\ttokens.push({ t: 13 });\n\treturn tokens;\n}\n',
    "function tokenize(src) {\n\treturn tokenizeMoonbit(src);\n}\n",
  ],
  [
    "function preprocess(input) {\n\treturn stripComments(stripFences(input.trim())).trim();\n}",
    "function preprocess(input) {\n\treturn preprocessMoonbit(input);\n}",
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
function mergeMoonbitStatements(existing, patch, rootId) {
  return __ouiMergeStatements(existing, patch, rootId);
}
function jsonToOpenUIMoonbit(json, library, options) {
  return __ouiJsonToOpenUI(json, library, options);
}
function evaluateMoonbitPure(node, context, schemaCtx) {
  return __ouiEvaluatePure(node, context, schemaCtx, (child) => evaluate(child, context, schemaCtx));
}
function walkASTMoonbit(node, visit) {
  return __ouiWalkAST(node, visit);
}
function isASTNodeMoonbit(value) {
  return __ouiIsASTNode(value);
}
function toLiteralASTMoonbit(value) {
  return __ouiToLiteralAST(value);
}
function literalValueMoonbit(node) {
  return __ouiLiteralValue(node);
}
function generatePromptMoonbit(spec) {
  return __ouiGeneratePrompt(spec);
}
function generateCloudConfigMoonbit(spec) {
  return __ouiCloudConfig(spec);
}
function callBuiltinMoonbit(name, args) {
  return __ouiCallBuiltin(name, args);
}
function eagerStepMoonbit(node, context) {
  return __ouiEagerStep(node.name, evaluateArgs(node, context));
}
function lazyStepMoonbit(node) {
  const args = node.args ?? [];
  const decision = __ouiLazyStep(
    node.name,
    args.map((arg) => (arg && typeof arg.k === "string" ? arg.k : "")),
  );
  if (decision.op === "run") {
    const refNode = args[0];
    return { steps: [{ type: "run", statementId: refNode.n, refType: refNode.refType }] };
  }
  if (decision.op === "set") {
    return { steps: [{ type: "set", target: args[0].n, valueAST: args[1] }] };
  }
  if (decision.op === "reset") {
    return { steps: [{ type: "reset", targets: decision.at.map((index) => args[index].n) }] };
  }
  return { steps: [] };
}
function substituteRefMoonbit(node, varName, value) {
  return __ouiSubstituteRef(node, varName, value);
}
function generateSystemPromptMoonbit(spec) {
  const kind = systemPromptKindMoonbit(spec);
  if (kind === "cloud") return generateCloudConfig(spec);
  if (kind === "legacy") {
    const prompt = generatePrompt(spec);
    recordSystemPromptGeneration(spec, "legacy_prompt_spec");
    return prompt;
  }
  const merged = {
    ...spec.library,
    ...spec.promptOptions,
  };
  const prompt = generatePrompt(merged);
  recordSystemPromptGeneration(merged, "library_spec");
  return prompt;
}
function systemPromptKindMoonbit(spec) {
  return __ouiSystemPromptKind(spec);
}
function isElementNodeMoonbit(value) {
  return __ouiIsElementNode(value);
}
function isReactiveAssignMoonbit(value) {
  return __ouiIsReactiveAssign(value);
}
function isRuntimeExprMoonbit(node) {
  return __ouiIsRuntimeExpr(node);
}
function isActionPlanMoonbit(value) {
  return __ouiIsActionPlan(value);
}
function flattenPlansMoonbit(values) {
  return ownSteps(__ouiFlattenPlans(values));
}
function toolContentItems(content) {
  const items = [];
  for (let i = 0; i < content.length; i++) {
    if (!(i in content)) {
      items.push("h");
      continue;
    }
    if (content[i] == null) {
      items.push("bad");
      break;
    }
    items.push(content[i].type === "text" ? "text" : "skip");
  }
  return items;
}
function extractToolResultMoonbit(result) {
  if (result.isError) {
    const content = result.content;
    if (content != null && !Array.isArray(content)) {
      const errorText = result.content?.filter((c) => c.type === "text").map((c) => c.text).join("\\n");
      throw new McpToolError(errorText || "Unknown error");
    }
    const decision = __ouiExtractToolResult({
      error: true,
      structured: false,
      content: content == null ? "missing" : "array",
      items: content == null ? [] : toolContentItems(content)
    });
    if (decision.op === "throw") void content[decision.i].type;
    const errorText = decision.at.map((i) => content[i].text).join("\\n");
    throw new McpToolError(errorText || "Unknown error");
  }
  if (result.structuredContent != null) return result.structuredContent;
  const content = result.content;
  if (content != null && !Array.isArray(content)) {
    const textParts = result.content?.filter((c) => c.type === "text").map((c) => c.text ?? "");
    if (textParts?.length) {
      const text = textParts.join("");
      try {
        return JSON.parse(text);
      } catch {
        return text;
      }
    }
    return null;
  }
  const decision = __ouiExtractToolResult({
    error: false,
    structured: false,
    content: content == null ? "missing" : "array",
    items: content == null ? [] : toolContentItems(content)
  });
  if (decision.op === "throw") void content[decision.i].type;
  if (decision.op === "parse") {
    const text = decision.at.map((i) => content[i].text ?? "").join("");
    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  }
  return null;
}
function stableStringifyMoonbit(value) {
  return __ouiStableStringify(value);
}
function buildCacheKeyMoonbit(toolName, args, deps) {
  return __ouiBuildCacheKey(toolName, args, deps);
}
function resolveFieldMoonbit(obj, path) {
  return __ouiResolveField(obj, path);
}
function toNumberMoonbit(val) {
  return __ouiToNumber(val);
}
function evaluateRootMoonbit(result, evalCtx) {
  const step = __ouiEvaluateRoot(result.root ? "root" : result.rootExpression ? "expr" : "none");
  if (step.op === "props") return evaluateElementProps(result.root, evalCtx);
  if (step.op !== "eval") return null;
  const value = evaluate(result.rootExpression, evalCtx.ctx, { library: evalCtx.library });
  const after = __ouiEvaluateRoot(isElementNode(value) ? "element" : "miss");
  if (after.op === "props") return evaluateElementProps(value, evalCtx);
  evalCtx.errors?.push(after.error);
  return null;
}
function eachLength(args) {
  const length = args.length;
  if (typeof length === "number" && Number.isFinite(length)) return { n: length };
  if (length === -Infinity) return { n: -1 };
  if (length < 3) return { n: 0 };
  return { wide: true };
}
function evaluateLazyBuiltinMoonbit(name, args, context, schemaCtx) {
  const openPayload = {
    phase: "open",
    name: typeof name === "string" ? name : "",
  };
  if (name === "Each") Object.assign(openPayload, eachLength(args));
  const open = __ouiEach(openPayload);
  if (open.op === "empty") return [];
  if (open.op !== "eval") return null;
  const arr = evaluate(args[0], context);
  const listed = __ouiEach({ phase: "array", array: Array.isArray(arr) });
  if (listed.op !== "bind") return [];
  let slot = "";
  let named = null;
  if (args[1].k === "Ref") {
    slot = "Ref";
    named = args[1].n;
  } else if (args[1].k === "Str") {
    slot = "Str";
    named = args[1].v;
  }
  const picked = __ouiEach({ phase: "name", k: slot, ok: Boolean(named) });
  if (picked.op !== "map") return [];
  const varName = named;
  const template = args[2];
  return arr.map((item, _idx) => {
    const substituted = substituteRef(template, varName, item);
    const childCtx = {
      ...context,
      resolveRef: (refName) => {
        if (refName === varName) return item;
        return context.resolveRef(refName);
      },
    };
    const result = evaluate(substituted, childCtx, schemaCtx);
    if (schemaCtx && isElementNode(result)) return evaluateElementInline(result, childCtx, schemaCtx);
    return result;
  });
}
function evaluatePropValueMoonbit(value, context, schemaCtx, reactiveSchema, callbacks) {
  if (value == null || typeof value !== "object") return value;
  if (Array.isArray(value)) {
    const step = __ouiPropStep({ phase: "start", kind: "array" });
    if (step.op === "arr") return value.map((item) => callbacks.recurse(item, reactiveSchema));
    return value;
  }
  const seen = value.k;
  const probe = __ouiPropStep({ phase: "kind", k: typeof seen === "string" ? seen : "" });
  if (probe.op === "ast") {
    const again = value.k;
    const stateRef = again === "StateRef";
    const reactive = stateRef && Boolean(reactiveSchema && isReactiveSchema(reactiveSchema));
    const step = __ouiPropStep({
      phase: "start",
      kind: "ast",
      k: stateRef ? "StateRef" : typeof again === "string" ? again : "",
      reactive,
    });
    if (step.op === "assign") return {
      __reactive: "assign",
      target: value.n,
      expr: { k: "StateRef", n: "$value" },
    };
    const result = evaluate(value, context, schemaCtx);
    if (isElementNode(result)) {
      const after = __ouiPropStep({ phase: "eval", element: true });
      if (after.op === "el") return callbacks.recurseElement(result);
      return result;
    }
    if (Array.isArray(result)) {
      const after = __ouiPropStep({ phase: "eval", array: true });
      if (after.op === "items") return result.map((item) => isElementNode(item) ? callbacks.recurseElement(item) : item);
      return result;
    }
    if (isReactiveAssign(result)) {
      const live = Boolean(reactiveSchema && isReactiveSchema(reactiveSchema));
      const after = __ouiPropStep({ phase: "eval", assign: true, reactive: live });
      if (after.op === "state") return context.getState(result.target) ?? null;
      return result;
    }
    __ouiPropStep({ phase: "eval" });
    return result;
  }
  if (isElementNode(value)) {
    const step = __ouiPropStep({ phase: "start", kind: "el" });
    if (step.op === "el") return callbacks.recurseElement(value);
    return value;
  }
  if (isActionPlan(value)) {
    __ouiPropStep({ phase: "start", kind: "plan" });
    return value;
  }
  let needs = false;
  for (const val of Object.values(value)) if (typeof val === "object" && val !== null) {
    needs = true;
    break;
  }
  const scanned = __ouiPropStep({ phase: "scan", needs });
  if (scanned.op !== "obj") return value;
  const result = {};
  for (const [key, item] of Object.entries(value)) result[key] = callbacks.recurse(item, reactiveSchema);
  return result;
}
function evaluateElementPropsMoonbit(el, evalCtx) {
  const frozen = el.hasDynamicProps === false;
  if (__ouiInlineStep({ frozen }).op === "keep") return el;
  const schemaCtx = { library: evalCtx.library };
  const def = evalCtx.library.components[el.typeName];
  const evaluated = {};
  let key = "";
  const report = (msg) => {
    const component = el.typeName;
    const statementId = el.statementId;
    const error = __ouiPropError({ key, typeName: String(el.typeName), message: String(msg) });
    error.component = component;
    error.statementId = statementId;
    evalCtx.errors?.push(error);
  };
  const propCtx = evalCtx.ctx.functions || evalCtx.ctx.actions ? {
    ...evalCtx,
    ctx: { ...evalCtx.ctx, reportError: report },
  } : evalCtx;
  for (const [propKey, value] of Object.entries(el.props)) {
    key = propKey;
    const propSchema = def?.props?.shape?.[key];
    try {
      evaluated[key] = evaluatePropValue(value, propCtx, schemaCtx, propSchema);
    } catch (e) {
      evaluated[key] = value;
      report(e instanceof Error ? e.message : String(e));
    }
  }
  return { ...el, props: evaluated };
}
function storePlain(existing, value) {
  return Boolean(
    value &&
      existing &&
      typeof value === "object" &&
      typeof existing === "object" &&
      !Array.isArray(value) &&
      !Array.isArray(existing),
  );
}
function storeEqualKeys(existing, value) {
  const nextKeys = Object.keys(value);
  const prevKeys = Object.keys(existing);
  const eq = [];
  if (nextKeys.length === prevKeys.length) {
    for (const key of nextKeys) {
      const same = Object.is(value[key], existing[key]);
      eq.push(same);
      if (!same) break;
    }
  }
  return __ouiStoreKeep({
    same: false,
    plain: true,
    n: nextKeys.length,
    o: prevKeys.length,
    eq,
  });
}
function createStoreMoonbit() {
  const state = new Map();
  const pristine = new Set();
  const listeners = new Set();
  let snapshot = {};
  function notify() {
    const currentListeners = [...listeners];
    for (const listener of currentListeners) listener();
  }
  function rebuildSnapshot() {
    snapshot = Object.fromEntries(state);
  }
  function get(name) {
    return state.get(name);
  }
  function set(name, value, options) {
    if (options?.pristine) pristine.add(name);
    else pristine.delete(name);
    const existing = state.get(name);
    if (Object.is(existing, value)) {
      if (__ouiStoreKeep({ same: true }).op === "keep") return;
    } else if (storePlain(existing, value)) {
      if (storeEqualKeys(existing, value).op === "keep") return;
    } else if (__ouiStoreKeep({ same: false, plain: false }).op === "keep") return;
    state.set(name, value);
    rebuildSnapshot();
    notify();
  }
  function subscribe(listener) {
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
    };
  }
  function getSnapshot() {
    return snapshot;
  }
  function initialize(defaults, persisted) {
    let changed = false;
    for (const key of Object.keys(persisted)) {
      pristine.delete(key);
      const has = state.has(key);
      const same = has ? Object.is(state.get(key), persisted[key]) : false;
      if (__ouiStoreInit({ phase: "persisted", has, same }).op === "write") {
        state.set(key, persisted[key]);
        changed = true;
      }
    }
    for (const key of Object.keys(defaults)) {
      const has = state.has(key);
      if (!has) {
        if (__ouiStoreInit({ phase: "defaults", has: false }).op === "insert") {
          state.set(key, defaults[key]);
          pristine.add(key);
          changed = true;
        }
        continue;
      }
      const clean = pristine.has(key);
      if (!clean) {
        __ouiStoreInit({ phase: "defaults", has: true, pristine: false });
        continue;
      }
      const same = Object.is(state.get(key), defaults[key]);
      if (__ouiStoreInit({ phase: "defaults", has: true, pristine: true, same }).op === "replace") {
        state.set(key, defaults[key]);
        changed = true;
      }
    }
    if (changed) {
      rebuildSnapshot();
      notify();
    }
  }
  function dispose() {
    state.clear();
    pristine.clear();
    listeners.clear();
    snapshot = {};
  }
  return {
    get,
    set,
    subscribe,
    getSnapshot,
    initialize,
    dispose,
  };
}
function createQueryManagerMoonbit(toolProvider) {
  return __ouiCreateQueryManager(toolProvider, { ToolNotFoundError, McpToolError });
}
function stripReactiveAssignMoonbit(value, context) {
  const assign = typeof value === "object" && value !== null && value.__reactive === "assign";
  const step = __ouiStripAssign({ assign });
  if (step.op !== "state") return value;
  return context.getState(value.target) ?? null;
}
function resolveStateFieldMoonbit(name, bindingValue, store, evaluationContext, fieldGetter, fieldSetter) {
  const assign = typeof bindingValue === "object" && bindingValue !== null && bindingValue.__reactive === "assign";
  const hasStore = Boolean(assign && store);
  const hasContext = Boolean(hasStore && evaluationContext);
  const step = __ouiStateField({ assign, store: hasStore, context: hasContext });
  if (step.op === "reactive") {
    const { target, expr } = bindingValue;
    return {
      name,
      value: store.get(target),
      setValue: (value) => {
        const extraScope = { $value: value };
        const nextValue = evaluate(expr, {
          ...evaluationContext,
          extraScope,
        });
        store.set(target, nextValue);
      },
      isReactive: true,
    };
  }
  return {
    name,
    value: fieldGetter(name) ?? bindingValue,
    setValue: (value) => fieldSetter(name, value),
    isReactive: false,
  };
}
function callArgsMoonbit(node, context, params) {
  const args = evaluateArgs(node, context, Object.keys(params.properties ?? {}).map((name) => ({
    name,
    required: false,
  })));
  for (const key in args) {
    const nil = args[key] === null;
    let list = false;
    let hit = false;
    if (nil) {
      const listed = params.required;
      list = listed != null;
      hit = list && listed.includes(key);
    }
    const step = __ouiCallArg({ phase: "drop", nil, list, hit });
    if (step.op === "drop") delete args[key];
  }
  return args;
}
function missesRequiredMoonbit(args, params) {
  const required = params.required;
  if (required == null) return __ouiCallArg({ phase: "miss", absent: false, bare: false }).op === "miss";
  return !!required.some((key) => {
    const absent = args[key] == null;
    let bare = false;
    if (absent) {
      const properties = params.properties;
      const property = properties == null ? void 0 : properties[key];
      bare = getSchemaDefaultValue(property) === void 0;
    }
    return __ouiCallArg({ phase: "miss", absent, bare }).op === "miss";
  });
}
function sortArrayMoonbit(array, field, direction) {
  const opened = __ouiListStep({ phase: "open", kind: "sort", array: Array.isArray(array) });
  if (opened.op !== "sort") return array;
  const f = String(field ?? "");
  const desc = String(direction ?? "asc") === "desc";
  return [...array].sort((a, b) => {
    const av = f ? resolveField(a, f) : a;
    const bv = f ? resolveField(b, f) : b;
    const aIsNumeric = typeof av === "number" || typeof av === "string" && !isNaN(Number(av)) && av !== "";
    const bIsNumeric = typeof bv === "number" || typeof bv === "string" && !isNaN(Number(bv)) && bv !== "";
    const step = __ouiListStep({ phase: "pair", numeric: aIsNumeric && bIsNumeric, desc });
    if (step.op === "num") return (toNumber(av) - toNumber(bv)) * step.sign;
    return String(av ?? "").localeCompare(String(bv ?? "")) * step.sign;
  });
}
function filterArrayMoonbit(array, field, operator, value) {
  const opened = __ouiListStep({ phase: "open", kind: "filter", array: Array.isArray(array) });
  if (opened.op !== "filter") return [];
  const f = String(field ?? "");
  const o = String(operator ?? "==");
  return array.filter((item) => {
    const v = f ? resolveField(item, f) : item;
    const step = __ouiListStep({ phase: "cmp", op: o });
    if (step.op === "eq") return v == value;
    if (step.op === "ne") return v != value;
    if (step.op === "gt") return toNumber(v) > toNumber(value);
    if (step.op === "lt") return toNumber(v) < toNumber(value);
    if (step.op === "ge") return toNumber(v) >= toNumber(value);
    if (step.op === "le") return toNumber(v) <= toNumber(value);
    if (step.op === "has") return String(v ?? "").includes(String(value ?? ""));
    return false;
  });
}
function evaluateElementInlineMoonbit(el, context, schemaCtx) {
  const frozen = el.hasDynamicProps === false;
  if (__ouiInlineStep({ frozen }).op === "keep") return el;
  const def = schemaCtx.library.components[el.typeName];
  const evaluated = {};
  for (const [key, value] of Object.entries(el.props)) {
    const propSchema = def?.props?.shape?.[key];
    evaluated[key] = evaluatePropInline(value, context, schemaCtx, propSchema);
  }
  return { ...el, props: evaluated };
}
function checkText(step, bound) {
  if (step.op !== "fail") return void 0;
  if (step.code === "min") return "Must be at least " + bound;
  if (step.code === "max") return "Must be no more than " + bound;
  if (step.code === "minLength") return "Must be at least " + bound + " characters";
  if (step.code === "maxLength") return "Must be no more than " + bound + " characters";
  return step.text;
}
function isEmptyMoonbit(value) {
  const nil = value === null || value === void 0 || value === "";
  const array = Array.isArray(value);
  const blank = __ouiCheck({ phase: "blank", nil, empty: array && value.length === 0 });
  if (blank.op === "empty") return true;
  const object = Boolean(value) && typeof value === "object" && !Array.isArray(value);
  const has = object && "value" in value;
  if (has && __ouiCheck({ phase: "wrap", has: true }).op === "dive") return isEmptyMoonbit(value.value);
  if (!object) return __ouiCheck({ phase: "done" }).op === "empty";
  return __ouiCheck({ phase: "keys", n: Object.keys(value).length }).op === "empty";
}
function requiredMoonbit(value) {
  if (isEmptyMoonbit(value)) return checkText(__ouiCheck({ phase: "msg", code: "required" }));
  if (typeof value === "object" && !Array.isArray(value) && value !== null) {
    const vals = Object.values(value);
    const options = vals.length > 0 && vals.every((v) => typeof v === "boolean") && !vals.some(Boolean);
    if (options) return checkText(__ouiCheck({ phase: "msg", code: "options" }));
  }
}
function emailMoonbit(value) {
  if (isEmptyMoonbit(value)) return void 0;
  if (typeof value !== "string") return checkText(__ouiCheck({ phase: "msg", code: "email" }));
  return /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(value) ? void 0 : checkText(__ouiCheck({ phase: "msg", code: "email" }));
}
function urlMoonbit(value) {
  if (isEmptyMoonbit(value)) return void 0;
  if (typeof value !== "string") return checkText(__ouiCheck({ phase: "msg", code: "url" }));
  try {
    new URL(value);
    return;
  } catch {
    return checkText(__ouiCheck({ phase: "msg", code: "url" }));
  }
}
function numericMoonbit(value) {
  if (isEmptyMoonbit(value)) return void 0;
  if (typeof value === "number" && !isNaN(value)) return void 0;
  if (typeof value === "string" && !isNaN(parseFloat(value)) && value.trim() !== "") return void 0;
  return checkText(__ouiCheck({ phase: "msg", code: "numeric" }));
}
function minMoonbit(value, arg) {
  if (isEmptyMoonbit(value)) return void 0;
  const n = typeof value === "number" ? value : parseFloat(String(value));
  if (isNaN(n)) return void 0;
  const min = Number(arg);
  return checkText(__ouiCheck({ phase: "bound", kind: "min", ok: n >= min }), min);
}
function maxMoonbit(value, arg) {
  if (isEmptyMoonbit(value)) return void 0;
  const n = typeof value === "number" ? value : parseFloat(String(value));
  if (isNaN(n)) return void 0;
  const max = Number(arg);
  return checkText(__ouiCheck({ phase: "bound", kind: "max", ok: n <= max }), max);
}
function minLengthMoonbit(value, arg) {
  if (isEmptyMoonbit(value)) return void 0;
  if (typeof value !== "string") return void 0;
  const min = Number(arg);
  return checkText(__ouiCheck({ phase: "bound", kind: "minLength", ok: value.length >= min }), min);
}
function maxLengthMoonbit(value, arg) {
  if (isEmptyMoonbit(value)) return void 0;
  if (typeof value !== "string") return void 0;
  const max = Number(arg);
  return checkText(__ouiCheck({ phase: "bound", kind: "maxLength", ok: value.length <= max }), max);
}
function patternMoonbit(value, arg) {
  if (isEmptyMoonbit(value)) return void 0;
  if (typeof value !== "string" || typeof arg !== "string") return void 0;
  try {
    if (new RegExp(arg).test(value)) return void 0;
    return checkText(__ouiCheck({ phase: "msg", code: "format" }));
  } catch {
    return;
  }
}
function validateMoonbit(value, rules, customValidators) {
  for (const rule of rules) {
    const validator = customValidators?.[rule.type] ?? builtInValidators[rule.type];
    const known = Boolean(validator);
    const error = known ? validator(value, rule.arg) : void 0;
    const step = __ouiCheck({ phase: "rule", known, hit: Boolean(error) });
    if (step.op === "warn") console.warn('[openui] Unknown validation rule type: "' + rule.type + '"');
    if (step.op === "stop") return error;
  }
}
function callFunctionMoonbit(name, def, node, context) {
  const raw = callArgs(node, context, def.params);
  if (__ouiUserCall({ phase: "args", miss: missesRequired(raw, def.params) }).op === "null") return null;
  const args = checkValue(raw, def.params, name, "", context);
  if (__ouiUserCall({ phase: "checked", bad: args === INVALID }).op === "null") return null;
  let result;
  try {
    result = def.fn(args);
  } catch (e) {
    if (__ouiUserCall({ phase: "threw" }).op === "null") {
      context.reportError?.("@" + name + " threw: " + (e instanceof Error ? e.message : String(e)));
      return null;
    }
  }
  if (__ouiUserCall({ phase: "result", returns: Boolean(def.returns) }).op === "value") return result;
  const checked = checkValue(result, def.returns, name, "/returns", context);
  if (__ouiUserCall({ phase: "returns", bad: checked === INVALID, nil: checked == null }).op === "null") return null;
  return checked;
}
function customActionMoonbit(node, context) {
  const acts = context.actions;
  const named = Boolean(acts) && Object.prototype.hasOwnProperty.call(acts, node.name);
  if (__ouiCustom({ phase: "open", named }).op !== "act") return null;
  const def = acts[node.name];
  const args = callArgs(node, context, def.params);
  if (__ouiCustom({ phase: "args", miss: missesRequired(args, def.params) }).op === "empty") return { steps: [] };
  const params = checkValue(args, def.params, node.name, "", context, true);
  if (__ouiCustom({ phase: "checked", bad: params === INVALID }).op !== "build") return { steps: [] };
  const step = {
    type: "custom_action",
    name: node.name,
    params
  };
  customSteps.add(step);
  return { steps: [step] };
}
function mappedCompMoonbit(node, context, schemaCtx) {
  if (__ouiMapped({ phase: "open", mapped: Boolean(node.mappedProps) }).op === "warn") {
    console.warn("[openui] Unexpected unmapped Comp node: " + node.name);
    return null;
  }
  const def = schemaCtx?.library.components[node.name];
  const props = {};
  for (const [key, val] of Object.entries(node.mappedProps)) {
    const propSchema = def?.props?.shape?.[key];
    const state = val.k === "StateRef";
    const reactive = state && propSchema && isReactiveSchema(propSchema);
    if (__ouiMapped({ phase: "prop", state, reactive: Boolean(reactive) }).op === "assign") {
      props[key] = {
        __reactive: "assign",
        target: val.n,
        expr: { k: "StateRef", n: "$value" }
      };
    } else if (val.k === "StateRef") props[key] = schemaCtx ? context.getState(val.n) : val;
    else props[key] = evaluate(val, context, schemaCtx);
  }
  const result = {
    type: "element",
    typeName: node.name,
    props,
    partial: false,
    hasDynamicProps: true
  };
  if (__ouiMapped({ phase: "finish", schema: Boolean(schemaCtx) }).op === "walk") {
    for (const [key, val] of Object.entries(props)) {
      const element = isElementNode(val);
      const array = !element && Array.isArray(val);
      const child = __ouiMapped({ phase: "child", element, array });
      if (child.op === "inline") props[key] = evaluateElementInline(val, context, schemaCtx);
      else if (child.op === "list") props[key] = val.map((item) => isElementNode(item) ? evaluateElementInline(item, context, schemaCtx) : item);
    }
  }
  return result;
}
function jsTypeMoonbit(value) {
  if (__ouiLeaf({ phase: "js", array: Array.isArray(value) }).op === "array") return "array";
  return typeof value;
}
function getScalarTypeInfoMoonbit(s) {
  if (Array.isArray(s["enum"]) && __ouiLeaf({ phase: "scalar", kind: "enum" }).op === "enum") {
    return { enumValues: s["enum"] };
  }
  if ("const" in s && __ouiLeaf({ phase: "scalar", kind: "const" }).op === "const") {
    return { enumValues: [s["const"]] };
  }
  const raw = s["type"];
  const kind = typeof raw === "string" ? raw : "";
  const step = __ouiLeaf({ phase: "scalar", kind });
  if (step.op === "string") return { expectedType: "string" };
  if (step.op === "number") return { expectedType: "number" };
  if (step.op === "boolean") return { expectedType: "boolean" };
  return {};
}
function checkTypeMismatchMoonbit(value, info) {
  const actual = typeof value;
  if (info.enumValues) {
    const scalar = SCALAR_TYPEOFS.includes(actual);
    const hit = scalar && info.enumValues.includes(value);
    if (__ouiLeaf({ phase: "enum", scalar, hit }).op === "fail") {
      return {
        expected: "one of [" + info.enumValues.map((v) => JSON.stringify(v)).join(", ") + "]",
        actual: JSON.stringify(value),
      };
    }
    return null;
  }
  const typed = Boolean(info.expectedType);
  const match = typed && info.expectedType === actual;
  if (__ouiLeaf({ phase: "type", typed, match }).op === "fail") {
    return { expected: info.expectedType, actual: jsType(value) };
  }
  return null;
}
function validationMessageMoonbit(component, path, issue) {
  const code = issue.code;
  const open = __ouiMsg({ phase: "open", code: typeof code === "string" ? code : "" });
  if (open.op === "type") {
    return 'field "' + path + '" expects ' + issue.expected + " but got " + issue.actual;
  }
  if (open.op === "missing" || open.op === "null") {
    const head =
      open.op === "missing"
        ? 'missing required field "' + path + '"'
        : 'required field "' + path + '" cannot be null';
    const marked = Boolean(issue.signature);
    if (__ouiMsg({ phase: "sign", marked }).op === "with") {
      return head + " — signature: " + issue.signature;
    }
    return head;
  }
  if (open.op === "component") {
    const head = 'Unknown component "' + component + '" — not found in catalog or builtins';
    const show = Boolean(issue.available?.length);
    if (__ouiMsg({ phase: "list", show }).op === "join") {
      return head + ". Available components: " + issue.available.join(", ");
    }
    return head;
  }
  if (open.op === "inline") {
    return component + "() must be declared as a top-level statement, not used inline as a value";
  }
  if (open.op === "excess") {
    return (
      component +
      " takes " +
      issue.declared +
      " arg(s), got " +
      issue.got +
      " (" +
      (issue.got - issue.declared) +
      " excess dropped)"
    );
  }
  if (open.op === "function") {
    return (
      'Unknown function "@' +
      component +
      '": not a built-in or action step. The call evaluates to null'
    );
  }
  if (open.op === "root") {
    const first = issue.reason === "not-component";
    const fallback = !first && issue.reason === "fallback";
    const kind = first ? "not-component" : fallback ? "fallback" : "";
    const root = __ouiMsg({ phase: "root", kind, named: Boolean(component) });
    if (root.op === "not-component") return "root does not evaluate to a component";
    if (root.op === "fallback") {
      return "No root statement. Rendering the first statement that calls the root component " + component;
    }
    if (root.op === "named") {
      return "No root statement, and no statement calls the root component " + component;
    }
    return "No root statement";
  }
  return undefined;
}
function resolveInvalidValueMoonbit(required, defaultValue) {
  const defined = defaultValue !== void 0;
  const step = __ouiShape({ phase: "repair", defined, required: !defined && Boolean(required) });
  if (step.op === "keep") return defaultValue;
  if (step.op === "invalid") return INVALID;
  return undefined;
}
function validateElementPositionMoonbit(element, s, component, path, ctx) {
  if (__ouiShape({ phase: "place", composite: isCompositeSchema(s) }).op === "skip") return false;
  const shaped = typeof s["type"] === "string" || Array.isArray(s["enum"]) || "const" in s;
  if (__ouiShape({ phase: "shaped", shaped }).op === "bad") {
    pushValidationIssue(ctx, component, path, {
      code: "type-mismatch",
      expected: typeof s["type"] === "string" ? s["type"] : "a literal value",
      actual: 'component "' + element.typeName + '"'
    });
    return true;
  }
  return false;
}
function validateObjectValueMoonbit(value, s, component, path, ctx) {
  if (__ouiShape({ phase: "box", bad: typeof value !== "object" || Array.isArray(value) }).op === "mismatch") {
    pushValidationIssue(ctx, component, path, {
      code: "type-mismatch",
      expected: "object",
      actual: jsType(value)
    });
    return INVALID;
  }
  const obj = value;
  let out;
  const first = s["properties"];
  const propsPresent = Boolean(first);
  const propsObject = propsPresent && typeof s["properties"] === "object";
  const props = __ouiShape({ phase: "props", present: propsPresent, object: propsObject }).op === "use" ? s["properties"] : NO_PROPS;
  const listed = Array.isArray(s["required"]);
  const required = __ouiShape({ phase: "req", list: listed }).op === "use" ? s["required"] : NO_REQUIRED;
  let invalid = false;
  if (__ouiShape({ phase: "need", partial: Boolean(ctx.partial) }).op === "scan") {
    for (const key of required) {
      const present = key in obj;
      const nil = present && obj[key] == null;
      if (__ouiShape({ phase: "hole", present, nil }).op !== "fill") continue;
      const fallback = getSchemaDefaultValue(props[key]);
      if (__ouiShape({ phase: "fill", defined: fallback !== void 0 }).op === "default") {
        (out ??= { ...obj })[key] = fallback;
        continue;
      }
      pushValidationIssue(ctx, component, path + "/" + key, {
        code: present ? "null-required" : "missing-required"
      });
      invalid = true;
    }
  }
  for (const key of Object.keys(props)) {
    if (!(key in obj)) continue;
    const sub = props[key];
    let next = validateSchemaValue(obj[key], sub, component, path + "/" + key, ctx);
    if (__ouiShape({ phase: "edge", invalid: next === INVALID }).op === "repair") {
      next = resolveInvalidValue(required.includes(key), getSchemaDefaultValue(sub));
      if (next === INVALID) {
        invalid = true;
        continue;
      }
    }
    if (__ouiShape({ phase: "same", same: next === obj[key] }).op === "keep") continue;
    out ??= { ...obj };
    if (__ouiShape({ phase: "write", nil: next === void 0 }).op === "delete") delete out[key];
    else out[key] = next;
  }
  if (__ouiShape({ phase: "done", invalid }).op === "invalid") return INVALID;
  return out ?? obj;
}
function validateArrayValueMoonbit(value, s, component, path, ctx) {
  if (__ouiShape({ phase: "box", bad: !Array.isArray(value) }).op === "mismatch") {
    pushValidationIssue(ctx, component, path, {
      code: "type-mismatch",
      expected: "array",
      actual: jsType(value)
    });
    return INVALID;
  }
  const items = s["items"];
  const bad = !items || typeof items !== "object" || Array.isArray(items);
  if (__ouiShape({ phase: "items", bad }).op === "keep") return value;
  let out;
  for (let i = 0; i < value.length; i++) {
    const next = validateSchemaValue(value[i], items, component, path + "/" + i, ctx);
    const changed = next !== value[i];
    if (__ouiShape({ phase: "cell", changed, fresh: !out }).op === "copy") out = value.slice(0, i);
    if (__ouiShape({ phase: "push", open: Boolean(out), valid: next !== INVALID }).op === "push") out.push(next);
  }
  return out ?? value;
}
function validateLeafValueMoonbit(value, s, component, path, ctx) {
  const leaf = getScalarTypeInfo(s);
  const typed = leaf.expectedType != null;
  const enums = !typed && leaf.enumValues != null;
  if (__ouiShape({ phase: "leaf", typed, enums }).op === "skip") return false;
  const listed = Boolean(leaf.enumValues);
  const partial = listed && Boolean(ctx.partial);
  if (__ouiShape({ phase: "defer", listed, partial }).op === "defer") return false;
  const mismatch = checkTypeMismatch(value, leaf);
  if (__ouiShape({ phase: "miss", bad: Boolean(mismatch) }).op === "bad") {
    pushValidationIssue(ctx, component, path, {
      code: "type-mismatch",
      ...mismatch
    });
    return true;
  }
  return false;
}
function validateSchemaValueMoonbit(value, schema, component, path, ctx) {
  if (__ouiShape({ phase: "gate", bad: !schema || typeof schema !== "object" || Array.isArray(schema) }).op === "keep") return value;
  if (__ouiShape({ phase: "value", nil: value == null }).op === "keep") return value;
  if (__ouiShape({ phase: "ast", ast: isASTNode(value) }).op === "keep") return value;
  if (__ouiShape({ phase: "element", element: isElementNode(value) }).op === "position") {
    return validateElementPosition(value, schema, component, path, ctx) ? INVALID : value;
  }
  if (__ouiShape({ phase: "shape", composite: isCompositeSchema(schema) }).op === "slot") {
    if (!isOnlyComponentSlot(schema, ctx)) return value;
    pushValidationIssue(ctx, component, path, {
      code: "type-mismatch",
      expected: slotRefNames(schema).join(" | "),
      actual: Array.isArray(value) ? "array" : typeof value === "object" ? "plain object" : typeof value
    });
    return INVALID;
  }
  const type = schema["type"];
  const step = __ouiShape({ phase: "kind", object: type === "object", array: type === "array" });
  if (step.op === "object") return validateObjectValue(value, schema, component, path, ctx);
  if (step.op === "array") return validateArrayValue(value, schema, component, path, ctx);
  return validateLeafValue(value, schema, component, path, ctx) ? INVALID : value;
}
function checkValueMoonbit(value, schema, name, path, context, strict) {
  const ctx = { errors: [], partial: false };
  const checked = validateSchemaValue(value, schema, name, path, ctx);
  for (const e of ctx.errors) context.reportError?.("@" + name + ": " + e.message);
  const failed = strict && ctx.errors.length > 0;
  if (__ouiBind({ phase: "strict", failed }).op === "invalid") return INVALID;
  return checked;
}
function evaluateArgsMoonbit(node, context, params) {
  const mapped = node.mappedProps;
  const named =
    __ouiBind({ phase: "args", mapped: mapped != null }).op === "props" ? mapped : nameArgs(node.args, params);
  const args = {};
  for (const key in named) args[key] = evaluate(named[key], context);
  return args;
}
function nameArgsMoonbit(args, params) {
  const named = {};
  for (let i = 0; i < params.length && i < args.length; i++) {
    if (__ouiBind({ phase: "name" }).op === "set") named[params[i].name] = args[i];
  }
  return named;
}
function pushValidationIssueMoonbit(ctx, component, path, issue) {
  const errors = ctx.errors;
  const entry = {
    code: issue.code,
    component,
    path,
    message: validationMessage(component, path, issue),
    statementId: ctx.currentStatementId
  };
  const warn = issue.code === "no-root" && issue.reason === "fallback";
  if (__ouiBind({ phase: "warn", warn }).op === "warning") entry.severity = "warning";
  errors.push(entry);
}
function getSchemaDefaultValueMoonbit(property) {
  if (__ouiLink({ phase: "gate", bad: !property || typeof property !== "object" || Array.isArray(property) }).op === "skip") return;
  return property.default;
}
function refNameMoonbit(s) {
  if (__ouiLink({ phase: "ref", text: typeof s["$ref"] === "string" }).op === "name") return s["$ref"].split("/").pop();
  return void 0;
}
function isCompositeSchemaMoonbit(s) {
  let miss = "";
  for (;;) {
    const step = __ouiLink({ phase: "composite", miss });
    if (step.op !== "check") return false;
    if (step.key in s) return true;
    miss = step.key;
  }
}
function slotRefNamesMoonbit(s) {
  const anyOf = s["anyOf"];
  if (__ouiLink({ phase: "slot", any: anyOf != null }).op === "any") return anyOf.map(refName);
  const oneOf = s["oneOf"];
  if (__ouiLink({ phase: "slot", one: oneOf != null }).op === "one") return oneOf.map(refName);
  return [s].map(refName);
}
function isOnlyComponentSlotMoonbit(s, ctx) {
  const names = slotRefNames(s);
  if (__ouiLink({ phase: "only", open: names.length > 0 }).op !== "scan") return false;
  return names.every((n) => {
    if (__ouiLink({ phase: "member", named: n !== void 0 }).op !== "has") return false;
    return ctx.cat?.has(n);
  });
}
function getTypeFromSchemaMoonbit(property) {
  if (__ouiLink({ phase: "gate", bad: !property || typeof property !== "object" || Array.isArray(property) }).op === "skip") return;
  const ref = refName(property);
  if (__ouiLink({ phase: "type", ref: Boolean(ref) }).op === "ref") return ref;
  const leaf = getScalarTypeInfo(property);
  if (__ouiLink({ phase: "leaf", enums: Boolean(leaf.enumValues) }).op === "enum") {
    return leaf.enumValues.map((v) => JSON.stringify(v)).join("|");
  }
  if (__ouiLink({ phase: "expect", typed: Boolean(leaf.expectedType) }).op === "type") return leaf.expectedType;
  if (__ouiLink({ phase: "plain", text: typeof property.type === "string" }).op === "type") return property.type;
  return void 0;
}
function buildParamsSignatureMoonbit(component, params) {
  const head = String(component) + "(";
  const parts = params.map((p) => {
    const type = getTypeFromSchema(p.schema);
    const required = Boolean(p.required);
    const name = p.name;
    const step = __ouiLink({ phase: "param", required, typed: Boolean(type) });
    if (step.op === "both") return String(name) + "*: " + type;
    if (step.op === "typed") return String(name) + ": " + type;
    if (step.op === "star") return String(name) + "*";
    return name;
  });
  return head + parts.join(", ") + ")";
}
function evaluatePropInlineMoonbit(value, context, schemaCtx, reactiveSchema) {
  if (__ouiWrap({ phase: "inline" }).op !== "core") return value;
  return evaluatePropCore(value, context, schemaCtx, reactiveSchema, {
    recurseElement: (el) => evaluateElementInline(el, context, schemaCtx),
    recurse: (v, rs) => evaluatePropInline(v, context, schemaCtx, rs)
  });
}
function evaluatePropCoreMoonbit(value, context, schemaCtx, reactiveSchema, callbacks) {
  const result = evaluatePropValue$1(value, context, schemaCtx, reactiveSchema, callbacks);
  const plan = isActionPlan(result);
  if (__ouiWrap({ phase: "plan", plan }).op === "own") return ownSteps(result);
  return result;
}
function evaluatePropTreeMoonbit(value, evalCtx, schemaCtx, reactiveSchema) {
  const ctx = evalCtx.ctx;
  if (__ouiWrap({ phase: "tree" }).op !== "core") return value;
  return evaluatePropCore(value, ctx, schemaCtx, reactiveSchema, {
    recurseElement: (el) => evaluateElementProps(el, evalCtx),
    recurse: (v, rs) => evaluatePropValue(v, evalCtx, schemaCtx, rs)
  });
}
function evaluateActionCallMoonbit(node, context) {
  const name = node.name;
  const args = node.args;
  if (__ouiWrap({ phase: "call", action: name === "Action" }).op === "list") {
    const open = args.length > 0;
    const list = __ouiWrap({ phase: "open", open }).op === "eval" ? evaluate(args[0], context) : [];
    if (__ouiWrap({ phase: "boxed", array: Array.isArray(list) }).op === "plans") return flattenPlans(list);
    return flattenPlans([]);
  }
  const def = BUILTIN_STEPS[name];
  const has = Boolean(def.step);
  const step = __ouiWrap({ phase: "def", has }).op === "call" ? def.step(evaluateArgs(node, context)) : evaluateLazyStep(name, args);
  if (__ouiWrap({ phase: "pack", filled: Boolean(step) }).op === "one") return { steps: [step] };
  return { steps: [] };
}
function evaluateLazyStepMoonbit(name, args) {
  const kind = name === "Run" ? "run" : name === "Set" ? "set" : name === "Reset" ? "reset" : "";
  const step = __ouiWrap({ phase: "lazy", kind });
  if (step.op === "run") {
    const refNode = args[0];
    if (__ouiWrap({ phase: "ref", ok: refNode?.k === "RuntimeRef" }).op !== "keep") return null;
    return { type: ACTION_STEPS.Run, statementId: refNode.n, refType: refNode.refType };
  }
  if (step.op === "set") {
    if (__ouiWrap({ phase: "pair", open: args.length >= 2 }).op !== "go") return null;
    if (__ouiWrap({ phase: "state", state: args[0].k === "StateRef" }).op !== "keep") return null;
    return { type: ACTION_STEPS.Set, target: args[0].n, valueAST: args[1] };
  }
  if (step.op === "reset") {
    const targets = args.filter((a) => a.k === "StateRef").map((a) => a.n);
    if (__ouiWrap({ phase: "reset", empty: targets.length === 0 }).op === "drop") return null;
    return { type: ACTION_STEPS.Reset, targets };
  }
  return null;
}
function isBuiltinMoonbit(name) {
  return __ouiWrap({ phase: "builtin", has: BUILTIN_CALLS.has(name) }).op === "yes";
}
function isStepMoonbit(name, actions) {
  const def = BUILTIN_CALLS.get(name);
  if (__ouiWrap({ phase: "step", action: def?.kind === "action" }).op === "yes") return true;
  if (__ouiWrap({ phase: "extra", present: !!actions }).op !== "scan") return false;
  return __ouiWrap({ phase: "own", own: Object.prototype.hasOwnProperty.call(actions, name) }).op === "yes";
}
function isReservedCallMoonbit(name) {
  return __ouiWrap({ phase: "reserved", has: name in RESERVED_CALLS }).op === "yes";
}
function getCallDefsMoonbit(cat) {
  if (__ouiWrap({ phase: "cat", present: cat != null }).op !== "local") return BUILTIN_CALLS;
  const defs = cat.callDefs;
  if (__ouiWrap({ phase: "defs", present: defs != null }).op === "local") return defs;
  return BUILTIN_CALLS;
}
const LEGACY_TOKEN = {
  Newline: 0,
  LParen: 1,
  RParen: 2,
  LBrack: 3,
  RBrack: 4,
  LBrace: 5,
  RBrace: 6,
  Comma: 7,
  Colon: 8,
  Equals: 9,
  True: 10,
  False: 11,
  Null: 12,
  EOF: 13,
  Str: 14,
  Num: 15,
  Ident: 16,
  Type: 17,
  StateVar: 18,
  Dot: 19,
  Plus: 20,
  Minus: 21,
  Star: 22,
  Slash: 23,
  Percent: 24,
  EqEq: 25,
  NotEq: 26,
  Greater: 27,
  Less: 28,
  GreaterEq: 29,
  LessEq: 30,
  And: 31,
  Or: 32,
  Not: 33,
  Question: 34,
  BuiltinCall: 35
};
function legacyString(src, line, column) {
  let index = 0;
  let lineNow = 1;
  let col = 1;
  while (index < src.length && (lineNow < line || col < column)) {
    if (src.charCodeAt(index) === 10) {
      lineNow += 1;
      col = 1;
    } else {
      col += 1;
    }
    index += 1;
  }
  const quote = src.charCodeAt(index);
  const start = index;
  index += 1;
  let closed = false;
  if (quote === 34) {
    while (index < src.length) {
      const code = src.charCodeAt(index);
      if (code === 92) index += 2;
      else if (code === 34) {
        index += 1;
        closed = true;
        break;
      } else index += 1;
    }
    const raw = src.slice(start, index);
    const valid = closed ? raw : raw + String.fromCharCode(34);
    try {
      return JSON.parse(valid);
    } catch (error) {
      return raw.replace(/^"|"$/g, "");
    }
  }
  let result = "";
  while (index < src.length) {
    const code = src.charCodeAt(index);
    if (code === 92) {
      index += 1;
      if (index < src.length) {
        const esc = src.charCodeAt(index);
        if (esc === 39) result += "'";
        else if (esc === 92) result += String.fromCharCode(92);
        else if (esc === 110) result += String.fromCharCode(10);
        else if (esc === 116) result += String.fromCharCode(9);
        else result += src.charAt(index);
        index += 1;
      }
    } else if (code === 39) {
      break;
    } else {
      result += src.charAt(index);
      index += 1;
    }
  }
  return result;
}
function tokenizeMoonbit(src) {
  if (typeof src !== "string") {
    const length = src.length;
    if (!(typeof length === "number" && length > 0)) return [{ t: 13 }];
    let text = "";
    for (let index = 0; index < length; index += 1) text += src[index];
    src = text;
  }
  const tokens = __ouiTokenize(src);
  const out = [];
  for (const tok of tokens) {
    const item = { t: LEGACY_TOKEN[tok.t] };
    if (tok.t === "Str") item.v = legacyString(src, tok.line, tok.column);
    else if (tok.t === "Num") item.v = +tok.v;
    else if (tok.v !== undefined) item.v = tok.v;
    out.push(item);
  }
  return out;
}

function preprocessMoonbit(input) {
  return __ouiPreprocess(input.trim()).trim();
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
import { parseProgram as __ouiParseProgram, parseResult as __ouiParseResult, createStream as __ouiCreateStream, parseMessage as __ouiParseMessage, buildMessage as __ouiBuildMessage, parseRules as __ouiParseRules, parseStructuredRules as __ouiParseStructuredRules, checkBuiltin as __ouiCheckBuiltin, enrichErrors as __ouiEnrichErrors, mergeStatements as __ouiMergeStatements, jsonToOpenUI as __ouiJsonToOpenUI, evaluatePure as __ouiEvaluatePure, walkAST as __ouiWalkAST, isASTNode as __ouiIsASTNode, toLiteralAST as __ouiToLiteralAST, literalValue as __ouiLiteralValue, callBuiltin as __ouiCallBuiltin, lazyStep as __ouiLazyStep, eagerStep as __ouiEagerStep, generatePrompt as __ouiGeneratePrompt, cloudConfig as __ouiCloudConfig, substituteRef as __ouiSubstituteRef, systemPromptKind as __ouiSystemPromptKind, isElementNode as __ouiIsElementNode, isReactiveAssign as __ouiIsReactiveAssign, isRuntimeExpr as __ouiIsRuntimeExpr, isActionPlan as __ouiIsActionPlan, flattenPlans as __ouiFlattenPlans, extractToolResult as __ouiExtractToolResult, stableStringify as __ouiStableStringify, buildCacheKey as __ouiBuildCacheKey, resolveField as __ouiResolveField, toNumber as __ouiToNumber, rootStep as __ouiEvaluateRoot, eachStep as __ouiEach, propStep as __ouiPropStep, propError as __ouiPropError, storeKeep as __ouiStoreKeep, storeInit as __ouiStoreInit, createQueryManager as __ouiCreateQueryManager, stateField as __ouiStateField, stripAssign as __ouiStripAssign, callArg as __ouiCallArg, listStep as __ouiListStep, inlineStep as __ouiInlineStep, checkValue as __ouiCheck, userCall as __ouiUserCall, customCall as __ouiCustom, mappedComp as __ouiMapped, leafStep as __ouiLeaf, msgStep as __ouiMsg, shapeStep as __ouiShape, bindStep as __ouiBind, linkStep as __ouiLink, wrapStep as __ouiWrap, tokenize as __ouiTokenize, preprocessSource as __ouiPreprocess } from '@heyq02/openui.mbt/parser';
${SHIM}`;
  }
  return `${MARKER}
const { parseProgram: __ouiParseProgram, parseResult: __ouiParseResult, createStream: __ouiCreateStream, parseMessage: __ouiParseMessage, buildMessage: __ouiBuildMessage, parseRules: __ouiParseRules, parseStructuredRules: __ouiParseStructuredRules, checkBuiltin: __ouiCheckBuiltin, enrichErrors: __ouiEnrichErrors, mergeStatements: __ouiMergeStatements, jsonToOpenUI: __ouiJsonToOpenUI, evaluatePure: __ouiEvaluatePure, walkAST: __ouiWalkAST, isASTNode: __ouiIsASTNode, toLiteralAST: __ouiToLiteralAST, literalValue: __ouiLiteralValue, callBuiltin: __ouiCallBuiltin, lazyStep: __ouiLazyStep, eagerStep: __ouiEagerStep, generatePrompt: __ouiGeneratePrompt, cloudConfig: __ouiCloudConfig, substituteRef: __ouiSubstituteRef, systemPromptKind: __ouiSystemPromptKind, isElementNode: __ouiIsElementNode, isReactiveAssign: __ouiIsReactiveAssign, isRuntimeExpr: __ouiIsRuntimeExpr, isActionPlan: __ouiIsActionPlan, flattenPlans: __ouiFlattenPlans, extractToolResult: __ouiExtractToolResult, stableStringify: __ouiStableStringify, buildCacheKey: __ouiBuildCacheKey, resolveField: __ouiResolveField, toNumber: __ouiToNumber, rootStep: __ouiEvaluateRoot, eachStep: __ouiEach, propStep: __ouiPropStep, propError: __ouiPropError, storeKeep: __ouiStoreKeep, storeInit: __ouiStoreInit, createQueryManager: __ouiCreateQueryManager, stateField: __ouiStateField, stripAssign: __ouiStripAssign, callArg: __ouiCallArg, listStep: __ouiListStep, inlineStep: __ouiInlineStep, checkValue: __ouiCheck, userCall: __ouiUserCall, customCall: __ouiCustom, mappedComp: __ouiMapped, leafStep: __ouiLeaf, msgStep: __ouiMsg, shapeStep: __ouiShape, bindStep: __ouiBind, linkStep: __ouiLink, wrapStep: __ouiWrap, tokenize: __ouiTokenize, preprocessSource: __ouiPreprocess } = require('@heyq02/openui.mbt/parser');
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
  const expected = 85;
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

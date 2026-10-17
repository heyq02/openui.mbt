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
    'const builtInValidators = {\n\trequired: (value) => builtinMoonbit("required", value),\n\temail: (value) => builtinMoonbit("email", value),\n\turl: (value) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== "string") return "Please enter a valid URL";\n\t\ttry {\n\t\t\tnew URL(value);\n\t\t\treturn;\n\t\t} catch {\n\t\t\treturn "Please enter a valid URL";\n\t\t}\n\t},\n\tnumeric: (value) => builtinMoonbit("numeric", value),\n\tmin: (value, arg) => builtinMoonbit("min", value, arg),\n\tmax: (value, arg) => builtinMoonbit("max", value, arg),\n\tminLength: (value, arg) => builtinMoonbit("minLength", value, arg),\n\tmaxLength: (value, arg) => builtinMoonbit("maxLength", value, arg),\n\tpattern: (value, arg) => {\n\t\tif (isEmpty(value)) return void 0;\n\t\tif (typeof value !== "string" || typeof arg !== "string") return void 0;\n\t\ttry {\n\t\t\treturn new RegExp(arg).test(value) ? void 0 : "Invalid format";\n\t\t} catch {\n\t\t\treturn;\n\t\t}\n\t}\n};\n',
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
    'function evaluate(node, context, schemaCtx) {\n\tif (node.k === "Comp") {\n\t\t\tconst builtin = BUILTINS[node.name];\n\t\t\tif (builtin) {\n\t\t\t\tif (builtin.lazy) return evaluateLazyBuiltin(node.name, node.args, context, schemaCtx);\n\t\t\t\tconst builtinArgs = evaluateArgs(node, context);\n\t\t\t\tconst builtinResult = callBuiltinMoonbit(node.name, builtinArgs);\n\t\t\t\tif (!(builtinResult && builtinResult.__useJs)) return builtinResult;\n\t\t\t\treturn builtin.fn(builtinArgs);\n\t\t\t}\n\t\t\tif (isStep(node.name) && (node.name === "Run" || node.name === "Set" || node.name === "Reset")) return lazyStepMoonbit(node);\n\t\t\tif (isStep(node.name) && (node.name === \"OpenUrl\" || node.name === \"ToAssistant\")) return eagerStepMoonbit(node, context);\n\t\t\tif (isStep(node.name)) return evaluateActionCall(node, context);\n\t\t\tconst fns = context.functions;\n\t\t\tif (fns && Object.prototype.hasOwnProperty.call(fns, node.name)) return callFunction(node.name, fns[node.name], node, context);\n\t\t\tconst acts = context.actions;\n\t\t\tif (acts && Object.prototype.hasOwnProperty.call(acts, node.name)) {\n\t\t\t\tconst def = acts[node.name];\n\t\t\t\tconst args = callArgs(node, context, def.params);\n\t\t\t\tif (missesRequired(args, def.params)) return { steps: [] };\n\t\t\t\tconst params = checkValue(args, def.params, node.name, "", context, true);\n\t\t\t\tif (params === INVALID) return { steps: [] };\n\t\t\t\tconst step = {\n\t\t\t\t\ttype: "custom_action",\n\t\t\t\t\tname: node.name,\n\t\t\t\t\tparams\n\t\t\t\t};\n\t\t\t\tcustomSteps.add(step);\n\t\t\t\treturn { steps: [step] };\n\t\t\t}\n\t\t\tif (node.mappedProps) {\n\t\t\t\tconst def = schemaCtx?.library.components[node.name];\n\t\t\t\tconst props = {};\n\t\t\t\tfor (const [key, val] of Object.entries(node.mappedProps)) {\n\t\t\t\t\tconst propSchema = def?.props?.shape?.[key];\n\t\t\t\t\tif (val.k === "StateRef" && propSchema && isReactiveSchema(propSchema)) props[key] = {\n\t\t\t\t\t\t__reactive: "assign",\n\t\t\t\t\t\ttarget: val.n,\n\t\t\t\t\t\texpr: {\n\t\t\t\t\t\t\tk: "StateRef",\n\t\t\t\t\t\t\tn: "$value"\n\t\t\t\t\t\t}\n\t\t\t\t\t};\n\t\t\t\t\telse if (val.k === "StateRef") props[key] = schemaCtx ? context.getState(val.n) : val;\n\t\t\t\t\telse props[key] = evaluate(val, context, schemaCtx);\n\t\t\t\t}\n\t\t\t\tconst result = {\n\t\t\t\t\ttype: "element",\n\t\t\t\t\ttypeName: node.name,\n\t\t\t\t\tprops,\n\t\t\t\t\tpartial: false,\n\t\t\t\t\thasDynamicProps: true\n\t\t\t\t};\n\t\t\t\tif (schemaCtx) {\n\t\t\t\t\tfor (const [key, val] of Object.entries(props)) if (isElementNode(val)) props[key] = evaluateElementInline(val, context, schemaCtx);\n\t\t\t\t\telse if (Array.isArray(val)) props[key] = val.map((item) => isElementNode(item) ? evaluateElementInline(item, context, schemaCtx) : item);\n\t\t\t\t}\n\t\t\t\treturn result;\n\t\t\t}\n\t\t\tconsole.warn(`[openui] Unexpected unmapped Comp node: ${node.name}`);\n\t\t\treturn null;\n\t}\n\treturn evaluateMoonbitPure(node, context, schemaCtx);\n}\n',
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
import { parseProgram as __ouiParseProgram, parseResult as __ouiParseResult, createStream as __ouiCreateStream, parseMessage as __ouiParseMessage, buildMessage as __ouiBuildMessage, parseRules as __ouiParseRules, parseStructuredRules as __ouiParseStructuredRules, checkBuiltin as __ouiCheckBuiltin, enrichErrors as __ouiEnrichErrors, mergeStatements as __ouiMergeStatements, jsonToOpenUI as __ouiJsonToOpenUI, evaluatePure as __ouiEvaluatePure, walkAST as __ouiWalkAST, isASTNode as __ouiIsASTNode, toLiteralAST as __ouiToLiteralAST, literalValue as __ouiLiteralValue, callBuiltin as __ouiCallBuiltin, lazyStep as __ouiLazyStep, eagerStep as __ouiEagerStep, generatePrompt as __ouiGeneratePrompt, cloudConfig as __ouiCloudConfig, substituteRef as __ouiSubstituteRef, systemPromptKind as __ouiSystemPromptKind, isElementNode as __ouiIsElementNode, isReactiveAssign as __ouiIsReactiveAssign, isRuntimeExpr as __ouiIsRuntimeExpr } from '@heyq02/openui.mbt/parser';
${SHIM}`;
  }
  return `${MARKER}
const { parseProgram: __ouiParseProgram, parseResult: __ouiParseResult, createStream: __ouiCreateStream, parseMessage: __ouiParseMessage, buildMessage: __ouiBuildMessage, parseRules: __ouiParseRules, parseStructuredRules: __ouiParseStructuredRules, checkBuiltin: __ouiCheckBuiltin, enrichErrors: __ouiEnrichErrors, mergeStatements: __ouiMergeStatements, jsonToOpenUI: __ouiJsonToOpenUI, evaluatePure: __ouiEvaluatePure, walkAST: __ouiWalkAST, isASTNode: __ouiIsASTNode, toLiteralAST: __ouiToLiteralAST, literalValue: __ouiLiteralValue, callBuiltin: __ouiCallBuiltin, lazyStep: __ouiLazyStep, eagerStep: __ouiEagerStep, generatePrompt: __ouiGeneratePrompt, cloudConfig: __ouiCloudConfig, substituteRef: __ouiSubstituteRef, systemPromptKind: __ouiSystemPromptKind, isElementNode: __ouiIsElementNode, isReactiveAssign: __ouiIsReactiveAssign, isRuntimeExpr: __ouiIsRuntimeExpr } = require('@heyq02/openui.mbt/parser');
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
  const expected = 30;
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

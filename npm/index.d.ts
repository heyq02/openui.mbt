export interface MoonbitError {
  line: number;
  column: number;
  message: string;
}

export interface MoonbitExpr {
  k: string;
  [field: string]: unknown;
}

export interface MoonbitStatement {
  id: string;
  line: number;
  expr: MoonbitExpr;
}

export interface MoonbitProgram {
  statements: MoonbitStatement[];
  errors: MoonbitError[];
}

export interface MoonbitToken {
  t: string;
  line: number;
  column: number;
  v?: string;
}

export interface MaterializedElement {
  type: "element";
  typeName: string;
  statementId?: string;
  partial: boolean;
  props: Record<string, unknown>;
}

export interface MaterializeError {
  code: string;
  component: string;
  path: string;
  message: string;
  line: number;
  column: number;
}

export interface MaterializeResult {
  root: MaterializedElement | null;
  incomplete: boolean;
  unresolved: string[];
  orphaned: string[];
  errors: MaterializeError[];
}

export function parseProgram(source: string): MoonbitProgram;
export function tokenize(source: string): MoonbitToken[];
export function materializeProgram(
  source: string,
  schema: string,
  rootName?: string,
): MaterializeResult;

export interface ParseResult {
  root: MaterializedElement | null;
  meta: {
    incomplete: boolean;
    unresolved: string[];
    orphaned: string[];
    statementCount: number;
    errors: MaterializeError[];
  };
  stateDeclarations: Record<string, unknown>;
  queryStatements: unknown[];
  mutationStatements: unknown[];
}

export interface OpenUiStream {
  push(chunk: string, complete?: boolean): ParseResult;
  set(text: string, complete?: boolean): ParseResult;
  result(complete?: boolean): ParseResult;
  finish(): ParseResult;
  dispose(): void;
}

export interface OpenUiMessage {
  content: string;
  context: unknown;
  attributes: Record<string, string>;
  end: boolean;
}

export function parseMessage(raw: string, options?: { streaming?: boolean }): OpenUiMessage;

export function buildMessage(message: {
  content?: string;
  context?: unknown;
  attributes?: Record<string, unknown>;
  end?: boolean;
}): string;

export interface ParsedRule {
  type: string;
  arg?: unknown;
}

export function parseRules(rules: unknown): ParsedRule[];

export function parseStructuredRules(rules: unknown): ParsedRule[];

export function checkBuiltin(kind: string, value: unknown, arg?: unknown): string | undefined;

export interface EnrichedError {
  source: "parser";
  code: string;
  message: string;
  component: string;
  path?: string;
  statementId?: string;
  severity?: string;
  hint?: string;
}

export function mergeStatements(existing: string, patch: string, rootId?: string): string;

export function isASTNode(value: unknown): boolean;
export function toLiteralAST(value: unknown): {
  k: string;
  v?: unknown;
  els?: unknown[];
  entries?: unknown[];
};
export function literalValue(node: { k?: unknown }): { v: unknown } | undefined;
export function substituteRef(node: { k?: unknown }, varName: unknown, value: unknown): unknown;
export function systemPromptKind(spec: object): "cloud" | "legacy" | "library";
export function isElementNode(value: unknown): boolean;
export function isReactiveAssign(value: unknown): boolean;
export function isRuntimeExpr(node: { k?: unknown }): boolean;
export function isActionPlan(value: unknown): boolean;
export function flattenPlans(values: unknown): { steps: unknown[] } | unknown;
export function resolveField(obj: unknown, path: unknown): unknown;
export function toNumber(value: unknown): number;
export function rootStep(tag: string): {
  op: string;
  error?: {
    source: string;
    code: string;
    statementId: string;
    message: string;
  };
};
export function eachStep(payload: {
  phase?: string;
  name?: string;
  n?: number;
  wide?: boolean;
  array?: boolean;
  k?: string;
  ok?: boolean;
}): { op: string };
export function propStep(payload: {
  phase?: string;
  kind?: string;
  k?: string;
  reactive?: boolean;
  element?: boolean;
  array?: boolean;
  assign?: boolean;
  needs?: boolean;
}): { op: string };
export function storeKeep(payload: {
  same?: boolean;
  plain?: boolean;
  n?: number;
  o?: number;
  eq?: boolean[];
}): { op: string };
export function storeInit(payload: {
  phase?: string;
  has?: boolean;
  same?: boolean;
  pristine?: boolean;
}): { op: string };
export function querySlot(payload: {
  phase?: string;
  data?: boolean;
  prev?: boolean;
  prevData?: boolean;
  loading?: boolean;
  ever?: boolean;
  error?: boolean;
}): { op?: string; load?: boolean; refetch?: boolean; error?: boolean };
export function stateField(payload: { assign?: boolean; store?: boolean; context?: boolean }): {
  op: string;
};
export function stripAssign(payload: { assign?: boolean }): { op: string };
export function callArg(payload: {
  phase?: string;
  nil?: boolean;
  list?: boolean;
  hit?: boolean;
  absent?: boolean;
  bare?: boolean;
}): { op: string };
export function listStep(payload: {
  phase?: string;
  kind?: string;
  array?: boolean;
  numeric?: boolean;
  desc?: boolean;
  op?: string;
}): { op: string; sign?: number };
export function inlineStep(payload: { frozen?: boolean }): { op: string };
export function checkValue(payload: {
  phase?: string;
  nil?: boolean;
  empty?: boolean;
  has?: boolean;
  n?: number;
  code?: string;
  kind?: string;
  ok?: boolean;
  known?: boolean;
  hit?: boolean;
}): { op: string; text?: string; code?: string };
export function userCall(payload: {
  phase?: string;
  miss?: boolean;
  bad?: boolean;
  returns?: boolean;
  nil?: boolean;
}): { op: string };
export function customCall(payload: {
  phase?: string;
  named?: boolean;
  miss?: boolean;
  bad?: boolean;
}): { op: string };
export function mappedComp(payload: {
  phase?: string;
  mapped?: boolean;
  state?: boolean;
  reactive?: boolean;
  schema?: boolean;
  element?: boolean;
  array?: boolean;
}): { op: string };
export function leafStep(payload: {
  phase?: string;
  kind?: string;
  scalar?: boolean;
  hit?: boolean;
  array?: boolean;
  typed?: boolean;
  match?: boolean;
}): { op: string };
export function msgStep(payload: {
  phase?: string;
  code?: string;
  marked?: boolean;
  show?: boolean;
  kind?: string;
  named?: boolean;
}): { op: string };
export function shapeStep(payload: {
  phase?: string;
  bad?: boolean;
  nil?: boolean;
  ast?: boolean;
  element?: boolean;
  composite?: boolean;
  object?: boolean;
  array?: boolean;
  typed?: boolean;
  enums?: boolean;
  listed?: boolean;
  partial?: boolean;
  shaped?: boolean;
  present?: boolean;
  list?: boolean;
  defined?: boolean;
  required?: boolean;
  invalid?: boolean;
  same?: boolean;
  changed?: boolean;
  fresh?: boolean;
  open?: boolean;
  valid?: boolean;
}): { op: string };
export function bindStep(payload: {
  phase?: string;
  mapped?: boolean;
  failed?: boolean;
  warn?: boolean;
}): { op: string };
export function queryError(payload: {
  source?: string;
  kind?: string;
  tool?: string;
  detail?: string;
}): {
  source: string;
  code: string;
  message: string;
  statementId: null;
  component: string;
  toolName: string;
  hint?: null;
};
export function createQueryManager(
  toolProvider?: {
    callTool: (name: string, args: unknown) => Promise<unknown>;
  },
  host?: {
    ToolNotFoundError?: new (...args: never[]) => Error;
    McpToolError?: new (...args: never[]) => Error;
  },
): {
  evaluateQueries: (nodes: unknown[]) => void;
  getResult: (statementId: string) => unknown;
  isLoading: (statementId: string) => boolean;
  isAnyLoading: () => boolean;
  invalidate: (statementIds?: string[]) => void;
  registerMutations: (nodes: unknown[]) => void;
  fireMutation: (
    statementId: string,
    evaluatedArgs: unknown,
    refreshQueryIds?: string[],
  ) => Promise<boolean>;
  getMutationResult: (statementId: string) => unknown;
  subscribe: (listener: () => void) => () => void;
  getSnapshot: () => Record<string, unknown>;
  activate: () => void;
  dispose: () => void;
};
export function propError(payload: { key?: string; typeName?: string; message?: string }): {
  source: string;
  code: string;
  component: string;
  statementId: null;
  message: string;
  hint: string;
};
export function stableStringify(value: unknown): string | undefined;
export function buildCacheKey(toolName: unknown, args: unknown, deps: unknown): string;
export function extractToolResult(payload: {
  error?: boolean;
  structured?: boolean;
  content?: string;
  items?: string[];
}): { op: string; at?: number[]; i?: number };
export function walkAST(node: { k?: unknown }, visit: (node: { k?: unknown }) => void): void;
export function generatePrompt(spec: {
  root?: unknown;
  preamble?: unknown;
  components: Record<string, { signature?: unknown; description?: unknown }>;
  componentGroups?: {
    name?: unknown;
    components: unknown[];
    notes?: unknown[];
  }[];
  functions?: Record<string, { signature?: unknown; description?: unknown }>;
  actions?: Record<string, { signature?: unknown; description?: unknown }>;
  builtinFunctions?: unknown;
  toolCalls?: unknown;
  bindings?: unknown;
  tools?: unknown[];
  examples?: unknown[];
  toolExamples?: unknown[];
  editMode?: unknown;
  inlineMode?: unknown;
  additionalRules?: unknown[];
}): string;
export function cloudConfig(spec: {
  library?: unknown;
  promptOptions?: {
    examples?: unknown;
    preamble?: unknown;
    additionalRules?: unknown;
  } | null;
  instructions?: unknown;
}): string;
export function callBuiltin(name: string, args: Record<string, unknown>): unknown;
export function eagerStep(
  name: string,
  args: { url?: unknown; message?: unknown; context?: unknown },
): { steps: Array<Record<string, unknown>> };
export function lazyStep(
  name: string,
  kinds: string[],
): { op: "run" | "set" | "reset" | "none"; at?: number[] };
export function evaluatePure(
  node: { k?: unknown },
  context?: {
    getState?: (name: string) => unknown;
    resolveRef?: (name: string) => unknown;
    extraScope?: Record<string, unknown> | null;
  },
  schemaCtx?: unknown,
  evalNode?: (node: { k?: unknown }) => unknown,
): unknown;
export function jsonToOpenUI(
  json: { typeName?: unknown; props?: object; statementId?: unknown },
  library: { toJSONSchema(): unknown },
  options?: { stateDeclarations?: Record<string, unknown> | null },
): string;

export function enrichErrors(
  validationErrors: Array<Record<string, unknown>>,
  schema:
    | { $defs?: Record<string, { properties?: object; required?: unknown[] }> }
    | null
    | undefined,
  componentNames: string[],
): EnrichedError[];

export function createStream(schema: string, rootName?: string): OpenUiStream;

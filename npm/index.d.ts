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

export function parseMessage(
  raw: string,
  options?: { streaming?: boolean },
): OpenUiMessage;

export function createStream(schema: string, rootName?: string): OpenUiStream;

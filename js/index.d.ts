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

export function parseProgram(source: string): MoonbitProgram;
export function tokenize(source: string): MoonbitToken[];

///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int32
  mut depth : Int32
  mut ternary_depth : Int32
  errors : Array[ParseError]
}

///|
fn infix_prec(kind : TokenKind) -> Int32 {
  match kind {
    Question => 1
    Or => 2
    And => 3
    EqEq | NotEq => 4
    Greater | Less | GreaterEq | LessEq => 5
    Plus | Minus => 6
    Star | Slash | Percent => 7
    Dot | LBrack => 9
    _ => 0
  }
}

///|
fn Parser::current(self : Parser) -> Token {
  self.tokens[self.pos]
}

///|
fn Parser::advance(self : Parser) -> Unit {
  if self.pos + 1 < self.tokens.length() {
    self.pos += 1
  }
}

///|
fn Parser::peek_kind(self : Parser) -> TokenKind {
  let next = self.pos + 1
  if next >= self.tokens.length() {
    EOF
  } else {
    self.tokens[next].kind
  }
}

///|
fn Parser::error(self : Parser, message : String) -> Unit {
  let tok = self.current()
  self.errors.push({
    line: tok.line,
    column: tok.column,
    kind: Expected(message),
  })
}

///|
fn Parser::skip_nested_newlines(self : Parser) -> Unit {
  if self.depth > 0 || self.ternary_depth > 0 {
    while self.current().kind is Newline {
      self.advance()
    }
    return
  }
  // A `?` on the next line continues the statement. A `:` only continues
  // while a ternary is already open, which the branch above covers.
  let mut peek = self.pos
  while peek < self.tokens.length() && self.tokens[peek].kind is Newline {
    peek += 1
  }
  if peek < self.tokens.length() && self.tokens[peek].kind is Question {
    self.pos = peek
  }
}

///|
fn Parser::skip_line(self : Parser) -> Unit {
  while true {
    match self.current().kind {
      EOF => break
      Newline => {
        self.advance()
        break
      }
      _ => self.advance()
    }
  }
}

///|
fn strip_state_prefix(name : String) -> String {
  if name.length() > 0 && name.at(0).to_int() == '$'.to_int() {
    name[1:].to_owned()
  } else {
    name
  }
}

///|
fn Parser::parse_list(self : Parser, closing : TokenKind) -> Array[Expr] {
  self.depth += 1
  let items : Array[Expr] = []
  while true {
    self.skip_nested_newlines()
    let kind = self.current().kind
    if kind is EOF || kind == closing {
      break
    }
    let before = self.pos
    items.push(self.parse_expr(0))
    if self.pos == before {
      self.error("expected expression")
      self.advance()
    }
    self.skip_nested_newlines()
    if self.current().kind is Comma {
      self.advance()
    }
  }
  if self.current().kind == closing {
    self.advance()
  }
  self.depth -= 1
  items
}

///|
fn Parser::parse_call(self : Parser, is_function : Bool) -> Expr {
  let name = self.current().text
  let function = is_function && !is_builtin(name)
  self.advance()
  if self.current().kind is LParen {
    self.advance()
  }
  let args = self.parse_list(RParen)
  Comp(name, function, args)
}

///|
fn Parser::parse_array(self : Parser) -> Expr {
  self.advance()
  Arr(self.parse_list(RBrack))
}

///|
fn Parser::field_name(self : Parser) -> String {
  let tok = self.current()
  match tok.kind {
    Ident | Type | Str | Num => {
      self.advance()
      tok.text
    }
    StateVar => {
      self.advance()
      strip_state_prefix(tok.text)
    }
    _ => {
      self.advance()
      "?"
    }
  }
}

///|
fn Parser::parse_object(self : Parser) -> Expr {
  self.advance()
  self.depth += 1
  let entries : Array[(String, Expr)] = []
  while true {
    self.skip_nested_newlines()
    let kind = self.current().kind
    if kind is RBrace || kind is EOF {
      break
    }
    let key = self.field_name()
    self.skip_nested_newlines()
    if self.current().kind is Colon {
      self.advance()
    } else {
      self.error("expected ':'")
    }
    let before = self.pos
    let value = self.parse_expr(0)
    if self.pos == before {
      self.error("expected expression")
      self.advance()
    }
    entries.push((key, value))
    self.skip_nested_newlines()
    if self.current().kind is Comma {
      self.advance()
    }
  }
  if self.current().kind is RBrace {
    self.advance()
  }
  self.depth -= 1
  Obj(entries)
}

///|
fn Parser::parse_prefix(self : Parser) -> Expr {
  self.skip_nested_newlines()
  let tok = self.current()
  match tok.kind {
    Str => {
      self.advance()
      Str(tok.text)
    }
    Num => {
      self.advance()
      Num(parse_number(tok.text), tok.text)
    }
    True => {
      self.advance()
      Bool(true)
    }
    False => {
      self.advance()
      Bool(false)
    }
    Null => {
      self.advance()
      Null
    }
    LBrack => self.parse_array()
    LBrace => self.parse_object()
    StateVar => {
      let name = tok.text
      self.advance()
      if self.current().kind is Equals {
        self.advance()
        Assign(name, self.parse_expr(0))
      } else {
        StateRef(name)
      }
    }
    Type => {
      let name = tok.text
      if self.peek_kind() is LParen && is_component_call_name(name) {
        self.parse_call(false)
      } else {
        self.advance()
        Ref(name)
      }
    }
    BuiltinCall =>
      if self.peek_kind() is LParen {
        self.parse_call(true)
      } else {
        let name = tok.text
        self.advance()
        Ref(name)
      }
    Ident => {
      let name = tok.text
      self.advance()
      Ref(name)
    }
    Not => {
      self.advance()
      UnaryOp("!", self.parse_expr(8))
    }
    Minus => {
      self.advance()
      UnaryOp("-", self.parse_expr(8))
    }
    LParen => {
      self.advance()
      self.depth += 1
      let inner = self.parse_expr(0)
      self.skip_nested_newlines()
      if self.current().kind is RParen {
        self.advance()
      }
      self.depth -= 1
      inner
    }
    _ => Null
  }
}

///|
fn Parser::parse_infix(self : Parser, left : Expr, prec : Int32) -> Expr {
  match self.current().kind {
    Plus => {
      self.advance()
      BinOp("+", left, self.parse_expr(prec))
    }
    Minus => {
      self.advance()
      BinOp("-", left, self.parse_expr(prec))
    }
    Star => {
      self.advance()
      BinOp("*", left, self.parse_expr(prec))
    }
    Slash => {
      self.advance()
      BinOp("/", left, self.parse_expr(prec))
    }
    Percent => {
      self.advance()
      BinOp("%", left, self.parse_expr(prec))
    }
    EqEq => {
      self.advance()
      BinOp("==", left, self.parse_expr(prec))
    }
    NotEq => {
      self.advance()
      BinOp("!=", left, self.parse_expr(prec))
    }
    Greater => {
      self.advance()
      BinOp(">", left, self.parse_expr(prec))
    }
    Less => {
      self.advance()
      BinOp("<", left, self.parse_expr(prec))
    }
    GreaterEq => {
      self.advance()
      BinOp(">=", left, self.parse_expr(prec))
    }
    LessEq => {
      self.advance()
      BinOp("<=", left, self.parse_expr(prec))
    }
    And => {
      self.advance()
      BinOp("&&", left, self.parse_expr(prec))
    }
    Or => {
      self.advance()
      BinOp("||", left, self.parse_expr(prec))
    }
    Question => {
      if self.depth == 0 {
        self.ternary_depth += 1
      }
      self.advance()
      let then_branch = self.parse_expr(0)
      self.skip_nested_newlines()
      if self.current().kind is Colon {
        if self.depth == 0 && self.ternary_depth > 0 {
          self.ternary_depth -= 1
        }
        self.advance()
      } else if self.depth == 0 && self.ternary_depth > 0 {
        self.ternary_depth -= 1
      }
      let else_branch = self.parse_expr(0)
      Ternary(left, then_branch, else_branch)
    }
    Dot => {
      self.advance()
      let field = self.field_name()
      Member(left, field)
    }
    LBrack => {
      self.advance()
      self.depth += 1
      let index = self.parse_expr(0)
      self.skip_nested_newlines()
      if self.current().kind is RBrack {
        self.advance()
      }
      self.depth -= 1
      Index(left, index)
    }
    _ => left
  }
}

///|
fn Parser::parse_expr(self : Parser, min_prec : Int32) -> Expr {
  let mut left = self.parse_prefix()
  while true {
    self.skip_nested_newlines()
    let prec = infix_prec(self.current().kind)
    if prec <= min_prec {
      break
    }
    left = self.parse_infix(left, prec)
  }
  left
}

///|
fn is_statement_name(kind : TokenKind) -> Bool {
  match kind {
    Ident | Type | StateVar => true
    _ => false
  }
}

///|
fn Parser::parse_statement(self : Parser) -> Statement? {
  let tok = self.current()
  if !is_statement_name(tok.kind) {
    self.error("expected statement")
    self.skip_line()
    return None
  }
  let id = tok.text
  let line = tok.line
  self.advance()
  if !(self.current().kind is Equals) {
    self.error("expected '='")
    self.skip_line()
    return None
  }
  self.advance()
  let start = self.pos
  let expr = self.parse_expr(0)
  if self.pos == start {
    self.error("expected expression")
    self.skip_line()
    return None
  }
  match self.current().kind {
    Newline => self.advance()
    EOF => ()
    _ => {
      self.error("trailing tokens")
      self.skip_line()
    }
  }
  Some({ id, expr, line, })
}

///|
/// Parse assignment statements. A bad line is reported and skipped.
pub fn parse(src : String) -> Program {
  let tokens = tokenize(src)
  let parser = Parser::{
    tokens,
    pos: 0,
    depth: 0,
    ternary_depth: 0,
    errors: [],
  }
  let statements : Array[Statement] = []
  while !(parser.current().kind is EOF) {
    while parser.current().kind is Newline {
      parser.advance()
    }
    if parser.current().kind is EOF {
      break
    }
    match parser.parse_statement() {
      Some(stmt) => statements.push(stmt)
      None => ()
    }
  }
  { statements, errors: parser.errors, }
}

///|
pub fn tokens_json(src : String) -> String {
  let encoded : Array[Json] = []
  for tok in tokenize(src) {
    encoded.push(tok.to_json())
  }
  Json::array(encoded).stringify()
}

///|
pub fn parse_json(src : String) -> String {
  parse(src).to_json().stringify(indent=2)
}

///|
pub fn summarize(src : String) -> String {
  let program = parse(src)
  let buf = StringBuilder()
  buf.write_string("statements: ")
  buf.write_string(program.statements.length().to_string())
  buf.write_string("\nerrors: ")
  buf.write_string(program.errors.length().to_string())
  for stmt in program.statements {
    buf.write_string("\n")
    buf.write_string(stmt.line.to_string())
    buf.write_string(" ")
    buf.write_string(stmt.id)
    buf.write_string(" = ")
    buf.write_string(stmt.expr.dump())
  }
  for err in program.errors {
    buf.write_string("\nerror ")
    buf.write_string(err.line.to_string())
    buf.write_string(":")
    buf.write_string(err.column.to_string())
    buf.write_string(" ")
    buf.write_string(err.message())
  }
  buf.to_string()
}

///|
/// Official `parseExpression()` over numeric tokens.
/// Leaf names and literal values stay indexes so the host can keep `tok.v`.
priv struct LegacyTok {
  t : Int32
  s : String
  named : Bool
}

///|
priv struct LegacyExpr {
  mut pos : Int32
  toks : Array[LegacyTok]
}

///|
fn legacy_num(value : Int32) -> Json {
  Json::number(value.to_double())
}

///|
fn legacy_code(value : Json) -> Int32 {
  match value {
    Number(number, ..) =>
      if number < 0.0 || number > 35.0 {
        -1
      } else {
        let code = number.to_int()
        if code.to_double() == number {
          code
        } else {
          -1
        }
      }
    _ => -1
  }
}

///|
fn legacy_tok(value : Json) -> LegacyTok {
  match value {
    Object(map) => {
      let t = match map.get("t") {
        Some(code) => legacy_code(code)
        None => -1
      }
      match map.get("s") {
        Some(String(text)) => { t, s: text, named: true, }
        _ => { t, s: "", named: false, }
      }
    }
    _ => { t: -1, s: "", named: false, }
  }
}

///|
fn LegacyExpr::cur_t(self : LegacyExpr) -> Int32 {
  if self.pos < 0 || self.pos >= self.toks.length() {
    13
  } else {
    self.toks[self.pos].t
  }
}

///|
fn LegacyExpr::named_text(self : LegacyExpr) -> String {
  if self.pos < 0 ||
    self.pos >= self.toks.length() ||
    !self.toks[self.pos].named {
    ""
  } else {
    self.toks[self.pos].s
  }
}

///|
fn LegacyExpr::is_named(self : LegacyExpr) -> Bool {
  self.pos >= 0 && self.pos < self.toks.length() && self.toks[self.pos].named
}

///|
fn LegacyExpr::peek_t(self : LegacyExpr) -> Int32 {
  let next = self.pos + 1
  if next >= 0 && next < self.toks.length() {
    self.toks[next].t
  } else {
    -1
  }
}

///|
fn LegacyExpr::take(self : LegacyExpr) -> Int32 {
  let at = self.pos
  self.pos = self.pos + 1
  at
}

///|
fn LegacyExpr::skip(self : LegacyExpr) -> Unit {
  self.pos = self.pos + 1
}

///|
fn LegacyExpr::eat(self : LegacyExpr, kind : Int32) -> Unit {
  if self.cur_t() == kind {
    self.pos = self.pos + 1
  }
}

///|
fn legacy_prec(kind : Int32) -> Int32 {
  match kind {
    34 => 1
    32 => 2
    31 => 3
    25 | 26 => 4
    27 | 28 | 29 | 30 => 5
    20 | 21 => 6
    22 | 23 | 24 => 7
    19 | 3 => 9
    _ => 0
  }
}

///|
fn legacy_null() -> Json {
  object_of([("k", Json::string("Null"))])
}

///|
fn legacy_at(kind : String, at : Int32) -> Json {
  object_of([("k", Json::string(kind)), ("at", legacy_num(at))])
}

///|
fn legacy_key(op : String, at : Int32) -> Json {
  if op == "q" {
    object_of([("op", Json::string("q"))])
  } else {
    object_of([("op", Json::string(op)), ("at", legacy_num(at))])
  }
}

///|
fn LegacyExpr::take_key(self : LegacyExpr) -> Json {
  let tt = self.cur_t()
  let at = self.take()
  if tt == 16 || tt == 17 || tt == 14 || tt == 15 {
    legacy_key("str", at)
  } else if tt == 18 {
    legacy_key("strip", at)
  } else {
    legacy_key("q", at)
  }
}

///|
fn legacy_comp(at : Int32, args : Array[Json], is_fn : Bool) -> Json {
  if is_fn {
    object_of([
      ("k", Json::string("Comp")),
      ("at", legacy_num(at)),
      ("args", Json::array(args)),
      ("fn", Json::boolean(true)),
    ])
  } else {
    object_of([
      ("k", Json::string("Comp")),
      ("at", legacy_num(at)),
      ("args", Json::array(args)),
    ])
  }
}

///|
fn legacy_binop(op : String, left : Json, right : Json) -> Json {
  object_of([
    ("k", Json::string("BinOp")),
    ("op", Json::string(op)),
    ("left", left),
    ("right", right),
  ])
}

///|
fn LegacyExpr::parse_list(self : LegacyExpr, closing : Int32) -> Array[Json] {
  let items : Array[Json] = []
  while self.cur_t() != closing && self.cur_t() != 13 {
    items.push(self.parse_expr(0))
    if self.cur_t() == 7 {
      self.skip()
    }
  }
  self.eat(closing)
  items
}

///|
fn LegacyExpr::parse_comp(self : LegacyExpr, is_fn : Bool) -> Json {
  let at = self.take()
  self.eat(1)
  legacy_comp(at, self.parse_list(2), is_fn)
}

///|
fn LegacyExpr::component_call(self : LegacyExpr) -> Bool {
  if self.peek_t() != 1 {
    false
  } else if !self.is_named() {
    true
  } else {
    let name = self.named_text()
    !is_builtin(name) || name == "Action"
  }
}

///|
fn LegacyExpr::parse_prefix(self : LegacyExpr) -> Json {
  let tt = self.cur_t()
  if tt == 14 {
    legacy_at("Str", self.take())
  } else if tt == 15 {
    legacy_at("Num", self.take())
  } else if tt == 10 {
    self.skip()
    object_of([("k", Json::string("Bool")), ("v", Json::boolean(true))])
  } else if tt == 11 {
    self.skip()
    object_of([("k", Json::string("Bool")), ("v", Json::boolean(false))])
  } else if tt == 12 {
    self.skip()
    legacy_null()
  } else if tt == 3 {
    self.skip()
    object_of([
      ("k", Json::string("Arr")),
      ("els", Json::array(self.parse_list(4))),
    ])
  } else if tt == 5 {
    self.skip()
    let entries : Array[Json] = []
    while self.cur_t() != 6 && self.cur_t() != 13 {
      let key = self.take_key()
      self.eat(8)
      entries.push(object_of([("key", key), ("value", self.parse_expr(0))]))
      if self.cur_t() == 7 {
        self.skip()
      }
    }
    self.eat(6)
    object_of([("k", Json::string("Obj")), ("entries", Json::array(entries))])
  } else if tt == 18 {
    let at = self.take()
    if self.cur_t() == 9 {
      self.skip()
      object_of([
        ("k", Json::string("Assign")),
        ("at", legacy_num(at)),
        ("value", self.parse_expr(0)),
      ])
    } else {
      legacy_at("StateRef", at)
    }
  } else if tt == 17 {
    if self.component_call() {
      self.parse_comp(false)
    } else {
      legacy_at("Ref", self.take())
    }
  } else if tt == 35 {
    if self.peek_t() == 1 {
      let name = self.named_text()
      let is_fn = !self.is_named() || !is_builtin(name)
      self.parse_comp(is_fn)
    } else {
      legacy_at("Ref", self.take())
    }
  } else if tt == 16 {
    legacy_at("Ref", self.take())
  } else if tt == 33 {
    self.skip()
    object_of([
      ("k", Json::string("UnaryOp")),
      ("op", Json::string("!")),
      ("operand", self.parse_expr(8)),
    ])
  } else if tt == 21 {
    self.skip()
    object_of([
      ("k", Json::string("UnaryOp")),
      ("op", Json::string("-")),
      ("operand", self.parse_expr(8)),
    ])
  } else if tt == 1 {
    self.skip()
    let inner = self.parse_expr(0)
    self.eat(2)
    inner
  } else {
    self.skip()
    legacy_null()
  }
}

///|
fn LegacyExpr::parse_infix(self : LegacyExpr, left : Json) -> Json {
  let tt = self.cur_t()
  if tt == 20 {
    self.skip()
    legacy_binop("+", left, self.parse_expr(6))
  } else if tt == 21 {
    self.skip()
    legacy_binop("-", left, self.parse_expr(6))
  } else if tt == 22 {
    self.skip()
    legacy_binop("*", left, self.parse_expr(7))
  } else if tt == 23 {
    self.skip()
    legacy_binop("/", left, self.parse_expr(7))
  } else if tt == 24 {
    self.skip()
    legacy_binop("%", left, self.parse_expr(7))
  } else if tt == 25 {
    self.skip()
    legacy_binop("==", left, self.parse_expr(4))
  } else if tt == 26 {
    self.skip()
    legacy_binop("!=", left, self.parse_expr(4))
  } else if tt == 27 {
    self.skip()
    legacy_binop(">", left, self.parse_expr(5))
  } else if tt == 28 {
    self.skip()
    legacy_binop("<", left, self.parse_expr(5))
  } else if tt == 29 {
    self.skip()
    legacy_binop(">=", left, self.parse_expr(5))
  } else if tt == 30 {
    self.skip()
    legacy_binop("<=", left, self.parse_expr(5))
  } else if tt == 31 {
    self.skip()
    legacy_binop("&&", left, self.parse_expr(3))
  } else if tt == 32 {
    self.skip()
    legacy_binop("||", left, self.parse_expr(2))
  } else if tt == 34 {
    self.skip()
    let then_branch = self.parse_expr(0)
    self.eat(8)
    object_of([
      ("k", Json::string("Ternary")),
      ("cond", left),
      ("then", then_branch),
      ("else", self.parse_expr(0)),
    ])
  } else if tt == 19 {
    self.skip()
    let key = self.take_key()
    object_of([("k", Json::string("Member")), ("obj", left), ("field", key)])
  } else if tt == 3 {
    self.skip()
    let index = self.parse_expr(0)
    self.eat(4)
    object_of([("k", Json::string("Index")), ("obj", left), ("index", index)])
  } else {
    left
  }
}

///|
fn LegacyExpr::parse_expr(self : LegacyExpr, min_prec : Int32) -> Json {
  let mut left = self.parse_prefix()
  while legacy_prec(self.cur_t()) > min_prec {
    left = self.parse_infix(left)
  }
  left
}

///|
/// Expression skeleton for official numeric tokens. `at` is the token index of a copied `v`.
pub fn parse_expression_json(tokens_json : String) -> String {
  try {
    match @json.parse(tokens_json) {
      Array(items) => {
        let toks : Array[LegacyTok] = []
        for item in items {
          toks.push(legacy_tok(item))
        }
        let parser = LegacyExpr::{ pos: 0, toks, }
        parser.parse_expr(0).stringify()
      }
      _ => "{\"k\":\"Null\"}"
    }
  } catch {
    _ => "{\"k\":\"Null\"}"
  }
}

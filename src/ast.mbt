///|
/// Expression produced by the phase-0 parser.
/// Component calls use `Comp`. `@Custom(...)` sets `is_function`.
pub enum Expr {
  Null
  Bool(Bool)
  Num(Double, String)
  Str(String)
  Ref(String)
  StateRef(String)
  Comp(String, Bool, Array[Expr])
  Arr(Array[Expr])
  Obj(Array[(String, Expr)])
  UnaryOp(String, Expr)
  BinOp(String, Expr, Expr)
  Ternary(Expr, Expr, Expr)
  Member(Expr, String)
  Index(Expr, Expr)
  Assign(String, Expr)
}

///|
pub struct Statement {
  id : String
  expr : Expr
  line : Int32
}

///|
pub struct ParseError {
  line : Int32
  column : Int32
  kind : SyntaxKind
}

///|
pub fn ParseError::message(self : ParseError) -> String {
  self.kind.message()
}

///|
pub struct Program {
  statements : Array[Statement]
  errors : Array[ParseError]
}

///|
fn join_dump(items : Array[Expr]) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for item in items {
    if index > 0 {
      buf.write_string(", ")
    }
    buf.write_string(item.dump())
    index += 1
  }
  buf.to_string()
}

///|
pub fn Expr::dump(self : Expr) -> String {
  match self {
    Null => "Null"
    Bool(true) => "Bool(true)"
    Bool(false) => "Bool(false)"
    Num(_, repr) => "Num(" + repr + ")"
    Str(text) => "Str(" + Json::string(text).stringify() + ")"
    Ref(name) => "Ref(" + name + ")"
    StateRef(name) => "StateRef(" + name + ")"
    Comp(name, is_function, args) =>
      if is_function {
        "Fn(" + name + ", [" + join_dump(args) + "])"
      } else {
        "Comp(" + name + ", [" + join_dump(args) + "])"
      }
    Arr(items) => "Arr([" + join_dump(items) + "])"
    Obj(entries) => {
      let buf = StringBuilder()
      buf.write_string("Obj({")
      let mut index = 0
      for entry in entries {
        if index > 0 {
          buf.write_string(", ")
        }
        let (key, value) = entry
        buf.write_string(Json::string(key).stringify())
        buf.write_string(": ")
        buf.write_string(value.dump())
        index += 1
      }
      buf.write_string("})")
      buf.to_string()
    }
    UnaryOp(op, operand) => "Unary(" + op + ", " + operand.dump() + ")"
    BinOp(op, left, right) =>
      "Bin(" + op + ", " + left.dump() + ", " + right.dump() + ")"
    Ternary(cond, then_branch, else_branch) =>
      "Ternary(" +
      cond.dump() +
      ", " +
      then_branch.dump() +
      ", " +
      else_branch.dump() +
      ")"
    Member(obj, field) => "Member(" + obj.dump() + ", " + field + ")"
    Index(obj, index) => "Index(" + obj.dump() + ", " + index.dump() + ")"
    Assign(target, value) => "Assign(" + target + ", " + value.dump() + ")"
  }
}

///|
fn object_of(fields : Array[(String, Json)]) -> Json {
  let map : Map[String, Json] = Map([])
  for field in fields {
    let (key, value) = field
    map[key] = value
  }
  Json::object(map)
}

///|
pub fn Expr::to_json(self : Expr) -> Json {
  match self {
    Null => object_of([("k", Json::string("Null"))])
    Bool(value) =>
      object_of([("k", Json::string("Bool")), ("v", Json::boolean(value))])
    Num(value, repr) =>
      object_of([("k", Json::string("Num")), ("v", Json::number(value, repr~))])
    Str(text) =>
      object_of([("k", Json::string("Str")), ("v", Json::string(text))])
    Ref(name) =>
      object_of([("k", Json::string("Ref")), ("n", Json::string(name))])
    StateRef(name) =>
      object_of([("k", Json::string("StateRef")), ("n", Json::string(name))])
    Comp(name, is_function, args) => {
      let encoded : Array[Json] = []
      for arg in args {
        encoded.push(arg.to_json())
      }
      let fields : Array[(String, Json)] = [
        ("k", Json::string("Comp")),
        ("name", Json::string(name)),
        ("args", Json::array(encoded)),
      ]
      if is_function {
        fields.push(("fn", Json::boolean(true)))
      }
      object_of(fields)
    }
    Arr(items) => {
      let encoded : Array[Json] = []
      for item in items {
        encoded.push(item.to_json())
      }
      object_of([("k", Json::string("Arr")), ("els", Json::array(encoded))])
    }
    Obj(entries) => {
      let encoded : Array[Json] = []
      for entry in entries {
        let (key, value) = entry
        encoded.push(Json::array([Json::string(key), value.to_json()]))
      }
      object_of([("k", Json::string("Obj")), ("entries", Json::array(encoded))])
    }
    UnaryOp(op, operand) =>
      object_of([
        ("k", Json::string("UnaryOp")),
        ("op", Json::string(op)),
        ("operand", operand.to_json()),
      ])
    BinOp(op, left, right) =>
      object_of([
        ("k", Json::string("BinOp")),
        ("op", Json::string(op)),
        ("left", left.to_json()),
        ("right", right.to_json()),
      ])
    Ternary(cond, then_branch, else_branch) =>
      object_of([
        ("k", Json::string("Ternary")),
        ("cond", cond.to_json()),
        ("then", then_branch.to_json()),
        ("else", else_branch.to_json()),
      ])
    Member(obj, field) =>
      object_of([
        ("k", Json::string("Member")),
        ("obj", obj.to_json()),
        ("field", Json::string(field)),
      ])
    Index(obj, index) =>
      object_of([
        ("k", Json::string("Index")),
        ("obj", obj.to_json()),
        ("index", index.to_json()),
      ])
    Assign(target, value) =>
      object_of([
        ("k", Json::string("Assign")),
        ("target", Json::string(target)),
        ("value", value.to_json()),
      ])
  }
}

///|
pub fn Program::to_json(self : Program) -> Json {
  let statements : Array[Json] = []
  for stmt in self.statements {
    statements.push(
      object_of([
        ("id", Json::string(stmt.id)),
        ("line", Json::number(Double::from_int(stmt.line))),
        ("expr", stmt.expr.to_json()),
      ]),
    )
  }
  let errors : Array[Json] = []
  for err in self.errors {
    errors.push(
      object_of([
        ("line", Json::number(Double::from_int(err.line))),
        ("column", Json::number(Double::from_int(err.column))),
        ("message", Json::string(err.message())),
      ]),
    )
  }
  object_of([
    ("statements", Json::array(statements)),
    ("errors", Json::array(errors)),
  ])
}

///|
fn write_hex_byte(buf : StringBuilder, code : Int32) -> Unit {
  let digits = "0123456789abcdef"
  match digits.at(code / 16).to_int().to_char() {
    Some(ch) => buf.write_char(ch)
    None => ()
  }
  match digits.at(code % 16).to_int().to_char() {
    Some(ch) => buf.write_char(ch)
    None => ()
  }
}

///|
fn write_json_string(buf : StringBuilder, text : String) -> Unit {
  buf.write_char('"')
  let mut index = 0
  let length = text.length()
  while index < length {
    let code = text.at(index).to_int()
    if code == 34 {
      buf.write_string("\\\"")
    } else if code == 92 {
      buf.write_string("\\\\")
    } else if code == 8 {
      buf.write_string("\\b")
    } else if code == 12 {
      buf.write_string("\\f")
    } else if code == 10 {
      buf.write_string("\\n")
    } else if code == 13 {
      buf.write_string("\\r")
    } else if code == 9 {
      buf.write_string("\\t")
    } else if code < 32 {
      buf.write_string("\\u00")
      write_hex_byte(buf, code)
    } else if code >= 0xD800 && code <= 0xDFFF {
      buf.write_char(code.unsafe_to_char())
    } else {
      match code.to_char() {
        Some(ch) => buf.write_char(ch)
        None => ()
      }
    }
    index += 1
  }
  buf.write_char('"')
}

///|
fn write_expr_list(buf : StringBuilder, items : Array[Expr]) -> Unit {
  buf.write_char('[')
  let mut index = 0
  for item in items {
    if index > 0 {
      buf.write_char(',')
    }
    write_expr_json(buf, item)
    index += 1
  }
  buf.write_char(']')
}

///|
fn write_expr_json(buf : StringBuilder, expr : Expr) -> Unit {
  match expr {
    Null => buf.write_string("{\"k\":\"Null\"}")
    Bool(true) => buf.write_string("{\"k\":\"Bool\",\"v\":true}")
    Bool(false) => buf.write_string("{\"k\":\"Bool\",\"v\":false}")
    Num(_, repr) => {
      buf.write_string("{\"k\":\"Num\",\"v\":")
      buf.write_string(repr)
      buf.write_char('}')
    }
    Str(text) => {
      buf.write_string("{\"k\":\"Str\",\"v\":")
      write_json_string(buf, text)
      buf.write_char('}')
    }
    Ref(name) => {
      buf.write_string("{\"k\":\"Ref\",\"n\":")
      write_json_string(buf, name)
      buf.write_char('}')
    }
    StateRef(name) => {
      buf.write_string("{\"k\":\"StateRef\",\"n\":")
      write_json_string(buf, name)
      buf.write_char('}')
    }
    Comp(name, is_function, args) => {
      buf.write_string("{\"k\":\"Comp\",\"name\":")
      write_json_string(buf, name)
      buf.write_string(",\"args\":")
      write_expr_list(buf, args)
      match mapped_param_names(name) {
        Some(params) => {
          buf.write_string(",\"mappedProps\":{")
          let mut index = 0
          let mut wrote = false
          while index < params.length() && index < args.length() {
            if wrote {
              buf.write_char(',')
            }
            wrote = true
            write_json_string(buf, params[index])
            buf.write_char(':')
            write_expr_json(buf, args[index])
            index = index + 1
          }
          buf.write_char('}')
        }
        None => ()
      }
      if is_function {
        buf.write_string(",\"fn\":true")
      }
      buf.write_char('}')
    }
    Arr(items) => {
      buf.write_string("{\"k\":\"Arr\",\"els\":")
      write_expr_list(buf, items)
      buf.write_char('}')
    }
    Obj(entries) => {
      buf.write_string("{\"k\":\"Obj\",\"entries\":[")
      let mut index = 0
      for entry in entries {
        if index > 0 {
          buf.write_char(',')
        }
        let (key, value) = entry
        buf.write_char('[')
        write_json_string(buf, key)
        buf.write_char(',')
        write_expr_json(buf, value)
        buf.write_char(']')
        index += 1
      }
      buf.write_string("]}")
    }
    UnaryOp(op, operand) => {
      buf.write_string("{\"k\":\"UnaryOp\",\"op\":")
      write_json_string(buf, op)
      buf.write_string(",\"operand\":")
      write_expr_json(buf, operand)
      buf.write_char('}')
    }
    BinOp(op, left, right) => {
      buf.write_string("{\"k\":\"BinOp\",\"op\":")
      write_json_string(buf, op)
      buf.write_string(",\"left\":")
      write_expr_json(buf, left)
      buf.write_string(",\"right\":")
      write_expr_json(buf, right)
      buf.write_char('}')
    }
    Ternary(cond, then_branch, else_branch) => {
      buf.write_string("{\"k\":\"Ternary\",\"cond\":")
      write_expr_json(buf, cond)
      buf.write_string(",\"then\":")
      write_expr_json(buf, then_branch)
      buf.write_string(",\"else\":")
      write_expr_json(buf, else_branch)
      buf.write_char('}')
    }
    Member(obj, field) => {
      buf.write_string("{\"k\":\"Member\",\"obj\":")
      write_expr_json(buf, obj)
      buf.write_string(",\"field\":")
      write_json_string(buf, field)
      buf.write_char('}')
    }
    Index(obj, index) => {
      buf.write_string("{\"k\":\"Index\",\"obj\":")
      write_expr_json(buf, obj)
      buf.write_string(",\"index\":")
      write_expr_json(buf, index)
      buf.write_char('}')
    }
    Assign(target, value) => {
      buf.write_string("{\"k\":\"Assign\",\"target\":")
      write_json_string(buf, target)
      buf.write_string(",\"value\":")
      write_expr_json(buf, value)
      buf.write_char('}')
    }
  }
}

///|
/// Statement JSON without the intermediate `Json` map. The Wasm binding parses this back in JavaScript.
pub fn Program::compact_json(self : Program) -> String {
  let buf = StringBuilder()
  buf.write_string("{\"statements\":[")
  let mut index = 0
  for stmt in self.statements {
    if index > 0 {
      buf.write_char(',')
    }
    buf.write_string("{\"id\":")
    write_json_string(buf, stmt.id)
    buf.write_string(",\"line\":")
    buf.write_string(stmt.line.to_string())
    buf.write_string(",\"expr\":")
    write_expr_json(buf, stmt.expr)
    buf.write_char('}')
    index += 1
  }
  buf.write_string("],\"errors\":[")
  index = 0
  for err in self.errors {
    if index > 0 {
      buf.write_char(',')
    }
    buf.write_string("{\"line\":")
    buf.write_string(err.line.to_string())
    buf.write_string(",\"column\":")
    buf.write_string(err.column.to_string())
    buf.write_string(",\"message\":")
    write_json_string(buf, err.message())
    buf.write_char('}')
    index += 1
  }
  buf.write_string("]}")
  buf.to_string()
}

///|
pub fn Token::to_json(self : Token) -> Json {
  let fields : Array[(String, Json)] = [
    ("t", Json::string(self.kind.name())),
    ("line", Json::number(Double::from_int(self.line))),
    ("column", Json::number(Double::from_int(self.column))),
  ]
  if self.text != "" {
    fields.push(("v", Json::string(self.text)))
  }
  object_of(fields)
}

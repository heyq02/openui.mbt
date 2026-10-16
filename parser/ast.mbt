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
  message : String
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
        ("message", Json::string(err.message)),
      ]),
    )
  }
  object_of([
    ("statements", Json::array(statements)),
    ("errors", Json::array(errors)),
  ])
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

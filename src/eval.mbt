///|
/// Expression evaluator. JavaScript boxes values and runs host calls.
/// This walk decides order: `&&`, `||`, and `?:` evaluate the side they use.
priv enum Frame {
  Eval(Json)
  AfterLeft(String, Json)
  AfterTruthy(String, Int32, Json)
  AfterRight(String, Int32)
  AfterUnary(String)
  AfterCond(Json, Json)
  Pick(Json, Json)
  AfterMember(String)
  AfterIndexObj(Json)
  AfterIndex(Int32)
  ArrStep(Array[Json], Int32, Array[Int32])
  ArrAfter(Array[Json], Int32, Array[Int32])
  ObjStep(Array[Json], Int32, Array[String], Array[Int32])
  ObjAfter(Array[Json], Int32, Array[String], Array[Int32])
}

///|
priv struct EvalRun {
  stack : Array[Frame]
  wait : Array[Int32]
  acc : Array[Int32]
  bit : Array[Int32]
}

///|
let eval_runs : Array[EvalRun] = []

///|
fn json_kind(node : Json) -> String {
  match node {
    Array(items) =>
      if items.length() > 0 {
        match items[0] {
          String(text) => text
          _ => ""
        }
      } else {
        ""
      }
    _ => ""
  }
}

///|
fn json_at(node : Json, index : Int32) -> Json {
  match node {
    Array(items) =>
      if index < items.length() {
        items[index]
      } else {
        Json::null()
      }
    _ => Json::null()
  }
}

///|
fn json_text_at(node : Json, index : Int32) -> String {
  match json_at(node, index) {
    String(text) => text
    _ => ""
  }
}

///|
fn json_int_at(node : Json, index : Int32) -> Int32 {
  match json_at(node, index) {
    Number(number, ..) => number.to_int()
    _ => 0
  }
}

///|
fn json_bool_at(node : Json, index : Int32) -> Bool {
  match json_at(node, index) {
    True => true
    _ => false
  }
}

///|
fn json_list(node : Json, index : Int32) -> Array[Json] {
  match json_at(node, index) {
    Array(items) => items
    _ => []
  }
}

///|
fn quote_json(text : String) -> String {
  Json::string(text).stringify()
}

///|
fn join_ints(ids : Array[Int32]) -> String {
  let buf = StringBuilder()
  buf.write_char('[')
  let mut index = 0
  for id in ids {
    if index > 0 {
      buf.write_char(',')
    }
    buf.write_string(id.to_string())
    index = index + 1
  }
  buf.write_char(']')
  buf.to_string()
}

///|
fn join_entries(keys : Array[String], ids : Array[Int32]) -> String {
  let buf = StringBuilder()
  buf.write_char('[')
  let mut index = 0
  while index < keys.length() && index < ids.length() {
    if index > 0 {
      buf.write_char(',')
    }
    buf.write_char('[')
    buf.write_string(quote_json(keys[index]))
    buf.write_char(',')
    buf.write_string(ids[index].to_string())
    buf.write_char(']')
    index = index + 1
  }
  buf.write_char(']')
  buf.to_string()
}

///|
fn req_done(id : Int32) -> String {
  "{\"done\":true,\"id\":" + id.to_string() + "}"
}

///|
fn number_repr(value : Json) -> String {
  match value {
    Number(_, repr~) =>
      match repr {
        Some(text) => text
        None => "0"
      }
    _ => "0"
  }
}

///|
fn run_acc(session : EvalRun) -> Int32 {
  session.acc[0]
}

///|
fn set_acc(session : EvalRun, id : Int32) -> Unit {
  session.acc[0] = id
}

///|
fn run_bit(session : EvalRun) -> Bool {
  session.bit[0] != 0
}

///|
fn set_bit(session : EvalRun, value : Bool) -> Unit {
  session.bit[0] = if value { 1 } else { 0 }
}

///|
fn finish_need(session : EvalRun, kind : String, body : String) -> String {
  session.wait[0] = if kind == "truthy" { 2 } else { 1 }
  eval_runs.push(session)
  let buf = StringBuilder()
  buf.write_string("{\"need\":")
  buf.write_string(quote_json(kind))
  buf.write_string(body)
  buf.write_char('}')
  buf.to_string()
}

///|
fn begin_node(session : EvalRun, node : Json) -> String? {
  let kind = json_kind(node)
  if kind == "Lit" {
    Some(
      finish_need(
        session,
        "lit",
        ",\"ast\":" + json_int_at(node, 1).to_string(),
      ),
    )
  } else if kind == "Str" {
    Some(
      finish_need(session, "str", ",\"v\":" + quote_json(json_text_at(node, 2))),
    )
  } else if kind == "Num" {
    let tag = json_at(node, 2)
    let flag = json_text_at(tag, 0)
    let extra = if flag == "n" {
      ",\"v\":" + number_repr(json_at(tag, 1))
    } else {
      ""
    }
    Some(finish_need(session, "num", ",\"k\":" + quote_json(flag) + extra))
  } else if kind == "Bool" {
    let flag = if json_bool_at(node, 2) { "true" } else { "false" }
    Some(finish_need(session, "bool", ",\"v\":" + flag))
  } else if kind == "Null" || kind == "Ph" {
    Some(finish_need(session, "null", ""))
  } else if kind == "StateRef" {
    Some(
      finish_need(
        session,
        "state",
        ",\"name\":" + quote_json(json_text_at(node, 2)),
      ),
    )
  } else if kind == "Ref" || kind == "RuntimeRef" {
    Some(
      finish_need(
        session,
        "ref",
        ",\"name\":" + quote_json(json_text_at(node, 2)),
      ),
    )
  } else if kind == "Assign" {
    Some(
      finish_need(
        session,
        "assign",
        ",\"ast\":" + json_int_at(node, 1).to_string(),
      ),
    )
  } else if kind == "Comp" {
    Some(
      finish_need(
        session,
        "eval",
        ",\"ast\":" + json_int_at(node, 1).to_string(),
      ),
    )
  } else if kind == "Arr" {
    session.stack.push(ArrStep(json_list(node, 2), 0, []))
    None
  } else if kind == "Obj" {
    session.stack.push(ObjStep(json_list(node, 2), 0, [], []))
    None
  } else if kind == "BinOp" {
    session.stack.push(AfterLeft(json_text_at(node, 2), json_at(node, 4)))
    session.stack.push(Eval(json_at(node, 3)))
    None
  } else if kind == "UnaryOp" {
    let op = json_text_at(node, 2)
    if op == "!" || op == "-" {
      session.stack.push(AfterUnary(op))
      session.stack.push(Eval(json_at(node, 3)))
    } else {
      return Some(finish_need(session, "null", ""))
    }
    None
  } else if kind == "Ternary" {
    session.stack.push(AfterCond(json_at(node, 3), json_at(node, 4)))
    session.stack.push(Eval(json_at(node, 2)))
    None
  } else if kind == "Member" {
    session.stack.push(AfterMember(json_text_at(node, 3)))
    session.stack.push(Eval(json_at(node, 2)))
    None
  } else if kind == "Index" {
    session.stack.push(AfterIndexObj(json_at(node, 3)))
    session.stack.push(Eval(json_at(node, 2)))
    None
  } else {
    Some(finish_need(session, "undef", ""))
  }
}

///|
fn arith(session : EvalRun, op : String, left : Int32, right : Int32) -> String {
  let kind = match op {
    "+" => "add"
    "-" => "sub"
    "*" => "mul"
    "/" => "div"
    "%" => "mod"
    "==" => "eq"
    "!=" => "ne"
    ">" => "gt"
    "<" => "lt"
    ">=" => "ge"
    "<=" => "le"
    _ => "null"
  }
  if kind == "null" {
    finish_need(session, "null", "")
  } else {
    finish_need(
      session,
      kind,
      ",\"l\":" + left.to_string() + ",\"r\":" + right.to_string(),
    )
  }
}

///|
fn step_session(session : EvalRun) -> String? {
  match session.stack.pop() {
    None => Some(req_done(run_acc(session)))
    Some(frame) =>
      match frame {
        Eval(node) => begin_node(session, node)
        AfterLeft(op, right) =>
          if op == "&&" || op == "||" {
            session.stack.push(AfterTruthy(op, run_acc(session), right))
            Some(
              finish_need(
                session,
                "truthy",
                ",\"id\":" + run_acc(session).to_string(),
              ),
            )
          } else {
            session.stack.push(AfterRight(op, run_acc(session)))
            session.stack.push(Eval(right))
            None
          }
        AfterTruthy(op, left, right) =>
          if (op == "&&" && !run_bit(session)) ||
            (op == "||" && run_bit(session)) {
            set_acc(session, left)
            None
          } else {
            session.stack.push(AfterRight(op, left))
            session.stack.push(Eval(right))
            None
          }
        AfterRight(op, left) =>
          if op == "&&" || op == "||" {
            None
          } else {
            Some(arith(session, op, left, run_acc(session)))
          }
        AfterUnary(op) =>
          if op == "!" {
            Some(
              finish_need(
                session,
                "not",
                ",\"id\":" + run_acc(session).to_string(),
              ),
            )
          } else {
            Some(
              finish_need(
                session,
                "neg",
                ",\"id\":" + run_acc(session).to_string(),
              ),
            )
          }
        AfterCond(when_true, when_false) => {
          session.stack.push(Pick(when_true, when_false))
          Some(
            finish_need(
              session,
              "truthy",
              ",\"id\":" + run_acc(session).to_string(),
            ),
          )
        }
        Pick(when_true, when_false) => {
          session.stack.push(
            Eval(if run_bit(session) { when_true } else { when_false }),
          )
          None
        }
        AfterMember(field) =>
          Some(
            finish_need(
              session,
              "member",
              ",\"id\":" +
              run_acc(session).to_string() +
              ",\"field\":" +
              quote_json(field),
            ),
          )
        AfterIndexObj(index) => {
          session.stack.push(AfterIndex(run_acc(session)))
          session.stack.push(Eval(index))
          None
        }
        AfterIndex(obj) =>
          Some(
            finish_need(
              session,
              "index",
              ",\"obj\":" +
              obj.to_string() +
              ",\"idx\":" +
              run_acc(session).to_string(),
            ),
          )
        ArrStep(items, index, ids) =>
          if index == items.length() {
            Some(finish_need(session, "arr", ",\"ids\":" + join_ints(ids)))
          } else {
            session.stack.push(ArrAfter(items, index, ids))
            session.stack.push(Eval(items[index]))
            None
          }
        ArrAfter(items, index, ids) => {
          ids.push(run_acc(session))
          session.stack.push(ArrStep(items, index + 1, ids))
          None
        }
        ObjStep(entries, index, keys, ids) =>
          if index == entries.length() {
            Some(
              finish_need(
                session,
                "obj",
                ",\"entries\":" + join_entries(keys, ids),
              ),
            )
          } else {
            let entry = entries[index]
            keys.push(json_text_at(entry, 0))
            session.stack.push(ObjAfter(entries, index, keys, ids))
            session.stack.push(Eval(json_at(entry, 1)))
            None
          }
        ObjAfter(entries, index, keys, ids) => {
          ids.push(run_acc(session))
          session.stack.push(ObjStep(entries, index + 1, keys, ids))
          None
        }
      }
  }
}

///|
fn pump(session : EvalRun) -> String {
  match step_session(session) {
    Some(text) => text
    None => pump(session)
  }
}

///|
fn read_answer(session : EvalRun, answer_json : String) -> EvalRun {
  if session.wait[0] == 0 {
    return session
  }
  try {
    match @json.parse(answer_json) {
      Object(map) =>
        if session.wait[0] == 2 {
          set_bit(
            session,
            match map.get("bit") {
              Some(True) => true
              _ => false
            },
          )
        } else {
          set_acc(
            session,
            match map.get("id") {
              Some(Number(number, ..)) => number.to_int()
              _ => 0
            },
          )
        }
      _ => ()
    }
  } catch {
    _ => ()
  }
  session.wait[0] = 0
  session
}

///|
fn push_root(root : Json) -> String {
  pump({ stack: [Eval(root)], wait: [0], acc: [0], bit: [0], })
}

///|
/// Start an expression. The result is a host request or `{"done":true,"id":n}`.
pub fn eval_start(ast_json : String) -> String {
  push_root(@json.parse(ast_json)) catch {
    _ => req_done(-1)
  }
}

///|
/// Continue the innermost expression with a host answer.
pub fn eval_answer(answer_json : String) -> String {
  match eval_runs.pop() {
    None => req_done(-1)
    Some(session) => pump(read_answer(session, answer_json))
  }
}

///|
/// Drop the innermost expression after the host throws.
pub fn eval_cancel() -> String {
  match eval_runs.pop() {
    None => ""
    Some(_) => ""
  }
}

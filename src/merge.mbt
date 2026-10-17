///|
/// Merge two OpenUI programs by statement name and drop statements that `root` cannot reach.
priv struct MergedStmt {
  id : String
  raw : String
  expr : Expr
}

///|
fn fence_at(src : String, index : Int32) -> Bool {
  index + 2 < src.length() &&
  src.at(index).to_int() == code('`') &&
  src.at(index + 1).to_int() == code('`') &&
  src.at(index + 2).to_int() == code('`')
}

///|
fn merge_skip_string(src : String, start : Int32) -> Int32 {
  if start >= src.length() || src.at(start).to_int() != code('"') {
    return start
  }
  let mut index = start + 1
  while index < src.length() {
    let ch = src.at(index).to_int()
    if ch == code('\\') {
      index = index + 2
    } else if ch == code('"') {
      return index + 1
    } else {
      index = index + 1
    }
  }
  index
}

///|
/// Pull fenced bodies out of a patch. A fence inside a double-quoted string stays text.
fn merge_strip_fences(input : String) -> String {
  let blocks : Array[String] = []
  let mut index = 0
  while index < input.length() {
    let mut fence = -1
    while index < input.length() {
      let next = merge_skip_string(input, index)
      if next > index {
        index = next
        continue
      }
      if fence_at(input, index) {
        fence = index
        break
      }
      index = index + 1
    }
    if fence < 0 {
      break
    }
    let mut cursor = fence + 3
    while cursor < input.length() && input.at(cursor).to_int() != code('\n') {
      cursor = cursor + 1
    }
    if cursor >= input.length() {
      blocks.push("")
      index = input.length()
      break
    }
    cursor = cursor + 1
    let mut close = -1
    let mut scan = cursor
    while scan < input.length() {
      let next = merge_skip_string(input, scan)
      if next > scan {
        scan = next
        continue
      }
      if fence_at(input, scan) {
        close = scan
        break
      }
      scan = scan + 1
    }
    if close >= 0 {
      blocks.push(input.unsafe_substring(start=cursor, end=close))
      index = close + 3
    } else {
      blocks.push(input.unsafe_substring(start=cursor, end=input.length()))
      index = input.length()
    }
  }
  if blocks.length() > 0 {
    return join_lines(blocks)
  }
  input
}

///|
fn split_statement_source(input : String) -> Array[String] {
  let stmts : Array[String] = []
  let mut depth = 0
  let mut quote = 0
  let mut escaped = false
  let mut start = 0
  let mut index = 0
  let limit = input.length()
  while index < limit {
    let ch = input.at(index).to_int()
    if escaped {
      escaped = false
    } else if ch == code('\\') && quote != 0 {
      escaped = true
    } else if quote != 0 {
      if ch == quote {
        quote = 0
      }
    } else if ch == code('"') || ch == code('\'') {
      quote = ch
    } else if ch == code('(') || ch == code('[') || ch == code('{') {
      depth = depth + 1
    } else if ch == code(')') || ch == code(']') || ch == code('}') {
      if depth > 0 {
        depth = depth - 1
      }
    } else if ch == code('\n') && depth <= 0 {
      let stmt = trim_copy(input.unsafe_substring(start~, end=index))
      if stmt.length() > 0 {
        stmts.push(stmt)
      }
      start = index + 1
    }
    index = index + 1
  }
  let tail = trim_copy(input.unsafe_substring(start~, end=limit))
  if tail.length() > 0 {
    stmts.push(tail)
  }
  stmts
}

///|
fn first_statement(raw : String) -> MergedStmt? {
  let program = parse(raw)
  if program.statements.length() == 0 {
    None
  } else {
    let stmt = program.statements[0]
    Some({ id: stmt.id, raw, expr: stmt.expr, })
  }
}

///|
fn parsed_statements(input : String) -> Array[MergedStmt] {
  let trimmed = trim_copy(input)
  let found : Array[MergedStmt] = []
  if trimmed.length() == 0 {
    return found
  }
  for raw in split_statement_source(trimmed) {
    match first_statement(raw) {
      Some(stmt) => found.push(stmt)
      None => ()
    }
  }
  found
}

///|
fn push_ref(names : Array[String], name : String) -> Unit {
  for found in names {
    if found == name {
      return
    }
  }
  names.push(name)
}

///|
fn collect_refs(expr : Expr, names : Array[String]) -> Unit {
  match expr {
    Ref(name) => push_ref(names, name)
    Comp(_, _, args) =>
      for arg in args {
        collect_refs(arg, names)
      }
    Arr(items) =>
      for item in items {
        collect_refs(item, names)
      }
    Obj(entries) =>
      for entry in entries {
        let (_, value) = entry
        collect_refs(value, names)
      }
    BinOp(_, left, right) => {
      collect_refs(left, names)
      collect_refs(right, names)
    }
    UnaryOp(_, operand) => collect_refs(operand, names)
    Ternary(cond, yes, no) => {
      collect_refs(cond, names)
      collect_refs(yes, names)
      collect_refs(no, names)
    }
    Member(obj, _) => collect_refs(obj, names)
    Index(obj, index) => {
      collect_refs(obj, names)
      collect_refs(index, names)
    }
    Assign(_, value) => collect_refs(value, names)
    Null | Bool(_) | Num(_) | Str(_) | StateRef(_) => ()
  }
}

///|
fn drop_id(order : Array[String], id : String) -> Unit {
  let mut index = 0
  while index < order.length() {
    if order[index] == id {
      let mut next = index
      while next + 1 < order.length() {
        order[next] = order[next + 1]
        next = next + 1
      }
      ignore(order.pop())
      return
    }
    index = index + 1
  }
}

///|
fn join_raw(order : Array[String], merged : Map[String, String]) -> String {
  let buf = StringBuilder()
  let mut count = 0
  for id in order {
    match merged.get(id) {
      Some(raw) => {
        if count > 0 {
          buf.write_char('\n')
        }
        buf.write_string(raw)
        count = count + 1
      }
      None => ()
    }
  }
  buf.to_string()
}

///|
fn keep_reachable(
  order : Array[String],
  merged : Map[String, String],
  asts : Map[String, Expr],
  root_id : String,
) -> Unit {
  match asts.get(root_id) {
    None => ()
    Some(_) => {
      let reachable : Map[String, Bool] = Map([])
      reachable[root_id] = true
      let stack : Array[String] = [root_id]
      while stack.length() > 0 {
        let id = stack[stack.length() - 1]
        ignore(stack.pop())
        match asts.get(id) {
          None => ()
          Some(expr) => {
            let names : Array[String] = []
            collect_refs(expr, names)
            for name in names {
              if reachable.get(name) is None && asts.get(name) is Some(_) {
                reachable[name] = true
                stack.push(name)
              }
            }
          }
        }
      }
      for id in order {
        if id.length() > 0 && id.at(0).to_int() == code('$') {
          reachable[id] = true
        }
      }
      let mut index = order.length() - 1
      while index >= 0 {
        let id = order[index]
        if reachable.get(id) is None {
          ignore(merged.remove(id))
          drop_id(order, id)
        }
        index = index - 1
      }
    }
  }
}

///|
/// Merge `patch` onto `existing`. A `null` statement deletes that name.
/// Statements that `root_id` cannot reach are dropped. `$` names stay.
pub fn merge_statements(
  existing : String,
  patch : String,
  root_id : String,
  has_root~ : Bool = true,
) -> String {
  let existing_stmts = parsed_statements(existing)
  let patch_stmts = parsed_statements(merge_strip_fences(patch))
  if existing_stmts.length() == 0 {
    let raws : Array[String] = []
    for stmt in patch_stmts {
      raws.push(stmt.raw)
    }
    return join_lines(raws)
  }
  if patch_stmts.length() == 0 {
    return existing
  }
  let merged : Map[String, String] = Map([])
  let asts : Map[String, Expr] = Map([])
  let order : Array[String] = []
  for stmt in existing_stmts {
    merged[stmt.id] = stmt.raw
    asts[stmt.id] = stmt.expr
    order.push(stmt.id)
  }
  for stmt in patch_stmts {
    if stmt.expr is Null {
      ignore(merged.remove(stmt.id))
      ignore(asts.remove(stmt.id))
      drop_id(order, stmt.id)
    } else {
      if merged.get(stmt.id) is None {
        order.push(stmt.id)
      }
      merged[stmt.id] = stmt.raw
      asts[stmt.id] = stmt.expr
    }
  }
  if has_root {
    keep_reachable(order, merged, asts, root_id)
  }
  join_raw(order, merged)
}

///|
/// Child order for `walkAST`. The host visits the live node, then these edges.
pub fn walk_plan(kind : String) -> String {
  match kind {
    "Comp" => "[\"args\",\"props\"]"
    "Arr" => "[\"els\"]"
    "Obj" => "[\"entries\"]"
    "BinOp" => "[\"left\",\"right\"]"
    "UnaryOp" => "[\"operand\"]"
    "Ternary" => "[\"cond\",\"then\",\"else\"]"
    "Member" => "[\"obj\"]"
    "Index" => "[\"obj\",\"index\"]"
    "Assign" => "[\"value\"]"
    _ => "[]"
  }
}

///|
/// `1` when `kind` is an OpenUI AST discriminant.
pub fn is_ast_kind(kind : String) -> Int32 {
  match kind {
    "Comp"
    | "Ref"
    | "StateRef"
    | "RuntimeRef"
    | "BinOp"
    | "UnaryOp"
    | "Ternary"
    | "Member"
    | "Index"
    | "Assign"
    | "Str"
    | "Num"
    | "Bool"
    | "Null"
    | "Arr"
    | "Obj"
    | "Ph" => 1
    _ => 0
  }
}

///|
fn cell(items : Array[Json], index : Int32) -> Json {
  if index < items.length() {
    items[index]
  } else {
    Json::null()
  }
}

///|
fn walk_cell_text(items : Array[Json], index : Int32) -> String {
  match cell(items, index) {
    String(text) => text
    _ => ""
  }
}

///|
fn emit_json(value : Json) -> String {
  value.stringify()
}

///|
fn number_tag(tag : Json) -> String {
  match tag {
    Array(items) => {
      let flag = walk_cell_text(items, 0)
      if flag == "n" {
        let repr = match cell(items, 1) {
          Number(number, ..) => number.to_string()
          _ => "0"
        }
        "[\"n\"," + repr + "]"
      } else {
        "[" + Json::string(flag).stringify() + "]"
      }
    }
    _ => "[\"n\",0]"
  }
}

///|
fn tagged_value(value : Json) -> String {
  match value {
    Array(items) => {
      let flag = walk_cell_text(items, 0)
      if flag == "s" || flag == "b" || flag == "z" || flag == "u" || flag == "x" {
        if items.length() == 1 {
          "[" + Json::string(flag).stringify() + "]"
        } else {
          "[" +
          Json::string(flag).stringify() +
          "," +
          emit_json(cell(items, 1)) +
          "]"
        }
      } else if flag == "n" {
        "[" +
        Json::string(flag).stringify() +
        "," +
        number_tag(cell(items, 1)) +
        "]"
      } else {
        "[\"x\"]"
      }
    }
    _ => "[\"x\"]"
  }
}

///|
fn literal_node(value : Json) -> String {
  match value {
    Array(items) => {
      let flag = walk_cell_text(items, 0)
      if flag == "h" {
        "null"
      } else if flag == "s" {
        "[\"Str\"," + emit_json(cell(items, 1)) + "]"
      } else if flag == "n" {
        "[\"Num\"," + number_tag(cell(items, 1)) + "]"
      } else if flag == "b" {
        "[\"Bool\"," + emit_json(cell(items, 1)) + "]"
      } else if flag == "a" {
        let buf = StringBuilder()
        buf.write_string("[\"Arr\",[")
        match cell(items, 1) {
          Array(children) => {
            let mut index = 0
            for child in children {
              if index > 0 {
                buf.write_char(',')
              }
              buf.write_string(literal_node(child))
              index = index + 1
            }
          }
          _ => ()
        }
        buf.write_string("]]")
        buf.to_string()
      } else if flag == "o" {
        let buf = StringBuilder()
        buf.write_string("[\"Obj\",[")
        match cell(items, 1) {
          Array(entries) => {
            let mut index = 0
            for entry in entries {
              if index > 0 {
                buf.write_char(',')
              }
              match entry {
                Array(pair) => {
                  buf.write_char('[')
                  buf.write_string(emit_json(cell(pair, 0)))
                  buf.write_char(',')
                  buf.write_string(literal_node(cell(pair, 1)))
                  buf.write_char(']')
                }
                _ => buf.write_string("[\"\",[\"Null\"]]")
              }
              index = index + 1
            }
          }
          _ => ()
        }
        buf.write_string("]]")
        buf.to_string()
      } else {
        "[\"Null\"]"
      }
    }
    _ => "[\"Null\"]"
  }
}

///|
/// Encode a JavaScript value as a literal AST. Tags use the host's number form.
pub fn to_literal_ast(value_json : String) -> String {
  literal_node(@json.parse(value_json)) catch {
    _ => "[\"Null\"]"
  }
}

///|
fn literal_of(node : Json) -> String? {
  match node {
    Array(items) => {
      let kind = walk_cell_text(items, 0)
      if kind == "Str" || kind == "Num" || kind == "Bool" {
        Some(tagged_value(cell(items, 1)))
      } else if kind == "Null" {
        Some("[\"z\"]")
      } else if kind == "Arr" {
        let buf = StringBuilder()
        buf.write_string("[\"a\",[")
        let mut failed = false
        match cell(items, 1) {
          Array(children) => {
            let mut index = 0
            for child in children {
              match literal_of(child) {
                None => failed = true
                Some(text) => {
                  if index > 0 {
                    buf.write_char(',')
                  }
                  buf.write_string(text)
                  index = index + 1
                }
              }
            }
          }
          _ => failed = true
        }
        buf.write_string("]]")
        if failed {
          None
        } else {
          Some(buf.to_string())
        }
      } else if kind == "Obj" {
        let buf = StringBuilder()
        buf.write_string("[\"o\",[")
        let mut failed = false
        match cell(items, 1) {
          Array(entries) => {
            let mut index = 0
            for entry in entries {
              match entry {
                Array(pair) =>
                  match literal_of(cell(pair, 1)) {
                    None => failed = true
                    Some(text) => {
                      if index > 0 {
                        buf.write_char(',')
                      }
                      buf.write_char('[')
                      buf.write_string(emit_json(cell(pair, 0)))
                      buf.write_char(',')
                      buf.write_string(text)
                      buf.write_char(']')
                      index = index + 1
                    }
                  }
                _ => failed = true
              }
            }
          }
          _ => failed = true
        }
        buf.write_string("]]")
        if failed {
          None
        } else {
          Some(buf.to_string())
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Read a literal AST. `["no"]` means the node is not a literal.
pub fn literal_value(node_json : String) -> String {
  try {
    match literal_of(@json.parse(node_json)) {
      Some(text) => "[\"ok\"," + text + "]"
      None => "[\"no\"]"
    }
  } catch {
    _ => "[\"no\"]"
  }
}

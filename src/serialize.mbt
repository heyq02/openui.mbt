///|
/// Turn an element tree back into OpenUI Lang source.
/// JavaScript tags values and calls `library.toJSONSchema()`; this walk trims
/// optional nulls, collects named statements, and prints calls.
priv struct Collector {
  ids : Array[String]
  texts : Array[String]
}

///|
fn Collector::has(self : Collector, id : String) -> Bool {
  for name in self.ids {
    if name == id {
      return true
    }
  }
  false
}

///|
fn Collector::register(self : Collector, id : String, text : String) -> Unit {
  self.ids.push(id)
  self.texts.push(text)
}

///|
fn join_comma(parts : Array[String]) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for part in parts {
    if index > 0 {
      buf.write_string(", ")
    }
    buf.write_string(part)
    index = index + 1
  }
  buf.to_string()
}

///|
fn json_cell(items : Array[Json], index : Int32) -> Json {
  if index < items.length() {
    items[index]
  } else {
    Json::null()
  }
}

///|
fn tagged_text(value : Json) -> String {
  match value {
    String(text) => text
    _ => ""
  }
}

///|
fn cell_text(items : Array[Json], index : Int32) -> String {
  tagged_text(json_cell(items, index))
}

///|
fn as_pairs(value : Json) -> Array[Json] {
  match value {
    Array(items) => items
    _ => []
  }
}

///|
fn lookup_name(value : Json) -> String? {
  match value {
    String(text) => Some(text)
    _ => None
  }
}

///|
fn find_component(catalog : SchemaCatalog, name : String) -> ComponentDef? {
  for component in catalog.components {
    if component.name == name {
      return Some(component)
    }
  }
  None
}

///|
fn lookup_prop(pairs : Array[Json], name : String) -> Json {
  for pair in pairs {
    match pair {
      Array(cells) =>
        match json_cell(cells, 0) {
          String(key) => if key == name { return json_cell(cells, 1) }
          _ => ()
        }
      _ => ()
    }
  }
  Json::null()
}

///|
fn builtin_call(name : String) -> Bool {
  let names = [
    "Count", "First", "Last", "Sum", "Avg", "Min", "Max", "Sort", "Filter", "Round",
    "Abs", "Floor", "Ceil", "Each", "Run", "ToAssistant", "OpenUrl", "Set", "Reset",
    "Action",
  ]
  for item in names {
    if item == name {
      return true
    }
  }
  false
}

///|
fn schema_call(catalog : SchemaCatalog, name : String) -> Bool {
  for call in catalog.calls {
    if call.name == name {
      return true
    }
  }
  false
}

///|
fn prefix_at(catalog : SchemaCatalog, name : String) -> Bool {
  if name == "Action" {
    return false
  }
  builtin_call(name) || schema_call(catalog, name)
}

///|
fn prec(op : String) -> Int32 {
  let table = [
    ("||", 2),
    ("&&", 3),
    ("==", 4),
    ("!=", 4),
    (">", 5),
    ("<", 5),
    (">=", 5),
    ("<=", 5),
    ("+", 6),
    ("-", 6),
    ("*", 7),
    ("/", 7),
    ("%", 7),
  ]
  for pair in table {
    if pair.0 == op {
      return pair.1
    }
  }
  0
}

///|
fn serialize_value(
  catalog : SchemaCatalog,
  collector : Collector,
  value : Json,
) -> String {
  match value {
    Array(items) =>
      match cell_text(items, 0) {
        "z" | "x" => "null"
        "s" | "n" | "b" => cell_text(items, 1)
        "el" => serialize_element(catalog, collector, items)
        "ast" => serialize_ast(catalog, collector, json_cell(items, 1))
        "a" =>
          "[" +
          join_comma(serialize_list(catalog, collector, json_cell(items, 1))) +
          "]"
        "o" =>
          "{" +
          join_comma(serialize_entries(catalog, collector, json_cell(items, 1))) +
          "}"
        _ => "null"
      }
    _ => "null"
  }
}

///|
fn serialize_list(
  catalog : SchemaCatalog,
  collector : Collector,
  value : Json,
) -> Array[String] {
  let parts : Array[String] = []
  for item in as_pairs(value) {
    parts.push(serialize_value(catalog, collector, item))
  }
  parts
}

///|
fn serialize_entries(
  catalog : SchemaCatalog,
  collector : Collector,
  value : Json,
) -> Array[String] {
  let parts : Array[String] = []
  for pair in as_pairs(value) {
    match pair {
      Array(cells) =>
        parts.push(
          cell_text(cells, 0) +
          ": " +
          serialize_value(catalog, collector, json_cell(cells, 1)),
        )
      _ => ()
    }
  }
  parts
}

///|
fn serialize_element(
  catalog : SchemaCatalog,
  collector : Collector,
  items : Array[Json],
) -> String {
  let id = cell_text(items, 2)
  if id != "" {
    if !collector.has(id) {
      let expr = serialize_call(
        catalog,
        collector,
        Some(cell_text(items, 1)),
        cell_text(items, 1),
        as_pairs(json_cell(items, 3)),
      )
      collector.register(id, id + " = " + expr)
    }
    return id
  }
  serialize_call(
    catalog,
    collector,
    Some(cell_text(items, 1)),
    cell_text(items, 1),
    as_pairs(json_cell(items, 3)),
  )
}

///|
fn serialize_call(
  catalog : SchemaCatalog,
  collector : Collector,
  lookup : String?,
  label : String,
  pairs : Array[Json],
) -> String {
  match lookup {
    Some(name) =>
      match find_component(catalog, name) {
        Some(def) =>
          label +
          "(" +
          join_comma(positional_args(catalog, collector, def, pairs)) +
          ")"
        None => fallback_call(catalog, collector, label, pairs)
      }
    None => fallback_call(catalog, collector, label, pairs)
  }
}

///|
fn positional_args(
  catalog : SchemaCatalog,
  collector : Collector,
  def : ComponentDef,
  pairs : Array[Json],
) -> Array[String] {
  let args : Array[String] = []
  for param in def.params {
    let value = lookup_prop(pairs, param.name)
    args.push(serialize_value(catalog, collector, value))
  }
  while args.length() > 0 {
    let last = args.length() - 1
    if args[last] != "null" || def.params[last].required {
      break
    }
    ignore(args.pop())
  }
  args
}

///|
fn fallback_call(
  catalog : SchemaCatalog,
  collector : Collector,
  label : String,
  pairs : Array[Json],
) -> String {
  let args : Array[String] = []
  for pair in pairs {
    match pair {
      Array(cells) =>
        args.push(serialize_value(catalog, collector, json_cell(cells, 1)))
      _ => ()
    }
  }
  label + "(" + join_comma(args) + ")"
}

///|
fn serialize_ast(
  catalog : SchemaCatalog,
  collector : Collector,
  node : Json,
) -> String {
  match node {
    Array(items) =>
      match cell_text(items, 0) {
        "Str" | "Num" | "Bool" => cell_text(items, 1)
        "Null" | "Other" => "null"
        "Ph" | "Ref" | "StateRef" | "RuntimeRef" => cell_text(items, 1)
        "Arr" =>
          "[" +
          join_comma(serialize_asts(catalog, collector, json_cell(items, 1))) +
          "]"
        "Obj" =>
          "{" +
          join_comma(
            serialize_ast_entries(catalog, collector, json_cell(items, 1)),
          ) +
          "}"
        "BinOp" => serialize_binop(catalog, collector, items)
        "UnaryOp" =>
          cell_text(items, 1) +
          serialize_ast(catalog, collector, json_cell(items, 2))
        "Ternary" =>
          serialize_ast(catalog, collector, json_cell(items, 1)) +
          " ? " +
          serialize_ast(catalog, collector, json_cell(items, 2)) +
          " : " +
          serialize_ast(catalog, collector, json_cell(items, 3))
        "Member" =>
          serialize_ast(catalog, collector, json_cell(items, 1)) +
          "." +
          cell_text(items, 2)
        "Index" =>
          serialize_ast(catalog, collector, json_cell(items, 1)) +
          "[" +
          serialize_ast(catalog, collector, json_cell(items, 2)) +
          "]"
        "Assign" =>
          cell_text(items, 1) +
          " = " +
          serialize_ast(catalog, collector, json_cell(items, 2))
        "Comp" => serialize_comp(catalog, collector, items)
        _ => "null"
      }
    _ => "null"
  }
}

///|
fn serialize_asts(
  catalog : SchemaCatalog,
  collector : Collector,
  value : Json,
) -> Array[String] {
  let parts : Array[String] = []
  for item in as_pairs(value) {
    parts.push(serialize_ast(catalog, collector, item))
  }
  parts
}

///|
fn serialize_ast_entries(
  catalog : SchemaCatalog,
  collector : Collector,
  value : Json,
) -> Array[String] {
  let parts : Array[String] = []
  for pair in as_pairs(value) {
    match pair {
      Array(cells) =>
        parts.push(
          cell_text(cells, 0) +
          ": " +
          serialize_ast(catalog, collector, json_cell(cells, 1)),
        )
      _ => ()
    }
  }
  parts
}

///|
fn serialize_binop(
  catalog : SchemaCatalog,
  collector : Collector,
  items : Array[Json],
) -> String {
  let op = cell_text(items, 1)
  let left = serialize_binop_child(catalog, collector, json_cell(items, 2), op)
  let right = serialize_binop_child(catalog, collector, json_cell(items, 3), op)
  left + " " + op + " " + right
}

///|
fn serialize_binop_child(
  catalog : SchemaCatalog,
  collector : Collector,
  child : Json,
  parent_op : String,
) -> String {
  let inner = serialize_ast(catalog, collector, child)
  match child {
    Array(items) =>
      if cell_text(items, 0) == "BinOp" &&
        prec(cell_text(items, 1)) < prec(parent_op) {
        return "(" + inner + ")"
      }
    _ => ()
  }
  inner
}

///|
fn serialize_comp(
  catalog : SchemaCatalog,
  collector : Collector,
  items : Array[Json],
) -> String {
  let name = cell_text(items, 1)
  let args = join_comma(serialize_asts(catalog, collector, json_cell(items, 2)))
  if prefix_at(catalog, name) {
    "@" + name + "(" + args + ")"
  } else {
    name + "(" + args + ")"
  }
}

///|
fn append_state(
  lines : Array[String],
  catalog : SchemaCatalog,
  collector : Collector,
  state : Json,
) -> Unit {
  match state {
    Array(entries) =>
      for entry in entries {
        match entry {
          Array(cells) =>
            if cells.length() >= 2 {
              match cells[1] {
                Array(tag) =>
                  if cell_text(tag, 0) != "skip" {
                    lines.push(
                      tagged_text(cells[0]) +
                      " = " +
                      serialize_value(catalog, collector, cells[1]),
                    )
                  }
                _ =>
                  lines.push(
                    tagged_text(cells[0]) +
                    " = " +
                    serialize_value(catalog, collector, cells[1]),
                  )
              }
            }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn render_openui(catalog : SchemaCatalog, root : Json, state : Json) -> String {
  match root {
    Array(items) => {
      let collector = { ids: [], texts: [], }
      let expr = serialize_call(
        catalog,
        collector,
        lookup_name(json_cell(items, 1)),
        cell_text(items, 2),
        as_pairs(json_cell(items, 4)),
      )
      let id = cell_text(items, 3)
      let root_id = if id == "" { "root" } else { id }
      let lines = [root_id + " = " + expr]
      let mut index = 0
      while index < collector.texts.length() {
        if collector.ids[index] != root_id {
          lines.push(collector.texts[index])
        }
        index = index + 1
      }
      append_state(lines, catalog, collector, state)
      join_lines(lines)
    }
    _ => ""
  }
}

///|
/// `root_json` and `state_json` are tagged values. `state_json` of `null` omits state.
pub fn json_to_openui(
  schema_json : String,
  root_json : String,
  state_json : String,
) -> String {
  let catalog = compile_schema(schema_json)
  try {
    let root = @json.parse(root_json)
    let state = if state_json == "null" || state_json == "" {
      Json::null()
    } else {
      @json.parse(state_json)
    }
    render_openui(catalog, root, state)
  } catch {
    _ => ""
  }
}

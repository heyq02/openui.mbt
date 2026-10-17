///|
/// Result of checking one value against a nested schema.
priv enum Outcome {
  Keep(Val)
  Bad
}

///|
fn node_default(node : SchemaNode) -> JsonLit {
  match node {
    Leaf(_, _, lit) => lit
    _ => Absent
  }
}

///|
fn lit_val(lit : JsonLit) -> Val? {
  match lit {
    Absent => None
    Boolean(flag) => Some(Boolean(flag))
    Num(number, repr) => Some(Num(number, repr))
    Str(text) => Some(Str(text))
  }
}

///|
fn value_kind(value : Val) -> String {
  match value {
    Null => "null"
    Boolean(_) => "boolean"
    Num(_) => "number"
    Str(_) => "string"
    Arr(_) => "array"
    Obj(_) => "object"
    Element(name, _, _, _, _) => "component \"" + name + "\""
    Runtime(_) => "value"
  }
}

///|
fn report_mismatch(
  mat : Mat,
  component : String,
  path : String,
  expected : String,
  actual : String,
  line : Int32,
) -> Outcome {
  push_issue(
    mat,
    "type-mismatch",
    component,
    path,
    "field \"" + path + "\" expects " + expected + " but got " + actual,
    line,
  )
  Bad
}

///|
fn report_required(
  mat : Mat,
  component : String,
  path : String,
  code : String,
  line : Int32,
) -> Unit {
  let message = if code == "null-required" {
    "required field \"" + path + "\" cannot be null"
  } else {
    "missing required field \"" + path + "\""
  }
  push_issue(mat, code, component, path, message, line)
}

///|
fn field_get(fields : Array[(String, Val)], key : String) -> Val? {
  for field in fields {
    let (name, value) = field
    if name == key {
      return Some(value)
    }
  }
  None
}

///|
fn field_set(
  fields : Array[(String, Val)],
  key : String,
  value : Val,
) -> Array[(String, Val)] {
  let next : Array[(String, Val)] = []
  let mut found = false
  for field in fields {
    let (name, current) = field
    if name == key {
      next.push((key, value))
      found = true
    } else {
      next.push((name, current))
    }
  }
  if !found {
    next.push((key, value))
  }
  next
}

///|
fn field_delete(
  fields : Array[(String, Val)],
  key : String,
) -> Array[(String, Val)] {
  let next : Array[(String, Val)] = []
  for field in fields {
    let (name, value) = field
    if name != key {
      next.push((name, value))
    }
  }
  next
}

///|
fn prop_node(props : Array[(String, SchemaNode)], key : String) -> SchemaNode {
  for prop in props {
    let (name, node) = prop
    if name == key {
      return node
    }
  }
  Open
}

///|
fn enum_expected(items : Array[String]) -> String {
  "one of [" + join_labels(items, ", ") + "]"
}

///|
fn refine_leaf(
  mat : Mat,
  component : String,
  path : String,
  kind : String,
  enums : Array[String]?,
  value : Val,
  line : Int32,
) -> Outcome {
  match value {
    Element(name, _, _, _, _) =>
      report_mismatch(
        mat,
        component,
        path,
        if kind == "" {
          "a literal value"
        } else {
          kind
        },
        "component \"" + name + "\"",
        line,
      )
    _ =>
      match enums {
        Some(items) =>
          if mat.partial {
            Keep(value)
          } else {
            match literal_display(value) {
              None => Keep(value)
              Some(text) =>
                if list_has(items, text) {
                  Keep(value)
                } else {
                  report_mismatch(
                    mat,
                    component,
                    path,
                    enum_expected(items),
                    text,
                    line,
                  )
                }
            }
          }
        None =>
          if kind == "" || value_kind(value) == kind {
            Keep(value)
          } else {
            report_mismatch(mat, component, path, kind, value_kind(value), line)
          }
      }
  }
}

///|
fn refine_object(
  mat : Mat,
  component : String,
  path : String,
  props : Array[(String, SchemaNode)],
  required : Array[String],
  value : Val,
  line : Int32,
) -> Outcome {
  match value {
    Element(name, _, _, _, _) =>
      report_mismatch(
        mat,
        component,
        path,
        "object",
        "component \"" + name + "\"",
        line,
      )
    Obj(fields) => {
      let mut next = fields
      let mut invalid = false
      if !mat.partial {
        for key in required {
          let child = path + "/" + key
          let node = prop_node(props, key)
          match field_get(next, key) {
            None =>
              match lit_val(node_default(node)) {
                Some(fallback) => next = field_set(next, key, fallback)
                None => {
                  report_required(
                    mat, component, child, "missing-required", line,
                  )
                  invalid = true
                }
              }
            Some(Null) =>
              match lit_val(node_default(node)) {
                Some(fallback) => next = field_set(next, key, fallback)
                None => {
                  report_required(mat, component, child, "null-required", line)
                  invalid = true
                }
              }
            Some(_) => ()
          }
        }
      }
      for prop in props {
        let (key, node) = prop
        match field_get(next, key) {
          None => ()
          Some(current) =>
            match
              refine(mat, component, path + "/" + key, node, current, line) {
              Keep(checked) =>
                if !same_value(current, checked) {
                  next = field_set(next, key, checked)
                }
              Bad =>
                match lit_val(node_default(node)) {
                  Some(fallback) => next = field_set(next, key, fallback)
                  None =>
                    if list_has(required, key) {
                      invalid = true
                    } else {
                      next = field_delete(next, key)
                    }
                }
            }
        }
      }
      if invalid {
        Bad
      } else if same_fields(fields, next) {
        Keep(value)
      } else {
        Keep(Obj(next))
      }
    }
    _ =>
      report_mismatch(mat, component, path, "object", value_kind(value), line)
  }
}

///|
fn same_value(left : Val, right : Val) -> Bool {
  match (left, right) {
    (Null, Null) => true
    (Boolean(a), Boolean(b)) => a == b
    (Num(_, a), Num(_, b)) => a == b
    (Str(a), Str(b)) => a == b
    (Arr(a), Arr(b)) => same_items(a, b)
    (Obj(a), Obj(b)) => same_fields(a, b)
    (Element(a, b, c, d, e), Element(f, g, h, i, j)) =>
      a == f && b == g && d == i && e == j && same_fields(c, h)
    (Runtime(_), Runtime(_)) => false
    _ => false
  }
}

///|
fn same_items(left : Array[Val], right : Array[Val]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  let mut index = 0
  while index < left.length() {
    if !same_value(left[index], right[index]) {
      return false
    }
    index = index + 1
  }
  true
}

///|
fn same_fields(
  left : Array[(String, Val)],
  right : Array[(String, Val)],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  let mut index = 0
  while index < left.length() {
    let (lname, lvalue) = left[index]
    let (rname, rvalue) = right[index]
    if lname != rname || !same_value(lvalue, rvalue) {
      return false
    }
    index = index + 1
  }
  true
}

///|
fn refine_array(
  mat : Mat,
  component : String,
  path : String,
  item : SchemaNode,
  value : Val,
  line : Int32,
) -> Outcome {
  match value {
    Element(name, _, _, _, _) =>
      report_mismatch(
        mat,
        component,
        path,
        "array",
        "component \"" + name + "\"",
        line,
      )
    Arr(items) =>
      match item {
        Open => Keep(value)
        _ => {
          let kept : Array[Val] = []
          let mut changed = false
          let mut index = 0
          for entry in items {
            match
              refine(
                mat,
                component,
                path + "/" + index.to_string(),
                item,
                entry,
                line,
              ) {
              Keep(next) => {
                kept.push(next)
                if !same_value(entry, next) {
                  changed = true
                }
              }
              Bad => changed = true
            }
            index = index + 1
          }
          if changed {
            Keep(Arr(kept))
          } else {
            Keep(value)
          }
        }
      }
    _ => report_mismatch(mat, component, path, "array", value_kind(value), line)
  }
}

///|
fn slot_open(mat : Mat, names : Array[String]) -> Bool {
  if names.length() == 0 {
    return true
  }
  for name in names {
    if component_params(mat.catalog, name) is None {
      return true
    }
  }
  false
}

///|
fn slot_actual(value : Val) -> String {
  match value {
    Obj(_) => "plain object"
    Arr(_) => "array"
    Str(_) => "string"
    Num(_) => "number"
    Boolean(_) => "boolean"
    Null => "null"
    Element(name, _, _, _, _) => "component \"" + name + "\""
    Runtime(_) => "value"
  }
}

///|
fn refine_slot(
  mat : Mat,
  component : String,
  path : String,
  names : Array[String],
  value : Val,
  line : Int32,
) -> Outcome {
  if slot_open(mat, names) {
    Keep(value)
  } else {
    match value {
      Element(_) | Runtime(_) => Keep(value)
      _ =>
        report_mismatch(
          mat,
          component,
          path,
          join_labels(names, " | "),
          slot_actual(value),
          line,
        )
    }
  }
}

///|
fn refine(
  mat : Mat,
  component : String,
  path : String,
  node : SchemaNode,
  value : Val,
  line : Int32,
) -> Outcome {
  match value {
    Null | Runtime(_) => Keep(value)
    _ =>
      match node {
        Open => Keep(value)
        Leaf(kind, enums, _) =>
          refine_leaf(mat, component, path, kind, enums, value, line)
        Fields(props, required) =>
          refine_object(mat, component, path, props, required, value, line)
        Items(item) => refine_array(mat, component, path, item, value, line)
        Slot(names) => refine_slot(mat, component, path, names, value, line)
      }
  }
}

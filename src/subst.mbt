///|
priv enum SubstWalk {
  Held(Json)
  Stop(String)
}

///|
priv enum SubstFind {
  FindHit(Json)
  FindMiss
  FindBad(String)
}

///|
fn subst_undef() -> Json {
  object_of([("t", Json::string("u"))])
}

///|
fn subst_obj(entries : Array[Json]) -> Json {
  object_of([("t", Json::string("o")), ("v", Json::array(entries))])
}

///|
fn subst_list(items : Array[Json]) -> Json {
  object_of([("t", Json::string("a")), ("v", Json::array(items))])
}

///|
fn subst_str(text : String) -> Json {
  object_of([("t", Json::string("s")), ("v", Json::string(text))])
}

///|
fn subst_field(node : Json, key : String) -> Json? {
  for item in builtin_items(node) {
    match item {
      Array(cells) =>
        if cells.length() >= 2 {
          match cells[0] {
            String(text) => if text == key { return Some(cells[1]) }
            _ => ()
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn subst_kind(node : Json) -> String? {
  if builtin_tag(node) != "o" {
    return None
  }
  match subst_field(node, "k") {
    Some(field) =>
      if builtin_tag(field) == "s" {
        let kind = builtin_string(field)
        if is_ast_kind(kind) == 1 {
          Some(kind)
        } else {
          None
        }
      } else {
        None
      }
    None => None
  }
}

///|
fn subst_repr(value : Json) -> String {
  match value {
    Number(number, ..) => number.to_string()
    _ => "0"
  }
}

///|
fn subst_num(value : Json) -> Double {
  match builtin_field(value, "v") {
    Some(Number(number, ..)) => number
    _ => 0.0
  }
}

///|
fn subst_is_zero(value : Json) -> Bool {
  subst_num(value) == 0.0
}

///|
fn subst_bool(value : Json) -> Bool {
  match builtin_field(value, "v") {
    Some(True) => true
    _ => false
  }
}

///|
fn subst_id(value : Json) -> Double {
  match builtin_field(value, "i") {
    Some(Number(number, ..)) => number
    _ => -1.0
  }
}

///|
/// JavaScript `===` for tagged scalars. Objects compare by identity, so two trees never match.
fn subst_same(left : Json, right : Json) -> Bool {
  let left_tag = builtin_tag(left)
  let right_tag = builtin_tag(right)
  if left_tag == "n0" &&
    (right_tag == "n0" || (right_tag == "n" && subst_is_zero(right))) {
    return true
  }
  if right_tag == "n0" && left_tag == "n" && subst_is_zero(left) {
    return true
  }
  if left_tag != right_tag {
    return false
  }
  if left_tag == "s" {
    builtin_string(left) == builtin_string(right)
  } else if left_tag == "b" {
    subst_bool(left) == subst_bool(right)
  } else if left_tag == "n" {
    subst_num(left) == subst_num(right)
  } else if left_tag == "x" {
    subst_id(left) == subst_id(right)
  } else if left_tag == "z" ||
    left_tag == "u" ||
    left_tag == "inf" ||
    left_tag == "-inf" {
    true
  } else {
    false
  }
}

///|
fn subst_number_text(value : Json) -> String {
  let tag = builtin_tag(value)
  if tag == "nan" {
    "NaN"
  } else if tag == "inf" {
    "Infinity"
  } else if tag == "-inf" {
    "-Infinity"
  } else if tag == "n0" {
    "0"
  } else {
    match builtin_field(value, "v") {
      Some(Number(number, ..)) => number.to_string()
      _ => "0"
    }
  }
}

///|
fn subst_iter(value : Json) -> String {
  let tag = builtin_tag(value)
  let label = if tag == "u" {
    "undefined"
  } else if tag == "z" {
    "object null"
  } else if tag == "n" ||
    tag == "n0" ||
    tag == "nan" ||
    tag == "inf" ||
    tag == "-inf" {
    "number " + subst_number_text(value)
  } else if tag == "b" {
    if subst_bool(value) {
      "boolean true"
    } else {
      "boolean false"
    }
  } else if tag == "x" {
    match builtin_field(value, "j") {
      Some(String(text)) => text
      _ => "object"
    }
  } else {
    "object"
  }
  "iter:" + label
}

///|
fn subst_truthy(value : Json) -> Bool {
  let tag = builtin_tag(value)
  if tag == "u" || tag == "z" || tag == "n0" || tag == "nan" || tag == "h" {
    false
  } else if tag == "b" {
    subst_bool(value)
  } else if tag == "s" {
    builtin_string(value).length() > 0
  } else if tag == "n" {
    !subst_is_zero(value)
  } else {
    true
  }
}

///|
fn subst_cell(cells : Array[Json], index : Int32) -> Json {
  if index < cells.length() {
    let item = cells[index]
    if builtin_tag(item) == "h" {
      subst_undef()
    } else {
      item
    }
  } else {
    subst_undef()
  }
}

///|
fn subst_assign(node : Json, key : String, value : Json) -> Json {
  let next : Array[Json] = []
  let mut found = false
  for item in builtin_items(node) {
    match item {
      Array(cells) =>
        if cells.length() >= 1 {
          match cells[0] {
            String(text) =>
              if text == key && !found {
                found = true
                next.push(Json::array([Json::string(text), value]))
              } else {
                next.push(item)
              }
            _ => next.push(item)
          }
        } else {
          next.push(item)
        }
      _ => next.push(item)
    }
  }
  if !found {
    next.push(Json::array([Json::string(key), value]))
  }
  subst_obj(next)
}

///|
fn emit_items(items : Array[Json], pairs : Bool) -> String {
  let buf = StringBuilder()
  buf.write_char('[')
  let mut index = 0
  for item in items {
    if index > 0 {
      buf.write_char(',')
    }
    if pairs {
      match item {
        Array(cells) => {
          buf.write_char('[')
          if cells.length() > 0 {
            match cells[0] {
              String(text) => buf.write_string(json_string(text))
              _ => buf.write_string(emit_tag(cells[0]))
            }
          }
          if cells.length() > 1 {
            buf.write_char(',')
            buf.write_string(emit_tag(cells[1]))
          }
          buf.write_char(']')
        }
        _ => buf.write_string("null")
      }
    } else {
      buf.write_string(emit_tag(item))
    }
    index = index + 1
  }
  buf.write_char(']')
  buf.to_string()
}

///|
fn emit_tag(value : Json) -> String {
  let tag = builtin_tag(value)
  if tag == "s" {
    "{\"t\":\"s\",\"v\":" + json_string(builtin_string(value)) + "}"
  } else if tag == "n" {
    "{\"t\":\"n\",\"v\":" +
    subst_repr(builtin_field(value, "v").unwrap_or(Json::null())) +
    "}"
  } else if tag == "b" {
    if subst_bool(value) {
      "{\"t\":\"b\",\"v\":true}"
    } else {
      "{\"t\":\"b\",\"v\":false}"
    }
  } else if tag == "a" {
    "{\"t\":\"a\",\"v\":" + emit_items(builtin_items(value), false) + "}"
  } else if tag == "o" {
    "{\"t\":\"o\",\"v\":" + emit_items(builtin_items(value), true) + "}"
  } else if tag == "x" {
    "{\"t\":\"x\",\"i\":" +
    subst_repr(builtin_field(value, "i").unwrap_or(Json::null())) +
    "}"
  } else if tag == "" {
    "null"
  } else {
    "{\"t\":" + json_string(tag) + "}"
  }
}

///|
fn subst_walk(node : Json, name : Json, literal : Json) -> SubstWalk {
  let tag = builtin_tag(node)
  if tag == "u" {
    return Stop("undef")
  }
  if tag == "z" {
    return Stop("null")
  }
  if tag != "o" {
    return Held(node)
  }
  match subst_kind(node) {
    None => Held(node)
    Some(kind) => subst_kind_walk(node, kind, name, literal)
  }
}

///|
fn subst_kind_walk(
  node : Json,
  kind : String,
  name : Json,
  literal : Json,
) -> SubstWalk {
  if kind == "Ref" {
    subst_ref(node, name, literal)
  } else if kind == "Member" {
    subst_member(node, name, literal)
  } else if kind == "Index" {
    subst_index(node, name, literal)
  } else if kind == "BinOp" {
    subst_children(node, ["left", "right"], name, literal)
  } else if kind == "UnaryOp" {
    subst_children(node, ["operand"], name, literal)
  } else if kind == "Ternary" {
    subst_children(node, ["cond", "then", "else"], name, literal)
  } else if kind == "Assign" {
    subst_children(node, ["value"], name, literal)
  } else if kind == "Arr" {
    subst_sequence(node, "els", false, name, literal)
  } else if kind == "Obj" {
    subst_sequence(node, "entries", true, name, literal)
  } else if kind == "Comp" {
    subst_comp(node, name, literal)
  } else {
    Held(node)
  }
}

///|
fn subst_ref(node : Json, name : Json, literal : Json) -> SubstWalk {
  let field = match subst_field(node, "n") {
    Some(value) => value
    None => subst_undef()
  }
  if subst_same(field, name) {
    Held(literal)
  } else {
    Held(node)
  }
}

///|
fn subst_member(node : Json, name : Json, literal : Json) -> SubstWalk {
  match subst_field(node, "obj") {
    None => Held(node)
    Some(obj) =>
      if subst_kind(obj) is None {
        Held(node)
      } else {
        match subst_walk(obj, name, literal) {
          Stop(why) => Stop(why)
          Held(sub) =>
            if subst_kind(sub) is Some("Obj") {
              let field = match subst_field(node, "field") {
                Some(value) => value
                None => subst_undef()
              }
              match subst_find(sub, field) {
                FindHit(value) => Held(value)
                FindMiss => Held(subst_assign(node, "obj", sub))
                FindBad(why) => Stop(why)
              }
            } else {
              Held(subst_assign(node, "obj", sub))
            }
        }
      }
  }
}

///|
fn subst_find(obj : Json, field : Json) -> SubstFind {
  match subst_field(obj, "entries") {
    None => FindBad("find")
    Some(entries) =>
      if builtin_tag(entries) == "u" {
        FindBad("find")
      } else if builtin_tag(entries) == "z" {
        FindBad("find-null")
      } else if builtin_tag(entries) != "a" {
        FindBad("find-fn")
      } else {
        let mut found : SubstFind = FindMiss
        for item in builtin_items(entries) {
          if found is FindMiss && builtin_tag(item) != "h" {
            if builtin_tag(item) == "s" {
              let text = builtin_string(item)
              let key = if text.length() == 0 {
                subst_undef()
              } else {
                subst_str(copy_units(text, 0, 1))
              }
              if subst_same(key, field) {
                if text.length() < 2 {
                  found = FindHit(subst_undef())
                } else {
                  found = FindHit(subst_str(copy_units(text, 1, 2)))
                }
              }
            } else if builtin_tag(item) != "a" {
              found = FindBad(subst_iter(item))
            } else {
              let cells = builtin_items(item)
              if subst_same(subst_cell(cells, 0), field) {
                found = FindHit(subst_cell(cells, 1))
              }
            }
          }
        }
        found
      }
  }
}

///|
fn subst_optional(
  node : Json,
  key : String,
  name : Json,
  literal : Json,
) -> SubstWalk {
  let child = match subst_field(node, key) {
    Some(value) => value
    None => subst_undef()
  }
  if subst_kind(child) is Some(_) {
    match subst_walk(child, name, literal) {
      Stop(why) => Stop(why)
      Held(next) => Held(subst_assign(node, key, next))
    }
  } else {
    Held(subst_assign(node, key, child))
  }
}

///|
fn subst_index(node : Json, name : Json, literal : Json) -> SubstWalk {
  match subst_optional(node, "obj", name, literal) {
    Stop(why) => Stop(why)
    Held(next) => subst_optional(next, "index", name, literal)
  }
}

///|
fn subst_children(
  node : Json,
  keys : Array[String],
  name : Json,
  literal : Json,
) -> SubstWalk {
  let mut current = node
  for key in keys {
    match subst_field(current, key) {
      None => return Stop("undef")
      Some(child) =>
        match subst_walk(child, name, literal) {
          Stop(why) => return Stop(why)
          Held(next) => current = subst_assign(current, key, next)
        }
    }
  }
  Held(current)
}

///|
fn subst_mapped_list(
  list : Json,
  pairs : Bool,
  name : Json,
  literal : Json,
) -> SubstWalk {
  let next : Array[Json] = []
  for item in builtin_items(list) {
    if builtin_tag(item) == "h" {
      next.push(item)
    } else if pairs && builtin_tag(item) == "s" {
      let text = builtin_string(item)
      if text.length() < 2 {
        return Stop("undef")
      }
      next.push(
        subst_list([
          subst_str(copy_units(text, 0, 1)),
          subst_str(copy_units(text, 1, 2)),
        ]),
      )
    } else if pairs && builtin_tag(item) != "a" {
      return Stop(subst_iter(item))
    } else if pairs {
      let cells = builtin_items(item)
      match subst_walk(subst_cell(cells, 1), name, literal) {
        Stop(why) => return Stop(why)
        Held(value) => next.push(subst_list([subst_cell(cells, 0), value]))
      }
    } else {
      match subst_walk(item, name, literal) {
        Stop(why) => return Stop(why)
        Held(value) => next.push(value)
      }
    }
  }
  Held(subst_list(next))
}

///|
fn subst_sequence(
  node : Json,
  key : String,
  pairs : Bool,
  name : Json,
  literal : Json,
) -> SubstWalk {
  match subst_field(node, key) {
    None => Stop("map")
    Some(list) =>
      if builtin_tag(list) == "u" {
        Stop("map")
      } else if builtin_tag(list) == "z" {
        Stop("map-null")
      } else if builtin_tag(list) != "a" {
        Stop("map-fn")
      } else {
        match subst_mapped_list(list, pairs, name, literal) {
          Stop(why) => Stop(why)
          Held(next) => Held(subst_assign(node, key, next))
        }
      }
  }
}

///|
fn subst_map_values(record : Json, name : Json, literal : Json) -> SubstWalk {
  let tag = builtin_tag(record)
  if tag == "o" {
    let out : Array[Json] = []
    for item in builtin_items(record) {
      match item {
        Array(cells) =>
          if cells.length() >= 2 {
            match cells[0] {
              String(key) =>
                match subst_walk(cells[1], name, literal) {
                  Stop(why) => return Stop(why)
                  Held(next) => out.push(Json::array([Json::string(key), next]))
                }
              _ => return Stop(subst_iter(cells[0]))
            }
          } else {
            return Stop("undef")
          }
        _ => return Stop(subst_iter(item))
      }
    }
    Held(subst_obj(out))
  } else if tag == "a" {
    let out : Array[Json] = []
    let mut index = 0
    for item in builtin_items(record) {
      if builtin_tag(item) != "h" {
        match subst_walk(item, name, literal) {
          Stop(why) => return Stop(why)
          Held(next) =>
            out.push(Json::array([Json::string(index.to_string()), next]))
        }
      }
      index = index + 1
    }
    Held(subst_obj(out))
  } else if tag == "s" {
    let text = builtin_string(record)
    let out : Array[Json] = []
    let mut index = 0
    while index < text.length() {
      let ch = copy_units(text, index, index + 1)
      out.push(Json::array([Json::string(index.to_string()), subst_str(ch)]))
      index = index + 1
    }
    Held(subst_obj(out))
  } else {
    Held(subst_obj([]))
  }
}

///|
fn subst_comp(node : Json, name : Json, literal : Json) -> SubstWalk {
  match subst_sequence(node, "args", false, name, literal) {
    Stop(why) => Stop(why)
    Held(result) =>
      match subst_field(node, "mappedProps") {
        None => Held(result)
        Some(props) =>
          if subst_truthy(props) {
            match subst_map_values(props, name, literal) {
              Stop(why) => Stop(why)
              Held(mapped) => Held(subst_assign(result, "mappedProps", mapped))
            }
          } else {
            Held(result)
          }
      }
  }
}

///|
fn subst_stop(why : String) -> String {
  if host_starts_with(why, "iter:") {
    let label = copy_units(why, 5, why.length())
    "{\"t\":\"throw\",\"why\":\"iter\",\"j\":" + json_string(label) + "}"
  } else {
    "{\"t\":\"throw\",\"why\":" + json_string(why) + "}"
  }
}

///|
/// Replace `Ref` nodes whose name is `===` to `var_name_json`. `literal_json` is the encoded replacement.
pub fn substitute_ref(
  node_json : String,
  var_name_json : String,
  literal_json : String,
) -> String {
  try {
    let node = @json.parse(node_json)
    let name = @json.parse(var_name_json)
    let literal = @json.parse(literal_json)
    match subst_walk(node, name, literal) {
      Held(value) => emit_tag(value)
      Stop(why) => subst_stop(why)
    }
  } catch {
    _ => "{\"t\":\"z\"}"
  }
}

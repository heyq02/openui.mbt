///|
/// Stable JSON for query cache keys. The host applies `toJSON`, sorts reads, and reports cycles.
priv enum Stable {
  Text(String)
  Omit
  Big
}

///|
fn stable_kind(value : Json) -> String {
  match value {
    Object(map) =>
      match map.get("t") {
        Some(String(text)) => text
        _ => ""
      }
    _ => ""
  }
}

///|
fn stable_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn stable_items(value : Json) -> Array[Json] {
  match stable_field(value, "v") {
    Some(Array(items)) => items
    _ => []
  }
}

///|
fn stable_join(parts : Array[String]) -> String {
  let buf = StringBuilder()
  let mut first = true
  for part in parts {
    if !first {
      buf.write_char(',')
    }
    first = false
    buf.write_string(part)
  }
  buf.to_string()
}

///|
fn utf16_before(left : String, right : String) -> Bool {
  let mut index : Int32 = 0
  let left_len = left.length()
  let right_len = right.length()
  while index < left_len && index < right_len {
    let left_unit = left.at(index).to_int()
    let right_unit = right.at(index).to_int()
    if left_unit != right_unit {
      return left_unit < right_unit
    }
    index = index + 1
  }
  left_len < right_len
}

///|
fn pairs_of(value : Json) -> Array[(String, Json)] {
  let pairs = []
  for item in stable_items(value) {
    match item {
      Array(cells) =>
        if cells.length() >= 2 {
          match cells[0] {
            String(key) => pairs.push((key, cells[1]))
            _ => ()
          }
        }
      _ => ()
    }
  }
  pairs
}

///|
fn is_array_index(key : String) -> Bool {
  let len = key.length()
  if len == 0 {
    return false
  }
  let first = key.at(0).to_int()
  if first == 48 {
    return len == 1
  }
  if first < 49 || first > 57 {
    return false
  }
  let mut index : Int32 = 1
  while index < len {
    let unit = key.at(index).to_int()
    if unit < 48 || unit > 57 {
      return false
    }
    index = index + 1
  }
  if len > 10 {
    return false
  }
  if len < 10 {
    return true
  }
  utf16_before(key, "4294967295")
}

///|
fn index_before(left : String, right : String) -> Bool {
  let left_len = left.length()
  let right_len = right.length()
  if left_len != right_len {
    return left_len < right_len
  }
  utf16_before(left, right)
}

///|
fn key_before(left : String, right : String) -> Bool {
  let left_index = is_array_index(left)
  let right_index = is_array_index(right)
  if left_index && right_index {
    return index_before(left, right)
  }
  if left_index != right_index {
    return left_index
  }
  utf16_before(left, right)
}

///|
fn insert_sorted(
  sorted : Array[(String, Json)],
  pair : (String, Json),
) -> Array[(String, Json)] {
  let (key, _) = pair
  let next = []
  let mut placed = false
  for item in sorted {
    let (item_key, _) = item
    if !placed && key_before(key, item_key) {
      next.push(pair)
      placed = true
    }
    next.push(item)
  }
  if !placed {
    next.push(pair)
  }
  next
}

///|
fn quoted(text : String) -> String {
  Json::string(text).stringify()
}

///|
fn emit_number(value : Json) -> String {
  match stable_field(value, "v") {
    Some(Number(number, ..)) => Json::number(number).stringify()
    _ => "0"
  }
}

///|
fn emit_bool(value : Json) -> String {
  match stable_field(value, "v") {
    Some(True) => "true"
    _ => "false"
  }
}

///|
fn emit_string(value : Json) -> String {
  match stable_field(value, "v") {
    Some(String(text)) => quoted(text)
    _ => "\"\""
  }
}

///|
fn emit(value : Json) -> Stable {
  let kind = stable_kind(value)
  if kind == "s" {
    return Text(emit_string(value))
  }
  if kind == "n" {
    return Text(emit_number(value))
  }
  if kind == "b" {
    return Text(emit_bool(value))
  }
  if kind == "z" {
    return Text("null")
  }
  if kind == "u" {
    return Text(quoted("__undefined__"))
  }
  if kind == "nan" {
    return Text(quoted("__NaN__"))
  }
  if kind == "pinf" {
    return Text(quoted("__Inf__"))
  }
  if kind == "ninf" {
    return Text(quoted("__-Inf__"))
  }
  if kind == "big" {
    return Big
  }
  if kind == "a" {
    let parts = []
    for item in stable_items(value) {
      match emit(item) {
        Text(text) => parts.push(text)
        Omit => parts.push("null")
        Big => return Big
      }
    }
    return Text("[" + stable_join(parts) + "]")
  }
  if kind == "o" {
    let mut sorted = []
    for pair in pairs_of(value) {
      sorted = insert_sorted(sorted, pair)
    }
    let parts = []
    for pair in sorted {
      let (key, child) = pair
      match emit(child) {
        Text(text) => parts.push(quoted(key) + ":" + text)
        Omit => ()
        Big => return Big
      }
    }
    return Text("{" + stable_join(parts) + "}")
  }
  Omit
}

///|
/// JSON text with sorted object keys. `U` means the root is omitted. `Ebigint` asks the host to throw.
pub fn stable_stringify(value_json : String) -> String {
  try {
    match emit(@json.parse(value_json)) {
      Text(text) => "S" + text
      Omit => "U"
      Big => "Ebigint"
    }
  } catch {
    _ => "Eparse"
  }
}

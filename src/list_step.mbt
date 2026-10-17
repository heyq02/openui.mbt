///|
/// `Sort` and `Filter` choices. The host still calls `localeCompare`, `==`, and `toNumber`.
fn list_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn list_flag(value : Json, key : String) -> Bool {
  match list_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn list_text(value : Json, key : String) -> String {
  match list_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn list_sign(desc : Bool) -> String {
  if desc {
    "-1"
  } else {
    "1"
  }
}

///|
fn list_cmp(op : String) -> String {
  if op == "==" {
    "{\"op\":\"eq\"}"
  } else if op == "!=" {
    "{\"op\":\"ne\"}"
  } else if op == ">" {
    "{\"op\":\"gt\"}"
  } else if op == "<" {
    "{\"op\":\"lt\"}"
  } else if op == ">=" {
    "{\"op\":\"ge\"}"
  } else if op == "<=" {
    "{\"op\":\"le\"}"
  } else if op == "contains" {
    "{\"op\":\"has\"}"
  } else {
    "{\"op\":\"no\"}"
  }
}

///|
/// `sort` copies the array. `same` returns it. `empty` is a non-array filter.
pub fn list_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match list_text(payload, "phase") {
      "open" => {
        let kind = list_text(payload, "kind")
        let array = list_flag(payload, "array")
        if kind == "sort" && array {
          "{\"op\":\"sort\"}"
        } else if kind == "sort" {
          "{\"op\":\"same\"}"
        } else if kind == "filter" && array {
          "{\"op\":\"filter\"}"
        } else if kind == "filter" {
          "{\"op\":\"empty\"}"
        } else {
          "{\"op\":\"same\"}"
        }
      }
      "pair" => {
        let sign = list_sign(list_flag(payload, "desc"))
        if list_flag(payload, "numeric") {
          "{\"op\":\"num\",\"sign\":" + sign + "}"
        } else {
          "{\"op\":\"text\",\"sign\":" + sign + "}"
        }
      }
      "cmp" => list_cmp(list_text(payload, "op"))
      _ => "{\"op\":\"same\"}"
    }
  } catch {
    _ => "{\"op\":\"same\"}"
  }
}

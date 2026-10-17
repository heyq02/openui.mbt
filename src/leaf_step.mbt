///|
/// Schema leaf checks. The host still reads schema fields and builds messages.
fn leaf_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn leaf_flag(value : Json, key : String) -> Bool {
  match leaf_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn leaf_text(value : Json, key : String) -> String {
  match leaf_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `enum` and `const` are membership checks. `fail` is a type or enum miss.
pub fn leaf_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match leaf_text(payload, "phase") {
      "scalar" => {
        let kind = leaf_text(payload, "kind")
        if kind == "enum" {
          "{\"op\":\"enum\"}"
        } else if kind == "const" {
          "{\"op\":\"const\"}"
        } else if kind == "string" {
          "{\"op\":\"string\"}"
        } else if kind == "number" || kind == "integer" {
          "{\"op\":\"number\"}"
        } else if kind == "boolean" {
          "{\"op\":\"boolean\"}"
        } else {
          "{\"op\":\"empty\"}"
        }
      }
      "enum" =>
        if leaf_flag(payload, "scalar") && !leaf_flag(payload, "hit") {
          "{\"op\":\"fail\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      "js" =>
        if leaf_flag(payload, "array") {
          "{\"op\":\"array\"}"
        } else {
          "{\"op\":\"type\"}"
        }
      "type" =>
        if leaf_flag(payload, "typed") && !leaf_flag(payload, "match") {
          "{\"op\":\"fail\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      _ => "{\"op\":\"skip\"}"
    }
  } catch {
    _ => "{\"op\":\"skip\"}"
  }
}

///|
/// Argument binding and validation severity. The host still reads fields and builds objects.
fn bind_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn bind_flag(value : Json, key : String) -> Bool {
  match bind_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn bind_text(value : Json, key : String) -> String {
  match bind_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `props` uses mapped arguments. `invalid` drops a strict failure. `warning` marks a fallback root.
pub fn bind_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match bind_text(payload, "phase") {
      "args" =>
        if bind_flag(payload, "mapped") {
          "{\"op\":\"props\"}"
        } else {
          "{\"op\":\"list\"}"
        }
      "name" => "{\"op\":\"set\"}"
      "strict" =>
        if bind_flag(payload, "failed") {
          "{\"op\":\"invalid\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "warn" =>
        if bind_flag(payload, "warn") {
          "{\"op\":\"warning\"}"
        } else {
          "{\"op\":\"plain\"}"
        }
      _ => "{\"op\":\"keep\"}"
    }
  } catch {
    _ => "{\"op\":\"keep\"}"
  }
}

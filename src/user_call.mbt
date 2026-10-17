///|
/// `callFunction` branches. The host still calls the function, `checkValue`, and `reportError`.
fn user_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn user_flag(value : Json, key : String) -> Bool {
  match user_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn user_text(value : Json, key : String) -> String {
  match user_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `null` stops the call. `check` continues into schema validation. `keep` returns the checked value.
pub fn user_call(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match user_text(payload, "phase") {
      "args" =>
        if user_flag(payload, "miss") {
          "{\"op\":\"null\"}"
        } else {
          "{\"op\":\"check\"}"
        }
      "checked" =>
        if user_flag(payload, "bad") {
          "{\"op\":\"null\"}"
        } else {
          "{\"op\":\"call\"}"
        }
      "threw" => "{\"op\":\"null\"}"
      "result" =>
        if user_flag(payload, "returns") {
          "{\"op\":\"check\"}"
        } else {
          "{\"op\":\"value\"}"
        }
      "returns" =>
        if user_flag(payload, "bad") || user_flag(payload, "nil") {
          "{\"op\":\"null\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      _ => "{\"op\":\"null\"}"
    }
  } catch {
    _ => "{\"op\":\"null\"}"
  }
}

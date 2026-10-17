///|
/// Function and action argument decisions. The host evaluates values and reads defaults.
fn call_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn call_flag(value : Json, key : String) -> Bool {
  match call_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn call_phase(value : Json, key : String) -> String {
  match call_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `drop` removes an explicit null optional argument. `miss` means a required argument has no default.
pub fn call_arg(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match call_phase(payload, "phase") {
      "drop" =>
        if call_flag(payload, "nil") &&
          (!call_flag(payload, "list") || !call_flag(payload, "hit")) {
          "{\"op\":\"drop\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "miss" =>
        if call_flag(payload, "absent") && call_flag(payload, "bare") {
          "{\"op\":\"miss\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      _ => "{\"op\":\"keep\"}"
    }
  } catch {
    _ => "{\"op\":\"keep\"}"
  }
}

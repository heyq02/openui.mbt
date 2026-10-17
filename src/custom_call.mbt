///|
/// Custom-action branches. The host still builds the step and records it.
fn custom_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn custom_flag(value : Json, key : String) -> Bool {
  match custom_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn custom_text(value : Json, key : String) -> String {
  match custom_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `act` enters the action. `empty` is a plan with no steps. `build` records one step.
pub fn custom_call(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match custom_text(payload, "phase") {
      "open" =>
        if custom_flag(payload, "named") {
          "{\"op\":\"act\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      "args" =>
        if custom_flag(payload, "miss") {
          "{\"op\":\"empty\"}"
        } else {
          "{\"op\":\"check\"}"
        }
      "checked" =>
        if custom_flag(payload, "bad") {
          "{\"op\":\"empty\"}"
        } else {
          "{\"op\":\"build\"}"
        }
      _ => "{\"op\":\"skip\"}"
    }
  } catch {
    _ => "{\"op\":\"skip\"}"
  }
}

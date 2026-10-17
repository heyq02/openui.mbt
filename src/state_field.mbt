///|
/// Reactive state-field decisions. The host reads state, evaluates, and builds `setValue`.
fn field_flag(value : Json, key : String) -> Bool {
  match value {
    Object(map) =>
      match map.get(key) {
        Some(True) => true
        _ => false
      }
    _ => false
  }
}

///|
/// `reactive` when the binding is a reactive assign with a store and an evaluation context.
pub fn state_field(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    if field_flag(payload, "assign") &&
      field_flag(payload, "store") &&
      field_flag(payload, "context") {
      "{\"op\":\"reactive\"}"
    } else {
      "{\"op\":\"plain\"}"
    }
  } catch {
    _ => "{\"op\":\"plain\"}"
  }
}

///|
/// `state` when a reactive assign should resolve through `getState`.
pub fn strip_assign(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    if field_flag(payload, "assign") {
      "{\"op\":\"state\"}"
    } else {
      "{\"op\":\"keep\"}"
    }
  } catch {
    _ => "{\"op\":\"keep\"}"
  }
}

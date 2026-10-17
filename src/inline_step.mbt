///|
/// Whether an inline element keeps its props. The host still evaluates them.
fn inline_flag(value : Json, key : String) -> Bool {
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
/// `keep` when `hasDynamicProps === false`.
pub fn inline_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    if inline_flag(payload, "frozen") {
      "{\"op\":\"keep\"}"
    } else {
      "{\"op\":\"eval\"}"
    }
  } catch {
    _ => "{\"op\":\"eval\"}"
  }
}

///|
/// Mapped component props. The host still reads state and evaluates values.
fn comp_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn comp_flag(value : Json, key : String) -> Bool {
  match comp_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn comp_text(value : Json, key : String) -> String {
  match comp_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `assign` builds a reactive assignment. `state` reads the store. `inline` evaluates a child.
pub fn mapped_comp(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match comp_text(payload, "phase") {
      "open" =>
        if comp_flag(payload, "mapped") {
          "{\"op\":\"props\"}"
        } else {
          "{\"op\":\"warn\"}"
        }
      "prop" =>
        if comp_flag(payload, "state") && comp_flag(payload, "reactive") {
          "{\"op\":\"assign\"}"
        } else if comp_flag(payload, "state") {
          "{\"op\":\"state\"}"
        } else {
          "{\"op\":\"eval\"}"
        }
      "finish" =>
        if comp_flag(payload, "schema") {
          "{\"op\":\"walk\"}"
        } else {
          "{\"op\":\"done\"}"
        }
      "child" =>
        if comp_flag(payload, "element") {
          "{\"op\":\"inline\"}"
        } else if comp_flag(payload, "array") {
          "{\"op\":\"list\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      _ => "{\"op\":\"keep\"}"
    }
  } catch {
    _ => "{\"op\":\"keep\"}"
  }
}

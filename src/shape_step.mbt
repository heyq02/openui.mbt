///|
/// Schema validation branch. The host still copies values and reports errors.
fn shape_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn shape_flag(value : Json, key : String) -> Bool {
  match shape_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn shape_text(value : Json, key : String) -> String {
  match shape_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `keep` returns the original value. `repair` applies the default or drops a key.
pub fn shape_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match shape_text(payload, "phase") {
      "gate" =>
        if shape_flag(payload, "bad") {
          "{\"op\":\"keep\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "value" =>
        if shape_flag(payload, "nil") {
          "{\"op\":\"keep\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "ast" =>
        if shape_flag(payload, "ast") {
          "{\"op\":\"keep\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "element" =>
        if shape_flag(payload, "element") {
          "{\"op\":\"position\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "shape" =>
        if shape_flag(payload, "composite") {
          "{\"op\":\"slot\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "kind" =>
        if shape_flag(payload, "object") {
          "{\"op\":\"object\"}"
        } else if shape_flag(payload, "array") {
          "{\"op\":\"array\"}"
        } else {
          "{\"op\":\"leaf\"}"
        }
      "leaf" =>
        if !shape_flag(payload, "typed") && !shape_flag(payload, "enums") {
          "{\"op\":\"skip\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "defer" =>
        if shape_flag(payload, "listed") && shape_flag(payload, "partial") {
          "{\"op\":\"defer\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "miss" =>
        if shape_flag(payload, "bad") {
          "{\"op\":\"bad\"}"
        } else {
          "{\"op\":\"ok\"}"
        }
      "place" =>
        if shape_flag(payload, "composite") {
          "{\"op\":\"skip\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "shaped" =>
        if shape_flag(payload, "shaped") {
          "{\"op\":\"bad\"}"
        } else {
          "{\"op\":\"ok\"}"
        }
      "box" =>
        if shape_flag(payload, "bad") {
          "{\"op\":\"mismatch\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "props" =>
        if shape_flag(payload, "present") && shape_flag(payload, "object") {
          "{\"op\":\"use\"}"
        } else {
          "{\"op\":\"empty\"}"
        }
      "req" =>
        if shape_flag(payload, "list") {
          "{\"op\":\"use\"}"
        } else {
          "{\"op\":\"empty\"}"
        }
      "need" =>
        if shape_flag(payload, "partial") {
          "{\"op\":\"skip\"}"
        } else {
          "{\"op\":\"scan\"}"
        }
      "hole" =>
        if !shape_flag(payload, "present") || shape_flag(payload, "nil") {
          "{\"op\":\"fill\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "fill" =>
        if shape_flag(payload, "defined") {
          "{\"op\":\"default\"}"
        } else {
          "{\"op\":\"issue\"}"
        }
      "edge" =>
        if shape_flag(payload, "invalid") {
          "{\"op\":\"repair\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "repair" =>
        if shape_flag(payload, "defined") {
          "{\"op\":\"keep\"}"
        } else if shape_flag(payload, "required") {
          "{\"op\":\"invalid\"}"
        } else {
          "{\"op\":\"drop\"}"
        }
      "same" =>
        if shape_flag(payload, "same") {
          "{\"op\":\"keep\"}"
        } else {
          "{\"op\":\"copy\"}"
        }
      "write" =>
        if shape_flag(payload, "nil") {
          "{\"op\":\"delete\"}"
        } else {
          "{\"op\":\"set\"}"
        }
      "done" =>
        if shape_flag(payload, "invalid") {
          "{\"op\":\"invalid\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "items" =>
        if shape_flag(payload, "bad") {
          "{\"op\":\"keep\"}"
        } else {
          "{\"op\":\"walk\"}"
        }
      "cell" =>
        if shape_flag(payload, "changed") && shape_flag(payload, "fresh") {
          "{\"op\":\"copy\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "push" =>
        if shape_flag(payload, "open") && shape_flag(payload, "valid") {
          "{\"op\":\"push\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      _ => "{\"op\":\"keep\"}"
    }
  } catch {
    _ => "{\"op\":\"keep\"}"
  }
}

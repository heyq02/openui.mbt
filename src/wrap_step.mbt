///|
/// Prop wrapping, action calls, and builtin gates. The host still reads nodes and calls Zod maps.
fn wrap_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn wrap_flag(value : Json, key : String) -> Bool {
  match wrap_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn wrap_text(value : Json, key : String) -> String {
  match wrap_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `own` filters an action plan. `list` evaluates an Action argument. `yes` accepts a builtin step.
pub fn wrap_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match wrap_text(payload, "phase") {
      "plan" =>
        if wrap_flag(payload, "plan") {
          "{\"op\":\"own\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "inline" => "{\"op\":\"core\"}"
      "tree" => "{\"op\":\"core\"}"
      "call" =>
        if wrap_flag(payload, "action") {
          "{\"op\":\"list\"}"
        } else {
          "{\"op\":\"step\"}"
        }
      "open" =>
        if wrap_flag(payload, "open") {
          "{\"op\":\"eval\"}"
        } else {
          "{\"op\":\"empty\"}"
        }
      "boxed" =>
        if wrap_flag(payload, "array") {
          "{\"op\":\"plans\"}"
        } else {
          "{\"op\":\"blank\"}"
        }
      "def" =>
        if wrap_flag(payload, "has") {
          "{\"op\":\"call\"}"
        } else {
          "{\"op\":\"lazy\"}"
        }
      "pack" =>
        if wrap_flag(payload, "filled") {
          "{\"op\":\"one\"}"
        } else {
          "{\"op\":\"empty\"}"
        }
      "lazy" =>
        match wrap_text(payload, "kind") {
          "run" => "{\"op\":\"run\"}"
          "set" => "{\"op\":\"set\"}"
          "reset" => "{\"op\":\"reset\"}"
          _ => "{\"op\":\"none\"}"
        }
      "ref" =>
        if wrap_flag(payload, "ok") {
          "{\"op\":\"keep\"}"
        } else {
          "{\"op\":\"drop\"}"
        }
      "pair" =>
        if wrap_flag(payload, "open") {
          "{\"op\":\"go\"}"
        } else {
          "{\"op\":\"drop\"}"
        }
      "state" =>
        if wrap_flag(payload, "state") {
          "{\"op\":\"keep\"}"
        } else {
          "{\"op\":\"drop\"}"
        }
      "reset" =>
        if wrap_flag(payload, "empty") {
          "{\"op\":\"drop\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "builtin" =>
        if wrap_flag(payload, "has") {
          "{\"op\":\"yes\"}"
        } else {
          "{\"op\":\"no\"}"
        }
      "step" =>
        if wrap_flag(payload, "action") {
          "{\"op\":\"yes\"}"
        } else {
          "{\"op\":\"no\"}"
        }
      "extra" =>
        if wrap_flag(payload, "present") {
          "{\"op\":\"scan\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      "own" =>
        if wrap_flag(payload, "own") {
          "{\"op\":\"yes\"}"
        } else {
          "{\"op\":\"no\"}"
        }
      "reserved" =>
        if wrap_flag(payload, "has") {
          "{\"op\":\"yes\"}"
        } else {
          "{\"op\":\"no\"}"
        }
      "cat" =>
        if wrap_flag(payload, "present") {
          "{\"op\":\"local\"}"
        } else {
          "{\"op\":\"builtin\"}"
        }
      "defs" =>
        if wrap_flag(payload, "present") {
          "{\"op\":\"local\"}"
        } else {
          "{\"op\":\"builtin\"}"
        }
      _ => "{\"op\":\"keep\"}"
    }
  } catch {
    _ => "{\"op\":\"keep\"}"
  }
}

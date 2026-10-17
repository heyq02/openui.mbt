///|
/// Prop evaluation steps and runtime error text. The host evaluates, recurses, and reads state.
fn prop_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn prop_text(value : Json, key : String) -> String {
  match prop_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn prop_flag(value : Json, key : String) -> Bool {
  match prop_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn prop_quote(text : String) -> String {
  Json::string(text).stringify()
}

///|
/// Next step for one prop value. `kind` classifies an AST discriminant.
pub fn prop_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match prop_text(payload, "phase") {
      "kind" =>
        if is_ast_kind(prop_text(payload, "k")) == 1 {
          "{\"op\":\"ast\"}"
        } else {
          "{\"op\":\"no\"}"
        }
      "start" =>
        match prop_text(payload, "kind") {
          "array" => "{\"op\":\"arr\"}"
          "el" => "{\"op\":\"el\"}"
          "plan" => "{\"op\":\"keep\"}"
          "ast" =>
            if prop_text(payload, "k") == "StateRef" &&
              prop_flag(payload, "reactive") {
              "{\"op\":\"assign\"}"
            } else {
              "{\"op\":\"eval\"}"
            }
          _ => "{\"op\":\"scan\"}"
        }
      "eval" =>
        if prop_flag(payload, "element") {
          "{\"op\":\"el\"}"
        } else if prop_flag(payload, "array") {
          "{\"op\":\"items\"}"
        } else if prop_flag(payload, "assign") &&
          !prop_flag(payload, "reactive") {
          "{\"op\":\"state\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "scan" =>
        if prop_flag(payload, "needs") {
          "{\"op\":\"obj\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      _ => "{\"op\":\"keep\"}"
    }
  } catch {
    _ => "{\"op\":\"keep\"}"
  }
}

///|
/// Runtime error pushed when evaluating one element prop throws.
pub fn prop_error(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    let key = prop_text(payload, "key")
    let type_name = prop_text(payload, "typeName")
    let detail = prop_text(payload, "message")
    let message = "Evaluating prop \"" +
      key +
      "\" on " +
      type_name +
      " failed: " +
      detail
    let hint = "Check the expression used for prop \"" + key + "\""
    "{\"source\":\"runtime\",\"code\":\"runtime-error\",\"component\":" +
    prop_quote(type_name) +
    ",\"statementId\":null,\"message\":" +
    prop_quote(message) +
    ",\"hint\":" +
    prop_quote(hint) +
    "}"
  } catch {
    _ =>
      "{\"source\":\"runtime\",\"code\":\"runtime-error\",\"component\":\"\",\"statementId\":null,\"message\":\"Evaluating prop \\\"\\\" on  failed: \",\"hint\":\"Check the expression used for prop \\\"\\\"\"}"
  }
}

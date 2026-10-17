///|
/// Schema default, ref, and signature branch. The host still reads fields.
fn link_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn link_flag(value : Json, key : String) -> Bool {
  match link_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn link_text(value : Json, key : String) -> String {
  match link_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `read` keeps a default. `check` tests the next composite key. `name` splits a ref.
pub fn link_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match link_text(payload, "phase") {
      "gate" =>
        if link_flag(payload, "bad") {
          "{\"op\":\"skip\"}"
        } else {
          "{\"op\":\"read\"}"
        }
      "composite" =>
        match link_text(payload, "miss") {
          "" => "{\"op\":\"check\",\"key\":\"$ref\"}"
          "$ref" => "{\"op\":\"check\",\"key\":\"anyOf\"}"
          "anyOf" => "{\"op\":\"check\",\"key\":\"oneOf\"}"
          "oneOf" => "{\"op\":\"check\",\"key\":\"allOf\"}"
          _ => "{\"op\":\"no\"}"
        }
      "slot" =>
        if link_flag(payload, "any") {
          "{\"op\":\"any\"}"
        } else if link_flag(payload, "one") {
          "{\"op\":\"one\"}"
        } else {
          "{\"op\":\"self\"}"
        }
      "ref" =>
        if link_flag(payload, "text") {
          "{\"op\":\"name\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      "only" =>
        if link_flag(payload, "open") {
          "{\"op\":\"scan\"}"
        } else {
          "{\"op\":\"empty\"}"
        }
      "member" =>
        if link_flag(payload, "named") {
          "{\"op\":\"has\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      "type" =>
        if link_flag(payload, "ref") {
          "{\"op\":\"ref\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "leaf" =>
        if link_flag(payload, "enums") {
          "{\"op\":\"enum\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "expect" =>
        if link_flag(payload, "typed") {
          "{\"op\":\"type\"}"
        } else {
          "{\"op\":\"go\"}"
        }
      "plain" =>
        if link_flag(payload, "text") {
          "{\"op\":\"type\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      "param" =>
        if link_flag(payload, "typed") && link_flag(payload, "required") {
          "{\"op\":\"both\"}"
        } else if link_flag(payload, "typed") {
          "{\"op\":\"typed\"}"
        } else if link_flag(payload, "required") {
          "{\"op\":\"star\"}"
        } else {
          "{\"op\":\"bare\"}"
        }
      _ => "{\"op\":\"skip\"}"
    }
  } catch {
    _ => "{\"op\":\"skip\"}"
  }
}

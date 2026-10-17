///|
/// Validation message branch. The host still reads issue fields and joins text.
fn msg_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn msg_flag(value : Json, key : String) -> Bool {
  match msg_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn msg_text(value : Json, key : String) -> String {
  match msg_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `with` appends a signature. `join` appends the component list. `none` leaves the message empty.
pub fn msg_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match msg_text(payload, "phase") {
      "open" => {
        let code = msg_text(payload, "code")
        if code == "type-mismatch" {
          "{\"op\":\"type\"}"
        } else if code == "missing-required" {
          "{\"op\":\"missing\"}"
        } else if code == "null-required" {
          "{\"op\":\"null\"}"
        } else if code == "unknown-component" {
          "{\"op\":\"component\"}"
        } else if code == "inline-reserved" {
          "{\"op\":\"inline\"}"
        } else if code == "excess-args" {
          "{\"op\":\"excess\"}"
        } else if code == "unknown-function" {
          "{\"op\":\"function\"}"
        } else if code == "no-root" {
          "{\"op\":\"root\"}"
        } else {
          "{\"op\":\"none\"}"
        }
      }
      "sign" =>
        if msg_flag(payload, "marked") {
          "{\"op\":\"with\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      "list" =>
        if msg_flag(payload, "show") {
          "{\"op\":\"join\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      "root" => {
        let kind = msg_text(payload, "kind")
        if kind == "not-component" {
          "{\"op\":\"not-component\"}"
        } else if kind == "fallback" {
          "{\"op\":\"fallback\"}"
        } else if msg_flag(payload, "named") {
          "{\"op\":\"named\"}"
        } else {
          "{\"op\":\"bare\"}"
        }
      }
      _ => "{\"op\":\"none\"}"
    }
  } catch {
    _ => "{\"op\":\"none\"}"
  }
}

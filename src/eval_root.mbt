///|
/// `evaluateRoot` and `Each` decisions. The host evaluates expressions and keeps element identity.
fn root_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn root_text(value : Json, key : String) -> String {
  match root_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn root_flag(value : Json, key : String) -> Bool {
  match root_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn root_count(value : Json) -> Double? {
  match root_field(value, "n") {
    Some(Number(number, ..)) => Some(number)
    _ => None
  }
}

///|
/// Next step for `evaluateRoot`. `miss` carries the fixed `no-root` error.
pub fn evaluate_root(tag : String) -> String {
  match tag {
    "root" => "{\"op\":\"props\"}"
    "expr" => "{\"op\":\"eval\"}"
    "none" => "{\"op\":\"null\"}"
    "element" => "{\"op\":\"props\"}"
    "miss" =>
      "{\"op\":\"error\",\"error\":{\"source\":\"runtime\",\"code\":\"no-root\",\"statementId\":\"root\",\"message\":\"root does not evaluate to a component\"}}"
    _ => "{\"op\":\"null\"}"
  }
}

///|
/// `Each` gate. `open` checks the name and arity, `array` the evaluated list, `name` the loop variable.
pub fn each_step(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match root_text(payload, "phase") {
      "open" =>
        if root_text(payload, "name") != "Each" {
          "{\"op\":\"null\"}"
        } else if root_flag(payload, "wide") {
          "{\"op\":\"eval\"}"
        } else {
          match root_count(payload) {
            Some(number) =>
              if number < 3.0 {
                "{\"op\":\"empty\"}"
              } else {
                "{\"op\":\"eval\"}"
              }
            None => "{\"op\":\"empty\"}"
          }
        }
      "array" =>
        if root_flag(payload, "array") {
          "{\"op\":\"bind\"}"
        } else {
          "{\"op\":\"empty\"}"
        }
      "name" => {
        let kind = root_text(payload, "k")
        if (kind == "Ref" || kind == "Str") && root_flag(payload, "ok") {
          "{\"op\":\"map\"}"
        } else {
          "{\"op\":\"empty\"}"
        }
      }
      _ => "{\"op\":\"null\"}"
    }
  } catch {
    _ => "{\"op\":\"null\"}"
  }
}

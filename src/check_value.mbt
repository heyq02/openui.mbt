///|
/// Field-validator decisions. The host still builds `URL`, `RegExp`, and dynamic bound text.
fn check_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn check_flag(value : Json, key : String) -> Bool {
  match check_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn check_text(value : Json, key : String) -> String {
  match check_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn check_count(value : Json, key : String) -> Double {
  match check_field(value, key) {
    Some(Number(number, ..)) => number
    _ => -1.0
  }
}

///|
fn check_msg(code : String) -> String {
  if code == "required" {
    "{\"op\":\"fail\",\"text\":\"This field is required\"}"
  } else if code == "options" {
    "{\"op\":\"fail\",\"text\":\"At least one option is required\"}"
  } else if code == "email" {
    "{\"op\":\"fail\",\"text\":\"Please enter a valid email\"}"
  } else if code == "url" {
    "{\"op\":\"fail\",\"text\":\"Please enter a valid URL\"}"
  } else if code == "numeric" {
    "{\"op\":\"fail\",\"text\":\"Must be a number\"}"
  } else if code == "format" {
    "{\"op\":\"fail\",\"text\":\"Invalid format\"}"
  } else {
    "{\"op\":\"skip\"}"
  }
}

///|
fn check_bound(kind : String, ok : Bool) -> String {
  if ok {
    "{\"op\":\"skip\"}"
  } else if kind == "min" ||
    kind == "max" ||
    kind == "minLength" ||
    kind == "maxLength" {
    "{\"op\":\"fail\",\"code\":\"" + kind + "\"}"
  } else {
    "{\"op\":\"skip\"}"
  }
}

///|
fn check_rule(known : Bool, hit : Bool) -> String {
  if !known {
    "{\"op\":\"warn\"}"
  } else if hit {
    "{\"op\":\"stop\"}"
  } else {
    "{\"op\":\"next\"}"
  }
}

///|
/// `empty` and `dive` walk `isEmpty`. `fail` is a static message or a bound code.
pub fn check_value(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match check_text(payload, "phase") {
      "blank" =>
        if check_flag(payload, "nil") || check_flag(payload, "empty") {
          "{\"op\":\"empty\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "wrap" =>
        if check_flag(payload, "has") {
          "{\"op\":\"dive\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "keys" =>
        if check_count(payload, "n") == 0.0 {
          "{\"op\":\"empty\"}"
        } else {
          "{\"op\":\"keep\"}"
        }
      "done" => "{\"op\":\"keep\"}"
      "msg" => check_msg(check_text(payload, "code"))
      "bound" =>
        check_bound(check_text(payload, "kind"), check_flag(payload, "ok"))
      "rule" =>
        check_rule(check_flag(payload, "known"), check_flag(payload, "hit"))
      _ => "{\"op\":\"keep\"}"
    }
  } catch {
    _ => "{\"op\":\"keep\"}"
  }
}

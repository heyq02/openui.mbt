///|
/// `OpenUrl` and `ToAssistant` step text. The host keeps `context` by identity.
fn step_host(value : Json) -> String? {
  match builtin_field(value, "j") {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn step_throws(value : Json) -> Bool {
  match builtin_field(value, "throw") {
    Some(True) => true
    _ => false
  }
}

///|
fn step_symbol(value : Json) -> Bool {
  match builtin_field(value, "sym") {
    Some(True) => true
    _ => false
  }
}

///|
fn step_number(value : Json) -> String {
  match builtin_tag(value) {
    "nan" => "NaN"
    "pinf" => "Infinity"
    "ninf" => "-Infinity"
    "n0" => "0"
    _ =>
      match builtin_field(value, "v") {
        Some(Number(number, ..)) => number.to_string()
        Some(String(text)) => text
        _ => "0"
      }
  }
}

///|
fn step_text(value : Json, failed : Ref[Bool], inside : Bool) -> String {
  if step_throws(value) || (inside && step_symbol(value)) {
    failed.val = true
    return ""
  }
  match step_host(value) {
    Some(text) => text
    None => {
      let tag = builtin_tag(value)
      if tag == "s" {
        builtin_string(value)
      } else if tag == "n" ||
        tag == "nan" ||
        tag == "pinf" ||
        tag == "ninf" ||
        tag == "n0" {
        step_number(value)
      } else if tag == "b" {
        match builtin_field(value, "v") {
          Some(True) => "true"
          _ => "false"
        }
      } else if tag == "a" {
        let parts = []
        for item in builtin_items(value) {
          let item_tag = builtin_tag(item)
          if item_tag == "null" || item_tag == "u" || item_tag == "hole" {
            parts.push("")
          } else {
            parts.push(step_text(item, failed, true))
            if failed.val {
              return ""
            }
          }
        }
        join_sep(parts, ",")
      } else {
        "[object Object]"
      }
    }
  }
}

///|
fn arg_text(args : Json, key : String, failed : Ref[Bool]) -> String {
  match builtin_field(args, key) {
    None => ""
    Some(value) =>
      if builtin_tag(value) == "null" || builtin_tag(value) == "u" {
        ""
      } else {
        step_text(value, failed, false)
      }
  }
}

///|
fn step_result(op : String, key : String, text : String) -> String {
  "{\"op\":\"" + op + "\",\"" + key + "\":" + json_string(text) + "}"
}

///|
/// Build an `OpenUrl` or `ToAssistant` step. `throw` asks the host to call `String`.
pub fn eager_step(name : String, args_json : String) -> String {
  try {
    let args = @json.parse(args_json)
    let failed : Ref[Bool] = Ref(false)
    if name == "OpenUrl" {
      let text = arg_text(args, "url", failed)
      if failed.val {
        "{\"op\":\"throw\"}"
      } else {
        step_result("open_url", "url", text)
      }
    } else if name == "ToAssistant" {
      let text = arg_text(args, "message", failed)
      if failed.val {
        "{\"op\":\"throw\"}"
      } else {
        step_result("continue", "message", text)
      }
    } else {
      "{\"op\":\"none\"}"
    }
  } catch {
    _ => "{\"op\":\"none\"}"
  }
}

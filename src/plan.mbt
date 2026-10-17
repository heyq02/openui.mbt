///|
/// Action plans and MCP tool results. The host keeps step identity and `structuredContent`.
fn plan_flag(value : Json, key : String) -> Bool {
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
fn plan_text(value : Json, key : String) -> String {
  match value {
    Object(map) =>
      match map.get(key) {
        Some(String(text)) => text
        _ => ""
      }
    _ => ""
  }
}

///|
fn plan_items(value : Json) -> Array[Json] {
  match value {
    Object(map) =>
      match map.get("items") {
        Some(Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
/// `1` when the host saw a non-null object whose `steps` is an array.
pub fn is_action_plan(node_json : String) -> Int32 {
  try {
    let node = @json.parse(node_json)
    if plan_flag(node, "object") && plan_text(node, "steps") == "a" {
      1
    } else {
      0
    }
  } catch {
    _ => 0
  }
}

///|
fn plan_ops(items : Array[Json]) -> String {
  let buf = StringBuilder()
  buf.write_char('[')
  let mut first = true
  let mut index : Int32 = 0
  for item in items {
    let op = match item {
      String("plan") => "steps"
      String("step") => "step"
      _ => ""
    }
    if op != "" {
      if !first {
        buf.write_char(',')
      }
      first = false
      buf.write_string("{\"op\":")
      buf.write_string(Json::string(op).stringify())
      buf.write_string(",\"i\":")
      buf.write_string(index.to_string())
      buf.write_char('}')
    }
    index = index + 1
  }
  buf.write_char(']')
  buf.to_string()
}

///|
/// Which values `flattenPlans` keeps. `"h"` is a hole, `"plan"` copies `steps`, `"step"` keeps the value.
pub fn flatten_plans(tags_json : String) -> String {
  try {
    match @json.parse(tags_json) {
      Array(items) => plan_ops(items)
      _ => "[]"
    }
  } catch {
    _ => "[]"
  }
}

///|
fn write_indices(buf : StringBuilder, indices : Array[Int32]) -> Unit {
  buf.write_char('[')
  let mut first = true
  for index in indices {
    if !first {
      buf.write_char(',')
    }
    first = false
    buf.write_string(index.to_string())
  }
  buf.write_char(']')
}

///|
fn tool_scan(payload : Json, error : Bool) -> String {
  let content = plan_text(payload, "content")
  if content == "missing" {
    if error {
      return "{\"op\":\"error\",\"at\":[]}"
    }
    return "{\"op\":\"null\"}"
  }
  if content != "array" {
    return "{\"op\":\"throw\"}"
  }
  let indices : Array[Int32] = []
  let mut index : Int32 = 0
  let mut bad : Int32 = -1
  let mut seen_bad = false
  for item in plan_items(payload) {
    if !seen_bad {
      match item {
        String("bad") => {
          bad = index
          seen_bad = true
        }
        String("text") => indices.push(index)
        _ => ()
      }
      index = index + 1
    }
  }
  if bad >= 0 {
    return "{\"op\":\"throw\",\"i\":" + bad.to_string() + "}"
  }
  if error {
    let buf = StringBuilder()
    buf.write_string("{\"op\":\"error\",\"at\":")
    write_indices(buf, indices)
    buf.write_char('}')
    return buf.to_string()
  }
  if indices.length() == 0 {
    return "{\"op\":\"null\"}"
  }
  let buf = StringBuilder()
  buf.write_string("{\"op\":\"parse\",\"at\":")
  write_indices(buf, indices)
  buf.write_char('}')
  buf.to_string()
}

///|
/// Choose an MCP tool result: throw, return structured content, parse text, or null.
pub fn extract_tool_result(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    if plan_flag(payload, "error") {
      tool_scan(payload, true)
    } else if plan_flag(payload, "structured") {
      "{\"op\":\"structured\"}"
    } else {
      tool_scan(payload, false)
    }
  } catch {
    _ => "{\"op\":\"null\"}"
  }
}

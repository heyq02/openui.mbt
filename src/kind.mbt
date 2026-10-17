///|
fn kind_flag(value : Json, key : String) -> Bool {
  match json_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn kind_text(value : Json, key : String) -> String {
  match json_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
/// `cloud` when `spec.cloud === true`, `library` when `spec.library` is an object, otherwise `legacy`.
pub fn system_prompt_kind(spec_json : String) -> String {
  try {
    let spec = @json.parse(spec_json)
    if kind_flag(spec, "cloudIn") && kind_flag(spec, "cloudTrue") {
      "cloud"
    } else if kind_flag(spec, "libraryIn") && kind_flag(spec, "libraryObject") {
      "library"
    } else {
      "legacy"
    }
  } catch {
    _ => "legacy"
  }
}

///|
/// `1` when the tagged fields are an element node. The host rejects non-objects first.
pub fn is_element_node(node_json : String) -> Int32 {
  try {
    let node = @json.parse(node_json)
    if kind_text(node, "type") != "element" {
      return 0
    }
    if kind_text(node, "typeName") != "s" {
      return 0
    }
    let props = kind_text(node, "props")
    if props != "o" && props != "a" {
      return 0
    }
    if kind_text(node, "partial") != "b" {
      return 0
    }
    1
  } catch {
    _ => 0
  }
}

///|
/// `1` when the value is a non-null object whose `__reactive` is `"assign"`.
pub fn is_reactive_assign(node_json : String) -> Int32 {
  try {
    let node = @json.parse(node_json)
    if kind_flag(node, "object") && kind_text(node, "text") == "assign" {
      1
    } else {
      0
    }
  } catch {
    _ => 0
  }
}

///|
/// `1` for runtime expression discriminants.
pub fn is_runtime_expr(kind : String) -> Int32 {
  match kind {
    "StateRef"
    | "RuntimeRef"
    | "BinOp"
    | "UnaryOp"
    | "Ternary"
    | "Member"
    | "Index"
    | "Assign" => 1
    _ => 0
  }
}

///|
/// Built-in functions and action steps. `Action` is included.
/// `Count(x)` is not a call; `@Count(x)` and `Action([...])` are.
fn is_builtin(name : String) -> Bool {
  match name {
    "Count"
    | "First"
    | "Last"
    | "Sum"
    | "Avg"
    | "Min"
    | "Max"
    | "Sort"
    | "Filter"
    | "Round"
    | "Abs"
    | "Floor"
    | "Ceil"
    | "Each"
    | "Run"
    | "ToAssistant"
    | "OpenUrl"
    | "Set"
    | "Reset"
    | "Action" => true
    _ => false
  }
}

///|
fn is_component_call_name(name : String) -> Bool {
  !is_builtin(name) || name == "Action"
}

///|
/// Positional names for a non-lazy call. Lazy builtins stay positional.
fn mapped_param_names(name : String) -> Array[String]? {
  match name {
    "Count" | "First" | "Last" => Some(["array"])
    "Sum" | "Avg" | "Min" | "Max" => Some(["numbers"])
    "Sort" => Some(["array", "field", "direction"])
    "Filter" => Some(["array", "field", "operator", "value"])
    "Round" => Some(["number", "decimals"])
    "Abs" | "Floor" | "Ceil" => Some(["number"])
    "ToAssistant" => Some(["message", "context"])
    "OpenUrl" => Some(["url"])
    _ => {
      let mut found : Array[String]? = None
      for call in cached_catalog.val.calls {
        if call.name == name {
          let names : Array[String] = []
          for param in call.params {
            names.push(param.name)
          }
          found = Some(names)
        }
      }
      found
    }
  }
}

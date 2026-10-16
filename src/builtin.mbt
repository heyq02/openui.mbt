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

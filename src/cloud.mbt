///|
/// Cloud library checks. The host still serializes the config block.
fn node_kind(value : Json) -> String {
  match json_field(value, "t") {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn node_payload(value : Json) -> Json? {
  json_field(value, "v")
}

///|
fn node_entries(value : Json) -> Array[Json] {
  if node_kind(value) != "o" {
    return []
  }
  match node_payload(value) {
    Some(Array(items)) => items
    _ => []
  }
}

///|
fn node_items(value : Json) -> Array[Json] {
  if node_kind(value) != "a" {
    return []
  }
  match node_payload(value) {
    Some(Array(items)) => items
    _ => []
  }
}

///|
fn find_entry(value : Json, key : String) -> Json? {
  for item in node_entries(value) {
    match item {
      Array(cells) =>
        if cells.length() >= 2 {
          match cells[0] {
            String(name) => if name == key { return Some(cells[1]) }
            _ => ()
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn string_node(value : Json) -> String? {
  if node_kind(value) != "s" {
    return None
  }
  match node_payload(value) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn number_text(value : Json) -> String {
  match node_payload(value) {
    Some(String(text)) =>
      if text == "nan" {
        "NaN"
      } else if text == "inf" {
        "Infinity"
      } else if text == "-inf" {
        "-Infinity"
      } else {
        "0"
      }
    Some(Number(number, ..)) => number.to_string()
    _ => "0"
  }
}

///|
fn host_text(value : Json) -> String? {
  match json_field(value, "j") {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn text_throws(value : Json) -> Bool {
  match json_field(value, "throw") {
    Some(True) => true
    _ => false
  }
}

///|
fn is_symbol(value : Json) -> Bool {
  match json_field(value, "sym") {
    Some(True) => true
    _ => false
  }
}

///|
fn js_text(value : Json, failed : Ref[Bool], inside : Bool) -> String {
  if text_throws(value) || (inside && is_symbol(value)) {
    failed.val = true
    return ""
  }
  match host_text(value) {
    Some(text) => text
    None => {
      let kind = node_kind(value)
      if kind == "s" {
        match string_node(value) {
          Some(text) => text
          None => ""
        }
      } else if kind == "n" {
        number_text(value)
      } else if kind == "b" {
        match node_payload(value) {
          Some(True) => "true"
          _ => "false"
        }
      } else if kind == "z" {
        "null"
      } else if kind == "u" || kind == "h" {
        "undefined"
      } else if kind == "a" {
        let parts = []
        for item in node_items(value) {
          if node_kind(item) == "z" ||
            node_kind(item) == "u" ||
            node_kind(item) == "h" {
            parts.push("")
          } else {
            parts.push(js_text(item, failed, true))
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
fn ref_target(text : String) -> String? {
  let prefix = "#/$defs/"
  if text.length() <= prefix.length() {
    return None
  }
  if text.unsafe_substring(start=0, end=prefix.length()) != prefix {
    return None
  }
  let rest = text.unsafe_substring(start=prefix.length(), end=text.length())
  let mut index = 0
  while index < rest.length() {
    let unit = unit_at(rest, index)
    if unit == 0x0A || unit == 0x0D || unit == 0x2028 || unit == 0x2029 {
      return None
    }
    index = index + 1
  }
  Some(rest)
}

///|
fn has_name(names : Array[String], name : String) -> Bool {
  for item in names {
    if item == name {
      return true
    }
  }
  false
}

///|
fn def_names(defs : Json) -> Array[String] {
  let names = []
  for item in node_entries(defs) {
    match item {
      Array(cells) =>
        if cells.length() > 0 {
          match cells[0] {
            String(name) => names.push(name)
            _ => ()
          }
        }
      _ => ()
    }
  }
  names
}

///|
fn collect_schema_refs(
  node : Json,
  path : String,
  names : Array[String],
  issues : Array[String],
) -> Unit {
  if node_kind(node) == "a" {
    let mut index = 0
    for item in node_items(node) {
      if node_kind(item) != "h" {
        collect_schema_refs(item, path + "/" + index.to_string(), names, issues)
      }
      index = index + 1
    }
    return
  }
  if node_kind(node) != "o" {
    return
  }
  match find_entry(node, "$ref") {
    Some(ref_node) =>
      match string_node(ref_node) {
        Some(text) => {
          let unresolved = match ref_target(text) {
            Some(name) => !has_name(names, name)
            None => true
          }
          if unresolved {
            issues.push(
              "Unresolvable $ref \"" +
              text +
              "\" at " +
              path +
              " — refs must be \"#/$defs/<name>\" pointing at a component in $defs.",
            )
          }
        }
        None => ()
      }
    None => ()
  }
  for item in node_entries(node) {
    match item {
      Array(cells) =>
        if cells.length() >= 2 {
          match cells[0] {
            String(key) =>
              if key != "$ref" {
                collect_schema_refs(cells[1], path + "/" + key, names, issues)
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn required_invalid(items : Array[Json]) -> Bool {
  for item in items {
    if node_kind(item) != "h" && node_kind(item) != "s" {
      return true
    }
  }
  false
}

///|
fn check_def(
  name : String,
  def : Json,
  names : Array[String],
  issues : Array[String],
) -> Unit {
  let def_path = "$defs/" + name
  if node_kind(def) != "o" {
    issues.push(def_path + " must be an object component schema.")
    return
  }
  let properties = find_entry(def, "properties")
  match properties {
    Some(value) =>
      if node_kind(value) != "u" && node_kind(value) != "o" {
        issues.push(def_path + "/properties must be an object.")
      }
    None => ()
  }
  match find_entry(def, "required") {
    Some(required) =>
      if node_kind(required) == "u" {
        ()
      } else if node_kind(required) != "a" ||
        required_invalid(node_items(required)) {
        issues.push(def_path + "/required must be an array of property names.")
      } else {
        let keys = match properties {
          Some(value) =>
            if node_kind(value) == "o" {
              def_names(value)
            } else {
              []
            }
          None => []
        }
        for item in node_items(required) {
          let prop = if node_kind(item) == "h" {
            "undefined"
          } else {
            match string_node(item) {
              Some(text) => text
              None => ""
            }
          }
          if !has_name(keys, prop) {
            issues.push(
              def_path +
              " lists required property \"" +
              prop +
              "\" that is not in properties.",
            )
          }
        }
      }
    None => ()
  }
  match properties {
    Some(value) =>
      collect_schema_refs(value, def_path + "/properties", names, issues)
    None => ()
  }
}

///|
fn check_group(
  group : Json,
  names : Array[String],
  issues : Array[String],
  failed : Ref[Bool],
) -> Bool {
  let shape = "Each componentGroups entry must be {name: string, components: string[], notes?: string[]}."
  if node_kind(group) != "o" {
    issues.push(shape)
    return true
  }
  match find_entry(group, "name") {
    Some(name_node) =>
      match string_node(name_node) {
        Some(name) =>
          match find_entry(group, "components") {
            Some(components) =>
              if node_kind(components) != "a" {
                issues.push(shape)
              } else {
                for comp in node_items(components) {
                  match string_node(comp) {
                    Some(text) =>
                      if !has_name(names, text) {
                        issues.push(
                          "Component group \"" +
                          name +
                          "\" references unknown component \"" +
                          text +
                          "\".",
                        )
                      }
                    None => {
                      let text = js_text(comp, failed, false)
                      if failed.val {
                        return false
                      }
                      issues.push(
                        "Component group \"" +
                        name +
                        "\" references unknown component \"" +
                        text +
                        "\".",
                      )
                    }
                  }
                }
              }
            None => issues.push(shape)
          }
        None => issues.push(shape)
      }
    None => issues.push(shape)
  }
  true
}

///|
fn walk_groups(
  library : Json,
  names : Array[String],
  issues : Array[String],
  failed : Ref[Bool],
) -> String {
  match find_entry(library, "componentGroups") {
    None => ""
    Some(groups) =>
      if node_kind(groups) == "u" || node_kind(groups) == "z" {
        ""
      } else if node_kind(groups) == "a" {
        for group in node_items(groups) {
          if node_kind(group) == "h" {
            issues.push(
              "Each componentGroups entry must be {name: string, components: string[], notes?: string[]}.",
            )
          } else if !check_group(group, names, issues, failed) {
            return "string"
          }
        }
        ""
      } else if node_kind(groups) == "s" {
        match string_node(groups) {
          Some(text) => {
            let mut index = 0
            while index < text.length() {
              let unit = unit_at(text, index)
              issues.push(
                "Each componentGroups entry must be {name: string, components: string[], notes?: string[]}.",
              )
              if unit >= 0xD800 &&
                unit <= 0xDBFF &&
                index + 1 < text.length() &&
                unit_at(text, index + 1) >= 0xDC00 &&
                unit_at(text, index + 1) <= 0xDFFF {
                index = index + 1
              }
              index = index + 1
            }
          }
          None => ()
        }
        ""
      } else {
        "throw"
      }
  }
}

///|
fn push_library_root(library : Json, issues : Array[String]) -> Unit {
  match find_entry(library, "root") {
    None => ()
    Some(root) =>
      if node_kind(root) != "u" {
        match string_node(root) {
          Some(text) =>
            if text.length() == 0 {
              issues.push(
                "chatLibrary.root, when present, must be a non-empty string.",
              )
            }
          None =>
            issues.push(
              "chatLibrary.root, when present, must be a non-empty string.",
            )
        }
      }
  }
}

///|
fn library_issues(library : Json) -> String {
  if node_kind(library) != "o" {
    return "chatLibrary must be an object."
  }
  let issues = []
  let failed : Ref[Bool] = Ref(false)
  push_library_root(library, issues)
  match find_entry(library, "schema") {
    None =>
      issues.push(
        "chatLibrary.schema must be an object with a $defs map of component schemas.",
      )
    Some(schema) =>
      if node_kind(schema) != "o" {
        issues.push(
          "chatLibrary.schema must be an object with a $defs map of component schemas.",
        )
      } else {
        match find_entry(schema, "$defs") {
          None =>
            issues.push(
              "chatLibrary.schema.$defs must be a non-empty object keyed by component name.",
            )
          Some(defs) =>
            if node_kind(defs) != "o" || node_entries(defs).length() == 0 {
              issues.push(
                "chatLibrary.schema.$defs must be a non-empty object keyed by component name.",
              )
            } else {
              let names = def_names(defs)
              match find_entry(library, "root") {
                Some(root) =>
                  match string_node(root) {
                    Some(text) =>
                      if text.length() > 0 && !has_name(names, text) {
                        issues.push(
                          "Root component \"" +
                          text +
                          "\" was not found in schema.$defs. Available components: " +
                          join_sep(names, ", ") +
                          ".",
                        )
                      }
                    None => ()
                  }
                None => ()
              }
              for item in node_entries(defs) {
                match item {
                  Array(cells) =>
                    if cells.length() >= 2 {
                      match cells[0] {
                        String(name) => check_def(name, cells[1], names, issues)
                        _ => ()
                      }
                    }
                  _ => ()
                }
              }
              let status = walk_groups(library, names, issues, failed)
              if status == "throw" || status == "string" {
                return status
              }
            }
        }
      }
  }
  join_sep(issues, " ")
}

///|
fn flag_at(spec : Json, key : String) -> Bool {
  match json_field(spec, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn option_json(examples : Bool, preamble : Bool, rules : Bool) -> String {
  let parts = []
  if examples {
    parts.push("\"examples\"")
  }
  if preamble {
    parts.push("\"preamble\"")
  }
  if rules {
    parts.push("\"additionalRules\"")
  }
  "{\"t\":\"lib\",\"options\":[" + join_sep(parts, ",") + "]}"
}

///|
/// Decide a cloud config. `throw` asks the host to iterate `componentGroups`.
pub fn cloud_config(spec_json : String) -> String {
  try {
    let spec = @json.parse(spec_json)
    let examples = flag_at(spec, "examples")
    let preamble = flag_at(spec, "preamble")
    let rules = flag_at(spec, "rules")
    let picked = examples || preamble || rules
    if !flag_at(spec, "hasLibrary") {
      if flag_at(spec, "hasPromptOptions") && picked {
        return "{\"t\":\"err\",\"m\":" +
          json_string(
            "[generateSystemPrompt] promptOptions requires a library — the built-in library ignores it.",
          ) +
          "}"
      }
      return "{\"t\":\"version\"}"
    }
    let library = match json_field(spec, "library") {
      Some(value) => value
      None => @json.parse("{\"t\":\"u\"}")
    }
    let issues = library_issues(library)
    if issues == "throw" {
      "{\"t\":\"throw\"}"
    } else if issues == "string" {
      "{\"t\":\"string\"}"
    } else if issues.length() > 0 {
      "{\"t\":\"err\",\"m\":" +
      json_string("[generateSystemPrompt] Invalid library: " + issues) +
      "}"
    } else {
      option_json(examples, preamble, rules)
    }
  } catch {
    _ => "{\"t\":\"err\",\"m\":\"\"}"
  }
}

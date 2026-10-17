///|
/// Query snapshot choice and error text. The host keeps cache entries and tool results.
fn query_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn query_text(value : Json, key : String) -> String {
  match query_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn query_flag(value : Json, key : String) -> Bool {
  match query_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn query_quote(text : String) -> String {
  Json::string(text).stringify()
}

///|
fn query_bool(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
/// `data`, `prev`, or `defaults` for one query. `flags` says which status lists include it.
pub fn query_slot(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match query_text(payload, "phase") {
      "value" =>
        if query_flag(payload, "data") {
          "{\"op\":\"data\"}"
        } else if query_flag(payload, "prev") && query_flag(payload, "prevData") {
          "{\"op\":\"prev\"}"
        } else {
          "{\"op\":\"defaults\"}"
        }
      "flags" => {
        let loading = query_flag(payload, "loading")
        let refetch = loading && query_flag(payload, "ever")
        "{\"load\":" +
        query_bool(loading) +
        ",\"refetch\":" +
        query_bool(refetch) +
        ",\"error\":" +
        query_bool(query_flag(payload, "error")) +
        "}"
      }
      _ => "{\"op\":\"defaults\"}"
    }
  } catch {
    _ => "{\"op\":\"defaults\"}"
  }
}

///|
fn query_noun(source : String) -> String {
  if source == "mutation" {
    "Mutation"
  } else {
    "Query"
  }
}

///|
fn query_code(kind : String) -> String {
  if kind == "missing" {
    "tool-not-found"
  } else if kind == "mcp" {
    "mcp-error"
  } else {
    "tool-error"
  }
}

///|
fn query_message(
  source : String,
  kind : String,
  tool : String,
  detail : String,
) -> String {
  let noun = query_noun(source)
  if kind == "missing" {
    noun + " tool \"" + tool + "\" not found"
  } else if kind == "mcp" {
    noun + " \"" + tool + "\" returned an error: " + detail
  } else {
    noun + " \"" + tool + "\" failed: " + detail
  }
}

///|
/// Structured query or mutation failure. The host sets the live ids and the tool hint.
pub fn query_error(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    let source = query_text(payload, "source")
    let kind = query_text(payload, "kind")
    let tool = query_text(payload, "tool")
    let detail = query_text(payload, "detail")
    let noun = query_noun(source)
    let message = query_message(source, kind, tool, detail)
    let body = "{\"source\":" +
      query_quote(if source == "mutation" { "mutation" } else { "query" }) +
      ",\"code\":" +
      query_quote(query_code(kind)) +
      ",\"message\":" +
      query_quote(message) +
      ",\"statementId\":null,\"component\":" +
      query_quote(noun) +
      ",\"toolName\":" +
      query_quote(tool)
    if kind == "missing" {
      body + ",\"hint\":null}"
    } else {
      body + "}"
    }
  } catch {
    _ =>
      "{\"source\":\"query\",\"code\":\"tool-error\",\"message\":\"Query \\\"\\\" failed: \",\"statementId\":null,\"component\":\"Query\",\"toolName\":\"\"}"
  }
}

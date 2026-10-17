///|
/// Parse a complete OpenUI Lang program and return JSON.
#export_name("parse_openui")
pub fn parse_openui(src : String) -> String {
  // Compact JSON. Pretty-printing dominated the parse that lang-core immediately parses back.
  @openui.parse(src).compact_json()
}

///|
/// Statement count only, so a benchmark can separate parsing from JSON encoding.
#export_name("parse_count")
pub fn parse_count(src : String) -> Int32 {
  @openui.parse(src).statements.length()
}

///|
/// Token count only, so a benchmark can separate lexing from parsing.
#export_name("token_count")
pub fn token_count(src : String) -> Int32 {
  @openui.tokenize(src).length()
}

///|
/// Tokenize OpenUI Lang source and return a JSON array.
#export_name("tokenize_openui")
pub fn tokenize_openui(src : String) -> String {
  @openui.tokens_json(src)
}

///|
/// Materialize without encoding, so a benchmark can separate the walk from JSON.
#export_name("materialize_count")
pub fn materialize_count(
  src : String,
  schema : String,
  root_name : String,
) -> Int32 {
  @openui.materialize_count(src, schema, root_name)
}

///|
/// Materialize source and return the official ParseResult JSON.
#export_name("parse_result")
pub fn parse_result(
  src : String,
  schema : String,
  root_name : String,
) -> String {
  @openui.materialize_result(src, schema, root_name)
}

///|
/// Materialize source against a library JSON Schema.
/// `root_name` is used only when the program has no `root` statement.
#export_name("materialize_openui")
pub fn materialize_openui(
  src : String,
  schema : String,
  root_name : String,
) -> String {
  @openui.materialize_json(src, schema, root_name)
}

///|
/// Open a streaming parser and return its id.
#export_name("stream_open")
pub fn stream_open(schema : String, root_name : String) -> Int32 {
  @openui.stream_open(schema, root_name)
}

///|
/// Append text and return the latest ParseResult JSON.
/// `complete` 1 checks the whole buffer in this same call.
#export_name("stream_append")
pub fn stream_append(id : Int32, chunk : String, complete : Int32) -> String {
  @openui.stream_append(id, chunk, complete)
}

///|
/// Append text and return the latest ParseResult JSON.
#export_name("stream_push")
pub fn stream_push(id : Int32, chunk : String) -> String {
  @openui.stream_push(id, chunk)
}

///|
/// Replace the buffer. `complete` 1 checks the whole buffer in this same call.
#export_name("stream_replace")
pub fn stream_replace(id : Int32, text : String, complete : Int32) -> String {
  @openui.stream_replace(id, text, complete)
}

///|
/// Read the current ParseResult. `complete` 1 previews the final check.
#export_name("stream_view")
pub fn stream_view(id : Int32, complete : Int32) -> String {
  @openui.stream_view(id, complete)
}

///|
/// Replace the buffer and return the latest materialize JSON.
#export_name("stream_set")
pub fn stream_set(id : Int32, text : String) -> String {
  @openui.stream_set(id, text)
}

///|
/// Finish the stream and return the final materialize JSON.
#export_name("stream_finish")
pub fn stream_finish(id : Int32) -> String {
  @openui.stream_finish(id)
}

///|
/// Drop the stream. Returns 1 if it existed.
#export_name("stream_close")
pub fn stream_close(id : Int32) -> Int32 {
  @openui.stream_close(id)
}

///|
/// Split an OpenUI `]]>openui:` message. `streaming` 1 holds a partial marker.
#export_name("parse_message")
pub fn parse_message(raw : String, streaming : Int32) -> String {
  @openui.parse_message(raw, streaming != 0)
}

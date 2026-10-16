///|
/// Parse a complete OpenUI Lang program and return JSON.
#export_name("parse_openui")
pub fn parse_openui(src : String) -> String {
  @openui.parse_json(src)
}

///|
/// Tokenize OpenUI Lang source and return a JSON array.
#export_name("tokenize_openui")
pub fn tokenize_openui(src : String) -> String {
  @openui.tokens_json(src)
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
/// Append text and return the latest materialize JSON.
#export_name("stream_push")
pub fn stream_push(id : Int32, chunk : String) -> String {
  @openui.stream_push(id, chunk)
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

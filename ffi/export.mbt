///|
/// Parse a complete OpenUI Lang program and return JSON.
#export_name("parse_openui")
pub fn parse_openui(src : String) -> String {
  @parser.parse_json(src)
}

///|
/// Tokenize OpenUI Lang source and return a JSON array.
#export_name("tokenize_openui")
pub fn tokenize_openui(src : String) -> String {
  @parser.tokens_json(src)
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
  @parser.materialize_json(src, schema, root_name)
}

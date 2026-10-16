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

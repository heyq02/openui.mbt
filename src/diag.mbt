///|
/// Syntax and stream failures. The official JSON still carries `message`.
pub enum SyntaxKind {
  Expected(String)
  UnclosedInput
  StreamClosed
} derive(Eq)

///|
pub extend SyntaxKind with Eq::{not_equal, equal}

///|
pub fn SyntaxKind::message(self : SyntaxKind) -> String {
  match self {
    Expected(text) => text
    UnclosedInput => "unclosed input"
    StreamClosed => "stream is closed"
  }
}

///|
/// Schema compilation failures. JSON syntax keeps the byte index.
pub enum SchemaKind {
  InvalidJson(Int32)
  InvalidJsonString(Int32)
  InvalidJsonNumber(Int32)
  Expected(String)
} derive(Eq)

///|
pub extend SchemaKind with Eq::{not_equal, equal}

///|
pub fn SchemaKind::message(self : SchemaKind) -> String {
  match self {
    InvalidJson(index) => "invalid JSON at " + index.to_string()
    InvalidJsonString(index) => "invalid JSON string at " + index.to_string()
    InvalidJsonNumber(index) => "invalid JSON number at " + index.to_string()
    Expected(text) => text
  }
}

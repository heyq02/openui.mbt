///|
/// Token kinds aligned with the OpenUI Lang lexer.
pub enum TokenKind {
  Newline
  LParen
  RParen
  LBrack
  RBrack
  LBrace
  RBrace
  Comma
  Colon
  Equals
  True
  False
  Null
  EOF
  Str
  Num
  Ident
  Type
  StateVar
  Dot
  Plus
  Minus
  Star
  Slash
  Percent
  EqEq
  NotEq
  Greater
  Less
  GreaterEq
  LessEq
  And
  Or
  Not
  Question
  BuiltinCall
} derive(Eq)

///|
pub extend TokenKind with Eq::{not_equal, equal}

///|
/// A lexer token. `text` is the decoded string, raw number lexeme, or name.
/// Punctuation leaves `text` empty. State variables keep the leading `$`.
/// Builtin calls store the name without `@`.
pub struct Token {
  kind : TokenKind
  text : String
  line : Int32
  column : Int32
}

///|
pub fn TokenKind::name(self : TokenKind) -> String {
  match self {
    Newline => "Newline"
    LParen => "LParen"
    RParen => "RParen"
    LBrack => "LBrack"
    RBrack => "RBrack"
    LBrace => "LBrace"
    RBrace => "RBrace"
    Comma => "Comma"
    Colon => "Colon"
    Equals => "Equals"
    True => "True"
    False => "False"
    Null => "Null"
    EOF => "EOF"
    Str => "Str"
    Num => "Num"
    Ident => "Ident"
    Type => "Type"
    StateVar => "StateVar"
    Dot => "Dot"
    Plus => "Plus"
    Minus => "Minus"
    Star => "Star"
    Slash => "Slash"
    Percent => "Percent"
    EqEq => "EqEq"
    NotEq => "NotEq"
    Greater => "Greater"
    Less => "Less"
    GreaterEq => "GreaterEq"
    LessEq => "LessEq"
    And => "And"
    Or => "Or"
    Not => "Not"
    Question => "Question"
    BuiltinCall => "BuiltinCall"
  }
}

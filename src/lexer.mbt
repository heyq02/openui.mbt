///|
priv struct Lexer {
  src : String
  mut index : Int32
  mut line : Int32
  mut column : Int32
}

///|
fn code(ch : Char) -> Int32 {
  ch.to_int()
}

///|
fn Lexer::ended(self : Lexer) -> Bool {
  self.index >= self.src.length()
}

///|
fn Lexer::peek(self : Lexer) -> Int32 {
  if self.ended() {
    -1
  } else {
    self.src.unsafe_get(self.index).to_int()
  }
}

///|
fn Lexer::peek_at(self : Lexer, offset : Int32) -> Int32 {
  let index = self.index + offset
  if index >= self.src.length() {
    -1
  } else {
    self.src.unsafe_get(index).to_int()
  }
}

///|
fn Lexer::advance(self : Lexer) -> Unit {
  if self.ended() {
    return
  }
  let current = self.peek()
  self.index += 1
  if current == code('\n') {
    self.line += 1
    self.column = 1
  } else {
    self.column += 1
  }
}

///|
fn is_alpha(ch : Int32) -> Bool {
  (ch >= code('a') && ch <= code('z')) ||
  (ch >= code('A') && ch <= code('Z')) ||
  ch == code('_')
}

///|
fn is_digit(ch : Int32) -> Bool {
  ch >= code('0') && ch <= code('9')
}

///|
fn is_ident_continue(ch : Int32) -> Bool {
  is_alpha(ch) || is_digit(ch)
}

///|
fn is_after_value(tokens : Array[Token]) -> Bool {
  if tokens.length() == 0 {
    return false
  }
  match tokens[tokens.length() - 1].kind {
    Num
    | Str
    | Ident
    | Type
    | RParen
    | RBrack
    | True
    | False
    | Null
    | StateVar
    | BuiltinCall => true
    _ => false
  }
}

///|
fn hex_digit(ch : Int32) -> Int32? {
  if ch >= code('0') && ch <= code('9') {
    Some(ch - code('0'))
  } else if ch >= code('a') && ch <= code('f') {
    Some(ch - code('a') + 10)
  } else if ch >= code('A') && ch <= code('F') {
    Some(ch - code('A') + 10)
  } else {
    None
  }
}

///|
fn write_code_point(buf : StringBuilder, point : Int32) -> Unit {
  if point >= 0 && point <= 0x10FFFF && !(point >= 0xD800 && point <= 0xDFFF) {
    match point.to_char() {
      Some(ch) => buf.write_char(ch)
      None => ()
    }
  }
}

///|
fn Lexer::read_hex4(self : Lexer) -> Int32? {
  if self.index + 4 > self.src.length() {
    return None
  }
  let mut value = 0
  for offset in 0..<4 {
    match hex_digit(self.peek_at(offset)) {
      Some(digit) => value = value * 16 + digit
      None => return None
    }
  }
  for _offset in 0..<4 {
    self.advance()
  }
  Some(value)
}

///|
fn Lexer::write_unicode(self : Lexer, buf : StringBuilder) -> Unit {
  match self.read_hex4() {
    None => buf.write_char('u')
    Some(high) =>
      if high >= 0xD800 &&
        high <= 0xDBFF &&
        self.peek() == code('\\') &&
        self.peek_at(1) == code('u') {
        let saved = self.index
        let saved_line = self.line
        let saved_column = self.column
        self.advance()
        self.advance()
        match self.read_hex4() {
          Some(low) if low >= 0xDC00 && low <= 0xDFFF => {
            let scalar = 0x10000 + (high - 0xD800) * 0x400 + (low - 0xDC00)
            write_code_point(buf, scalar)
          }
          _ => {
            self.index = saved
            self.line = saved_line
            self.column = saved_column
            write_code_point(buf, high)
          }
        }
      } else {
        write_code_point(buf, high)
      }
  }
}

///|
fn Lexer::write_escape(
  self : Lexer,
  buf : StringBuilder,
  escaped : Int32,
) -> Unit {
  if escaped == code('"') ||
    escaped == code('\\') ||
    escaped == code('/') ||
    escaped == code('\'') {
    write_code_point(buf, escaped)
  } else if escaped == code('b') {
    buf.write_char('\b')
  } else if escaped == code('f') {
    buf.write_char('\u{000C}')
  } else if escaped == code('n') {
    buf.write_char('\n')
  } else if escaped == code('r') {
    buf.write_char('\r')
  } else if escaped == code('t') {
    buf.write_char('\t')
  } else if escaped == code('u') {
    self.write_unicode(buf)
  } else {
    write_code_point(buf, escaped)
  }
}

///|
fn Lexer::scan_string(
  self : Lexer,
  quote : Int32,
  json_escapes : Bool,
) -> String {
  self.advance()
  let buf = StringBuilder()
  while !self.ended() {
    let current = self.peek()
    if current == code('\\') {
      self.advance()
      if self.ended() {
        break
      }
      let escaped = self.peek()
      self.advance()
      if json_escapes {
        self.write_escape(buf, escaped)
      } else if escaped == code('\'') {
        buf.write_char('\'')
      } else if escaped == code('\\') {
        buf.write_char('\\')
      } else if escaped == code('n') {
        buf.write_char('\n')
      } else if escaped == code('t') {
        buf.write_char('\t')
      } else {
        write_code_point(buf, escaped)
      }
    } else if current == quote {
      self.advance()
      break
    } else {
      let start = self.index
      while !self.ended() {
        let next = self.peek()
        if next == code('\\') || next == quote {
          break
        }
        self.advance()
      }
      buf.write_string(self.src[start:self.index].to_owned())
    }
  }
  buf.to_string()
}

///|
fn digit_value(ch : Int32) -> Double {
  Double::from_int(ch - code('0'))
}

///|
fn parse_number(text : String) -> Double {
  let length = text.length()
  let mut index = 0
  let mut sign = 1.0
  if index < length && text.unsafe_get(index).to_int() == code('-') {
    sign = -1.0
    index += 1
  }
  let mut value = 0.0
  while index < length && is_digit(text.unsafe_get(index).to_int()) {
    value = value * 10.0 + digit_value(text.unsafe_get(index).to_int())
    index += 1
  }
  if index < length && text.unsafe_get(index).to_int() == code('.') {
    index += 1
    let mut scale = 0.1
    while index < length && is_digit(text.unsafe_get(index).to_int()) {
      value = value + digit_value(text.unsafe_get(index).to_int()) * scale
      scale = scale / 10.0
      index += 1
    }
  }
  if index < length {
    let marker = text.unsafe_get(index).to_int()
    if marker == code('e') || marker == code('E') {
      index += 1
      let mut exp_sign = 1
      if index < length && text.unsafe_get(index).to_int() == code('+') {
        index += 1
      } else if index < length && text.unsafe_get(index).to_int() == code('-') {
        exp_sign = -1
        index += 1
      }
      let mut exp = 0
      let exp_start = index
      while index < length && is_digit(text.unsafe_get(index).to_int()) {
        exp = exp * 10 + (text.unsafe_get(index).to_int() - code('0'))
        index += 1
      }
      if index > exp_start {
        let mut factor = 1.0
        let mut left = exp
        while left > 0 {
          factor = factor * 10.0
          left -= 1
        }
        if exp_sign < 0 {
          value = value / factor
        } else {
          value = value * factor
        }
      }
    }
  }
  sign * value
}

///|
fn scan_ident(
  src : String,
  index : Int32,
  column : Int32,
) -> (String, Int32, Int32) {
  let length = src.length()
  let start = index
  let mut cursor = index + 1
  let mut next_column = column + 1
  while cursor < length && is_ident_continue(src.unsafe_get(cursor).to_int()) {
    cursor += 1
    next_column += 1
  }
  (src[start:cursor].to_owned(), cursor, next_column)
}

///|
fn scan_numeric(
  src : String,
  index : Int32,
  column : Int32,
) -> (String, Int32, Int32) {
  let length = src.length()
  let start = index
  let mut cursor = index
  let mut next_column = column
  if cursor < length && src.unsafe_get(cursor).to_int() == 45 {
    cursor += 1
    next_column += 1
  }
  while cursor < length && is_digit(src.unsafe_get(cursor).to_int()) {
    cursor += 1
    next_column += 1
  }
  if cursor + 1 < length &&
    src.unsafe_get(cursor).to_int() == 46 &&
    is_digit(src.unsafe_get(cursor + 1).to_int()) {
    cursor += 1
    next_column += 1
    while cursor < length && is_digit(src.unsafe_get(cursor).to_int()) {
      cursor += 1
      next_column += 1
    }
  }
  if cursor < length {
    let marker = src.unsafe_get(cursor).to_int()
    if marker == 101 || marker == 69 {
      cursor += 1
      next_column += 1
      if cursor < length {
        let sign = src.unsafe_get(cursor).to_int()
        if sign == 43 || sign == 45 {
          cursor += 1
          next_column += 1
        }
      }
      while cursor < length && is_digit(src.unsafe_get(cursor).to_int()) {
        cursor += 1
        next_column += 1
      }
    }
  }
  (src[start:cursor].to_owned(), cursor, next_column)
}

///|
/// Quotes with no escapes are one slice. Escapes and unclosed quotes use the lexer.
fn scan_quoted(
  src : String,
  index : Int32,
  line : Int32,
  column : Int32,
  quote : Int32,
  json_escapes : Bool,
) -> (String, Int32, Int32, Int32) {
  let length = src.length()
  let mut cursor = index + 1
  let mut next_line = line
  let mut next_column = column + 1
  let mut simple = true
  while cursor < length {
    let ch = src.unsafe_get(cursor).to_int()
    if ch == 92 || ch == quote {
      simple = ch == quote
      break
    }
    if ch == 10 {
      next_line += 1
      next_column = 1
    } else {
      next_column += 1
    }
    cursor += 1
  }
  if simple && cursor < length {
    next_column += 1
    (src[index + 1:cursor].to_owned(), cursor + 1, next_line, next_column)
  } else {
    let lexer = Lexer::{ src, index, line, column, }
    let text = lexer.scan_string(quote, json_escapes)
    (text, lexer.index, lexer.line, lexer.column)
  }
}

///|
fn push_token(
  tokens : Array[Token],
  kind : TokenKind,
  text : String,
  line : Int32,
  column : Int32,
) -> Unit {
  tokens.push({ kind, text, line, column, })
}

///|
fn one_char(current : Int32) -> TokenKind? {
  if current == 10 {
    Some(Newline)
  } else if current == 40 {
    Some(LParen)
  } else if current == 41 {
    Some(RParen)
  } else if current == 91 {
    Some(LBrack)
  } else if current == 93 {
    Some(RBrack)
  } else if current == 123 {
    Some(LBrace)
  } else if current == 125 {
    Some(RBrace)
  } else if current == 44 {
    Some(Comma)
  } else if current == 58 {
    Some(Colon)
  } else if current == 46 {
    Some(Dot)
  } else if current == 63 {
    Some(Question)
  } else if current == 43 {
    Some(Plus)
  } else if current == 42 {
    Some(Star)
  } else if current == 47 {
    Some(Slash)
  } else if current == 37 {
    Some(Percent)
  } else {
    None
  }
}

///|
/// Tokenize OpenUI Lang source. Newlines are tokens. Horizontal whitespace is not.
pub fn tokenize(src : String) -> Array[Token] {
  let length = src.length()
  let tokens : Array[Token] = []
  let mut index = 0
  let mut line = 1
  let mut column = 1
  while index < length {
    while index < length {
      let skipped = src.unsafe_get(index).to_int()
      if skipped == 32 || skipped == 9 || skipped == 13 {
        index += 1
        column += 1
      } else {
        break
      }
    }
    if index >= length {
      break
    }
    let current = src.unsafe_get(index).to_int()
    let tok_line = line
    let tok_column = column
    match one_char(current) {
      Some(kind) => {
        push_token(tokens, kind, "", tok_line, tok_column)
        index += 1
        if current == 10 {
          line += 1
          column = 1
        } else {
          column += 1
        }
      }
      None =>
        if current == 61 || current == 33 || current == 62 || current == 60 {
          index += 1
          column += 1
          let doubled = index < length && src.unsafe_get(index).to_int() == 61
          let kind = if current == 61 {
            if doubled {
              EqEq
            } else {
              Equals
            }
          } else if current == 33 {
            if doubled {
              NotEq
            } else {
              Not
            }
          } else if current == 62 {
            if doubled {
              GreaterEq
            } else {
              Greater
            }
          } else if doubled {
            LessEq
          } else {
            Less
          }
          if doubled {
            index += 1
            column += 1
          }
          push_token(tokens, kind, "", tok_line, tok_column)
        } else if current == 38 || current == 124 {
          let kind = if current == 38 { And } else { Or }
          push_token(tokens, kind, "", tok_line, tok_column)
          index += 1
          column += 1
          if index < length && src.unsafe_get(index).to_int() == current {
            index += 1
            column += 1
          }
        } else if current == 34 || current == 39 {
          let (text, next, next_line, next_column) = scan_quoted(
            src,
            index,
            line,
            column,
            current,
            current == 34,
          )
          push_token(tokens, Str, text, tok_line, tok_column)
          index = next
          line = next_line
          column = next_column
        } else if current == 45 &&
          (
            is_after_value(tokens) ||
            index + 1 >= length ||
            !is_digit(src.unsafe_get(index + 1).to_int())
          ) {
          push_token(tokens, Minus, "", tok_line, tok_column)
          index += 1
          column += 1
        } else if is_digit(current) ||
          (
            current == 45 &&
            index + 1 < length &&
            is_digit(src.unsafe_get(index + 1).to_int())
          ) {
          let (text, next, next_column) = scan_numeric(src, index, column)
          push_token(tokens, Num, text, tok_line, tok_column)
          index = next
          column = next_column
        } else if current == 36 &&
          index + 1 < length &&
          is_alpha(src.unsafe_get(index + 1).to_int()) {
          let (text, next, next_column) = scan_ident(src, index, column)
          push_token(tokens, StateVar, text, tok_line, tok_column)
          index = next
          column = next_column
        } else if is_alpha(current) {
          let (text, next, next_column) = scan_ident(src, index, column)
          if text == "true" {
            push_token(tokens, True, "", tok_line, tok_column)
          } else if text == "false" {
            push_token(tokens, False, "", tok_line, tok_column)
          } else if text == "null" {
            push_token(tokens, Null, "", tok_line, tok_column)
          } else if current >= 65 && current <= 90 {
            push_token(tokens, Type, text, tok_line, tok_column)
          } else {
            push_token(tokens, Ident, text, tok_line, tok_column)
          }
          index = next
          column = next_column
        } else if current == 64 &&
          index + 1 < length &&
          is_alpha(src.unsafe_get(index + 1).to_int()) {
          index += 1
          column += 1
          let (text, next, next_column) = scan_ident(src, index, column)
          push_token(tokens, BuiltinCall, text, tok_line, tok_column)
          index = next
          column = next_column
        } else {
          index += 1
          column += 1
        }
    }
  }
  tokens.push({ kind: EOF, text: "", line, column, })
  tokens
}

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
    self.src.at(self.index).to_int()
  }
}

///|
fn Lexer::peek_at(self : Lexer, offset : Int32) -> Int32 {
  let index = self.index + offset
  if index >= self.src.length() {
    -1
  } else {
    self.src.at(index).to_int()
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
fn Lexer::skip_horizontal(self : Lexer) -> Unit {
  while !self.ended() {
    let current = self.peek()
    if current == code(' ') || current == code('\t') || current == code('\r') {
      self.advance()
    } else {
      break
    }
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
  if index < length && text.at(index).to_int() == code('-') {
    sign = -1.0
    index += 1
  }
  let mut value = 0.0
  while index < length && is_digit(text.at(index).to_int()) {
    value = value * 10.0 + digit_value(text.at(index).to_int())
    index += 1
  }
  if index < length && text.at(index).to_int() == code('.') {
    index += 1
    let mut scale = 0.1
    while index < length && is_digit(text.at(index).to_int()) {
      value = value + digit_value(text.at(index).to_int()) * scale
      scale = scale / 10.0
      index += 1
    }
  }
  if index < length {
    let marker = text.at(index).to_int()
    if marker == code('e') || marker == code('E') {
      index += 1
      let mut exp_sign = 1
      if index < length && text.at(index).to_int() == code('+') {
        index += 1
      } else if index < length && text.at(index).to_int() == code('-') {
        exp_sign = -1
        index += 1
      }
      let mut exp = 0
      let exp_start = index
      while index < length && is_digit(text.at(index).to_int()) {
        exp = exp * 10 + (text.at(index).to_int() - code('0'))
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
fn Lexer::scan_number(self : Lexer) -> Unit {
  if self.peek() == code('-') {
    self.advance()
  }
  while is_digit(self.peek()) {
    self.advance()
  }
  if self.peek() == code('.') && is_digit(self.peek_at(1)) {
    self.advance()
    while is_digit(self.peek()) {
      self.advance()
    }
  }
  let marker = self.peek()
  if marker == code('e') || marker == code('E') {
    self.advance()
    let sign = self.peek()
    if sign == code('+') || sign == code('-') {
      self.advance()
    }
    while is_digit(self.peek()) {
      self.advance()
    }
  }
}

///|
fn Lexer::scan_word(self : Lexer) -> String {
  let start = self.index
  self.advance()
  while is_ident_continue(self.peek()) {
    self.advance()
  }
  self.src[start:self.index].to_owned()
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
/// Tokenize OpenUI Lang source. Newlines are tokens. Horizontal whitespace is not.
pub fn tokenize(src : String) -> Array[Token] {
  let lexer = Lexer::{ src, index: 0, line: 1, column: 1, }
  let tokens : Array[Token] = []
  while !lexer.ended() {
    lexer.skip_horizontal()
    if lexer.ended() {
      break
    }
    let current = lexer.peek()
    let line = lexer.line
    let column = lexer.column
    if current == code('\n') {
      push_token(tokens, Newline, "", line, column)
      lexer.advance()
    } else if current == code('(') {
      push_token(tokens, LParen, "", line, column)
      lexer.advance()
    } else if current == code(')') {
      push_token(tokens, RParen, "", line, column)
      lexer.advance()
    } else if current == code('[') {
      push_token(tokens, LBrack, "", line, column)
      lexer.advance()
    } else if current == code(']') {
      push_token(tokens, RBrack, "", line, column)
      lexer.advance()
    } else if current == code('{') {
      push_token(tokens, LBrace, "", line, column)
      lexer.advance()
    } else if current == code('}') {
      push_token(tokens, RBrace, "", line, column)
      lexer.advance()
    } else if current == code(',') {
      push_token(tokens, Comma, "", line, column)
      lexer.advance()
    } else if current == code(':') {
      push_token(tokens, Colon, "", line, column)
      lexer.advance()
    } else if current == code('=') {
      lexer.advance()
      if lexer.peek() == code('=') {
        push_token(tokens, EqEq, "", line, column)
        lexer.advance()
      } else {
        push_token(tokens, Equals, "", line, column)
      }
    } else if current == code('!') {
      lexer.advance()
      if lexer.peek() == code('=') {
        push_token(tokens, NotEq, "", line, column)
        lexer.advance()
      } else {
        push_token(tokens, Not, "", line, column)
      }
    } else if current == code('>') {
      lexer.advance()
      if lexer.peek() == code('=') {
        push_token(tokens, GreaterEq, "", line, column)
        lexer.advance()
      } else {
        push_token(tokens, Greater, "", line, column)
      }
    } else if current == code('<') {
      lexer.advance()
      if lexer.peek() == code('=') {
        push_token(tokens, LessEq, "", line, column)
        lexer.advance()
      } else {
        push_token(tokens, Less, "", line, column)
      }
    } else if current == code('&') {
      push_token(tokens, And, "", line, column)
      lexer.advance()
      if lexer.peek() == code('&') {
        lexer.advance()
      }
    } else if current == code('|') {
      push_token(tokens, Or, "", line, column)
      lexer.advance()
      if lexer.peek() == code('|') {
        lexer.advance()
      }
    } else if current == code('.') {
      push_token(tokens, Dot, "", line, column)
      lexer.advance()
    } else if current == code('?') {
      push_token(tokens, Question, "", line, column)
      lexer.advance()
    } else if current == code('+') {
      push_token(tokens, Plus, "", line, column)
      lexer.advance()
    } else if current == code('*') {
      push_token(tokens, Star, "", line, column)
      lexer.advance()
    } else if current == code('/') {
      push_token(tokens, Slash, "", line, column)
      lexer.advance()
    } else if current == code('%') {
      push_token(tokens, Percent, "", line, column)
      lexer.advance()
    } else if current == code('"') {
      let text = lexer.scan_string(code('"'), true)
      push_token(tokens, Str, text, line, column)
    } else if current == code('\'') {
      let text = lexer.scan_string(code('\''), false)
      push_token(tokens, Str, text, line, column)
    } else if current == code('-') &&
      (is_after_value(tokens) || !is_digit(lexer.peek_at(1))) {
      push_token(tokens, Minus, "", line, column)
      lexer.advance()
    } else if is_digit(current) ||
      (current == code('-') && is_digit(lexer.peek_at(1))) {
      let start = lexer.index
      lexer.scan_number()
      let text = lexer.src[start:lexer.index].to_owned()
      push_token(tokens, Num, text, line, column)
    } else if current == code('$') && is_alpha(lexer.peek_at(1)) {
      let text = lexer.scan_word()
      push_token(tokens, StateVar, text, line, column)
    } else if is_alpha(current) {
      let text = lexer.scan_word()
      if text == "true" {
        push_token(tokens, True, "", line, column)
      } else if text == "false" {
        push_token(tokens, False, "", line, column)
      } else if text == "null" {
        push_token(tokens, Null, "", line, column)
      } else if current >= code('A') && current <= code('Z') {
        push_token(tokens, Type, text, line, column)
      } else {
        push_token(tokens, Ident, text, line, column)
      }
    } else if current == code('@') && is_alpha(lexer.peek_at(1)) {
      lexer.advance()
      let text = lexer.scan_word()
      push_token(tokens, BuiltinCall, text, line, column)
    } else {
      lexer.advance()
    }
  }
  tokens.push({ kind: EOF, text: "", line: lexer.line, column: lexer.column, })
  tokens
}

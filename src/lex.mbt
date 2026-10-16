///|
priv struct Hold {
  mut depth : Int32
  mut quote : Int32
  mut escape : Bool
  mut open_at : Int32
  mut index : Int32
}

///|
fn Hold::new() -> Hold {
  { depth: 0, quote: 0, escape: false, open_at: -1, index: 0, }
}

///|
fn Hold::feed(self : Hold, current : Int32) -> Unit {
  self.index += 1
  if self.escape {
    self.escape = false
    return
  }
  if self.quote != 0 {
    if current == '\\'.to_int() {
      self.escape = true
    } else if current == self.quote {
      self.quote = 0
      if self.depth == 0 {
        self.open_at = -1
      }
    }
    return
  }
  if current == '"'.to_int() || current == '\''.to_int() {
    self.quote = current
    if self.depth == 0 {
      self.open_at = self.index - 1
    }
  } else if current == '('.to_int() ||
    current == '['.to_int() ||
    current == '{'.to_int() {
    if self.depth == 0 {
      self.open_at = self.index - 1
    }
    self.depth += 1
  } else if current == ')'.to_int() ||
    current == ']'.to_int() ||
    current == '}'.to_int() {
    if self.depth > 0 {
      self.depth -= 1
    }
    if self.depth == 0 {
      self.open_at = -1
    }
  }
}

///|
fn Hold::result(self : Hold) -> Int32 {
  if self.quote != 0 || self.depth > 0 {
    self.open_at
  } else {
    -1
  }
}

///|
/// Plain text is one `lexscan` match. Quotes and brackets are fed one by one.
fn skip_plain(hold : Hold, skipped : StringView) -> Unit {
  hold.index += skipped.length()
}

///|
fn scan_scanner(scanner : @lexbuf.StringScanner) -> Int32 {
  let hold = Hold::new()
  while true {
    if hold.quote != 0 && !hold.escape {
      lexscan scanner {
        re"^[^\"'\\\\]+" as skipped => skip_plain(hold, skipped)
        re"^." as mark => hold.feed(mark.to_int())
        _ => break
      }
    } else {
      lexscan scanner {
        re"^[^\"'(){}]+" as skipped => skip_plain(hold, skipped)
        re"^." as mark => hold.feed(mark.to_int())
        _ => break
      }
    }
  }
  hold.result()
}

///|
fn scan_lexbuf(input : @lexbuf.Lexbuf) -> Int32 {
  let hold = Hold::new()
  while true {
    if hold.quote != 0 && !hold.escape {
      lexscan input {
        re"^[^\"'\\\\]+" as skipped => skip_plain(hold, skipped)
        re"^." as mark => hold.feed(mark.to_int())
        _ => break
      }
    } else {
      lexscan input {
        re"^[^\"'(){}]+" as skipped => skip_plain(hold, skipped)
        re"^." as mark => hold.feed(mark.to_int())
        _ => break
      }
    }
  }
  hold.result()
}

///|
/// Outermost unclosed quote or bracket, using `lexscan` on the whole source.
fn hold_from(src : String) -> Int32 {
  let scanner = @lexbuf.StringScanner::{ data: src[:], cursor: 0, }
  scan_scanner(scanner)
}

///|
/// Same scan over chunks. `Lexbuf` refills when a token crosses a chunk boundary.
fn hold_from_chunks(chunks : Array[String]) -> Int32 {
  let mut next = 0
  let input = @lexbuf.Lexbuf::from_fn(fn() {
    if next >= chunks.length() {
      None
    } else {
      let chunk = chunks[next]
      next += 1
      Some(chunk)
    }
  })
  scan_lexbuf(input)
}

///|
/// Classify one JSON escape with `lexmatch`. Unicode escapes stay with the hex reader.
fn write_schema_escape(buf : StringBuilder, escaped : Char) -> Bool {
  lexmatch escaped.to_string() {
    re"^\"$" | re"^\\\\$" | re"^/$" => {
      buf.write_char(escaped)
      true
    }
    re"^b$" => {
      buf.write_char('\u{0008}')
      true
    }
    re"^f$" => {
      buf.write_char('\u{000c}')
      true
    }
    re"^n$" => {
      buf.write_char('\n')
      true
    }
    re"^r$" => {
      buf.write_char('\r')
      true
    }
    re"^t$" => {
      buf.write_char('\t')
      true
    }
    _ => false
  }
}

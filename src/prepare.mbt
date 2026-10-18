///|
/// Source after fence stripping, comment stripping, and auto-close.
pub struct Prepared {
  text : String
  incomplete : Bool
  empty : Bool
}

///|
fn is_space(ch : Int32) -> Bool {
  ch == code(' ') || ch == code('\t') || ch == code('\n') || ch == code('\r')
}

///|
fn trim_space(src : String) -> String {
  let mut start = 0
  let mut end = src.length()
  while start < end && is_space(src.at(start).to_int()) {
    start = start + 1
  }
  while end > start && is_space(src.at(end - 1).to_int()) {
    end = end - 1
  }
  if start == 0 && end == src.length() {
    src
  } else {
    src.unsafe_substring(start~, end~)
  }
}

///|
fn has_preprocess_marker(src : String) -> Bool {
  let mut index = 0
  let limit = src.length()
  while index < limit {
    let ch = src.at(index).to_int()
    if ch == code('#') || ch == code('`') {
      return true
    }
    if ch == code('/') &&
      index + 1 < limit &&
      src.at(index + 1).to_int() == code('/') {
      return true
    }
    index = index + 1
  }
  false
}

///|
/// Fences, comments, or a still-open quote or bracket need the official front end.
pub fn needs_normalize(src : String) -> Bool {
  has_preprocess_marker(src) || unclosed_at(src) >= 0
}

///|
fn skip_string_end(src : String, start : Int32) -> Int32 {
  if start >= src.length() || src.at(start).to_int() != code('"') {
    return start
  }
  let mut index = start + 1
  while index < src.length() {
    let ch = src.at(index).to_int()
    if ch == code('\\') {
      index = index + 2
    } else if ch == code('"') {
      return index + 1
    } else {
      index = index + 1
    }
  }
  index
}

///|
fn is_fence(src : String, index : Int32) -> Bool {
  index + 2 < src.length() &&
  src.at(index).to_int() == code('`') &&
  src.at(index + 1).to_int() == code('`') &&
  src.at(index + 2).to_int() == code('`')
}

///|
fn line_end(src : String, start : Int32) -> Int32 {
  let mut index = start
  while index < src.length() && src.at(index).to_int() != code('\n') {
    index = index + 1
  }
  index
}

///|
/// Extract fenced blocks. A fence inside a double-quoted string stays text.
fn strip_fences(src : String) -> String {
  let blocks : Array[String] = []
  let mut index = 0
  while index < src.length() {
    let mut fence = -1
    while index < src.length() {
      let next = skip_string_end(src, index)
      if next > index {
        index = next
        continue
      }
      if is_fence(src, index) {
        fence = index
        break
      }
      index = index + 1
    }
    if fence < 0 {
      break
    }
    let mut cursor = fence + 3
    let info_end = line_end(src, cursor)
    if info_end >= src.length() {
      blocks.push("")
      index = src.length()
      break
    }
    cursor = info_end + 1
    let mut close = -1
    let mut scan = cursor
    while scan < src.length() {
      let next = skip_string_end(src, scan)
      if next > scan {
        scan = next
        continue
      }
      if is_fence(src, scan) {
        close = scan
        break
      }
      scan = scan + 1
    }
    if close >= 0 {
      blocks.push(src.unsafe_substring(start=cursor, end=close))
      index = close + 3
    } else {
      blocks.push(src.unsafe_substring(start=cursor, end=src.length()))
      index = src.length()
    }
  }
  if blocks.length() > 0 {
    return join_blocks(blocks)
  }
  src
}

///|
fn join_blocks(blocks : Array[String]) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for block in blocks {
    if index > 0 {
      buf.write_char('\n')
    }
    buf.write_string(block)
    index = index + 1
  }
  buf.to_string()
}

///|
fn trim_end_line(src : String) -> String {
  let mut end = src.length()
  while end > 0 &&
        (
          src.at(end - 1).to_int() == code(' ') ||
          src.at(end - 1).to_int() == code('\t')
        ) {
    end = end - 1
  }
  if end == src.length() {
    src
  } else {
    src.unsafe_substring(start=0, end~)
  }
}

///|
/// Strip `//` and `#` comments outside strings. A quote can stay open across lines.
fn strip_comments(src : String) -> String {
  let buf = StringBuilder()
  let mut in_string = 0
  let mut line_start = 0
  let mut index = 0
  while index <= src.length() {
    let at_end = index == src.length()
    let ch = if at_end { code('\n') } else { src.at(index).to_int() }
    if ch == code('\n') || at_end {
      let line = src.unsafe_substring(start=line_start, end=index)
      buf.write_string(comment_free(line, in_string))
      let (kept, next_string) = comment_scan(line, in_string)
      in_string = next_string
      let _kept = kept
      if ch == code('\n') && !at_end {
        buf.write_char('\n')
      }
      line_start = index + 1
      index = index + 1
      continue
    }
    index = index + 1
  }
  buf.to_string()
}

///|
fn comment_scan(line : String, in_string : Int32) -> (String, Int32) {
  let mut quote = in_string
  let mut index = 0
  while index < line.length() {
    let ch = line.at(index).to_int()
    if quote != 0 {
      if ch == code('\\') && index + 1 < line.length() {
        index = index + 2
        continue
      }
      if ch == quote {
        quote = 0
      }
      index = index + 1
      continue
    }
    if ch == code('"') || ch == code('\'') {
      quote = ch
      index = index + 1
      continue
    }
    if ch == code('/') &&
      index + 1 < line.length() &&
      line.at(index + 1).to_int() == code('/') {
      return (trim_end_line(line.unsafe_substring(start=0, end=index)), quote)
    }
    if ch == code('#') {
      return (trim_end_line(line.unsafe_substring(start=0, end=index)), quote)
    }
    index = index + 1
  }
  (line, quote)
}

///|
fn comment_free(line : String, in_string : Int32) -> String {
  let (text, _) = comment_scan(line, in_string)
  text
}

///|
/// Clean an LLM response the way official `preprocess` does.
pub fn preprocess(src : String) -> String {
  trim_space(strip_comments(strip_fences(trim_space(src))))
}

///|
fn write_code(buf : StringBuilder, ch : Int32) -> Unit {
  if ch == code(')') {
    buf.write_char(')')
  } else if ch == code(']') {
    buf.write_char(']')
  } else if ch == code('}') {
    buf.write_char('}')
  } else if ch == code('"') {
    buf.write_char('"')
  } else if ch == code('\'') {
    buf.write_char('\'')
  } else if ch == code('\\') {
    buf.write_char('\\')
  }
}

///|
fn closer_for(opener : Int32) -> Int32 {
  if opener == code('(') {
    code(')')
  } else if opener == code('[') {
    code(']')
  } else {
    code('}')
  }
}

///|
/// Close an open string and the still-open brackets, matching official `autoClose`.
pub fn auto_close(src : String) -> Prepared {
  let stack : Array[Int32] = []
  let mut in_string = 0
  let mut escaped = false
  let mut index = 0
  while index < src.length() {
    let ch = src.at(index).to_int()
    if escaped {
      escaped = false
    } else if ch == code('\\') && in_string != 0 {
      escaped = true
    } else if in_string != 0 {
      if ch == in_string {
        in_string = 0
      }
    } else if ch == code('"') || ch == code('\'') {
      in_string = ch
    } else if ch == code('(') || ch == code('[') || ch == code('{') {
      stack.push(ch)
    } else if ch == code(')') &&
      stack.length() > 0 &&
      stack[stack.length() - 1] == code('(') {
      let _ = stack.pop()
    } else if ch == code(']') &&
      stack.length() > 0 &&
      stack[stack.length() - 1] == code('[') {
      let _ = stack.pop()
    } else if ch == code('}') &&
      stack.length() > 0 &&
      stack[stack.length() - 1] == code('{') {
      let _ = stack.pop()
    }
    index = index + 1
  }
  if in_string == 0 && stack.length() == 0 {
    return { text: src, incomplete: false, empty: false, }
  }
  let buf = StringBuilder()
  buf.write_string(src)
  if in_string != 0 {
    if escaped {
      write_code(buf, code('\\'))
    }
    write_code(buf, in_string)
  }
  let mut cursor = stack.length() - 1
  while cursor >= 0 {
    write_code(buf, closer_for(stack[cursor]))
    cursor = cursor - 1
  }
  { text: buf.to_string(), incomplete: true, empty: false, }
}

///|
/// Official `autoClose` payload. `incomplete` maps to `wasIncomplete` on the host.
pub fn auto_close_json(src : String) -> String {
  let closed = auto_close(src)
  let buf = StringBuilder()
  buf.write_string("{\"text\":")
  buf.write_string(Json::string(closed.text).stringify())
  buf.write_string(",\"incomplete\":")
  if closed.incomplete {
    buf.write_string("true")
  } else {
    buf.write_string("false")
  }
  buf.write_string("}")
  buf.to_string()
}

///|
/// Official front end: blank input is an empty result, and partial input is closed before parsing.
pub fn normalize_source(src : String) -> Prepared {
  if trim_space(src).length() == 0 {
    return { text: "", incomplete: true, empty: true, }
  }
  if !needs_normalize(src) {
    return { text: src, incomplete: false, empty: false, }
  }
  let cleaned = preprocess(src)
  if cleaned.length() == 0 {
    return { text: "", incomplete: true, empty: true, }
  }
  let closed = auto_close(cleaned)
  { text: closed.text, incomplete: closed.incomplete, empty: false, }
}

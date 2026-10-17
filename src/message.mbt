///|
/// Split an OpenUI message on `]]>openui:` markers.
/// `streaming` holds back a marker that is still arriving.
pub fn parse_message(raw : String, streaming : Bool) -> String {
  let text = cut_partial_marker(insert_content_breaks(raw), streaming)
  let lines = split_lines(text)
  let last = lines[lines.length() - 1]
  let held = streaming && is_held_line(last)
  if held {
    ignore(lines.pop())
  }
  let sections : Array[Section] = [{ kind: "", attributes: [], lines: [], }]
  let mut end_at = -1
  let mut index = 0
  while index < lines.length() {
    let raw = lines[index]
    match marker_of(strip_cr(raw)) {
      None => sections[sections.length() - 1].lines.push(raw)
      Some((kind, query)) => {
        close_section(sections[sections.length() - 1])
        if kind == "end" {
          end_at = sections.length() - 1
          if index == lines.length() - 2 && lines[index + 1].length() == 0 {
            break
          }
        } else {
          sections.push({ kind, attributes: read_attributes(query), lines: [], })
        }
      }
    }
    index = index + 1
  }
  if held && sections.length() > 0 {
    close_section(sections[sections.length() - 1])
  }
  let win = {
    let found = last_kind(sections, "content")
    if found < 0 {
      0
    } else {
      found
    }
  }
  let ctx = last_kind(sections, "context")
  let buf = StringBuilder()
  buf.write_string("{\"content\":")
  write_json_string(buf, join_lines(sections[win].lines))
  buf.write_string(",\"context\":")
  if ctx > win {
    let body = join_lines(sections[ctx].lines)
    if json_text(body) {
      buf.write_string(body)
    } else {
      write_json_string(buf, body)
    }
  } else {
    buf.write_string("null")
  }
  buf.write_string(",\"attributes\":{")
  let mut attr = 0
  for pair in sections[win].attributes {
    if attr > 0 {
      buf.write_char(',')
    }
    let (key, value) = pair
    write_json_string(buf, key)
    buf.write_char(':')
    write_json_string(buf, value)
    attr = attr + 1
  }
  buf.write_string("},\"end\":")
  if end_at >= win {
    buf.write_string("true")
  } else {
    buf.write_string("false")
  }
  buf.write_char('}')
  buf.to_string()
}

///|
priv struct Section {
  kind : String
  attributes : Array[(String, String)]
  lines : Array[String]
}

///|
fn split_lines(src : String) -> Array[String] {
  let lines : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < src.length() {
    if src.at(index).to_int() == code('\n') {
      lines.push(src.unsafe_substring(start~, end=index))
      start = index + 1
    }
    index = index + 1
  }
  lines.push(src.unsafe_substring(start~, end=src.length()))
  lines
}

///|
fn starts_with_at(src : String, index : Int32, prefix : String) -> Bool {
  let mut offset = 0
  while offset < prefix.length() {
    if index + offset >= src.length() {
      return false
    }
    if src.at(index + offset).to_int() != prefix.at(offset).to_int() {
      return false
    }
    offset = offset + 1
  }
  true
}

///|
fn host_starts_with(host : String, text : String) -> Bool {
  text.length() <= host.length() && starts_with_at(host, 0, text)
}

///|
fn insert_content_breaks(src : String) -> String {
  let marker = "]]>openui:content"
  let buf = StringBuilder()
  let mut index = 0
  let limit = src.length()
  while index < limit {
    let ch = src.at(index).to_int()
    let after = index + 1 + marker.length()
    let mut boundary = false
    if ch != code('\n') && starts_with_at(src, index + 1, marker) {
      if after >= limit {
        boundary = true
      } else {
        let next = src.at(after).to_int()
        boundary = next == code('?') ||
          next == code('\n') ||
          (
            next == code('\r') &&
            after + 1 < limit &&
            src.at(after + 1).to_int() == code('\n')
          )
      }
    }
    buf.write_char(ch.unsafe_to_char())
    if boundary {
      buf.write_char('\n')
    }
    index = index + 1
  }
  buf.to_string()
}

///|
fn cut_partial_marker(src : String, streaming : Bool) -> String {
  if !streaming {
    return src
  }
  let limit = src.length()
  if limit < 4 {
    return src
  }
  let mut index = limit
  while index > 0 {
    let ch = src.at(index - 1).to_int()
    if (ch >= code('a') && ch <= code('z')) || ch == code(':') {
      index = index - 1
    } else {
      break
    }
  }
  if index < 3 || !starts_with_at(src, index - 3, "]]>") {
    return src
  }
  let marker_at = index - 3
  if marker_at == 0 || src.at(marker_at - 1).to_int() == code('\n') {
    return src
  }
  let capture = src.unsafe_substring(start=marker_at, end=limit)
  if !host_starts_with("]]>openui:content", capture) {
    return src
  }
  src.unsafe_substring(start=0, end=marker_at)
}

///|
fn is_held_line(line : String) -> Bool {
  line.length() > 0 &&
  (
    starts_with_at(line, 0, "]]>openui:") ||
    host_starts_with("]]>openui:", line)
  )
}

///|
fn strip_cr(line : String) -> String {
  let limit = line.length()
  if limit > 0 && line.at(limit - 1).to_int() == code('\r') {
    line.unsafe_substring(start=0, end=limit - 1)
  } else {
    line
  }
}

///|
fn marker_of(line : String) -> (String, String)? {
  let prefix = "]]>openui:"
  if !starts_with_at(line, 0, prefix) {
    return None
  }
  let mut index = prefix.length()
  let kind_at = index
  while index < line.length() {
    let ch = line.at(index).to_int()
    if ch >= code('a') && ch <= code('z') {
      index = index + 1
    } else {
      break
    }
  }
  if index == kind_at {
    return None
  }
  let kind = line.unsafe_substring(start=kind_at, end=index)
  if index == line.length() {
    Some((kind, ""))
  } else if line.at(index).to_int() == code('?') {
    Some((kind, line.unsafe_substring(start=index + 1, end=line.length())))
  } else {
    None
  }
}

///|
fn utf8_append(buf : StringBuilder, bytes : Array[Int32]) -> Bool {
  let mut index = 0
  while index < bytes.length() {
    let lead = bytes[index]
    let (need, min) = if lead < 0x80 {
      (1, 0)
    } else if lead >= 0xC2 && lead <= 0xDF {
      (2, 0x80)
    } else if lead >= 0xE0 && lead <= 0xEF {
      (3, 0x800)
    } else if lead >= 0xF0 && lead <= 0xF4 {
      (4, 0x10000)
    } else {
      return false
    }
    if index + need > bytes.length() {
      return false
    }
    let mut point = if need == 2 {
      lead & 0x1F
    } else if need == 3 {
      lead & 0x0F
    } else if need == 4 {
      lead & 0x07
    } else {
      lead
    }
    let mut step = 1
    while step < need {
      let next = bytes[index + step]
      if next < 0x80 || next > 0xBF {
        return false
      }
      point = (point << 6) | (next & 0x3F)
      step = step + 1
    }
    if point < min || point > 0x10FFFF || (point >= 0xD800 && point <= 0xDFFF) {
      return false
    }
    write_code_point(buf, point)
    index = index + need
  }
  true
}

///|
fn percent_decode(src : String) -> String {
  let buf = StringBuilder()
  let bytes : Array[Int32] = []
  let mut index = 0
  while index < src.length() {
    let ch = src.at(index).to_int()
    if ch == code('%') {
      if index + 2 >= src.length() {
        return src
      }
      match
        (
          hex_digit(src.at(index + 1).to_int()),
          hex_digit(src.at(index + 2).to_int()),
        ) {
        (Some(hi), Some(lo)) => bytes.push((hi << 4) | lo)
        _ => return src
      }
      index = index + 3
    } else {
      if !utf8_append(buf, bytes) {
        return src
      }
      bytes.clear()
      if ch == code('+') {
        buf.write_char(' ')
      } else {
        buf.write_char(ch.unsafe_to_char())
      }
      index = index + 1
    }
  }
  if !utf8_append(buf, bytes) {
    return src
  }
  buf.to_string()
}

///|
fn read_attributes(query : String) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  if query.length() == 0 {
    return pairs
  }
  let mut start = 0
  let mut index = 0
  while index <= query.length() {
    if index == query.length() || query.at(index).to_int() == code('&') {
      let pair = query.unsafe_substring(start~, end=index)
      let mut eq = 0
      let mut found = false
      while eq < pair.length() {
        if pair.at(eq).to_int() == code('=') {
          found = true
          break
        }
        eq = eq + 1
      }
      let key = if found {
        percent_decode(pair.unsafe_substring(start=0, end=eq))
      } else {
        percent_decode(pair)
      }
      if key.length() > 0 {
        let value = if found {
          percent_decode(pair.unsafe_substring(start=eq + 1, end=pair.length()))
        } else {
          ""
        }
        pairs.push((key, value))
      }
      start = index + 1
    }
    index = index + 1
  }
  pairs
}

///|
fn close_section(section : Section) -> Unit {
  let count = section.lines.length()
  if count == 0 {
    return
  }
  let last = section.lines[count - 1]
  let stripped = strip_cr(last)
  if stripped.length() == last.length() {
    return
  }
  let next : Array[String] = []
  let mut index = 0
  while index < count - 1 {
    next.push(section.lines[index])
    index = index + 1
  }
  next.push(stripped)
  section.lines.clear()
  for line in next {
    section.lines.push(line)
  }
}

///|
fn last_kind(sections : Array[Section], kind : String) -> Int32 {
  let mut index = sections.length() - 1
  while index >= 0 {
    if sections[index].kind == kind {
      return index
    }
    index = index - 1
  }
  -1
}

///|
fn join_lines(lines : Array[String]) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for line in lines {
    if index > 0 {
      buf.write_char('\n')
    }
    buf.write_string(line)
    index = index + 1
  }
  buf.to_string()
}

///|
fn json_text(text : String) -> Bool {
  try {
    ignore(@json.parse(text))
    true
  } catch {
    _ => false
  }
}

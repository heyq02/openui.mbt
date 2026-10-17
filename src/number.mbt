///|
/// `resolveField` segments and `toNumber` conversions. The host reads properties and keeps number bits.
fn segments_json(path : String) -> String {
  let buf = StringBuilder()
  buf.write_char('[')
  let mut first = true
  let mut start : Int32 = 0
  let mut index : Int32 = 0
  let limit = path.length()
  while index <= limit {
    let at_end = index == limit
    let is_dot = if at_end { false } else { path.at(index).to_int() == 46 }
    if at_end || is_dot {
      if !first {
        buf.write_char(',')
      }
      first = false
      buf.write_string(Json::string(copy_units(path, start, index)).stringify())
      start = index + 1
    }
    index = index + 1
  }
  buf.write_char(']')
  buf.to_string()
}

///|
/// Dot segments of a field path, in order. An empty path is one empty segment.
pub fn resolve_field(path_json : String) -> String {
  try {
    match @json.parse(path_json) {
      String(path) => segments_json(path)
      _ => "[]"
    }
  } catch {
    _ => "[]"
  }
}

///|
/// `toNumber` for a tagged value. `NaN` from a string becomes `0`.
pub fn to_number(value_json : String) -> String {
  num_json(to_num(@json.parse(value_json))) catch {
    _ => "{\"t\":\"n\",\"v\":0}"
  }
}

///|
/// Statement ranges for the official numeric token stream.
/// `?` after a top-level newline keeps the statement open. A following `:` does not,
/// because that check only runs while the ternary depth is already zero.
fn split_continues(next_t : Int32, ternary : Int32) -> Bool {
  next_t == 34 || (next_t == 8 && ternary > 0)
}

///|
fn split_code(value : Json) -> Int32 {
  match value {
    Number(number, ..) =>
      if number < 0.0 || number > 35.0 {
        -1
      } else {
        let code = number.to_int()
        if code.to_double() == number {
          code
        } else {
          -1
        }
      }
    _ => -1
  }
}

///|
fn split_write(
  buf : StringBuilder,
  id_at : Int32,
  id_type : Int32,
  indices : Array[Int32],
) -> Unit {
  buf.write_string("{\"idAt\":")
  buf.write_string(id_at.to_string())
  buf.write_string(",\"t\":")
  buf.write_string(id_type.to_string())
  buf.write_string(",\"ix\":[")
  let mut first = true
  for index in indices {
    if !first {
      buf.write_char(',')
    }
    first = false
    buf.write_string(index.to_string())
  }
  buf.write_string("]}")
}

///|
fn split_encode(types : Array[Int32]) -> String {
  let limit = types.length()
  let mut pos : Int32 = 0
  let buf = StringBuilder()
  buf.write_char('[')
  let mut first = true
  while pos < limit {
    while pos < limit && types[pos] == 0 {
      pos = pos + 1
    }
    if pos >= limit || types[pos] == 13 {
      break
    }
    let tok = types[pos]
    if tok != 16 && tok != 17 && tok != 18 {
      while pos < limit && types[pos] != 0 && types[pos] != 13 {
        pos = pos + 1
      }
      continue
    }
    let id_at = pos
    let id_type = tok
    pos = pos + 1
    if pos >= limit || types[pos] != 9 {
      while pos < limit && types[pos] != 0 && types[pos] != 13 {
        pos = pos + 1
      }
      continue
    }
    pos = pos + 1
    let indices : Array[Int32] = []
    let mut depth : Int32 = 0
    let mut ternary : Int32 = 0
    while pos < limit && types[pos] != 13 {
      let tt = types[pos]
      if tt == 0 && depth <= 0 && ternary <= 0 {
        let mut peek = pos + 1
        while peek < limit && types[peek] == 0 {
          peek = peek + 1
        }
        let next_t = if peek < limit { types[peek] } else { 13 }
        if split_continues(next_t, ternary) {
          pos = pos + 1
          continue
        }
        break
      }
      if tt == 0 {
        pos = pos + 1
        continue
      }
      if tt == 1 || tt == 3 || tt == 5 {
        depth = depth + 1
      } else if (tt == 2 || tt == 4 || tt == 6) && depth > 0 {
        depth = depth - 1
      } else if tt == 34 && depth == 0 {
        ternary = ternary + 1
      } else if tt == 8 && depth == 0 && ternary > 0 {
        ternary = ternary - 1
      }
      indices.push(pos)
      pos = pos + 1
    }
    if indices.length() > 0 {
      if !first {
        buf.write_char(',')
      }
      first = false
      split_write(buf, id_at, id_type, indices)
    }
  }
  buf.write_char(']')
  buf.to_string()
}

///|
/// `split()` ranges. Each item is the identifier index, its token code, and the
/// expression indexes. Newlines stay out of the expression, including ones that
/// only kept the statement open.
pub fn split_ranges(types_json : String) -> String {
  try {
    match @json.parse(types_json) {
      Array(items) => {
        let types : Array[Int32] = []
        for item in items {
          types.push(split_code(item))
        }
        split_encode(types)
      }
      _ => "[]"
    }
  } catch {
    _ => "[]"
  }
}

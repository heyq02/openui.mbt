///|
/// Eager built-in calls. `Sort` and `Filter` stay in JavaScript for `localeCompare` and `==`.
priv enum Num {
  NNan
  PInf
  NInf
  Neg0
  NFin(Double)
}

///|
fn builtin_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn builtin_tag(value : Json) -> String {
  match builtin_field(value, "t") {
    Some(String(tag)) => tag
    _ => ""
  }
}

///|
fn builtin_string(value : Json) -> String {
  match builtin_field(value, "v") {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn builtin_items(value : Json) -> Array[Json] {
  match builtin_field(value, "v") {
    Some(Array(items)) => items
    _ => []
  }
}

///|
fn is_neg_zero(number : Double) -> Bool {
  number == 0.0 && 1.0 / number < 0.0
}

///|
fn finite_num(number : Double) -> Num {
  if is_neg_zero(number) {
    Neg0
  } else {
    NFin(number)
  }
}

///|
fn bound_num(bound : Bound) -> Num {
  match bound {
    Nan => NFin(0.0)
    PosInf => PInf
    NegInf => NInf
    Bound::Finite(number) => finite_num(number)
  }
}

///|
fn to_num(value : Json) -> Num {
  match builtin_tag(value) {
    "nan" => NNan
    "pinf" => PInf
    "ninf" => NInf
    "n0" => Neg0
    "n" =>
      match builtin_field(value, "v") {
        Some(Number(number, ..)) => finite_num(number)
        _ => NFin(0.0)
      }
    "b" =>
      match builtin_field(value, "v") {
        Some(True) => NFin(1.0)
        _ => NFin(0.0)
      }
    "s" => bound_num(parse_js_number(builtin_string(value)))
    _ => NFin(0.0)
  }
}

///|
fn add_num(left : Num, right : Num) -> Num {
  match (left, right) {
    (NNan, _) | (_, NNan) => NNan
    (PInf, NInf) | (NInf, PInf) => NNan
    (PInf, _) | (_, PInf) => PInf
    (NInf, _) | (_, NInf) => NInf
    (Neg0, Neg0) => Neg0
    (Neg0, NFin(number)) => finite_num(number)
    (NFin(number), Neg0) => finite_num(number)
    (NFin(left_number), NFin(right_number)) =>
      finite_num(left_number + right_number)
  }
}

///|
fn div_num(left : Num, right : Double) -> Num {
  match left {
    NNan => NNan
    PInf => if right < 0.0 { NInf } else if right == 0.0 { NNan } else { PInf }
    NInf => if right < 0.0 { PInf } else if right == 0.0 { NNan } else { NInf }
    Neg0 => if right < 0.0 { Neg0 } else { NFin(0.0) }
    NFin(number) =>
      if right == 0.0 {
        if number == 0.0 {
          NNan
        } else if number < 0.0 {
          NInf
        } else {
          PInf
        }
      } else {
        finite_num(number / right)
      }
  }
}

///|
fn min_num(left : Num, right : Num) -> Num {
  match (left, right) {
    (NNan, _) | (_, NNan) => NNan
    (NInf, _) | (_, NInf) => NInf
    (PInf, other) | (other, PInf) => other
    (Neg0, NFin(number)) | (NFin(number), Neg0) =>
      if number < 0.0 {
        NFin(number)
      } else {
        Neg0
      }
    (Neg0, Neg0) => Neg0
    (NFin(left_number), NFin(right_number)) =>
      if left_number <= right_number {
        NFin(left_number)
      } else {
        NFin(right_number)
      }
  }
}

///|
fn max_num(left : Num, right : Num) -> Num {
  match (left, right) {
    (NNan, _) | (_, NNan) => NNan
    (PInf, _) | (_, PInf) => PInf
    (NInf, other) | (other, NInf) => other
    (Neg0, NFin(number)) | (NFin(number), Neg0) =>
      if number > 0.0 || (number == 0.0 && !is_neg_zero(number)) {
        NFin(number)
      } else {
        Neg0
      }
    (Neg0, Neg0) => Neg0
    (NFin(left_number), NFin(right_number)) =>
      if left_number >= right_number {
        NFin(left_number)
      } else {
        NFin(right_number)
      }
  }
}

///|
fn floor_num(value : Num) -> Num {
  match value {
    NFin(number) => finite_num(number.floor())
    other => other
  }
}

///|
fn ceil_num(value : Num) -> Num {
  match value {
    NFin(number) => finite_num(number.ceil())
    other => other
  }
}

///|
fn abs_num(value : Num) -> Num {
  match value {
    NNan => NNan
    NInf => PInf
    Neg0 => NFin(0.0)
    NFin(number) => if number < 0.0 { NFin(-number) } else { NFin(number) }
    other => other
  }
}

///|
fn round_num(value : Num) -> Num {
  match value {
    NFin(number) => finite_num((number + 0.5).floor())
    other => other
  }
}

///|
fn pow10(exponent : Double) -> Double {
  if exponent == 0.0 {
    return 1.0
  }
  let whole = exponent.floor()
  if whole != exponent || exponent > 12.0 || exponent < -12.0 {
    return @math.pow(10.0, exponent)
  }
  let mut factor = 1.0
  let mut count = 0.0
  let steps = if exponent < 0.0 { -exponent } else { exponent }
  while count < steps {
    factor = factor * 10.0
    count = count + 1.0
  }
  if exponent < 0.0 {
    1.0 / factor
  } else {
    factor
  }
}

///|
fn kept_items(items : Array[Json]) -> Array[Json] {
  let out = []
  for item in items {
    if builtin_tag(item) != "hole" {
      out.push(item)
    }
  }
  out
}

///|
fn sum_items(items : Array[Json]) -> Num {
  let mut total = NFin(0.0)
  for item in kept_items(items) {
    total = add_num(total, to_num(item))
  }
  total
}

///|
fn classify(number : Double) -> Num {
  if number.is_nan() {
    NNan
  } else if number == 1.0 / 0.0 {
    PInf
  } else if number == -1.0 / 0.0 {
    NInf
  } else {
    finite_num(number)
  }
}

///|
fn num_json(value : Num) -> String {
  match value {
    NNan => "{\"t\":\"nan\"}"
    PInf => "{\"t\":\"pinf\"}"
    NInf => "{\"t\":\"ninf\"}"
    Neg0 => "{\"t\":\"n0\"}"
    NFin(number) =>
      match classify(number) {
        NFin(value) => "{\"t\":\"n\",\"v\":" + value.to_string() + "}"
        other => num_json(other)
      }
  }
}

///|
fn index_json(index : Int32) -> String {
  "{\"t\":\"index\",\"i\":" + index.to_string() + "}"
}

///|
fn array_of(args : Json, key : String) -> Json? {
  match builtin_field(args, key) {
    Some(value) => if builtin_tag(value) == "a" { Some(value) } else { None }
    None => None
  }
}

///|
fn widen(value : Num) -> Double {
  match value {
    NNan => 0.0 / 0.0
    PInf => 1.0 / 0.0
    NInf => -1.0 / 0.0
    Neg0 => -0.0
    NFin(number) => number
  }
}

///|
fn round_call(args : Json) -> String {
  let number = match builtin_field(args, "number") {
    Some(value) => to_num(value)
    None => NFin(0.0)
  }
  let decimals = match builtin_field(args, "decimals") {
    Some(value) =>
      if builtin_tag(value) == "null" || builtin_tag(value) == "u" {
        NFin(0.0)
      } else {
        to_num(value)
      }
    None => NFin(0.0)
  }
  let factor = pow10(widen(decimals))
  let scaled = widen(number) * factor
  match round_num(classify(scaled)) {
    NFin(value) => num_json(classify(value / factor))
    Neg0 => num_json(classify(-0.0 / factor))
    other => num_json(other)
  }
}

///|
fn dispatch_builtin(name : String, args : Json) -> String {
  if name == "Count" {
    match array_of(args, "array") {
      Some(value) => num_json(NFin(builtin_items(value).length().to_double()))
      None => "{\"t\":\"n\",\"v\":0}"
    }
  } else if name == "First" {
    match array_of(args, "array") {
      Some(value) =>
        if builtin_items(value).length() == 0 {
          "{\"t\":\"null\"}"
        } else {
          index_json(0)
        }
      None => "{\"t\":\"null\"}"
    }
  } else if name == "Last" {
    match array_of(args, "array") {
      Some(value) => {
        let count = builtin_items(value).length()
        if count == 0 {
          "{\"t\":\"null\"}"
        } else {
          index_json(count - 1)
        }
      }
      None => "{\"t\":\"null\"}"
    }
  } else if name == "Sum" {
    match array_of(args, "numbers") {
      Some(value) => num_json(sum_items(builtin_items(value)))
      None => "{\"t\":\"n\",\"v\":0}"
    }
  } else if name == "Avg" {
    match array_of(args, "numbers") {
      Some(value) => {
        let items = builtin_items(value)
        if items.length() == 0 {
          "{\"t\":\"n\",\"v\":0}"
        } else {
          num_json(div_num(sum_items(items), items.length().to_double()))
        }
      }
      None => "{\"t\":\"n\",\"v\":0}"
    }
  } else if name == "Min" || name == "Max" {
    match array_of(args, "numbers") {
      Some(value) => {
        let items = builtin_items(value)
        if items.length() == 0 {
          "{\"t\":\"n\",\"v\":0}"
        } else {
          let mut total = to_num(items[0])
          for item in kept_items(items) {
            total = if name == "Min" {
              min_num(total, to_num(item))
            } else {
              max_num(total, to_num(item))
            }
          }
          num_json(total)
        }
      }
      None => "{\"t\":\"n\",\"v\":0}"
    }
  } else if name == "Abs" {
    match builtin_field(args, "number") {
      Some(value) => num_json(abs_num(to_num(value)))
      None => "{\"t\":\"n\",\"v\":0}"
    }
  } else if name == "Floor" {
    match builtin_field(args, "number") {
      Some(value) => num_json(floor_num(to_num(value)))
      None => "{\"t\":\"n\",\"v\":0}"
    }
  } else if name == "Ceil" {
    match builtin_field(args, "number") {
      Some(value) => num_json(ceil_num(to_num(value)))
      None => "{\"t\":\"n\",\"v\":0}"
    }
  } else if name == "Round" {
    round_call(args)
  } else {
    "{\"t\":\"js\"}"
  }
}

///|
/// Evaluate one eager built-in from tagged arguments.
pub fn call_builtin(name : String, args_json : String) -> String {
  dispatch_builtin(name, @json.parse(args_json)) catch {
    _ => "{\"t\":\"js\"}"
  }
}

///|
fn kind_at(items : Array[Json], index : Int32) -> String {
  if index < items.length() {
    match items[index] {
      String(text) => text
      _ => ""
    }
  } else {
    ""
  }
}

///|
/// `Run`, `Set`, and `Reset` decide from argument kinds. The host keeps the AST nodes.
pub fn lazy_step(name : String, kinds_json : String) -> String {
  try {
    match @json.parse(kinds_json) {
      Array(items) =>
        if name == "Run" {
          if kind_at(items, 0) == "RuntimeRef" {
            "{\"op\":\"run\"}"
          } else {
            "{\"op\":\"none\"}"
          }
        } else if name == "Set" {
          if items.length() >= 2 && kind_at(items, 0) == "StateRef" {
            "{\"op\":\"set\"}"
          } else {
            "{\"op\":\"none\"}"
          }
        } else if name == "Reset" {
          let buf = StringBuilder()
          buf.write_string("{\"op\":\"reset\",\"at\":[")
          let mut count = 0
          let mut index = 0
          for item in items {
            if kind_at([item], 0) == "StateRef" {
              if count > 0 {
                buf.write_char(',')
              }
              buf.write_string(index.to_string())
              count = count + 1
            }
            index = index + 1
          }
          buf.write_string("]}")
          if count == 0 {
            "{\"op\":\"none\"}"
          } else {
            buf.to_string()
          }
        } else {
          "{\"op\":\"none\"}"
        }
      _ => "{\"op\":\"none\"}"
    }
  } catch {
    _ => "{\"op\":\"none\"}"
  }
}

///|
/// OpenUI field rules: `parseRules`, `parseStructuredRules`, built-in checks, and error hints.
/// `url` and `pattern` stay in JavaScript so they use `URL` and `RegExp`.
priv enum Bound {
  Nan
  PosInf
  NegInf
  Finite(Double)
}

///|
fn is_js_space(unit : Int32) -> Bool {
  if unit == 0x09 ||
    unit == 0x0A ||
    unit == 0x0B ||
    unit == 0x0C ||
    unit == 0x0D {
    true
  } else if unit == 0x20 ||
    unit == 0xA0 ||
    unit == 0x1680 ||
    unit == 0x2028 ||
    unit == 0x2029 {
    true
  } else if unit == 0x202F || unit == 0x205F || unit == 0x3000 || unit == 0xFEFF {
    true
  } else {
    unit >= 0x2000 && unit <= 0x200A
  }
}

///|
fn unit_at(src : String, index : Int32) -> Int32 {
  src.at(index).to_int()
}

///|
fn write_unit(buf : StringBuilder, unit : Int32) -> Unit {
  buf.write_char(unit.unsafe_to_char())
}

///|
fn copy_units(src : String, start : Int32, end : Int32) -> String {
  let buf = StringBuilder()
  let mut index = start
  while index < end {
    write_unit(buf, unit_at(src, index))
    index = index + 1
  }
  buf.to_string()
}

///|
fn trim_copy(src : String) -> String {
  let limit = src.length()
  let mut start = 0
  while start < limit && is_js_space(unit_at(src, start)) {
    start = start + 1
  }
  let mut end = limit
  while end > start && is_js_space(unit_at(src, end - 1)) {
    end = end - 1
  }
  copy_units(src, start, end)
}

///|
fn trim_empty(src : String) -> Bool {
  let mut index = 0
  let limit = src.length()
  while index < limit {
    if !is_js_space(unit_at(src, index)) {
      return false
    }
    index = index + 1
  }
  true
}

///|
fn take_digits(src : String, index : Int32, buf : StringBuilder) -> Int32 {
  let mut next = index
  let limit = src.length()
  while next < limit {
    let unit = unit_at(src, next)
    if unit >= code('0') && unit <= code('9') {
      write_unit(buf, unit)
      next = next + 1
    } else {
      break
    }
  }
  next
}

///|
fn strip_zeros(digits : String) -> String {
  if digits.length() == 0 {
    return "0"
  }
  let mut index = 0
  let limit = digits.length()
  while index + 1 < limit && unit_at(digits, index) == code('0') {
    index = index + 1
  }
  copy_units(digits, index, limit)
}

///|
fn json_number(literal : String) -> Bound {
  try {
    match @json.parse(literal) {
      Number(value, ..) =>
        if value.is_pos_inf() {
          PosInf
        } else if value.is_neg_inf() {
          NegInf
        } else {
          Finite(value)
        }
      _ => Nan
    }
  } catch {
    _ => Nan
  }
}

///|
fn decimal_literal(
  neg : Bool,
  int_digits : String,
  saw_dot : Bool,
  frac_digits : String,
  saw_exp : Bool,
  exp_neg : Bool,
  exp_digits : String,
) -> String {
  let buf = StringBuilder()
  if neg {
    buf.write_char('-')
  }
  buf.write_string(strip_zeros(int_digits))
  if saw_dot {
    buf.write_char('.')
    if frac_digits.length() == 0 {
      buf.write_char('0')
    } else {
      buf.write_string(frac_digits)
    }
  }
  if saw_exp {
    buf.write_char('e')
    if exp_neg {
      buf.write_char('-')
    }
    buf.write_string(exp_digits)
  }
  buf.to_string()
}

///|
fn starts_with_infinity(src : String, index : Int32) -> Bool {
  let word = "Infinity"
  let mut offset = 0
  while offset < word.length() {
    if index + offset >= src.length() {
      return false
    }
    if unit_at(src, index + offset) != unit_at(word, offset) {
      return false
    }
    offset = offset + 1
  }
  true
}

///|
fn digit_of(unit : Int32, base : Int32) -> Int32? {
  let value = if unit >= code('0') && unit <= code('9') {
    unit - code('0')
  } else if unit >= code('a') && unit <= code('f') {
    unit - code('a') + 10
  } else if unit >= code('A') && unit <= code('F') {
    unit - code('A') + 10
  } else {
    -1
  }
  if value >= 0 && value < base {
    Some(value)
  } else {
    None
  }
}

///|
fn parse_prefixed(src : String) -> Bound? {
  if src.length() < 2 || unit_at(src, 0) != code('0') {
    return None
  }
  let mark = unit_at(src, 1)
  let base = if mark == code('x') || mark == code('X') {
    16
  } else if mark == code('b') || mark == code('B') {
    2
  } else if mark == code('o') || mark == code('O') {
    8
  } else {
    0
  }
  if base == 0 {
    return None
  }
  if src.length() == 2 {
    return Some(Nan)
  }
  let mut value = 0.0
  let mut index = 2
  while index < src.length() {
    match digit_of(unit_at(src, index), base) {
      Some(digit) => {
        value = value * base.to_double() + digit.to_double()
        index = index + 1
      }
      None => return Some(Nan)
    }
  }
  if value.is_pos_inf() {
    Some(PosInf)
  } else {
    Some(Finite(value))
  }
}

///|
fn scan_decimal(src : String, start : Int32, entire : Bool) -> Bound {
  let limit = src.length()
  let mut index = start
  if index >= limit {
    return Nan
  }
  let mut neg = false
  let sign = unit_at(src, index)
  if sign == code('+') {
    index = index + 1
  } else if sign == code('-') {
    neg = true
    index = index + 1
  }
  if index < limit && starts_with_infinity(src, index) {
    let next = index + 8
    if entire && next != limit {
      return Nan
    }
    if neg {
      return NegInf
    }
    return PosInf
  }
  let int_buf = StringBuilder()
  let int_end = take_digits(src, index, int_buf)
  let mut saw = int_end != index
  index = int_end
  let frac_buf = StringBuilder()
  let mut saw_dot = false
  if index < limit && unit_at(src, index) == code('.') {
    saw_dot = true
    index = index + 1
    let frac_end = take_digits(src, index, frac_buf)
    if frac_end != index {
      saw = true
    }
    index = frac_end
  }
  if !saw {
    return Nan
  }
  let exp_buf = StringBuilder()
  let mut saw_exp = false
  let mut exp_neg = false
  if index < limit {
    let mark = unit_at(src, index)
    if mark == code('e') || mark == code('E') {
      let mut next = index + 1
      if next < limit {
        let exp_sign = unit_at(src, next)
        if exp_sign == code('+') || exp_sign == code('-') {
          exp_neg = exp_sign == code('-')
          next = next + 1
        }
      }
      let exp_start = next
      next = take_digits(src, next, exp_buf)
      if next != exp_start {
        saw_exp = true
        index = next
      } else if entire {
        return Nan
      }
    }
  }
  if entire && index != limit {
    return Nan
  }
  json_number(
    decimal_literal(
      neg,
      int_buf.to_string(),
      saw_dot,
      frac_buf.to_string(),
      saw_exp,
      exp_neg,
      exp_buf.to_string(),
    ),
  )
}

///|
fn parse_js_number(src : String) -> Bound {
  let trimmed = trim_copy(src)
  if trimmed.length() == 0 {
    return Finite(0.0)
  }
  match parse_prefixed(trimmed) {
    Some(bound) => bound
    None => scan_decimal(trimmed, 0, true)
  }
}

///|
fn parse_js_float(src : String) -> Bound {
  let limit = src.length()
  let mut index = 0
  while index < limit && is_js_space(unit_at(src, index)) {
    index = index + 1
  }
  scan_decimal(src, index, false)
}

///|
fn find_colon(src : String) -> Int32 {
  let mut index = 0
  let limit = src.length()
  while index < limit {
    if unit_at(src, index) == code(':') {
      return index
    }
    index = index + 1
  }
  -1
}

///|
fn is_numeric_rule(kind : String) -> Bool {
  kind == "min" || kind == "max" || kind == "minLength" || kind == "maxLength"
}

///|
fn write_rule(buf : StringBuilder, rule : String) -> Unit {
  let colon = find_colon(rule)
  buf.write_string("{\"type\":")
  if colon < 0 {
    buf.write_string(Json::string(rule).stringify())
    buf.write_char('}')
    return
  }
  let kind = copy_units(rule, 0, colon)
  let raw = copy_units(rule, colon + 1, rule.length())
  buf.write_string(Json::string(kind).stringify())
  if is_numeric_rule(kind) {
    match parse_js_number(raw) {
      PosInf => buf.write_string(",\"inf\":1")
      NegInf => buf.write_string(",\"inf\":-1")
      Nan => {
        buf.write_string(",\"arg\":")
        buf.write_string(Json::string(raw).stringify())
      }
      Finite(value) => {
        buf.write_string(",\"arg\":")
        buf.write_string(Json::number(value).stringify())
      }
    }
  } else {
    buf.write_string(",\"arg\":")
    buf.write_string(Json::string(raw).stringify())
  }
  buf.write_char('}')
}

///|
/// Parse string rules. Numeric `min`, `max`, `minLength`, and `maxLength` args become numbers.
/// Infinity is `inf` 1 or -1 because JSON has no infinity.
pub fn parse_rules(rules_json : String) -> String {
  try {
    match @json.parse(rules_json) {
      Array(items) => {
        let buf = StringBuilder()
        buf.write_char('[')
        let mut count = 0
        for item in items {
          match item {
            String(rule) => {
              if count > 0 {
                buf.write_char(',')
              }
              write_rule(buf, rule)
              count = count + 1
            }
            _ => ()
          }
        }
        buf.write_char(']')
        buf.to_string()
      }
      _ => "[]"
    }
  } catch {
    _ => "[]"
  }
}

///|
/// Keep entries tagged `true` or `arg`. `i` is the caller's original index for an arg.
pub fn parse_structured_rules(entries_json : String) -> String {
  try {
    match @json.parse(entries_json) {
      Array(items) => {
        let buf = StringBuilder()
        buf.write_char('[')
        let mut count = 0
        let mut index = 0
        for item in items {
          match item {
            Array(cells) =>
              if cells.length() >= 2 {
                match (cells[0], cells[1]) {
                  (String(key), String(kind)) =>
                    if kind == "true" || kind == "arg" {
                      if count > 0 {
                        buf.write_char(',')
                      }
                      buf.write_string("{\"type\":")
                      buf.write_string(Json::string(key).stringify())
                      if kind == "arg" {
                        buf.write_string(",\"i\":")
                        buf.write_string(index.to_string())
                      }
                      buf.write_char('}')
                      count = count + 1
                    }
                  _ => ()
                }
              }
            _ => ()
          }
          index = index + 1
        }
        buf.write_char(']')
        buf.to_string()
      }
      _ => "[]"
    }
  } catch {
    _ => "[]"
  }
}

///|
fn field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn tag_of(value : Json) -> String {
  match field(value, "t") {
    Some(String(tag)) => tag
    _ => ""
  }
}

///|
fn string_field(value : Json, key : String) -> String {
  match field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn read_bound(value : Json) -> Bound {
  match field(value, "k") {
    Some(String("pinf")) => PosInf
    Some(String("ninf")) => NegInf
    Some(String("n")) =>
      match field(value, "v") {
        Some(Number(number, ..)) => Finite(number)
        _ => Nan
      }
    _ => Nan
  }
}

///|
fn is_empty(value : Json) -> Bool {
  match tag_of(value) {
    "null" | "u" => true
    "s" => string_field(value, "v").length() == 0
    "a" =>
      match field(value, "v") {
        Some(Array(items)) => items.length() == 0
        _ => false
      }
    "o" =>
      match field(value, "inner") {
        Some(inner) => is_empty(inner)
        None =>
          match field(value, "vals") {
            Some(Array(items)) => items.length() == 0
            _ => true
          }
      }
    _ => false
  }
}

///|
fn all_false_bools(value : Json) -> Bool {
  match field(value, "vals") {
    Some(Array(items)) => {
      for item in items {
        if tag_of(item) != "b" {
          return false
        }
        match field(item, "v") {
          Some(True) => return false
          Some(False) => ()
          _ => return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn value_as_number(value : Json) -> Bound {
  match tag_of(value) {
    "n" =>
      match field(value, "v") {
        Some(bound) => read_bound(bound)
        None => Nan
      }
    "s" => parse_js_float(string_field(value, "v"))
    _ =>
      match field(value, "host") {
        Some(bound) => read_bound(bound)
        None => Nan
      }
  }
}

///|
fn ge(left : Bound, right : Bound) -> Bool {
  match left {
    Nan => false
    PosInf =>
      match right {
        Nan => false
        _ => true
      }
    NegInf =>
      match right {
        NegInf => true
        _ => false
      }
    Finite(lhs) =>
      match right {
        Nan => false
        PosInf => false
        NegInf => true
        Finite(rhs) => lhs >= rhs
      }
  }
}

///|
fn bound_code(
  value : Json,
  arg : Json,
  code : String,
  maximum : Bool,
) -> String {
  if is_empty(value) {
    return ""
  }
  let number = value_as_number(value)
  match number {
    Nan => ""
    _ => {
      let limit = read_bound(arg)
      let ok = if maximum { ge(limit, number) } else { ge(number, limit) }
      if ok {
        ""
      } else {
        code
      }
    }
  }
}

///|
fn length_code(
  value : Json,
  arg : Json,
  code : String,
  maximum : Bool,
) -> String {
  if is_empty(value) || tag_of(value) != "s" {
    return ""
  }
  let length = Finite(string_field(value, "v").length().to_double())
  let limit = read_bound(arg)
  let ok = if maximum { ge(limit, length) } else { ge(length, limit) }
  if ok {
    ""
  } else {
    code
  }
}

///|
fn email_atom(src : String, index : Int32) -> Int32 {
  let mut next = index
  let limit = src.length()
  while next < limit {
    let unit = unit_at(src, next)
    if unit == code('@') || is_js_space(unit) {
      break
    }
    next = next + 1
  }
  next
}

///|
fn email_ok(src : String) -> Bool {
  let limit = src.length()
  let head = email_atom(src, 0)
  if head == 0 || head >= limit || unit_at(src, head) != code('@') {
    return false
  }
  let domain = head + 1
  let end = email_atom(src, domain)
  if end == domain || end != limit || domain + 1 >= limit {
    return false
  }
  let mut index = domain + 1
  let last = limit - 1
  while index < last {
    if unit_at(src, index) == code('.') {
      return true
    }
    index = index + 1
  }
  false
}

///|
/// Built-in check. Empty means the rule passed. `min` and `max` compare with JavaScript `>=`.
pub fn builtin_check(
  kind : String,
  value_json : String,
  arg_json : String,
) -> String {
  let value = @json.parse(value_json) catch { _ => return "" }
  let arg = @json.parse(arg_json) catch { _ => Json::null() }
  match kind {
    "required" =>
      if is_empty(value) {
        "required"
      } else if tag_of(value) == "o" && all_false_bools(value) {
        "options"
      } else {
        ""
      }
    "email" =>
      if is_empty(value) {
        ""
      } else if tag_of(value) != "s" || !email_ok(string_field(value, "v")) {
        "email"
      } else {
        ""
      }
    "numeric" =>
      if is_empty(value) {
        ""
      } else if tag_of(value) == "n" {
        match value_as_number(value) {
          Nan => "numeric"
          _ => ""
        }
      } else if tag_of(value) == "s" {
        let text = string_field(value, "v")
        if trim_empty(text) {
          "numeric"
        } else {
          match parse_js_float(text) {
            Nan => "numeric"
            _ => ""
          }
        }
      } else {
        "numeric"
      }
    "min" => bound_code(value, arg, "min", false)
    "max" => bound_code(value, arg, "max", true)
    "minLength" => length_code(value, arg, "minLength", false)
    "maxLength" => length_code(value, arg, "maxLength", true)
    _ => ""
  }
}

///|
fn json_strings(value : Json?) -> Array[String] {
  let names : Array[String] = []
  match value {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(text) => names.push(text)
          _ => ()
        }
      }
    _ => ()
  }
  names
}

///|
fn contains_string(items : Array[String], key : String) -> Bool {
  for item in items {
    if item == key {
      return true
    }
  }
  false
}

///|
fn signature_hint(
  component : String,
  keys : Array[String],
  required : Array[String],
) -> String {
  let buf = StringBuilder()
  buf.write_string("Signature: ")
  buf.write_string(component)
  buf.write_char('(')
  let mut index = 0
  for key in keys {
    if index > 0 {
      buf.write_string(", ")
    }
    buf.write_string(key)
    if contains_string(required, key) {
      buf.write_char('*')
    }
    index = index + 1
  }
  buf.write_string(") — * marks required")
  buf.to_string()
}

///|
fn hint_for(item : Json, names : Array[String]) -> String {
  let code = string_field(item, "code")
  let component = string_field(item, "component")
  if code == "unknown-component" {
    if names.length() == 0 {
      return ""
    }
    let buf = StringBuilder()
    buf.write_string("Available components: ")
    let mut index = 0
    for name in names {
      if index > 0 {
        buf.write_string(", ")
      }
      buf.write_string(name)
      index = index + 1
    }
    return buf.to_string()
  }
  if code == "missing-required" || code == "null-required" {
    match field(item, "keys") {
      Some(Array(_)) =>
        signature_hint(
          component,
          json_strings(field(item, "keys")),
          json_strings(field(item, "required")),
        )
      _ => ""
    }
  } else if code == "inline-reserved" {
    let buf = StringBuilder()
    buf.write_string("Declare as a top-level statement: myVar = ")
    buf.write_string(component)
    buf.write_string("(...)")
    buf.to_string()
  } else {
    ""
  }
}

///|
/// One hint string per validation error. An empty string means no hint.
pub fn enrich_hints(payload_json : String) -> String {
  try {
    match @json.parse(payload_json) {
      Object(map) => {
        let names = json_strings(map.get("names"))
        match map.get("items") {
          Some(Array(items)) => {
            let buf = StringBuilder()
            buf.write_char('[')
            let mut index = 0
            for item in items {
              if index > 0 {
                buf.write_char(',')
              }
              buf.write_string(Json::string(hint_for(item, names)).stringify())
              index = index + 1
            }
            buf.write_char(']')
            buf.to_string()
          }
          _ => "[]"
        }
      }
      _ => "[]"
    }
  } catch {
    _ => "[]"
  }
}

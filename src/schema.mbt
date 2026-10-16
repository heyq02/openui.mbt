///|
/// Ordered JSON value. Object keys stay in source order; `Json` objects do not.
priv enum J {
  Null
  Bool(Bool)
  Num(String)
  Str(String)
  Arr(Array[J])
  Obj(Array[(String, J)])
}

///|
/// Type information kept for one component or call parameter.
pub enum SchemaShape {
  Any
  Str
  Num
  Boolean
  Obj
  Arr
  Null
  Ref(String)
  Enum(Array[String])
  Union(Array[SchemaShape])
  Unknown(String)
}

///|
pub struct ParamDef {
  name : String
  required : Bool
  shape : SchemaShape
}

///|
pub struct ComponentDef {
  name : String
  params : Array[ParamDef]
}

///|
pub enum CallKind {
  Function
  Action
}

///|
pub struct CallDef {
  name : String
  kind : CallKind
  params : Array[ParamDef]
}

///|
pub struct SchemaError {
  path : String
  kind : SchemaKind
}

///|
pub fn SchemaError::message(self : SchemaError) -> String {
  self.kind.message()
}

///|
/// Component and call tables compiled from a library JSON Schema document.
pub struct SchemaCatalog {
  components : Array[ComponentDef]
  calls : Array[CallDef]
  errors : Array[SchemaError]
}

///|
priv struct SchemaReader {
  src : String
  mut index : Int32
  mut failed : Bool
  mut kind : SchemaKind
}

///|
fn SchemaReader::ended(self : SchemaReader) -> Bool {
  self.index >= self.src.length()
}

///|
fn SchemaReader::peek(self : SchemaReader) -> Int32 {
  if self.ended() {
    -1
  } else {
    self.src.at(self.index).to_int()
  }
}

///|
fn SchemaReader::peek_at(self : SchemaReader, offset : Int32) -> Int32 {
  let index = self.index + offset
  if index >= self.src.length() {
    -1
  } else {
    self.src.at(index).to_int()
  }
}

///|
fn SchemaReader::advance(self : SchemaReader) -> Unit {
  if !self.ended() {
    self.index += 1
  }
}

///|
fn SchemaReader::fail(self : SchemaReader, kind : SchemaKind) -> Unit {
  if !self.failed {
    self.failed = true
    self.kind = kind
  }
}

///|
fn SchemaReader::skip_ws(self : SchemaReader) -> Unit {
  while !self.ended() {
    let current = self.peek()
    if current == code(' ') ||
      current == code('\t') ||
      current == code('\n') ||
      current == code('\r') {
      self.advance()
    } else {
      break
    }
  }
}

///|
fn SchemaReader::consume(self : SchemaReader, text : String) -> Bool {
  let mut offset = 0
  while offset < text.length() {
    if self.peek_at(offset) != text.at(offset).to_int() {
      return false
    }
    offset += 1
  }
  let mut left = text.length()
  while left > 0 {
    self.advance()
    left -= 1
  }
  true
}

///|
fn SchemaReader::parse_string(self : SchemaReader) -> String {
  self.advance()
  let buf = StringBuilder()
  while !self.ended() && !self.failed {
    let current = self.peek()
    if current == code('"') {
      self.advance()
      return buf.to_string()
    }
    if current == code('\\') {
      self.advance()
      self.parse_escape(buf)
    } else if current < 0x20 {
      self.fail(InvalidJsonString(self.index))
      return ""
    } else {
      match current.to_char() {
        Some(ch) => buf.write_char(ch)
        None => self.fail(InvalidJsonString(self.index))
      }
      self.advance()
    }
  }
  self.fail(InvalidJsonString(self.index))
  ""
}

///|
fn SchemaReader::parse_escape(self : SchemaReader, buf : StringBuilder) -> Unit {
  let current = self.peek()
  self.advance()
  match current.to_char() {
    Some('u') =>
      match self.read_hex4() {
        Some(point) =>
          if point >= 0xD800 && point <= 0xDFFF {
            self.fail(InvalidJsonString(self.index))
          } else {
            write_code_point(buf, point)
          }
        None => self.fail(InvalidJsonString(self.index))
      }
    Some(ch) =>
      if !write_schema_escape(buf, ch) {
        self.fail(InvalidJsonString(self.index))
      }
    None => self.fail(InvalidJsonString(self.index))
  }
}

///|
fn SchemaReader::read_hex4(self : SchemaReader) -> Int32? {
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
fn SchemaReader::parse_number(self : SchemaReader) -> String {
  let start = self.index
  if self.peek() == code('-') {
    self.advance()
  }
  if self.peek() == code('0') {
    self.advance()
  } else if is_digit(self.peek()) {
    while is_digit(self.peek()) {
      self.advance()
    }
  } else {
    self.fail(InvalidJsonNumber(self.index))
    return "0"
  }
  if self.peek() == code('.') {
    self.advance()
    if !is_digit(self.peek()) {
      self.fail(InvalidJsonNumber(self.index))
      return "0"
    }
    while is_digit(self.peek()) {
      self.advance()
    }
  }
  if self.peek() == code('e') || self.peek() == code('E') {
    self.advance()
    if self.peek() == code('+') || self.peek() == code('-') {
      self.advance()
    }
    if !is_digit(self.peek()) {
      self.fail(InvalidJsonNumber(self.index))
      return "0"
    }
    while is_digit(self.peek()) {
      self.advance()
    }
  }
  self.src[start:self.index].to_owned()
}

///|
fn SchemaReader::parse_value(self : SchemaReader) -> J {
  if self.failed {
    return Null
  }
  self.skip_ws()
  match self.peek().to_char() {
    Some('n') =>
      if self.consume("null") {
        Null
      } else {
        self.fail(InvalidJson(self.index))
        Null
      }
    Some('t') =>
      if self.consume("true") {
        Bool(true)
      } else {
        self.fail(InvalidJson(self.index))
        Null
      }
    Some('f') =>
      if self.consume("false") {
        Bool(false)
      } else {
        self.fail(InvalidJson(self.index))
        Null
      }
    Some('"') => Str(self.parse_string())
    Some('[') => self.parse_array()
    Some('{') => self.parse_object()
    Some('-')
    | Some('0')
    | Some('1')
    | Some('2')
    | Some('3')
    | Some('4')
    | Some('5')
    | Some('6')
    | Some('7')
    | Some('8')
    | Some('9') => Num(self.parse_number())
    _ => {
      self.fail(InvalidJson(self.index))
      Null
    }
  }
}

///|
fn SchemaReader::parse_array(self : SchemaReader) -> J {
  self.advance()
  let items : Array[J] = []
  self.skip_ws()
  if self.peek() == code(']') {
    self.advance()
    return Arr(items)
  }
  while !self.failed {
    items.push(self.parse_value())
    self.skip_ws()
    if self.peek() == code(']') {
      self.advance()
      return Arr(items)
    }
    if self.peek() == code(',') {
      self.advance()
      continue
    }
    self.fail(InvalidJson(self.index))
    return Arr(items)
  }
  Arr(items)
}

///|
fn SchemaReader::parse_object(self : SchemaReader) -> J {
  self.advance()
  let fields : Array[(String, J)] = []
  self.skip_ws()
  if self.peek() == code('}') {
    self.advance()
    return Obj(fields)
  }
  while !self.failed {
    self.skip_ws()
    if self.peek() != code('"') {
      self.fail(InvalidJson(self.index))
      return Obj(fields)
    }
    let key = self.parse_string()
    self.skip_ws()
    if self.peek() != code(':') {
      self.fail(InvalidJson(self.index))
      return Obj(fields)
    }
    self.advance()
    fields.push((key, self.parse_value()))
    self.skip_ws()
    if self.peek() == code('}') {
      self.advance()
      return Obj(fields)
    }
    if self.peek() == code(',') {
      self.advance()
      continue
    }
    self.fail(InvalidJson(self.index))
    return Obj(fields)
  }
  Obj(fields)
}

///|
fn parse_ordered(src : String) -> Result[J, SchemaKind] {
  let reader = SchemaReader::{
    src,
    index: 0,
    failed: false,
    kind: InvalidJson(0),
  }
  let value = reader.parse_value()
  reader.skip_ws()
  if reader.failed {
    Err(reader.kind)
  } else if !reader.ended() {
    Err(InvalidJson(reader.index))
  } else {
    Ok(value)
  }
}

///|
fn object_get(fields : Array[(String, J)], key : String) -> J? {
  let mut found : J? = None
  for field in fields {
    let (name, value) = field
    if name == key {
      found = Some(value)
    }
  }
  found
}

///|
fn as_fields(value : J) -> Array[(String, J)]? {
  match value {
    Obj(fields) => Some(fields)
    _ => None
  }
}

///|
fn json_quote(text : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  let mut index = 0
  while index < text.length() {
    match text.at(index).to_int().to_char() {
      Some('"') => buf.write_string("\\\"")
      Some('\\') => buf.write_string("\\\\")
      Some('\n') => buf.write_string("\\n")
      Some('\r') => buf.write_string("\\r")
      Some('\t') => buf.write_string("\\t")
      Some(ch) => buf.write_char(ch)
      None => ()
    }
    index += 1
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn J::display(self : J) -> String {
  match self {
    Null => "null"
    Bool(true) => "true"
    Bool(false) => "false"
    Num(repr) => repr
    Str(text) => json_quote(text)
    Arr(items) => {
      let buf = StringBuilder()
      buf.write_char('[')
      let mut index = 0
      for item in items {
        if index > 0 {
          buf.write_char(',')
        }
        buf.write_string(item.display())
        index += 1
      }
      buf.write_char(']')
      buf.to_string()
    }
    Obj(fields) => {
      let buf = StringBuilder()
      buf.write_char('{')
      let mut index = 0
      for field in fields {
        if index > 0 {
          buf.write_char(',')
        }
        let (key, value) = field
        buf.write_string(json_quote(key))
        buf.write_char(':')
        buf.write_string(value.display())
        index += 1
      }
      buf.write_char('}')
      buf.to_string()
    }
  }
}

///|
fn join_labels(items : Array[String], separator : String) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for item in items {
    if index > 0 {
      buf.write_string(separator)
    }
    buf.write_string(item)
    index += 1
  }
  buf.to_string()
}

///|
fn SchemaShape::label(self : SchemaShape) -> String {
  match self {
    Any => ""
    Str => "string"
    Num => "number"
    Boolean => "boolean"
    Obj => "object"
    Arr => "array"
    Null => "null"
    Ref(name) => name
    Enum(items) => join_labels(items, "|")
    Union(items) => {
      let labels : Array[String] = []
      for item in items {
        labels.push(item.label())
      }
      join_labels(labels, " | ")
    }
    Unknown(name) => name
  }
}

///|
fn ParamDef::label(self : ParamDef) -> String {
  let marked = if self.required { self.name + "*" } else { self.name }
  match self.shape {
    Any => marked
    _ => marked + ": " + self.shape.label()
  }
}

///|
fn push_error(
  errors : Array[SchemaError],
  path : String,
  message : String,
) -> Unit {
  errors.push({ path, kind: Expected(message), })
}

///|
fn known_shape(name : String) -> SchemaShape? {
  match name {
    "string" => Some(Str)
    "number" | "integer" => Some(Num)
    "boolean" => Some(Boolean)
    "object" => Some(Obj)
    "array" => Some(Arr)
    "null" => Some(Null)
    _ => None
  }
}

///|
fn ref_name(raw : String) -> String {
  let mut start = 0
  let mut index = 0
  while index < raw.length() {
    if raw.at(index).to_int() == code('/') {
      start = index + 1
    }
    index += 1
  }
  raw[start:].to_owned()
}

///|
fn shape_of(
  value : J,
  path : String,
  errors : Array[SchemaError],
) -> SchemaShape {
  match as_fields(value) {
    None => {
      push_error(errors, path, "expected an object")
      Any
    }
    Some(fields) =>
      match object_get(fields, "$ref") {
        Some(Str(raw)) => Ref(ref_name(raw))
        Some(_) => {
          push_error(errors, path + ".$ref", "expected a string")
          Any
        }
        None =>
          match object_get(fields, "enum") {
            Some(Arr(items)) => {
              if items.length() == 0 {
                push_error(errors, path + ".enum", "enum must not be empty")
              }
              let encoded : Array[String] = []
              for item in items {
                encoded.push(item.display())
              }
              Enum(encoded)
            }
            Some(_) => {
              push_error(errors, path + ".enum", "expected an array")
              Any
            }
            None =>
              match object_get(fields, "const") {
                Some(item) => Enum([item.display()])
                None => compound_or_type(fields, path, errors)
              }
          }
      }
  }
}

///|
fn compound_or_type(
  fields : Array[(String, J)],
  path : String,
  errors : Array[SchemaError],
) -> SchemaShape {
  let mut compound : J? = None
  let mut compound_key = ""
  for key in ["anyOf", "oneOf", "allOf"] {
    if compound is None {
      match object_get(fields, key) {
        Some(value) => {
          compound = Some(value)
          compound_key = key
        }
        None => ()
      }
    }
  }
  match compound {
    Some(Arr(items)) => {
      let shapes : Array[SchemaShape] = []
      let mut index = 0
      for item in items {
        shapes.push(
          shape_of(
            item,
            path + "." + compound_key + "." + index.to_string(),
            errors,
          ),
        )
        index += 1
      }
      Union(shapes)
    }
    Some(_) => {
      push_error(errors, path + "." + compound_key, "expected an array")
      Any
    }
    None => type_shape(fields, path, errors)
  }
}

///|
fn type_shape(
  fields : Array[(String, J)],
  path : String,
  errors : Array[SchemaError],
) -> SchemaShape {
  match object_get(fields, "type") {
    None => Any
    Some(Str(name)) =>
      match known_shape(name) {
        Some(shape) => shape
        None => {
          push_error(errors, path + ".type", "unknown type \"" + name + "\"")
          Unknown(name)
        }
      }
    Some(Arr(items)) => {
      if items.length() == 0 {
        push_error(errors, path + ".type", "type must not be empty")
      }
      let shapes : Array[SchemaShape] = []
      let mut index = 0
      for item in items {
        match item {
          Str(name) =>
            match known_shape(name) {
              Some(shape) => shapes.push(shape)
              None => {
                push_error(
                  errors,
                  path + ".type." + index.to_string(),
                  "unknown type \"" + name + "\"",
                )
                shapes.push(Unknown(name))
              }
            }
          _ =>
            push_error(
              errors,
              path + ".type." + index.to_string(),
              "expected a string",
            )
        }
        index += 1
      }
      Union(shapes)
    }
    Some(_) => {
      push_error(
        errors,
        path + ".type",
        "expected a string or an array of strings",
      )
      Any
    }
  }
}

///|
fn names_in(fields : Array[(String, J)]) -> Array[String] {
  let names : Array[String] = []
  for field in fields {
    let (name, _) = field
    let mut seen = false
    for existing in names {
      if existing == name {
        seen = true
      }
    }
    if !seen {
      names.push(name)
    }
  }
  names
}

///|
fn compile_params(
  schema : J,
  path : String,
  errors : Array[SchemaError],
) -> Array[ParamDef] {
  match as_fields(schema) {
    None => {
      push_error(errors, path, "expected an object")
      []
    }
    Some(fields) => {
      let properties = match object_get(fields, "properties") {
        None => []
        Some(Obj(props)) => props
        Some(_) => {
          push_error(errors, path + ".properties", "expected an object")
          []
        }
      }
      let required_values = match object_get(fields, "required") {
        None => []
        Some(Arr(items)) => items
        Some(_) => {
          push_error(errors, path + ".required", "expected an array")
          []
        }
      }
      let required_names : Array[String] = []
      for item in required_values {
        match item {
          Str(name) => required_names.push(name)
          _ => push_error(errors, path + ".required", "expected a string")
        }
      }
      let params : Array[ParamDef] = []
      let prop_names = names_in(properties)
      for name in prop_names {
        match object_get(properties, name) {
          Some(value) => {
            let mut required = false
            for required_name in required_names {
              if required_name == name {
                required = true
              }
            }
            params.push({
              name,
              required,
              shape: shape_of(value, path + ".properties." + name, errors),
            })
          }
          None => ()
        }
      }
      for required_name in required_names {
        let mut found = false
        for name in prop_names {
          if name == required_name {
            found = true
          }
        }
        if !found {
          push_error(
            errors,
            path + ".required",
            "\"" + required_name + "\" is not a property",
          )
        }
      }
      params
    }
  }
}

///|
fn is_action_data(name : String, action_names : Array[String]) -> Bool {
  if name == "ActionExpression" || name == "OpenUrl" || name == "ToAssistant" {
    return true
  }
  for action_name in action_names {
    if action_name == name {
      return true
    }
  }
  false
}

///|
fn compile_components(
  root : Array[(String, J)],
  errors : Array[SchemaError],
) -> Array[ComponentDef] {
  let defs = match object_get(root, "$defs") {
    None => []
    Some(Obj(fields)) => fields
    Some(_) => {
      push_error(errors, "$.$defs", "expected an object")
      []
    }
  }
  let listed = match object_get(root, "properties") {
    None => None
    Some(Obj(fields)) => Some(names_in(fields))
    Some(_) => {
      push_error(errors, "$.properties", "expected an object")
      None
    }
  }
  let action_names = match object_get(root, "actions") {
    Some(Obj(fields)) => names_in(fields)
    _ => []
  }
  let selected = match listed {
    Some(names) => names
    None => {
      let names : Array[String] = []
      for name in names_in(defs) {
        if !is_action_data(name, action_names) {
          names.push(name)
        }
      }
      names
    }
  }
  let components : Array[ComponentDef] = []
  for name in selected {
    match object_get(defs, name) {
      None => push_error(errors, "$.$defs." + name, "missing component schema")
      Some(schema) =>
        components.push({
          name,
          params: compile_params(schema, "$.$defs." + name, errors),
        })
    }
  }
  components
}

///|
fn compile_calls(
  root : Array[(String, J)],
  key : String,
  kind : CallKind,
  errors : Array[SchemaError],
) -> Array[CallDef] {
  let fields = match object_get(root, key) {
    None => return []
    Some(Obj(fields)) => fields
    Some(_) => {
      push_error(errors, "$." + key, "expected an object")
      return []
    }
  }
  let calls : Array[CallDef] = []
  for name in names_in(fields) {
    let path = "$." + key + "." + name
    match object_get(fields, name) {
      Some(Obj(body)) =>
        match object_get(body, "params") {
          None => push_error(errors, path, "missing params")
          Some(params) =>
            calls.push({
              name,
              kind,
              params: compile_params(params, path + ".params", errors),
            })
        }
      Some(_) => push_error(errors, path, "expected an object")
      None => ()
    }
  }
  calls
}

///|
fn ComponentDef::label(self : ComponentDef) -> String {
  let params : Array[String] = []
  for param in self.params {
    params.push(param.label())
  }
  self.name + "(" + join_labels(params, ", ") + ")"
}

///|
fn CallDef::label(self : CallDef) -> String {
  let kind = match self.kind {
    Function => "function"
    Action => "action"
  }
  let params : Array[String] = []
  for param in self.params {
    params.push(param.label())
  }
  kind + " " + self.name + "(" + join_labels(params, ", ") + ")"
}

///|
pub fn SchemaCatalog::dump(self : SchemaCatalog) -> String {
  let buf = StringBuilder()
  buf.write_string("components: " + self.components.length().to_string())
  for component in self.components {
    buf.write_char('\n')
    buf.write_string(component.label())
  }
  buf.write_char('\n')
  buf.write_string("calls: " + self.calls.length().to_string())
  for call in self.calls {
    buf.write_char('\n')
    buf.write_string(call.label())
  }
  buf.write_char('\n')
  buf.write_string("errors: " + self.errors.length().to_string())
  for err in self.errors {
    buf.write_char('\n')
    buf.write_string(err.path + ": " + err.message())
  }
  buf.to_string()
}

///|
/// Compile the component definition table from a library JSON Schema document.
/// Property order is the positional order of OpenUI Lang arguments.
pub fn compile_schema(src : String) -> SchemaCatalog {
  match parse_ordered(src) {
    Err(kind) => { components: [], calls: [], errors: [{ path: "$", kind, }], }
    Ok(Obj(root)) => {
      let errors : Array[SchemaError] = []
      let components = compile_components(root, errors)
      let functions = compile_calls(root, "functions", Function, errors)
      let actions = compile_calls(root, "actions", Action, errors)
      let calls = functions
      for action in actions {
        calls.push(action)
      }
      { components, calls, errors, }
    }
    Ok(_) =>
      {
        components: [],
        calls: [],
        errors: [{ path: "$", kind: Expected("expected an object"), }],
      }
  }
}

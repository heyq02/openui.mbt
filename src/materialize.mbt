///|
/// A materialized value. Catalog components become elements; builtins stay AST.
priv enum Val {
  Null
  Boolean(Bool)
  Num(Double, String)
  Str(String)
  Arr(Array[Val])
  Obj(Array[(String, Val)])
  Element(String, String, Array[(String, Val)], Bool)
  Runtime(Expr)
}

///|
priv struct Issue {
  code : String
  component : String
  path : String
  message : String
  line : Int32
  column : Int32
}

///|
priv struct Mat {
  program : Program
  catalog : SchemaCatalog
  defs : Map[String, Int32]
  unresolved : Array[String]
  mut reached : Array[String]
  visited : Map[String, Bool]
  mut visiting : Array[String]
  errors : Array[Issue]
}

///|
let cached_schema : Ref[String] = Ref("")

///|
let cached_catalog : Ref[SchemaCatalog] = Ref({
  components: [],
  calls: [],
  errors: [],
})

///|
fn catalog_for(schema : String) -> SchemaCatalog {
  if schema == cached_schema.val {
    cached_catalog.val
  } else {
    let catalog = compile_schema(schema)
    cached_schema.val = schema
    cached_catalog.val = catalog
    catalog
  }
}

///|
fn clone_expr(expr : Expr) -> Expr {
  match expr {
    Null => Null
    Bool(value) => Bool(value)
    Num(value, repr) => Num(value, repr)
    Str(text) => Str(text)
    Ref(name) => Ref(name)
    StateRef(name) => StateRef(name)
    Comp(name, is_function, args) => {
      let copied : Array[Expr] = []
      for arg in args {
        copied.push(clone_expr(arg))
      }
      Comp(name, is_function, copied)
    }
    Arr(items) => {
      let copied : Array[Expr] = []
      for item in items {
        copied.push(clone_expr(item))
      }
      Arr(copied)
    }
    Obj(entries) => {
      let copied : Array[(String, Expr)] = []
      for entry in entries {
        let (key, value) = entry
        copied.push((key, clone_expr(value)))
      }
      Obj(copied)
    }
    UnaryOp(op, operand) => UnaryOp(op, clone_expr(operand))
    BinOp(op, left, right) => BinOp(op, clone_expr(left), clone_expr(right))
    Ternary(cond, then_branch, else_branch) =>
      Ternary(
        clone_expr(cond),
        clone_expr(then_branch),
        clone_expr(else_branch),
      )
    Member(obj, field) => Member(clone_expr(obj), field)
    Index(obj, index) => Index(clone_expr(obj), clone_expr(index))
    Assign(target, value) => Assign(target, clone_expr(value))
  }
}

///|
fn starts_with_dollar(name : String) -> Bool {
  name.length() > 0 && name.at(0).to_int() == code('$')
}

///|
fn list_has(items : Array[String], name : String) -> Bool {
  for item in items {
    if item == name {
      return true
    }
  }
  false
}

///|
fn push_unique(items : Array[String], name : String) -> Unit {
  if !list_has(items, name) {
    items.push(name)
  }
}

///|
/// Index of the outermost construct that is still unclosed, or -1.
fn unclosed_at(src : String) -> Int32 {
  let mut index = 0
  let mut depth = 0
  let mut quote = 0
  let mut escape = false
  let mut open_at = -1
  while index < src.length() {
    let current = src.at(index).to_int()
    index = index + 1
    if escape {
      escape = false
      continue
    }
    if quote != 0 {
      if current == code('\\') {
        escape = true
      } else if current == quote {
        quote = 0
        if depth == 0 {
          open_at = -1
        }
      }
      continue
    }
    if current == code('"') || current == code('\'') {
      quote = current
      if depth == 0 {
        open_at = index - 1
      }
    } else if current == code('(') ||
      current == code('[') ||
      current == code('{') {
      if depth == 0 {
        open_at = index - 1
      }
      depth = depth + 1
    } else if current == code(')') ||
      current == code(']') ||
      current == code('}') {
      if depth > 0 {
        depth = depth - 1
      }
      if depth == 0 {
        open_at = -1
      }
    }
  }
  if quote != 0 || depth > 0 {
    open_at
  } else {
    -1
  }
}

///|
/// Unclosed strings or brackets mean the trailing construct is still incomplete.
pub fn source_incomplete(src : String) -> Bool {
  unclosed_at(src) >= 0
}

///|
fn index_statements(program : Program) -> Map[String, Int32] {
  let defs : Map[String, Int32] = Map([], capacity=program.statements.length())
  let mut index = 0
  for stmt in program.statements {
    defs[stmt.id] = index
    index += 1
  }
  defs
}

///|
fn last_statement(
  program : Program,
  defs : Map[String, Int32],
  id : String,
) -> Statement? {
  match defs.get(id) {
    Some(index) => Some(program.statements[index])
    None => None
  }
}

///|
fn is_runtime_name(catalog : SchemaCatalog, name : String) -> Bool {
  if is_builtin(name) || name == "Query" || name == "Mutation" {
    return true
  }
  for call in catalog.calls {
    if call.name == name {
      return true
    }
  }
  false
}

///|
fn component_params(catalog : SchemaCatalog, name : String) -> Array[ParamDef]? {
  for component in catalog.components {
    if component.name == name {
      return Some(component.params)
    }
  }
  None
}

///|
fn push_issue(
  mat : Mat,
  code : String,
  component : String,
  path : String,
  message : String,
  line : Int32,
) -> Unit {
  mat.errors.push({ code, component, path, message, line, column: 0, })
}

///|
fn literal_display(value : Val) -> String? {
  match value {
    Null => Some("null")
    Boolean(true) => Some("true")
    Boolean(false) => Some("false")
    Num(_, repr) => Some(repr)
    Str(text) => Some(json_quote(text))
    _ => None
  }
}

///|
fn shape_label(shape : SchemaShape) -> String {
  match shape {
    Union(items) => {
      let labels : Array[String] = []
      for item in items {
        labels.push(item.label())
      }
      join_labels(labels, " | ")
    }
    _ => shape.label()
  }
}

///|
fn matches_shape(shape : SchemaShape, value : Val) -> Bool {
  match value {
    Runtime(_) => true
    _ =>
      match shape {
        Any | Ref(_) | Unknown(_) => true
        Str =>
          match value {
            Str(_) => true
            _ => false
          }
        Num =>
          match value {
            Num(_) => true
            _ => false
          }
        Boolean =>
          match value {
            Boolean(_) => true
            _ => false
          }
        Obj =>
          match value {
            Obj(_) => true
            _ => false
          }
        Arr =>
          match value {
            Arr(_) => true
            _ => false
          }
        Null =>
          match value {
            Null => true
            _ => false
          }
        Enum(items) =>
          match literal_display(value) {
            Some(text) => list_has(items, text)
            None => false
          }
        Union(items) => {
          for item in items {
            if matches_shape(item, value) {
              return true
            }
          }
          false
        }
      }
  }
}

///|
fn materialize_expr(mat : Mat, expr : Expr, line : Int32) -> Val {
  match expr {
    Null => Null
    Bool(value) => Boolean(value)
    Num(value, repr) => Num(value, repr)
    Str(text) => Str(text)
    StateRef(_) as expr => Runtime(expr)
    Ref(name) => materialize_ref(mat, name, line)
    Arr(items) => {
      let values : Array[Val] = []
      for item in items {
        let value = materialize_expr(mat, item, line)
        match (item, value) {
          (Comp(_, _, _), Null) | (Ref(_), Null) => ()
          _ => values.push(value)
        }
      }
      Arr(values)
    }
    Obj(entries) => {
      let fields : Array[(String, Val)] = []
      for entry in entries {
        let (key, value) = entry
        fields.push((key, materialize_expr(mat, value, line)))
      }
      Obj(fields)
    }
    Comp(name, is_function, args) =>
      materialize_call(mat, name, is_function, args, "", line)
    other => Runtime(other)
  }
}

///|
fn materialize_ref(mat : Mat, name : String, line : Int32) -> Val {
  if list_has(mat.visiting, name) {
    push_unique(mat.unresolved, name)
    return Null
  }
  match last_statement(mat.program, mat.defs, name) {
    None => {
      push_unique(mat.unresolved, name)
      Null
    }
    Some(stmt) => {
      mat.visited[name] = true
      mat.visiting.push(name)
      let value = match stmt.expr {
        Comp(comp_name, is_function, args) =>
          materialize_call(mat, comp_name, is_function, args, name, stmt.line)
        other => materialize_expr(mat, other, stmt.line)
      }
      let next : Array[String] = []
      for item in mat.visiting {
        if item != name {
          next.push(item)
        }
      }
      mat.visiting = next
      let _line = line
      value
    }
  }
}

///|
fn materialize_call(
  mat : Mat,
  name : String,
  is_function : Bool,
  args : Array[Expr],
  statement_id : String,
  line : Int32,
) -> Val {
  if is_function && !is_runtime_name(mat.catalog, name) {
    push_issue(
      mat,
      "unknown-function",
      name,
      "",
      "Unknown function \"@" + name + "\"",
      line,
    )
    return Null
  }
  if name == "Query" || name == "Mutation" {
    push_issue(
      mat,
      "inline-reserved",
      name,
      "",
      name +
      "() must be declared as a top-level statement, not used inline as a value",
      line,
    )
    return Null
  }
  if is_runtime_name(mat.catalog, name) {
    let copied : Array[Expr] = []
    for arg in args {
      copied.push(clone_expr(arg))
    }
    return Runtime(Comp(name, is_function, copied))
  }
  match component_params(mat.catalog, name) {
    None => {
      push_issue(
        mat,
        "unknown-component",
        name,
        "",
        "Unknown component \"" + name + "\"",
        line,
      )
      Null
    }
    Some(params) => {
      let props : Array[(String, Val)] = []
      let mismatched : Array[String] = []
      let mut index = 0
      let mut drop_component = false
      while index < params.length() && index < args.length() {
        let param = params[index]
        let value = materialize_expr(mat, args[index], line)
        if matches_shape(param.shape, value) {
          props.push((param.name, value))
        } else {
          let expected = shape_label(param.shape)
          let actual = match literal_display(value) {
            Some(text) => text
            None => "value"
          }
          push_issue(
            mat,
            "type-mismatch",
            name,
            "/" + param.name,
            "field \"/" +
            param.name +
            "\" expects " +
            expected +
            " but got " +
            actual,
            line,
          )
          if param.required {
            drop_component = true
            mismatched.push(param.name)
          }
        }
        index += 1
      }
      if args.length() > params.length() {
        let extra = args.length() - params.length()
        push_issue(
          mat,
          "excess-args",
          name,
          "",
          name +
          " takes " +
          params.length().to_string() +
          " arg(s), got " +
          args.length().to_string() +
          " (" +
          extra.to_string() +
          " excess dropped)",
          line,
        )
      }
      for param in params {
        if param.required && !list_has(mismatched, param.name) {
          let mut present = false
          for prop in props {
            let (key, value) = prop
            if key == param.name {
              match value {
                Null => ()
                _ => present = true
              }
            }
          }
          if !present {
            drop_component = true
            push_issue(
              mat,
              "missing-required",
              name,
              "/" + param.name,
              "missing required field \"/" + param.name + "\"",
              line,
            )
          }
        }
      }
      if drop_component {
        Null
      } else {
        Element(name, statement_id, props, false)
      }
    }
  }
}

///|
fn pick_root(
  program : Program,
  defs : Map[String, Int32],
  root_name : String,
) -> (String, Bool)? {
  match last_statement(program, defs, "root") {
    Some(_) => Some(("root", false))
    None =>
      if root_name == "" {
        None
      } else {
        let mut found : String? = None
        for stmt in program.statements {
          match stmt.expr {
            Comp(name, false, _) =>
              if name == root_name &&
                !is_builtin(name) &&
                name != "Query" &&
                name != "Mutation" {
                if found is None {
                  found = Some(stmt.id)
                }
              }
            _ => ()
          }
        }
        match found {
          Some(id) => Some((id, true))
          None => None
        }
      }
  }
}

///|
fn orphan_ids(
  program : Program,
  root_id : String,
  visited : Map[String, Bool],
) -> Array[String] {
  let ids : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for stmt in program.statements {
    if stmt.id != root_id &&
      !starts_with_dollar(stmt.id) &&
      !visited.contains(stmt.id) &&
      !seen.contains(stmt.id) {
      seen[stmt.id] = true
      ids.push(stmt.id)
    }
  }
  ids
}

///|
fn Mat::run(self : Mat, root_name : String, incomplete : Bool) -> Val? {
  for err in self.program.errors {
    self.errors.push({
      code: "parse-failed",
      component: "",
      path: "",
      message: err.message,
      line: err.line,
      column: err.column,
    })
  }
  for err in self.catalog.errors {
    self.errors.push({
      code: "schema",
      component: "",
      path: err.path,
      message: err.message,
      line: 0,
      column: 0,
    })
  }
  match pick_root(self.program, self.defs, root_name) {
    None => {
      let component = if root_name == "" { "" } else { root_name }
      push_issue(self, "no-root", component, "", "No root statement", 0)
      None
    }
    Some((id, fallback)) => {
      let root = match last_statement(self.program, self.defs, id) {
        None => None
        Some(stmt) =>
          match stmt.expr {
            Comp(name, is_function, args) =>
              match
                materialize_call(self, name, is_function, args, id, stmt.line) {
                Element(type_name, _, props, _) =>
                  Some(Element(type_name, id, props, incomplete))
                Null => None
                other => Some(other)
              }
            other =>
              match materialize_expr(self, other, stmt.line) {
                Element(type_name, _, props, _) =>
                  Some(Element(type_name, id, props, incomplete))
                Null => None
                value => Some(value)
              }
          }
      }
      match root {
        Some(Element(_)) =>
          if fallback {
            push_issue(
              self,
              "no-root",
              root_name,
              "",
              "No root statement. Rendering the first statement that calls the root component " +
              root_name,
              0,
            )
          }
        Some(_) =>
          push_issue(
            self, "no-root", root_name, "", "root does not evaluate to a component",
            0,
          )
        None => ()
      }
      self.reached = orphan_ids(self.program, id, self.visited)
      match root {
        Some(Element(type_name, statement_id, props, partial)) =>
          Some(Element(type_name, statement_id, props, partial))
        _ => None
      }
    }
  }
}

///|
fn write_indent(buf : StringBuilder, level : Int32) -> Unit {
  let mut index = 0
  while index < level {
    buf.write_string("  ")
    index += 1
  }
}

///|
fn Val::is_scalar(self : Val) -> Bool {
  match self {
    Null | Boolean(_) | Num(_) | Str(_) | Runtime(_) => true
    _ => false
  }
}

///|
fn Val::write(
  self : Val,
  buf : StringBuilder,
  level : Int32,
  bullet : Bool,
) -> Unit {
  write_indent(buf, level)
  if bullet {
    buf.write_string("- ")
  }
  match self {
    Null => buf.write_string("null")
    Boolean(true) => buf.write_string("true")
    Boolean(false) => buf.write_string("false")
    Num(_, repr) => buf.write_string(repr)
    Str(text) => buf.write_string(json_quote(text))
    Runtime(expr) => buf.write_string(expr.dump())
    Element(type_name, _, props, _) => {
      buf.write_string(type_name)
      for prop in props {
        let (key, value) = prop
        buf.write_char('\n')
        if value.is_scalar() {
          write_indent(buf, level + 1)
          buf.write_string(key + ": ")
          match value {
            Null => buf.write_string("null")
            Boolean(true) => buf.write_string("true")
            Boolean(false) => buf.write_string("false")
            Num(_, repr) => buf.write_string(repr)
            Str(text) => buf.write_string(json_quote(text))
            Runtime(expr) => buf.write_string(expr.dump())
            _ => ()
          }
        } else {
          write_indent(buf, level + 1)
          buf.write_string(key + ":")
          buf.write_char('\n')
          match value {
            Arr(items) => {
              let mut item_index = 0
              for item in items {
                if item_index > 0 {
                  buf.write_char('\n')
                }
                item.write(buf, level + 2, true)
                item_index += 1
              }
            }
            Obj(fields) => {
              let mut field_index = 0
              for field in fields {
                if field_index > 0 {
                  buf.write_char('\n')
                }
                let (field_key, field_value) = field
                write_indent(buf, level + 2)
                buf.write_string(field_key + ": ")
                match field_value {
                  Str(text) => buf.write_string(json_quote(text))
                  Boolean(true) => buf.write_string("true")
                  Boolean(false) => buf.write_string("false")
                  Num(_, repr) => buf.write_string(repr)
                  Null => buf.write_string("null")
                  other => {
                    buf.write_char('\n')
                    other.write(buf, level + 3, false)
                  }
                }
                field_index += 1
              }
            }
            other => other.write(buf, level + 2, false)
          }
        }
      }
    }
    Arr(items) =>
      for item in items {
        buf.write_char('\n')
        item.write(buf, level, true)
      }
    Obj(_) => buf.write_string("{...}")
  }
}

///|
fn issue_dump(errors : Array[Issue]) -> String {
  let buf = StringBuilder()
  for err in errors {
    buf.write_char('\n')
    buf.write_string(err.line.to_string())
    buf.write_char(':')
    buf.write_string(err.column.to_string())
    buf.write_char(' ')
    buf.write_string(err.code)
    buf.write_char(' ')
    buf.write_string(err.message)
  }
  buf.to_string()
}

///|
fn names_dump(items : Array[String]) -> String {
  if items.length() == 0 {
    ""
  } else {
    " " + join_labels(items, " ")
  }
}

///|
fn result_dump(
  root : Val?,
  incomplete : Bool,
  unresolved : Array[String],
  orphaned : Array[String],
  errors : Array[Issue],
) -> String {
  let buf = StringBuilder()
  buf.write_string("incomplete: ")
  buf.write_string(if incomplete { "true" } else { "false" })
  buf.write_string("\nunresolved:" + names_dump(unresolved))
  buf.write_string("\norphaned:" + names_dump(orphaned))
  buf.write_string("\nerrors: " + errors.length().to_string())
  buf.write_string(issue_dump(errors))
  match root {
    Some(value) => {
      buf.write_char('\n')
      value.write(buf, 0, false)
    }
    None => buf.write_string("\nroot: null")
  }
  buf.to_string()
}

///|
fn val_json(value : Val) -> Json {
  match value {
    Null => Json::null()
    Boolean(true) => Json::boolean(true)
    Boolean(false) => Json::boolean(false)
    Num(number, repr) => Json::number(number, repr~)
    Str(text) => Json::string(text)
    Runtime(expr) => expr.to_json()
    Arr(items) => {
      let encoded : Array[Json] = []
      for item in items {
        encoded.push(val_json(item))
      }
      Json::array(encoded)
    }
    Obj(fields) => {
      let encoded : Array[(String, Json)] = []
      for field in fields {
        let (key, item) = field
        encoded.push((key, val_json(item)))
      }
      json_object(encoded)
    }
    Element(type_name, statement_id, props, partial) => {
      let prop_fields : Array[(String, Json)] = []
      for prop in props {
        let (key, item) = prop
        prop_fields.push((key, val_json(item)))
      }
      let fields : Array[(String, Json)] = [
        ("type", Json::string("element")),
        ("typeName", Json::string(type_name)),
        ("props", json_object(prop_fields)),
        ("partial", Json::boolean(partial)),
      ]
      if statement_id != "" {
        fields.push(("statementId", Json::string(statement_id)))
      }
      json_object(fields)
    }
  }
}

///|
fn json_object(fields : Array[(String, Json)]) -> Json {
  let map : Map[String, Json] = Map([])
  for field in fields {
    let (key, value) = field
    map[key] = value
  }
  Json::object(map)
}

///|
fn result_json(
  root : Val?,
  incomplete : Bool,
  unresolved : Array[String],
  orphaned : Array[String],
  errors : Array[Issue],
) -> String {
  let unresolved_json : Array[Json] = []
  for name in unresolved {
    unresolved_json.push(Json::string(name))
  }
  let orphaned_json : Array[Json] = []
  for name in orphaned {
    orphaned_json.push(Json::string(name))
  }
  let error_json : Array[Json] = []
  for err in errors {
    error_json.push(
      json_object([
        ("code", Json::string(err.code)),
        ("component", Json::string(err.component)),
        ("path", Json::string(err.path)),
        ("message", Json::string(err.message)),
        ("line", Json::number(Double::from_int(err.line))),
        ("column", Json::number(Double::from_int(err.column))),
      ]),
    )
  }
  let root_json = match root {
    Some(value) => val_json(value)
    None => Json::null()
  }
  json_object([
    ("root", root_json),
    ("incomplete", Json::boolean(incomplete)),
    ("unresolved", Json::array(unresolved_json)),
    ("orphaned", Json::array(orphaned_json)),
    ("errors", Json::array(error_json)),
  ]).stringify(indent=2)
}

///|
fn materialize_with(
  src : String,
  schema : String,
  root_name : String,
) -> (Val?, Bool, Array[String], Array[String], Array[Issue], Int32) {
  let program = parse(src)
  let count = program.statements.length()
  let catalog = catalog_for(schema)
  let defs = index_statements(program)
  let incomplete = source_incomplete(src)
  let mat = Mat::{
    program,
    catalog,
    defs,
    unresolved: [],
    reached: [],
    visited: Map([]),
    visiting: [],
    errors: [],
  }
  let root = mat.run(root_name, incomplete)
  (root, incomplete, mat.unresolved, mat.reached, mat.errors, count)
}

///|
/// Materialize a program against a library JSON Schema.
/// `root_name` is used only when the program has no `root` statement.
pub fn materialize_dump(
  src : String,
  schema : String,
  root_name : String,
) -> String {
  let (root, incomplete, unresolved, orphaned, errors, _count) = materialize_with(
    src, schema, root_name,
  )
  result_dump(root, incomplete, unresolved, orphaned, errors)
}

///|
/// JSON result: element tree, errors, unresolved, orphaned, and incomplete.
pub fn materialize_json(
  src : String,
  schema : String,
  root_name : String,
) -> String {
  let (root, incomplete, unresolved, orphaned, errors, _count) = materialize_with(
    src, schema, root_name,
  )
  result_json(root, incomplete, unresolved, orphaned, errors)
}

///|
fn write_json_bool(buf : StringBuilder, value : Bool) -> Unit {
  if value {
    buf.write_string("true")
  } else {
    buf.write_string("false")
  }
}

///|
fn write_val_fields(buf : StringBuilder, fields : Array[(String, Val)]) -> Unit {
  buf.write_char('{')
  let mut index = 0
  for field in fields {
    if index > 0 {
      buf.write_char(',')
    }
    let (key, value) = field
    write_json_string(buf, key)
    buf.write_char(':')
    write_val(buf, value, false)
    index += 1
  }
  buf.write_char('}')
}

///|
fn write_val(buf : StringBuilder, value : Val, with_id : Bool) -> Unit {
  match value {
    Null => buf.write_string("null")
    Boolean(true) => buf.write_string("true")
    Boolean(false) => buf.write_string("false")
    Num(_, repr) => buf.write_string(repr)
    Str(text) => write_json_string(buf, text)
    Runtime(expr) => write_expr_json(buf, expr)
    Arr(items) => {
      buf.write_char('[')
      let mut index = 0
      for item in items {
        if index > 0 {
          buf.write_char(',')
        }
        write_val(buf, item, false)
        index += 1
      }
      buf.write_char(']')
    }
    Obj(fields) => write_val_fields(buf, fields)
    Element(type_name, statement_id, props, partial) => {
      buf.write_string("{\"type\":\"element\",\"typeName\":")
      write_json_string(buf, type_name)
      buf.write_string(",\"props\":")
      write_val_fields(buf, props)
      if partial {
        buf.write_string(",\"partial\":true")
      }
      if with_id && statement_id != "" {
        buf.write_string(",\"statementId\":")
        write_json_string(buf, statement_id)
      }
      buf.write_char('}')
    }
  }
}

///|
fn write_string_list(buf : StringBuilder, items : Array[String]) -> Unit {
  buf.write_char('[')
  let mut index = 0
  for item in items {
    if index > 0 {
      buf.write_char(',')
    }
    write_json_string(buf, item)
    index += 1
  }
  buf.write_char(']')
}

///|
fn write_issues(buf : StringBuilder, errors : Array[Issue]) -> Unit {
  buf.write_char('[')
  let mut index = 0
  for err in errors {
    if index > 0 {
      buf.write_char(',')
    }
    buf.write_string("{\"code\":")
    write_json_string(buf, err.code)
    buf.write_string(",\"component\":")
    write_json_string(buf, err.component)
    buf.write_string(",\"path\":")
    write_json_string(buf, err.path)
    buf.write_string(",\"message\":")
    write_json_string(buf, err.message)
    buf.write_string(",\"line\":")
    buf.write_string(err.line.to_string())
    buf.write_string(",\"column\":")
    buf.write_string(err.column.to_string())
    buf.write_char('}')
    index += 1
  }
  buf.write_char(']')
}

///|
/// Statement count after materialize, without encoding the tree.
pub fn materialize_count(
  src : String,
  schema : String,
  root_name : String,
) -> Int32 {
  let (_, _, _, _, _, count) = materialize_with(src, schema, root_name)
  count
}

///|
/// Official `ParseResult` shape, written without building a `Json` map.
pub fn materialize_result(
  src : String,
  schema : String,
  root_name : String,
) -> String {
  let (root, incomplete, unresolved, orphaned, errors, count) = materialize_with(
    src, schema, root_name,
  )
  let buf = StringBuilder()
  buf.write_string("{\"root\":")
  match root {
    Some(value) => write_val(buf, value, true)
    None => buf.write_string("null")
  }
  buf.write_string(",\"meta\":{\"incomplete\":")
  write_json_bool(buf, incomplete)
  buf.write_string(",\"unresolved\":")
  write_string_list(buf, unresolved)
  buf.write_string(",\"orphaned\":")
  write_string_list(buf, orphaned)
  buf.write_string(",\"statementCount\":")
  buf.write_string(count.to_string())
  buf.write_string(",\"errors\":")
  write_issues(buf, errors)
  buf.write_string(
    "},\"stateDeclarations\":{},\"queryStatements\":[],\"mutationStatements\":[]}",
  )
  buf.to_string()
}

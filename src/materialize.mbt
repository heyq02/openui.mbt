///|
/// A materialized value. Catalog components become elements; builtins stay AST.
priv enum Val {
  Null
  Boolean(Bool)
  Num(Double, String)
  Str(String)
  Arr(Array[Val])
  Obj(Array[(String, Val)])
  Element(String, String, Array[(String, Val)], Bool, Bool)
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
  statement_id : String
  warning : Bool
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
  mut current_statement : String
  mut partial : Bool
  errors : Array[Issue]
  use_cache : Bool
  cache : Ref[Map[String, Val]]
  cache_limit : Int32
}

///|
let cached_schema : Ref[String] = Ref("")

///|
/// JSON for stream leaves. Empty while a one-shot parse is encoding.
let encoded_elements : Ref[Map[String, String]] = Ref(Map([]))

///|
/// Runtime entry (`root = $t ? A : B`). Cleared at the start of each run.
let root_expression : Ref[Expr?] = Ref(None)

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
/// The scan itself is `lexscan` over the source.
fn unclosed_at(src : String) -> Int32 {
  hold_from(src)
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
  push_marked(mat, code, component, path, message, line, false)
}

///|
fn push_marked(
  mat : Mat,
  code : String,
  component : String,
  path : String,
  message : String,
  line : Int32,
  warning : Bool,
) -> Unit {
  mat.errors.push({
    code,
    component,
    path,
    message,
    line,
    column: 0,
    statement_id: mat.current_statement,
    warning,
  })
}

///|
fn param_signature(name : String, params : Array[ParamDef]) -> String {
  let labels : Array[String] = []
  for param in params {
    labels.push(param.label())
  }
  name + "(" + join_labels(labels, ", ") + ")"
}

///|
fn required_message(code : String, path : String, signature : String) -> String {
  let base = if code == "null-required" {
    "required field \"" + path + "\" cannot be null"
  } else {
    "missing required field \"" + path + "\""
  }
  base + " — signature: " + signature
}

///|
fn catalog_names(catalog : SchemaCatalog) -> String {
  let names : Array[String] = []
  for component in catalog.components {
    names.push(component.name)
  }
  join_labels(names, ", ")
}

///|
fn unknown_component_message(name : String, catalog : SchemaCatalog) -> String {
  let base = "Unknown component \"" +
    name +
    "\" — not found in catalog or builtins"
  let available = catalog_names(catalog)
  if available == "" {
    base
  } else {
    base + ". Available components: " + available
  }
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
    other => Runtime(fold_runtime(mat, other, line))
  }
}

///|
fn fold_args(mat : Mat, args : Array[Expr], line : Int32) -> Array[Expr] {
  let folded : Array[Expr] = []
  for arg in args {
    folded.push(fold_runtime(mat, arg, line))
  }
  folded
}

///|
fn contains_component(expr : Expr) -> Bool {
  match expr {
    Comp(name, false, args) =>
      if !is_builtin(name) && name != "Query" && name != "Mutation" {
        true
      } else {
        args_contain_component(args)
      }
    Comp(_, _, args) => args_contain_component(args)
    Arr(items) => args_contain_component(items)
    Obj(entries) => {
      for entry in entries {
        let (_, value) = entry
        if contains_component(value) {
          return true
        }
      }
      false
    }
    UnaryOp(_, value) => contains_component(value)
    BinOp(_, left, right) =>
      contains_component(left) || contains_component(right)
    Ternary(cond, yes, no) =>
      contains_component(cond) ||
      contains_component(yes) ||
      contains_component(no)
    Member(value, _) => contains_component(value)
    Index(value, index) =>
      contains_component(value) || contains_component(index)
    Assign(_, value) => contains_component(value)
    _ => false
  }
}

///|
fn args_contain_component(args : Array[Expr]) -> Bool {
  for arg in args {
    if contains_component(arg) {
      return true
    }
  }
  false
}

///|
fn fold_ref(mat : Mat, name : String, line : Int32) -> Expr {
  if list_has(mat.visiting, name) {
    push_unique(mat.unresolved, name)
    return Ref(name)
  }
  match last_statement(mat.program, mat.defs, name) {
    None => {
      push_unique(mat.unresolved, name)
      Ref(name)
    }
    Some(stmt) => {
      mat.visited[name] = true
      mat.visiting.push(name)
      let saved = mat.current_statement
      mat.current_statement = name
      let value = fold_runtime(mat, stmt.expr, stmt.line)
      mat.current_statement = saved
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
/// Rewrite a runtime expression: resolve refs, null unknown `@` calls.
fn fold_runtime(mat : Mat, expr : Expr, line : Int32) -> Expr {
  match expr {
    Ref(name) => fold_ref(mat, name, line)
    Comp(name, is_function, args) =>
      if is_function && !is_runtime_name(mat.catalog, name) {
        push_issue(
          mat,
          "unknown-function",
          name,
          "",
          "Unknown function \"@" +
          name +
          "\": not a built-in or action step. The call evaluates to null",
          line,
        )
        Null
      } else {
        let folded = fold_args(mat, args, line)
        if !is_function &&
          !is_runtime_name(mat.catalog, name) &&
          component_params(mat.catalog, name) is None &&
          !is_builtin(name) {
          push_issue(
            mat,
            "unknown-component",
            name,
            "",
            unknown_component_message(name, mat.catalog),
            line,
          )
        }
        Comp(name, is_function, folded)
      }
    Arr(items) => Arr(fold_args(mat, items, line))
    Obj(entries) => {
      let folded : Array[(String, Expr)] = []
      for entry in entries {
        let (key, value) = entry
        folded.push((key, fold_runtime(mat, value, line)))
      }
      Obj(folded)
    }
    UnaryOp(op, operand) => UnaryOp(op, fold_runtime(mat, operand, line))
    BinOp(op, left, right) =>
      BinOp(op, fold_runtime(mat, left, line), fold_runtime(mat, right, line))
    Ternary(cond, yes, no) =>
      Ternary(
        fold_runtime(mat, cond, line),
        fold_runtime(mat, yes, line),
        fold_runtime(mat, no, line),
      )
    Member(obj, field) => Member(fold_runtime(mat, obj, line), field)
    Index(obj, index) =>
      Index(fold_runtime(mat, obj, line), fold_runtime(mat, index, line))
    Assign(target, value) => Assign(target, fold_runtime(mat, value, line))
    other => other
  }
}

///|
fn expr_has_ref(expr : Expr) -> Bool {
  match expr {
    Ref(_) => true
    Arr(items) => {
      for item in items {
        if expr_has_ref(item) {
          return true
        }
      }
      false
    }
    Obj(entries) => {
      for entry in entries {
        let (_, value) = entry
        if expr_has_ref(value) {
          return true
        }
      }
      false
    }
    Comp(_, _, args) => {
      for arg in args {
        if expr_has_ref(arg) {
          return true
        }
      }
      false
    }
    UnaryOp(_, value) => expr_has_ref(value)
    BinOp(_, left, right) => expr_has_ref(left) || expr_has_ref(right)
    Ternary(cond, yes, no) =>
      expr_has_ref(cond) || expr_has_ref(yes) || expr_has_ref(no)
    Member(value, _) => expr_has_ref(value)
    Index(value, index) => expr_has_ref(value) || expr_has_ref(index)
    Assign(_, value) => expr_has_ref(value)
    _ => false
  }
}

///|
fn materialize_ref(mat : Mat, name : String, line : Int32) -> Val {
  if mat.use_cache {
    match mat.cache.val.get(name) {
      Some(value) => {
        mat.visited[name] = true
        return value
      }
      None => ()
    }
  }
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
      let saved_statement = mat.current_statement
      mat.current_statement = name
      let value = match stmt.expr {
        Comp(comp_name, is_function, args) =>
          materialize_call(mat, comp_name, is_function, args, name, stmt.line)
        other => materialize_expr(mat, other, stmt.line)
      }
      mat.current_statement = saved_statement
      let next : Array[String] = []
      for item in mat.visiting {
        if item != name {
          next.push(item)
        }
      }
      mat.visiting = next
      if mat.use_cache &&
        mat.defs[name] < mat.cache_limit &&
        !expr_has_ref(stmt.expr) {
        mat.cache.val[name] = value
        let buf = StringBuilder()
        write_val(buf, value, false)
        encoded_elements.val[name] = buf.to_string()
      }
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
        unknown_component_message(name, mat.catalog),
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
        if value is Null {
          if param.required {
            match lit_val(node_default(param.node)) {
              Some(fallback) => props.push((param.name, fallback))
              None => {
                drop_component = true
                mismatched.push(param.name)
                push_issue(
                  mat,
                  "null-required",
                  name,
                  "/" + param.name,
                  required_message(
                    "null-required",
                    "/" + param.name,
                    param_signature(name, params),
                  ),
                  line,
                )
              }
            }
          } else {
            props.push((param.name, Null))
          }
          index += 1
          continue
        } else if param.node is Open {
          let _kept = refine(
            mat,
            name,
            "/" + param.name,
            param.node,
            value,
            line,
          )
          props.push((param.name, value))
        } else if mat.partial && param.node is Leaf(_, Some(_), _) {
          let _kept = refine(
            mat,
            name,
            "/" + param.name,
            param.node,
            value,
            line,
          )
          props.push((param.name, value))
        } else if matches_shape(param.shape, value) {
          match refine(mat, name, "/" + param.name, param.node, value, line) {
            Keep(next) => props.push((param.name, next))
            Bad =>
              if param.required {
                drop_component = true
                mismatched.push(param.name)
              }
          }
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
          match lit_val(node_default(param.node)) {
            Some(fallback) => props.push((param.name, fallback))
            None =>
              if param.required {
                drop_component = true
                mismatched.push(param.name)
              }
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
            match lit_val(node_default(param.node)) {
              Some(fallback) => props.push((param.name, fallback))
              None => {
                drop_component = true
                push_issue(
                  mat,
                  "missing-required",
                  name,
                  "/" + param.name,
                  required_message(
                    "missing-required",
                    "/" + param.name,
                    param_signature(name, params),
                  ),
                  line,
                )
              }
            }
          }
        }
      }
      if drop_component {
        Null
      } else {
        Element(
          name,
          statement_id,
          props,
          mat.partial,
          props_have_dynamic(props),
        )
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
  root_expression.val = None
  self.partial = incomplete
  for err in self.program.errors {
    self.errors.push({
      code: "parse-failed",
      component: "",
      path: "",
      message: err.message(),
      line: err.line,
      column: err.column,
      statement_id: "",
      warning: false,
    })
  }
  for err in self.catalog.errors {
    self.errors.push({
      code: "schema",
      component: "",
      path: err.path,
      message: err.message(),
      line: 0,
      column: 0,
      statement_id: "",
      warning: false,
    })
  }
  match pick_root(self.program, self.defs, root_name) {
    None => {
      let component = if root_name == "" { "" } else { root_name }
      let message = if root_name == "" {
        "No root statement"
      } else {
        "No root statement, and no statement calls the root component " +
        root_name
      }
      push_issue(self, "no-root", component, "", message, 0)
      None
    }
    Some((id, fallback)) => {
      self.current_statement = id
      let root = match last_statement(self.program, self.defs, id) {
        None => None
        Some(stmt) =>
          match stmt.expr {
            Comp(name, is_function, args) =>
              match
                materialize_call(self, name, is_function, args, id, stmt.line) {
                Element(type_name, _, props, _, dynamic) =>
                  Some(Element(type_name, id, props, incomplete, dynamic))
                Null => None
                other => Some(other)
              }
            other =>
              match materialize_expr(self, other, stmt.line) {
                Element(type_name, _, props, _, dynamic) =>
                  Some(Element(type_name, id, props, incomplete, dynamic))
                Null => None
                value => Some(value)
              }
          }
      }
      match root {
        Some(Element(_)) =>
          if fallback {
            push_marked(
              self,
              "no-root",
              root_name,
              "",
              "No root statement. Rendering the first statement that calls the root component " +
              root_name,
              0,
              true,
            )
          }
        Some(Runtime(expr)) =>
          if contains_component(expr) {
            root_expression.val = Some(expr)
          } else {
            push_issue(
              self, "no-root", root_name, "", "root does not evaluate to a component",
              0,
            )
          }
        Some(_) =>
          push_issue(
            self, "no-root", root_name, "", "root does not evaluate to a component",
            0,
          )
        None =>
          if fallback {
            push_issue(
              self,
              "no-root",
              root_name,
              "",
              "No root statement, and no statement calls the root component " +
              root_name,
              0,
            )
          }
      }
      self.reached = orphan_ids(self.program, id, self.visited)
      match root {
        Some(Element(type_name, statement_id, props, partial, dynamic)) =>
          Some(Element(type_name, statement_id, props, partial, dynamic))
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
    Element(type_name, _, props, _, _) => {
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
    Element(type_name, statement_id, props, partial, dynamic) => {
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
        ("hasDynamicProps", Json::boolean(dynamic)),
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
    let fields : Array[(String, Json)] = [
      ("code", Json::string(err.code)),
      ("component", Json::string(err.component)),
      ("path", Json::string(err.path)),
      ("message", Json::string(err.message)),
      ("line", Json::number(Double::from_int(err.line))),
      ("column", Json::number(Double::from_int(err.column))),
    ]
    if err.warning {
      fields.push(("severity", Json::string("warning")))
    }
    error_json.push(json_object(fields))
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
  let count = unique_statement_count(program)
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
    current_statement: "",
    partial: false,
    errors: [],
    use_cache: false,
    cache: Ref(Map([])),
    cache_limit: 0,
  }
  let root = mat.run(root_name, incomplete)
  (root, incomplete, mat.unresolved, mat.reached, mat.errors, count)
}

///|
fn materialize_program(
  program : Program,
  schema : String,
  root_name : String,
  incomplete : Bool,
  cache : Ref[Map[String, Val]],
  cache_limit : Int32,
) -> (Val?, Bool, Array[String], Array[String], Array[Issue], Int32) {
  let count = unique_statement_count(program)
  let catalog = catalog_for(schema)
  let defs = index_statements(program)
  let mat = Mat::{
    program,
    catalog,
    defs,
    unresolved: [],
    reached: [],
    visited: Map([]),
    visiting: [],
    current_statement: "",
    partial: false,
    errors: [],
    use_cache: true,
    cache,
    cache_limit,
  }
  let root = mat.run(root_name, incomplete)
  (root, incomplete, mat.unresolved, mat.reached, mat.errors, count)
}

///|
/// Materialize one statement. Callers use this for a closed leaf during streaming.
fn materialize_statement(
  stmt : Statement,
  schema : String,
) -> (Val, Array[Issue]) {
  let program : Program = { statements: [stmt], errors: [], }
  let catalog = catalog_for(schema)
  let defs : Map[String, Int32] = Map([])
  defs[stmt.id] = 0
  let saved = encoded_elements.val
  encoded_elements.val = Map([])
  let mat = Mat::{
    program,
    catalog,
    defs,
    unresolved: [],
    reached: [],
    visited: Map([]),
    visiting: [],
    current_statement: "",
    partial: false,
    errors: [],
    use_cache: false,
    cache: Ref(Map([])),
    cache_limit: 0,
  }
  mat.current_statement = stmt.id
  let value = match stmt.expr {
    Comp(name, is_function, args) =>
      materialize_call(mat, name, is_function, args, stmt.id, stmt.line)
    other => materialize_expr(mat, other, stmt.line)
  }
  encoded_elements.val = saved
  (value, mat.errors)
}

///|
fn scalar_json(expr : Expr) -> String? {
  match expr {
    Null => Some("null")
    Bool(true) => Some("true")
    Bool(false) => Some("false")
    Num(_, repr) => Some(repr)
    Str(text) => {
      let buf = StringBuilder()
      write_json_string(buf, text)
      Some(buf.to_string())
    }
    _ => None
  }
}

///|
fn scalar_display(expr : Expr) -> String? {
  match expr {
    Null => Some("null")
    Bool(true) => Some("true")
    Bool(false) => Some("false")
    Num(_, repr) => Some(repr)
    Str(text) => Some(json_quote(text))
    _ => None
  }
}

///|
fn scalar_matches(shape : SchemaShape, expr : Expr) -> Bool {
  match shape {
    Any | Ref(_) | Unknown(_) => true
    Str =>
      match expr {
        Str(_) => true
        _ => false
      }
    Num =>
      match expr {
        Num(_) => true
        _ => false
      }
    Boolean =>
      match expr {
        Bool(_) => true
        _ => false
      }
    Null =>
      match expr {
        Null => true
        _ => false
      }
    Obj | Arr | Enum(_) => false
    Union(items) => {
      for item in items {
        if scalar_matches(item, expr) {
          return true
        }
      }
      false
    }
  }
}

///|
/// Fast path only for scalars and unchecked arrays. Nested schemas use `refine`.
fn plain_node(node : SchemaNode) -> Bool {
  match node {
    Open => true
    Items(Open) => true
    Leaf(kind, None, Absent) =>
      kind == "string" || kind == "number" || kind == "boolean"
    _ => false
  }
}

///|
/// Literal component calls skip the value tree. Anything else uses `materialize_statement`.
fn literal_component(
  catalog : SchemaCatalog,
  name : String,
  args : Array[Expr],
  line : Int32,
  statement_id : String,
) -> (String, Array[Issue])? {
  if is_builtin(name) || name == "Query" || name == "Mutation" {
    return None
  }
  let mut index = 0
  while index < args.length() {
    if args[index] is Null || scalar_json(args[index]) is None {
      return None
    }
    index = index + 1
  }
  let issues : Array[Issue] = []
  match component_params(catalog, name) {
    None => {
      issues.push({
        code: "unknown-component",
        component: name,
        path: "",
        message: unknown_component_message(name, catalog),
        line,
        column: 0,
        statement_id,
        warning: false,
      })
      Some(("", issues))
    }
    Some(params) => {
      for param in params {
        if !plain_node(param.node) {
          return None
        }
      }
      let buf = StringBuilder()
      buf.write_string("{\"type\":\"element\",\"typeName\":")
      write_json_string(buf, name)
      buf.write_string(",\"props\":{")
      let mismatched : Array[String] = []
      let mut drop_component = false
      let mut wrote = false
      let mut arg_index = 0
      while arg_index < params.length() && arg_index < args.length() {
        let param = params[arg_index]
        let arg = args[arg_index]
        if scalar_matches(param.shape, arg) {
          if wrote {
            buf.write_char(',')
          }
          wrote = true
          write_json_string(buf, param.name)
          buf.write_char(':')
          match scalar_json(arg) {
            Some(json) => buf.write_string(json)
            None => ()
          }
        } else {
          let actual = match scalar_display(arg) {
            Some(text) => text
            None => "value"
          }
          issues.push({
            code: "type-mismatch",
            component: name,
            path: "/" + param.name,
            message: "field \"/" +
            param.name +
            "\" expects " +
            shape_label(param.shape) +
            " but got " +
            actual,
            line,
            column: 0,
            statement_id,
            warning: false,
          })
          if param.required {
            drop_component = true
            mismatched.push(param.name)
          }
        }
        arg_index = arg_index + 1
      }
      if args.length() > params.length() {
        let extra = args.length() - params.length()
        issues.push({
          code: "excess-args",
          component: name,
          path: "",
          message: name +
          " takes " +
          params.length().to_string() +
          " arg(s), got " +
          args.length().to_string() +
          " (" +
          extra.to_string() +
          " excess dropped)",
          line,
          column: 0,
          statement_id,
          warning: false,
        })
      }
      for param in params {
        if param.required && !list_has(mismatched, param.name) {
          let mut present = false
          let mut slot = 0
          while slot < params.length() && slot < args.length() {
            if params[slot].name == param.name &&
              scalar_matches(param.shape, args[slot]) {
              match args[slot] {
                Null => ()
                _ => present = true
              }
            }
            slot = slot + 1
          }
          if !present {
            drop_component = true
            issues.push({
              code: "missing-required",
              component: name,
              path: "/" + param.name,
              message: required_message(
                "missing-required",
                "/" + param.name,
                param_signature(name, params),
              ),
              line,
              column: 0,
              statement_id,
              warning: false,
            })
          }
        }
      }
      buf.write_string("},\"partial\":false,\"hasDynamicProps\":false")
      if statement_id != "" {
        buf.write_string(",\"statementId\":")
        write_json_string(buf, statement_id)
      }
      buf.write_char('}')
      if drop_component {
        Some(("", issues))
      } else {
        Some((buf.to_string(), issues))
      }
    }
  }
}

///|
fn leaf_payload(
  stmt : Statement,
  schema : String,
  catalog : SchemaCatalog,
) -> (String, Array[Issue]) {
  match stmt.expr {
    Comp(name, false, args) =>
      match literal_component(catalog, name, args, stmt.line, stmt.id) {
        Some(payload) => payload
        None => {
          let (value, issues) = materialize_statement(stmt, schema)
          (child_json(value), issues)
        }
      }
    _ => {
      let (value, issues) = materialize_statement(stmt, schema)
      (child_json(value), issues)
    }
  }
}

///|
/// Child JSON for an array slot. `Null` is omitted, matching ref materialize.
fn child_json(value : Val) -> String {
  match value {
    Null => ""
    other => {
      let saved = encoded_elements.val
      encoded_elements.val = Map([])
      let buf = StringBuilder()
      write_val(buf, other, false)
      encoded_elements.val = saved
      buf.to_string()
    }
  }
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
fn val_has_dynamic(value : Val) -> Bool {
  match value {
    Null | Boolean(_) | Num(_) | Str(_) => false
    Runtime(_) => true
    Arr(items) => {
      for item in items {
        if val_has_dynamic(item) {
          return true
        }
      }
      false
    }
    Obj(fields) => {
      for field in fields {
        let (key, item) = field
        if key == "steps" {
          match item {
            Arr(_) => return true
            _ => ()
          }
        }
        if val_has_dynamic(item) {
          return true
        }
      }
      false
    }
    Element(_, _, _, _, dynamic) => dynamic
  }
}

///|
fn props_have_dynamic(props : Array[(String, Val)]) -> Bool {
  for prop in props {
    let (_, value) = prop
    match value {
      Null | Boolean(_) | Num(_) | Str(_) => ()
      _ => if val_has_dynamic(value) { return true }
    }
  }
  false
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
    Element(type_name, statement_id, props, partial, dynamic) => {
      if !with_id && statement_id != "" && encoded_elements.val.length() > 0 {
        match encoded_elements.val.get(statement_id) {
          Some(json) => {
            buf.write_string(json)
            return
          }
          None => ()
        }
      }
      buf.write_string("{\"type\":\"element\",\"typeName\":")
      write_json_string(buf, type_name)
      buf.write_string(",\"props\":")
      write_val_fields(buf, props)
      buf.write_string(",\"partial\":")
      write_json_bool(buf, partial)
      buf.write_string(",\"hasDynamicProps\":")
      write_json_bool(buf, dynamic)
      if statement_id != "" {
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
    if err.statement_id != "" {
      buf.write_string(",\"statementId\":")
      write_json_string(buf, err.statement_id)
    }
    if err.warning {
      buf.write_string(",\"severity\":\"warning\"")
    }
    buf.write_char('}')
    index += 1
  }
  buf.write_char(']')
}

///|
fn blank_result() -> String {
  "{\"root\":null,\"meta\":{\"incomplete\":true,\"unresolved\":[],\"orphaned\":[],\"statementCount\":0,\"errors\":[]},\"stateDeclarations\":{},\"queryStatements\":[],\"mutationStatements\":[]}"
}

///|
fn empty_tail() -> String {
  ",\"stateDeclarations\":{},\"queryStatements\":[],\"mutationStatements\":[]}"
}

///|
fn has_side_statements(program : Program) -> Bool {
  for stmt in program.statements {
    if starts_with_dollar(stmt.id) {
      return true
    }
    match stmt.expr {
      Comp("Query", _, _) | Comp("Mutation", _, _) => return true
      _ => ()
    }
  }
  false
}

///|
fn collect_state_refs(expr : Expr, found : Array[String]) -> Unit {
  match expr {
    StateRef(name) => push_unique(found, name)
    Arr(items) =>
      for item in items {
        collect_state_refs(item, found)
      }
    Obj(entries) =>
      for entry in entries {
        let (_, value) = entry
        collect_state_refs(value, found)
      }
    Comp(_, _, args) =>
      for arg in args {
        collect_state_refs(arg, found)
      }
    UnaryOp(_, value) => collect_state_refs(value, found)
    BinOp(_, left, right) => {
      collect_state_refs(left, found)
      collect_state_refs(right, found)
    }
    Ternary(cond, yes, no) => {
      collect_state_refs(cond, found)
      collect_state_refs(yes, found)
      collect_state_refs(no, found)
    }
    Member(value, _) => collect_state_refs(value, found)
    Index(value, index) => {
      collect_state_refs(value, found)
      collect_state_refs(index, found)
    }
    Assign(_, value) => collect_state_refs(value, found)
    _ => ()
  }
}

///|
fn write_expr_or_null(
  buf : StringBuilder,
  args : Array[Expr],
  index : Int32,
) -> Unit {
  if index < args.length() {
    write_expr_json(buf, args[index])
  } else {
    buf.write_string("null")
  }
}

///|
fn write_state_value(
  buf : StringBuilder,
  expr : Expr,
  line : Int32,
  schema : String,
) -> Array[Issue] {
  let (value, issues) = materialize_statement({ id: "", expr, line, }, schema)
  write_val(buf, value, false)
  issues
}

///|
/// `stateDeclarations`, `queryStatements`, and `mutationStatements` in official order.
fn side_tail(program : Program, schema : String) -> (String, Array[Issue]) {
  let keys : Array[String] = []
  let values : Map[String, String] = Map([])
  let extra : Array[Issue] = []
  let queries : Array[String] = []
  let mutations : Array[String] = []
  for stmt in program.statements {
    match stmt.expr {
      Comp("Query", _, args) => {
        let buf = StringBuilder()
        buf.write_string("{\"statementId\":")
        write_json_string(buf, stmt.id)
        buf.write_string(",\"toolAST\":")
        write_expr_or_null(buf, args, 0)
        buf.write_string(",\"argsAST\":")
        write_expr_or_null(buf, args, 1)
        buf.write_string(",\"defaultsAST\":")
        write_expr_or_null(buf, args, 2)
        buf.write_string(",\"refreshAST\":")
        write_expr_or_null(buf, args, 3)
        if args.length() > 1 {
          let deps : Array[String] = []
          collect_state_refs(args[1], deps)
          if deps.length() > 0 {
            buf.write_string(",\"deps\":")
            write_string_list(buf, deps)
          }
        }
        buf.write_string(",\"complete\":true}")
        queries.push(buf.to_string())
      }
      Comp("Mutation", _, args) => {
        let buf = StringBuilder()
        buf.write_string("{\"statementId\":")
        write_json_string(buf, stmt.id)
        buf.write_string(",\"toolAST\":")
        write_expr_or_null(buf, args, 0)
        buf.write_string(",\"argsAST\":")
        write_expr_or_null(buf, args, 1)
        buf.write_char('}')
        mutations.push(buf.to_string())
      }
      _ =>
        if starts_with_dollar(stmt.id) {
          let buf = StringBuilder()
          let issues = write_state_value(buf, stmt.expr, stmt.line, schema)
          for issue in issues {
            extra.push(issue)
          }
          if !list_has(keys, stmt.id) {
            keys.push(stmt.id)
          }
          values[stmt.id] = buf.to_string()
        }
    }
  }
  for stmt in program.statements {
    let found : Array[String] = []
    match stmt.expr {
      Comp("Query", _, args) | Comp("Mutation", _, args) =>
        for arg in args {
          collect_state_refs(arg, found)
        }
      other => collect_state_refs(other, found)
    }
    for name in found {
      if !list_has(keys, name) {
        keys.push(name)
        values[name] = "null"
      }
    }
  }
  let buf = StringBuilder()
  buf.write_string(",\"stateDeclarations\":{")
  let mut index = 0
  for key in keys {
    if index > 0 {
      buf.write_char(',')
    }
    write_json_string(buf, key)
    buf.write_char(':')
    match values.get(key) {
      Some(json) => buf.write_string(json)
      None => buf.write_string("null")
    }
    index = index + 1
  }
  buf.write_string("},\"queryStatements\":[")
  index = 0
  for item in queries {
    if index > 0 {
      buf.write_char(',')
    }
    buf.write_string(item)
    index = index + 1
  }
  buf.write_string("],\"mutationStatements\":[")
  index = 0
  for item in mutations {
    if index > 0 {
      buf.write_char(',')
    }
    buf.write_string(item)
    index = index + 1
  }
  buf.write_string("]}")
  (buf.to_string(), extra)
}

///|
fn reported_issues(errors : Array[Issue]) -> Array[Issue] {
  let kept : Array[Issue] = []
  for err in errors {
    if err.code != "parse-failed" {
      kept.push(err)
    }
  }
  kept
}

///|
fn unique_statement_count(program : Program) -> Int32 {
  let seen : Map[String, Bool] = Map([])
  let mut count : Int32 = 0
  for stmt in program.statements {
    if !seen.contains(stmt.id) {
      seen[stmt.id] = true
      count = count + 1
    }
  }
  count
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
  let prepared = normalize_source(src)
  if prepared.empty {
    return blank_result()
  }
  encoded_elements.val = Map([])
  let program = parse(prepared.text)
  let (root, incomplete, unresolved, orphaned, errors, _count) = materialize_program(
    program,
    schema,
    root_name,
    prepared.incomplete,
    Ref(Map([])),
    0,
  )
  let (tail, extra) = side_tail(program, schema)
  for issue in extra {
    errors.push(issue)
  }
  encode_parse_result(
    root,
    incomplete,
    unresolved,
    orphaned,
    errors,
    unique_statement_count(program),
    tail,
  )
}

///|
fn encode_parse_result(
  root : Val?,
  incomplete : Bool,
  unresolved : Array[String],
  orphaned : Array[String],
  errors : Array[Issue],
  count : Int32,
  tail : String,
) -> String {
  let buf = StringBuilder()
  buf.write_string("{\"root\":")
  match root {
    Some(value) => write_val(buf, value, true)
    None => buf.write_string("null")
  }
  match root_expression.val {
    Some(expr) => {
      buf.write_string(",\"rootExpression\":")
      write_expr_json(buf, expr)
    }
    None => ()
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
  write_issues(buf, reported_issues(errors))
  buf.write_string("}")
  buf.write_string(tail)
  buf.to_string()
}

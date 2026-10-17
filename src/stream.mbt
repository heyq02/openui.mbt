///|
/// One streaming parse. Closed lines stay parsed; a push parses only the new suffix.

///|
/// Flat documents are `root = Comp([refs...])` plus later leaf statements.
/// Closed leaves are encoded once. Later pushes append those fragments.
priv struct Flat {
  mode : Ref[Int32]
  type_name : Ref[String]
  root_id : Ref[String]
  refs : Ref[Array[String]]
  refset : Ref[Map[String, Bool]]
  quoted : Ref[Array[String]]
  unique : Ref[Bool]
  parts : Ref[Array[String]]
  orphans : Ref[Array[String]]
  filled : Ref[Int32]
  complete : Ref[Bool]
  dirty : Ref[Bool]
  bad_leaves : Ref[Int32]
  dynamic : Ref[Bool]
  catalog : Ref[SchemaCatalog]
  seen : Ref[Int32]
  defined : Ref[Map[String, Bool]]
  json : Ref[Map[String, String]]
  issues : Ref[Map[String, Array[Issue]]]
  root_issues : Ref[Array[Issue]]
  schema_issues : Ref[Array[Issue]]
  balanced : Ref[Int32]
}

///|
priv struct Session {
  id : Int32
  buffer : Ref[String]
  schema : String
  root_name : String
  finished : Ref[Bool]
  committed : Ref[Int32]
  newlines : Ref[Int32]
  program : Ref[Program]
  cache : Ref[Map[String, Val]]
  encoded : Ref[Map[String, String]]
  flat : Flat
}

///|
let sessions : Array[Session] = []

///|
let next_stream : Ref[Int32] = Ref(1)

///|
fn line_start(src : String, index : Int32) -> Int32 {
  let mut cursor = index
  while cursor > 0 {
    cursor = cursor - 1
    if src.at(cursor).to_int() == code('\n') {
      return cursor + 1
    }
  }
  0
}

///|
fn prefix(src : String, end : Int32) -> String {
  if end <= 0 {
    ""
  } else if end >= src.length() {
    src
  } else {
    src.unsafe_substring(start=0, end~)
  }
}

///|
fn position_at(src : String, index : Int32) -> (Int32, Int32) {
  let mut line : Int32 = 1
  let mut column : Int32 = 1
  let mut cursor = 0
  let end = if index < src.length() { index } else { src.length() }
  while cursor < end {
    if src.at(cursor).to_int() == code('\n') {
      line = line + 1
      column = 1
    } else {
      column = column + 1
    }
    cursor = cursor + 1
  }
  (line, column)
}

///|
fn ends_with_newline(src : String) -> Bool {
  let length = src.length()
  length > 0 && src.at(length - 1).to_int() == code('\n')
}

///|
/// Before finish, keep only lines that are closed and already parseable.
/// The held-back tail is incomplete, not a final error.
fn view_source(
  src : String,
  open_at : Int32,
  finished : Bool,
) -> (String, Bool) {
  if finished {
    return (src, open_at >= 0)
  }
  if open_at >= 0 {
    return (prefix(src, line_start(src, open_at)), true)
  }
  if !ends_with_newline(src) && src.length() > 0 {
    if parse(src).errors.length() > 0 {
      let cut = line_start(src, src.length() - 1)
      return (prefix(src, cut), true)
    }
  }
  (src, false)
}

///|
fn without_provisional(errors : Array[Issue], finished : Bool) -> Array[Issue] {
  if finished {
    return errors
  }
  let kept : Array[Issue] = []
  for err in errors {
    if err.code != "no-root" {
      kept.push(err)
    }
  }
  kept
}

///|
fn empty_program() -> Program {
  { statements: [], errors: [], }
}

///|
fn count_newlines(src : String) -> Int32 {
  let mut count = 0
  let mut index = 0
  let end = src.length()
  while index < end {
    if src.at(index).to_int() == code('\n') {
      count = count + 1
    }
    index = index + 1
  }
  count
}

///|
fn append_program(
  base : Program,
  extra : Program,
  line_base : Int32,
) -> Program {
  for stmt in extra.statements {
    base.statements.push({
      id: stmt.id,
      expr: stmt.expr,
      line: stmt.line + line_base,
    })
  }
  for err in extra.errors {
    base.errors.push({
      line: err.line + line_base,
      column: err.column,
      kind: err.kind,
    })
  }
  base
}

///|
/// Closed lines end at a newline. The last open line can still grow, so it is not cached.
fn stable_end(text : String, finished : Bool) -> Int32 {
  if finished || ends_with_newline(text) || text.length() == 0 {
    text.length()
  } else {
    line_start(text, text.length() - 1)
  }
}

///|
fn with_tail(base : Program, tail : String, line_base : Int32) -> Program {
  let extra = parse(tail)
  let statements = []
  for stmt in base.statements {
    statements.push(stmt)
  }
  for stmt in extra.statements {
    statements.push({
      id: stmt.id,
      expr: stmt.expr,
      line: stmt.line + line_base,
    })
  }
  { statements, errors: base.errors, }
}

///|
/// Parse only the suffix past `committed`. A shorter or replaced buffer starts over.
fn sync_program(session : Session, text : String, finished : Bool) -> Program {
  let stable = stable_end(text, finished)
  if session.committed.val < stable {
    let delta = text.unsafe_substring(start=session.committed.val, end=stable)
    let program = append_program(
      session.program.val,
      parse(delta),
      session.newlines.val,
    )
    session.committed.val = stable
    session.newlines.val = session.newlines.val + count_newlines(delta)
    session.program.val = program
  }
  if stable == text.length() {
    session.program.val
  } else {
    with_tail(
      session.program.val,
      text.unsafe_substring(start=stable, end=text.length()),
      session.newlines.val,
    )
  }
}

///|
fn new_flat() -> Flat {
  {
    mode: Ref(0),
    type_name: Ref(""),
    root_id: Ref(""),
    refs: Ref([]),
    refset: Ref(Map([])),
    quoted: Ref([]),
    unique: Ref(true),
    parts: Ref([]),
    orphans: Ref([]),
    filled: Ref(0),
    complete: Ref(true),
    dirty: Ref(false),
    bad_leaves: Ref(0),
    dynamic: Ref(false),
    catalog: Ref({ components: [], calls: [], errors: [], }),
    seen: Ref(0),
    defined: Ref(Map([])),
    json: Ref(Map([])),
    issues: Ref(Map([])),
    root_issues: Ref([]),
    schema_issues: Ref([]),
    balanced: Ref(0),
  }
}

///|
fn reset_flat(flat : Flat) -> Unit {
  flat.mode.val = 0
  flat.type_name.val = ""
  flat.root_id.val = ""
  flat.refs.val = []
  flat.refset.val = Map([])
  flat.quoted.val = []
  flat.unique.val = true
  flat.parts.val = []
  flat.orphans.val = []
  flat.filled.val = 0
  flat.complete.val = true
  flat.dirty.val = false
  flat.bad_leaves.val = 0
  flat.dynamic.val = false
  flat.catalog.val = { components: [], calls: [], errors: [], }
  flat.seen.val = 0
  flat.defined.val = Map([])
  flat.json.val = Map([])
  flat.issues.val = Map([])
  flat.root_issues.val = []
  flat.schema_issues.val = []
  flat.balanced.val = 0
}

///|
fn reset_program(session : Session) -> Unit {
  session.committed.val = 0
  session.newlines.val = 0
  session.program.val = empty_program()
  session.cache.val = Map([])
  session.encoded.val = Map([])
  reset_flat(session.flat)
}

///|
/// A balanced prefix stays balanced when text is only appended.
fn session_hold(session : Session) -> Int32 {
  let src = session.buffer.val
  let known = session.flat.balanced.val
  if known == src.length() {
    return -1
  }
  let open = if known == 0 {
    hold_from(src)
  } else {
    let suffix = src.unsafe_substring(start=known, end=src.length())
    let relative = hold_from(suffix)
    if relative < 0 {
      -1
    } else {
      relative + known
    }
  }
  if open < 0 {
    session.flat.balanced.val = src.length()
  }
  open
}

///|
fn root_child_refs(expr : Expr) -> (String, Array[String])? {
  match expr {
    Comp(name, false, args) =>
      if args.length() != 1 {
        None
      } else {
        match args[0] {
          Arr(items) => {
            let names : Array[String] = []
            let mut only_refs = true
            for item in items {
              match item {
                Ref(ref_name) => names.push(ref_name)
                _ => only_refs = false
              }
            }
            if only_refs {
              Some((name, names))
            } else {
              None
            }
          }
          _ => None
        }
      }
    _ => None
  }
}

///|
fn schema_issues(catalog : SchemaCatalog) -> Array[Issue] {
  let issues : Array[Issue] = []
  for err in catalog.errors {
    issues.push({
      code: "schema",
      component: "",
      path: err.path,
      message: err.message(),
      line: 0,
      column: 0,
      statement_id: "",
    })
  }
  issues
}

///|
fn enable_flat(session : Session, stmt : Statement) -> Bool {
  match root_child_refs(stmt.expr) {
    None => false
    Some((type_name, refs)) => {
      let catalog = catalog_for(session.schema)
      match component_params(catalog, type_name) {
        None => false
        Some(_) => {
          let shell = {
            id: stmt.id,
            expr: Comp(type_name, false, [Arr([])]),
            line: stmt.line,
          }
          let (value, issues) = materialize_statement(shell, session.schema)
          match value {
            Element(actual, _, _, _, _) =>
              if actual != type_name {
                return false
              }
            _ => return false
          }
          let refset : Map[String, Bool] = Map([])
          let quoted : Array[String] = []
          let mut unique = true
          for name in refs {
            if refset.contains(name) {
              unique = false
            }
            refset[name] = true
            let quoted_name = StringBuilder()
            write_json_string(quoted_name, name)
            quoted.push(quoted_name.to_string())
          }
          session.flat.mode.val = 1
          session.flat.type_name.val = type_name
          session.flat.root_id.val = stmt.id
          session.flat.refs.val = refs
          session.flat.refset.val = refset
          session.flat.quoted.val = quoted
          session.flat.unique.val = unique
          session.flat.root_issues.val = issues
          session.flat.schema_issues.val = schema_issues(catalog)
          session.flat.catalog.val = catalog
          session.flat.parts.val = []
          session.flat.orphans.val = []
          session.flat.filled.val = 0
          session.flat.complete.val = true
          session.flat.dirty.val = false
          session.flat.bad_leaves.val = 0
          session.flat.seen.val = 0
          true
        }
      }
    }
  }
}

///|
fn prepare_flat(session : Session, committed : Program) -> Bool {
  match session.flat.mode.val {
    2 => false
    1 => true
    _ => {
      let mut roots = 0
      let mut found : Statement? = None
      for stmt in committed.statements {
        if stmt.id == "root" {
          roots = roots + 1
          found = Some(stmt)
        }
      }
      if roots > 1 {
        session.flat.mode.val = 2
        return false
      }
      match found {
        None => false
        Some(stmt) =>
          if enable_flat(session, stmt) {
            true
          } else {
            session.flat.mode.val = 2
            false
          }
      }
    }
  }
}

///|
fn extend_frontier(session : Session, name : String) -> Unit {
  if !session.flat.unique.val || !session.flat.complete.val {
    session.flat.dirty.val = true
    session.flat.complete.val = false
    return
  }
  let refs = session.flat.refs.val
  let filled = session.flat.filled.val
  if filled < refs.length() && refs[filled] == name {
    let parts = session.flat.parts.val
    while session.flat.filled.val < refs.length() &&
          refs[session.flat.filled.val] == name {
      push_part(parts, child_fragment(session, name))
      session.flat.filled.val = session.flat.filled.val + 1
    }
  } else {
    session.flat.dirty.val = true
    session.flat.complete.val = false
  }
}

///|
fn finalize_frontier(session : Session) -> Unit {
  if !session.flat.dirty.val {
    return
  }
  rebuild_parts(session)
  let refs = session.flat.refs.val
  let mut filled = 0
  while filled < refs.length() &&
        session.flat.defined.val.contains(refs[filled]) {
    filled = filled + 1
  }
  let mut on_count = filled
  let mut index = filled
  while index < refs.length() {
    if session.flat.defined.val.contains(refs[index]) {
      on_count = on_count + 1
    }
    index = index + 1
  }
  session.flat.filled.val = filled
  session.flat.complete.val = on_count == filled
  session.flat.dirty.val = !session.flat.complete.val
}

///|
fn store_leaf(session : Session, stmt : Statement) -> Unit {
  session.flat.defined.val[stmt.id] = true
  if session.flat.refset.val.contains(stmt.id) {
    let (json, issues) = leaf_payload(
      stmt,
      session.schema,
      session.flat.catalog.val,
    )
    session.flat.json.val[stmt.id] = json
    if fragment_dynamic(json) {
      session.flat.dynamic.val = true
    }
    session.flat.issues.val[stmt.id] = issues
    if issues.length() > 0 {
      session.flat.bad_leaves.val = session.flat.bad_leaves.val + 1
    }
    extend_frontier(session, stmt.id)
  } else if !starts_with_dollar(stmt.id) {
    session.flat.orphans.val.push(stmt.id)
  }
}

///|
/// Returns false when this committed statement cannot stay on the flat path.
fn absorb_statement(session : Session, stmt : Statement) -> Bool {
  if session.flat.defined.val.contains(stmt.id) {
    return false
  }
  if stmt.id == session.flat.root_id.val {
    session.flat.defined.val[stmt.id] = true
    return true
  }
  if expr_has_ref(stmt.expr) {
    return false
  }
  store_leaf(session, stmt)
  true
}

///|
fn absorb_range(
  session : Session,
  program : Program,
  start : Int32,
  end : Int32,
) -> Bool {
  let mut index = start
  while index < end {
    if !absorb_statement(session, program.statements[index]) {
      return false
    }
    index = index + 1
  }
  true
}

///|
fn append_child(buf : StringBuilder, json : String, started : Bool) -> Bool {
  if json.length() == 0 {
    return started
  }
  if started {
    buf.write_char(',')
  }
  buf.write_string(json)
  true
}

///|
fn child_fragment(session : Session, name : String) -> String {
  match session.flat.json.val.get(name) {
    Some(json) => json
    None => ""
  }
}

///|
fn push_part(parts : Array[String], json : String) -> Unit {
  if json.length() > 0 {
    parts.push(json)
  }
}

///|
fn rebuild_parts(session : Session) -> Unit {
  let parts : Array[String] = []
  let refs = session.flat.refs.val
  let mut index = 0
  while index < refs.length() {
    let name = refs[index]
    if session.flat.defined.val.contains(name) {
      push_part(parts, child_fragment(session, name))
    }
    index = index + 1
  }
  session.flat.parts.val = parts
}

///|
fn lookup_child(
  session : Session,
  extra : Map[String, String],
  name : String,
) -> String? {
  match extra.get(name) {
    Some(json) => Some(json)
    None =>
      if session.flat.defined.val.contains(name) {
        session.flat.json.val.get(name)
      } else {
        None
      }
  }
}

///|
fn fragment_dynamic(json : String) -> Bool {
  json.contains("\"hasDynamicProps\":true")
}

///|
fn write_children(
  buf : StringBuilder,
  session : Session,
  extra : Map[String, String],
) -> Unit {
  let mut started = false
  if extra.length() == 0 {
    for part in session.flat.parts.val {
      started = append_child(buf, part, started)
    }
  } else {
    for name in session.flat.refs.val {
      match lookup_child(session, extra, name) {
        Some(json) => started = append_child(buf, json, started)
        None => ()
      }
    }
  }
}

///|
fn write_quoted_suffix(
  buf : StringBuilder,
  quoted : Array[String],
  start : Int32,
) -> Unit {
  buf.write_char('[')
  let mut index = start
  while index < quoted.length() {
    if index > start {
      buf.write_char(',')
    }
    buf.write_string(quoted[index])
    index = index + 1
  }
  buf.write_char(']')
}

///|
fn name_defined(
  session : Session,
  extra : Map[String, String],
  name : String,
) -> Bool {
  session.flat.defined.val.contains(name) || extra.contains(name)
}

///|
fn flat_unresolved(
  session : Session,
  extra : Map[String, String],
) -> Array[String] {
  let names : Array[String] = []
  for name in session.flat.refs.val {
    if !name_defined(session, extra, name) {
      push_unique(names, name)
    }
  }
  names
}

///|
fn flat_orphans(
  program : Program,
  root_id : String,
  refset : Map[String, Bool],
) -> Array[String] {
  let ids : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for stmt in program.statements {
    if stmt.id != root_id &&
      !starts_with_dollar(stmt.id) &&
      !refset.contains(stmt.id) &&
      !seen.contains(stmt.id) {
      seen[stmt.id] = true
      ids.push(stmt.id)
    }
  }
  ids
}

///|
fn push_issues(target : Array[Issue], items : Array[Issue]) -> Unit {
  for issue in items {
    target.push(issue)
  }
}

///|
fn flat_errors(
  session : Session,
  program : Program,
  extra_issues : Map[String, Array[Issue]],
  defined_extra : Map[String, String],
) -> Array[Issue] {
  let errors : Array[Issue] = []
  for err in program.errors {
    errors.push({
      code: "parse-failed",
      component: "",
      path: "",
      message: err.message(),
      line: err.line,
      column: err.column,
      statement_id: "",
    })
  }
  push_issues(errors, session.flat.schema_issues.val)
  push_issues(errors, session.flat.root_issues.val)
  let seen : Map[String, Bool] = Map([])
  for name in session.flat.refs.val {
    if !seen.contains(name) && name_defined(session, defined_extra, name) {
      seen[name] = true
      match extra_issues.get(name) {
        Some(items) => push_issues(errors, items)
        None =>
          match session.flat.issues.val.get(name) {
            Some(items) => push_issues(errors, items)
            None => ()
          }
      }
    }
  }
  errors
}

///|
fn encode_flat(
  session : Session,
  extra : Map[String, String],
  partial : Bool,
  incomplete : Bool,
  unresolved : Array[String],
  orphaned : Array[String],
  errors : Array[Issue],
  count : Int32,
  tail : String,
) -> String {
  let buf = StringBuilder()
  buf.write_string("{\"root\":{\"type\":\"element\",\"typeName\":")
  write_json_string(buf, session.flat.type_name.val)
  buf.write_string(",\"props\":{\"children\":[")
  write_children(buf, session, extra)
  let mut dynamic = session.flat.dynamic.val
  if !dynamic && extra.length() != 0 {
    for name in session.flat.refs.val {
      match extra.get(name) {
        Some(json) => if fragment_dynamic(json) { dynamic = true }
        None => ()
      }
    }
  }
  buf.write_string("]},\"partial\":")
  write_json_bool(buf, partial)
  buf.write_string(",\"hasDynamicProps\":")
  write_json_bool(buf, dynamic)
  buf.write_string(",\"statementId\":")
  write_json_string(buf, session.flat.root_id.val)
  buf.write_char('}')
  buf.write_string(",\"meta\":{\"incomplete\":")
  write_json_bool(buf, incomplete)
  buf.write_string(",\"unresolved\":")
  if extra.length() == 0 && session.flat.unique.val && session.flat.complete.val {
    write_quoted_suffix(buf, session.flat.quoted.val, session.flat.filled.val)
  } else {
    write_string_list(buf, unresolved)
  }
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

///|
fn tail_statement(
  session : Session,
  stmt : Statement,
  extra : Map[String, String],
  extra_issues : Map[String, Array[Issue]],
  seen : Map[String, Bool],
) -> Bool {
  if expr_has_ref(stmt.expr) {
    return false
  }
  if stmt.id == session.flat.root_id.val ||
    session.flat.defined.val.contains(stmt.id) ||
    seen.contains(stmt.id) {
    return false
  }
  seen[stmt.id] = true
  if session.flat.refset.val.contains(stmt.id) {
    let (json, issues) = leaf_payload(
      stmt,
      session.schema,
      session.flat.catalog.val,
    )
    extra[stmt.id] = json
    extra_issues[stmt.id] = issues
  }
  true
}

///|
/// `None` means this push still needs a full materialize.
fn flat_result(
  session : Session,
  program : Program,
  partial : Bool,
  incomplete : Bool,
  finished : Bool,
) -> String? {
  let committed = session.program.val.statements.length()
  if !prepare_flat(session, session.program.val) {
    return None
  }
  if !absorb_range(
      session,
      session.program.val,
      session.flat.seen.val,
      committed,
    ) {
    session.flat.mode.val = 2
    return None
  }
  session.flat.seen.val = committed
  finalize_frontier(session)
  let extra : Map[String, String] = Map([])
  let extra_issues : Map[String, Array[Issue]] = Map([])
  let seen : Map[String, Bool] = Map([])
  let mut index = committed
  while index < program.statements.length() {
    if !tail_statement(
        session,
        program.statements[index],
        extra,
        extra_issues,
        seen,
      ) {
      return None
    }
    index = index + 1
  }
  let mut errors = if program.errors.length() == 0 &&
    extra_issues.length() == 0 &&
    session.flat.bad_leaves.val == 0 &&
    session.flat.schema_issues.val.length() == 0 &&
    session.flat.root_issues.val.length() == 0 {
    []
  } else {
    flat_errors(session, program, extra_issues, extra)
  }
  errors = without_provisional(errors, finished)
  let unresolved = if extra.length() == 0 &&
    session.flat.unique.val &&
    session.flat.complete.val {
    []
  } else {
    flat_unresolved(session, extra)
  }
  let (tail, side_issues) = if has_side_statements(program) {
    side_tail(program, session.schema)
  } else {
    (empty_tail(), [])
  }
  for issue in side_issues {
    errors.push(issue)
  }
  Some(
    encode_flat(
      session,
      extra,
      partial,
      incomplete,
      unresolved,
      if program.statements.length() == committed {
        session.flat.orphans.val
      } else {
        flat_orphans(program, session.flat.root_id.val, session.flat.refset.val)
      },
      errors,
      unique_statement_count(program),
      tail,
    ),
  )
}

///|
fn unclosed_program(src : String, open_at : Int32) -> (Program, Int32) {
  let cut = line_start(src, open_at)
  let closed = parse(prefix(src, cut))
  let pending = auto_close(src.unsafe_substring(start=cut, end=src.length()))
  let extra = parse(pending.text)
  let seen : Map[String, Bool] = Map([])
  for stmt in closed.statements {
    seen[stmt.id] = true
  }
  let statements : Array[Statement] = []
  for stmt in closed.statements {
    statements.push(stmt)
  }
  for stmt in extra.statements {
    if !(pending.incomplete && seen.contains(stmt.id)) {
      statements.push(stmt)
    }
  }
  (
    { statements, errors: closed.errors, },
    closed.statements.length() + extra.statements.length(),
  )
}

///|
fn present(
  session : Session,
  finished : Bool,
) -> (Val?, Bool, Array[String], Array[String], Array[Issue], Int32) {
  let src = session.buffer.val
  let open_at = session_hold(session)
  if open_at >= 0 && !has_preprocess_marker(src) {
    let (program, count) = unclosed_program(src, open_at)
    let (line, column) = position_at(src, open_at)
    ignore(UnclosedInput.message())
    ignore(line)
    ignore(column)
    let (root, _, unresolved, orphaned, errors, _) = materialize_program(
      program,
      session.schema,
      session.root_name,
      true,
      Ref(Map([])),
      0,
    )
    let reported = without_provisional(errors, finished)
    let (_, tail_issues) = side_tail(program, session.schema)
    for issue in tail_issues {
      reported.push(issue)
    }
    return (root, true, unresolved, orphaned, reported, count)
  }
  if has_preprocess_marker(src) {
    if open_at >= 0 {
      let (line, column) = position_at(src, open_at)
      ignore(UnclosedInput.message())
      ignore(line)
      ignore(column)
    }
    let prepared = normalize_source(src)
    if prepared.empty {
      return (None, true, [], [], [], 0)
    }
    let program = parse(prepared.text)
    let (root, incomplete, unresolved, orphaned, errors, count) = materialize_program(
      program,
      session.schema,
      session.root_name,
      prepared.incomplete,
      Ref(Map([])),
      0,
    )
    let reported = without_provisional(errors, finished)
    let (_, tail_issues) = side_tail(program, session.schema)
    for issue in tail_issues {
      reported.push(issue)
    }
    return (root, incomplete, unresolved, orphaned, reported, count)
  }
  encoded_elements.val = session.encoded.val
  let (text, held) = view_source(src, open_at, finished)
  let program = sync_program(session, text, finished)
  let partial = source_incomplete(text)
  let (root, nested, unresolved, orphaned, errors, count) = materialize_program(
    program,
    session.schema,
    session.root_name,
    partial,
    session.cache,
    session.program.val.statements.length(),
  )
  let incomplete = if finished { nested } else { held || nested }
  let reported = without_provisional(errors, finished)
  (root, incomplete, unresolved, orphaned, reported, count)
}

///|
fn render_json(session : Session, finished : Bool) -> String {
  let src = session.buffer.val
  let open_at = session_hold(session)
  if open_at >= 0 && !has_preprocess_marker(src) {
    let (program, count) = unclosed_program(src, open_at)
    let (root, _, unresolved, orphaned, errors, _) = materialize_program(
      program,
      session.schema,
      session.root_name,
      true,
      Ref(Map([])),
      0,
    )
    let reported = without_provisional(errors, finished)
    let (tail, extra) = side_tail(program, session.schema)
    for issue in extra {
      reported.push(issue)
    }
    return encode_parse_result(
      root, true, unresolved, orphaned, reported, count, tail,
    )
  }
  if has_preprocess_marker(src) {
    return materialize_result(src, session.schema, session.root_name)
  }
  let (text, held) = view_source(src, open_at, finished)
  let program = sync_program(session, text, finished)
  let partial = source_incomplete(text)
  let incomplete = if finished { partial } else { held || partial }
  match flat_result(session, program, partial, incomplete, finished) {
    Some(json) => json
    None => {
      let (root, reported_incomplete, unresolved, orphaned, errors, count) = present(
        session, finished,
      )
      let (tail, _) = if has_side_statements(program) {
        side_tail(program, session.schema)
      } else {
        (empty_tail(), [])
      }
      encode_parse_result(
        root, reported_incomplete, unresolved, orphaned, errors, count, tail,
      )
    }
  }
}

///|
fn render_dump(session : Session, finished : Bool) -> String {
  let (root, incomplete, unresolved, orphaned, errors, _count) = present(
    session, finished,
  )
  result_dump(root, incomplete, unresolved, orphaned, errors)
}

///|
fn find_session(id : Int32) -> Session? {
  for session in sessions {
    if session.id == id {
      return Some(session)
    }
  }
  None
}

///|
fn closed_issue() -> Issue {
  {
    code: "unknown-stream",
    component: "",
    path: "",
    message: StreamClosed.message(),
    line: 0,
    column: 0,
    statement_id: "",
  }
}

///|
fn closed_json() -> String {
  encode_parse_result(None, true, [], [], [closed_issue()], 0, empty_tail())
}

///|
fn closed_dump() -> String {
  result_dump(None, true, [], [], [closed_issue()])
}

///|
fn session_json(session : Session, finished : Bool) -> String {
  render_json(session, finished)
}

///|
fn extends_buffer(prev : String, next : String) -> Bool {
  prev.length() > 0 &&
  next.length() >= prev.length() &&
  next.unsafe_substring(start=0, end=prev.length()) == prev
}

///|
/// Open a streaming parser. `root_name` is used only when there is no `root`.
pub fn stream_open(schema : String, root_name : String) -> Int32 {
  let id = next_stream.val
  next_stream.val = id + 1
  sessions.push({
    id,
    buffer: Ref(""),
    schema,
    root_name,
    finished: Ref(false),
    committed: Ref(0),
    newlines: Ref(0),
    program: Ref(empty_program()),
    cache: Ref(Map([])),
    encoded: Ref(Map([])),
    flat: new_flat(),
  })
  id
}

///|
/// Append text. `complete` 1 runs the final check in the same render.
pub fn stream_append(id : Int32, chunk : String, complete : Int32) -> String {
  match find_session(id) {
    None => closed_json()
    Some(session) => {
      session.buffer.val = session.buffer.val + chunk
      if complete != 0 {
        session.finished.val = true
      }
      session_json(session, session.finished.val)
    }
  }
}

///|
/// Append text and return the latest ParseResult JSON.
pub fn stream_push(id : Int32, chunk : String) -> String {
  stream_append(id, chunk, 0)
}

///|
/// Replace the buffer. A longer text that still starts with the old buffer keeps closed lines.
pub fn stream_replace(id : Int32, text : String, complete : Int32) -> String {
  match find_session(id) {
    None => closed_json()
    Some(session) => {
      if !extends_buffer(session.buffer.val, text) {
        reset_program(session)
      }
      session.buffer.val = text
      if complete != 0 {
        session.finished.val = true
      }
      session_json(session, session.finished.val)
    }
  }
}

///|
/// Replace the buffer and return the latest ParseResult JSON.
pub fn stream_set(id : Int32, text : String) -> String {
  stream_replace(id, text, 0)
}

///|
/// Read the current result. `complete` 1 checks the whole buffer without keeping that check.
pub fn stream_view(id : Int32, complete : Int32) -> String {
  match find_session(id) {
    None => closed_json()
    Some(session) =>
      if complete != 0 && !session.finished.val {
        let (json, _) = preview(session)
        json
      } else {
        session_json(session, session.finished.val)
      }
  }
}

///|
fn preview(session : Session) -> (String, String) {
  encoded_elements.val = Map([])
  let prepared = normalize_source(session.buffer.val)
  if prepared.empty {
    let json = blank_result()
    return (json, result_dump(None, true, [], [], []))
  }
  let program = parse(prepared.text)
  let (root, nested, unresolved, orphaned, errors, count) = materialize_program(
    program,
    session.schema,
    session.root_name,
    prepared.incomplete,
    Ref(Map([])),
    0,
  )
  let (tail, extra) = side_tail(program, session.schema)
  for issue in extra {
    errors.push(issue)
  }
  (
    encode_parse_result(root, nested, unresolved, orphaned, errors, count, tail),
    result_dump(root, nested, unresolved, orphaned, errors),
  )
}

///|
/// Mark the stream finished and run the final check on the whole buffer.
pub fn stream_finish(id : Int32) -> String {
  match find_session(id) {
    None => closed_json()
    Some(session) => {
      session.finished.val = true
      session_json(session, true)
    }
  }
}

///|
/// Drop the session. Later calls report `unknown-stream`.
pub fn stream_close(id : Int32) -> Int32 {
  let mut index = 0
  while index < sessions.length() {
    if sessions[index].id == id {
      let _removed = sessions.remove(index)
      return 1
    }
    index = index + 1
  }
  0
}

///|
pub fn stream_dump(id : Int32) -> String {
  match find_session(id) {
    None => closed_dump()
    Some(session) => render_dump(session, session.finished.val)
  }
}

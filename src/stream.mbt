///|
/// One streaming parse. The buffer is reparsed on every update.
priv struct Session {
  id : Int32
  buffer : Ref[String]
  schema : String
  root_name : String
  finished : Ref[Bool]
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
fn view_source(src : String, finished : Bool) -> (String, Bool) {
  if finished {
    return (src, source_incomplete(src))
  }
  let open_at = unclosed_at(src)
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
fn render(
  src : String,
  schema : String,
  root_name : String,
  finished : Bool,
) -> (String, String) {
  let (text, held) = view_source(src, finished)
  let (root, nested, unresolved, orphaned, errors) = materialize_with(
    text, schema, root_name,
  )
  let incomplete = if finished { nested } else { held || nested }
  let reported = without_provisional(errors, finished)
  if finished {
    let open_at = unclosed_at(src)
    if open_at >= 0 {
      let (line, column) = position_at(src, open_at)
      reported.push({
        code: "incomplete",
        component: "",
        path: "",
        message: "unclosed input",
        line,
        column,
      })
    }
  }
  (
    result_json(root, incomplete, unresolved, orphaned, reported),
    result_dump(root, incomplete, unresolved, orphaned, reported),
  )
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
    message: "stream is closed",
    line: 0,
    column: 0,
  }
}

///|
fn closed_json() -> String {
  result_json(None, true, [], [], [closed_issue()])
}

///|
fn closed_dump() -> String {
  result_dump(None, true, [], [], [closed_issue()])
}

///|
fn session_render(session : Session) -> (String, String) {
  render(
    session.buffer.val,
    session.schema,
    session.root_name,
    session.finished.val,
  )
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
  })
  id
}

///|
/// Append text and return the latest materialize JSON.
pub fn stream_push(id : Int32, chunk : String) -> String {
  match find_session(id) {
    None => closed_json()
    Some(session) => {
      session.buffer.val = session.buffer.val + chunk
      let (json, _) = session_render(session)
      json
    }
  }
}

///|
/// Replace the buffer and return the latest materialize JSON.
pub fn stream_set(id : Int32, text : String) -> String {
  match find_session(id) {
    None => closed_json()
    Some(session) => {
      session.buffer.val = text
      let (json, _) = session_render(session)
      json
    }
  }
}

///|
/// Mark the stream finished and run the final check on the whole buffer.
pub fn stream_finish(id : Int32) -> String {
  match find_session(id) {
    None => closed_json()
    Some(session) => {
      session.finished.val = true
      let (json, _) = session_render(session)
      json
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
    Some(session) => {
      let (_, dump) = session_render(session)
      dump
    }
  }
}

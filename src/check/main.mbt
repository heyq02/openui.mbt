///|
extern "C" fn process_exit(code : Int32) = "exit"

///|
async fn hold_async(input : @lexbuf.AsyncLexbuf) -> Int32 {
  let mut depth = 0
  let mut quote = 0
  let mut escape = false
  let mut open_at = -1
  let mut index = 0
  while true {
    lexscan input {
      re"^." as mark => {
        let current = mark.to_int()
        index += 1
        if escape {
          escape = false
          continue
        }
        if quote != 0 {
          if current == '\\'.to_int() {
            escape = true
          } else if current == quote {
            quote = 0
            if depth == 0 {
              open_at = -1
            }
          }
          continue
        }
        if current == '"'.to_int() || current == '\''.to_int() {
          quote = current
          if depth == 0 {
            open_at = index - 1
          }
        } else if current == '('.to_int() ||
          current == '['.to_int() ||
          current == '{'.to_int() {
          if depth == 0 {
            open_at = index - 1
          }
          depth += 1
        } else if current == ')'.to_int() ||
          current == ']'.to_int() ||
          current == '}'.to_int() {
          if depth > 0 {
            depth -= 1
          }
          if depth == 0 {
            open_at = -1
          }
        }
      }
      _ => break
    }
  }
  if quote != 0 || depth > 0 {
    open_at
  } else {
    -1
  }
}

///|
fn source_lines(src : String) -> Array[String] {
  let lines = []
  for part in src.split("\n") {
    lines.push(part.to_owned())
  }
  lines
}

///|
fn report(program : @openui.Program, open_at : Int32) -> Bool {
  let failed = program.errors.length() > 0 || open_at >= 0
  for err in program.errors {
    println(
      err.line.to_string() +
      ":" +
      err.column.to_string() +
      ": " +
      err.kind.message(),
    )
  }
  if open_at >= 0 {
    println("unclosed input at " + open_at.to_string())
  }
  failed
}

///|
async fn main {
  let argv = @env.args()
  if argv.length() < 2 {
    println("Usage: moon run src/check -- <file.openui>")
    process_exit(1)
  }
  let path = argv[1]
  let src = @fs.read_file(path).text()
  let lines = source_lines(src)
  let next = Ref(0)
  let input = @lexbuf.AsyncLexbuf::from_fn(fn() {
    if next.val >= lines.length() {
      None
    } else {
      let line = lines[next.val]
      next.val += 1
      if next.val == lines.length() {
        Some(line)
      } else {
        Some(line + "\n")
      }
    }
  })
  let open_at = hold_async(input)
  if report(@openui.parse(src), open_at) {
    process_exit(1)
  }
}

///|
async test "async lexbuf reports an open bracket" {
  let sent = Ref(false)
  let input = @lexbuf.AsyncLexbuf::from_fn(fn() {
    if sent.val {
      None
    } else {
      sent.val = true
      Some("root = Stack([")
    }
  })
  inspect(hold_async(input), content="12")
}

///|
async test "async lexbuf accepts a closed program" {
  let sent = Ref(false)
  let input = @lexbuf.AsyncLexbuf::from_fn(fn() {
    if sent.val {
      None
    } else {
      sent.val = true
      Some("root = Stack([])\n")
    }
  })
  inspect(hold_async(input), content="-1")
}

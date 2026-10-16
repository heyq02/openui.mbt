///|
fn generated_source(count : Int32) -> String {
  let children = StringBuilder()
  let lines = StringBuilder()
  let mut index = 0
  while index < count {
    if index > 0 {
      children.write_string(", ")
    }
    let id = "f" + index.to_string()
    children.write_string(id)
    lines.write_string(id + " = TextContent(\"" + index.to_string() + "\")\n")
    index += 1
  }
  "root = Stack([" + children.to_string() + "])\n" + lines.to_string()
}

///|
fn closed_program(raw : Int32) -> Bool {
  let count = (raw % 5 + 5) % 5
  let src = generated_source(count)
  let program = parse(src)
  let mid = src.length() / 2
  let chunks = [
    src.unsafe_substring(start=0, end=mid),
    src.unsafe_substring(start=mid, end=src.length()),
  ]
  program.errors.length() == 0 &&
  program.statements.length() == count + 1 &&
  hold_from(src) == -1 &&
  hold_from_chunks(chunks) == hold_from(src)
}

///|
test "quickcheck closed programs agree across chunk splits" {
  @quickcheck.check(closed_program)
}

///|
let stream_schema : String =
  #|{
  #|  "properties": { "Stack": {}, "TextContent": {} },
  #|  "$defs": {
  #|    "Stack": {
  #|      "properties": { "children": { "type": "array" } },
  #|      "required": ["children"]
  #|    },
  #|    "TextContent": {
  #|      "properties": { "text": { "type": "string" } },
  #|      "required": ["text"]
  #|    }
  #|  }
  #|}

///|
test "an unfinished line is held back until finish" {
  let id = stream_open(stream_schema, "")
  let _ = stream_push(id, "root = TextContent(\"Hi\")\nroot = TextContent(\"")
  inspect(
    stream_dump(id),
    content=(
      #|incomplete: true
      #|unresolved:
      #|orphaned:
      #|errors: 0
      #|TextContent
      #|  text: "Hi"
    ),
  )
  let _ = stream_finish(id)
  inspect(
    stream_dump(id),
    content=(
      #|incomplete: true
      #|unresolved:
      #|orphaned:
      #|errors: 1
      #|2:19 incomplete unclosed input
      #|TextContent
      #|  text: ""
    ),
  )
  let _closed = stream_close(id)
}

///|
test "a forward reference resolves when its definition arrives" {
  let id = stream_open(stream_schema, "")
  let _ = stream_push(id, "root = Stack([title])\n")
  inspect(
    stream_dump(id),
    content=(
      #|incomplete: false
      #|unresolved: title
      #|orphaned:
      #|errors: 0
      #|Stack
      #|  children:
      #|
    ),
  )
  let _ = stream_push(id, "title = TextContent(\"Hi\")\n")
  inspect(
    stream_dump(id),
    content=(
      #|incomplete: false
      #|unresolved:
      #|orphaned:
      #|errors: 0
      #|Stack
      #|  children:
      #|    - TextContent
      #|      text: "Hi"
    ),
  )
  let _closed = stream_close(id)
}

///|
test "a bad finished line does not drop the valid root" {
  let id = stream_open(stream_schema, "")
  let _ = stream_set(id, "root = TextContent(\"Hi\")\n!!!\n")
  inspect(
    stream_dump(id),
    content=(
      #|incomplete: false
      #|unresolved:
      #|orphaned:
      #|errors: 1
      #|2:1 parse-failed expected statement
      #|TextContent
      #|  text: "Hi"
    ),
  )
  let _closed = stream_close(id)
}

///|
test "chunked pushes match one complete set" {
  let pushed = stream_open(stream_schema, "")
  let _ = stream_push(pushed, "root = Text")
  let _ = stream_push(pushed, "Content(\"Hi\")\n")
  let replaced = stream_open(stream_schema, "")
  let _ = stream_set(replaced, "root = TextContent(\"Hi\")\n")
  inspect(stream_dump(pushed), content=stream_dump(replaced))
  let _ = stream_close(pushed)
  let _ = stream_close(replaced)
}

///|
test "close drops the wasm session" {
  let id = stream_open(stream_schema, "")
  let _ = stream_push(id, "root = TextContent(\"Hi\")\n")
  inspect(stream_close(id), content="1")
  inspect(stream_close(id), content="0")
  inspect(
    stream_dump(id),
    content=(
      #|incomplete: true
      #|unresolved:
      #|orphaned:
      #|errors: 1
      #|0:0 unknown-stream stream is closed
      #|root: null
    ),
  )
  inspect(stream_push(id, "more").contains("unknown-stream"), content="true")
}

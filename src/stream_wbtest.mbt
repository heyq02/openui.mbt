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
test "an open line stays uncommitted until it closes" {
  let id = stream_open(stream_schema, "")
  let _ = stream_push(id, "root = TextContent(\"Hi\")\n")
  let _ = stream_push(id, "title = TextContent(\"X\")")
  inspect(stream_view(999, 1).contains("unknown-stream"), content="true")
  let open = stream_open(stream_schema, "")
  let _ = stream_push(open, "root = TextContent(\"")
  inspect(stream_view(open, 1).contains("unclosed input"), content="true")
  let _ = stream_close(open)
  let preview = stream_view(id, 1)
  inspect(preview.contains("\"statementCount\":2"), content="true")
  let _ = stream_append(id, "\n", 0)
  let replaced = stream_open(stream_schema, "")
  let _ = stream_replace(replaced, "root = TextContent(\"Hi\")\n", 0)
  let _ = stream_replace(
    replaced, "root = TextContent(\"Hi\")\ntitle = TextContent(\"X\")\n", 1,
  )
  inspect(stream_dump(id), content=stream_dump(replaced))
  let _ = stream_view(id, 0)
  let done = stream_open(stream_schema, "")
  let _ = stream_append(done, "root = TextContent(\"Hi\")\n", 1)
  inspect(stream_dump(done).contains("text: \"Hi\""), content="true")
  let _ = stream_close(id)
  let _ = stream_close(replaced)
  let _ = stream_close(done)
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

///|
test "flat pushes match one-shot materialize" {
  let id = stream_open(stream_schema, "")
  let mut src = ""
  let parts = [
    "root = Stack([b, a])\n", "extra = TextContent(\"E\")\n", "b = TextContent(\"B\")\n",
    "a = TextContent(\"A\")\n",
  ]
  for part in parts {
    src = src + part
    inspect(
      stream_append(id, part, 0),
      content=materialize_result(src, stream_schema, ""),
    )
  }
  let mut mode = 0
  for session in sessions {
    if session.id == id {
      mode = session.flat.mode.val
    }
  }
  inspect(mode, content="1")
  let _ = stream_close(id)
  let early = stream_open(stream_schema, "")
  let _ = stream_push(early, "title = TextContent(\"Hi\")\n")
  let rooted = stream_append(early, "root = Stack([title])\n", 0)
  inspect(
    rooted,
    content=materialize_result(
      "title = TextContent(\"Hi\")\nroot = Stack([title])\n", stream_schema, "",
    ),
  )
  let _ = stream_close(early)
  let bad = stream_open(stream_schema, "")
  let _ = stream_push(bad, "root = Stack([a])\n")
  let missing = stream_append(bad, "a = Missing(\"x\")\n", 0)
  inspect(
    missing,
    content=materialize_result(
      "root = Stack([a])\na = Missing(\"x\")\n", stream_schema, "",
    ),
  )
  let redefined = stream_append(bad, "a = TextContent(\"A\", \"medium\")\n", 0)
  inspect(
    redefined,
    content=materialize_result(
      "root = Stack([a])\na = Missing(\"x\")\na = TextContent(\"A\", \"medium\")\n",
      stream_schema, "",
    ),
  )
  let _ = stream_close(bad)
  let twin = stream_open(stream_schema, "")
  let _ = stream_push(twin, "root = Stack([a, a])\n")
  inspect(
    stream_append(twin, "a = TextContent(\"A\")\n", 0),
    content=materialize_result(
      "root = Stack([a, a])\na = TextContent(\"A\")\n", stream_schema, "",
    ),
  )
  let _ = stream_close(twin)
  let broken = stream_open(stream_schema, "")
  let _ = stream_push(broken, "root = Stack([a])\na = TextContent(\"A\")\n")
  inspect(
    stream_append(broken, "!!!\n", 0),
    content=materialize_result(
      "root = Stack([a])\na = TextContent(\"A\")\n!!!\n", stream_schema, "",
    ),
  )
  let _ = stream_close(broken)
  let open_id = stream_open(stream_schema, "")
  let _ = stream_push(open_id, "root = Stack([a])\n")
  let open = stream_append(open_id, "a = TextContent(\"A\")", 0)
  inspect(
    open,
    content=materialize_result(
      "root = Stack([a])\na = TextContent(\"A\")", stream_schema, "",
    ),
  )
  inspect(stream_view(open_id, 0), content=open)
  let _ = stream_close(open_id)
  let hole = stream_open(stream_schema, "")
  let _ = stream_push(hole, "root = Stack([a, b, d])\n")
  inspect(
    stream_append(hole, "b = TextContent(\"B\")\n", 0),
    content=materialize_result(
      "root = Stack([a, b, d])\nb = TextContent(\"B\")\n", stream_schema, "",
    ),
  )
  inspect(
    stream_append(hole, "a = TextContent(\"A\", \"medium\")\n", 0),
    content=materialize_result(
      "root = Stack([a, b, d])\nb = TextContent(\"B\")\na = TextContent(\"A\", \"medium\")\n",
      stream_schema, "",
    ),
  )
  inspect(
    stream_append(hole, "d = TextContent()\n", 0),
    content=materialize_result(
      "root = Stack([a, b, d])\nb = TextContent(\"B\")\na = TextContent(\"A\", \"medium\")\nd = TextContent()\n",
      stream_schema, "",
    ),
  )
  let _ = stream_close(hole)
}

///|
let rich_schema : String =
  #|{
  #|  "properties": { "Stack": {}, "TextContent": {} },
  #|  "$defs": {
  #|    "Stack": {
  #|      "properties": { "children": { "type": "array" } },
  #|      "required": ["children"]
  #|    },
  #|    "TextContent": {
  #|      "properties": {
  #|        "text": { "type": "string" },
  #|        "flag": { "type": "boolean" },
  #|        "n": { "type": "number" }
  #|      },
  #|      "required": ["text"]
  #|    }
  #|  }
  #|}

///|
test "flat edges stay aligned with one-shot materialize" {
  let rich = stream_open(rich_schema, "")
  let rich_src = "root = Stack([a, b, c, d, e])\na = TextContent(\"A\", false, 1)\nb = TextContent(1)\nc = TextContent(null)\nd = \"hi\"\ne = TextContent([1])\n"
  inspect(
    stream_append(rich, rich_src, 1),
    content=materialize_result(rich_src, rich_schema, ""),
  )
  let _ = stream_close(rich)
  let shapes = [
    "root = Stack(a)\n", "root = Stack([1])\n", "root = Stack(a, b)\n", "root = 1\n",
    "root = Nope([a])\n", "root = Stack([a])\nroot = Stack([b])\n", "root = Stack([a])\na = TextContent(b)\n",
    "root = Stack([a])\na = [b]\n", "root = Stack([a])\na = {k: b}\n", "root = Stack([a])\na = -b\n",
    "root = Stack([a])\na = b + 1\n", "root = Stack([a])\na = b ? 1 : 2\n", "root = Stack([a])\na = b.x\n",
    "root = Stack([a])\na = b[0]\n", "root = Stack([a])\na = x = b\n",
  ]
  for src in shapes {
    let id = stream_open(stream_schema, "")
    inspect(
      stream_append(id, src, 1),
      content=materialize_result(src, stream_schema, ""),
    )
    let _ = stream_close(id)
  }
  let held = stream_open(stream_schema, "")
  let _ = stream_push(held, "root = Stack([a, b])\n")
  let _ = stream_append(held, "a = TextContent(\"A\")\n", 0)
  let tail = "root = Stack([a, b])\na = TextContent(\"A\")\nb = Missing(\"x\")"
  inspect(
    stream_append(held, "b = Missing(\"x\")", 0),
    content=materialize_result(tail, stream_schema, ""),
  )
  let _ = stream_close(held)
  let nested = stream_open(stream_schema, "")
  let _ = stream_push(nested, "root = Stack([a])\n")
  let nested_src = "root = Stack([a])\na = TextContent(b)"
  inspect(
    stream_append(nested, "a = TextContent(b)", 0),
    content=materialize_result(nested_src, stream_schema, ""),
  )
  let _ = stream_close(nested)
  let again = stream_open(stream_schema, "")
  let _ = stream_push(again, "root = Stack([a])\na = TextContent(\"A\")\n")
  let again_src = "root = Stack([a])\na = TextContent(\"A\")\na = TextContent(\"B\")"
  inspect(
    stream_append(again, "a = TextContent(\"B\")", 0),
    content=materialize_result(again_src, stream_schema, ""),
  )
  let _ = stream_close(again)
  let broken_schema =
    #|{
    #|  "properties": { "Stack": {}, "TextContent": {} },
    #|  "$defs": {
    #|    "Stack": {
    #|      "properties": { "children": { "type": "array" } },
    #|      "required": ["children"]
    #|    },
    #|    "TextContent": {
    #|      "properties": { "text": { "type": "nope" } },
    #|      "required": ["text"]
    #|    }
    #|  }
    #|}
  let schema_id = stream_open(broken_schema, "")
  let schema_src = "root = Stack([a])\na = TextContent(\"A\")\n"
  inspect(
    stream_append(schema_id, schema_src, 1),
    content=materialize_result(schema_src, broken_schema, ""),
  )
  let _ = stream_close(schema_id)
  let orphan_tail = stream_open(stream_schema, "")
  let _ = stream_push(orphan_tail, "root = Stack([a, b])\n")
  let orphan_src = "root = Stack([a, b])\nb = TextContent(\"B\")\nextra = TextContent(\"E\")"
  inspect(
    stream_append(
      orphan_tail, "b = TextContent(\"B\")\nextra = TextContent(\"E\")", 0,
    ),
    content=materialize_result(orphan_src, stream_schema, ""),
  )
  let _ = stream_close(orphan_tail)
  let later_tail = stream_open(stream_schema, "")
  let _ = stream_push(later_tail, "root = Stack([a, b])\n")
  let later_src = "root = Stack([a, b])\nb = TextContent(\"B\")"
  inspect(
    stream_append(later_tail, "b = TextContent(\"B\")", 0),
    content=materialize_result(later_src, stream_schema, ""),
  )
  let _ = stream_close(later_tail)
  let open = stream_open(stream_schema, "")
  let _ = stream_push(open, "root = Stack([a])\n")
  let _ = stream_append(open, "a = TextContent(\"", 1)
  inspect(stream_dump(open).contains("unclosed input"), content="true")
  let _ = stream_close(open)
}

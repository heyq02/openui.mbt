///|
test "compact json keeps the statement shape" {
  inspect(
    parse("root = TextContent(\"Hi\", \"large\")\n").compact_json(),
    content="{\"statements\":[{\"id\":\"root\",\"line\":1,\"expr\":{\"k\":\"Comp\",\"name\":\"TextContent\",\"args\":[{\"k\":\"Str\",\"v\":\"Hi\"},{\"k\":\"Str\",\"v\":\"large\"}]}}],\"errors\":[]}",
  )
}

///|
fn use_text(text : String) -> Unit {
  if text.length() < 0 {
    println(text)
  }
}

///|
test "every token kind has a name" {
  let kinds : Array[TokenKind] = [
    Newline,
    LParen,
    RParen,
    LBrack,
    RBrack,
    LBrace,
    RBrace,
    Comma,
    Colon,
    Equals,
    True,
    False,
    Null,
    EOF,
    Str,
    Num,
    Ident,
    Type,
    StateVar,
    Dot,
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    EqEq,
    NotEq,
    Greater,
    Less,
    GreaterEq,
    LessEq,
    And,
    Or,
    Not,
    Question,
    BuiltinCall,
  ]
  let buf = StringBuilder()
  for kind in kinds {
    buf.write_string(kind.name())
    buf.write_char(' ')
  }
  inspect(
    buf.to_string(),
    content="Newline LParen RParen LBrack RBrack LBrace RBrace Comma Colon Equals True False Null EOF Str Num Ident Type StateVar Dot Plus Minus Star Slash Percent EqEq NotEq Greater Less GreaterEq LessEq And Or Not Question BuiltinCall ",
  )
}

///|
test "lexer covers numbers, escapes, and operators" {
  let src = " \t\r#\n" +
    "()[]{},:=true false null \"s\" 1 ident Type $state . + - * / % == != > < >= <= && || ! ? @Foo\n" +
    "1.5 2. 3e 4e+ 5E-2 6e+2 -7.25e-1 1-\n" +
    "\"\\\"\\\\\\/\\b\\f\\n\\r\\t\\u0041\\u00aF\\uD83D\\uDE00\\uD800\\u0041\\u12\\uXXXX\\q\\\"\n" +
    "'a\\'b\\\\c\\n\\t\\q'\n" +
    "\"\\\n"
  for tok in tokenize(src) {
    use_text(tok.kind.name() + tok.text)
  }
  let buf = StringBuilder()
  write_code_point(buf, -1)
  write_code_point(buf, 0xD800)
  write_code_point(buf, 0x110000)
  write_code_point(buf, 0x41)
  use_text(buf.to_string())
  let _digit = hex_digit(code('g'))
  let _upper = hex_digit(code('G'))
  let _lower = hex_digit(code('a'))
  use_text(parse_number("1.5").to_string())
  use_text(parse_number("2E+2").to_string())
  use_text(parse_number("5E-2").to_string())
  use_text(parse_number("3e").to_string())
  use_text(parse_number("4e+").to_string())
  use_text(parse_number("-").to_string())
  use_text(parse_number("1.").to_string())
  use_text(parse_number("-12.25e+3").to_string())
  let lexer = Lexer::{ src: "", index: 0, line: 1, column: 1, }
  lexer.advance()
  let _ended = lexer.peek()
  let _ended_at = lexer.peek_at(0)
}

///|
test "parser and json cover every expression form" {
  let src =
    #|root = (a + b - c) * d / e % f == g != h > i < j >= k <= m && n || p
    #|flag = !true
    #|neg = -1.5e-1
    #|big = 2E+2
    #|empty = null
    #|text = "hi"
    #|name = item.name
    #|slot = items[0]
    #|choice = flag ? name : empty
    #|broken = flag ?
    #|assign = $count = 1
    #|state = $count
    #|obj = { $id: 1, name: null, "k": true, 2: false, : 1, bad }
    #|arr = [1, , null]
    #|call = Title("a", 1)
    #|fn = @Nope(1)
    #|bare = Title
    #|open = (
    #|star = * 1
    #|???
    #|
  use_text(summarize(src))
  use_text(parse_json(src))
  use_text(parse("").to_json().stringify())
  use_text(parse("\n\n").to_json().stringify())
  let expr = parse("root = !null\n").statements[0].expr
  use_text(expr.dump())
  use_text(expr.to_json().stringify())
}

///|
test "schema compilation covers invalid documents and every shape" {
  let samples = [
    "", "null", "[]", "{", "\"unterminated", "{\"a\"", "{\"a\":", "[1,]", "[1 2]",
    "{a:1}", "tru", "fals", "nul", "{\"a\":1 \"b\":2}", "{} x", "-", "1.", "1e",
    "1e+", "01", "\"\\n\\r\\t\\b\\f\\\\\\\"\\/\\u0041\\u00aF\"", "\"\\uD800\"", "\"\\q\"",
    "\"\\u12\"", "\"\\u12GG\"", "\"\u{0001}\"", "  \n\t{\"a\":-12.5e+2,\"b\":0,\"c\":0.5,\"d\":1E-2}",
    "{\"a\":1,\"a\":2}",
  ]
  for sample in samples {
    use_text(compile_schema(sample).dump())
  }
  let rich =
    #|{
    #|  "properties": {
    #|    "Box": { "$ref": "#/$defs/Box" },
    #|    "Missing": {},
    #|    "Box": {}
    #|  },
    #|  "$defs": {
    #|    "Box": {
    #|      "properties": {
    #|        "title": { "type": "string" },
    #|        "count": { "type": "integer" },
    #|        "flag": { "type": "boolean" },
    #|        "empty": { "type": "null" },
    #|        "meta": { "type": "object" },
    #|        "tags": { "type": "array" },
    #|        "status": { "enum": ["on", "off", 1, true, null, {"a":1}, ["x"]] },
    #|        "plain": { "enum": [] },
    #|        "badEnum": { "enum": "on" },
    #|        "value": { "anyOf": [{ "type": "string" }, { "type": "number" }, { "type": "nope" }] },
    #|        "one": { "oneOf": [{ "type": ["string", "null", "date", 1] }] },
    #|        "all": { "allOf": { "type": "string" } },
    #|        "none": { "type": [] },
    #|        "weird": { "type": 1 },
    #|        "ghost": { "type": "date" },
    #|        "link": { "$ref": "#/$defs/Slot" },
    #|        "badRef": { "$ref": 1 },
    #|        "bare": "string",
    #|        "mark": { "const": false },
    #|        "any": {}
    #|      },
    #|      "required": ["title", "missing", 1]
    #|    },
    #|    "Slot": { "properties": "nope", "required": "title" },
    #|    "ActionExpression": { "properties": { "steps": { "type": "array" } } },
    #|    "Save": { "properties": { "id": { "type": "string" } } }
    #|  },
    #|  "functions": {
    #|    "Percent": {
    #|      "params": {
    #|        "properties": { "n": { "type": "number" }, "label": {} },
    #|        "required": ["n"]
    #|      }
    #|    },
    #|    "Broken": { "params": [] },
    #|    "Nope": "x"
    #|  },
    #|  "actions": {
    #|    "Save": { "params": { "properties": { "id": { "type": "string" } } } },
    #|    "Bare": {}
    #|  }
    #|}
  use_text(compile_schema(rich).dump())
  let broken_roots = [
    "{\"properties\":[],\"$defs\":{},\"functions\":[],\"actions\":[]}", "{\"$defs\":{\"Card\":{\"properties\":{\"t\":{\"type\":\"string\"}}},\"ActionExpression\":{},\"OpenUrl\":{},\"ToAssistant\":{},\"Save\":{}},\"actions\":{\"Save\":{\"params\":{}}}}",
  ]
  for sample in broken_roots {
    use_text(compile_schema(sample).dump())
  }
  let reader = SchemaReader::{ src: "", index: 0, failed: false, message: "", }
  let _peek = reader.peek_at(3)
  reader.advance()
  reader.fail("first")
  reader.fail("second")
}

///|
test "materialize covers shapes, runtime clones, and json" {
  let schema =
    #|{
    #|  "properties": { "Box": {}, "Slot": {} },
    #|  "$defs": {
    #|    "Box": {
    #|      "properties": {
    #|        "title": { "type": "string" },
    #|        "count": { "type": "integer" },
    #|        "flag": { "type": "boolean" },
    #|        "empty": { "type": "null" },
    #|        "meta": { "type": "object" },
    #|        "tags": { "type": "array" },
    #|        "status": { "enum": ["on", "off"] },
    #|        "value": { "anyOf": [{ "type": "string" }, { "type": "number" }, { "type": "boolean" }] },
    #|        "note": { "type": ["string", "null"] },
    #|        "ghost": { "type": "date" },
    #|        "link": { "$ref": "#/$defs/Slot" }
    #|      },
    #|      "required": ["title", "count"]
    #|    },
    #|    "Slot": { "properties": { "text": { "type": "string" } }, "required": ["text"] }
    #|  },
    #|  "functions": {
    #|    "Percent": { "params": { "properties": { "n": { "type": "number" } }, "required": ["n"] } }
    #|  },
    #|  "actions": {
    #|    "Save": { "params": { "properties": { "id": { "type": "string" } } } }
    #|  }
    #|}
  let src =
    #|$flag = false
    #|root = Box("ok", 1, true, null, {a: 1, b: "x"}, ["x", slot], "on", "s", null, slot)
    #|slot = Slot($flag)
    #|bad = Box(1, "no", "no", "no", "no", "no", 1, true, 1, 1)
    #|wide = Box("t", 1, true, null, {}, [], "on", "s", "n", slot, "extra")
    #|fn = @Percent(!true + -2, a ? b : c, item.name, items[0], $flag = false, [null, name], {k: "v"}, $flag, name, Slot("a"))
    #|missing = @Nope(1)
    #|inline = Box(Query("x"), Mutation("y"))
    #|cycle = cycle
    #|calc = 1 + 2 * 3 / 4 % 5 == 1 != 2 > 3 < 4 >= 5 <= 6 && true || false
    #|choice = $flag ? slot : bad
    #|alone = Slot("z")
    #|
  use_text(materialize_dump(src, schema, "Box"))
  use_text(materialize_json(src, schema, "Box"))
  use_text(materialize_result(src, schema, "Box"))
  use_text(materialize_result("root = Box(\n", schema, "Box"))
  use_text(materialize_result("root = Box(\"ok\", 1, false)\n", schema, "Box"))
  let escaped = StringBuilder()
  write_json_string(escaped, "\"\\\b\u{000C}\n\r\t\u{0001}")
  use_text(escaped.to_string())
  let _counted = materialize_count(src, schema, "Box")
  use_text(materialize_dump("t = Slot(\"x\")\n", schema, "Box"))
  use_text(materialize_json("", schema, ""))
  use_text(materialize_dump("root = Slot()\npage = Slot(\"x\")\n", schema, ""))
}

///|
test "remaining expression, schema, and materialize branches" {
  let nodes : Array[Expr] = [
    Null,
    Bool(true),
    Bool(false),
    Num(1.0, "1"),
    Str("a\"b"),
    Ref("item"),
    StateRef("$flag"),
    Comp("Title", false, [Str("a")]),
    Comp("Nope", true, [Num(1.0, "1")]),
    Arr([Null, Bool(false), Num(2.0, "2")]),
    Obj([("k", Bool(false)), ("n", Null)]),
    UnaryOp("!", Bool(true)),
    BinOp("+", Num(1.0, "1"), Num(2.0, "2")),
    Ternary(Bool(true), Ref("a"), Ref("b")),
    Member(Ref("item"), "name"),
    Index(Ref("items"), Num(0.0, "0")),
    Assign("$count", Num(1.0, "1")),
  ]
  for node in nodes {
    use_text(clone_expr(node).dump())
    use_text(node.dump())
    use_text(node.to_json().stringify())
    use_text(
      {
        statements: [{ id: "root", expr: node, line: 1, }],
        errors: [{ line: 1, column: 2, message: "a\"b\n", }],
      }.compact_json(),
    )
  }
  let snippets = [
    "-", "1\n-", "$", "@", "\"\\", "'\\'\\\\n\\t\\q'", "\"\\uAB\"", "\"hello\nworld\"",
    "   ", "root = -1\n", "root = -\n", "root = @Foo\n", "root = )\n", "root = [,]\n",
    "root = item.name\n", "root = $count = 1\n", "root = a ? b\n",
  ]
  for snippet in snippets {
    for tok in tokenize(snippet) {
      use_text(tok.text)
    }
    use_text(parse_json(snippet))
    use_text(summarize(snippet))
  }
  use_text(strip_state_prefix("name"))
  use_text(strip_state_prefix(""))
  let lexer = Lexer::{ src: "ab", index: 1, line: 1, column: 2, }
  let _past = lexer.peek_at(5)
  let _short = lexer.read_hex4()
  let _empty = is_after_value([])
  let parser = Parser::{
    tokens: [],
    pos: 0,
    depth: 0,
    ternary_depth: 0,
    errors: [],
  }
  let _eof = parser.peek_kind()
  use_text(json_quote("a\"b\\c\n\r\td"))
  use_text(J::Arr([]).display())
  use_text(J::Arr([J::Num("1"), J::Bool(false), J::Null]).display())
  use_text(
    J::Obj([("a\"b", J::Null), ("c\n", J::Arr([J::Str("x")]))]).display(),
  )
  use_text(SchemaShape::Any.label())
  let failed = SchemaReader::{ src: "1", index: 0, failed: true, message: "x", }
  let _stopped = failed.parse_value()
  let schemas = [
    "{\"$defs\":1,\"properties\":1,\"functions\":1,\"actions\":1}", "{\"$defs\":{\"Box\":{\"properties\":[],\"required\":{}}},\"functions\":{\"F\":{}},\"actions\":{\"A\":{\"params\":[]}}}",
    "{\"$defs\":{\"Box\":{\"properties\":{\"title\":{\"enum\":[\"a\\\"b\",\"a\\\\c\",\"line\\n\",\"tab\\t\",\"cr\\r\",[],{}]}},\"required\":[\"title\"]}},\"properties\":{\"Box\":{}}}",
    "{\"functions\":{\"Percent\":{\"params\":{\"properties\":{\"n\":{}},\"required\":[\"n\"]}}}}",
  ]
  for schema in schemas {
    use_text(compile_schema(schema).dump())
  }
  let schema =
    #|{
    #|  "properties": { "Box": {}, "Slot": {} },
    #|  "$defs": {
    #|    "Box": {
    #|      "properties": {
    #|        "title": { "type": "string" },
    #|        "count": { "type": "integer" },
    #|        "flag": { "type": "boolean" },
    #|        "empty": { "type": "null" },
    #|        "meta": { "type": "object" },
    #|        "tags": { "type": "array" },
    #|        "status": { "enum": ["on", "off"] },
    #|        "value": { "anyOf": [{ "type": "string" }, { "type": "number" }] },
    #|        "ghost": { "type": "date" },
    #|        "link": { "$ref": "#/$defs/Slot" },
    #|        "any": {}
    #|      },
    #|      "required": ["title", "empty"]
    #|    },
    #|    "Slot": { "properties": { "text": { "type": "string" } }, "required": ["text"] }
    #|  },
    #|  "functions": { "Percent": { "params": { "properties": { "n": { "type": "number" } } } } }
    #|}
  let programs = [
    "root = Box(\"ok\", 1, false, null, {flag: false, n: 2, empty: null, child: slot}, [null, false, 1, \"x\", {a: false, b: null, c: 3, d: slot}, [null]], \"on\", \"s\", 1 + 2, slot, @Percent(!true, a ? b : c, item.name, items[0], $flag = false), \"extra\")\nslot = Slot(\"hi\")\n",
    "root = Box(1, \"no\", \"no\", \"no\", \"no\", \"no\", 1, true, 1, 1)\n", "root = Box(\"ok\", 1)\n",
    "first = Box(\"a\", 1, true, null)\nsecond = Box(\"b\", 1, true, null)\n", "root = \"hi\"\n",
    "root = page\npage = Box(\"a\", 1, false, null)\n", "root = a\na = b\nb = a\n",
    "root = Box(\"a\", 1, false, null, {}, [], \"on\", \"s\", @Nope(1), Query(\"q\"))\n",
    "root = @Nope(1)\n", "root = Query(\"q\")\n", "root = u\nu = !true\nm = item.name\ni = items[0]\na = $x = 1\n",
  ]
  for program in programs {
    use_text(materialize_dump(program, schema, "Box"))
    use_text(materialize_json(program, schema, "Box"))
  }
  use_text(json_quote("plain"))
  for tok in tokenize("'\\n'") {
    use_text(tok.text)
  }
  let infix = Parser::{
    tokens: tokenize("name"),
    pos: 0,
    depth: 0,
    ternary_depth: 0,
    errors: [],
  }
  let _left = infix.parse_infix(Null, 0)
  let _shown = literal_display(Boolean(true))
  let _shown_false = literal_display(Boolean(false))
  let _shown_num = literal_display(Num(1.0, "1"))
  let _shown_str = literal_display(Str("a\"b\\c"))
  let _hidden = literal_display(Arr([]))
  let _enum = matches_shape(Enum(["on"]), Arr([]))
  let buf = StringBuilder()
  let element = Element(
    "Box",
    "root",
    [
      ("flag", Boolean(false)),
      ("on", Boolean(true)),
      ("count", Num(1.0, "1")),
      ("empty", Null),
      ("title", Str("a")),
      ("expr", Runtime(Ref("a"))),
      (
        "tags",
        Arr([
          Null,
          Boolean(false),
          Boolean(true),
          Num(1.0, "1"),
          Str("a"),
          Runtime(Ref("a")),
          Arr([Null]),
          Obj([("k", Boolean(false)), ("n", Num(1.0, "1")), ("z", Null)]),
        ]),
      ),
      (
        "meta",
        Obj([
          ("s", Str("a")),
          ("t", Boolean(true)),
          ("f", Boolean(false)),
          ("n", Num(1.0, "1")),
          ("z", Null),
          ("child", Element("Slot", "slot", [], false)),
        ]),
      ),
    ],
    false,
  )
  element.write(buf, 0, false)
  Val::Arr([Val::Null, Val::Boolean(false)]).write(buf, 0, true)
  Val::Obj([("k", Val::Null)]).write(buf, 0, false)
  use_text(buf.to_string())
  use_text(val_json(Boolean(false)).stringify())
  use_text(val_json(element).stringify())
  use_text(
    materialize_dump(
      "title = \"hi\"\npage = Box(\"a\", 1, false, null)\n", schema, "Box",
    ),
  )
  let _quote = source_incomplete("\"hi\\n\"")
  let _single = source_incomplete("'a\\'b'")
  let _open = source_incomplete("(\"")
  let _closed = source_incomplete("(a)")
}

///|
test "stream covers closed sessions and a bad tail" {
  use_text(stream_push(999, "x"))
  use_text(stream_set(999, "x"))
  use_text(stream_finish(999))
  use_text(stream_dump(999))
  let _closed = stream_close(999)
  let id = stream_open("{}", "")
  use_text(stream_push(id, "not a statement"))
  use_text(stream_set(id, "\""))
  use_text(stream_finish(id))
  let _ = stream_close(id)
  use_text(prefix("ab", 0))
  use_text(prefix("ab", 1))
  use_text(prefix("ab", 100))
  let (line, column) = position_at("a\nb", 10)
  use_text(line.to_string() + ":" + column.to_string())
}

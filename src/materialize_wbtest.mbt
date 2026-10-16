///|
let signup_schema : String =
  #|{
  #|  "properties": {
  #|    "Stack": {},
  #|    "TextContent": {},
  #|    "Form": {},
  #|    "FormControl": {},
  #|    "Input": {},
  #|    "Buttons": {},
  #|    "Button": {}
  #|  },
  #|  "$defs": {
  #|    "Stack": { "properties": { "children": { "type": "array" } }, "required": ["children"] },
  #|    "TextContent": {
  #|      "properties": {
  #|        "text": { "type": "string" },
  #|        "size": { "enum": ["large-heavy", "small"] }
  #|      },
  #|      "required": ["text"]
  #|    },
  #|    "Form": {
  #|      "properties": {
  #|        "name": { "type": "string" },
  #|        "buttons": {},
  #|        "fields": { "type": "array" }
  #|      },
  #|      "required": ["name", "fields"]
  #|    },
  #|    "FormControl": {
  #|      "properties": { "label": { "type": "string" }, "control": {} },
  #|      "required": ["label"]
  #|    },
  #|    "Input": {
  #|      "properties": {
  #|        "name": { "type": "string" },
  #|        "placeholder": { "type": "string" },
  #|        "type": { "type": "string" },
  #|        "validation": { "type": "object" }
  #|      }
  #|    },
  #|    "Buttons": {
  #|      "properties": { "buttons": { "type": "array" }, "direction": { "type": "string" } },
  #|      "required": ["buttons"]
  #|    },
  #|    "Button": {
  #|      "properties": { "label": { "type": "string" }, "action": {}, "variant": { "type": "string" } },
  #|      "required": ["label"]
  #|    }
  #|  }
  #|}

///|
test "signup materializes to an element tree" {
  let src =
    #|root = Stack([title, form])
    #|title = TextContent("Sign up", "large-heavy")
    #|form = Form("signup", actions, [nameField, emailField])
    #|nameField = FormControl("Name", Input("name", "Your name", "text", {required: true}))
    #|emailField = FormControl("Email", Input("email", "you@example.com", "email", {required: true, email: true}))
    #|actions = Buttons([submitBtn, cancelBtn], "row")
    #|submitBtn = Button("Submit", @ToAssistant("Sign me up"), "primary")
    #|cancelBtn = Button("Cancel", @ToAssistant("Cancel sign up"), "secondary")
    #|
  inspect(
    materialize_dump(src, signup_schema, ""),
    content=(
      #|incomplete: false
      #|unresolved:
      #|orphaned:
      #|errors: 0
      #|Stack
      #|  children:
      #|    - TextContent
      #|      text: "Sign up"
      #|      size: "large-heavy"
      #|    - Form
      #|      name: "signup"
      #|      buttons:
      #|        Buttons
      #|          buttons:
      #|            - Button
      #|              label: "Submit"
      #|              action: Comp(ToAssistant, [Str("Sign me up")])
      #|              variant: "primary"
      #|            - Button
      #|              label: "Cancel"
      #|              action: Comp(ToAssistant, [Str("Cancel sign up")])
      #|              variant: "secondary"
      #|          direction: "row"
      #|      fields:
      #|        - FormControl
      #|          label: "Name"
      #|          control:
      #|            Input
      #|              name: "name"
      #|              placeholder: "Your name"
      #|              type: "text"
      #|              validation:
      #|                required: true
      #|        - FormControl
      #|          label: "Email"
      #|          control:
      #|            Input
      #|              name: "email"
      #|              placeholder: "you@example.com"
      #|              type: "email"
      #|              validation:
      #|                required: true
      #|                email: true
    ),
  )
}

///|
test "materialize reports missing props, orphans, and unresolved refs" {
  let schema =
    #|{
    #|  "properties": { "Stack": {}, "TextContent": {}, "Card": {} },
    #|  "$defs": {
    #|    "Stack": { "properties": { "children": { "type": "array" } }, "required": ["children"] },
    #|    "TextContent": {
    #|      "properties": { "text": { "type": "string" }, "size": { "enum": ["small", "large"] } },
    #|      "required": ["text"]
    #|    },
    #|    "Card": { "properties": { "title": { "type": "string" } }, "required": ["title"] }
    #|  }
    #|}
  let src =
    #|root = Stack([title, card])
    #|title = TextContent("Hi", "tiny")
    #|card = Card(missing)
    #|extra = TextContent("Spare", "small")
    #|
  inspect(
    materialize_dump(src, schema, ""),
    content=(
      #|incomplete: false
      #|unresolved: missing
      #|orphaned: extra
      #|errors: 2
      #|2:0 type-mismatch field "/size" expects "small"|"large" but got "tiny"
      #|3:0 type-mismatch field "/title" expects string but got null
      #|Stack
      #|  children:
      #|    - TextContent
      #|      text: "Hi"
    ),
  )
}

///|
test "unknown components and missing required props are reported" {
  let schema =
    #|{
    #|  "$defs": {
    #|    "TextContent": {
    #|      "properties": { "text": { "type": "string" } },
    #|      "required": ["text"]
    #|    }
    #|  }
    #|}
  inspect(
    materialize_dump("root = Nope(\"x\")\ntitle = TextContent()\n", schema, ""),
    content=(
      #|incomplete: false
      #|unresolved:
      #|orphaned: title
      #|errors: 1
      #|1:0 unknown-component Unknown component "Nope"
      #|root: null
    ),
  )
}

///|
test "a named root is used when there is no root statement" {
  let schema =
    #|{
    #|  "$defs": {
    #|    "Card": {
    #|      "properties": { "title": { "type": "string" } },
    #|      "required": ["title"]
    #|    }
    #|  }
    #|}
  inspect(
    materialize_dump("card = Card(\"Hi\")\n", schema, "Card"),
    content=(
      #|incomplete: false
      #|unresolved:
      #|orphaned:
      #|errors: 1
      #|0:0 no-root No root statement. Rendering the first statement that calls the root component Card
      #|Card
      #|  title: "Hi"
    ),
  )
}

///|
test "runtime calls publish official mapped props" {
  let names = [
    "Count", "First", "Last", "Sum", "Avg", "Min", "Max", "Sort", "Filter", "Round",
    "Abs", "Floor", "Ceil", "ToAssistant", "OpenUrl",
  ]
  for name in names {
    inspect(mapped_param_names(name) is Some(_), content="true")
  }
  inspect(mapped_param_names("Each") is None, content="true")
  inspect(mapped_param_names("Set") is None, content="true")
  let buf = StringBuilder()
  write_expr_json(buf, Comp("ToAssistant", false, [Str("Hi"), Obj([])]))
  inspect(
    buf.to_string().contains("\"message\":{\"k\":\"Str\",\"v\":\"Hi\"}"),
    content="true",
  )
  inspect(buf.to_string().contains("\"context\""), content="true")
  buf.reset()
  write_expr_json(buf, Comp("Each", false, [Arr([]), Str("item"), Str("item")]))
  inspect(buf.to_string().contains("mappedProps"), content="false")
  cached_catalog.val = {
    components: [],
    calls: [
      {
        name: "Save",
        kind: Action,
        params: [
          {
            name: "id",
            required: true,
            shape: Str,
            node: Leaf("string", None, Absent),
          },
        ],
      },
    ],
    errors: [],
  }
  buf.reset()
  write_expr_json(buf, Comp("Save", false, [Str("1")]))
  inspect(
    buf.to_string().contains("\"id\":{\"k\":\"Str\",\"v\":\"1\"}"),
    content="true",
  )
  inspect(val_has_dynamic(Obj([("steps", Arr([]))])), content="true")
  inspect(val_has_dynamic(Obj([("k", Str("a"))])), content="false")
  inspect(val_has_dynamic(Arr([Runtime(Str("x"))])), content="true")
  inspect(
    val_has_dynamic(Element("T", "", [("a", Num(1.0, "1"))], false, false)),
    content="false",
  )
  inspect(props_have_dynamic([("a", Runtime(Ref("title")))]), content="true")
}

///|
test "unclosed input is incomplete" {
  inspect(source_incomplete("root = Stack([title]"), content="true")
  inspect(source_incomplete("root = Stack([title])\n"), content="false")
}

///|
test "preprocess and state stay in the parse result" {
  let schema =
    #|{
    #|  "properties": { "TextContent": {} },
    #|  "$defs": {
    #|    "TextContent": {
    #|      "properties": { "text": { "type": "string" } },
    #|      "required": ["text"]
    #|    }
    #|  }
    #|}
  inspect(preprocess("  \n"), content="")
  inspect(
    preprocess("```openui\nroot = TextContent(\"Hi\")\n```"),
    content="root = TextContent(\"Hi\")",
  )
  inspect(
    preprocess("root = TextContent(\"Hi\") // note\n# hidden\n"),
    content="root = TextContent(\"Hi\")",
  )
  inspect(
    preprocess("root = TextContent(\"// keep\")"),
    content="root = TextContent(\"// keep\")",
  )
  let closed = auto_close("root = TextContent(\"")
  inspect(closed.incomplete, content="true")
  inspect(closed.text, content="root = TextContent(\"\")")
  inspect(auto_close("root = Stack([").text, content="root = Stack([])")
  inspect(auto_close("root = Obj({").text, content="root = Obj({})")
  inspect(auto_close("root = TextContent(\"Hi\")").incomplete, content="false")
  let escaped = auto_close("root = TextContent(\"\\")
  inspect(escaped.incomplete, content="true")
  inspect(escaped.text, content="root = TextContent(\"\\\\\")")
  inspect(normalize_source("   ").empty, content="true")
  inspect(
    normalize_source("root = TextContent(\"Hi\")\n").incomplete,
    content="false",
  )
  let fenced = materialize_result(
    "```ui\nroot = TextContent(\"Hi\") // c\n```", schema, "",
  )
  inspect(fenced.contains("\"text\":\"Hi\""), content="true")
  let stated = materialize_result(
    "root = TextContent($name)\n$name = \"Ada\"\nuser = Query(\"tool\", $name)\nsave = Mutation(\"tool\", { id: 1 })\n",
    schema, "",
  )
  inspect(stated.contains("\"$name\":\"Ada\""), content="true")
  inspect(stated.contains("\"statementId\":\"user\""), content="true")
  inspect(stated.contains("\"deps\":[\"$name\"]"), content="true")
  inspect(stated.contains("\"statementId\":\"save\""), content="true")
  let missing = materialize_result("root = TextContent($ghost)\n", schema, "")
  inspect(missing.contains("\"$ghost\":null"), content="true")
  inspect(needs_normalize("a // b"), content="true")
  inspect(preprocess("# only"), content="")
  inspect(normalize_source("# only").empty, content="true")
  inspect(
    materialize_result("   ", schema, "").contains("\"root\":null"),
    content="true",
  )
  inspect(auto_close("'").text, content="''")
  inspect(auto_close("()[]{}").incomplete, content="false")
  inspect(auto_close("\"\\x").incomplete, content="true")
  inspect(
    preprocess("\"a\\\\\" ```\nroot = A\n```").contains("root = A"),
    content="true",
  )
  inspect(preprocess("\"a\\\"b\" // z"), content="\"a\\\"b\"")
  inspect(preprocess("```openui root = A"), content="")
  inspect(preprocess("```\nroot = A").contains("root = A"), content="true")
  let joined = preprocess("```\nroot = A\n```\n```\nroot = B\n```")
  inspect(joined.contains("root = A"), content="true")
  inspect(joined.contains("root = B"), content="true")
  let both = materialize_result(
    "$a = \"A\"\n$b = \"B\"\nroot = TextContent($a)\n", schema, "",
  )
  inspect(both.contains("\"$a\":\"A\""), content="true")
  inspect(both.contains("\"$b\":\"B\""), content="true")
  let queried = materialize_result(
    "root = TextContent(\"Hi\")\none = Query(\"a\")\ntwo = Query(\"b\", $a)\n", schema,
    "",
  )
  inspect(queried.contains("\"statementId\":\"two\""), content="true")
  let id = stream_open(schema, "")
  inspect(stream_view(id, 1).contains("\"root\":null"), content="true")
  let _ = stream_replace(id, "# only\n", 1)
  inspect(stream_dump(id).contains("incomplete: true"), content="true")
  let _ = stream_close(id)
  let flat = stream_open(stream_schema, "")
  let _ = stream_push(
    flat, "root = Stack([title])\ntitle = TextContent(\"Hi\")\n$name = Nope(\"x\")\n",
  )
  inspect(stream_view(flat, 0).contains("\"$name\""), content="true")
  let _ = stream_close(flat)
  let marked = stream_open(stream_schema, "")
  let _ = stream_replace(
    marked, "root = TextContent(\"Hi\") // c\n$name = Nope(\"x\")\n", 1,
  )
  inspect(stream_dump(marked).contains("incomplete"), content="true")
  let _ = stream_close(marked)
  let preview_id = stream_open(stream_schema, "")
  let _ = stream_push(
    preview_id, "root = TextContent(\"Hi\")\n$name = Nope(\"x\")\n",
  )
  inspect(stream_view(preview_id, 1).contains("\"$name\""), content="true")
  let _ = stream_close(preview_id)
  let nested = stream_open(stream_schema, "")
  let _ = stream_push(nested, "root = TextContent($name)\n$name = \"Ada\"\n")
  inspect(stream_view(nested, 0).contains("\"$name\":\"Ada\""), content="true")
  let _ = stream_close(nested)
  let both = stream_open(stream_schema, "")
  let _ = stream_replace(both, "root = TextContent(\" // c", 1)
  inspect(stream_dump(both).contains("incomplete: true"), content="true")
  let _ = stream_close(both)
}

///|
fn nested_schema() -> String {
  let src =
    #|{
    #|  "properties": {
    #|    "ObjBox": {}, "ArrBox": {}, "TagBox": {}, "EnumBox": {}, "AnyBox": {},
    #|    "ScalarBox": {}, "ListBox": {}, "CardBox": {}, "ReqScalar": {}, "DefBox": {},
    #|    "SlotBox": {}, "ChartBox": {}, "NestDefBox": {}, "FlagBox": {},
    #|    "BagBox": {}, "NeedBox": {}, "EmptyBox": {}
    #|  },
    #|  "$defs": {
    #|    "ObjBox": { "properties": { "info": { "type": "object", "properties": { "author": { "type": "string" }, "views": { "type": "number" } }, "required": ["author"] } } },
    #|    "ArrBox": { "properties": { "rows": { "type": "array", "items": { "type": "object", "properties": { "label": { "type": "string" }, "value": { "type": "number" } }, "required": ["label"] } } } },
    #|    "TagBox": { "properties": { "tags": { "type": "array", "items": { "type": "string" } } } },
    #|    "EnumBox": { "properties": { "status": { "enum": ["active", "inactive"] } } },
    #|    "AnyBox": { "properties": { "combo": { "anyOf": [{ "type": "string" }, { "type": "number" }] } } },
    #|    "ScalarBox": { "properties": { "title": { "type": "string" }, "count": { "type": "number" }, "flag": { "type": "boolean" } } },
    #|    "ListBox": { "properties": { "children": { "type": "array" } } },
    #|    "CardBox": { "properties": { "text": { "type": "string" } }, "required": ["text"] },
    #|    "ReqScalar": { "properties": { "title": { "type": "string" } }, "required": ["title"] },
    #|    "DefBox": { "properties": { "theme": { "type": "string", "default": "dark" } }, "required": ["theme"] },
    #|    "SlotBox": { "properties": { "children": { "type": "array", "items": { "anyOf": [{ "$ref": "#/$defs/CardBox" }] } } } },
    #|    "ChartBox": { "properties": { "labels": { "type": "array", "items": { "type": "string" } }, "variant": { "enum": ["grouped", "stacked"] } }, "required": ["labels"] },
    #|    "NestDefBox": { "properties": { "cfg": { "type": "object", "properties": { "mode": { "enum": ["fast", "slow"], "default": "fast" }, "retries": { "type": "number", "default": 3 } }, "required": ["mode"] } } },
    #|    "FlagBox": { "properties": { "flag": { "type": "boolean", "default": true } }, "required": ["flag"] },
    #|    "BagBox": { "properties": { "bag": { "type": "object", "properties": { "tags": { "type": "array", "items": { "type": "string" } }, "box": { "type": "object", "properties": { "n": { "type": "number" } } } } } } },
    #|    "NeedBox": { "properties": { "info": { "type": "object", "properties": { "author": { "type": "string" } }, "required": ["author"] } }, "required": ["info"] },
    #|    "EmptyBox": { "properties": { "v": { "anyOf": [] } } }
    #|  }
    #|}
  src
}

///|
fn sink_schema() -> String {
  let src =
    #|{
    #|  "properties": { "Sink": {} },
    #|  "$defs": {
    #|    "CardBox": { "properties": { "text": { "type": "string" } } },
    #|    "Sink": { "properties": {
    #|      "a": { "$ref": 1 },
    #|      "b": { "enum": "on" },
    #|      "c": "nope",
    #|      "d": { "anyOf": {} },
    #|      "e": { "anyOf": [{ "type": "string" }] },
    #|      "f": { "anyOf": [] },
    #|      "s": { "anyOf": [1] },
    #|      "g": { "oneOf": [{ "$ref": "#/$defs/CardBox" }] },
    #|      "h": { "oneOf": [{ "type": "number" }] },
    #|      "i": { "oneOf": {} },
    #|      "j": { "allOf": [{ "type": "string" }] },
    #|      "k": { "type": "array", "items": [{ "type": "string" }] },
    #|      "m": { "type": "object", "required": "author" },
    #|      "n": { "type": "object", "required": ["a", 1] },
    #|      "p": { "type": "date" },
    #|      "q": { "default": null },
    #|      "r": { "const": "fixed" }
    #|    } }
    #|  }
    #|}
  src
}

///|
test "nested schema validation follows the official edge rule" {
  let schema = nested_schema()
  let _sink = compile_schema(sink_schema()).dump()
  let tree =
    #|{
    #|  "properties": { "Tree": {} },
    #|  "$defs": {
    #|    "Tree": { "properties": { "node": { "$ref": "#/$defs/__schema0" } }, "required": ["node"] },
    #|    "__schema0": { "type": "object", "properties": { "label": { "type": "string" } } }
    #|  }
    #|}
  inspect(
    materialize_result("root = Tree({ label: \"a\" })", tree, "").contains(
      "\"label\":\"a\"",
    ),
    content="true",
  )
  inspect(
    materialize_result("root = Tree({ label: \"a\" })", tree, "").contains(
      "\"errors\":[]",
    ),
    content="true",
  )
  let ok = materialize_result(
    "root = ObjBox({ author: \"ann\", views: 3 })", schema, "",
  )
  inspect(ok.contains("\"author\":\"ann\""), content="true")
  inspect(ok.contains("\"errors\":[]"), content="true")
  let views = materialize_result(
    "root = ObjBox({ author: \"ann\", views: \"lots\" })", schema, "",
  )
  inspect(views.contains("\"path\":\"/info/views\""), content="true")
  inspect(views.contains("\"author\":\"ann\""), content="true")
  inspect(views.contains("\"views\":"), content="false")
  let rows = materialize_result(
    "root = ArrBox([{ label: \"a\", value: \"x\" }])", schema, "",
  )
  inspect(rows.contains("\"path\":\"/rows/0/value\""), content="true")
  let missing = materialize_result("root = ObjBox({ views: 3 })", schema, "")
  inspect(missing.contains("\"code\":\"missing-required\""), content="true")
  inspect(missing.contains("\"path\":\"/info/author\""), content="true")
  inspect(missing.contains("\"info\""), content="false")
  let nulled = materialize_result(
    "root = ObjBox({ author: null, views: 3 })", schema, "",
  )
  inspect(nulled.contains("\"code\":\"null-required\""), content="true")
  let tags = materialize_result("root = TagBox([\"a\", 2, \"c\"])", schema, "")
  inspect(tags.contains("\"tags\":[\"a\",\"c\"]"), content="true")
  let kept = materialize_result(
    "root = ArrBox([{ label: \"a\", value: 1 }, { value: 2 }])", schema, "",
  )
  inspect(kept.contains("\"label\":\"a\""), content="true")
  inspect(kept.contains("\"value\":2"), content="false")
  inspect(
    materialize_result("root = ReqScalar(5)", schema, "").contains(
      "\"root\":null",
    ),
    content="true",
  )
  let theme = materialize_result("root = DefBox(5)", schema, "")
  inspect(theme.contains("\"theme\":\"dark\""), content="true")
  inspect(theme.contains("\"code\":\"type-mismatch\""), content="true")
  let silent = materialize_result("root = DefBox()", schema, "")
  inspect(silent.contains("\"theme\":\"dark\""), content="true")
  inspect(silent.contains("\"errors\":[]"), content="true")
  let flag = materialize_result("root = FlagBox()", schema, "")
  inspect(flag.contains("\"flag\":true"), content="true")
  inspect(flag.contains("\"errors\":[]"), content="true")
  let mode = materialize_result(
    "root = NestDefBox({ mode: \"warp\", retries: 1 })", schema, "",
  )
  inspect(mode.contains("\"mode\":\"fast\""), content="true")
  inspect(mode.contains("\"retries\":1"), content="true")
  let retries = materialize_result(
    "root = NestDefBox({ mode: \"slow\", retries: \"many\" })", schema, "",
  )
  inspect(retries.contains("\"retries\":3"), content="true")
  let absent = materialize_result(
    "root = NestDefBox({ retries: 2 })", schema, "",
  )
  inspect(absent.contains("\"mode\":\"fast\""), content="true")
  inspect(absent.contains("\"errors\":[]"), content="true")
  let filled = materialize_result(
    "root = NestDefBox({ mode: null, retries: 2 })", schema, "",
  )
  inspect(filled.contains("\"mode\":\"fast\""), content="true")
  inspect(filled.contains("\"errors\":[]"), content="true")
  inspect(
    materialize_result(
      "root = ChartBox(CardBox(\"x\"), \"grouped\")", schema, "",
    ).contains("\"root\":null"),
    content="true",
  )
  let variant = materialize_result(
    "root = ChartBox([\"a\"], CardBox(\"x\"))", schema, "",
  )
  inspect(variant.contains("\"variant\":"), content="false")
  inspect(variant.contains("\"labels\":[\"a\"]"), content="true")
  let mixed = materialize_result(
    "root = TagBox([\"a\", CardBox(\"x\"), \"b\"])", schema, "",
  )
  inspect(mixed.contains("\"tags\":[\"a\",\"b\"]"), content="true")
  let slot = materialize_result(
    "root = SlotBox([CardBox(\"hi\"), EnumBox(\"active\")])", schema, "",
  )
  inspect(slot.contains("\"errors\":[]"), content="true")
  inspect(slot.contains("CardBox"), content="true")
  inspect(slot.contains("EnumBox"), content="true")
  let author = materialize_result(
    "root = ObjBox({ author: CardBox(9) })", schema, "",
  )
  inspect(author.contains("\"component\":\"CardBox\""), content="true")
  inspect(author.contains("\"path\":\"/info/author\""), content="true")
  let data = materialize_result(
    "root = SlotBox([CardBox(\"hi\"), { text: \"a\" }, \"b\", 3, [CardBox(\"x\")]])",
    schema, "",
  )
  inspect(data.contains("plain object"), content="true")
  inspect(data.contains("CardBox"), content="true")
  let via = materialize_result(
    "root = SlotBox(items)\nitems = [{ text: \"a\" }]", schema, "",
  )
  inspect(via.contains("\"children\":[]"), content="true")
  inspect(
    materialize_result("root = TagBox([\"a\", $x])", schema, "").contains(
      "\"errors\":[]",
    ),
    content="true",
  )
  inspect(
    materialize_result(
      "root = ObjBox({ author: \"a\", views: Sum([1, 2]) })", schema, "",
    ).contains("\"errors\":[]"),
    content="true",
  )
  inspect(
    materialize_result("root = AnyBox({ anything: true })", schema, "").contains(
      "\"errors\":[]",
    ),
    content="true",
  )
  inspect(
    materialize_result("root = ObjBox(null)", schema, "").contains(
      "\"errors\":[]",
    ),
    content="true",
  )
  inspect(
    materialize_result("root = ObjBox()", schema, "").contains("\"errors\":[]"),
    content="true",
  )
  inspect(
    materialize_result(
      "root = ObjBox({ author: \"a\", bonus: 99 })", schema, "",
    ).contains("\"errors\":[]"),
    content="true",
  )
  inspect(
    materialize_result("root = ListBox([1, \"a\", true])", schema, "").contains(
      "\"errors\":[]",
    ),
    content="true",
  )
  let scalar = materialize_result("root = ScalarBox(5)", schema, "")
  inspect(scalar.contains("\"root\":null"), content="false")
  inspect(scalar.contains("\"title\":"), content="false")
  let open = stream_open(schema, "")
  let partial = stream_push(open, "root = ObjBox({ views: 3 ")
  inspect(partial.contains("\"errors\":[]"), content="true")
  let done = stream_push(open, "})\n")
  inspect(done.contains("\"code\":\"missing-required\""), content="true")
  let _ = stream_close(open)
  let bogus = materialize_result("root = EnumBox(\"bogus\")", schema, "")
  inspect(bogus.contains("active"), content="true")
  inspect(bogus.contains("bogus"), content="true")
  inspect(value_kind(Null), content="null")
  inspect(value_kind(Arr([])), content="array")
  inspect(value_kind(Obj([])), content="object")
  inspect(
    value_kind(Element("Card", "", [], false, false)),
    content="component \"Card\"",
  )
  inspect(value_kind(Runtime(Null)), content="value")
  inspect(slot_actual(Null), content="null")
  inspect(slot_actual(Boolean(true)), content="boolean")
  inspect(
    slot_actual(Element("Card", "", [], false, false)),
    content="component \"Card\"",
  )
  inspect(slot_actual(Runtime(Null)), content="value")
  inspect(same_value(Null, Boolean(true)), content="false")
  inspect(same_value(Arr([Null]), Arr([])), content="false")
  inspect(same_value(Arr([Str("a")]), Arr([Str("b")])), content="false")
  let bag = materialize_result(
    "root = BagBox({ tags: [\"a\", 2], box: \"no\" })", schema, "",
  )
  inspect(bag.contains("\"tags\":[\"a\"]"), content="true")
  inspect(bag.contains("expects object"), content="true")
  inspect(
    materialize_result("root = BagBox({ tags: CardBox(\"x\") })", schema, "").contains(
      "component",
    ),
    content="true",
  )
  inspect(
    materialize_result("root = BagBox({ tags: 1 })", schema, "").contains(
      "expects array",
    ),
    content="true",
  )
  inspect(
    materialize_result("root = ObjBox({ author: 1, views: 3 })", schema, "").contains(
      "\"info\":",
    ),
    content="false",
  )
  inspect(
    materialize_result("root = NeedBox({ views: 3 })", schema, "").contains(
      "\"root\":null",
    ),
    content="true",
  )
  inspect(
    materialize_result(
      "root = NestDefBox({ mode: { a: 1 }, retries: 1 })", schema, "",
    ).contains("\"errors\":[]"),
    content="true",
  )
  inspect(
    materialize_result("root = EmptyBox(1)", schema, "").contains(
      "\"errors\":[]",
    ),
    content="true",
  )
  let cover = Mat::{
    program: { statements: [], errors: [], },
    catalog: compile_schema("{}"),
    defs: Map([]),
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
  inspect(slot_open(cover, []), content="true")
  inspect(plain_node(Items(Open)), content="true")
  inspect(plain_node(Fields([], [])), content="false")
  inspect(scalar_matches(Num, Str("a")), content="false")
  inspect(scalar_matches(Boolean, Num(1.0, "1")), content="false")
  inspect(scalar_matches(Null, Str("a")), content="false")
  inspect(scalar_matches(Null, Null), content="true")
  inspect(scalar_matches(Enum(["\"a\""]), Str("a")), content="false")
  inspect(scalar_matches(Union([Str]), Num(1.0, "1")), content="false")
  inspect(scalar_matches(Union([Str]), Str("a")), content="true")
  inspect(scalar_display(Bool(true)) is Some("true"), content="true")
  inspect(scalar_display(Bool(false)) is Some("false"), content="true")
  inspect(scalar_display(Str("a")) is Some("\"a\""), content="true")
  inspect(scalar_display(Ref("x")) is None, content="true")
  let _enum_element = refine(
    cover,
    "E",
    "/v",
    Leaf("", Some(["\"a\""]), Absent),
    Element("Card", "", [], false, false),
    1,
  )
  let _object_element = refine(
    cover,
    "E",
    "/v",
    Fields([], []),
    Element("Card", "", [], false, false),
    1,
  )
  inspect(
    materialize_result("root = SlotBox([true])", schema, "").contains("boolean"),
    content="true",
  )
  let partial_enum = stream_open(schema, "")
  let held_enum = stream_push(partial_enum, "root = EnumBox(\"")
  inspect(held_enum.contains("\"code\":\"type-mismatch\""), content="false")
  let _ = stream_close(partial_enum)
  inspect(lit_of(Num("nope")) is Absent, content="true")
  inspect(lit_of(Num("")) is Absent, content="true")
  inspect(lit_of(Num(".")) is Absent, content="true")
  inspect(lit_of(Num("1.2.3")) is Absent, content="true")
  inspect(lit_of(Num("1.5")) is Num(1.5, "1.5"), content="true")
}

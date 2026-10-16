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
        params: [{ name: "id", required: true, shape: Str, }],
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

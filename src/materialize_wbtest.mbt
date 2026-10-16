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
test "unclosed input is incomplete" {
  inspect(source_incomplete("root = Stack([title]"), content="true")
  inspect(source_incomplete("root = Stack([title])\n"), content="false")
}

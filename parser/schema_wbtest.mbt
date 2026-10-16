///|
test "schema keeps property order and required flags" {
  let src =
    #|{
    #|  "properties": {
    #|    "TextContent": { "$ref": "#/$defs/TextContent" },
    #|    "Stack": { "$ref": "#/$defs/Stack" }
    #|  },
    #|  "$defs": {
    #|    "Stack": {
    #|      "properties": { "children": { "type": "array" } },
    #|      "required": ["children"]
    #|    },
    #|    "TextContent": {
    #|      "properties": {
    #|        "text": { "type": "string" },
    #|        "size": { "enum": ["large", "small"] }
    #|      },
    #|      "required": ["text"]
    #|    },
    #|    "ActionExpression": {
    #|      "properties": { "steps": { "type": "array" } }
    #|    }
    #|  },
    #|  "functions": {
    #|    "Percent": {
    #|      "params": {
    #|        "properties": {
    #|          "total": { "type": "integer" },
    #|          "part": { "type": "number" }
    #|        },
    #|        "required": ["part"]
    #|      }
    #|    }
    #|  }
    #|}
  inspect(
    compile_schema(src).dump(),
    content=(
      #|components: 2
      #|TextContent(text*: string, size: "large"|"small")
      #|Stack(children*: array)
      #|calls: 1
      #|function Percent(total: number, part*: number)
      #|errors: 0
    ),
  )
}

///|
test "schema reports unknown types and missing properties" {
  let src =
    #|{
    #|  "properties": { "Card": { "$ref": "#/$defs/Card" } },
    #|  "$defs": {
    #|    "Card": {
    #|      "properties": {
    #|        "title": { "type": "string" },
    #|        "tone": { "type": "date" }
    #|      },
    #|      "required": ["title", "missing"]
    #|    }
    #|  }
    #|}
  inspect(
    compile_schema(src).dump(),
    content=(
      #|components: 1
      #|Card(title*: string, tone: date)
      #|calls: 0
      #|errors: 2
      #|$.$defs.Card.properties.tone.type: unknown type "date"
      #|$.$defs.Card.required: "missing" is not a property
    ),
  )
}

///|
test "schema without a component list skips action data" {
  let src =
    #|{
    #|  "$defs": {
    #|    "ActionExpression": { "properties": { "steps": { "type": "array" } } },
    #|    "Card": {
    #|      "properties": { "title": { "const": "hello" } },
    #|      "required": ["title"]
    #|    }
    #|  },
    #|  "actions": {
    #|    "Save": { "params": { "properties": { "id": { "type": "string" } } } }
    #|  }
    #|}
  inspect(
    compile_schema(src).dump(),
    content=(
      #|components: 1
      #|Card(title*: "hello")
      #|calls: 1
      #|action Save(id: string)
      #|errors: 0
    ),
  )
}

///|
test "schema rejects invalid JSON" {
  inspect(
    compile_schema("{").dump(),
    content=(
      #|components: 0
      #|calls: 0
      #|errors: 1
      #|$: invalid JSON at 1
    ),
  )
}

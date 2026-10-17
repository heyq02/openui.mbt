///|
fn shows(text : String, needle : String) -> Bool {
  let limit = text.length() - needle.length()
  let mut index = 0
  while index <= limit {
    if text.unsafe_substring(start=index, end=index + needle.length()) == needle {
      return true
    }
    index = index + 1
  }
  false
}

///|
test "openui generatePrompt matches the official section order" {
  let expected =
    #|You are an AI assistant that responds using openui-lang, a declarative UI language. Your ENTIRE response must be valid openui-lang code — no markdown, no explanations, just openui-lang.
    #|
    #|## Syntax Rules
    #|
    #|1. Each statement is on its own line: `identifier = Expression`
    #|2. `root` is the entry point — every program must define `root = Root(...)`
    #|3. Expressions are: strings ("..."), numbers, booleans (true/false), null, arrays ([...]), objects ({...}), or component calls TypeName(arg1, arg2, ...)
    #|4. Use references for readability: define `name = ...` on one line, then use `name` later
    #|5. EVERY variable (except root) MUST be referenced by at least one other variable. Unreferenced variables are silently dropped and will NOT render. Always include defined variables in their parent's children/items array.
    #|6. Arguments are POSITIONAL (order matters, not names). Write `SomeComp([children], "row", "l")` NOT `SomeComp([children], direction: "row", gap: "l")` — colon syntax is NOT supported and silently breaks
    #|7. Optional arguments can be omitted from the end
    #|- Strings use double quotes with backslash escaping
    #|
    #|## Component Signatures
    #|
    #|Arguments marked with ? are optional. Sub-components can be inline or referenced; prefer references for better streaming.
    #|
    #|Card(title: string) — A card
    #|
    #|## Hoisting & Streaming (CRITICAL)
    #|
    #|openui-lang supports hoisting: a reference can be used BEFORE it is defined. The parser resolves all references after the full input is parsed.
    #|
    #|During streaming, the output is re-parsed on every chunk. Undefined references are temporarily unresolved and appear once their definitions stream in. This creates a progressive top-down reveal — structure first, then data fills in.
    #|
    #|**Recommended statement order for optimal streaming:**
    #|1. `root = Root(...)` — UI shell appears immediately
    #|2. Component definitions — fill in as they stream
    #|3. Data values — leaf content last
    #|
    #|Always write the root = Root(...) statement first so the UI shell appears immediately, even before child data has streamed in.
    #|## Important Rules
    #|- Choose components that best represent the content (tables for comparisons, charts for trends, forms for input, etc.)
    #|
    #|## Final Verification
    #|Before finishing, walk your output and verify:
    #|1. root = Root(...) is the FIRST line (for optimal streaming).
    #|2. Every referenced name is defined. Every defined name (other than root) is reachable from root.
  let minimal = "{\"root\":\"Root\",\"components\":[{\"name\":\"Card\",\"sig\":\"s\",\"signature\":\"Card(title: string)\",\"description\":\"A card\"}],\"builtin\":false,\"toolCalls\":false,\"bindings\":false}"
  inspect(generate_prompt(minimal), content=expected)
  inspect(generate_prompt("{"), content="")
  let rich =
    #|{"root":"Card","preamble":"Custom preamble","components":[{"name":"Card","sig":"s","signature":"Card(title: string, action?: ActionExpression)","description":"A card"},{"name":"Row","sig":"s","signature":"Row(children: (@OpenUrl | @ToAssistant)[])"},{"name":"Bind","sig":"s","signature":"Bind(value?: $binding<string>)"},{"name":"Bare","sig":"u","description":"d"},{"name":"Empty","sig":"n"}],"groups":[{"name":"Layout","components":["Card","Missing","Card"],"notes":["use me"]},{"name":"Extra","components":["Row"]}],"functions":[{"signature":"Double(n: number)","description":"twice"},{"signature":"Z()","description":""}],"actions":[{"name":"Ping","signature":"Ping(msg?: string)","description":"ping"}],"builtin":true,"toolCalls":true,"bindings":true,"tools":[{"k":"s","name":"search"},{"k":"t","name":"metrics","description":"counts","input":{"type":"object","required":["q","o"],"properties":[["q",{"type":"string","required":[],"properties":[],"enum":[]}],["n",{"type":"integer","required":[],"properties":[]}],["a\"b",{"type":"boolean","required":[],"properties":[]}],["x\ny",{"type":"array","required":[],"properties":[]}],["c",{"type":"string","required":[],"properties":[],"enum":["a","b"]}],["\u001f",{"type":"other","required":[],"properties":[]}]]},"output":{"type":"object","required":[],"properties":[["rows",{"type":"array","required":[],"properties":[],"items":{"type":"integer","required":[],"properties":[]}}],["flag",{"type":"boolean","required":[],"properties":[]}],["nest",{"type":"object","required":[],"properties":[]}],["a\"b",{"type":"string","required":[],"properties":[]}],["a\\b",{"type":"number","required":[],"properties":[]}],["\n",{"type":"boolean","required":[],"properties":[]}],["\t",{"type":"string","required":[],"properties":[]}],["\u001f",{"type":"other","required":[],"properties":[]}],["\b",{"type":"string","required":[],"properties":[]}],["\f",{"type":"string","required":[],"properties":[]}],["\r",{"type":"string","required":[],"properties":[]}]]}}],"examples":["ex1",""],"edit":true,"inline":true,"rules":["be brief"]}
  let text = generate_prompt(rich)
  inspect(shows(text, "Custom preamble"), content="true")
  inspect(shows(text, "@Count(array: any[])"), content="true")
  inspect(shows(text, "on Query results"), content="true")
  inspect(shows(text, "@Double(n: number) — twice"), content="true")
  inspect(shows(text, "@Z()"), content="true")
  inspect(shows(text, "@Run(ref: Query | Mutation)"), content="true")
  inspect(shows(text, "@Reset(variable: $variable)"), content="true")
  inspect(shows(text, "- @Ping(msg?: string) — ping"), content="true")
  inspect(shows(text, "## Interactive Filters"), content="true")
  inspect(shows(text, "## Data Workflow"), content="true")
  inspect(shows(text, "- search"), content="true")
  inspect(shows(text, "a\"b?: boolean"), content="true")
  inspect(shows(text, "\\u001f"), content="true")
  inspect(shows(text, "\\n"), content="true")
  inspect(shows(text, "\\t"), content="true")
  inspect(shows(text, "\\b"), content="true")
  inspect(shows(text, "\\f"), content="true")
  inspect(shows(text, "\\r"), content="true")
  inspect(shows(text, "\\\\"), content="true")
  inspect(shows(text, "rows?: number[]"), content="true")
  inspect(shows(text, "use me"), content="true")
  inspect(shows(text, "### Other"), content="true")
  inspect(shows(text, "undefined — d"), content="true")
  inspect(
    shows(text, "Props typed like `@OpenUrl | @ToAssistant`"),
    content="true",
  )
  inspect(shows(text, "ex1"), content="true")
  inspect(shows(text, "## Edit Mode"), content="true")
  inspect(shows(text, "## Inline Mode"), content="true")
  inspect(shows(text, "- be brief"), content="true")
  let custom = "{\"root\":\"Root\",\"components\":[{\"name\":\"Card\",\"sig\":\"s\",\"signature\":\"Card()\"}],\"functions\":[{\"signature\":\"Only()\"}],\"actions\":[{\"name\":\"Go\",\"signature\":\"Go(x?: number)\"}],\"builtin\":false,\"toolCalls\":false,\"bindings\":false}"
  let custom_text = generate_prompt(custom)
  inspect(
    shows(custom_text, "## Built-in Functions\n\n@Only()"),
    content="true",
  )
  inspect(shows(custom_text, "- @Go(x?: number)"), content="true")
  inspect(shows(custom_text, "@Count"), content="false")
  let bound = "{\"root\":\"Root\",\"components\":[{\"name\":\"A\",\"sig\":\"s\",\"signature\":\"A()\"}],\"builtin\":false,\"toolCalls\":false,\"bindings\":true}"
  let bound_text = generate_prompt(bound)
  inspect(shows(bound_text, "Declare mutable state"), content="true")
  inspect(shows(bound_text, "Every $binding appears"), content="true")
  inspect(shows(bound_text, "## Query"), content="false")
  let calls = "{\"root\":\"Root\",\"components\":[{\"name\":\"A\",\"sig\":\"s\",\"signature\":\"A()\"}],\"builtin\":false,\"toolCalls\":true,\"bindings\":false,\"tools\":[{\"k\":\"t\",\"name\":\"bare\",\"output\":{\"type\":\"number\",\"required\":[],\"properties\":[]}}]}"
  let calls_text = generate_prompt(calls)
  inspect(shows(calls_text, "## Query — Live Data Fetching"), content="true")
  inspect(shows(calls_text, "- bare: `0`"), content="true")
  inspect(shows(calls_text, "## Interactive Filters"), content="false")
  let data = "{\"root\":\"Root\",\"components\":[{\"name\":\"A\",\"sig\":\"s\",\"signature\":\"A(v: $binding<string>)\"}],\"builtin\":true,\"toolCalls\":false,\"bindings\":false}"
  let data_text = generate_prompt(data)
  inspect(shows(data_text, "on data"), content="true")
  inspect(shows(data_text, "`$binding<type>`"), content="true")
  inspect(shows(data_text, "3. Query statements"), content="false")
  let odd =
    #|{"root":1,"components":[{"name":"N","sig":"n","description":"d"},{"name":"E","sig":"n"}],"groups":[{"name":"G","components":["E",1],"notes":["ok",1]}],"tools":[{"k":"t","name":"odd","input":{"type":"object","required":[1,"e"],"properties":[[],["nope"],[1,{"type":"string","required":[],"properties":[]}],["k"],["e",{"type":"string","required":[],"properties":[],"enum":[1,true,false,null,{"a":1}]}]]},"output":{"type":"object","required":[],"properties":[["z"],["e",{"type":"string","required":[],"properties":[],"enum":[1,true,false,null]}]]}}],"builtin":false,"toolCalls":true,"bindings":false}
  let odd_text = generate_prompt(odd)
  inspect(shows(odd_text, "null — d"), content="true")
  inspect(shows(odd_text, "\"1\""), content="true")
  inspect(shows(odd_text, "\"true\""), content="true")
  inspect(shows(odd_text, "\"false\""), content="true")
  inspect(shows(odd_text, "\"null\""), content="true")
  let flat = "{\"root\":\"R\",\"components\":[{\"name\":\"E\",\"sig\":\"n\"}],\"builtin\":false,\"toolCalls\":false,\"bindings\":false}"
  inspect(generate_prompt(flat).length() > 0, content="true")
  inspect(generate_prompt("[]").length() > 0, content="true")
  let named = "{\"root\":\"R\",\"components\":[{\"name\":\"A\",\"sig\":\"s\",\"signature\":\"A()\"}],\"tools\":[{\"k\":\"t\",\"name\":\"plain\"}],\"builtin\":false,\"toolCalls\":true,\"bindings\":false}"
  inspect(shows(generate_prompt(named), "- plain()"), content="true")
}

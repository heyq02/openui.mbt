///|
/// System prompt text. Cloud config and telemetry stay in JavaScript.
fn json_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn text_field(value : Json, key : String) -> String {
  match json_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn flag(value : Json, key : String) -> Bool {
  match json_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn array_field(value : Json, key : String) -> Array[Json] {
  match json_field(value, key) {
    Some(Array(items)) => items
    _ => []
  }
}

///|
fn string_list(value : Json, key : String) -> Array[String] {
  let out = []
  for item in array_field(value, key) {
    match item {
      String(text) => out.push(text)
      _ => ()
    }
  }
  out
}

///|
fn has_text(src : String, needle : String) -> Bool {
  let limit = src.length() - needle.length()
  let mut index = 0
  while index <= limit {
    if src.unsafe_substring(start=index, end=index + needle.length()) == needle {
      return true
    }
    index = index + 1
  }
  false
}

///|
fn is_upper(unit : Int32) -> Bool {
  unit >= code('A') && unit <= code('Z')
}

///|
fn restricted_slot(signature : String) -> Bool {
  let limit = signature.length()
  let mut index = 0
  while index + 3 < limit {
    let mark = unit_at(signature, index)
    if (mark == code(':') || mark == code('|')) &&
      unit_at(signature, index + 1) == code(' ') &&
      unit_at(signature, index + 2) == code('@') &&
      is_upper(unit_at(signature, index + 3)) {
      return true
    }
    index = index + 1
  }
  false
}

///|
fn join_sep(parts : Array[String], sep : String) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for part in parts {
    if index > 0 {
      buf.write_string(sep)
    }
    buf.write_string(part)
    index = index + 1
  }
  buf.to_string()
}

///|
fn join_parts(parts : Array[String]) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for part in parts {
    if index > 0 {
      buf.write_char('\n')
    }
    buf.write_string(part)
    index = index + 1
  }
  buf.to_string()
}

///|
fn json_hex(value : Int32) -> Char {
  let unit = if value < 10 { code('0') + value } else { code('a') + value - 10 }
  unit.unsafe_to_char()
}

///|
fn escape_json(text : String) -> String {
  let buf = StringBuilder()
  let mut index = 0
  while index < text.length() {
    let unit = unit_at(text, index)
    if unit == code('"') || unit == code('\\') {
      buf.write_char('\\')
      write_unit(buf, unit)
    } else if unit == 0x08 {
      buf.write_string("\\b")
    } else if unit == 0x0C {
      buf.write_string("\\f")
    } else if unit == 0x0A {
      buf.write_string("\\n")
    } else if unit == 0x0D {
      buf.write_string("\\r")
    } else if unit == 0x09 {
      buf.write_string("\\t")
    } else if unit < 0x20 {
      buf.write_string("\\u00")
      buf.write_char(json_hex(unit / 16))
      buf.write_char(json_hex(unit % 16))
    } else {
      write_unit(buf, unit)
    }
    index = index + 1
  }
  buf.to_string()
}

///|
fn json_string(text : String) -> String {
  "\"" + escape_json(text) + "\""
}

///|
fn schema_type(schema : Json) -> String {
  text_field(schema, "type")
}

///|
fn pair_key(item : Json) -> String {
  match item {
    Array(cells) =>
      if cells.length() > 0 {
        match cells[0] {
          String(text) => text
          _ => ""
        }
      } else {
        ""
      }
    _ => ""
  }
}

///|
fn pair_value(item : Json) -> Json? {
  match item {
    Array(cells) => if cells.length() > 1 { Some(cells[1]) } else { None }
    _ => None
  }
}

///|
fn prop_entries(schema : Json) -> Array[Json] {
  array_field(schema, "properties")
}

///|
fn is_required(schema : Json, key : String) -> Bool {
  for name in string_list(schema, "required") {
    if name == key {
      return true
    }
  }
  false
}

///|
fn enum_text(value : Json) -> String {
  match value {
    String(text) => text
    Number(number, ..) => number.to_string()
    True => "true"
    False => "false"
    Null => "null"
    _ => ""
  }
}

///|
fn type_str(schema : Json) -> String {
  let kind = schema_type(schema)
  if kind == "string" {
    let enums = array_field(schema, "enum")
    if json_field(schema, "enum") is Some(Array(_)) {
      let parts = []
      for item in enums {
        parts.push("\"" + enum_text(item) + "\"")
      }
      return join_sep(parts, " | ")
    }
    return "string"
  }
  if kind == "number" || kind == "integer" {
    return "number"
  }
  if kind == "boolean" {
    return "boolean"
  }
  if kind == "array" {
    match json_field(schema, "items") {
      Some(items) => type_str(items) + "[]"
      None => "any[]"
    }
  } else if kind == "object" {
    let props = prop_entries(schema)
    if props.length() == 0 {
      "object"
    } else {
      let parts = []
      for prop in props {
        let key = pair_key(prop)
        let mark = if is_required(schema, key) { "" } else { "?" }
        match pair_value(prop) {
          Some(value) => parts.push(key + mark + ": " + type_str(value))
          None => parts.push(key + mark + ": any")
        }
      }
      "{" + join_sep(parts, ", ") + "}"
    }
  } else {
    "any"
  }
}

///|
fn default_json(schema : Json) -> String {
  let kind = schema_type(schema)
  if kind == "string" {
    "\"\""
  } else if kind == "number" || kind == "integer" {
    "0"
  } else if kind == "boolean" {
    "false"
  } else if kind == "array" {
    "[]"
  } else if kind == "object" {
    let props = prop_entries(schema)
    if props.length() == 0 {
      "{}"
    } else {
      let buf = StringBuilder()
      buf.write_char('{')
      let mut index = 0
      for prop in props {
        if index > 0 {
          buf.write_char(',')
        }
        buf.write_string(json_string(pair_key(prop)))
        buf.write_char(':')
        match pair_value(prop) {
          Some(value) => buf.write_string(default_json(value))
          None => buf.write_string("null")
        }
        index = index + 1
      }
      buf.write_char('}')
      buf.to_string()
    }
  } else {
    "null"
  }
}

///|
fn syntax_rules(
  root_name : String,
  bindings : Bool,
  expressions : Bool,
) -> String {
  let lines = [
    "## Syntax Rules",
    "",
    "1. Each statement is on its own line: `identifier = Expression`",
    "2. `root` is the entry point — every program must define `root = " +
    root_name +
    "(...)`",
    "3. Expressions are: strings (\"...\"), numbers, booleans (true/false), null, arrays ([...]), objects ({...}), or component calls TypeName(arg1, arg2, ...)",
    "4. Use references for readability: define `name = ...` on one line, then use `name` later",
    "5. EVERY variable (except root) MUST be referenced by at least one other variable. Unreferenced variables are silently dropped and will NOT render. Always include defined variables in their parent's children/items array.",
    "6. Arguments are POSITIONAL (order matters, not names). Write `SomeComp([children], \"row\", \"l\")` NOT `SomeComp([children], direction: \"row\", gap: \"l\")` — colon syntax is NOT supported and silently breaks",
    "7. Optional arguments can be omitted from the end",
  ]
  let mut rule = 8
  if bindings {
    lines.push(
      rule.to_string() +
      ". Declare mutable state with `$varName = defaultValue`. Components marked with `$binding` can read/write these. Undeclared $variables are auto-created with null default.",
    )
    rule = rule + 1
  }
  if expressions {
    lines.push(
      rule.to_string() + ". String concatenation: `\"text\" + $var + \"more\"`",
    )
    rule = rule + 1
    lines.push(
      rule.to_string() +
      ". Dot member access: `query.field` reads a field; on arrays it extracts that field from every element",
    )
    rule = rule + 1
    lines.push(rule.to_string() + ". Index access: `arr[0]`, `data[index]`")
    rule = rule + 1
    lines.push(
      rule.to_string() +
      ". Arithmetic operators: +, -, *, /, % (work on numbers; + is string concat when either side is a string)",
    )
    rule = rule + 1
    lines.push(rule.to_string() + ". Comparison: ==, !=, >, <, >=, <=")
    rule = rule + 1
    lines.push(rule.to_string() + ". Logical: &&, ||, ! (prefix)")
    rule = rule + 1
    lines.push(
      rule.to_string() + ". Ternary: `condition ? valueIfTrue : valueIfFalse`",
    )
    rule = rule + 1
    lines.push(rule.to_string() + ". Parentheses for grouping: `(a + b) * c`")
  }
  lines.push("- Strings use double quotes with backslash escaping")
  join_parts(lines)
}

///|
fn function_line(signature : String, description : String?) -> String {
  match description {
    Some(text) => "@" + signature + " — " + text
    None => "@" + signature
  }
}

///|
fn description_of(value : Json) -> String? {
  match json_field(value, "description") {
    Some(String(text)) => if text.length() == 0 { None } else { Some(text) }
    _ => None
  }
}

///|
fn builtin_function_lines() -> Array[String] {
  [
    "@Count(array: any[]) → number — Returns array length", "@First(array: any[]) → any — Returns first element of array",
    "@Last(array: any[]) → any — Returns last element of array", "@Sum(numbers: number[]) → number — Sum of numeric array",
    "@Avg(numbers: number[]) → number — Average of numeric array", "@Min(numbers: number[]) → number — Minimum value in array",
    "@Max(numbers: number[]) → number — Maximum value in array", "@Sort(array: any[], field: string, direction?: \"asc\" | \"desc\") → any[] — Sort array by field. Direction: \"asc\" (default) or \"desc\"",
    "@Filter(array: any[], field: string, operator: \"==\" | \"!=\" | \">\" | \"<\" | \">=\" | \"<=\" | \"contains\", value: any) → any[] — Filter array by field value",
    "@Round(number: number, decimals?: number) → number — Round to N decimal places (default 0)",
    "@Abs(number: number) → number — Absolute value", "@Floor(number: number) → number — Round down to nearest integer",
    "@Ceil(number: number) → number — Round up to nearest integer", "@Each(array: any[], varName: string, template: any) — Evaluate template for each element. varName is the loop variable — use it ONLY inside the template expression (inline). Do NOT create a separate statement for the template.",
  ]
}

///|
fn builtin_functions_section(
  custom : Array[String],
  tool_calls : Bool,
) -> String {
  let lines = builtin_function_lines()
  for line in custom {
    lines.push(line)
  }
  let subject = if tool_calls { "Query results" } else { "data" }
  let head =
    #|## Built-in Functions
    #|
    #|Data functions prefixed with `@` to distinguish from components. These are the ONLY functions available — do NOT invent new ones.
    #|Use @-prefixed built-in functions (@Count, @Sum, @Avg, @Min, @Max, @Round) on 
  let tail =
    #|. Do NOT hardcode computed values.
    #|
    #|
  let foot =
    #|
    #|
    #|Builtins compose — output of one is input to the next:
    #|`@Count(@Filter(data.rows, "field", "==", "val"))` for KPIs/chart values, `@Round(@Avg(data.rows.score), 1)`, `@Each(data.rows, "item", Comp(item.field))` for per-item rendering.
    #|Array pluck: `data.rows.field` extracts a field from every row → use with @Sum, @Avg, charts, tables.
    #|
    #|IMPORTANT @Each rule: The loop variable (e.g. "item") is ONLY available inside the @Each template expression. Always inline the template — do NOT extract it to a separate statement.
    #|CORRECT: `list = @Each(rows, "t", Comp(t.name))`
    #|WRONG: `item = Comp(t.name)` then `list = @Each(rows, "t", item)`, because t is undefined in item.
  head + subject + tail + join_parts(lines) + foot
}

///|
fn query_section() -> String {
  let text =
    #|## Query — Live Data Fetching
    #|
    #|Fetch data from available tools. Returns defaults instantly, swaps in real data when it arrives.
    #|
    #|```
    #|metrics = Query("tool_name", {arg1: value, arg2: $binding}, {defaultField: 0, defaultData: []}, refreshInterval?)
    #|```
    #|
    #|- First arg: tool name (string)
    #|- Second arg: arguments object (may reference $bindings — re-fetches automatically on change)
    #|- Third arg: default data (rendered immediately before fetch resolves)
    #|- Fourth arg (optional): refresh interval in seconds (e.g. 30 for auto-refresh every 30s)
    #|- Use dot access on results: metrics.totalEvents, metrics.data.day (array pluck)
    #|- Query results must use regular identifiers: `metrics = Query(...)`, NOT `$metrics = Query(...)`
    #|- Manual refresh: `Button("Refresh", Action([@Run(query1), @Run(query2)]), "secondary")` — re-fetches the listed queries
    #|- Refresh all queries: create Action with @Run for each query
  text
}

///|
fn mutation_section() -> String {
  let text =
    #|## Mutation — Write Operations
    #|
    #|Execute state-changing tool calls (create, update, delete). Unlike Query (auto-fetches on render), Mutation fires only on button click via Action.
    #|
    #|```
    #|result = Mutation("tool_name", {arg1: $binding, arg2: "value"})
    #|```
    #|
    #|- First arg: tool name (string)
    #|- Second arg: arguments object (evaluated with current $binding values at click time)
    #|- result.status: "idle" | "loading" | "success" | "error"
    #|- result.data: tool response on success
    #|- result.error: error message on failure
    #|- Mutation results use regular identifiers: `result = Mutation(...)`, NOT `$result`
    #|- Show loading state: `result.status == "loading" ? TextContent("Saving...") : null`
  text
}

///|
fn step_names(tool_calls : Bool, bindings : Bool) -> Array[String] {
  let names = []
  if tool_calls {
    names.push("Run")
  }
  names.push("ToAssistant")
  names.push("OpenUrl")
  if bindings {
    names.push("Set")
    names.push("Reset")
  }
  names
}

///|
fn builtin_step_lines(tool_calls : Bool, bindings : Bool) -> Array[String] {
  let lines = []
  if tool_calls {
    lines.push(
      "- @Run(ref: Query | Mutation) — Execute a Mutation or re-fetch a Query (ref must be a declared Query/Mutation)",
    )
  }
  lines.push(
    "- @ToAssistant(message: string, context?: any) — Send a message to the assistant (for conversational buttons like \"Tell me more\", \"Explain this\"). The optional context is any value (object, array, string, number) passed to the assistant as hidden data, e.g. @ToAssistant(\"Show details\", {orderId: 42})",
  )
  lines.push("- @OpenUrl(url: string) — Navigate to a URL")
  if bindings {
    lines.push(
      "- @Set(variable: $variable, value: any) — Set a $variable to a specific value",
    )
    lines.push(
      "- @Reset(variable: $variable) — Reset $variables to their declared defaults; pass several to reset each (e.g. @Reset($title, $priority) restores $title=\"\" and $priority=\"medium\")",
    )
  }
  lines
}

///|
fn action_section(
  tool_calls : Bool,
  bindings : Bool,
  custom : Array[String],
) -> String {
  let steps = builtin_step_lines(tool_calls, bindings)
  for line in custom {
    steps.push(line)
  }
  let examples = []
  if tool_calls {
    let preferred =
      #|Example — mutation + refresh + reset (PREFERRED pattern):
      #|```
      #|$binding = "default"
      #|result = Mutation("tool_name", {field: $binding})
      #|data = Query("tool_name", {}, {rows: []})
      #|onSubmit = Action([@Run(result), @Run(data), @Reset($binding)])
      #|```
    examples.push(preferred)
  }
  let nav =
    #|Example — simple nav:
    #|```
    #|viewBtn = Button("View", @OpenUrl("https://example.com"))
    #|```
  examples.push(nav)
  let rules = [
    "- An action can be assigned to a variable or inlined: Button(\"Go\", onSubmit) and Button(\"Go\", Action([...])) both work",
  ]
  if tool_calls {
    rules.push(
      "- If a @Run(mutation) step fails, remaining steps are skipped (halt on failure)",
    )
    rules.push(
      "- @Run(queryRef) re-fetches the query (fire-and-forget, cannot fail)",
    )
  }
  let intro =
    #|## Action — Button Behavior
    #|
    #|An action wires a button click to operations. Pass one @-prefixed step bare, e.g. Button("Ask", @ToAssistant("Tell me more")). Put several steps in Action([...]), e.g. Button("Read", Action([@OpenUrl("https://example.com"), @ToAssistant("Summarize this page")])). Steps execute in order.
    #|Buttons without an action automatically send their label to the assistant (equivalent to @ToAssistant(label)).
    #|
    #|Available steps:
  intro +
  "\n" +
  join_parts(steps) +
  "\n\n" +
  join_sep(examples, "\n\n") +
  "\n\n" +
  join_parts(rules)
}

///|
fn filters_section() -> String {
  let text =
    #|## Interactive Filters
    #|
    #|To let the user filter data with a dropdown:
    #|1. Declare a $variable with a default: `$dateRange = "14"`
    #|2. Create a Select with name, items, and binding: `Select("dateRange", [SelectItem("7", "Last 7 days"), ...], null, null, $dateRange)`
    #|3. Wrap in FormControl for a label: `FormControl("Date Range", Select(...))`
    #|4. Pass $dateRange in Query args: `Query("tool", {dateRange: $dateRange}, {defaults})`
    #|5. When the user changes the Select, $dateRange updates and the Query automatically re-fetches
    #|
    #|FILTER WIRING RULE: If a $binding filter is visible in the UI, EVERY relevant Query MUST reference that $binding in its args. Never show a filter dropdown while hardcoding the query args.
    #|
    #|Rules for $variables:
    #|- $variables hold simple values (strings or numbers), NOT arrays or objects
    #|- $variables must be bound to a Select/Input component via the value argument (last positional arg) to be interactive
    #|- Queries must use regular identifiers (NOT $variables): `metrics = Query(...)` not `$metrics = Query(...)`
    #|- **Auto-declare**: You do NOT need to explicitly declare $variables. If you use `$foo` without declaring it, the parser auto-creates `$foo = null`. You can still declare explicitly to set a default: `$days = "14"`
    #|
    #|## Forms
    #|
    #|Simple form — no $bindings needed. Field values are managed internally by the Form via the name prop:
    #|```
    #|contactForm = Form("contact", submitBtn, [nameField, emailField])
    #|nameField = FormControl("Name", Input("name", "Your name", "text", {required: true}))
    #|emailField = FormControl("Email", Input("email", "your@email.com", "email", {required: true, email: true}))
    #|submitBtn = Button("Submit")
    #|```
    #|
    #|Use $bindings when you need to read field values elsewhere (in Action context, Query args, or conditionals). They are auto-declared:
    #|```
    #|$role = "engineer"
    #|contactForm = Form("contact", submitBtn, [nameField, emailField, roleField])
    #|nameField = FormControl("Name", Input("name", "Enter your name", "text", {required: true}, $name))
    #|emailField = FormControl("Email", Input("email", "Enter your email", "email", {required: true, email: true}, $email))
    #|roleField = FormControl("Role", Select("role", [SelectItem("engineer", "Engineer"), SelectItem("designer", "Designer"), SelectItem("pm", "PM")], null, {required: true}, $role))
    #|submitBtn = Button("Submit")
    #|```
    #|
    #|For form + mutation patterns (create, refresh, reset), see the Action section example above.
    #|
    #|IMPORTANT: Always add validation rules to form fields used with Mutations. Use OBJECT syntax: {required: true, email: true, minLength: 8}. The renderer shows error messages automatically and blocks submit when validation fails.
  text
}

///|
fn edit_section() -> String {
  let text =
    #|## Edit Mode
    #|
    #|The runtime merges by statement name: same name = replace, new name = append.
    #|Output ONLY statements that changed or are new. Everything else is kept automatically.
    #|
    #|### Delete
    #|To remove a component, re-declare its parent without that component in the parent's children array. The removed component and any statements only it referenced are automatically garbage-collected.
    #|
    #|### Patch size guide
    #|- Changing a title or label: 1 statement
    #|- Adding a component: 2-3 statements (the new component + parent update)
    #|- Removing a component: 1 statement (re-declare parent without the removed child)
    #|- Adding a filter + wiring to query: 3-5 statements
    #|- Restructuring into tabs: 5-10 statements
    #|
    #|### Rules
    #|- Reuse existing statement names exactly — do not rename
    #|- Do NOT re-emit unchanged statements — the runtime keeps them
    #|- A typical edit patch is 1-10 statements, not 20+
    #|- If the existing code already satisfies the request, output only the root statement
    #|- NEVER output the entire program as a patch. Only output what actually changes
    #|- If you are about to output more than 10 statements, reconsider — most edits need fewer
  text
}

///|
fn streaming_rules(
  root_name : String,
  expressions : Bool,
  tool_calls : Bool,
) -> String {
  let steps = [
    "1. `root = " + root_name + "(...)` — UI shell appears immediately",
  ]
  if expressions {
    steps.push("2. $variable declarations — state ready for bindings")
    if tool_calls {
      steps.push(
        "3. Query statements — defaults resolve immediately so components render with data",
      )
    }
    let count = steps.length()
    steps.push(
      (count + 1).to_string() +
      ". Component definitions — fill in with data already available",
    )
    steps.push((count + 2).to_string() + ". Data values — leaf content last")
  } else {
    steps.push("2. Component definitions — fill in as they stream")
    steps.push("3. Data values — leaf content last")
  }
  let head =
    #|## Hoisting & Streaming (CRITICAL)
    #|
    #|openui-lang supports hoisting: a reference can be used BEFORE it is defined. The parser resolves all references after the full input is parsed.
    #|
    #|During streaming, the output is re-parsed on every chunk. Undefined references are temporarily unresolved and appear once their definitions stream in. This creates a progressive top-down reveal — structure first, then data fills in.
    #|
    #|**Recommended statement order for optimal streaming:**
  let foot = "\n\nAlways write the root = " +
    root_name +
    "(...) statement first so the UI shell appears immediately, even before child data has streamed in."
  head + "\n" + join_parts(steps) + foot
}

///|
fn inline_section() -> String {
  let text =
    #|## Inline Mode
    #|
    #|You are in inline mode. You can respond in two ways:
    #|
    #|### 1. Code response (when the user wants to CREATE or CHANGE the UI)
    #|Wrap openui-lang code in triple-backtick fences. You can include explanatory text before/after:
    #|
    #|Here's your dashboard:
    #|
    #|```openui-lang
    #|root = RootComp([header, content])
    #|header = SomeHeader("Title")
    #|content = SomeContent("Hello world")
    #|```
    #|
    #|I created a simple layout with a header.
    #|
    #|### 2. Text-only response (when the user asks a QUESTION)
    #|If the user asks "what is this?", "explain the chart", "how does this work", etc. — respond with plain text. Do NOT output any openui-lang code. The existing dashboard stays unchanged.
    #|
    #|### Rules
    #|- When the user asks for changes, output ONLY the changed/new statements in a fenced block
    #|- When the user asks a question, respond with text only — NO code. The dashboard stays unchanged.
    #|- The parser extracts code from fences automatically. Text outside fences is shown as chat.
  text
}

///|
fn workflow_section() -> String {
  let text =
    #|## Data Workflow
    #|
    #|When tools are available, follow this workflow:
    #|1. FIRST: Call the most relevant tool to inspect the real data shape before generating code
    #|2. Use Query() for READ operations (data that should stay live) — NEVER hardcode tool results as literal arrays or objects
    #|3. Use Mutation() for WRITE operations (create, update, delete) — triggered by button clicks via @Run(mutationRef)
    #|4. Use the real data from step 1 as condensed Query defaults (3-5 rows) so the UI renders immediately
    #|5. Use @-prefixed builtins (@Count, @Filter, @Sort, @Sum) on Query results for KPIs and aggregations — the runtime evaluates these live on every refresh
    #|6. Hardcoded arrays are ONLY for static display data (labels, options) where no tool exists
    #|
    #|WRONG — you called a tool and got data back, but you inlined the results:
    #|```
    #|openCount = 2
    #|item1 = SomeComp("first item title")
    #|item2 = SomeComp("second item title")
    #|list = SomeList([item1, item2])
    #|chart = SomeChart(["A", "B"], [12, 8])
    #|```
    #|This is static — it shows stale data and won't update. Creating item1, item2, item3... manually is ALWAYS wrong when a tool exists.
    #|
    #|RIGHT — use Query() for live data, Mutation() for writes, @builtins to derive values:
    #|```
    #|data = Query("tool_name", {}, {rows: []})
    #|openCount = @Count(@Filter(data.rows, "field", "==", "value"))
    #|list = @Each(data.rows, "item", SomeComp(item.title, item.field))
    #|createResult = Mutation("create_tool", {title: $title})
    #|submitBtn = Button("Create", Action([@Run(createResult), @Run(data), @Reset($title)]))
    #|```
    #|Everything derives from the Query — when data refreshes, the entire dashboard updates automatically.
  text
}

///|
fn important_rules(
  root_name : String,
  tool_calls : Bool,
  bindings : Bool,
) -> String {
  let lines = [
    "1. root = " +
    root_name +
    "(...) is the FIRST line (for optimal streaming).",
    "2. Every referenced name is defined. Every defined name (other than root) is reachable from root.",
  ]
  if tool_calls {
    lines.push("3. Every Query result is referenced by at least one component.")
  }
  if bindings {
    let number = if tool_calls { "4" } else { "3" }
    lines.push(
      number +
      ". Every $binding appears in at least one component or expression.",
    )
  }
  if tool_calls && bindings {
    lines.push(
      "5. Every visible filter $binding appears in at least one Query args object.",
    )
  }
  let head =
    #|## Important Rules
    #|- Choose components that best represent the content (tables for comparisons, charts for trends, forms for input, etc.)
    #|
    #|## Final Verification
    #|Before finishing, walk your output and verify:
  head + "\n" + join_parts(lines)
}

///|
fn render_tool(tool : Json) -> String {
  let mut args = ""
  match json_field(tool, "input") {
    Some(input) => {
      let props = prop_entries(input)
      if props.length() > 0 {
        let parts = []
        for prop in props {
          let key = pair_key(prop)
          let mark = if is_required(input, key) { "" } else { "?" }
          match pair_value(prop) {
            Some(value) => parts.push(key + mark + ": " + type_str(value))
            None => parts.push(key + mark + ": any")
          }
        }
        args = join_sep(parts, ", ")
      }
    }
    None => ()
  }
  let mut returns = ""
  match json_field(tool, "output") {
    Some(output) => returns = " → " + type_str(output)
    None => ()
  }
  let mut line = "- " + text_field(tool, "name") + "(" + args + ")" + returns
  match description_of(tool) {
    Some(text) => line = line + "\n  " + text
    None => ()
  }
  line
}

///|
fn tools_section(tools : Array[Json]) -> String {
  let strings = []
  let specs = []
  for tool in tools {
    if text_field(tool, "k") == "s" {
      strings.push(tool)
    } else {
      specs.push(tool)
    }
  }
  let lines = [
    "## Available Tools", "", "Use these with Query() for read operations or Mutation() for write operations. The LLM decides which is appropriate based on the tool's purpose.",
    "",
  ]
  for tool in strings {
    lines.push("- " + text_field(tool, "name"))
  }
  for tool in specs {
    lines.push(render_tool(tool))
  }
  let with_output = []
  for tool in specs {
    if json_field(tool, "output") is Some(_) {
      with_output.push(tool)
    }
  }
  if with_output.length() > 0 {
    lines.push("")
    lines.push("### Default values for Query results")
    lines.push("")
    lines.push("Use these shapes as minimal Query defaults:")
    for tool in with_output {
      if json_field(tool, "output") is Some(output) {
        lines.push(
          "- " + text_field(tool, "name") + ": `" + default_json(output) + "`",
        )
      }
    }
  }
  lines.push("")
  lines.push(
    "CRITICAL: Use ONLY the tools listed above in Query() and Mutation() calls. Do NOT invent or guess tool names. If the user asks for functionality that doesn't match any available tool, use realistic mock data instead of fabricating a tool call.",
  )
  join_parts(lines)
}

///|
fn shown_signature(comp : Json) -> String? {
  let mode = text_field(comp, "sig")
  match description_of(comp) {
    Some(text) =>
      if mode == "n" {
        Some("null — " + text)
      } else if mode == "u" {
        Some("undefined — " + text)
      } else {
        Some(text_field(comp, "signature") + " — " + text)
      }
    None => if mode == "s" { Some(text_field(comp, "signature")) } else { None }
  }
}

///|
fn signature_text(comp : Json) -> String {
  if text_field(comp, "sig") == "s" {
    text_field(comp, "signature")
  } else {
    ""
  }
}

///|
fn uses_action(components : Array[Json]) -> Bool {
  for comp in components {
    let signature = signature_text(comp)
    if has_text(signature, "ActionExpression") || restricted_slot(signature) {
      return true
    }
  }
  false
}

///|
fn binding_hint(bindings : Bool, components : Array[Json]) -> Bool {
  if bindings {
    return true
  }
  for comp in components {
    if has_text(signature_text(comp), "$binding") {
      return true
    }
  }
  false
}

///|
fn component_section(
  components : Array[Json],
  groups : Array[Json],
  actions : Array[Json],
  tool_calls : Bool,
  bindings : Bool,
) -> String {
  let lines = [
    "## Component Signatures", "", "Arguments marked with ? are optional. Sub-components can be inline or referenced; prefer references for better streaming.",
  ]
  if uses_action(components) {
    let names = step_names(tool_calls, bindings)
    for action in actions {
      names.push(text_field(action, "name"))
    }
    let marked = []
    for name in names {
      marked.push("@" + name)
    }
    lines.push(
      "Props typed `ActionExpression` accept one @step, or Action([@steps...]) for several. See the Action section for available steps (" +
      join_sep(marked, ", ") +
      ").",
    )
    let mut restricted = false
    for comp in components {
      if restricted_slot(signature_text(comp)) {
        restricted = true
      }
    }
    if restricted {
      lines.push(
        "Props typed like `@OpenUrl | @ToAssistant` accept only the steps listed.",
      )
    }
  }
  if binding_hint(bindings, components) {
    lines.push(
      "Props marked `$binding<type>` accept a `$variable` reference for two-way binding.",
    )
  }
  if groups.length() > 0 {
    let seen = []
    for group in groups {
      lines.push("")
      lines.push("### " + text_field(group, "name"))
      for name in string_list(group, "components") {
        if seen.contains(name) {
          continue
        }
        match find_comp(components, name) {
          Some(comp) => {
            seen.push(name)
            match shown_signature(comp) {
              Some(text) => lines.push(text)
              None => lines.push("")
            }
          }
          None => ()
        }
      }
      for note in string_list(group, "notes") {
        lines.push(note)
      }
    }
    let rest = []
    for comp in components {
      let name = text_field(comp, "name")
      if !seen.contains(name) {
        rest.push(comp)
      }
    }
    if rest.length() > 0 {
      lines.push("")
      lines.push("### Other")
      for comp in rest {
        match shown_signature(comp) {
          Some(text) => lines.push(text)
          None => lines.push("")
        }
      }
    }
  } else {
    lines.push("")
    for comp in components {
      match shown_signature(comp) {
        Some(text) => lines.push(text)
        None => lines.push("")
      }
    }
  }
  join_parts(lines)
}

///|
fn find_comp(components : Array[Json], name : String) -> Json? {
  for comp in components {
    if text_field(comp, "name") == name {
      return Some(comp)
    }
  }
  None
}

///|
fn custom_lines(items : Array[Json], dash : Bool) -> Array[String] {
  let lines = []
  for item in items {
    let line = function_line(
      text_field(item, "signature"),
      description_of(item),
    )
    if dash {
      lines.push("- " + line)
    } else {
      lines.push(line)
    }
  }
  lines
}

///|
fn render_prompt(spec : Json) -> String {
  let root = text_field(spec, "root")
  let components = array_field(spec, "components")
  let tool_calls = flag(spec, "toolCalls")
  let bindings = flag(spec, "bindings")
  let expressions = tool_calls || bindings
  let preamble = match json_field(spec, "preamble") {
    Some(String(text)) => text
    _ =>
      "You are an AI assistant that responds using openui-lang, a declarative UI language. Your ENTIRE response must be valid openui-lang code — no markdown, no explanations, just openui-lang."
  }
  let parts = [preamble, "", syntax_rules(root, bindings, expressions)]
  parts.push("")
  parts.push(
    component_section(
      components,
      array_field(spec, "groups"),
      array_field(spec, "actions"),
      tool_calls,
      bindings,
    ),
  )
  let functions = custom_lines(array_field(spec, "functions"), false)
  if flag(spec, "builtin") {
    parts.push("")
    parts.push(builtin_functions_section(functions, tool_calls))
  } else if functions.length() > 0 {
    parts.push("")
    parts.push("## Built-in Functions\n\n" + join_parts(functions))
  }
  if tool_calls {
    parts.push("")
    parts.push(query_section())
    parts.push("")
    parts.push(mutation_section())
  }
  let actions = custom_lines(array_field(spec, "actions"), true)
  if uses_action(components) {
    parts.push("")
    parts.push(action_section(tool_calls, bindings, actions))
  } else if actions.length() > 0 {
    parts.push("")
    parts.push(
      "## Action — Button Behavior\n\nPass one step, or Action([...]) with several steps, as a button's action.\n\nAvailable steps:\n" +
      join_parts(actions),
    )
  }
  if tool_calls && bindings {
    parts.push("")
    parts.push(filters_section())
  }
  if tool_calls {
    parts.push("")
    parts.push(workflow_section())
  }
  let tools = array_field(spec, "tools")
  if tools.length() > 0 {
    parts.push("")
    parts.push(tools_section(tools))
  }
  parts.push("")
  parts.push(streaming_rules(root, expressions, tool_calls))
  let examples = string_list(spec, "examples")
  if examples.length() > 0 {
    parts.push("")
    parts.push("## Examples")
    parts.push("")
    for example in examples {
      parts.push(example)
      parts.push("")
    }
  }
  if flag(spec, "edit") {
    parts.push("")
    parts.push(edit_section())
  }
  if flag(spec, "inline") {
    parts.push("")
    parts.push(inline_section())
  }
  parts.push(important_rules(root, tool_calls, bindings))
  let rules = string_list(spec, "rules")
  if rules.length() > 0 {
    parts.push("")
    for rule in rules {
      parts.push("- " + rule)
    }
  }
  join_parts(parts)
}

///|
/// Render a `generatePrompt` spec that JavaScript has already ordered.
pub fn generate_prompt(spec_json : String) -> String {
  render_prompt(@json.parse(spec_json)) catch {
    _ => ""
  }
}

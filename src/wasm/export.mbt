///|
/// Parse a complete OpenUI Lang program and return JSON.
#export_name("parse_openui")
pub fn parse_openui(src : String) -> String {
  // Compact JSON. Pretty-printing dominated the parse that lang-core immediately parses back.
  @openui.parse(src).compact_json()
}

///|
/// Statement count only, so a benchmark can separate parsing from JSON encoding.
#export_name("parse_count")
pub fn parse_count(src : String) -> Int32 {
  @openui.parse(src).statements.length()
}

///|
/// Token count only, so a benchmark can separate lexing from parsing.
#export_name("token_count")
pub fn token_count(src : String) -> Int32 {
  @openui.tokenize(src).length()
}

///|
/// Tokenize OpenUI Lang source and return a JSON array.
#export_name("tokenize_openui")
pub fn tokenize_openui(src : String) -> String {
  @openui.tokens_json(src)
}

///|
/// Materialize without encoding, so a benchmark can separate the walk from JSON.
#export_name("materialize_count")
pub fn materialize_count(
  src : String,
  schema : String,
  root_name : String,
) -> Int32 {
  @openui.materialize_count(src, schema, root_name)
}

///|
/// Materialize source and return the official ParseResult JSON.
#export_name("parse_result")
pub fn parse_result(
  src : String,
  schema : String,
  root_name : String,
) -> String {
  @openui.materialize_result(src, schema, root_name)
}

///|
/// Materialize source against a library JSON Schema.
/// `root_name` is used only when the program has no `root` statement.
#export_name("materialize_openui")
pub fn materialize_openui(
  src : String,
  schema : String,
  root_name : String,
) -> String {
  @openui.materialize_json(src, schema, root_name)
}

///|
/// Open a streaming parser and return its id.
#export_name("stream_open")
pub fn stream_open(schema : String, root_name : String) -> Int32 {
  @openui.stream_open(schema, root_name)
}

///|
/// Append text and return the latest ParseResult JSON.
/// `complete` 1 checks the whole buffer in this same call.
#export_name("stream_append")
pub fn stream_append(id : Int32, chunk : String, complete : Int32) -> String {
  @openui.stream_append(id, chunk, complete)
}

///|
/// Append text and return the latest ParseResult JSON.
#export_name("stream_push")
pub fn stream_push(id : Int32, chunk : String) -> String {
  @openui.stream_push(id, chunk)
}

///|
/// Replace the buffer. `complete` 1 checks the whole buffer in this same call.
#export_name("stream_replace")
pub fn stream_replace(id : Int32, text : String, complete : Int32) -> String {
  @openui.stream_replace(id, text, complete)
}

///|
/// Read the current ParseResult. `complete` 1 previews the final check.
#export_name("stream_view")
pub fn stream_view(id : Int32, complete : Int32) -> String {
  @openui.stream_view(id, complete)
}

///|
/// Replace the buffer and return the latest materialize JSON.
#export_name("stream_set")
pub fn stream_set(id : Int32, text : String) -> String {
  @openui.stream_set(id, text)
}

///|
/// Finish the stream and return the final materialize JSON.
#export_name("stream_finish")
pub fn stream_finish(id : Int32) -> String {
  @openui.stream_finish(id)
}

///|
/// Drop the stream. Returns 1 if it existed.
#export_name("stream_close")
pub fn stream_close(id : Int32) -> Int32 {
  @openui.stream_close(id)
}

///|
/// Split an OpenUI `]]>openui:` message. `streaming` 1 holds a partial marker.
#export_name("parse_message")
pub fn parse_message(raw : String, streaming : Int32) -> String {
  @openui.parse_message(raw, streaming != 0)
}

///|
/// Write an OpenUI message. `has_context` 1 embeds `context`. `end` 1 writes the end marker.
#export_name("build_message")
pub fn build_message(
  content : String,
  context : String,
  has_context : Int32,
  pairs_json : String,
  end : Int32,
) -> String {
  @openui.build_message(
    content,
    context,
    has_context != 0,
    pairs_json,
    end != 0,
  )
}

///|
/// Parse string validation rules into JSON.
#export_name("parse_rules")
pub fn parse_rules(rules_json : String) -> String {
  @openui.parse_rules(rules_json)
}

///|
/// Keep structured rules tagged `true` or `arg`.
#export_name("parse_structured_rules")
pub fn parse_structured_rules(entries_json : String) -> String {
  @openui.parse_structured_rules(entries_json)
}

///|
/// Run one built-in validator. Empty means the value passed.
#export_name("builtin_check")
pub fn builtin_check(
  kind : String,
  value_json : String,
  arg_json : String,
) -> String {
  @openui.builtin_check(kind, value_json, arg_json)
}

///|
/// Hint strings for parser validation errors. Empty means no hint.
#export_name("enrich_hints")
pub fn enrich_hints(payload_json : String) -> String {
  @openui.enrich_hints(payload_json)
}

///|
/// Merge a patch onto an existing program. `has_root` 0 skips reachability.
#export_name("merge_statements")
pub fn merge_statements(
  existing : String,
  patch : String,
  root_id : String,
  use_root : Int32,
) -> String {
  @openui.merge_statements(existing, patch, root_id, has_root=use_root != 0)
}

///|
/// Serialize a tagged element tree to OpenUI Lang source.
#export_name("json_to_openui")
pub fn json_to_openui(
  schema_json : String,
  root_json : String,
  state_json : String,
) -> String {
  @openui.json_to_openui(schema_json, root_json, state_json)
}

///|
/// Start an expression walk. The host answers each request.
#export_name("eval_start")
pub fn eval_start(ast_json : String) -> String {
  @openui.eval_start(ast_json)
}

///|
/// Answer the innermost expression walk.
#export_name("eval_answer")
pub fn eval_answer(answer_json : String) -> String {
  @openui.eval_answer(answer_json)
}

///|
/// Drop the innermost expression walk after a host throw.
#export_name("eval_cancel")
pub fn eval_cancel() -> String {
  @openui.eval_cancel()
}

///|
/// Child edges visited after the current AST node.
#export_name("walk_plan")
pub fn walk_plan(kind : String) -> String {
  @openui.walk_plan(kind)
}

///|
/// `1` when `kind` is an AST discriminant.
#export_name("is_ast_kind")
pub fn is_ast_kind(kind : String) -> Int32 {
  @openui.is_ast_kind(kind)
}

///|
/// Encode a tagged JavaScript value as a literal AST.
#export_name("to_literal_ast")
pub fn to_literal_ast(value_json : String) -> String {
  @openui.to_literal_ast(value_json)
}

///|
/// Read a literal AST. `["no"]` means it is not a literal.
#export_name("literal_value")
pub fn literal_value(node_json : String) -> String {
  @openui.literal_value(node_json)
}

///|
/// Evaluate one eager built-in from tagged arguments.
#export_name("call_builtin")
pub fn call_builtin(name : String, args_json : String) -> String {
  @openui.call_builtin(name, args_json)
}

///|
/// Decide `Run`, `Set`, or `Reset` from argument kinds.
#export_name("lazy_step")
pub fn lazy_step(name : String, kinds_json : String) -> String {
  @openui.lazy_step(name, kinds_json)
}

///|
/// Build an `OpenUrl` or `ToAssistant` step. The host keeps `context`.
#export_name("eager_step")
pub fn eager_step(name : String, args_json : String) -> String {
  @openui.eager_step(name, args_json)
}

///|
/// Render the ordered `generatePrompt` spec.
#export_name("generate_prompt")
pub fn generate_prompt(spec_json : String) -> String {
  @openui.generate_prompt(spec_json)
}

///|
/// Decide a cloud config block. The host still serializes the JSON.
#export_name("cloud_config")
pub fn cloud_config(spec_json : String) -> String {
  @openui.cloud_config(spec_json)
}

///|
/// Replace `Ref` nodes with an encoded literal. The host builds that literal.
#export_name("substitute_ref")
pub fn substitute_ref(
  node_json : String,
  var_name_json : String,
  literal_json : String,
) -> String {
  @openui.substitute_ref(node_json, var_name_json, literal_json)
}

///|
/// `cloud`, `library`, or `legacy` for `generateSystemPrompt`.
#export_name("system_prompt_kind")
pub fn system_prompt_kind(spec_json : String) -> String {
  @openui.system_prompt_kind(spec_json)
}

///|
/// `1` when the tagged fields are an element node.
#export_name("is_element_node")
pub fn is_element_node(node_json : String) -> Int32 {
  @openui.is_element_node(node_json)
}

///|
/// `1` when `__reactive` is `"assign"` on a non-null object.
#export_name("is_reactive_assign")
pub fn is_reactive_assign(node_json : String) -> Int32 {
  @openui.is_reactive_assign(node_json)
}

///|
/// `1` for a runtime expression discriminant.
#export_name("is_runtime_expr")
pub fn is_runtime_expr(kind : String) -> Int32 {
  @openui.is_runtime_expr(kind)
}

///|
/// `1` when `steps` is an array on a non-null object.
#export_name("is_action_plan")
pub fn is_action_plan(node_json : String) -> Int32 {
  @openui.is_action_plan(node_json)
}

///|
/// Indices `flattenPlans` keeps. The host copies the original steps.
#export_name("flatten_plans")
pub fn flatten_plans(tags_json : String) -> String {
  @openui.flatten_plans(tags_json)
}

///|
/// MCP tool-result decision. The host returns `structuredContent` and parses text.
#export_name("extract_tool_result")
pub fn extract_tool_result(payload_json : String) -> String {
  @openui.extract_tool_result(payload_json)
}

///|
/// Stable JSON text. The host applies `toJSON` and reports cycles.
#export_name("stable_stringify")
pub fn stable_stringify(value_json : String) -> String {
  @openui.stable_stringify(value_json)
}

///|
/// Dot segments for `resolveField`. The host reads each property.
#export_name("resolve_field")
pub fn resolve_field(path_json : String) -> String {
  @openui.resolve_field(path_json)
}

///|
/// `toNumber` for a tagged value. The host keeps an existing number.
#export_name("to_number")
pub fn to_number(value_json : String) -> String {
  @openui.to_number(value_json)
}

///|
/// Next step for `evaluateRoot`. The host evaluates and keeps the element.
#export_name("evaluate_root")
pub fn evaluate_root(tag : String) -> String {
  @openui.evaluate_root(tag)
}

///|
/// `Each` gate. The host evaluates the list and the template.
#export_name("each_step")
pub fn each_step(payload_json : String) -> String {
  @openui.each_step(payload_json)
}

///|
/// Next step for one prop value. The host evaluates and recurses.
#export_name("prop_step")
pub fn prop_step(payload_json : String) -> String {
  @openui.prop_step(payload_json)
}

///|
/// Runtime error text for a prop that throws. The host keeps the live component.
#export_name("prop_error")
pub fn prop_error(payload_json : String) -> String {
  @openui.prop_error(payload_json)
}

///|
/// Whether `createStore().set` keeps the stored value.
#export_name("store_keep")
pub fn store_keep(payload_json : String) -> String {
  @openui.store_keep(payload_json)
}

///|
/// One `createStore().initialize` key.
#export_name("store_init")
pub fn store_init(payload_json : String) -> String {
  @openui.store_init(payload_json)
}

///|
/// Query snapshot choice. The host keeps the cache entry.
#export_name("query_slot")
pub fn query_slot(payload_json : String) -> String {
  @openui.query_slot(payload_json)
}

///|
/// Query or mutation error text. The host keeps live ids.
#export_name("query_error")
pub fn query_error(payload_json : String) -> String {
  @openui.query_error(payload_json)
}

///|
/// Whether `resolveStateField` returns the reactive binding.
#export_name("state_field")
pub fn state_field(payload_json : String) -> String {
  @openui.state_field(payload_json)
}

///|
/// Whether `stripReactiveAssign` reads the current state.
#export_name("strip_assign")
pub fn strip_assign(payload_json : String) -> String {
  @openui.strip_assign(payload_json)
}

///|
/// Drop a null optional argument, or report a required argument with no default.
#export_name("call_arg")
pub fn call_arg(payload_json : String) -> String {
  @openui.call_arg(payload_json)
}

///|
/// `Sort` and `Filter` branch. The host compares with `localeCompare` and `==`.
#export_name("list_step")
pub fn list_step(payload_json : String) -> String {
  @openui.list_step(payload_json)
}

///|
/// Whether an inline element keeps its current props.
#export_name("inline_step")
pub fn inline_step(payload_json : String) -> String {
  @openui.inline_step(payload_json)
}

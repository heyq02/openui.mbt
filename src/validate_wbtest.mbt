///|
test "openui validation rules follow the official checks" {
  inspect(
    parse_rules(
      "[\"required\",\"min:8\",\"min:8.5\",\"min:\",\"min: 8\",\"min:8abc\",\"min:0x10\",\"min:1e2\",\"min:Infinity\",\"min:-Infinity\",\"min:1e309\",\"pattern:a:b\",\"email:x\",\"min:0b10\",\"min:0o10\",\"max:1_000\"]",
    ),
    content=(
      #|[{"type":"required"},{"type":"min","arg":8},{"type":"min","arg":8.5},{"type":"min","arg":0},{"type":"min","arg":8},{"type":"min","arg":"8abc"},{"type":"min","arg":16},{"type":"min","arg":100},{"type":"min","inf":1},{"type":"min","inf":-1},{"type":"min","inf":1},{"type":"pattern","arg":"a:b"},{"type":"email","arg":"x"},{"type":"min","arg":2},{"type":"min","arg":8},{"type":"max","arg":"1_000"}]
    ),
  )
  inspect(parse_rules("\"required\""), content="[]")
  inspect(parse_rules("not-json"), content="[]")
  inspect(
    parse_structured_rules(
      "[[\"required\",\"true\"],[\"min\",\"arg\"],[\"skip\",\"skip\"],[\"nope\",\"skip\"],[\"pattern\",\"arg\"]]",
    ),
    content=(
      #|[{"type":"required"},{"type":"min","i":1},{"type":"pattern","i":4}]
    ),
  )
  inspect(parse_structured_rules("[1]"), content="[]")
  inspect(parse_structured_rules("null"), content="[]")
  let empty = "{\"t\":\"s\",\"v\":\"\"}"
  let text = "{\"t\":\"s\",\"v\":\"a@b.c\"}"
  let bad_mail = "{\"t\":\"s\",\"v\":\"a@b\"}"
  let spaced = "{\"t\":\"s\",\"v\":\"  12abc\"}"
  let blanks = "{\"t\":\"s\",\"v\":\"  \"}"
  let nan = "{\"t\":\"n\",\"v\":{\"k\":\"nan\"}}"
  let inf = "{\"t\":\"n\",\"v\":{\"k\":\"pinf\"}}"
  let three = "{\"t\":\"n\",\"v\":{\"k\":\"n\",\"v\":3}}"
  let emoji = "{\"t\":\"s\",\"v\":\"😀\"}"
  let flags = "{\"t\":\"o\",\"vals\":[{\"t\":\"b\",\"v\":false},{\"t\":\"b\",\"v\":false}]}"
  let flags_on = "{\"t\":\"o\",\"vals\":[{\"t\":\"b\",\"v\":false},{\"t\":\"b\",\"v\":true}]}"
  let box = "{\"t\":\"o\",\"vals\":[],\"inner\":{\"t\":\"s\",\"v\":\"\"}}"
  let list = "{\"t\":\"a\",\"v\":[{\"t\":\"s\",\"v\":\"12\"}],\"host\":{\"k\":\"n\",\"v\":12}}"
  let eight = "{\"k\":\"n\",\"v\":8}"
  let nan_arg = "{\"k\":\"nan\"}"
  let inf_arg = "{\"k\":\"pinf\"}"
  inspect(builtin_check("required", empty, nan_arg), content="required")
  inspect(builtin_check("required", text, nan_arg), content="")
  inspect(
    builtin_check("required", "{\"t\":\"b\",\"v\":false}", nan_arg),
    content="",
  )
  inspect(
    builtin_check("required", "{\"t\":\"a\",\"v\":[]}", nan_arg),
    content="required",
  )
  inspect(builtin_check("required", box, nan_arg), content="required")
  inspect(builtin_check("required", flags, nan_arg), content="options")
  inspect(builtin_check("required", flags_on, nan_arg), content="")
  inspect(builtin_check("email", empty, nan_arg), content="")
  inspect(builtin_check("email", bad_mail, nan_arg), content="email")
  inspect(builtin_check("email", text, nan_arg), content="")
  inspect(
    builtin_check("email", "{\"t\":\"s\",\"v\":\"a@..c\"}", nan_arg),
    content="",
  )
  inspect(
    builtin_check("email", "{\"t\":\"s\",\"v\":\"a@.c\"}", nan_arg),
    content="email",
  )
  inspect(builtin_check("email", three, nan_arg), content="email")
  inspect(builtin_check("numeric", spaced, nan_arg), content="")
  inspect(builtin_check("numeric", blanks, nan_arg), content="numeric")
  inspect(builtin_check("numeric", inf, nan_arg), content="")
  inspect(builtin_check("numeric", nan, nan_arg), content="numeric")
  inspect(builtin_check("numeric", empty, nan_arg), content="")
  inspect(builtin_check("min", spaced, eight), content="")
  inspect(builtin_check("min", three, eight), content="min")
  inspect(builtin_check("min", three, nan_arg), content="min")
  inspect(builtin_check("min", empty, eight), content="")
  inspect(builtin_check("min", three, inf_arg), content="min")
  inspect(builtin_check("min", inf, eight), content="")
  inspect(builtin_check("max", three, eight), content="")
  inspect(
    builtin_check("max", "{\"t\":\"n\",\"v\":{\"k\":\"n\",\"v\":9}}", eight),
    content="max",
  )
  inspect(
    builtin_check("minLength", emoji, "{\"k\":\"n\",\"v\":2}"),
    content="",
  )
  inspect(
    builtin_check("minLength", emoji, "{\"k\":\"n\",\"v\":3}"),
    content="minLength",
  )
  inspect(builtin_check("minLength", three, eight), content="")
  inspect(builtin_check("maxLength", text, "{\"k\":\"n\",\"v\":5}"), content="")
  inspect(
    builtin_check("maxLength", text, "{\"k\":\"n\",\"v\":4}"),
    content="maxLength",
  )
  inspect(builtin_check("min", list, "{\"k\":\"n\",\"v\":10}"), content="")
  inspect(builtin_check("nope", text, nan_arg), content="")
  inspect(builtin_check("required", "not-json", nan_arg), content="")
  inspect(
    enrich_hints(
      "{\"names\":[\"Card\",\"Text\"],\"items\":[{\"code\":\"unknown-component\",\"component\":\"Nope\"},{\"code\":\"missing-required\",\"component\":\"Card\",\"keys\":[\"title\",\"subtitle\"],\"required\":[\"title\"]},{\"code\":\"null-required\",\"component\":\"Ghost\"},{\"code\":\"inline-reserved\",\"component\":\"Button\"},{\"code\":\"other\",\"component\":\"X\"}]}",
    ),
    content=(
      #|["Available components: Card, Text","Signature: Card(title*, subtitle) — * marks required","","Declare as a top-level statement: myVar = Button(...)",""]
    ),
  )
  inspect(enrich_hints("[]"), content="[]")
  inspect(enrich_hints("not-json"), content="[]")
  inspect(
    enrich_hints(
      "{\"names\":[],\"items\":[{\"code\":\"unknown-component\",\"component\":\"Nope\"}]}",
    ),
    content="[\"\"]",
  )
  inspect(
    enrich_hints(
      "{\"names\":[1],\"items\":[{\"code\":\"missing-required\",\"component\":\"Box\",\"keys\":[],\"required\":[1]}]}",
    ),
    content="[\"Signature: Box() — * marks required\"]",
  )
  inspect(
    parse_rules(
      "[1,\"minLength:3\",\"maxLength:\",\"min:0x\",\"min:0xG\",\"min:0b2\",\"min:+Infinity\",\"min:-5\",\"min:.5\",\"min:1.\",\"min:1.e2\",\"min:1e\",\"min:   \",\"max:-1e309\",\"nope\"]",
    ),
    content=(
      #|[{"type":"minLength","arg":3},{"type":"maxLength","arg":0},{"type":"min","arg":"0x"},{"type":"min","arg":"0xG"},{"type":"min","arg":"0b2"},{"type":"min","inf":1},{"type":"min","arg":-5},{"type":"min","arg":0.5},{"type":"min","arg":1},{"type":"min","arg":100},{"type":"min","arg":"1e"},{"type":"min","arg":0},{"type":"max","inf":-1},{"type":"nope"}]
    ),
  )
  inspect(
    parse_structured_rules("[[\"a\"],[\"b\",1],[1,\"true\"]]"),
    content="[]",
  )
  let nbsp = "{\"t\":\"s\",\"v\":\"a\\u00a0@b.c\"}"
  let plus = "{\"t\":\"s\",\"v\":\"+\"}"
  let ninf = "{\"t\":\"n\",\"v\":{\"k\":\"ninf\"}}"
  let bare = "{\"t\":\"o\",\"vals\":[{\"t\":\"b\",\"v\":true}]}"
  let mixed = "{\"t\":\"o\",\"vals\":[{\"t\":\"b\",\"v\":false},{\"t\":\"n\",\"v\":{\"k\":\"n\",\"v\":0}}]}"
  inspect(builtin_check("email", nbsp, nan_arg), content="email")
  inspect(
    builtin_check("email", "{\"t\":\"s\",\"v\":\"a@b.\"}", nan_arg),
    content="email",
  )
  inspect(
    builtin_check("email", "{\"t\":\"s\",\"v\":\"@b.c\"}", nan_arg),
    content="email",
  )
  inspect(builtin_check("numeric", plus, nan_arg), content="numeric")
  inspect(
    builtin_check("numeric", "{\"t\":\"b\",\"v\":true}", nan_arg),
    content="numeric",
  )
  inspect(builtin_check("min", ninf, eight), content="min")
  inspect(builtin_check("max", ninf, eight), content="")
  inspect(builtin_check("min", three, "{\"k\":\"ninf\"}"), content="")
  inspect(builtin_check("max", inf, eight), content="max")
  inspect(builtin_check("min", bare, eight), content="")
  inspect(builtin_check("required", mixed, nan_arg), content="")
  inspect(
    builtin_check("required", "{\"t\":\"u\"}", nan_arg),
    content="required",
  )
  inspect(
    builtin_check("required", "{\"t\":\"null\"}", nan_arg),
    content="required",
  )
  inspect(
    builtin_check(
      "required", "{\"t\":\"a\",\"v\":[{\"t\":\"s\",\"v\":\"\"}]}", nan_arg,
    ),
    content="",
  )
  inspect(builtin_check("minLength", empty, eight), content="")
  inspect(builtin_check("maxLength", empty, eight), content="")
  inspect(builtin_check("min", three, "not-json"), content="min")
  inspect(builtin_check("numeric", "{\"t\":\"n\"}", nan_arg), content="numeric")
  inspect(
    builtin_check("min", "{\"t\":\"s\",\"v\":\"Infinity\"}", eight),
    content="",
  )
  inspect(
    builtin_check("min", "{\"t\":\"s\",\"v\":\"  -2\"}", eight),
    content="min",
  )
  inspect(
    builtin_check("max", "{\"t\":\"s\",\"v\":\"1e\"}", "{\"k\":\"n\",\"v\":1}"),
    content="",
  )
  inspect(
    parse_rules(
      "[\"min:\\t8\",\"min:\\u00a08\",\"min:\\u202f8\",\"min:\\u20038\",\"min:8 \",\"min:08\",\"min:1e-2\",\"min:0xff\",\"min:0xFF\",\"min:0e1\",\"min:Infinityx\",\"min:Inf\"]",
    ),
    content=(
      #|[{"type":"min","arg":8},{"type":"min","arg":8},{"type":"min","arg":8},{"type":"min","arg":8},{"type":"min","arg":8},{"type":"min","arg":8},{"type":"min","arg":0.01},{"type":"min","arg":255},{"type":"min","arg":255},{"type":"min","arg":0},{"type":"min","arg":"Infinityx"},{"type":"min","arg":"Inf"}]
    ),
  )
  let mut huge = "0x"
  for _index in 0..<400 {
    huge = huge + "f"
  }
  inspect(
    parse_rules("[\"min:" + huge + "\"]"),
    content="[{\"type\":\"min\",\"inf\":1}]",
  )
  inspect(parse_structured_rules("not-json"), content="[]")
  inspect(builtin_check("required", "{\"t\":\"a\"}", nan_arg), content="")
  inspect(
    builtin_check("required", "{\"t\":\"o\"}", nan_arg),
    content="required",
  )
  inspect(
    builtin_check(
      "required", "{\"t\":\"o\",\"vals\":1,\"inner\":{\"t\":\"n\",\"v\":{\"k\":\"n\",\"v\":1}}}",
      nan_arg,
    ),
    content="",
  )
  inspect(
    builtin_check("required", "{\"t\":\"o\",\"vals\":[{\"t\":\"b\"}]}", nan_arg),
    content="",
  )
  inspect(builtin_check("required", "{\"t\":1}", nan_arg), content="")
  inspect(
    builtin_check("required", "{\"t\":\"s\",\"v\":1}", nan_arg),
    content="required",
  )
  inspect(builtin_check("max", three, nan_arg), content="max")
  inspect(builtin_check("min", inf, nan_arg), content="min")
  inspect(builtin_check("min", ninf, "{\"k\":\"ninf\"}"), content="")
  inspect(builtin_check("min", three, "{\"k\":\"n\"}"), content="min")
  inspect(
    builtin_check("min", "{\"t\":\"s\",\"v\":\"   \"}", eight),
    content="",
  )
  inspect(enrich_hints("{\"items\":1}"), content="[]")
  inspect(enrich_hints("{\"items\":[{\"code\":\"other\"}]}"), content="[\"\"]")
}

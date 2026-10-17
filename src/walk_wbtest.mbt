///|
test "openui walk plan and literal ast match official shapes" {
  inspect(walk_plan("Comp"), content="[\"args\",\"props\"]")
  inspect(walk_plan("Arr"), content="[\"els\"]")
  inspect(walk_plan("Obj"), content="[\"entries\"]")
  inspect(walk_plan("BinOp"), content="[\"left\",\"right\"]")
  inspect(walk_plan("UnaryOp"), content="[\"operand\"]")
  inspect(walk_plan("Ternary"), content="[\"cond\",\"then\",\"else\"]")
  inspect(walk_plan("Member"), content="[\"obj\"]")
  inspect(walk_plan("Index"), content="[\"obj\",\"index\"]")
  inspect(walk_plan("Assign"), content="[\"value\"]")
  inspect(walk_plan("Str"), content="[]")
  inspect(walk_plan("Nope"), content="[]")
  inspect(is_ast_kind("Comp"), content="1")
  inspect(is_ast_kind("Ph"), content="1")
  inspect(is_ast_kind("RuntimeRef"), content="1")
  inspect(is_ast_kind(""), content="0")
  inspect(is_ast_kind("element"), content="0")
  let text =
    #|["s","hi"]
  inspect(to_literal_ast(text), content="[\"Str\",\"hi\"]")
  let number =
    #|["n",["n",2]]
  inspect(to_literal_ast(number), content="[\"Num\",[\"n\",2]]")
  let special =
    #|["n",["nan"]]
  inspect(to_literal_ast(special), content="[\"Num\",[\"nan\"]]")
  let flag =
    #|["b",false]
  inspect(to_literal_ast(flag), content="[\"Bool\",false]")
  let empty =
    #|["z"]
  inspect(to_literal_ast(empty), content="[\"Null\"]")
  let other =
    #|["x"]
  inspect(to_literal_ast(other), content="[\"Null\"]")
  let list =
    #|["a",[["s","a"],["z"]]]
  inspect(
    to_literal_ast(list),
    content="[\"Arr\",[[\"Str\",\"a\"],[\"Null\"]]]",
  )
  let hole =
    #|["a",[["h"],["s","a"]]]
  inspect(to_literal_ast(hole), content="[\"Arr\",[null,[\"Str\",\"a\"]]]")
  let record =
    #|["o",[["k",["n",["n",1]]]]]
  inspect(
    to_literal_ast(record),
    content="[\"Obj\",[[\"k\",[\"Num\",[\"n\",1]]]]]",
  )
  inspect(to_literal_ast("{"), content="[\"Null\"]")
  inspect(to_literal_ast("1"), content="[\"Null\"]")
  let missing =
    #|["s"]
  inspect(to_literal_ast(missing), content="[\"Str\",null]")
  let bad_number =
    #|["n","bad"]
  inspect(to_literal_ast(bad_number), content="[\"Num\",[\"n\",0]]")
  let bare =
    #|[1]
  inspect(to_literal_ast(bare), content="[\"Null\"]")
  let two =
    #|["o",[["a",["s","x"]],["b",["z"]]]]
  inspect(
    to_literal_ast(two),
    content="[\"Obj\",[[\"a\",[\"Str\",\"x\"]],[\"b\",[\"Null\"]]]]",
  )
  let odd =
    #|["o",[1]]
  inspect(to_literal_ast(odd), content="[\"Obj\",[[\"\",[\"Null\"]]]]")
  let kept =
    #|["Str",["s","a"]]
  inspect(literal_value(kept), content="[\"ok\",[\"s\",\"a\"]]")
  let nested =
    #|["Arr",[["Num",["n",["n",1]]],["Null"],["Bool",["b",true]]]]
  inspect(
    literal_value(nested),
    content="[\"ok\",[\"a\",[[\"n\",[\"n\",1]],[\"z\"],[\"b\",true]]]]",
  )
  let object =
    #|["Obj",[["k",["Str",["s","v"]]]]]
  inspect(
    literal_value(object),
    content="[\"ok\",[\"o\",[[\"k\",[\"s\",\"v\"]]]]]",
  )
  let reference =
    #|["Ref",["s","item"]]
  inspect(literal_value(reference), content="[\"no\"]")
  let mixed =
    #|["Arr",[["Str",["s","a"]],["Ref",["s","item"]]]]
  inspect(literal_value(mixed), content="[\"no\"]")
  inspect(literal_value("{"), content="[\"no\"]")
  let bad_array =
    #|["Arr","bad"]
  inspect(literal_value(bad_array), content="[\"no\"]")
  let bad_object =
    #|["Obj",["bad"]]
  inspect(literal_value(bad_object), content="[\"no\"]")
  let broken =
    #|["Num",1]
  inspect(literal_value(broken), content="[\"ok\",[\"x\"]]")
  let flag_only =
    #|["Bool",["b"]]
  inspect(literal_value(flag_only), content="[\"ok\",[\"b\"]]")
  let nested_ref =
    #|["Obj",[["k",["Ref"]]]]
  inspect(literal_value(nested_ref), content="[\"no\"]")
}

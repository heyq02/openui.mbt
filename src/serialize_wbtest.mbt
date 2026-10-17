///|
test "openui jsonToOpenUI prints reachable element source" {
  let schema =
    #|{"properties":{"Card":{},"Text":{},"Box":{}},"$defs":{"Card":{"properties":{"title":{},"body":{},"note":{}},"required":["title"]},"Text":{"properties":{"value":{}},"required":["value"]},"Box":{"properties":{"child":{}},"required":["child"]}},"functions":{"Percent":{"params":{"properties":{"n":{}}}}},"actions":{"Save":{"params":{"properties":{"id":{}}}}}}
  let card =
    #|["root","Card","Card","",[["title",["el","Box","box",[["child",["el","Text","label",[["value",["s","\"a\""]]]]]]]],["body",["el","Text","label",[["value",["s","\"b\""]]]]]]]
  inspect(
    json_to_openui(schema, card, "null"),
    content="root = Card(box, label)\nlabel = Text(\"a\")\nbox = Box(label)",
  )
  let text =
    #|["root","Text","Text","main",[["value",["s","\"a\\\"b\""]]]]
  inspect(
    json_to_openui(schema, text, "null"),
    content="main = Text(\"a\\\"b\")",
  )
  let foo =
    #|["root",null,"Foo","",[["a",["n","1"]],"bad",["b",["n","2"]]]]
  inspect(json_to_openui(schema, foo, "null"), content="root = Foo(1, 2)")
  let calls =
    #|["root","Card","Card","",[["title",["ast",["Comp","Count",[["Arr",[["Num","1"],["Num","2"]]]]]]],["body",["ast",["BinOp","*",["BinOp","+",["Ref","a"],["Ref","b"]],["Ref","c"]]]],["note",["ast",["BinOp","+",["Ref","a"],["BinOp","+",["Ref","b"],["Ref","c"]]]]]]]
  inspect(
    json_to_openui(schema, calls, "null"),
    content="root = Card(@Count([1, 2]), (a + b) * c, a + b + c)",
  )
  let action =
    #|["root","Card","Card","root",[["title",["ast",["Comp","Action",[["Comp","Percent",[]],["Comp","Save",[]],["Comp","Text",[]]]]]]]]
  inspect(
    json_to_openui(schema, action, "null"),
    content="root = Card(Action(@Percent(), @Save(), Text()))",
  )
  let ops =
    #|["root","Card","Card","",[["title",["ast",["BinOp","??",["BinOp","+",["Ref","a"],["Ref","b"]],["UnaryOp","!",["Bool","false"]]]]],["body",["ast",["Ternary",["Ref","a"],["Ref","b"],["Member",["BinOp","+",["Ref","a"],["Ref","b"]],"c"]]]],["note",["o",[["k",["n","1"]],"bad"]]]]]
  inspect(
    json_to_openui(schema, ops, "null"),
    content="root = Card(a + b ?? !false, a ? b : a + b.c, {k: 1})",
  )
  let list =
    #|["root","Text","Text","",[["value",["a",[["n","1"],["s","\"a\""],["x"]]]]]]
  inspect(
    json_to_openui(schema, list, "null"),
    content="root = Text([1, \"a\", null])",
  )
  let empty =
    #|["root","Card","Card","",[]]
  let state =
    #|[["$mode",["s","\"x\""]],["$skip",["skip"]],["$late",["el","Text","late",[["value",["s","\"z\""]]]]],"nope",["$n","plain"]]
  inspect(
    json_to_openui(schema, empty, state),
    content="root = Card(null)\n$mode = \"x\"\n$late = late\n$n = null",
  )
  let bare =
    #|["root","Card","Card","",[["title","raw"],["body",["nope"]]]]
  inspect(json_to_openui(schema, bare, ""), content="root = Card(null)")
  let other =
    #|["root","Card","Card","",[["title",["ast","nope"]],["body",["ast",["Other"]]],["note",["ast",["Obj",[["k",["Null"]],"bad",["m",["Ph","_"]]]]]]]]
  inspect(
    json_to_openui(schema, other, "null"),
    content="root = Card(null, null, {k: null, m: _})",
  )
  let refs =
    #|["root","Card","Card","",[["title",["ast",["Index",["StateRef","$s"],["Num","0"]]]],["body",["ast",["Assign","$s",["RuntimeRef","r"]]]],["note",["ast",["Arr",[]]]]]]
  inspect(
    json_to_openui(schema, refs, "null"),
    content="root = Card($s[0], $s = r, [])",
  )
  let missing =
    #|["root",null,"undefined","",[]]
  inspect(json_to_openui(schema, missing, "null"), content="root = undefined()")
  let inline =
    #|["root","Card","Card","",[["title",["el","Text","",[["value",["s","\"a\""]]]]],["body",["el","Missing","",[["z",["n","1"]]]]]]]
  inspect(
    json_to_openui(schema, inline, "null"),
    content="root = Card(Text(\"a\"), Missing(1))",
  )
  let short =
    #|["root"]
  inspect(json_to_openui(schema, short, "null"), content="root = ()")
  let numbered =
    #|["root",null,1,"",[]]
  inspect(json_to_openui(schema, numbered, "null"), content="root = ()")
  let object_props =
    #|["root","Card","Card","",{}]
  inspect(
    json_to_openui(schema, object_props, "null"),
    content="root = Card(null)",
  )
  let key =
    #|["root","Card","Card","",["bad",[1,["n","1"]],["title",["s","\"a\""]]]]
  inspect(json_to_openui(schema, key, "null"), content="root = Card(\"a\")")
  let nope =
    #|["root","Text","Text","",[["value",["ast",["Nope"]]]]]
  inspect(json_to_openui(schema, nope, "null"), content="root = Text(null)")
  let child =
    #|["root","Text","Text","",[["value",["ast",["BinOp","+","x",["Ref","c"]]]]]]
  inspect(
    json_to_openui(schema, child, "null"),
    content="root = Text(null + c)",
  )
  inspect(json_to_openui(schema, "{", "null"), content="")
  inspect(json_to_openui(schema, "1", "null"), content="")
  inspect(json_to_openui(schema, "[]", "{"), content="")
}

///|
fn subst_s(text : String) -> String {
  "{\"t\":\"s\",\"v\":" + json_string(text) + "}"
}

///|
fn subst_n(text : String) -> String {
  "{\"t\":\"n\",\"v\":" + text + "}"
}

///|
fn subst_pair(key : String, value : String) -> String {
  "[" + json_string(key) + "," + value + "]"
}

///|
fn subst_join(items : Array[String]) -> String {
  let buf = StringBuilder()
  let mut index = 0
  for item in items {
    if index > 0 {
      buf.write_char(',')
    }
    buf.write_string(item)
    index = index + 1
  }
  buf.to_string()
}

///|
fn subst_o(entries : Array[String]) -> String {
  "{\"t\":\"o\",\"v\":[" + subst_join(entries) + "]}"
}

///|
fn subst_a(items : Array[String]) -> String {
  "{\"t\":\"a\",\"v\":[" + subst_join(items) + "]}"
}

///|
fn subst_ref_named(name : String) -> String {
  subst_o([subst_pair("k", subst_s("Ref")), subst_pair("n", name)])
}

///|
fn subst_str_node(text : String) -> String {
  subst_o([subst_pair("k", subst_s("Str")), subst_pair("v", subst_s(text))])
}

///|
test "substituteRef replaces loop refs in the AST" {
  let item = subst_s("item")
  let hi = subst_str_node("hi")
  let ref_item = subst_ref_named(item)
  inspect(substitute_ref(ref_item, item, hi), content=hi)
  inspect(substitute_ref(ref_item, subst_s("other"), hi), content=ref_item)
  inspect(substitute_ref(ref_item, subst_n("1"), hi), content=ref_item)
  inspect(
    substitute_ref(subst_ref_named(subst_n("1")), subst_n("1"), hi),
    content=hi,
  )
  inspect(
    substitute_ref(subst_ref_named(subst_n("1")), subst_n("2"), hi),
    content=subst_ref_named(subst_n("1")),
  )
  inspect(
    substitute_ref(subst_ref_named("{\"t\":\"n0\"}"), subst_n("0"), hi),
    content=hi,
  )
  inspect(
    substitute_ref(subst_ref_named("{\"t\":\"n0\"}"), "{\"t\":\"n0\"}", hi),
    content=hi,
  )
  inspect(
    substitute_ref(subst_ref_named("{\"t\":\"n0\"}"), subst_n("1"), hi),
    content=subst_ref_named("{\"t\":\"n0\"}"),
  )
  inspect(
    substitute_ref(subst_ref_named("{\"t\":\"nan\"}"), "{\"t\":\"nan\"}", hi),
    content=subst_ref_named("{\"t\":\"nan\"}"),
  )
  inspect(
    substitute_ref(subst_ref_named("{\"t\":\"inf\"}"), "{\"t\":\"inf\"}", hi),
    content=hi,
  )
  inspect(
    substitute_ref(subst_ref_named("{\"t\":\"-inf\"}"), "{\"t\":\"inf\"}", hi),
    content=subst_ref_named("{\"t\":\"-inf\"}"),
  )
  inspect(
    substitute_ref(
      subst_ref_named("{\"t\":\"b\",\"v\":true}"),
      "{\"t\":\"b\",\"v\":true}",
      hi,
    ),
    content=hi,
  )
  inspect(
    substitute_ref(
      subst_ref_named("{\"t\":\"b\",\"v\":false}"),
      "{\"t\":\"b\",\"v\":true}",
      hi,
    ),
    content=subst_ref_named("{\"t\":\"b\",\"v\":false}"),
  )
  inspect(
    substitute_ref(subst_ref_named("{\"t\":\"z\"}"), "{\"t\":\"z\"}", hi),
    content=hi,
  )
  inspect(
    substitute_ref(
      subst_o([subst_pair("k", subst_s("Ref"))]),
      "{\"t\":\"u\"}",
      hi,
    ),
    content=hi,
  )
  inspect(
    substitute_ref(
      subst_ref_named("{\"t\":\"x\",\"i\":1}"),
      "{\"t\":\"x\",\"i\":1}",
      hi,
    ),
    content=hi,
  )
  inspect(
    substitute_ref(
      subst_ref_named("{\"t\":\"x\",\"i\":1}"),
      "{\"t\":\"x\",\"i\":2}",
      hi,
    ),
    content=subst_ref_named("{\"t\":\"x\",\"i\":1}"),
  )
  inspect(
    substitute_ref(subst_ref_named(subst_o([])), subst_o([]), hi),
    content=subst_ref_named(subst_o([])),
  )
  let folded = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", ref_item),
    subst_pair("field", subst_s("name")),
  ])
  let obj_hi = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair("entries", subst_a([subst_a([subst_s("name"), hi])])),
  ])
  inspect(substitute_ref(folded, item, obj_hi), content=hi)
  let nested = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", folded),
    subst_pair("field", subst_s("v")),
  ])
  let inner_obj = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair("entries", subst_a([subst_a([subst_s("v"), hi])])),
  ])
  let inner = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair("entries", subst_a([subst_a([subst_s("name"), inner_obj])])),
  ])
  inspect(substitute_ref(nested, item, inner), content=hi)
  let missed = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", ref_item),
    subst_pair("field", subst_s("missing")),
    subst_pair("loc", subst_n("3")),
  ])
  let missed_obj = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair(
      "entries",
      subst_a(["{\"t\":\"h\"}", subst_a([subst_s("name"), hi])]),
    ),
  ])
  let missed_expect = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", missed_obj),
    subst_pair("field", subst_s("missing")),
    subst_pair("loc", subst_n("3")),
  ])
  inspect(substitute_ref(missed, item, missed_obj), content=missed_expect)
  let plain = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", subst_n("1")),
    subst_pair("field", subst_s("a")),
  ])
  inspect(substitute_ref(plain, item, hi), content=plain)
  let no_obj = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("field", subst_s("a")),
  ])
  inspect(substitute_ref(no_obj, item, hi), content=no_obj)
  let hole_key = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", ref_item),
  ])
  let hole_obj = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair("entries", subst_a([subst_a(["{\"t\":\"h\"}", hi])])),
  ])
  inspect(substitute_ref(hole_key, item, hole_obj), content=hi)
  let bad_obj = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair("entries", subst_n("1")),
  ])
  let bad_member = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", ref_item),
    subst_pair("field", subst_s("a")),
  ])
  inspect(
    substitute_ref(bad_member, item, bad_obj),
    content="{\"t\":\"throw\",\"why\":\"find-fn\"}",
  )
  let num = subst_o([
    subst_pair("k", subst_s("Num")),
    subst_pair("v", subst_n("0")),
  ])
  let index = subst_o([
    subst_pair("k", subst_s("Index")),
    subst_pair("index", num),
    subst_pair("extra", subst_s("keep")),
  ])
  let index_expect = subst_o([
    subst_pair("k", subst_s("Index")),
    subst_pair("index", num),
    subst_pair("extra", subst_s("keep")),
    subst_pair("obj", "{\"t\":\"u\"}"),
  ])
  inspect(substitute_ref(index, item, hi), content=index_expect)
  let index_ref = subst_o([
    subst_pair("k", subst_s("Index")),
    subst_pair("obj", ref_item),
    subst_pair("index", ref_item),
  ])
  let index_both = subst_o([
    subst_pair("k", subst_s("Index")),
    subst_pair("obj", hi),
    subst_pair("index", hi),
  ])
  inspect(substitute_ref(index_ref, item, hi), content=index_both)
  let bin = subst_o([
    subst_pair("op", subst_s("+")),
    subst_pair("k", subst_s("BinOp")),
    subst_pair("left", ref_item),
    subst_pair("right", num),
  ])
  let bin_expect = subst_o([
    subst_pair("op", subst_s("+")),
    subst_pair("k", subst_s("BinOp")),
    subst_pair("left", hi),
    subst_pair("right", num),
  ])
  inspect(substitute_ref(bin, item, hi), content=bin_expect)
  inspect(
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("BinOp")),
        subst_pair("op", subst_s("+")),
      ]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"undef\"}",
  )
  inspect(
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("BinOp")),
        subst_pair("left", "{\"t\":\"z\"}"),
        subst_pair("right", num),
      ]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"null\"}",
  )
  let unary = subst_o([
    subst_pair("loc", subst_n("1")),
    subst_pair("k", subst_s("UnaryOp")),
    subst_pair("op", subst_s("!")),
    subst_pair("operand", ref_item),
  ])
  let unary_expect = subst_o([
    subst_pair("loc", subst_n("1")),
    subst_pair("k", subst_s("UnaryOp")),
    subst_pair("op", subst_s("!")),
    subst_pair("operand", hi),
  ])
  inspect(substitute_ref(unary, item, hi), content=unary_expect)
  let tern = subst_o([
    subst_pair("k", subst_s("Ternary")),
    subst_pair("cond", ref_item),
    subst_pair("then", num),
    subst_pair("else", ref_item),
  ])
  let tern_expect = subst_o([
    subst_pair("k", subst_s("Ternary")),
    subst_pair("cond", hi),
    subst_pair("then", num),
    subst_pair("else", hi),
  ])
  inspect(substitute_ref(tern, item, hi), content=tern_expect)
  let assign = subst_o([
    subst_pair("k", subst_s("Assign")),
    subst_pair("target", subst_s("title")),
    subst_pair("value", ref_item),
  ])
  let assign_expect = subst_o([
    subst_pair("k", subst_s("Assign")),
    subst_pair("target", subst_s("title")),
    subst_pair("value", hi),
  ])
  inspect(substitute_ref(assign, item, hi), content=assign_expect)
  let arr = subst_o([
    subst_pair("k", subst_s("Arr")),
    subst_pair(
      "els",
      subst_a([ref_item, "{\"t\":\"h\"}", subst_ref_named(subst_s("other"))]),
    ),
  ])
  let arr_expect = subst_o([
    subst_pair("k", subst_s("Arr")),
    subst_pair(
      "els",
      subst_a([hi, "{\"t\":\"h\"}", subst_ref_named(subst_s("other"))]),
    ),
  ])
  inspect(substitute_ref(arr, item, hi), content=arr_expect)
  inspect(
    substitute_ref(subst_o([subst_pair("k", subst_s("Arr"))]), item, hi),
    content="{\"t\":\"throw\",\"why\":\"map\"}",
  )
  inspect(
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("Arr")),
        subst_pair("els", "{\"t\":\"z\"}"),
      ]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"map-null\"}",
  )
  inspect(
    substitute_ref(
      subst_o([subst_pair("k", subst_s("Arr")), subst_pair("els", subst_n("1"))]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"map-fn\"}",
  )
  inspect(
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("Arr")),
        subst_pair("els", subst_a(["{\"t\":\"z\"}"])),
      ]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"null\"}",
  )
  let entries = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair(
      "entries",
      subst_a([
        subst_a([subst_s("name"), ref_item, subst_s("extra")]),
        "{\"t\":\"h\"}",
      ]),
    ),
  ])
  let entries_expect = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair(
      "entries",
      subst_a([subst_a([subst_s("name"), hi]), "{\"t\":\"h\"}"]),
    ),
  ])
  inspect(substitute_ref(entries, item, hi), content=entries_expect)
  inspect(
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", subst_a([subst_n("1")])),
      ]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"number 1\"}",
  )
  let text_entries = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair("entries", subst_a([subst_s("ab"), subst_s("xy")])),
  ])
  let text_expect = subst_o([
    subst_pair("k", subst_s("Obj")),
    subst_pair(
      "entries",
      subst_a([
        subst_a([subst_s("a"), subst_s("b")]),
        subst_a([subst_s("x"), subst_s("y")]),
      ]),
    ),
  ])
  inspect(substitute_ref(text_entries, item, hi), content=text_expect)
  let text_member = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair(
      "obj",
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", subst_a([subst_s("ab")])),
      ]),
    ),
    subst_pair("field", subst_s("a")),
  ])
  inspect(substitute_ref(text_member, item, hi), content=subst_s("b"))
  inspect(
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", subst_a([subst_a([subst_s("name")])])),
      ]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"undef\"}",
  )
  let comp = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("name", subst_s("Card")),
    subst_pair("args", subst_a([ref_item])),
    subst_pair("mappedProps", subst_o([subst_pair("label", ref_item)])),
  ])
  let comp_expect = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("name", subst_s("Card")),
    subst_pair("args", subst_a([hi])),
    subst_pair("mappedProps", subst_o([subst_pair("label", hi)])),
  ])
  inspect(substitute_ref(comp, item, hi), content=comp_expect)
  let comp_null = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("name", subst_s("Card")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", "{\"t\":\"z\"}"),
  ])
  inspect(substitute_ref(comp_null, item, hi), content=comp_null)
  let comp_only = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("name", subst_s("Card")),
    subst_pair("args", subst_a([])),
  ])
  inspect(substitute_ref(comp_only, item, hi), content=comp_only)
  let comp_blank = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("name", subst_s("Card")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", subst_o([])),
  ])
  inspect(substitute_ref(comp_blank, item, hi), content=comp_blank)
  let comp_text = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", subst_s("ab")),
  ])
  let comp_text_expect = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair(
      "mappedProps",
      subst_o([subst_pair("0", subst_s("a")), subst_pair("1", subst_s("b"))]),
    ),
  ])
  inspect(substitute_ref(comp_text, item, hi), content=comp_text_expect)
  let comp_arr = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair(
      "mappedProps",
      subst_a([ref_item, "{\"t\":\"h\"}", subst_n("2")]),
    ),
  ])
  let comp_arr_expect = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair(
      "mappedProps",
      subst_o([subst_pair("0", hi), subst_pair("2", subst_n("2"))]),
    ),
  ])
  inspect(substitute_ref(comp_arr, item, hi), content=comp_arr_expect)
  let comp_zero = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", subst_n("0")),
  ])
  inspect(substitute_ref(comp_zero, item, hi), content=comp_zero)
  let comp_one = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", subst_n("1")),
  ])
  let comp_one_expect = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", subst_o([])),
  ])
  inspect(substitute_ref(comp_one, item, hi), content=comp_one_expect)
  let comp_false = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", "{\"t\":\"b\",\"v\":false}"),
  ])
  inspect(substitute_ref(comp_false, item, hi), content=comp_false)
  let comp_true = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", "{\"t\":\"b\",\"v\":true}"),
  ])
  let comp_true_expect = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", subst_o([])),
  ])
  inspect(substitute_ref(comp_true, item, hi), content=comp_true_expect)
  inspect(
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("Comp")),
        subst_pair("args", subst_a([])),
        subst_pair(
          "mappedProps",
          subst_o([subst_pair("label", "{\"t\":\"z\"}")]),
        ),
      ]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"null\"}",
  )
  let state = subst_o([
    subst_pair("k", subst_s("StateRef")),
    subst_pair("n", item),
    subst_pair("loc", subst_n("4")),
  ])
  inspect(substitute_ref(state, item, hi), content=state)
  let ph = subst_o([subst_pair("k", subst_s("Ph"))])
  inspect(substitute_ref(ph, item, hi), content=ph)
  inspect(substitute_ref(subst_s("plain"), item, hi), content=subst_s("plain"))
  inspect(substitute_ref(subst_o([]), item, hi), content=subst_o([]))
  inspect(substitute_ref("{", item, hi), content="{\"t\":\"z\"}")
  inspect(
    substitute_ref("{\"t\":\"z\"}", item, hi),
    content="{\"t\":\"throw\",\"why\":\"null\"}",
  )
  inspect(
    substitute_ref("{\"t\":\"u\"}", item, hi),
    content="{\"t\":\"throw\",\"why\":\"undef\"}",
  )
  let throwing = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair(
      "obj",
      subst_o([
        subst_pair("k", subst_s("BinOp")),
        subst_pair("op", subst_s("+")),
      ]),
    ),
    subst_pair("field", subst_s("a")),
  ])
  inspect(
    substitute_ref(throwing, item, hi),
    content="{\"t\":\"throw\",\"why\":\"undef\"}",
  )
  inspect(
    substitute_ref(subst_ref_named(subst_n("0")), "{\"t\":\"n0\"}", hi),
    content=hi,
  )
  inspect(
    substitute_ref(subst_ref_named("{\"t\":\"n\"}"), "{\"t\":\"n0\"}", hi),
    content=hi,
  )
  inspect(
    substitute_ref(subst_ref_named("{\"t\":\"x\"}"), "{\"t\":\"x\"}", hi),
    content=hi,
  )
  let odd = subst_o([
    "[1," + subst_s("x") + "]",
    "1",
    subst_pair("k", subst_s("Str")),
    subst_pair("v", "{\"t\":\"b\",\"v\":true}"),
    "[\"k\"]",
  ])
  inspect(
    substitute_ref(odd, item, hi),
    content="{\"t\":\"o\",\"v\":[[null,{\"t\":\"s\",\"v\":\"x\"}],null,[\"k\",{\"t\":\"s\",\"v\":\"Str\"}],[\"v\",{\"t\":\"b\",\"v\":true}],[\"k\"]]}",
  )
  inspect(
    substitute_ref(subst_o([subst_pair("k", subst_n("1"))]), item, hi),
    content="{\"t\":\"o\",\"v\":[[\"k\",{\"t\":\"n\",\"v\":1}]]}",
  )
  inspect(
    substitute_ref(subst_o([subst_pair("k", subst_s("Nope"))]), item, hi),
    content="{\"t\":\"o\",\"v\":[[\"k\",{\"t\":\"s\",\"v\":\"Nope\"}]]}",
  )
  let kept = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", ref_item),
    subst_pair("field", subst_s("name")),
  ])
  let kept_expect = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", hi),
    subst_pair("field", subst_s("name")),
  ])
  inspect(substitute_ref(kept, item, hi), content=kept_expect)
  let index_throw = subst_o([
    subst_pair("k", subst_s("Index")),
    subst_pair("obj", subst_o([subst_pair("k", subst_s("BinOp"))])),
    subst_pair("index", num),
  ])
  inspect(
    substitute_ref(index_throw, item, hi),
    content="{\"t\":\"throw\",\"why\":\"undef\"}",
  )
  inspect(
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("Arr")),
        subst_pair("els", "{\"t\":\"u\"}"),
      ]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"map\"}",
  )
  inspect(
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", subst_a([subst_s("a")])),
      ]),
      item,
      hi,
    ),
    content="{\"t\":\"throw\",\"why\":\"undef\"}",
  )
  let broken = subst_o([
    "[1," + subst_s("z") + "]",
    "1",
    "[\"only\"]",
    subst_pair("k", subst_s("BinOp")),
    subst_pair("left", num),
    subst_pair("right", num),
  ])
  let broken_expect = subst_o([
    "[null," + subst_s("z") + "]",
    "null",
    "[\"only\"]",
    subst_pair("k", subst_s("BinOp")),
    subst_pair("left", num),
    subst_pair("right", num),
  ])
  inspect(substitute_ref(broken, item, hi), content=broken_expect)
  let iter_of = (entry : String) => {
    substitute_ref(
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", subst_a([entry])),
      ]),
      item,
      hi,
    )
  }
  inspect(
    iter_of("{\"t\":\"nan\"}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"number NaN\"}",
  )
  inspect(
    iter_of("{\"t\":\"inf\"}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"number Infinity\"}",
  )
  inspect(
    iter_of("{\"t\":\"-inf\"}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"number -Infinity\"}",
  )
  inspect(
    iter_of("{\"t\":\"n0\"}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"number 0\"}",
  )
  inspect(
    iter_of("{\"t\":\"b\",\"v\":true}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"boolean true\"}",
  )
  inspect(
    iter_of("{\"t\":\"b\",\"v\":false}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"boolean false\"}",
  )
  inspect(
    iter_of("{\"t\":\"u\"}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"undefined\"}",
  )
  inspect(
    iter_of("{\"t\":\"z\"}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"object null\"}",
  )
  inspect(
    iter_of("{\"t\":\"x\",\"j\":\"symbol\"}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"symbol\"}",
  )
  inspect(
    iter_of("{\"t\":\"x\"}"),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"object\"}",
  )
  inspect(
    iter_of(subst_o([subst_pair("a", subst_s("b"))])),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"object\"}",
  )
  let props_bad = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair(
      "mappedProps",
      subst_o(["[1," + subst_s("a") + "]", "[\"only\"]", "1"]),
    ),
  ])
  inspect(
    substitute_ref(props_bad, item, hi),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"object\"}",
  )
  let props_short = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", subst_o(["[\"only\"]"])),
  ])
  inspect(
    substitute_ref(props_short, item, hi),
    content="{\"t\":\"throw\",\"why\":\"undef\"}",
  )
  let props_atom = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", subst_o(["1"])),
  ])
  inspect(
    substitute_ref(props_atom, item, hi),
    content="{\"t\":\"throw\",\"why\":\"iter\",\"j\":\"object\"}",
  )
  let props_null = subst_o([
    subst_pair("k", subst_s("Comp")),
    subst_pair("args", subst_a([])),
    subst_pair("mappedProps", subst_a(["{\"t\":\"z\"}"])),
  ])
  inspect(
    substitute_ref(props_null, item, hi),
    content="{\"t\":\"throw\",\"why\":\"null\"}",
  )
  inspect(
    substitute_ref(subst_o([subst_pair("k", subst_s("Comp"))]), item, hi),
    content="{\"t\":\"throw\",\"why\":\"map\"}",
  )
  let find_member = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", ref_item),
    subst_pair("field", subst_s("a")),
  ])
  let find_open = subst_o([
    subst_pair("k", subst_s("Member")),
    subst_pair("obj", ref_item),
  ])
  inspect(
    substitute_ref(
      find_member,
      item,
      subst_o([subst_pair("k", subst_s("Obj"))]),
    ),
    content="{\"t\":\"throw\",\"why\":\"find\"}",
  )
  inspect(
    substitute_ref(
      find_member,
      item,
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", "{\"t\":\"u\"}"),
      ]),
    ),
    content="{\"t\":\"throw\",\"why\":\"find\"}",
  )
  inspect(
    substitute_ref(
      find_member,
      item,
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", "{\"t\":\"z\"}"),
      ]),
    ),
    content="{\"t\":\"throw\",\"why\":\"find-null\"}",
  )
  inspect(
    substitute_ref(
      find_member,
      item,
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", subst_a([subst_s("ab")])),
      ]),
    ),
    content=subst_s("b"),
  )
  inspect(
    substitute_ref(
      find_open,
      item,
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", subst_a([subst_s("")])),
      ]),
    ),
    content="{\"t\":\"u\"}",
  )
  inspect(
    substitute_ref(
      find_member,
      item,
      subst_o([
        subst_pair("k", subst_s("Obj")),
        subst_pair("entries", subst_a([subst_s("a")])),
      ]),
    ),
    content="{\"t\":\"u\"}",
  )
}

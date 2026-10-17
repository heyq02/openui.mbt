///|
test "openui eager builtins and lazy steps" {
  inspect(
    call_builtin(
      "Count", "{\"array\":{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":1},{\"t\":\"hole\"}]}}",
    ),
    content="{\"t\":\"n\",\"v\":2}",
  )
  inspect(
    call_builtin("Count", "{\"array\":{\"t\":\"s\",\"v\":\"no\"}}"),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(
    call_builtin("First", "{\"array\":{\"t\":\"a\",\"v\":[]}}"),
    content="{\"t\":\"null\"}",
  )
  inspect(
    call_builtin(
      "First", "{\"array\":{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":4}]}}",
    ),
    content="{\"t\":\"index\",\"i\":0}",
  )
  inspect(
    call_builtin("Last", "{\"array\":{\"t\":\"o\"}}"),
    content="{\"t\":\"null\"}",
  )
  inspect(
    call_builtin(
      "Last", "{\"array\":{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":1},{\"t\":\"n\",\"v\":2}]}}",
    ),
    content="{\"t\":\"index\",\"i\":1}",
  )
  inspect(
    call_builtin(
      "Sum", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":1},{\"t\":\"s\",\"v\":\"2\"},{\"t\":\"b\",\"v\":true},{\"t\":\"hole\"},{\"t\":\"n\"}]}}",
    ),
    content="{\"t\":\"n\",\"v\":4}",
  )
  inspect(
    call_builtin("Sum", "{\"numbers\":{\"t\":\"null\"}}"),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(
    call_builtin(
      "Avg", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":1},{\"t\":\"hole\"},{\"t\":\"n\",\"v\":3}]}}",
    ),
    content="{\"t\":\"n\",\"v\":1.3333333333333333}",
  )
  inspect(
    call_builtin("Avg", "{\"numbers\":{\"t\":\"a\",\"v\":[]}}"),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(
    call_builtin(
      "Min", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"s\",\"v\":\"3\"},{\"t\":\"n\",\"v\":1}]}}",
    ),
    content="{\"t\":\"n\",\"v\":1}",
  )
  inspect(
    call_builtin(
      "Max", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"nan\"},{\"t\":\"n\",\"v\":1}]}}",
    ),
    content="{\"t\":\"nan\"}",
  )
  inspect(
    call_builtin("Min", "{\"numbers\":{\"t\":\"a\",\"v\":[]}}"),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(
    call_builtin("Abs", "{\"number\":{\"t\":\"n\",\"v\":-2}}"),
    content="{\"t\":\"n\",\"v\":2}",
  )
  inspect(
    call_builtin("Abs", "{\"number\":{\"t\":\"n0\"}}"),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(
    call_builtin("Floor", "{\"number\":{\"t\":\"n\",\"v\":-1.2}}"),
    content="{\"t\":\"n\",\"v\":-2}",
  )
  inspect(
    call_builtin("Ceil", "{\"number\":{\"t\":\"n\",\"v\":-1.2}}"),
    content="{\"t\":\"n\",\"v\":-1}",
  )
  inspect(
    call_builtin("Floor", "{\"number\":{\"t\":\"pinf\"}}"),
    content="{\"t\":\"pinf\"}",
  )
  inspect(
    call_builtin(
      "Round", "{\"number\":{\"t\":\"n\",\"v\":1.25},\"decimals\":{\"t\":\"n\",\"v\":1}}",
    ),
    content="{\"t\":\"n\",\"v\":1.3}",
  )
  inspect(
    call_builtin("Round", "{\"number\":{\"t\":\"n\",\"v\":-1.5}}"),
    content="{\"t\":\"n\",\"v\":-1}",
  )
  inspect(call_builtin("Sort", "{}"), content="{\"t\":\"js\"}")
  inspect(call_builtin("{", "{}"), content="{\"t\":\"js\"}")
  inspect(lazy_step("Run", "[\"RuntimeRef\"]"), content="{\"op\":\"run\"}")
  inspect(lazy_step("Run", "[\"Str\"]"), content="{\"op\":\"none\"}")
  inspect(
    lazy_step("Set", "[\"StateRef\",\"Num\"]"),
    content="{\"op\":\"set\"}",
  )
  inspect(lazy_step("Set", "[\"Num\"]"), content="{\"op\":\"none\"}")
  inspect(
    lazy_step("Reset", "[\"Num\",\"StateRef\",\"StateRef\"]"),
    content="{\"op\":\"reset\",\"at\":[1,2]}",
  )
  inspect(lazy_step("Reset", "[\"Num\"]"), content="{\"op\":\"none\"}")
  inspect(lazy_step("OpenUrl", "[\"Str\"]"), content="{\"op\":\"none\"}")
  inspect(lazy_step("Reset", "{"), content="{\"op\":\"none\"}")
  inspect(
    call_builtin(
      "Max", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"n0\"},{\"t\":\"n\",\"v\":0}]}}",
    ),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(
    call_builtin(
      "Min", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"n0\"},{\"t\":\"n\",\"v\":0}]}}",
    ),
    content="{\"t\":\"n0\"}",
  )
  inspect(
    call_builtin(
      "Sum", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"nan\"},{\"t\":\"pinf\"},{\"t\":\"ninf\"},{\"t\":\"n0\"},{\"t\":\"s\",\"v\":\"Infinity\"},{\"t\":\"s\",\"v\":\"-Infinity\"},{\"t\":\"s\",\"v\":\"nope\"},{\"t\":\"b\",\"v\":false},{\"t\":\"null\"}]}}",
    ),
    content="{\"t\":\"nan\"}",
  )
  inspect(
    call_builtin("Avg", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"pinf\"}]}}"),
    content="{\"t\":\"pinf\"}",
  )
  inspect(
    call_builtin("Avg", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"ninf\"}]}}"),
    content="{\"t\":\"ninf\"}",
  )
  inspect(
    call_builtin("Avg", "{\"numbers\":{\"t\":\"a\",\"v\":[{\"t\":\"nan\"}]}}"),
    content="{\"t\":\"nan\"}",
  )
  inspect(
    call_builtin("Abs", "{\"number\":{\"t\":\"nan\"}}"),
    content="{\"t\":\"nan\"}",
  )
  inspect(
    call_builtin("Abs", "{\"number\":{\"t\":\"ninf\"}}"),
    content="{\"t\":\"pinf\"}",
  )
  inspect(call_builtin("Abs", "{}"), content="{\"t\":\"n\",\"v\":0}")
  inspect(
    call_builtin("Floor", "{\"number\":{\"t\":\"n0\"}}"),
    content="{\"t\":\"n0\"}",
  )
  inspect(
    call_builtin("Ceil", "{\"number\":{\"t\":\"ninf\"}}"),
    content="{\"t\":\"ninf\"}",
  )
  inspect(call_builtin("Ceil", "{}"), content="{\"t\":\"n\",\"v\":0}")
  inspect(call_builtin("Round", "{}"), content="{\"t\":\"n\",\"v\":0}")
  inspect(
    call_builtin(
      "Round", "{\"number\":{\"t\":\"n0\"},\"decimals\":{\"t\":\"null\"}}",
    ),
    content="{\"t\":\"n0\"}",
  )
  inspect(
    call_builtin(
      "Round", "{\"number\":{\"t\":\"n\",\"v\":1.25},\"decimals\":{\"t\":\"n\",\"v\":0.5}}",
    ),
    content="{\"t\":\"n\",\"v\":1.2649110640673518}",
  )
  inspect(
    call_builtin(
      "Round", "{\"number\":{\"t\":\"n\",\"v\":1},\"decimals\":{\"t\":\"n\",\"v\":13}}",
    ),
    content="{\"t\":\"n\",\"v\":1}",
  )
  inspect(
    call_builtin(
      "Round", "{\"number\":{\"t\":\"n\",\"v\":1},\"decimals\":{\"t\":\"n\",\"v\":-2}}",
    ),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(call_builtin("Count", "[]"), content="{\"t\":\"n\",\"v\":0}")
  inspect(call_builtin("Filter", "{}"), content="{\"t\":\"js\"}")
  inspect(lazy_step("Reset", "[]"), content="{\"op\":\"none\"}")
  inspect(lazy_step("Set", "[]"), content="{\"op\":\"none\"}")
  inspect(lazy_step("Other", "[]"), content="{\"op\":\"none\"}")
  inspect(
    lazy_step("Reset", "[1,\"StateRef\"]"),
    content="{\"op\":\"reset\",\"at\":[1]}",
  )
  inspect(num_json(add_num(PInf, NInf)), content="{\"t\":\"nan\"}")
  inspect(num_json(add_num(PInf, NFin(1.0))), content="{\"t\":\"pinf\"}")
  inspect(num_json(add_num(NInf, NFin(1.0))), content="{\"t\":\"ninf\"}")
  inspect(num_json(add_num(Neg0, Neg0)), content="{\"t\":\"n0\"}")
  inspect(num_json(add_num(Neg0, NFin(2.0))), content="{\"t\":\"n\",\"v\":2}")
  inspect(num_json(add_num(NFin(2.0), Neg0)), content="{\"t\":\"n\",\"v\":2}")
  inspect(num_json(div_num(NNan, 1.0)), content="{\"t\":\"nan\"}")
  inspect(num_json(div_num(PInf, -1.0)), content="{\"t\":\"ninf\"}")
  inspect(num_json(div_num(PInf, 0.0)), content="{\"t\":\"nan\"}")
  inspect(num_json(div_num(PInf, 2.0)), content="{\"t\":\"pinf\"}")
  inspect(num_json(div_num(NInf, -1.0)), content="{\"t\":\"pinf\"}")
  inspect(num_json(div_num(NInf, 0.0)), content="{\"t\":\"nan\"}")
  inspect(num_json(div_num(NInf, 2.0)), content="{\"t\":\"ninf\"}")
  inspect(num_json(div_num(Neg0, -1.0)), content="{\"t\":\"n0\"}")
  inspect(num_json(div_num(Neg0, 1.0)), content="{\"t\":\"n\",\"v\":0}")
  inspect(num_json(div_num(NFin(0.0), 0.0)), content="{\"t\":\"nan\"}")
  inspect(num_json(div_num(NFin(-1.0), 0.0)), content="{\"t\":\"ninf\"}")
  inspect(num_json(div_num(NFin(1.0), 0.0)), content="{\"t\":\"pinf\"}")
  inspect(num_json(div_num(NFin(4.0), 2.0)), content="{\"t\":\"n\",\"v\":2}")
  inspect(num_json(min_num(NNan, NFin(1.0))), content="{\"t\":\"nan\"}")
  inspect(num_json(min_num(NInf, NFin(1.0))), content="{\"t\":\"ninf\"}")
  inspect(num_json(min_num(PInf, NFin(1.0))), content="{\"t\":\"n\",\"v\":1}")
  inspect(num_json(min_num(Neg0, NFin(-1.0))), content="{\"t\":\"n\",\"v\":-1}")
  inspect(num_json(min_num(Neg0, Neg0)), content="{\"t\":\"n0\"}")
  inspect(
    num_json(min_num(NFin(2.0), NFin(3.0))),
    content="{\"t\":\"n\",\"v\":2}",
  )
  inspect(num_json(max_num(NNan, NFin(1.0))), content="{\"t\":\"nan\"}")
  inspect(num_json(max_num(PInf, NFin(1.0))), content="{\"t\":\"pinf\"}")
  inspect(num_json(max_num(NInf, NFin(1.0))), content="{\"t\":\"n\",\"v\":1}")
  inspect(num_json(max_num(Neg0, NFin(-1.0))), content="{\"t\":\"n0\"}")
  inspect(num_json(max_num(Neg0, Neg0)), content="{\"t\":\"n0\"}")
  inspect(
    num_json(max_num(NFin(2.0), NFin(3.0))),
    content="{\"t\":\"n\",\"v\":3}",
  )
  inspect(num_json(floor_num(NFin(1.2))), content="{\"t\":\"n\",\"v\":1}")
  inspect(num_json(floor_num(PInf)), content="{\"t\":\"pinf\"}")
  inspect(num_json(ceil_num(NFin(1.2))), content="{\"t\":\"n\",\"v\":2}")
  inspect(num_json(ceil_num(NNan)), content="{\"t\":\"nan\"}")
  inspect(num_json(abs_num(PInf)), content="{\"t\":\"pinf\"}")
  inspect(num_json(abs_num(NFin(-3.0))), content="{\"t\":\"n\",\"v\":3}")
  inspect(num_json(abs_num(NFin(3.0))), content="{\"t\":\"n\",\"v\":3}")
  inspect(num_json(round_num(NFin(1.5))), content="{\"t\":\"n\",\"v\":2}")
  inspect(num_json(round_num(NNan)), content="{\"t\":\"nan\"}")
  inspect(pow10(0.0), content="1")
  inspect(pow10(2.0), content="100")
  inspect(pow10(-1.0), content="0.1")
  inspect(pow10(0.5).is_nan(), content="false")
  inspect(pow10(13.0), content="10000000000000")
  inspect(pow10(-13.0), content="1e-13")
  inspect(num_json(classify(0.0 / 0.0)), content="{\"t\":\"nan\"}")
  inspect(num_json(classify(1.0 / 0.0)), content="{\"t\":\"pinf\"}")
  inspect(num_json(classify(-1.0 / 0.0)), content="{\"t\":\"ninf\"}")
  inspect(num_json(classify(-0.0)), content="{\"t\":\"n0\"}")
  inspect(num_json(NFin(1.0 / 0.0)), content="{\"t\":\"pinf\"}")
  let plain = @json.parse("true")
  inspect(builtin_tag(plain), content="")
  inspect(builtin_string(plain), content="")
  inspect(builtin_items(plain).length(), content="0")
}

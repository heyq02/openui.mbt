///|
test "prop steps and runtime errors match the official evaluator" {
  inspect(
    prop_step("{\"phase\":\"kind\",\"k\":\"StateRef\"}"),
    content="{\"op\":\"ast\"}",
  )
  inspect(
    prop_step("{\"phase\":\"kind\",\"k\":\"Str\"}"),
    content="{\"op\":\"ast\"}",
  )
  inspect(
    prop_step("{\"phase\":\"kind\",\"k\":\"Nope\"}"),
    content="{\"op\":\"no\"}",
  )
  inspect(prop_step("{\"phase\":\"kind\"}"), content="{\"op\":\"no\"}")
  inspect(
    prop_step(
      "{\"phase\":\"start\",\"kind\":\"ast\",\"k\":\"StateRef\",\"reactive\":true}",
    ),
    content="{\"op\":\"assign\"}",
  )
  inspect(
    prop_step("{\"phase\":\"start\",\"kind\":\"ast\",\"k\":\"StateRef\"}"),
    content="{\"op\":\"eval\"}",
  )
  inspect(
    prop_step(
      "{\"phase\":\"start\",\"kind\":\"ast\",\"k\":\"Str\",\"reactive\":true}",
    ),
    content="{\"op\":\"eval\"}",
  )
  inspect(
    prop_step("{\"phase\":\"start\",\"kind\":\"array\"}"),
    content="{\"op\":\"arr\"}",
  )
  inspect(
    prop_step("{\"phase\":\"start\",\"kind\":\"el\"}"),
    content="{\"op\":\"el\"}",
  )
  inspect(
    prop_step("{\"phase\":\"start\",\"kind\":\"plan\"}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    prop_step("{\"phase\":\"start\",\"kind\":\"obj\"}"),
    content="{\"op\":\"scan\"}",
  )
  inspect(prop_step("{\"phase\":\"start\"}"), content="{\"op\":\"scan\"}")
  inspect(
    prop_step("{\"phase\":\"eval\",\"element\":true,\"array\":true}"),
    content="{\"op\":\"el\"}",
  )
  inspect(
    prop_step("{\"phase\":\"eval\",\"array\":true}"),
    content="{\"op\":\"items\"}",
  )
  inspect(
    prop_step("{\"phase\":\"eval\",\"assign\":true,\"reactive\":false}"),
    content="{\"op\":\"state\"}",
  )
  inspect(
    prop_step("{\"phase\":\"eval\",\"assign\":true,\"reactive\":true}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(prop_step("{\"phase\":\"eval\"}"), content="{\"op\":\"keep\"}")
  inspect(
    prop_step("{\"phase\":\"scan\",\"needs\":true}"),
    content="{\"op\":\"obj\"}",
  )
  inspect(
    prop_step("{\"phase\":\"scan\",\"needs\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(prop_step("{\"phase\":\"later\"}"), content="{\"op\":\"keep\"}")
  inspect(prop_step("{"), content="{\"op\":\"keep\"}")
  inspect(prop_step("[]"), content="{\"op\":\"keep\"}")
  inspect(
    prop_error("{\"key\":\"title\",\"typeName\":\"Card\",\"message\":\"boom\"}"),
    content="{\"source\":\"runtime\",\"code\":\"runtime-error\",\"component\":\"Card\",\"statementId\":null,\"message\":\"Evaluating prop \\\"title\\\" on Card failed: boom\",\"hint\":\"Check the expression used for prop \\\"title\\\"\"}",
  )
  inspect(
    prop_error("{\"key\":\"a\\\"b\",\"typeName\":\"Row\",\"message\":\"x\"}"),
    content="{\"source\":\"runtime\",\"code\":\"runtime-error\",\"component\":\"Row\",\"statementId\":null,\"message\":\"Evaluating prop \\\"a\\\"b\\\" on Row failed: x\",\"hint\":\"Check the expression used for prop \\\"a\\\"b\\\"\"}",
  )
  inspect(
    prop_error("{"),
    content="{\"source\":\"runtime\",\"code\":\"runtime-error\",\"component\":\"\",\"statementId\":null,\"message\":\"Evaluating prop \\\"\\\" on  failed: \",\"hint\":\"Check the expression used for prop \\\"\\\"\"}",
  )
}

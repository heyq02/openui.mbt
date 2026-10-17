///|
test "action plans and tool results match the official decisions" {
  inspect(is_action_plan("{\"object\":true,\"steps\":\"a\"}"), content="1")
  inspect(is_action_plan("{\"object\":true,\"steps\":\"x\"}"), content="0")
  inspect(is_action_plan("{\"object\":false,\"steps\":\"a\"}"), content="0")
  inspect(is_action_plan("{\"object\":true}"), content="0")
  inspect(is_action_plan("{\"object\":\"yes\",\"steps\":\"a\"}"), content="0")
  inspect(is_action_plan("[]"), content="0")
  inspect(is_action_plan("{"), content="0")
  inspect(plan_items(@json.parse("[]")).length(), content="0")
  inspect(
    extract_tool_result(
      "{\"error\":true,\"structured\":false,\"content\":\"array\",\"items\":[]}",
    ),
    content="{\"op\":\"error\",\"at\":[]}",
  )
  inspect(
    flatten_plans("[\"h\",\"plan\",\"drop\",\"step\",1]"),
    content="[{\"op\":\"steps\",\"i\":1},{\"op\":\"step\",\"i\":3}]",
  )
  inspect(flatten_plans("[\"plan\"]"), content="[{\"op\":\"steps\",\"i\":0}]")
  inspect(flatten_plans("[]"), content="[]")
  inspect(flatten_plans("{}"), content="[]")
  inspect(flatten_plans("{"), content="[]")
  inspect(
    extract_tool_result(
      "{\"error\":true,\"structured\":true,\"content\":\"array\",\"items\":[\"text\",\"h\",\"text\",\"bad\",\"text\"]}",
    ),
    content="{\"op\":\"throw\",\"i\":3}",
  )
  inspect(
    extract_tool_result(
      "{\"error\":true,\"structured\":false,\"content\":\"array\",\"items\":[\"text\",\"skip\",\"text\"]}",
    ),
    content="{\"op\":\"error\",\"at\":[0,2]}",
  )
  inspect(
    extract_tool_result(
      "{\"error\":true,\"structured\":false,\"content\":\"missing\",\"items\":[]}",
    ),
    content="{\"op\":\"error\",\"at\":[]}",
  )
  inspect(
    extract_tool_result(
      "{\"error\":true,\"structured\":false,\"content\":\"other\",\"items\":[]}",
    ),
    content="{\"op\":\"throw\"}",
  )
  inspect(
    extract_tool_result(
      "{\"error\":false,\"structured\":true,\"content\":\"array\",\"items\":[\"bad\"]}",
    ),
    content="{\"op\":\"structured\"}",
  )
  inspect(
    extract_tool_result(
      "{\"error\":false,\"structured\":false,\"content\":\"array\",\"items\":[\"h\",\"skip\",1,\"text\"]}",
    ),
    content="{\"op\":\"parse\",\"at\":[3]}",
  )
  inspect(
    extract_tool_result(
      "{\"error\":false,\"structured\":false,\"content\":\"array\",\"items\":[\"skip\"]}",
    ),
    content="{\"op\":\"null\"}",
  )
  inspect(
    extract_tool_result(
      "{\"error\":false,\"structured\":false,\"content\":\"missing\"}",
    ),
    content="{\"op\":\"null\"}",
  )
  inspect(
    extract_tool_result(
      "{\"error\":false,\"structured\":false,\"content\":\"array\"}",
    ),
    content="{\"op\":\"null\"}",
  )
  inspect(extract_tool_result("1"), content="{\"op\":\"throw\"}")
  inspect(extract_tool_result("{"), content="{\"op\":\"null\"}")
}

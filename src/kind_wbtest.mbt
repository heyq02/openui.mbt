///|
test "prompt kind and node guards match the official predicates" {
  inspect(
    system_prompt_kind(
      "{\"cloudIn\":true,\"cloudTrue\":true,\"libraryIn\":true,\"libraryObject\":true}",
    ),
    content="cloud",
  )
  inspect(
    system_prompt_kind(
      "{\"cloudIn\":true,\"cloudTrue\":false,\"libraryIn\":true,\"libraryObject\":true}",
    ),
    content="library",
  )
  inspect(
    system_prompt_kind(
      "{\"cloudIn\":false,\"libraryIn\":true,\"libraryObject\":true}",
    ),
    content="library",
  )
  inspect(
    system_prompt_kind(
      "{\"cloudIn\":true,\"cloudTrue\":true,\"libraryIn\":false,\"libraryObject\":false}",
    ),
    content="cloud",
  )
  inspect(
    system_prompt_kind(
      "{\"cloudIn\":false,\"libraryIn\":true,\"libraryObject\":false}",
    ),
    content="legacy",
  )
  inspect(
    system_prompt_kind(
      "{\"cloudIn\":false,\"libraryIn\":false,\"libraryObject\":false}",
    ),
    content="legacy",
  )
  inspect(system_prompt_kind("{"), content="legacy")
  inspect(
    is_element_node(
      "{\"type\":\"element\",\"typeName\":\"s\",\"props\":\"o\",\"partial\":\"b\"}",
    ),
    content="1",
  )
  inspect(
    is_element_node(
      "{\"type\":\"element\",\"typeName\":\"s\",\"props\":\"a\",\"partial\":\"b\"}",
    ),
    content="1",
  )
  inspect(
    is_element_node(
      "{\"type\":\"element\",\"typeName\":\"s\",\"props\":\"z\",\"partial\":\"b\"}",
    ),
    content="0",
  )
  inspect(
    is_element_node(
      "{\"type\":\"element\",\"typeName\":\"s\",\"props\":\"f\",\"partial\":\"b\"}",
    ),
    content="0",
  )
  inspect(
    is_element_node(
      "{\"type\":\"Element\",\"typeName\":\"s\",\"props\":\"o\",\"partial\":\"b\"}",
    ),
    content="0",
  )
  inspect(
    is_element_node(
      "{\"type\":\"element\",\"typeName\":\"n\",\"props\":\"o\",\"partial\":\"b\"}",
    ),
    content="0",
  )
  inspect(
    is_element_node(
      "{\"type\":\"element\",\"typeName\":\"s\",\"props\":\"o\",\"partial\":\"n\"}",
    ),
    content="0",
  )
  inspect(
    is_element_node(
      "{\"type\":\"\",\"typeName\":\"s\",\"props\":\"o\",\"partial\":\"b\"}",
    ),
    content="0",
  )
  inspect(
    is_element_node(
      "{\"type\":1,\"typeName\":\"s\",\"props\":\"o\",\"partial\":\"b\"}",
    ),
    content="0",
  )
  inspect(is_element_node("{"), content="0")
  inspect(
    is_reactive_assign("{\"object\":true,\"text\":\"assign\"}"),
    content="1",
  )
  inspect(is_reactive_assign("{\"object\":true,\"text\":\"set\"}"), content="0")
  inspect(
    is_reactive_assign("{\"object\":false,\"text\":\"assign\"}"),
    content="0",
  )
  inspect(is_reactive_assign("{\"object\":true,\"text\":\"\"}"), content="0")
  inspect(is_reactive_assign("{"), content="0")
  inspect(is_runtime_expr("StateRef"), content="1")
  inspect(is_runtime_expr("RuntimeRef"), content="1")
  inspect(is_runtime_expr("BinOp"), content="1")
  inspect(is_runtime_expr("UnaryOp"), content="1")
  inspect(is_runtime_expr("Ternary"), content="1")
  inspect(is_runtime_expr("Member"), content="1")
  inspect(is_runtime_expr("Index"), content="1")
  inspect(is_runtime_expr("Assign"), content="1")
  inspect(is_runtime_expr("Ref"), content="0")
  inspect(is_runtime_expr("Comp"), content="0")
  inspect(is_runtime_expr("Str"), content="0")
  inspect(is_runtime_expr(""), content="0")
}

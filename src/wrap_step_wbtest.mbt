///|
test "prop wrapping and action calls choose the host branch" {
  inspect(
    wrap_step("{\"phase\":\"plan\",\"plan\":true}"),
    content="{\"op\":\"own\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"plan\",\"plan\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"plan\",\"plan\":1}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(wrap_step("{\"phase\":\"inline\"}"), content="{\"op\":\"core\"}")
  inspect(wrap_step("{\"phase\":\"tree\"}"), content="{\"op\":\"core\"}")
  inspect(
    wrap_step("{\"phase\":\"call\",\"action\":true}"),
    content="{\"op\":\"list\"}",
  )
  inspect(wrap_step("{\"phase\":\"call\"}"), content="{\"op\":\"step\"}")
  inspect(
    wrap_step("{\"phase\":\"open\",\"open\":true}"),
    content="{\"op\":\"eval\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"open\",\"open\":false}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"boxed\",\"array\":true}"),
    content="{\"op\":\"plans\"}",
  )
  inspect(wrap_step("{\"phase\":\"boxed\"}"), content="{\"op\":\"blank\"}")
  inspect(
    wrap_step("{\"phase\":\"def\",\"has\":true}"),
    content="{\"op\":\"call\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"def\",\"has\":\"yes\"}"),
    content="{\"op\":\"lazy\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"pack\",\"filled\":true}"),
    content="{\"op\":\"one\"}",
  )
  inspect(wrap_step("{\"phase\":\"pack\"}"), content="{\"op\":\"empty\"}")
  inspect(
    wrap_step("{\"phase\":\"lazy\",\"kind\":\"run\"}"),
    content="{\"op\":\"run\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"lazy\",\"kind\":\"set\"}"),
    content="{\"op\":\"set\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"lazy\",\"kind\":\"reset\"}"),
    content="{\"op\":\"reset\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"lazy\",\"kind\":\"other\"}"),
    content="{\"op\":\"none\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"lazy\",\"kind\":1}"),
    content="{\"op\":\"none\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"ref\",\"ok\":true}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(wrap_step("{\"phase\":\"ref\"}"), content="{\"op\":\"drop\"}")
  inspect(
    wrap_step("{\"phase\":\"pair\",\"open\":true}"),
    content="{\"op\":\"go\"}",
  )
  inspect(wrap_step("{\"phase\":\"pair\"}"), content="{\"op\":\"drop\"}")
  inspect(
    wrap_step("{\"phase\":\"state\",\"state\":true}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"state\",\"state\":false}"),
    content="{\"op\":\"drop\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"reset\",\"empty\":true}"),
    content="{\"op\":\"drop\"}",
  )
  inspect(wrap_step("{\"phase\":\"reset\"}"), content="{\"op\":\"keep\"}")
  inspect(
    wrap_step("{\"phase\":\"builtin\",\"has\":true}"),
    content="{\"op\":\"yes\"}",
  )
  inspect(wrap_step("{\"phase\":\"builtin\"}"), content="{\"op\":\"no\"}")
  inspect(
    wrap_step("{\"phase\":\"step\",\"action\":true}"),
    content="{\"op\":\"yes\"}",
  )
  inspect(wrap_step("{\"phase\":\"step\"}"), content="{\"op\":\"no\"}")
  inspect(
    wrap_step("{\"phase\":\"extra\",\"present\":true}"),
    content="{\"op\":\"scan\"}",
  )
  inspect(wrap_step("{\"phase\":\"extra\"}"), content="{\"op\":\"skip\"}")
  inspect(
    wrap_step("{\"phase\":\"own\",\"own\":true}"),
    content="{\"op\":\"yes\"}",
  )
  inspect(wrap_step("{\"phase\":\"own\"}"), content="{\"op\":\"no\"}")
  inspect(
    wrap_step("{\"phase\":\"reserved\",\"has\":true}"),
    content="{\"op\":\"yes\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"reserved\",\"has\":0}"),
    content="{\"op\":\"no\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"cat\",\"present\":true}"),
    content="{\"op\":\"local\"}",
  )
  inspect(wrap_step("{\"phase\":\"cat\"}"), content="{\"op\":\"builtin\"}")
  inspect(
    wrap_step("{\"phase\":\"defs\",\"present\":true}"),
    content="{\"op\":\"local\"}",
  )
  inspect(
    wrap_step("{\"phase\":\"defs\",\"present\":false}"),
    content="{\"op\":\"builtin\"}",
  )
  inspect(wrap_step("{\"phase\":\"other\"}"), content="{\"op\":\"keep\"}")
  inspect(wrap_step("{\"phase\":1}"), content="{\"op\":\"keep\"}")
  inspect(wrap_step("[]"), content="{\"op\":\"keep\"}")
  inspect(wrap_step("{"), content="{\"op\":\"keep\"}")
}

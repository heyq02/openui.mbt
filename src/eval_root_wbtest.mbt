///|
test "evaluateRoot and Each decide before the host evaluates" {
  inspect(evaluate_root("root"), content="{\"op\":\"props\"}")
  inspect(evaluate_root("expr"), content="{\"op\":\"eval\"}")
  inspect(evaluate_root("none"), content="{\"op\":\"null\"}")
  inspect(evaluate_root("element"), content="{\"op\":\"props\"}")
  inspect(
    evaluate_root("miss"),
    content="{\"op\":\"error\",\"error\":{\"source\":\"runtime\",\"code\":\"no-root\",\"statementId\":\"root\",\"message\":\"root does not evaluate to a component\"}}",
  )
  inspect(evaluate_root(""), content="{\"op\":\"null\"}")
  inspect(evaluate_root("other"), content="{\"op\":\"null\"}")
  inspect(
    each_step("{\"phase\":\"open\",\"name\":\"Filter\",\"n\":3}"),
    content="{\"op\":\"null\"}",
  )
  inspect(
    each_step("{\"phase\":\"open\",\"name\":\"Each\",\"n\":2}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    each_step("{\"phase\":\"open\",\"name\":\"Each\",\"n\":0}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    each_step("{\"phase\":\"open\",\"name\":\"Each\"}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    each_step("{\"phase\":\"open\",\"name\":\"Each\",\"n\":3}"),
    content="{\"op\":\"eval\"}",
  )
  inspect(
    each_step("{\"phase\":\"open\",\"name\":\"Each\",\"n\":3.5}"),
    content="{\"op\":\"eval\"}",
  )
  inspect(
    each_step("{\"phase\":\"open\",\"name\":\"Each\",\"n\":-1}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    each_step("{\"phase\":\"open\",\"name\":\"Each\",\"wide\":true}"),
    content="{\"op\":\"eval\"}",
  )
  inspect(
    each_step("{\"phase\":\"array\",\"array\":false}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    each_step("{\"phase\":\"array\",\"array\":true}"),
    content="{\"op\":\"bind\"}",
  )
  inspect(each_step("{\"phase\":\"array\"}"), content="{\"op\":\"empty\"}")
  inspect(
    each_step("{\"phase\":\"name\",\"k\":\"Ref\",\"ok\":true}"),
    content="{\"op\":\"map\"}",
  )
  inspect(
    each_step("{\"phase\":\"name\",\"k\":\"Str\",\"ok\":true}"),
    content="{\"op\":\"map\"}",
  )
  inspect(
    each_step("{\"phase\":\"name\",\"k\":\"Ref\",\"ok\":false}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    each_step("{\"phase\":\"name\",\"k\":\"Str\"}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    each_step("{\"phase\":\"name\",\"k\":\"Num\",\"ok\":true}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(each_step("{\"phase\":\"later\"}"), content="{\"op\":\"null\"}")
  inspect(each_step("[]"), content="{\"op\":\"null\"}")
  inspect(each_step("{"), content="{\"op\":\"null\"}")
}

///|
test "argument binding chooses mapped props, strict failure, and warnings" {
  inspect(
    bind_step("{\"phase\":\"args\",\"mapped\":true}"),
    content="{\"op\":\"props\"}",
  )
  inspect(
    bind_step("{\"phase\":\"args\",\"mapped\":false}"),
    content="{\"op\":\"list\"}",
  )
  inspect(bind_step("{\"phase\":\"args\"}"), content="{\"op\":\"list\"}")
  inspect(
    bind_step("{\"phase\":\"args\",\"mapped\":1}"),
    content="{\"op\":\"list\"}",
  )
  inspect(bind_step("{\"phase\":\"name\"}"), content="{\"op\":\"set\"}")
  inspect(
    bind_step("{\"phase\":\"strict\",\"failed\":true}"),
    content="{\"op\":\"invalid\"}",
  )
  inspect(
    bind_step("{\"phase\":\"strict\",\"failed\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    bind_step("{\"phase\":\"strict\",\"failed\":0}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    bind_step("{\"phase\":\"warn\",\"warn\":true}"),
    content="{\"op\":\"warning\"}",
  )
  inspect(
    bind_step("{\"phase\":\"warn\",\"warn\":false}"),
    content="{\"op\":\"plain\"}",
  )
  inspect(
    bind_step("{\"phase\":\"warn\",\"warn\":\"yes\"}"),
    content="{\"op\":\"plain\"}",
  )
  inspect(bind_step("{\"phase\":\"other\"}"), content="{\"op\":\"keep\"}")
  inspect(bind_step("{\"phase\":1}"), content="{\"op\":\"keep\"}")
  inspect(bind_step("[]"), content="{\"op\":\"keep\"}")
  inspect(bind_step("{"), content="{\"op\":\"keep\"}")
}

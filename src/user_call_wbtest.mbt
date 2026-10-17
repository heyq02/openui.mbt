///|
test "user calls stop on missing args, invalid values, and thrown errors" {
  inspect(
    user_call("{\"phase\":\"args\",\"miss\":true}"),
    content="{\"op\":\"null\"}",
  )
  inspect(
    user_call("{\"phase\":\"args\",\"miss\":false}"),
    content="{\"op\":\"check\"}",
  )
  inspect(
    user_call("{\"phase\":\"args\",\"miss\":1}"),
    content="{\"op\":\"check\"}",
  )
  inspect(user_call("{\"phase\":\"args\"}"), content="{\"op\":\"check\"}")
  inspect(
    user_call("{\"phase\":\"checked\",\"bad\":true}"),
    content="{\"op\":\"null\"}",
  )
  inspect(
    user_call("{\"phase\":\"checked\",\"bad\":false}"),
    content="{\"op\":\"call\"}",
  )
  inspect(
    user_call("{\"phase\":\"checked\",\"bad\":0}"),
    content="{\"op\":\"call\"}",
  )
  inspect(user_call("{\"phase\":\"threw\"}"), content="{\"op\":\"null\"}")
  inspect(
    user_call("{\"phase\":\"result\",\"returns\":false}"),
    content="{\"op\":\"value\"}",
  )
  inspect(
    user_call("{\"phase\":\"result\",\"returns\":true}"),
    content="{\"op\":\"check\"}",
  )
  inspect(
    user_call("{\"phase\":\"result\",\"returns\":1}"),
    content="{\"op\":\"value\"}",
  )
  inspect(user_call("{\"phase\":\"result\"}"), content="{\"op\":\"value\"}")
  inspect(
    user_call("{\"phase\":\"returns\",\"bad\":true,\"nil\":false}"),
    content="{\"op\":\"null\"}",
  )
  inspect(
    user_call("{\"phase\":\"returns\",\"bad\":false,\"nil\":true}"),
    content="{\"op\":\"null\"}",
  )
  inspect(
    user_call("{\"phase\":\"returns\",\"bad\":true,\"nil\":true}"),
    content="{\"op\":\"null\"}",
  )
  inspect(
    user_call("{\"phase\":\"returns\",\"bad\":false,\"nil\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    user_call("{\"phase\":\"returns\",\"bad\":1,\"nil\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(user_call("{\"phase\":\"other\"}"), content="{\"op\":\"null\"}")
  inspect(user_call("{\"phase\":1}"), content="{\"op\":\"null\"}")
  inspect(user_call("[]"), content="{\"op\":\"null\"}")
  inspect(user_call("{"), content="{\"op\":\"null\"}")
}

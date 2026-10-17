///|
test "custom actions stop on a missing argument or an invalid value" {
  inspect(
    custom_call("{\"phase\":\"open\",\"named\":true}"),
    content="{\"op\":\"act\"}",
  )
  inspect(
    custom_call("{\"phase\":\"open\",\"named\":false}"),
    content="{\"op\":\"skip\"}",
  )
  inspect(
    custom_call("{\"phase\":\"open\",\"named\":1}"),
    content="{\"op\":\"skip\"}",
  )
  inspect(custom_call("{\"phase\":\"open\"}"), content="{\"op\":\"skip\"}")
  inspect(
    custom_call("{\"phase\":\"args\",\"miss\":true}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    custom_call("{\"phase\":\"args\",\"miss\":false}"),
    content="{\"op\":\"check\"}",
  )
  inspect(
    custom_call("{\"phase\":\"args\",\"miss\":0}"),
    content="{\"op\":\"check\"}",
  )
  inspect(custom_call("{\"phase\":\"args\"}"), content="{\"op\":\"check\"}")
  inspect(
    custom_call("{\"phase\":\"checked\",\"bad\":true}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    custom_call("{\"phase\":\"checked\",\"bad\":false}"),
    content="{\"op\":\"build\"}",
  )
  inspect(
    custom_call("{\"phase\":\"checked\",\"bad\":1}"),
    content="{\"op\":\"build\"}",
  )
  inspect(custom_call("{\"phase\":\"checked\"}"), content="{\"op\":\"build\"}")
  inspect(custom_call("{\"phase\":\"other\"}"), content="{\"op\":\"skip\"}")
  inspect(custom_call("{\"phase\":1}"), content="{\"op\":\"skip\"}")
  inspect(custom_call("[]"), content="{\"op\":\"skip\"}")
  inspect(custom_call("{"), content="{\"op\":\"skip\"}")
}

///|
test "call arguments drop nulls and notice missing required values" {
  inspect(
    call_arg("{\"phase\":\"drop\",\"nil\":true,\"list\":false,\"hit\":false}"),
    content="{\"op\":\"drop\"}",
  )
  inspect(
    call_arg("{\"phase\":\"drop\",\"nil\":true,\"list\":true,\"hit\":false}"),
    content="{\"op\":\"drop\"}",
  )
  inspect(
    call_arg("{\"phase\":\"drop\",\"nil\":true,\"list\":true,\"hit\":true}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    call_arg("{\"phase\":\"drop\",\"nil\":false,\"list\":false,\"hit\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    call_arg("{\"phase\":\"drop\",\"nil\":1}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    call_arg("{\"phase\":\"miss\",\"absent\":true,\"bare\":true}"),
    content="{\"op\":\"miss\"}",
  )
  inspect(
    call_arg("{\"phase\":\"miss\",\"absent\":true,\"bare\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    call_arg("{\"phase\":\"miss\",\"absent\":false,\"bare\":true}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(call_arg("{\"phase\":\"later\"}"), content="{\"op\":\"keep\"}")
  inspect(call_arg("{\"phase\":1}"), content="{\"op\":\"keep\"}")
  inspect(call_arg("[]"), content="{\"op\":\"keep\"}")
  inspect(call_arg("{"), content="{\"op\":\"keep\"}")
}
